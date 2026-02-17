// enrich_authors.go
//
// A velocity (cncf/velocity) enrichment utility:
//
// - Reads the BigQuery output CSV (org/repo/activity/..., authors_*)
// - For each distinct repo, clones it *temporarily*, scans git history across *ALL refs*
//   (git log --all), and extracts contributors from:
//     * commit Author (name/email)
//     * commit Committer (name/email)
//     * trailers in commit messages (Foo-by: Name <email>, etc)
// - Updates authors/authors_alt1/authors_alt2 columns in the CSV
// - If anything fails for a repo (clone, fetch, log, parse, etc), the original row is preserved
// - "Never worse": if computed author count is lower than original authors_alt2, keep original
//
// Notes:
// - Counts all commits from all branches by using `git log --all` and by explicitly fetching
//   all heads (+refs/heads/*:refs/heads/*) even if user's git config defaults to single-branch.
// - Tries hard to clone: filter clone first, then full clone, retries on transient errors,
//   and (optionally) attempts to detect GitHub renames via HTTPS redirect.
// - Repos are cloned under a temp root directory (printed at start) and each repo dir is
//   removed immediately after it is processed.

package main

import (
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/csv"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// ---- Flags ----

type config struct {
	inPath           string
	outPath          string
	tmpParent        string
	threads          int
	repoTimeout      time.Duration
	cloneTimeout     time.Duration
	maxListItems     int
	debug            bool
	gitBinary        string
	since            string
	until            string
	useHTTPRename    bool
	maxCloneRetries  int
	fetchAllBranches bool
}

func parseFlags() config {
	cfg := config{}
	flag.StringVar(&cfg.inPath, "in", "", "Input CSV path (BigQuery output)")
	flag.StringVar(&cfg.outPath, "out", "", "Output CSV path (default: <in>_enriched.csv)")
	flag.StringVar(&cfg.tmpParent, "tmpdir", "", "Parent directory for temporary clones (default: system temp dir)")
	flag.IntVar(&cfg.threads, "threads", runtime.NumCPU(), "Number of concurrent repo workers")
	flag.DurationVar(&cfg.repoTimeout, "repo-timeout", 45*time.Minute, "Timeout per repo (clone+fetch+log)")
	flag.DurationVar(&cfg.cloneTimeout, "clone-timeout", 15*time.Minute, "Timeout for a single git clone attempt")
	flag.IntVar(&cfg.maxListItems, "max-list-items", 2000, "If computed contributor list has more than this many items, write '=N' instead of full list")
	flag.BoolVar(&cfg.debug, "debug", false, "Verbose logging")
	flag.StringVar(&cfg.gitBinary, "git", "git", "Git binary name/path")
	flag.StringVar(&cfg.since, "since", "", "Optional git log --since (YYYY-MM-DD or any git-parseable date)")
	flag.StringVar(&cfg.until, "until", "", "Optional git log --until (YYYY-MM-DD or any git-parseable date)")
	flag.BoolVar(&cfg.useHTTPRename, "detect-renames", true, "On clone failure, try to detect GitHub renames via HTTPS redirects")
	flag.IntVar(&cfg.maxCloneRetries, "clone-retries", 3, "Max attempts per clone variant (for transient errors)")
	flag.BoolVar(&cfg.fetchAllBranches, "fetch-all-branches", true, "After clone, explicitly fetch all heads (+refs/heads/*:refs/heads/*) to ensure all branches are present")

	flag.Parse()

	if cfg.inPath == "" {
		fmt.Fprintf(os.Stderr, "error: -in is required\n")
		os.Exit(2)
	}
	if cfg.outPath == "" {
		cfg.outPath = strings.TrimSuffix(cfg.inPath, filepath.Ext(cfg.inPath)) + "_enriched.csv"
	}
	if cfg.tmpParent == "" {
		cfg.tmpParent = os.TempDir()
	}
	if cfg.threads < 1 {
		cfg.threads = 1
	}
	if cfg.maxListItems < 0 {
		cfg.maxListItems = 0
	}
	if cfg.maxCloneRetries < 1 {
		cfg.maxCloneRetries = 1
	}

	return cfg
}

// ---- CSV handling ----

type csvTable struct {
	header []string
	rows   [][]string
	idx    map[string]int // lower(header) -> index
}

func readCSV(path string) (csvTable, error) {
	f, err := os.Open(path)
	if err != nil {
		return csvTable{}, err
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	records, err := r.ReadAll()
	if err != nil {
		return csvTable{}, err
	}
	if len(records) == 0 {
		return csvTable{}, errors.New("empty CSV")
	}

	// Heuristic: detect missing header (headless output) and synthesize expected header.
	first := records[0]
	tmpIdx := make(map[string]int, len(first))
	for i, h := range first {
		tmpIdx[strings.ToLower(strings.TrimSpace(h))] = i
	}

	// Expected columns from velocity_standard_query.sql
	expected := []string{"org", "repo", "activity", "comments", "prs", "commits", "issues", "authors_alt2", "authors_alt1", "authors", "pushes"}
	hasHeader := false
	for _, k := range []string{"repo", "authors", "authors_alt2"} {
		if _, ok := tmpIdx[k]; ok {
			hasHeader = true
			break
		}
	}

	var header []string
	var rows [][]string
	if hasHeader {
		header = first
		rows = records[1:]
	} else {
		// No header: treat first record as data and use expected header.
		header = expected
		rows = records
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
	if err := w.Write(t.header); err != nil {
		return err
	}
	for _, row := range t.rows {
		if err := w.Write(row); err != nil {
			return err
		}
	}
	w.Flush()
	return w.Error()
}

func colIndex(t csvTable, name string) (int, error) {
	i, ok := t.idx[strings.ToLower(name)]
	if !ok {
		return -1, fmt.Errorf("missing required column %q", name)
	}
	return i, nil
}

// ---- Git / parsing ----

type repoStats struct {
	repoInput    string
	repoResolved string
	emails       []string
	names        []string
	emailCount   int
	err          error
}

// Trailer line matcher. We intentionally accept a wider set than devstatscode's regex
// to catch underscores and the common unicode en-dash.
var trailerLineRE = regexp.MustCompile(`^(?P<name>[A-Za-z0-9_\-–]+)\:[ \t]+(?P<value>.+)$`)

// Email regex (reasonable heuristic). Used when value isn't strictly "Name <email>".
var emailRE = regexp.MustCompile(`(?i)([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})`)

func sanitizeRepoDirName(repo string) string {
	clean := strings.ToLower(strings.TrimSpace(repo))
	clean = strings.ReplaceAll(clean, "/", "_")
	clean = strings.ReplaceAll(clean, "\\", "_")
	clean = strings.ReplaceAll(clean, " ", "_")

	// Short hash to avoid collisions.
	sum := sha1.Sum([]byte(repo))
	h := fmt.Sprintf("%x", sum[:])
	if len(h) > 10 {
		h = h[:10]
	}
	return fmt.Sprintf("%s-%s", clean, h)
}

func githubCloneURL(repo string) string {
	repo = strings.TrimSpace(repo)
	if repo == "" {
		return ""
	}
	// If input already looks like a URL, keep it.
	if strings.Contains(repo, "://") || strings.HasPrefix(repo, "git@") {
		return repo
	}
	return "https://github.com/" + repo + ".git"
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

func runCmd(ctx context.Context, env []string, name string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = append(os.Environ(), env...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func resetDir(dst string) error {
	_ = os.RemoveAll(dst)
	return os.MkdirAll(dst, 0755)
}

func gitCloneOnce(ctx context.Context, cfg config, url, dst string, useFilter bool) (string, error) {
	// Use -c http.followRedirects=true to help git follow GitHub renames/moves (when possible).
	args := []string{"-c", "http.followRedirects=true", "clone", "--bare"}
	if useFilter {
		// Fetch commits+trees, omit blobs (saves bandwidth/disk for author-only stats).
		args = append(args, "--filter=blob:none")
	}
	// Do NOT use --single-branch; we want all branches.
	args = append(args, url, dst)

	env := []string{
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
	}
	out, err := runCmd(ctx, env, cfg.gitBinary, args...)
	if err != nil {
		return out, fmt.Errorf("git clone failed: %w; output: %s", err, strings.TrimSpace(out))
	}
	return out, nil
}

// resolveGitHubRepo tries to detect a GitHub rename by following redirects on https://github.com/<org>/<repo>.
func resolveGitHubRepo(repo string, timeout time.Duration) (string, bool, error) {
	repo = strings.Trim(repo, " /")
	if repo == "" {
		return "", false, errors.New("empty repo")
	}
	if strings.Contains(repo, "://") || strings.HasPrefix(repo, "git@") {
		// Can't resolve arbitrary URLs.
		return repo, false, nil
	}
	url := "https://github.com/" + repo

	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(url)
	if err != nil {
		return "", false, err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", false, fmt.Errorf("status %d", resp.StatusCode)
	}

	finalPath := strings.Trim(resp.Request.URL.Path, "/")
	parts := strings.Split(finalPath, "/")
	if len(parts) < 2 {
		return "", false, nil
	}
	newRepo := parts[0] + "/" + parts[1]
	if !strings.EqualFold(newRepo, repo) {
		return newRepo, true, nil
	}
	return repo, false, nil
}

func cloneRepo(ctx context.Context, cfg config, repo string, dst string) (resolvedRepo string, usedURL string, err error) {
	type variant struct {
		repo      string
		url       string
		useFilter bool
	}

	baseRepo := strings.TrimSpace(repo)
	baseURL := githubCloneURL(baseRepo)
	if baseURL == "" {
		return "", "", errors.New("empty clone url")
	}

	variants := []variant{
		{repo: baseRepo, url: baseURL, useFilter: true},
		{repo: baseRepo, url: baseURL, useFilter: false},
	}

	// On clone failure, try to detect GitHub rename and retry with resolved repo.
	if cfg.useHTTPRename && !(strings.Contains(baseRepo, "://") || strings.HasPrefix(baseRepo, "git@")) {
		if newRepo, changed, rerr := resolveGitHubRepo(baseRepo, 20*time.Second); rerr == nil && changed {
			newURL := githubCloneURL(newRepo)
			variants = append(variants,
				variant{repo: newRepo, url: newURL, useFilter: true},
				variant{repo: newRepo, url: newURL, useFilter: false},
			)
		}
	}

	var lastErr error
	var lastOut string
	for _, v := range variants {
		for attempt := 1; attempt <= cfg.maxCloneRetries; attempt++ {
			if err := resetDir(dst); err != nil {
				return "", "", fmt.Errorf("cannot reset clone dir %s: %w", dst, err)
			}

			cloneCtx, cancel := context.WithTimeout(ctx, cfg.cloneTimeout)
			out, cerr := gitCloneOnce(cloneCtx, cfg, v.url, dst, v.useFilter)
			cancel()

			if cerr == nil {
				return v.repo, v.url, nil
			}
			lastErr = cerr
			lastOut = out

			if !isTransientGitFailure(out) {
				break
			}
			time.Sleep(time.Duration(attempt) * 2 * time.Second)
		}
	}

	if lastErr == nil {
		lastErr = errors.New("clone failed")
	}
	return baseRepo, baseURL, fmt.Errorf("all clone attempts failed for %s (last output: %s): %w",
		repo, strings.TrimSpace(lastOut), lastErr,
	)
}

// Ensures we have *all* branch heads locally (even if git config defaults to single-branch clones).
func gitFetchAllBranches(ctx context.Context, cfg config, repoDir string) error {
	// For bare repos, cloning normally sets fetch to +refs/heads/*:refs/heads/* already,
	// but this explicit refspec is a guard against single-branch defaults and similar config.
	args := []string{"-C", repoDir, "fetch", "--prune", "origin", "+refs/heads/*:refs/heads/*"}
	env := []string{"GIT_TERMINAL_PROMPT=0"}
	out, err := runCmd(ctx, env, cfg.gitBinary, args...)
	if err != nil {
		return fmt.Errorf("git fetch all branches failed: %w; output: %s", err, strings.TrimSpace(out))
	}
	return nil
}

// contributorSet maintains unique contributors.
type contributorSet struct {
	emails map[string]struct{}
	names  map[string]struct{}
}

func newContributorSet() *contributorSet {
	return &contributorSet{
		emails: make(map[string]struct{}),
		names:  make(map[string]struct{}),
	}
}

func cleanEmail(s string) string {
	s = strings.ReplaceAll(s, "\x00", "")
	s = strings.TrimSpace(s)
	s = strings.Trim(s, "\"'")
	s = strings.ToLower(s)
	return s
}

func cleanName(s string) string {
	s = strings.ReplaceAll(s, "\x00", "")
	s = strings.TrimSpace(s)
	s = strings.Trim(s, "\"'")
	s = strings.ToLower(s)
	return s
}

func (cs *contributorSet) add(name, email string) {
	name = cleanName(name)
	email = cleanEmail(email)
	if email != "" {
		cs.emails[email] = struct{}{}
	}
	if name != "" {
		cs.names[name] = struct{}{}
	}
}

// parseTrailerValue extracts (name,email) from a trailer value.
// Accepts:
// - "Name <email>" (preferred)
// - "<email>"
// - "email" (fallback)
func parseTrailerValue(v string) (name, email string, ok bool) {
	v = strings.TrimSpace(v)
	if v == "" {
		return "", "", false
	}
	v = strings.TrimRight(v, "\r")

	// Name <email>
	if i := strings.Index(v, "<"); i >= 0 {
		j := strings.Index(v[i+1:], ">")
		if j >= 0 {
			em := strings.TrimSpace(v[i+1 : i+1+j])
			nm := strings.TrimSpace(v[:i])
			em = cleanEmail(em)
			nm = cleanName(nm)
			if em != "" {
				return nm, em, true
			}
		}
	}

	// Any email in the value.
	m := emailRE.FindStringSubmatch(v)
	if len(m) >= 2 {
		em := cleanEmail(m[1])
		nm := strings.TrimSpace(strings.Replace(v, m[1], "", 1))
		nm = strings.Trim(nm, "<>[]()\"' ")
		nm = cleanName(nm)
		if em != "" {
			return nm, em, true
		}
	}
	return "", "", false
}

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

func parseTrailersFromMessage(msg string, cs *contributorSet) {
	lines := strings.Split(msg, "\n")
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
		nm, em, ok := parseTrailerValue(value)
		if !ok {
			continue
		}
		cs.add(nm, em)
	}
}

func gitLogContributors(ctx context.Context, cfg config, repoDir string) (*contributorSet, error) {
	// Use NUL separators + double NUL record delimiter.
	// Fields: sha, author_name, author_email, committer_name, committer_email, message
	format := "%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B%x00%x00"
	args := []string{"-C", repoDir, "log", "--all", "--no-color", "--pretty=format:" + format}
	if cfg.since != "" {
		args = append(args, "--since="+cfg.since)
	}
	if cfg.until != "" {
		args = append(args, "--until="+cfg.until)
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
			// Malformed record; ignore.
			return
		}
		an := string(parts[1])
		ae := string(parts[2])
		cn := string(parts[3])
		ce := string(parts[4])
		msg := string(parts[5])

		cs.add(an, ae)
		cs.add(cn, ce)
		parseTrailersFromMessage(msg, cs)
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

	// Handle leftover (shouldn't happen if git ended with delim).
	if len(pending) > 0 {
		handleRecord(pending)
	}

	err = cmd.Wait()
	stderrWG.Wait()
	if err != nil {
		return nil, fmt.Errorf("git log failed: %w (stderr: %s)", err, strings.TrimSpace(stderrBuf.String()))
	}

	return cs, nil
}

func computeRepoStats(cfg config, tmpRoot string, repo string) repoStats {
	st := repoStats{repoInput: repo, repoResolved: repo}

	repoDir := filepath.Join(tmpRoot, sanitizeRepoDirName(repo))
	defer func() { _ = os.RemoveAll(repoDir) }()

	ctx, cancel := context.WithTimeout(context.Background(), cfg.repoTimeout)
	defer cancel()

	resolvedRepo, usedURL, err := cloneRepo(ctx, cfg, repo, repoDir)
	if err != nil {
		st.err = err
		return st
	}
	st.repoResolved = resolvedRepo
	if cfg.debug {
		fmt.Printf("cloned %s -> %s (%s)\n", repo, repoDir, usedURL)
	}

	if cfg.fetchAllBranches {
		if err := gitFetchAllBranches(ctx, cfg, repoDir); err != nil {
			st.err = err
			return st
		}
	}

	cs, err := gitLogContributors(ctx, cfg, repoDir)
	if err != nil {
		st.err = err
		return st
	}

	emails := make([]string, 0, len(cs.emails))
	for e := range cs.emails {
		emails = append(emails, e)
	}
	sort.Strings(emails)

	names := make([]string, 0, len(cs.names))
	for n := range cs.names {
		names = append(names, n)
	}
	sort.Strings(names)

	st.emails = emails
	st.names = names
	st.emailCount = len(emails)
	return st
}

// ---- "never worse" update logic ----

func parseIntSafe(s string) (int, bool) {
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

func countListField(field string) (int, bool) {
	field = strings.TrimSpace(field)
	if field == "" {
		return 0, true
	}
	if strings.HasPrefix(field, "=") {
		return parseIntSafe(strings.TrimPrefix(field, "="))
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

func formatListOrCount(items []string, maxItems int) string {
	if maxItems > 0 && len(items) > maxItems {
		return fmt.Sprintf("=%d", len(items))
	}
	return strings.Join(items, ",")
}

func main() {
	cfg := parseFlags()

	input, err := readCSV(cfg.inPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading CSV: %v\n", err)
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

	// Collect distinct repos.
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
	defer func() { _ = os.RemoveAll(tmpRoot) }()

	fmt.Printf("enrich_authors: input=%s output=%s repos=%d threads=%d tmpRoot=%s\n",
		cfg.inPath, cfg.outPath, len(repos), cfg.threads, tmpRoot,
	)

	// Worker pool.
	jobs := make(chan string)
	resultsCh := make(chan repoStats)

	var doneCount int64
	var wg sync.WaitGroup
	wg.Add(cfg.threads)
	for w := 0; w < cfg.threads; w++ {
		workerID := w
		go func() {
			defer wg.Done()
			for repo := range jobs {
				st := computeRepoStats(cfg, tmpRoot, repo)
				resultsCh <- st

				c := atomic.AddInt64(&doneCount, 1)
				if c%25 == 0 || c == int64(len(repos)) {
					fmt.Printf("progress: %d/%d repos processed\n", c, len(repos))
				}
				if cfg.debug && st.err != nil {
					fmt.Printf("worker %d: repo %s failed: %v\n", workerID, repo, st.err)
				}
			}
		}()
	}

	go func() {
		for _, repo := range repos {
			jobs <- repo
		}
		close(jobs)
		wg.Wait()
		close(resultsCh)
	}()

	// Collect results into map.
	resMap := make(map[string]repoStats, len(repos))
	for st := range resultsCh {
		resMap[st.repoInput] = st
	}

	// Update rows.
	updated := 0
	skipped := 0
	failed := 0

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
			skipped++
			continue
		}
		// If anything failed for the repo, keep original row (fallback).
		if st.err != nil || st.emailCount == 0 {
			failed++
			continue
		}

		// Determine original author count from authors_alt2 if present, else from authors list.
		origAlt2 := 0
		if auth2Idx < len(row) {
			if v, ok := parseIntSafe(row[auth2Idx]); ok {
				origAlt2 = v
			}
		}
		origCount := origAlt2
		if origCount == 0 && authIdx < len(row) {
			if v, ok := countListField(row[authIdx]); ok {
				origCount = v
			}
		}

		// "Never worse": don't replace if computed is smaller.
		if origCount > 0 && st.emailCount < origCount {
			skipped++
			continue
		}

		// Ensure the row has enough columns.
		maxIdx := authIdx
		if auth1Idx > maxIdx {
			maxIdx = auth1Idx
		}
		if auth2Idx > maxIdx {
			maxIdx = auth2Idx
		}
		for len(row) <= maxIdx {
			row = append(row, "")
		}

		// Update the 3 author columns.
		row[auth2Idx] = strconv.Itoa(st.emailCount)
		row[authIdx] = formatListOrCount(st.emails, cfg.maxListItems)
		row[auth1Idx] = formatListOrCount(st.names, cfg.maxListItems)

		input.rows[i] = row
		updated++
	}

	fmt.Printf("enrich_authors: updated=%d skipped(not worse)=%d failed(fallback to original)=%d\n", updated, skipped, failed)

	if err := writeCSV(cfg.outPath, input); err != nil {
		fmt.Fprintf(os.Stderr, "error writing output CSV: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("enrich_authors: wrote %s\n", cfg.outPath)
}

