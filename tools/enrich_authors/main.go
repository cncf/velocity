package main

// A velocity (cncf/velocity) enrichment utility.
//
// It post-processes BigQuery CSV exports and replaces the following columns:
//   - authors       : comma-separated list of unique contributor emails
//   - authors_alt1  : comma-separated list of unique contributor names (best-effort)
//   - authors_alt2  : count of unique contributor emails
//   - commits       : count of commits found by `git log --all` (within optional date range)
//
// Contributors are extracted from local git history by temporarily cloning each repo and
// scanning commits across ALL refs (git log --all), within an optional date range.
//
// The tool extracts contributors from:
//   * commit Author (name/email)
//   * commit Committer (name/email)
//   * trailer-like lines in commit messages (Key: Name <email>, etc), including multiple
//     "Name <email>" entries on a single line.
//
// Operational highlights ("best of both"):
//   * Robust cloning: partial clone first (--filter=blob:none), optional shallow-since,
//     retries on transient network errors, optional GitHub rename/transfer detection.
//   * Robust log parsing: streamed parsing (no full git log buffering).
//   * Safe CSV update: on per-repo failure, leaves rows unchanged; optional "never worse"
//     mode prevents replacing a row if the computed author count is lower than the original.
//     For commits, "never worse" prevents updating the commits field to a lower value.
//
// Intended to be compatible with velocity's analysis.rb which expects a header row.

import (
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/csv"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unicode"
	"unicode/utf8"
)

const (
	gitExecDefault = "git"
	userAgent      = "velocity-enrich-authors"
)

var expectedHeader = []string{
	"org",
	"repo",
	"activity",
	"comments",
	"prs",
	"commits",
	"issues",
	"pushes",
	"authors_alt2",
	"authors_alt1",
	"authors",
	"author_idents",
}

// ---- Flags / config ----

type config struct {
	inPath  string
	outPath string

	from string // git log --since
	to   string // git log --until

	threads int

	tmpParent string
	keepTmp   bool

	forksPath string // optional forks JSON (repo -> bool). If true, repo is a fork and will be skipped/removed.

	gitBinary string

	repoTimeout  time.Duration // total per repo
	cloneTimeout time.Duration // per clone attempt
	logTimeout   time.Duration // git log

	cloneRetries int

	detectRenames    bool
	fetchAllBranches bool

	maxListItems int
	maxListBytes int

	neverWorse    bool
	allowDecrease bool

	overwriteTruncated bool // If a list field is truncated to '=N', allow overwriting it with the full list

	allowNoAuthorsRepos bool // If false (default), drop output rows where all author columns are empty/0

	quiet bool
	debug bool
}

func parseDateMaybe(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	// Accept YYYYMMDD.
	if len(s) == 8 {
		allDigits := true
		for _, r := range s {
			if r < '0' || r > '9' {
				allDigits = false
				break
			}
		}
		if allDigits {
			return fmt.Sprintf("%s-%s-%s", s[0:4], s[4:6], s[6:8])
		}
	}
	return s
}

func parseFlags() config {
	cfg := config{}
	flag.StringVar(&cfg.inPath, "in", "", "Input CSV file (BigQuery export)")
	flag.StringVar(&cfg.outPath, "out", "", "Output CSV file (default: <in>_enriched.csv)")

	var fromArg, toArg string
	flag.StringVar(&fromArg, "from", "", "Start date/time (inclusive). Accepts YYYYMMDD, YYYY-MM-DD, or any git-parseable date")
	flag.StringVar(&toArg, "to", "", "End date/time (exclusive day boundary if YYYY-MM-DD/YYYMMDD; passed to git log --until)")
	// Backward/alternate flag names.
	flag.StringVar(&fromArg, "since", "", "Alias for -from")
	flag.StringVar(&toArg, "until", "", "Alias for -to")

	flag.IntVar(&cfg.threads, "threads", runtime.NumCPU(), "Number of concurrent repo workers")

	flag.StringVar(&cfg.tmpParent, "tmp", "", "Base temp directory (default: OS temp dir)")
	flag.StringVar(&cfg.tmpParent, "tmpdir", "", "Alias for -tmp")
	flag.BoolVar(&cfg.keepTmp, "keep-tmp", false, "Keep cloned repos on disk (debug)")

	flag.StringVar(&cfg.forksPath, "forks", "", "Optional forks JSON file (map repo->bool). If set, repos with value true are treated as forks and are NOT processed and are removed from the output CSV")

	flag.StringVar(&cfg.gitBinary, "git", gitExecDefault, "Git executable")

	flag.DurationVar(&cfg.repoTimeout, "repo-timeout", 45*time.Minute, "Timeout per repo (clone+fetch+log)")
	flag.DurationVar(&cfg.cloneTimeout, "clone-timeout", 15*time.Minute, "Timeout for a single git clone attempt")
	flag.DurationVar(&cfg.logTimeout, "log-timeout", 30*time.Minute, "Timeout for git log")

	flag.IntVar(&cfg.cloneRetries, "clone-retries", 3, "Max attempts per clone variant (for transient errors)")

	flag.BoolVar(&cfg.detectRenames, "detect-renames", true, "On clone failure, try to detect GitHub renames via HTTPS redirects")
	flag.BoolVar(&cfg.fetchAllBranches, "fetch-all-branches", true, "After clone, explicitly fetch all heads (+refs/heads/*:refs/heads/*)")

	flag.IntVar(&cfg.maxListItems, "max-list-items", 0, "If contributor list has more than this many items, write '=N' instead of full list (0 disables)")
	flag.IntVar(&cfg.maxListBytes, "max-list-bytes", 0, "If comma-joined list exceeds this many bytes, write '=N' instead of full list (0 disables)")

	flag.BoolVar(&cfg.neverWorse, "never-worse", true, "Do not replace a row if computed author count is lower than the original")
	flag.BoolVar(&cfg.allowDecrease, "allow-decrease", false, "Override -never-worse and allow replacing rows even if computed author count is lower")

	flag.BoolVar(&cfg.overwriteTruncated, "overwrite-truncated", true, "If a list field is truncated to '=N', allow overwriting it with the full list on a subsequent run (for example, after adjusting max-list-items or max-list-bytes)")

	flag.BoolVar(&cfg.allowNoAuthorsRepos, "allow-no-authors-repos", false, "Keep rows where all author fields are empty/0 (authors_alt2=0 and authors/authors_alt1/author_idents empty). Default is to drop such rows from output.")

	flag.BoolVar(&cfg.quiet, "quiet", false, "Less logging")
	flag.BoolVar(&cfg.debug, "debug", false, "Verbose logging")

	flag.Parse()

	if cfg.inPath == "" {
		fmt.Fprintf(os.Stderr, "Usage: %s -in input.csv [-out output.csv] [flags...]\n", os.Args[0])
		flag.PrintDefaults()
		os.Exit(2)
	}
	if cfg.outPath == "" {
		ext := filepath.Ext(cfg.inPath)
		base := strings.TrimSuffix(cfg.inPath, ext)
		cfg.outPath = base + "_enriched.csv"
	}
	if cfg.tmpParent == "" {
		cfg.tmpParent = os.TempDir()
	}
	if cfg.threads < 1 {
		cfg.threads = 1
	}
	if cfg.cloneRetries < 1 {
		cfg.cloneRetries = 1
	}
	if cfg.maxListItems < 0 {
		cfg.maxListItems = 0
	}
	if cfg.maxListBytes < 0 {
		cfg.maxListBytes = 0
	}
	if cfg.allowDecrease {
		cfg.neverWorse = false
	}

	cfg.from = parseDateMaybe(fromArg)
	cfg.to = parseDateMaybe(toArg)

	return cfg
}

// ---- CSV handling ----

type csvTable struct {
	header []string
	rows   [][]string
	idx    map[string]int // lower(header) -> index
}

func isHeaderRow(rec []string) bool {
	for _, v := range rec {
		vv := strings.ToLower(strings.TrimSpace(v))
		if vv == "repo" {
			return true
		}
	}
	return false
}

func readCSV(path string) (csvTable, error) {
	f, err := os.Open(path)
	if err != nil {
		return csvTable{}, err
	}
	defer func() { _ = f.Close() }()

	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	r.ReuseRecord = false

	first, err := r.Read()
	if err != nil {
		return csvTable{}, err
	}
	// Strip UTF-8 BOM if present.
	if len(first) > 0 {
		first[0] = strings.TrimPrefix(first[0], "\ufeff")
	}

	header := []string{}
	rows := [][]string{}
	if isHeaderRow(first) {
		header = first
	} else {
		header = append([]string{}, expectedHeader...)
		rows = append(rows, first)
	}

	for {
		rec, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return csvTable{}, err
		}
		// Skip completely empty lines.
		empty := true
		for _, c := range rec {
			if strings.TrimSpace(c) != "" {
				empty = false
				break
			}
		}
		if empty {
			continue
		}
		rows = append(rows, rec)
	}

	idx := make(map[string]int, len(header))
	for i, h := range header {
		idx[strings.ToLower(strings.TrimSpace(h))] = i
	}

	return csvTable{header: header, rows: rows, idx: idx}, nil
}

func writeCSV(path string, t csvTable) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()

	w := csv.NewWriter(f)
	// Always write header row.
	hdr := make([]string, len(t.header))
	for i := range t.header {
		hdr[i] = sanitizeUTF8Cell(t.header[i])
	}
	if err := w.Write(hdr); err != nil {
		return err
	}
	for _, row := range t.rows {
		outRow := make([]string, len(row))
		for i := range row {
			outRow[i] = sanitizeUTF8Cell(row[i])
		}
		if err := w.Write(outRow); err != nil {
			return err
		}
	}
	w.Flush()
	return w.Error()
}

func colIndex(t csvTable, name string) (int, error) {
	i, ok := t.idx[strings.ToLower(strings.TrimSpace(name))]
	if !ok {
		return -1, fmt.Errorf("missing required column %q", name)
	}
	return i, nil
}

// ---- Contributors ----

type contributorSet struct {
	emails      map[string]string   // canonical(email) -> chosen output email
	names       map[string]string   // canonical(name)  -> chosen output name
	idents      map[string]struct{} // canonical(name)\x00canonical(email) -> unique pair
	commitCount int                 // number of commits processed by git log
}

func newContributorSet() *contributorSet {
	return &contributorSet{
		emails: make(map[string]string),
		names:  make(map[string]string),
		idents: make(map[string]struct{}),
	}
}

func collapseSpaces(s string) string {
	// strings.Fields splits on all Unicode whitespace and collapses runs.
	parts := strings.Fields(s)
	if len(parts) == 0 {
		return ""
	}
	return strings.Join(parts, " ")
}

// looksLikeVersionToken returns true for strings like:
//
//	"4.17", "4.17+", "v1.2.3", "V6.14+"
//
// These frequently appear in trailers like "# 4.17+" and are not contributor names.
func looksLikeVersionToken(s string) bool {
	s = strings.TrimSpace(s)
	if s == "" {
		return false
	}
	// Version tokens are single "words".
	for _, r := range s {
		if unicode.IsSpace(r) {
			return false
		}
	}
	// Optional leading v/V.
	if len(s) > 0 && (s[0] == 'v' || s[0] == 'V') {
		s = s[1:]
	}
	// Optional trailing '+'.
	s = strings.TrimSuffix(s, "+")
	if s == "" {
		return false
	}
	// Require at least one dot to avoid dropping short usernames like "v1".
	if !strings.Contains(s, ".") {
		return false
	}
	if strings.HasPrefix(s, ".") || strings.HasSuffix(s, ".") {
		return false
	}
	parts := strings.Split(s, ".")
	if len(parts) < 2 {
		return false
	}
	for _, p := range parts {
		if p == "" {
			return false
		}
		for _, r := range p {
			if r < '0' || r > '9' {
				return false
			}
		}
	}
	return true
}

// stripNameTrash replaces common "separator/garbage" characters with spaces.
// This serves two purposes:
//  1. better dedup (ignore punctuation used as separators),
//  2. ensure list items remain parseable (we join lists with ',' and wrap idents as "<email>").
//
// NOTE: We intentionally KEEP square brackets to preserve common bot names like "github-actions[bot]".
func stripNameTrash(s string) string {
	if s == "" {
		return ""
	}
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		switch r {
		case ',', ';', '<', '>', '(', ')', '&', '*', '^':
			b.WriteByte(' ')
		default:
			// Treat control chars as whitespace.
			if unicode.IsControl(r) {
				b.WriteByte(' ')
				continue
			}
			b.WriteRune(r)
		}
	}
	return b.String()
}

func isASCII(s string) bool {
	for _, r := range s {
		if r > 0x7f {
			return false
		}
	}
	return true
}

// asciiFold returns a best-effort fold suitable for canonical comparisons.
// Known Latin/European letters are mapped to ASCII; unknown runes are preserved.
// This is not meant for display, only for dedup keys.
func asciiFold(s string) string {
	if s == "" {
		return ""
	}
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		// Drop combining marks (for already-decomposed input).
		if unicode.Is(unicode.Mn, r) || unicode.Is(unicode.Mc, r) || unicode.Is(unicode.Me, r) {
			continue
		}
		if r <= 0x7f {
			b.WriteRune(r)
			continue
		}

		switch r {
		// --- Polish / common Central European ---
		case 'Ą', 'À', 'Á', 'Â', 'Ã', 'Ä', 'Å', 'Ā', 'Ă', 'Ǎ':
			b.WriteByte('A')
		case 'ą', 'à', 'á', 'â', 'ã', 'ä', 'å', 'ā', 'ă', 'ǎ':
			b.WriteByte('a')
		case 'Ć', 'Ç', 'Ĉ', 'Ċ', 'Č':
			b.WriteByte('C')
		case 'ć', 'ç', 'ĉ', 'ċ', 'č':
			b.WriteByte('c')
		case 'Ď', 'Đ':
			b.WriteByte('D')
		case 'ď', 'đ':
			b.WriteByte('d')
		case 'Ę', 'È', 'É', 'Ê', 'Ë', 'Ē', 'Ĕ', 'Ė', 'Ě':
			b.WriteByte('E')
		case 'ę', 'è', 'é', 'ê', 'ë', 'ē', 'ĕ', 'ė', 'ě':
			b.WriteByte('e')
		case 'Ğ', 'Ĝ', 'Ġ', 'Ģ':
			b.WriteByte('G')
		case 'ğ', 'ĝ', 'ġ', 'ģ':
			b.WriteByte('g')
		case 'Ĥ', 'Ħ':
			b.WriteByte('H')
		case 'ĥ', 'ħ':
			b.WriteByte('h')
		case 'Ì', 'Í', 'Î', 'Ï', 'Ĩ', 'Ī', 'Ĭ', 'Į', 'İ':
			b.WriteByte('I')
		case 'ì', 'í', 'î', 'ï', 'ĩ', 'ī', 'ĭ', 'į', 'ı':
			b.WriteByte('i')
		case 'Ĵ':
			b.WriteByte('J')
		case 'ĵ':
			b.WriteByte('j')
		case 'Ķ':
			b.WriteByte('K')
		case 'ķ':
			b.WriteByte('k')
		case 'Ł', 'Ĺ', 'Ļ', 'Ľ':
			b.WriteByte('L')
		case 'ł', 'ĺ', 'ļ', 'ľ':
			b.WriteByte('l')
		case 'Ń', 'Ñ', 'Ņ', 'Ň':
			b.WriteByte('N')
		case 'ń', 'ñ', 'ņ', 'ň':
			b.WriteByte('n')
		case 'Ó', 'Ò', 'Ô', 'Õ', 'Ö', 'Ø', 'Ō', 'Ŏ', 'Ő':
			b.WriteByte('O')
		case 'ó', 'ò', 'ô', 'õ', 'ö', 'ø', 'ō', 'ŏ', 'ő':
			b.WriteByte('o')
		case 'Ŕ', 'Ŗ', 'Ř':
			b.WriteByte('R')
		case 'ŕ', 'ŗ', 'ř':
			b.WriteByte('r')
		case 'Ś', 'Ŝ', 'Ş', 'Š':
			b.WriteByte('S')
		case 'ś', 'ŝ', 'ş', 'š':
			b.WriteByte('s')
		case 'Ţ', 'Ť', 'Ŧ':
			b.WriteByte('T')
		case 'ţ', 'ť', 'ŧ':
			b.WriteByte('t')
		case 'Ú', 'Ù', 'Û', 'Ü', 'Ũ', 'Ū', 'Ŭ', 'Ů', 'Ű', 'Ų':
			b.WriteByte('U')
		case 'ú', 'ù', 'û', 'ü', 'ũ', 'ū', 'ŭ', 'ů', 'ű', 'ų':
			b.WriteByte('u')
		case 'Ý', 'Ÿ', 'Ŷ':
			b.WriteByte('Y')
		case 'ý', 'ÿ', 'ŷ':
			b.WriteByte('y')
		case 'Ź', 'Ż', 'Ž':
			b.WriteByte('Z')
		case 'ź', 'ż', 'ž':
			b.WriteByte('z')

		// --- Special multi-letter folds ---
		case 'Æ':
			b.WriteString("AE")
		case 'æ':
			b.WriteString("ae")
		case 'Œ':
			b.WriteString("OE")
		case 'œ':
			b.WriteString("oe")
		case 'ß':
			b.WriteString("ss")
		case 'ẞ':
			b.WriteString("SS")
		case 'Þ':
			b.WriteString("TH")
		case 'þ':
			b.WriteString("th")
		case 'Ð':
			b.WriteByte('D')
		case 'ð':
			b.WriteByte('d')

		default:
			// Preserve unknown scripts (CJK/Cyrillic/etc) in the canonical key.
			if unicode.IsLetter(r) || unicode.IsNumber(r) {
				b.WriteRune(r)
			}
		}
	}
	return b.String()
}

func canonicalNameKey(name string) string {
	name = collapseSpaces(stripNameTrash(name))
	if name == "" {
		return ""
	}
	f := asciiFold(name)
	f = collapseSpaces(f)
	f = strings.ToLower(f)
	return f
}

func canonicalEmailKey(email string) string {
	email = strings.TrimSpace(email)
	if email == "" {
		return ""
	}
	f := asciiFold(email)
	if f == "" {
		f = email
	}
	f = strings.ToLower(f)
	return f
}

func titleCaseScore(s string) int {
	// Rough heuristic: counts words that look like "Titlecase" (first letter upper, rest not upper).
	words := strings.Fields(s)
	score := 0
	for _, w := range words {
		rs := []rune(w)
		if len(rs) == 0 {
			continue
		}
		if unicode.IsLetter(rs[0]) && unicode.IsUpper(rs[0]) {
			ok := true
			for _, r := range rs[1:] {
				if unicode.IsLetter(r) && unicode.IsUpper(r) {
					ok = false
					break
				}
			}
			if ok {
				score++
			}
		}
	}
	return score
}

func displayNameScore(s string) int {
	s = collapseSpaces(s)
	if s == "" {
		return 0
	}
	score := 0
	score += titleCaseScore(s) * 1000
	if !isASCII(s) {
		// Prefer keeping diacritics when other signals are equal.
		score += 100
	}
	score += len(s)
	return score
}

func betterDisplayName(cur, cand string) string {
	cur = collapseSpaces(cur)
	cand = collapseSpaces(cand)
	if cur == "" {
		return cand
	}
	if cand == "" {
		return cur
	}
	if displayNameScore(cand) > displayNameScore(cur) {
		return cand
	}
	return cur
}

func betterEmail(cur, cand string) string {
	cur = strings.TrimSpace(cur)
	cand = strings.TrimSpace(cand)
	if cur == "" {
		return cand
	}
	if cand == "" {
		return cur
	}
	// Prefer ASCII-only emails (pragmatic for downstream tooling).
	if isASCII(cand) && !isASCII(cur) {
		return cand
	}
	if !isASCII(cand) && isASCII(cur) {
		return cur
	}
	// Otherwise prefer longer (slightly biases toward fuller addresses).
	if len(cand) > len(cur) {
		return cand
	}
	return cur
}

func normalizeEmail(email string) string {
	email = strings.ReplaceAll(email, "\x00", "")
	email = strings.TrimSpace(email)
	email = strings.Trim(email, "<>")
	email = strings.TrimSpace(email)
	email = strings.ToLower(email)

	// Remove separator/punctuation that can leak in from "Name <email>" forms and
	// would break our comma-separated list fields. (These aren't valid in raw emails.)
	email = strings.Map(func(r rune) rune {
		switch r {
		case ',', ';', '<', '>':
			return -1
		default:
			if unicode.IsSpace(r) || unicode.IsControl(r) {
				return -1
			}
			return r
		}
	}, email)

	// Basic sanity: require a single '@' and non-empty local+domain parts.
	if email == "" || strings.Count(email, "@") != 1 {
		return ""
	}
	at := strings.IndexByte(email, '@')
	if at <= 0 || at >= len(email)-1 {
		return ""
	}
	// Hard safety: after cleaning, we still must not contain list/ident separators.
	if strings.ContainsAny(email, ",;<>") {
		return ""
	}
	if !utf8.ValidString(email) {
		email = strings.ToValidUTF8(email, "")
	}
	return email
}

func normalizeName(name string) string {
	name = strings.ReplaceAll(name, "\x00", "")
	if !utf8.ValidString(name) {
		name = strings.ToValidUTF8(name, "")
	}
	name = strings.TrimSpace(name)
	name = strings.Trim(name, "\"'")
	name = strings.TrimSpace(name)
	name = stripNameTrash(name)
	name = collapseSpaces(name)
	if name == "" {
		return ""
	}
	if looksLikeVersionToken(name) {
		return ""
	}
	return name
}

func (cs *contributorSet) add(name, email string) {
	emailOut := normalizeEmail(email)
	if emailOut == "" {
		return
	}
	emailKey := canonicalEmailKey(emailOut)
	if emailKey == "" {
		emailKey = emailOut
	}
	if prev, ok := cs.emails[emailKey]; ok {
		cs.emails[emailKey] = betterEmail(prev, emailOut)
	} else {
		cs.emails[emailKey] = emailOut
	}

	nameOut := normalizeName(name)
	if nameOut == "" {
		return
	}
	nameKey := canonicalNameKey(nameOut)
	if nameKey == "" {
		nameKey = strings.ToLower(nameOut)
	}
	if prev, ok := cs.names[nameKey]; ok {
		cs.names[nameKey] = betterDisplayName(prev, nameOut)
	} else {
		cs.names[nameKey] = nameOut
	}

	// Dedup idents by canonical(name,email), output built later from best chosen strings.
	cs.idents[nameKey+"\x00"+emailKey] = struct{}{}
}

func (cs *contributorSet) emailsSorted() []string {
	out := make([]string, 0, len(cs.emails))
	for _, e := range cs.emails {
		out = append(out, e)
	}
	sort.Strings(out)
	return out
}

func (cs *contributorSet) namesSorted() []string {
	out := make([]string, 0, len(cs.names))
	for _, n := range cs.names {
		out = append(out, n)
	}
	sort.Strings(out)
	return out
}

func (cs *contributorSet) identsSorted() []string {
	out := make([]string, 0, len(cs.idents))
	for k := range cs.idents {
		parts := strings.SplitN(k, "\x00", 2)
		if len(parts) != 2 {
			continue
		}
		nk, ek := parts[0], parts[1]
		name := cs.names[nk]
		email := cs.emails[ek]
		if name == "" || email == "" {
			continue
		}
		// author_idents is comma-separated, so the *name* must not contain ','.
		// We also wrap email as "<...>", so name must not contain '<' or '>'.
		safeName := normalizeName(name)
		safeName = strings.ReplaceAll(safeName, "<", " ")
		safeName = strings.ReplaceAll(safeName, ">", " ")
		safeName = strings.ReplaceAll(safeName, ",", " ")
		safeName = collapseSpaces(safeName)
		// Emails should already be normalized to not contain these; keep it hard-safe.
		if safeName == "" || strings.ContainsAny(email, ",<>") {
			continue
		}
		out = append(out, safeName+"<"+email+">")
	}
	sort.Strings(out)
	return out
}

// ---- Trailer parsing ----

type trailerContributor struct {
	Name  string
	Email string
}

// Trailer line matcher: a conservative "Key: Value" form.
// Accept underscores and the common unicode en-dash.
var trailerLineRE = regexp.MustCompile(`^(?P<key>[A-Za-z0-9_\-–]+)\:[ \t]+(?P<value>.+)$`)

// Email regex (heuristic). Used as a fallback when value isn't strictly "Name <email>".
var emailRE = regexp.MustCompile(`(?i)([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})`)

func matchGroups(re *regexp.Regexp, s string) map[string]string {
	matches := re.FindStringSubmatch(s)
	if matches == nil {
		return nil
	}
	out := make(map[string]string)
	for i, name := range re.SubexpNames() {
		if i != 0 && name != "" {
			out[name] = matches[i]
		}
	}
	return out
}

// parseTrailerContributors extracts contributors from trailer-like lines in msg.
//
// It prefers "Name <email>" patterns and supports multiple entries per line.
// If none are found, it falls back to extracting raw emails from the value.
func parseTrailerContributors(msg string) []trailerContributor {
	lines := strings.Split(msg, "\n")
	out := make([]trailerContributor, 0, 4)
	for _, l := range lines {
		l = strings.TrimSpace(strings.TrimRight(l, "\r"))
		if l == "" {
			continue
		}
		m := matchGroups(trailerLineRE, l)
		if len(m) == 0 {
			continue
		}
		value := strings.TrimSpace(m["value"])
		if value == "" {
			continue
		}

		// First try: one or more "Name <email>" patterns.
		pairs := extractAllNameEmail(value)
		if len(pairs) > 0 {
			out = append(out, pairs...)
			continue
		}

		// Fallback: extract any emails and emit entries with empty names.
		matches := emailRE.FindAllStringSubmatch(value, -1)
		for _, mm := range matches {
			if len(mm) < 2 {
				continue
			}
			em := mm[1]
			out = append(out, trailerContributor{Name: "", Email: em})
		}
	}
	return out
}

// extractAllNameEmail extracts all occurrences of Name <email> from a string.
// It is tolerant to multiple entries on the same line.
func extractAllNameEmail(s string) []trailerContributor {
	out := []trailerContributor{}
	for {
		lt := strings.Index(s, "<")
		if lt < 0 {
			break
		}
		gt := strings.Index(s[lt+1:], ">")
		if gt < 0 {
			break
		}
		gt = lt + 1 + gt

		email := strings.TrimSpace(s[lt+1 : gt])

		prefix := strings.TrimSpace(s[:lt])
		if comma := strings.LastIndex(prefix, ","); comma >= 0 {
			prefix = strings.TrimSpace(prefix[comma+1:])
		}
		name := strings.TrimSpace(prefix)
		// Keep square brackets, they are common in bot names (github-actions[bot]).
		name = strings.Trim(name, "\t \"'()")
		email = strings.Trim(email, "\t \"'()")

		if normalizeEmail(email) != "" {
			out = append(out, trailerContributor{Name: name, Email: email})
		}

		if gt+1 >= len(s) {
			break
		}
		s = s[gt+1:]
	}
	return out
}

// ---- Repo processing ----

type repoStats struct {
	repoInput    string
	repoResolved string
	emails       []string
	names        []string
	idents       []string
	emailCount   int
	commitCount  int
	cloneFailed  bool
	err          error
}

func sanitizeRepoDirName(repo string) string {
	clean := strings.ToLower(strings.TrimSpace(repo))
	clean = strings.ReplaceAll(clean, "/", "_")
	clean = strings.ReplaceAll(clean, "\\", "_")
	clean = strings.ReplaceAll(clean, " ", "_")
	// Keep filenames reasonably short to avoid path length issues on some systems.
	if len(clean) > 80 {
		clean = clean[:80]
	}

	sum := sha1.Sum([]byte(repo))
	h := fmt.Sprintf("%x", sum[:])
	if len(h) > 10 {
		h = h[:10]
	}
	if clean == "" {
		clean = "repo"
	}
	return fmt.Sprintf("%s-%s", clean, h)
}

func isTransientGitFailure(out string) bool {
	s := strings.ToLower(out)
	transient := []string{
		"connection timed out",
		"connection reset",
		"could not resolve host",
		"failed to connect",
		"proxy error",
		"tls",
		"http2",
		"the requested url returned error: 5", // 5xx
		"the requested url returned error: 429",
		"rpc failed",
		"remote end hung up",
		"early eof",
		"network is unreachable",
	}
	for _, sub := range transient {
		if strings.Contains(s, sub) {
			return true
		}
	}
	return false
}

func resetDir(dst string) error {
	_ = os.RemoveAll(dst)
	return os.MkdirAll(dst, 0o755)
}

func runCmd(ctx context.Context, env []string, name string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = append(os.Environ(), env...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func normalizeGitHubRepo(repo string) (string, bool) {
	repo = strings.TrimSpace(repo)
	if repo == "" {
		return "", false
	}
	// If input is a URL, parse it.
	if strings.Contains(repo, "://") {
		u, err := url.Parse(repo)
		if err != nil {
			return "", false
		}
		if !strings.EqualFold(u.Hostname(), "github.com") {
			return "", false
		}
		parts := strings.Split(strings.Trim(u.Path, "/"), "/")
		if len(parts) < 2 {
			return "", false
		}
		owner := parts[0]
		r := strings.TrimSuffix(parts[1], ".git")
		if owner == "" || r == "" {
			return "", false
		}
		return owner + "/" + r, true
	}
	// Strip common github prefixes.
	repo = strings.TrimPrefix(repo, "https://github.com/")
	repo = strings.TrimPrefix(repo, "http://github.com/")
	repo = strings.TrimPrefix(repo, "github.com/")
	repo = strings.Trim(repo, "/")
	repo = strings.TrimSuffix(repo, ".git")
	parts := strings.Split(repo, "/")
	// If the user provided a host/path style without a scheme (for example
	// "gitlab.com/group/repo"), don't misinterpret that as a GitHub org/repo.
	if len(parts) >= 3 && strings.Contains(parts[0], ".") && !strings.EqualFold(parts[0], "github.com") {
		return "", false
	}
	if len(parts) < 2 {
		return "", false
	}
	owner := parts[0]
	r := parts[1]
	if owner == "" || r == "" {
		return "", false
	}
	return owner + "/" + r, true
}

// normalizeForkKey converts various repo spellings into a stable lowercase "org/repo" key
// suitable for lookups in the forks map.
func normalizeForkKey(repo string) string {
	repo = strings.TrimSpace(repo)
	if repo == "" {
		return ""
	}
	if r, ok := normalizeGitHubRepo(repo); ok {
		return strings.ToLower(r)
	}
	// Fallback for common non-URL spellings.
	repo = strings.TrimPrefix(repo, "github.com/")
	repo = strings.TrimPrefix(repo, "www.github.com/")
	repo = strings.TrimPrefix(repo, "https://github.com/")
	repo = strings.TrimPrefix(repo, "http://github.com/")
	repo = strings.TrimSuffix(repo, ".git")
	repo = strings.Trim(repo, "/")
	parts := strings.Split(repo, "/")
	if len(parts) >= 2 {
		return strings.ToLower(parts[0] + "/" + parts[1])
	}
	return strings.ToLower(repo)
}

func readForksFile(path string) (map[string]bool, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	raw := make(map[string]bool)
	if err := json.Unmarshal(b, &raw); err != nil {
		return nil, err
	}
	out := make(map[string]bool, len(raw))
	for k, v := range raw {
		nk := normalizeForkKey(k)
		if nk == "" {
			continue
		}
		out[nk] = v
	}
	return out, nil
}

func cloneURLFromRepo(repo string) string {
	repo = strings.TrimSpace(repo)
	if repo == "" {
		return ""
	}
	// If already a URL or SSH form, keep as-is.
	if strings.Contains(repo, "://") || strings.HasPrefix(repo, "git@") {
		return repo
	}
	// Handle host/path style without scheme (e.g. "gitlab.com/group/repo" or
	// "github.com/org/repo").
	if strings.Contains(repo, "/") {
		parts := strings.Split(strings.Trim(repo, "/"), "/")
		if len(parts) >= 3 && strings.Contains(parts[0], ".") {
			// Treat as https://<host>/<path>.
			u := "https://" + strings.TrimSuffix(strings.Trim(repo, "/"), ".git")
			return u + ".git"
		}
	}

	// If looks like github.com/org/repo without scheme.
	if strings.HasPrefix(repo, "github.com/") {
		repo = strings.TrimPrefix(repo, "github.com/")
	}

	// Default: treat as GitHub org/repo.
	repo = strings.TrimPrefix(repo, "https://github.com/")
	repo = strings.TrimSuffix(repo, ".git")
	repo = strings.Trim(repo, "/")
	if repo == "" {
		return ""
	}
	return "https://github.com/" + repo + ".git"
}

// resolveGitHubRepo tries to detect a GitHub rename/transfer by following redirects on
// https://github.com/<org>/<repo>.
func resolveGitHubRepo(repo string, timeout time.Duration) (string, bool, error) {
	orgRepo, ok := normalizeGitHubRepo(repo)
	if !ok {
		return "", false, nil
	}

	u := "https://github.com/" + orgRepo
	client := &http.Client{Timeout: timeout}
	req, err := http.NewRequest("GET", u, nil)
	if err != nil {
		return "", false, err
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := client.Do(req)
	if err != nil {
		return "", false, err
	}
	defer func() { _ = resp.Body.Close() }()
	_, _ = io.Copy(io.Discard, resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", false, fmt.Errorf("status %d", resp.StatusCode)
	}

	finalPath := strings.Trim(resp.Request.URL.Path, "/")
	parts := strings.Split(finalPath, "/")
	if len(parts) < 2 {
		return orgRepo, false, nil
	}
	newRepo := parts[0] + "/" + parts[1]
	if !strings.EqualFold(newRepo, orgRepo) {
		return newRepo, true, nil
	}
	return orgRepo, false, nil
}

func gitCloneOnce(ctx context.Context, cfg config, url, dst string, useFilter, useShallow bool, shallowSince string) (string, error) {
	// Use -c http.followRedirects=true to help git follow GitHub renames/moves (when possible).
	args := []string{"-c", "http.followRedirects=true", "clone", "--bare"}
	if useFilter {
		args = append(args, "--filter=blob:none")
	}
	if useShallow && shallowSince != "" {
		// Shallow options imply --single-branch unless overridden; disable that to keep
		// all branches available for `git log --all`.
		args = append(args, "--no-single-branch")
		args = append(args, "--shallow-since="+shallowSince)
	}
	args = append(args, url, dst)

	env := []string{
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"GIT_LFS_SKIP_SMUDGE=1",
	}
	out, err := runCmd(ctx, env, cfg.gitBinary, args...)
	if err != nil {
		return out, fmt.Errorf("git clone failed: %w; output: %s", err, strings.TrimSpace(out))
	}
	return out, nil
}

func cloneRepo(ctx context.Context, cfg config, repo string, dst string) (resolvedRepo string, usedURL string, err error) {
	type variant struct {
		repo         string
		url          string
		useFilter    bool
		useShallow   bool
		shallowSince string
	}

	baseRepo := strings.TrimSpace(repo)
	baseURL := cloneURLFromRepo(baseRepo)
	if baseURL == "" {
		return "", "", errors.New("empty clone url")
	}

	shallowSince := cfg.from

	buildVariants := func(repoStr, urlStr string) []variant {
		vs := []variant{}
		if shallowSince != "" {
			vs = append(vs,
				variant{repo: repoStr, url: urlStr, useFilter: true, useShallow: true, shallowSince: shallowSince},
				variant{repo: repoStr, url: urlStr, useFilter: false, useShallow: true, shallowSince: shallowSince},
			)
		}
		vs = append(vs,
			variant{repo: repoStr, url: urlStr, useFilter: true, useShallow: false},
			variant{repo: repoStr, url: urlStr, useFilter: false, useShallow: false},
		)
		return vs
	}

	tryVariants := func(vs []variant) (string, string, error) {
		var lastErr error
		var lastOut string
		for _, v := range vs {
			for attempt := 1; attempt <= cfg.cloneRetries; attempt++ {
				if err := resetDir(dst); err != nil {
					return "", "", fmt.Errorf("cannot reset clone dir %s: %w", dst, err)
				}

				cloneCtx, cancel := context.WithTimeout(ctx, cfg.cloneTimeout)
				out, cerr := gitCloneOnce(cloneCtx, cfg, v.url, dst, v.useFilter, v.useShallow, v.shallowSince)
				cancel()

				if cerr == nil {
					if cfg.debug {
						fmt.Printf("clone ok: %s -> %s (filter=%v shallow=%v repo=%s)\n", v.url, dst, v.useFilter, v.useShallow, v.repo)
					}
					return v.repo, v.url, nil
				}
				lastErr = cerr
				lastOut = out

				if ctx.Err() != nil {
					return "", "", ctx.Err()
				}
				if !isTransientGitFailure(out) {
					break
				}
				time.Sleep(time.Duration(attempt) * 2 * time.Second)
			}
		}
		if lastErr == nil {
			lastErr = errors.New("clone failed")
		}
		return "", "", fmt.Errorf("all clone attempts failed for %s (last output: %s): %w", repo, strings.TrimSpace(lastOut), lastErr)
	}

	// 1) Try the repo as-given.
	baseErr := error(nil)
	if r, u, err := tryVariants(buildVariants(baseRepo, baseURL)); err == nil {
		return r, u, nil
	} else {
		baseErr = err
		if !cfg.detectRenames {
			return baseRepo, baseURL, baseErr
		}
	}

	// 2) On failure, try to detect GitHub rename/transfer and retry.
	if newRepo, changed, rerr := resolveGitHubRepo(baseRepo, 20*time.Second); rerr == nil && changed {
		newURL := cloneURLFromRepo(newRepo)
		if newURL != "" {
			if r, u, err := tryVariants(buildVariants(newRepo, newURL)); err == nil {
				return r, u, nil
			}
		}
	}

	// If we got here, return the base error.
	if baseErr == nil {
		baseErr = errors.New("clone failed")
	}
	return baseRepo, baseURL, baseErr
}

func gitFetchAllBranches(ctx context.Context, cfg config, repoDir string) error {
	args := []string{"-C", repoDir, "fetch", "--prune", "origin", "+refs/heads/*:refs/heads/*"}
	env := []string{"GIT_TERMINAL_PROMPT=0"}
	out, err := runCmd(ctx, env, cfg.gitBinary, args...)
	if err != nil {
		return fmt.Errorf("git fetch all branches failed: %w; output: %s", err, strings.TrimSpace(out))
	}
	return nil
}

func gitLogContributors(ctx context.Context, cfg config, repoDir string) (*contributorSet, error) {
	// Record delimiter is double NUL.
	// Fields: sha, author_name, author_email, committer_name, committer_email, message.
	format := "%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B%x00%x00"
	args := []string{"-C", repoDir, "log", "--all", "--no-color", "--pretty=format:" + format}
	if cfg.from != "" {
		args = append(args, "--since="+cfg.from)
	}
	if cfg.to != "" {
		args = append(args, "--until="+cfg.to)
	}

	cmd := exec.CommandContext(ctx, cfg.gitBinary, args...)
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}

	// Capture stderr concurrently.
	var stderrBuf bytes.Buffer
	var stderrWG sync.WaitGroup
	stderrWG.Add(1)
	go func() {
		defer stderrWG.Done()
		_, _ = io.Copy(&stderrBuf, stderr)
	}()

	cs := newContributorSet()
	delim := []byte{0, 0}
	buf := make([]byte, 128*1024)
	pending := make([]byte, 0, 256*1024)

	handleRecord := func(rec []byte) {
		if len(rec) == 0 {
			return
		}
		parts := bytes.Split(rec, []byte{0})
		if len(parts) < 6 {
			return
		}
		cs.commitCount++
		an := string(parts[1])
		ae := string(parts[2])
		cn := string(parts[3])
		ce := string(parts[4])
		msg := string(parts[5])

		cs.add(an, ae)
		cs.add(cn, ce)
		for _, c := range parseTrailerContributors(msg) {
			cs.add(c.Name, c.Email)
		}
	}

	for {
		n, rerr := stdout.Read(buf)
		if n > 0 {
			pending = append(pending, buf[:n]...)
			for {
				idx := bytes.Index(pending, delim)
				if idx < 0 {
					break
				}
				rec := pending[:idx]
				handleRecord(rec)
				pending = pending[idx+len(delim):]
			}
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			_ = cmd.Process.Kill()
			stderrWG.Wait()
			return nil, fmt.Errorf("reading git log stdout: %w (stderr: %s)", rerr, strings.TrimSpace(stderrBuf.String()))
		}
	}
	if len(pending) > 0 {
		handleRecord(pending)
	}

	err = cmd.Wait()
	stderrWG.Wait()
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return nil, fmt.Errorf("git log failed: %w (stderr: %s)", err, strings.TrimSpace(stderrBuf.String()))
	}
	return cs, nil
}

func computeRepoStats(ctx context.Context, cfg config, tmpRoot string, repo string) repoStats {
	st := repoStats{repoInput: repo, repoResolved: repo}

	repoDir := filepath.Join(tmpRoot, sanitizeRepoDirName(repo))
	if !cfg.keepTmp {
		defer func() { _ = os.RemoveAll(repoDir) }()
	}

	if err := resetDir(repoDir); err != nil {
		st.err = fmt.Errorf("cannot create repo dir %s: %w", repoDir, err)
		return st
	}

	repoCtx := ctx
	var cancel context.CancelFunc
	if cfg.repoTimeout > 0 {
		repoCtx, cancel = context.WithTimeout(ctx, cfg.repoTimeout)
		defer cancel()
	}

	resolvedRepo, usedURL, err := cloneRepo(repoCtx, cfg, repo, repoDir)
	if err != nil {
		st.cloneFailed = true
		st.err = err
		return st
	}
	st.repoResolved = resolvedRepo
	if cfg.debug {
		fmt.Printf("cloned %s -> %s (%s)\n", repo, repoDir, usedURL)
	}

	if cfg.fetchAllBranches {
		if err := gitFetchAllBranches(repoCtx, cfg, repoDir); err != nil {
			st.err = err
			return st
		}
	}

	logCtx := repoCtx
	var cancelLog context.CancelFunc
	if cfg.logTimeout > 0 {
		logCtx, cancelLog = context.WithTimeout(repoCtx, cfg.logTimeout)
		defer cancelLog()
	}

	cs, err := gitLogContributors(logCtx, cfg, repoDir)
	if err != nil {
		st.err = err
		return st
	}

	emails := cs.emailsSorted()
	names := cs.namesSorted()
	idents := cs.identsSorted()

	st.emails = emails
	st.names = names
	st.idents = idents
	st.emailCount = len(emails)
	st.commitCount = cs.commitCount
	return st
}

// ---- Row update helpers ----

func parseIntStrict(s string) (int, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, false
	}
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		return 0, false
	}
	return n, true
}

func parseCountField(s string) (int, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, false
	}
	if strings.HasPrefix(s, "=") {
		return parseIntStrict(strings.TrimPrefix(s, "="))
	}
	return parseIntStrict(s)
}

func singleListItem(field string) (string, bool) {
	field = strings.TrimSpace(field)
	if field == "" {
		return "", false
	}
	// Truncation tokens ("=N") are not expandable.
	if strings.HasPrefix(field, "=") {
		return "", false
	}
	var item string
	for _, p := range strings.Split(field, ",") {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if item != "" {
			return "", false
		}
		item = p
	}
	if item == "" {
		return "", false
	}
	return item, true
}

func rowHasAnyAuthors(row []string, authIdx, auth1Idx, auth2Idx, identsIdx int) bool {
	get := func(idx int) string {
		if idx >= 0 && idx < len(row) {
			return strings.TrimSpace(row[idx])
		}
		return ""
	}

	// Any non-empty list field means "has authors" (including "=N" truncation tokens).
	if v := get(authIdx); v != "" && v != "0" {
		return true
	}
	if v := get(auth1Idx); v != "" && v != "0" {
		return true
	}
	if v := get(identsIdx); v != "" && v != "0" && v != "-" {
		return true
	}

	// authors_alt2 is numeric (or "=N"). Treat unparsable-but-non-empty as "present"
	// to avoid accidentally dropping rows with unexpected formatting.
	if v := get(auth2Idx); v != "" {
		if n, ok := parseCountField(v); ok {
			return n > 0
		}
		return true
	}
	return false
}

func countListField(field string) (int, bool) {
	field = strings.TrimSpace(field)
	if field == "" {
		return 0, true
	}
	if strings.HasPrefix(field, "=") {
		return parseIntStrict(strings.TrimPrefix(field, "="))
	}
	parts := strings.Split(field, ",")
	seen := make(map[string]struct{}, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		seen[p] = struct{}{}
	}
	return len(seen), true
}

func formatListOrCount(items []string, maxItems, maxBytes int) string {
	if len(items) == 0 {
		return ""
	}
	if maxItems > 0 && len(items) > maxItems {
		return fmt.Sprintf("=%d", len(items))
	}
	joined := strings.Join(items, ",")
	if maxBytes > 0 && len(joined) > maxBytes {
		return fmt.Sprintf("=%d", len(items))
	}
	return joined
}

func sanitizeUTF8Cell(s string) string {
	if s == "" {
		return s
	}
	// Ruby CSV + UTF-8 readers are unhappy with embedded NULs and invalid sequences.
	s = strings.ReplaceAll(s, "\x00", "")
	if !utf8.ValidString(s) {
		s = strings.ToValidUTF8(s, "\uFFFD")
	}
	return s
}

// reorderColumns reorders columns to match desired order (when present),
// keeping any unknown/extra columns at the end in their original order.
func reorderColumns(t *csvTable, desired []string) {
	if len(t.header) == 0 {
		return
	}
	cur := make(map[string]int, len(t.header))
	for i, h := range t.header {
		cur[strings.ToLower(strings.TrimSpace(h))] = i
	}

	used := make(map[int]bool, len(t.header))
	newHeader := make([]string, 0, len(t.header))
	newOrder := make([]int, 0, len(t.header))

	for _, col := range desired {
		if i, ok := cur[strings.ToLower(strings.TrimSpace(col))]; ok {
			newHeader = append(newHeader, col)
			newOrder = append(newOrder, i)
			used[i] = true
		}
	}
	for i, h := range t.header {
		if used[i] {
			continue
		}
		newHeader = append(newHeader, h)
		newOrder = append(newOrder, i)
	}

	newRows := make([][]string, len(t.rows))
	for r, row := range t.rows {
		nr := make([]string, len(newHeader))
		for j, oldi := range newOrder {
			if oldi >= 0 && oldi < len(row) {
				nr[j] = row[oldi]
			}
		}
		newRows[r] = nr
	}

	t.header = newHeader
	t.rows = newRows
	t.idx = make(map[string]int, len(newHeader))
	for i, h := range newHeader {
		t.idx[strings.ToLower(strings.TrimSpace(h))] = i
	}
}

// ---- Signal handling ----

func installSignalHandler(cancel func()) {
	ch := make(chan os.Signal, 2)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-ch
		cancel()
		<-ch
		os.Exit(1)
	}()
}

// ---- Main ----

func main() {
	cfg := parseFlags()

	input, err := readCSV(cfg.inPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading CSV: %v\n", err)
		os.Exit(1)
	}
	if len(input.rows) == 0 {
		fmt.Fprintf(os.Stderr, "error: input CSV has no data rows\n")
		os.Exit(1)
	}

	repoIdx, err := colIndex(input, "repo")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	authIdx, err := colIndex(input, "authors")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	auth1Idx, err := colIndex(input, "authors_alt1")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	auth2Idx, err := colIndex(input, "authors_alt2")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	// Optional output column: author_idents (unique Name<email> pairs).
	identsIdx := -1
	identsInInput := false
	if ii, err := colIndex(input, "author_idents"); err == nil {
		identsIdx = ii
		identsInInput = true
	} else {
		input.header = append(input.header, "author_idents")
		identsIdx = len(input.header) - 1
		input.idx["author_idents"] = identsIdx
	}

	// commits column is optional (older CSVs may omit it).
	commitsIdx := -1
	if ci, err := colIndex(input, "commits"); err == nil {
		commitsIdx = ci
	} else if !cfg.quiet {
		fmt.Printf("warning: %v (commits column will not be updated)\n", err)
	}

	// Optional: filter out fork repos (remove rows and do not process them).
	var forks map[string]bool
	if strings.TrimSpace(cfg.forksPath) != "" {
		fm, ferr := readForksFile(cfg.forksPath)
		if ferr != nil {
			fmt.Fprintf(os.Stderr, "error reading forks file %s: %v\n", cfg.forksPath, ferr)
			os.Exit(1)
		}
		forks = fm

		filtered := make([][]string, 0, len(input.rows))
		skippedRows := 0
		skippedRepos := make(map[string]struct{})
		for _, row := range input.rows {
			if repoIdx >= len(row) {
				filtered = append(filtered, row)
				continue
			}
			repo := strings.TrimSpace(row[repoIdx])
			key := normalizeForkKey(repo)
			if key != "" && forks[key] {
				skippedRows++
				skippedRepos[key] = struct{}{}
				continue
			}
			filtered = append(filtered, row)
		}
		input.rows = filtered
		if !cfg.quiet {
			fmt.Printf("forks: loaded=%d skippedRows=%d skippedRepos=%d (%s)\n", len(forks), skippedRows, len(skippedRepos), cfg.forksPath)
		}
		if len(input.rows) == 0 {
			fmt.Fprintf(os.Stderr, "error: all rows were filtered out by -forks\n")
			os.Exit(1)
		}
	}

	// Collect distinct repos (and original counts for progress / never-worse preview).
	origAuthorsByRepo := make(map[string]int, len(input.rows))
	origCommitsByRepo := make(map[string]int, len(input.rows))
	repoSet := make(map[string]struct{})
	repos := make([]string, 0, len(input.rows))
	for _, row := range input.rows {
		if repoIdx >= len(row) {
			continue
		}
		repo := strings.TrimSpace(row[repoIdx])
		if repo == "" {
			continue
		}

		// Original author count: authors_alt2 preferred, else authors list.
		origAuthors := 0
		if auth2Idx < len(row) {
			if v, ok := parseCountField(row[auth2Idx]); ok {
				origAuthors = v
			}
		}
		if origAuthors == 0 && authIdx < len(row) {
			if v, ok := countListField(row[authIdx]); ok {
				origAuthors = v
			}
		}
		if prev, ok := origAuthorsByRepo[repo]; !ok || origAuthors > prev {
			origAuthorsByRepo[repo] = origAuthors
		}

		// Original commits count (if column exists).
		if commitsIdx >= 0 && commitsIdx < len(row) {
			origCommits := 0
			if v, ok := parseCountField(row[commitsIdx]); ok {
				origCommits = v
			}
			if prev, ok := origCommitsByRepo[repo]; !ok || origCommits > prev {
				origCommitsByRepo[repo] = origCommits
			}
		}

		if _, ok := repoSet[repo]; ok {
			continue
		}

		repoSet[repo] = struct{}{}
		repos = append(repos, repo)
	}
	sort.Strings(repos)

	// Prepare temp root for clones.
	tmpRoot, err := os.MkdirTemp(cfg.tmpParent, "velocity-enrich-")
	if err != nil {
		fmt.Fprintf(os.Stderr, "error creating temp root under %s: %v\n", cfg.tmpParent, err)
		os.Exit(1)
	}
	if !cfg.keepTmp {
		defer func() { _ = os.RemoveAll(tmpRoot) }()
	}

	if !cfg.quiet {
		fmt.Printf("enrich_authors: input=%s output=%s repos=%d threads=%d tmpRoot=%s\n", cfg.inPath, cfg.outPath, len(repos), cfg.threads, tmpRoot)
		if cfg.from != "" || cfg.to != "" {
			fmt.Printf("date filter: since=%q until=%q (git log)\n", cfg.from, cfg.to)
		}
		fmt.Printf("clone: retries=%d detect-renames=%v fetch-all-branches=%v\n", cfg.cloneRetries, cfg.detectRenames, cfg.fetchAllBranches)
		if cfg.neverWorse {
			fmt.Printf("update policy: never-worse enabled (use -allow-decrease to override)\n")
		}
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	installSignalHandler(cancel)

	// Worker pool.
	jobs := make(chan string)
	resultsCh := make(chan repoStats)

	// Progress counters (updated by workers).
	var processed int64
	var failed int64
	var failedClone int64
	var wouldSkipNeverWorse int64
	var wouldSkipCommitsNeverWorse int64
	var authorsSum int64
	var commitsSum int64

	var progressMu sync.Mutex

	var wg sync.WaitGroup
	wg.Add(cfg.threads)
	for w := 0; w < cfg.threads; w++ {
		workerID := w
		go func() {
			defer wg.Done()
			for repo := range jobs {
				st := computeRepoStats(ctx, cfg, tmpRoot, repo)
				resultsCh <- st
				c := atomic.AddInt64(&processed, 1)

				if st.err != nil {
					atomic.AddInt64(&failed, 1)
					if st.cloneFailed {
						atomic.AddInt64(&failedClone, 1)
					}
				} else {
					atomic.AddInt64(&authorsSum, int64(st.emailCount))
					atomic.AddInt64(&commitsSum, int64(st.commitCount))
					if cfg.neverWorse {
						if orig := origAuthorsByRepo[repo]; orig > 0 && st.emailCount < orig {
							atomic.AddInt64(&wouldSkipNeverWorse, 1)
						}
						if commitsIdx >= 0 {
							if origC := origCommitsByRepo[repo]; origC > 0 && st.commitCount < origC {
								atomic.AddInt64(&wouldSkipCommitsNeverWorse, 1)
							}
						}
					}
				}

				if !cfg.quiet && (c%25 == 0 || c == int64(len(repos))) {
					progressMu.Lock()
					f := atomic.LoadInt64(&failed)
					fc := atomic.LoadInt64(&failedClone)
					nw := atomic.LoadInt64(&wouldSkipNeverWorse)
					nwC := atomic.LoadInt64(&wouldSkipCommitsNeverWorse)
					aSum := atomic.LoadInt64(&authorsSum)
					cSum := atomic.LoadInt64(&commitsSum)
					ok := c - f
					fmt.Printf(
						"progress: %d/%d repos | ok=%d failed=%d (clone=%d other=%d) | never-worse: authors=%d commits=%d | detected: authors(sum)=%d commits(sum)=%d\n",
						c, len(repos), ok, f, fc, f-fc, nw, nwC, aSum, cSum,
					)
					progressMu.Unlock()
				}
				// Always output failures
				// if cfg.debug && st.err != nil {
				if st.err != nil && (cfg.debug || !st.cloneFailed) {
					fmt.Printf("worker %d: repo %s failed: %v\n", workerID, repo, st.err)
				}
			}
		}()
	}

	go func() {
		defer close(jobs)
		for _, repo := range repos {
			select {
			case <-ctx.Done():
				return
			case jobs <- repo:
			}
		}
	}()

	go func() {
		wg.Wait()
		close(resultsCh)
	}()

	resMap := make(map[string]repoStats, len(repos))
	for st := range resultsCh {
		resMap[st.repoInput] = st
	}

	if ctx.Err() != nil {
		fmt.Fprintf(os.Stderr, "interrupted\n")
		os.Exit(1)
	}

	// Update rows.
	updated := 0
	skippedNeverWorse := 0
	failed = 0

	for i, row := range input.rows {
		if repoIdx >= len(row) {
			continue
		}
		repo := strings.TrimSpace(row[repoIdx])
		if repo == "" {
			continue
		}
		st, ok := resMap[repo]
		if !ok {
			continue
		}
		if st.err != nil {
			failed++
			// Input had no author_idents column => in "copy row from input" cases,
			// mark idents as unavailable.
			if !identsInInput && identsIdx >= 0 {
				for len(row) <= identsIdx {
					row = append(row, "")
				}
				row[identsIdx] = "-"
				input.rows[i] = row
			}
			continue
		}

		// Determine original author count (authors_alt2 preferred, else authors field).
		origCount := 0
		if auth2Idx < len(row) {
			if v, ok := parseCountField(row[auth2Idx]); ok {
				origCount = v
			}
		}
		if origCount == 0 && authIdx < len(row) {
			if v, ok := countListField(row[authIdx]); ok {
				origCount = v
			}
		}

		// If the input row was BigQuery-truncated (=N), always replace it with the
		// real expanded list even if never-worse is enabled.
		truncatedList := false
		if cfg.overwriteTruncated {
			if authIdx < len(row) && strings.HasPrefix(strings.TrimSpace(row[authIdx]), "=") {
				truncatedList = true
			}
			if auth1Idx < len(row) && strings.HasPrefix(strings.TrimSpace(row[auth1Idx]), "=") {
				truncatedList = true
			}
		}

		if cfg.neverWorse && !truncatedList && origCount > 0 && st.emailCount < origCount {
			skippedNeverWorse++
			// Input had no author_idents column => in "copy row from input" cases,
			// mark idents as unavailable.
			if !identsInInput && identsIdx >= 0 {
				for len(row) <= identsIdx {
					row = append(row, "")
				}
				row[identsIdx] = "-"
				input.rows[i] = row
			}
			continue
		}

		// Determine original commits count (if column present).
		origCommits := 0
		if commitsIdx >= 0 && commitsIdx < len(row) {
			if v, ok := parseCountField(row[commitsIdx]); ok {
				origCommits = v
			}
		}

		// Ensure row has enough columns.
		maxIdx := authIdx
		if auth1Idx > maxIdx {
			maxIdx = auth1Idx
		}
		if auth2Idx > maxIdx {
			maxIdx = auth2Idx
		}
		if identsIdx > maxIdx {
			maxIdx = identsIdx
		}
		if commitsIdx > maxIdx {
			maxIdx = commitsIdx
		}
		for len(row) <= maxIdx {
			row = append(row, "")
		}

		row[auth2Idx] = strconv.Itoa(st.emailCount)
		row[authIdx] = formatListOrCount(st.emails, cfg.maxListItems, cfg.maxListBytes)
		row[auth1Idx] = formatListOrCount(st.names, cfg.maxListItems, cfg.maxListBytes)
		row[identsIdx] = formatListOrCount(st.idents, cfg.maxListItems, cfg.maxListBytes)

		// Update commits, but (by default) never decrease it.
		if commitsIdx >= 0 {
			if !(cfg.neverWorse && origCommits > 0 && st.commitCount < origCommits) {
				row[commitsIdx] = strconv.Itoa(st.commitCount)
			}
		}

		input.rows[i] = row
		updated++
	}

	if !cfg.quiet {
		fmt.Printf("enrich_authors: updated=%d skipped(never-worse)=%d failed(fallback to original)=%d\n", updated, skippedNeverWorse, failed)
	}

	// Ensure all rows have at least header width (especially after appending author_idents).
	for i, row := range input.rows {
		for len(row) < len(input.header) {
			row = append(row, "")
		}
		input.rows[i] = row
	}

	// If author_idents is empty but we have exactly one author name and one author email,
	// we can safely synthesize the single Name<email> entry without needing git history.
	//
	// This fixes the common case where a row was not updated (never-worse / repo failure)
	// and the input CSV doesn't include author_idents.
	if identsIdx >= 0 && !identsInInput {
		synth := 0
		for i, row := range input.rows {
			if identsIdx >= len(row) || authIdx >= len(row) || auth1Idx >= len(row) {
				continue
			}
			cur := strings.TrimSpace(row[identsIdx])
			if cur != "" && cur != "-" {
				continue
			}
			nameRaw, okN := singleListItem(row[auth1Idx])
			emailRaw, okE := singleListItem(row[authIdx])
			if !okN || !okE {
				continue
			}

			email := normalizeEmail(emailRaw)
			if email == "" {
				continue
			}
			safeName := normalizeName(nameRaw)
			safeName = strings.ReplaceAll(safeName, "<", " ")
			safeName = strings.ReplaceAll(safeName, ">", " ")
			safeName = strings.ReplaceAll(safeName, ",", " ")
			safeName = collapseSpaces(safeName)
			if safeName == "" {
				continue
			}
			// Emails should already be normalized to not contain these; keep it hard-safe.
			if strings.ContainsAny(email, ",<>") {
				continue
			}
			row[identsIdx] = safeName + "<" + email + ">"
			input.rows[i] = row
			synth++
		}
		if !cfg.quiet && synth > 0 {
			fmt.Printf("enrich_authors: synthesized author_idents for %d rows (single name+email)\n", synth)
		}
	}

	// By default, drop rows that have no authors at all (all author-related columns empty/0).
	if !cfg.allowNoAuthorsRepos {
		before := len(input.rows)
		kept := input.rows[:0]
		skipped := 0
		for _, row := range input.rows {
			if !rowHasAnyAuthors(row, authIdx, auth1Idx, auth2Idx, identsIdx) {
				skipped++
				continue
			}
			kept = append(kept, row)
		}
		input.rows = kept
		if !cfg.quiet && skipped > 0 {
			fmt.Printf("enrich_authors: dropped %d/%d rows with no authors (use -allow-no-authors-repos to keep)\n", skipped, before)
		}
	}

	// Sort output by number of authors (desc), then by repo (asc) for stability.
	rowAuthorsCount := func(row []string) int {
		if auth2Idx >= 0 && auth2Idx < len(row) {
			if v, ok := parseCountField(row[auth2Idx]); ok {
				return v
			}
		}
		if authIdx >= 0 && authIdx < len(row) {
			if v, ok := countListField(row[authIdx]); ok {
				return v
			}
		}
		return 0
	}
	sort.SliceStable(input.rows, func(i, j int) bool {
		ai := rowAuthorsCount(input.rows[i])
		aj := rowAuthorsCount(input.rows[j])
		if ai != aj {
			return ai > aj
		}
		ri, rj := "", ""
		if repoIdx >= 0 && repoIdx < len(input.rows[i]) {
			ri = input.rows[i][repoIdx]
		}
		if repoIdx >= 0 && repoIdx < len(input.rows[j]) {
			rj = input.rows[j][repoIdx]
		}
		return strings.ToLower(ri) < strings.ToLower(rj)
	})

	// Force a stable header order for downstream tooling / diffs.
	reorderColumns(&input, []string{
		"org",
		"repo",
		"activity",
		"comments",
		"prs",
		"commits",
		"issues",
		"pushes",
		"authors_alt2",
		"authors_alt1",
		"authors",
		"author_idents",
	})

	if err := writeCSV(cfg.outPath, input); err != nil {
		fmt.Fprintf(os.Stderr, "error writing output CSV: %v\n", err)
		os.Exit(1)
	}
	if !cfg.quiet {
		fmt.Printf("enrich_authors: wrote %s\n", cfg.outPath)
	}
}
