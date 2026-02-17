package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/csv"
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
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

// enrich_authors.go
//
// A small utility to post-process velocity BigQuery CSV exports and replace
// the `authors` / `authors_alt1` / `authors_alt2` columns with values computed
// from local git history.
//
// For each distinct repo in the input CSV, the tool:
//   1. Clones the repo into a temporary directory (optionally shallow/partial).
//   2. Scans commits in a date range using `git log`.
//   3. Extracts contributor emails from:
//        - commit author (an/ae)
//        - commit committer (cn/ce)
//        - any trailer-like line containing one or more "Name <email>" entries
//          (e.g. Co-authored-by, Signed-off-by, Reviewed-by, Tested-by, etc.)
//   4. Deletes the cloned repo directory.
//   5. Writes an output CSV identical to input, except updated authors columns.
//
// The output is intended to be compatible with velocity's analysis.rb, which
// expects a header row and uses `authors` as a comma-separated list.

const gitExecDefault = "git"

var defaultHeader = []string{
	"org",
	"repo",
	"activity",
	"comments",
	"prs",
	"commits",
	"issues",
	"authors_alt2",
	"authors_alt1",
	"authors",
	"pushes",
}

// contributorSet tracks unique contributors by email, and a best-effort name.
// Email is treated as the identity key (lowercased).
// Names are deduped case-insensitively.
//
// NOTE: Some people use multiple emails; they will count as multiple identities.
// That is consistent with the original BigQuery query (distinct on email).
type contributorSet struct {
	emails map[string]string    // email -> display name (may be empty)
	names  map[string]string    // lower(name) -> original name
	mu     sync.Mutex          // protects both maps
	seen   map[string]struct{} // emails fast-path
}

func newContributorSet() *contributorSet {
	return &contributorSet{
		emails: make(map[string]string),
		names:  make(map[string]string),
		seen:   make(map[string]struct{}),
	}
}

func normalizeEmail(email string) string {
	email = strings.TrimSpace(email)
	email = strings.Trim(email, "<>")
	email = strings.TrimSpace(email)
	email = strings.ToLower(email)
	// Basic sanity: require '@' and no spaces.
	if email == "" || !strings.Contains(email, "@") || strings.ContainsAny(email, " \t\n\r") {
		return ""
	}
	return email
}

func normalizeName(name string) string {
	name = strings.TrimSpace(name)
	name = strings.Trim(name, "\"'")
	name = strings.TrimSpace(name)
	if name == "" {
		return ""
	}
	return name
}

func (cs *contributorSet) add(name, email string) {
	emailN := normalizeEmail(email)
	if emailN == "" {
		return
	}
	nameN := normalizeName(name)
	nameKey := strings.ToLower(nameN)

	cs.mu.Lock()
	defer cs.mu.Unlock()

	if _, ok := cs.seen[emailN]; !ok {
		cs.seen[emailN] = struct{}{}
		cs.emails[emailN] = nameN
	} else if cs.emails[emailN] == "" && nameN != "" {
		cs.emails[emailN] = nameN
	}

	if nameN != "" {
		if _, ok := cs.names[nameKey]; !ok {
			cs.names[nameKey] = nameN
		}
	}
}

func (cs *contributorSet) emailsSorted() []string {
	cs.mu.Lock()
	defer cs.mu.Unlock()
	out := make([]string, 0, len(cs.emails))
	for e := range cs.emails {
		out = append(out, e)
	}
	sort.Strings(out)
	return out
}

func (cs *contributorSet) namesSorted() []string {
	cs.mu.Lock()
	defer cs.mu.Unlock()
	out := make([]string, 0, len(cs.names))
	for _, n := range cs.names {
		out = append(out, n)
	}
	sort.Strings(out)
	return out
}

// repoStats is the per-repo enrichment result.
type repoStats struct {
	RepoRequested string
	RepoResolved  string
	AuthorsEmails []string
	AuthorsNames  []string
	AuthorsCount  int
	Err           error
}

type options struct {
	inPath       string
	outPath      string
	fromDate     string // git-friendly YYYY-MM-DD
	toDate       string // git-friendly YYYY-MM-DD (treated as exclusive day boundary when passed as YYYY-MM-DD)
	threads      int
	tmpBase      string
	keepTmp      bool
	gitExec      string
	cloneTimeout time.Duration
	logTimeout   time.Duration
	maxListBytes int
	quiet        bool
	debug        bool
}

func parseDateArg(s string) (string, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", nil
	}
	// Accept YYYYMMDD.
	if len(s) == 8 && strings.IndexFunc(s, func(r rune) bool { return r < '0' || r > '9' }) == -1 {
		y := s[0:4]
		m := s[4:6]
		d := s[6:8]
		return fmt.Sprintf("%s-%s-%s", y, m, d), nil
	}
	// Accept YYYY-MM-DD.
	if len(s) == 10 {
		parts := strings.Split(s, "-")
		if len(parts) == 3 && len(parts[0]) == 4 && len(parts[1]) == 2 && len(parts[2]) == 2 {
			return s, nil
		}
	}
	return "", fmt.Errorf("unsupported date format %q (use YYYYMMDD or YYYY-MM-DD)", s)
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

func colIndex(header []string, name string) int {
	name = strings.ToLower(strings.TrimSpace(name))
	for i, h := range header {
		if strings.ToLower(strings.TrimSpace(h)) == name {
			return i
		}
	}
	return -1
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	var opt options

	flag.StringVar(&opt.inPath, "in", "", "Input CSV file (BigQuery export)")
	flag.StringVar(&opt.outPath, "out", "", "Output CSV file (enriched)")
	var fromArg, toArg string
	flag.StringVar(&fromArg, "from", "", "Start date (inclusive), YYYYMMDD or YYYY-MM-DD; optional")
	flag.StringVar(&toArg, "to", "", "End date (exclusive day boundary), YYYYMMDD or YYYY-MM-DD; optional (use same dtto as BigQuery)")
	flag.IntVar(&opt.threads, "threads", runtime.NumCPU(), "Number of parallel workers (default: NumCPU)")
	flag.StringVar(&opt.tmpBase, "tmp", "", "Base temp directory (default: OS temp)")
	flag.BoolVar(&opt.keepTmp, "keep-tmp", false, "Keep cloned repos on disk (debug)")
	flag.StringVar(&opt.gitExec, "git", gitExecDefault, "Git executable")
	flag.DurationVar(&opt.cloneTimeout, "clone-timeout", 30*time.Minute, "Per-repo clone timeout")
	flag.DurationVar(&opt.logTimeout, "log-timeout", 30*time.Minute, "Per-repo git log timeout")
	flag.IntVar(&opt.maxListBytes, "max-list-bytes", 0, "If >0, replace authors/authors_alt1 with '=N' when the comma-joined list exceeds this many bytes")
	flag.BoolVar(&opt.quiet, "quiet", false, "Less logging")
	flag.BoolVar(&opt.debug, "debug", false, "Verbose logging")
	flag.Parse()

	if opt.inPath == "" || opt.outPath == "" {
		fmt.Fprintf(os.Stderr, "Usage: %s -in input.csv -out output.csv [-from YYYYMMDD] [-to YYYYMMDD]\n", os.Args[0])
		flag.PrintDefaults()
		return errors.New("missing required -in or -out")
	}

	var err error
	opt.fromDate, err = parseDateArg(fromArg)
	if err != nil {
		return fmt.Errorf("invalid -from: %w", err)
	}
	opt.toDate, err = parseDateArg(toArg)
	if err != nil {
		return fmt.Errorf("invalid -to: %w", err)
	}

	header, rows, err := readCSV(opt.inPath)
	if err != nil {
		return fmt.Errorf("read input CSV: %w", err)
	}
	if len(rows) == 0 {
		return errors.New("input CSV has no data rows")
	}

	repoIdx := colIndex(header, "repo")
	if repoIdx < 0 {
		return errors.New("input CSV missing 'repo' column")
	}
	authIdx := colIndex(header, "authors")
	authAlt1Idx := colIndex(header, "authors_alt1")
	authAlt2Idx := colIndex(header, "authors_alt2")
	if authIdx < 0 || authAlt1Idx < 0 || authAlt2Idx < 0 {
		return errors.New("input CSV missing one of required columns: authors/authors_alt1/authors_alt2")
	}

	uniqueRepos := make([]string, 0, 1024)
	repoSet := make(map[string]struct{})
	for _, row := range rows {
		if repoIdx >= len(row) {
			continue
		}
		repo := strings.TrimSpace(row[repoIdx])
		if repo == "" {
			continue
		}
		if _, ok := repoSet[repo]; ok {
			continue
		}
		repoSet[repo] = struct{}{}
		uniqueRepos = append(uniqueRepos, repo)
	}
	sort.Strings(uniqueRepos)

	if opt.threads < 1 {
		opt.threads = 1
	}

	baseTmpDir, err := os.MkdirTemp(opt.tmpBase, "velocity-enrich-")
	if err != nil {
		return fmt.Errorf("create temp base dir: %w", err)
	}
	if !opt.keepTmp {
		defer func() { _ = os.RemoveAll(baseTmpDir) }()
	}

	if !opt.quiet {
		fmt.Printf("Temp base directory: %s\n", baseTmpDir)
		fmt.Printf("Distinct repos to process: %d\n", len(uniqueRepos))
		if opt.fromDate != "" || opt.toDate != "" {
			fmt.Printf("Commit date filter (git log): from=%q to=%q (committer date)\n", opt.fromDate, opt.toDate)
		}
		fmt.Printf("Threads: %d\n", opt.threads)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	installSignalHandler(cancel)

	results := make(map[string]repoStats, len(uniqueRepos))
	var resultsMu sync.Mutex

	var processed int64
	var failures int64

	repoCh := make(chan string)
	wg := sync.WaitGroup{}

	for i := 0; i < opt.threads; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for repo := range repoCh {
				st := processRepo(ctx, repo, baseTmpDir, opt)
				resultsMu.Lock()
				results[repo] = st
				resultsMu.Unlock()

				newN := atomic.AddInt64(&processed, 1)
				if st.Err != nil {
					atomic.AddInt64(&failures, 1)
				}

				if !opt.quiet {
					if newN%25 == 0 || newN == int64(len(uniqueRepos)) {
						fmt.Printf("Progress: %d/%d repos processed (failures: %d)\n", newN, len(uniqueRepos), atomic.LoadInt64(&failures))
					}
				}
			}
		}(i)
	}

	// Producer.
	go func() {
		defer close(repoCh)
		for _, repo := range uniqueRepos {
			select {
			case <-ctx.Done():
				return
			case repoCh <- repo:
			}
		}
	}()

	wg.Wait()

	if ctx.Err() != nil {
		return errors.New("interrupted")
	}

	// Update rows.
	updated := 0
	for i, row := range rows {
		if repoIdx >= len(row) {
			continue
		}
		repo := strings.TrimSpace(row[repoIdx])
		st, ok := results[repo]
		if !ok {
			continue
		}
		if st.Err != nil {
			if opt.debug {
				fmt.Fprintf(os.Stderr, "WARN: repo %s: enrichment failed: %v\n", repo, st.Err)
			}
			continue
		}

		authStr := joinOrCount(st.AuthorsEmails, opt.maxListBytes)
		nameStr := joinOrCount(st.AuthorsNames, opt.maxListBytes)
		countStr := strconv.Itoa(st.AuthorsCount)

		// Ensure row has enough columns.
		need := max(authIdx, max(authAlt1Idx, authAlt2Idx)) + 1
		if len(row) < need {
			newRow := make([]string, need)
			copy(newRow, row)
			row = newRow
			rows[i] = row
		}

		row[authIdx] = authStr
		row[authAlt1Idx] = nameStr
		row[authAlt2Idx] = countStr
		updated++
	}

	if err := writeCSV(opt.outPath, header, rows); err != nil {
		return fmt.Errorf("write output CSV: %w", err)
	}

	if !opt.quiet {
		fmt.Printf("Wrote %s (updated %d/%d rows)\n", opt.outPath, updated, len(rows))
		if failures > 0 {
			fmt.Printf("WARNING: %d repos failed to enrich; rows for those repos were left unchanged.\n", failures)
		}
	}
	return nil
}

func installSignalHandler(cancel func()) {
	ch := make(chan os.Signal, 2)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-ch
		cancel()
		// If a second signal arrives, exit immediately.
		<-ch
		os.Exit(1)
	}()
}

func joinOrCount(items []string, maxBytes int) string {
	if len(items) == 0 {
		return ""
	}
	joined := strings.Join(items, ",")
	if maxBytes > 0 && len(joined) > maxBytes {
		return fmt.Sprintf("=%d", len(items))
	}
	return joined
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func readCSV(path string) (header []string, rows [][]string, err error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	defer func() { _ = f.Close() }()

	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	r.ReuseRecord = false

	first, err := r.Read()
	if err != nil {
		return nil, nil, err
	}
	// Strip UTF-8 BOM if present.
	if len(first) > 0 {
		first[0] = strings.TrimPrefix(first[0], "\ufeff")
	}

	if isHeaderRow(first) {
		header = first
	} else {
		header = append([]string{}, defaultHeader...)
		rows = append(rows, first)
	}

	for {
		rec, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, nil, err
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
	return header, rows, nil
}

func writeCSV(path string, header []string, rows [][]string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()

	w := csv.NewWriter(f)
	// Always write header row (analysis.rb expects it).
	if err := w.Write(header); err != nil {
		return err
	}
	for _, row := range rows {
		if err := w.Write(row); err != nil {
			return err
		}
	}
	w.Flush()
	return w.Error()
}

func processRepo(ctx context.Context, repo string, baseTmpDir string, opt options) repoStats {
	st := repoStats{RepoRequested: repo, RepoResolved: repo}

	workDir, err := os.MkdirTemp(baseTmpDir, "repo-")
	if err != nil {
		st.Err = fmt.Errorf("create repo temp dir: %w", err)
		return st
	}
	if !opt.keepTmp {
		defer func() { _ = os.RemoveAll(workDir) }()
	}
	cloneDir := filepath.Join(workDir, "clone")

	resolvedRepo := repo
	cloneURL := repoToGitHubURL(resolvedRepo)

	cloneCtx, cancel := context.WithTimeout(ctx, opt.cloneTimeout)
	defer cancel()

	cloneErr := cloneRepo(cloneCtx, opt.gitExec, cloneURL, cloneDir, opt.fromDate, opt.debug)
	if cloneErr != nil {
		// If this looks like a GitHub rename/transfer, try resolving redirect.
		if newRepo, ok := tryResolveGitHubRedirect(repo); ok {
			resolvedRepo = newRepo
			st.RepoResolved = resolvedRepo
			cloneURL = repoToGitHubURL(resolvedRepo)
			cloneErr = cloneRepo(cloneCtx, opt.gitExec, cloneURL, cloneDir, opt.fromDate, opt.debug)
		}
	}
	if cloneErr != nil {
		st.Err = fmt.Errorf("clone %s: %w", repo, cloneErr)
		return st
	}

	logCtx, cancel2 := context.WithTimeout(ctx, opt.logTimeout)
	defer cancel2()

	cs := newContributorSet()
	if err := scanGitLog(logCtx, opt.gitExec, cloneDir, opt.fromDate, opt.toDate, cs, opt.debug); err != nil {
		st.Err = fmt.Errorf("git log %s: %w", repo, err)
		return st
	}

	emails := cs.emailsSorted()
	names := cs.namesSorted()

	st.AuthorsEmails = emails
	st.AuthorsNames = names
	st.AuthorsCount = len(emails)
	return st
}

func repoToGitHubURL(repo string) string {
	repo = strings.TrimSpace(repo)
	repo = strings.TrimPrefix(repo, "https://github.com/")
	repo = strings.TrimSuffix(repo, ".git")
	repo = strings.Trim(repo, "/")
	return "https://github.com/" + repo + ".git"
}

func cloneRepo(ctx context.Context, gitExec, url, dir, shallowSince string, debug bool) error {
	baseEnv := append(os.Environ(), "GIT_TERMINAL_PROMPT=0", "GIT_LFS_SKIP_SMUDGE=1")

	candidates := [][]string{}

	if shallowSince != "" {
		candidates = append(candidates, []string{"clone", "--filter=blob:none", "--no-checkout", "--shallow-since=" + shallowSince, url, dir})
		candidates = append(candidates, []string{"clone", "--no-checkout", "--shallow-since=" + shallowSince, url, dir})
	}
	candidates = append(candidates, []string{"clone", "--filter=blob:none", "--no-checkout", url, dir})
	candidates = append(candidates, []string{"clone", "--no-checkout", url, dir})
	candidates = append(candidates, []string{"clone", url, dir})

	var lastErr error
	for _, args := range candidates {
		_ = os.RemoveAll(dir)

		cmd := exec.CommandContext(ctx, gitExec, args...)
		cmd.Env = baseEnv
		out, err := cmd.CombinedOutput()
		if err == nil {
			if debug {
				fmt.Printf("clone ok: %s -> %s (args: %v)\n", url, dir, args)
			}
			return nil
		}
		lastErr = fmt.Errorf("%v: %w: %s", args, err, strings.TrimSpace(string(out)))
		if debug {
			fmt.Fprintf(os.Stderr, "clone attempt failed: %v\n", lastErr)
		}
		if ctx.Err() != nil {
			return ctx.Err()
		}
	}
	if lastErr == nil {
		lastErr = errors.New("unknown clone error")
	}
	return lastErr
}

// scanGitLog runs git log and streams its output to extract contributors.
//
// It relies on the same -z + NUL-separated format pattern used by devstats' git_commits.sh.
func scanGitLog(ctx context.Context, gitExec, repoDir, fromDate, toDate string, cs *contributorSet, debug bool) error {
	args := []string{"-C", repoDir, "log", "-z", "--all"}
	if fromDate != "" {
		args = append(args, "--since="+fromDate)
	}
	if toDate != "" {
		args = append(args, "--until="+toDate)
	}
	args = append(args, "--format=%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B")

	cmd := exec.CommandContext(ctx, gitExec, args...)
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0")

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	errBuf := &bytes.Buffer{}
	errDone := make(chan struct{})
	go func() {
		defer close(errDone)
		_, _ = io.Copy(errBuf, stderr)
	}()

	r := bufio.NewReaderSize(stdout, 1024*1024)

	readField := func() (string, error) {
		b, err := r.ReadBytes(0)
		if len(b) > 0 && b[len(b)-1] == 0 {
			b = b[:len(b)-1]
		}
		if err != nil {
			if errors.Is(err, io.EOF) && len(b) > 0 {
				return string(b), io.EOF
			}
			return string(b), err
		}
		return string(b), nil
	}

	for {
		sha, err := readField()
		if err != nil {
			if errors.Is(err, io.EOF) && sha == "" {
				break
			}
			break
		}
		if sha == "" {
			continue
		}

		an, err := readField()
		if err != nil {
			break
		}
		ae, err := readField()
		if err != nil {
			break
		}
		cn, err := readField()
		if err != nil {
			break
		}
		ce, err := readField()
		if err != nil {
			break
		}
		msg, err := readField()
		if err != nil {
			if !errors.Is(err, io.EOF) {
				break
			}
		}

		_ = sha // reserved
		cs.add(an, ae)
		cs.add(cn, ce)
		for _, c := range parseTrailerContributors(msg) {
			cs.add(c.Name, c.Email)
		}

		if errors.Is(err, io.EOF) {
			break
		}
	}

	waitErr := cmd.Wait()
	<-errDone

	if waitErr != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		st := strings.TrimSpace(errBuf.String())
		if st != "" {
			return fmt.Errorf("%w: %s", waitErr, st)
		}
		return waitErr
	}

	if debug {
		st := strings.TrimSpace(errBuf.String())
		if st != "" {
			fmt.Fprintf(os.Stderr, "git log stderr (%s): %s\n", repoDir, st)
		}
	}

	return nil
}

type trailerContributor struct {
	Name  string
	Email string
}

// parseTrailerContributors scans a commit message and extracts contributors from
// trailer-like lines.
//
// This deliberately does NOT depend on a fixed allowlist; it extracts all
// occurrences of "Name <email>" from any line that looks like "Key: Value".
func parseTrailerContributors(msg string) []trailerContributor {
	lines := strings.Split(msg, "\n")
	out := make([]trailerContributor, 0, 4)
	for _, l := range lines {
		l = strings.TrimSpace(strings.TrimRight(l, "\r"))
		if l == "" {
			continue
		}
		// Quick reject: must contain ':' and '<' and '>' and '@'.
		if !strings.Contains(l, ":") || !strings.Contains(l, "<") || !strings.Contains(l, ">") || !strings.Contains(l, "@") {
			continue
		}
		idx := strings.Index(l, ":")
		if idx <= 0 {
			continue
		}
		value := strings.TrimSpace(l[idx+1:])
		if value == "" {
			continue
		}

		for _, c := range extractAllNameEmail(value) {
			out = append(out, c)
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
		name = strings.Trim(name, "\t \"'()[]{}")
		email = strings.Trim(email, "\t \"'()[]{}")

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

// tryResolveGitHubRedirect attempts to resolve github.com/<owner>/<repo> redirects
// (renames / transfers) without requiring authentication.
//
// It returns (newRepo, true) on a plausible redirect, or ("", false) otherwise.
func tryResolveGitHubRedirect(repo string) (string, bool) {
	repo = strings.TrimSpace(repo)
	if repo == "" {
		return "", false
	}

	parts := strings.Split(strings.Trim(repo, "/"), "/")
	if len(parts) < 2 {
		return "", false
	}

	u := "https://github.com/" + parts[0] + "/" + parts[1]
	client := &http.Client{
		Timeout: 10 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	req, err := http.NewRequest("HEAD", u, nil)
	if err != nil {
		return "", false
	}
	req.Header.Set("User-Agent", "velocity-enrich-authors")
	resp, err := client.Do(req)
	if err != nil {
		return "", false
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode < 300 || resp.StatusCode >= 400 {
		return "", false
	}
	loc := resp.Header.Get("Location")
	if loc == "" {
		return "", false
	}

	locURL, err := url.Parse(loc)
	if err != nil {
		return "", false
	}
	if !locURL.IsAbs() {
		base, _ := url.Parse("https://github.com")
		locURL = base.ResolveReference(locURL)
	}
	if !strings.EqualFold(locURL.Hostname(), "github.com") {
		return "", false
	}

	pathParts := strings.Split(strings.Trim(locURL.Path, "/"), "/")
	if len(pathParts) < 2 {
		return "", false
	}
	newRepo := pathParts[0] + "/" + pathParts[1]
	if strings.EqualFold(newRepo, parts[0]+"/"+parts[1]) {
		return "", false
	}
	return newRepo, true
}

