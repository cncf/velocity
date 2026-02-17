package main

import (
	"bufio"
	"context"
	"encoding/csv"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// Enrich a velocity BigQuery CSV by replacing the `authors` column with
// contributor emails extracted from local git history (author, committer,
// and any <email> occurrences in commit message trailers).
//
// This intentionally avoids external dependencies.

var (
	emailAngleRe = regexp.MustCompile(`(?i)<([^<>@\s]+@[^<>\s>]+)>`)
)

type config struct {
	inPath             string
	outPath            string
	since              string
	until              string
	workers            int
	tmpDir             string
	cloneURLFormat     string
	gitBin             string
	shallowSince       bool
	keepRepo           bool
	verbose            bool
	updateAuthorsAlt2  bool
	maxAuthorsListByte int
	cloneTimeout       time.Duration
	logTimeout         time.Duration
}

type csvFile struct {
	header    []string
	rows      [][]string
	repoIdx   int
	authIdx   int
	auth2Idx  int
	hasHeader bool
}

type repoResult struct {
	repo   string
	emails []string
	err    error
}

func main() {
	var cfg config
	flag.StringVar(&cfg.inPath, "in", "", "Input CSV path (BigQuery output)")
	flag.StringVar(&cfg.outPath, "out", "", "Output CSV path (authors replaced)")
	flag.StringVar(&cfg.since, "since", "", "Git commit date lower bound (YYYY-MM-DD or YYYYMMDD). Uses committer date.")
	flag.StringVar(&cfg.until, "until", "", "Git commit date upper bound (YYYY-MM-DD or YYYYMMDD). Uses committer date.")
	flag.IntVar(&cfg.workers, "workers", runtime.NumCPU(), "Concurrent workers (clones/log scans)")
	flag.StringVar(&cfg.tmpDir, "tmpdir", os.TempDir(), "Base temp dir for clones")
	flag.StringVar(&cfg.cloneURLFormat, "clone-url-format", "https://github.com/%s.git", "Clone URL format; repo name is substituted via fmt.Sprintf")
	flag.StringVar(&cfg.gitBin, "git", "git", "Path to git binary")
	flag.BoolVar(&cfg.shallowSince, "shallow-since", true, "If --since is set, use git clone --shallow-since to limit history")
	flag.BoolVar(&cfg.keepRepo, "keep", false, "Do not delete temporary clone directories")
	flag.BoolVar(&cfg.verbose, "v", false, "Verbose logging")
	flag.BoolVar(&cfg.updateAuthorsAlt2, "update-authors-alt2", false, "If true and authors_alt2 column exists, update it to the computed distinct email count")
	flag.IntVar(&cfg.maxAuthorsListByte, "max-authors-bytes", 0, "If >0 and authors list would exceed this byte size, write authors as =N (count) instead")
	flag.DurationVar(&cfg.cloneTimeout, "clone-timeout", 30*time.Minute, "Per-repo clone timeout")
	flag.DurationVar(&cfg.logTimeout, "log-timeout", 30*time.Minute, "Per-repo git log timeout")
	flag.Parse()

	if cfg.inPath == "" || cfg.outPath == "" {
		fatalf("-in and -out are required")
	}
	if cfg.workers <= 0 {
		fatalf("-workers must be > 0")
	}

	cfg.since = normalizeGitDate(cfg.since)
	cfg.until = normalizeGitDate(cfg.until)
	if cfg.until != "" && cfg.since != "" {
		// Best-effort sanity check (lex works for YYYY-MM-DD).
		if len(cfg.since) == 10 && len(cfg.until) == 10 && cfg.until < cfg.since {
			fatalf("-until (%s) is before -since (%s)", cfg.until, cfg.since)
		}
	}

	cf, err := readCSV(cfg.inPath)
	if err != nil {
		fatalf("read CSV: %v", err)
	}
	if cfg.verbose {
		logf("CSV: %d rows, repoIdx=%d authorsIdx=%d (hasHeader=%v)", len(cf.rows), cf.repoIdx, cf.authIdx, cf.hasHeader)
	}

	repos := uniqueRepos(cf.rows, cf.repoIdx)
	if len(repos) == 0 {
		fatalf("no repos found in %s", cfg.inPath)
	}
	logf("Found %d unique repos", len(repos))

	results := make(map[string]repoResult, len(repos))
	var resMu sync.Mutex

	jobs := make(chan string)
	var doneCount int64
	var errCount int64

	ctx := context.Background()
	var wg sync.WaitGroup
	for i := 0; i < cfg.workers; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			for repo := range jobs {
				emails, err := processRepo(ctx, cfg, repo)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					logf("ERROR repo=%s: %v", repo, err)
				} else if cfg.verbose {
					logf("repo=%s contributors=%d", repo, len(emails))
				}
				resMu.Lock()
				results[repo] = repoResult{repo: repo, emails: emails, err: err}
				resMu.Unlock()
				n := atomic.AddInt64(&doneCount, 1)
				if n%100 == 0 || n == int64(len(repos)) {
					logf("progress %d/%d (errors=%d)", n, len(repos), atomic.LoadInt64(&errCount))
				}
			}
		}(i)
	}

	go func() {
		for _, repo := range repos {
			jobs <- repo
		}
		close(jobs)
	}()

	wg.Wait()
	logf("Completed repos=%d errors=%d", len(repos), atomic.LoadInt64(&errCount))

	// Apply results back to rows.
	updated := 0
	for _, row := range cf.rows {
		if cf.repoIdx < 0 || cf.repoIdx >= len(row) {
			continue
		}
		repo := strings.TrimSpace(row[cf.repoIdx])
		if repo == "" {
			continue
		}
		res, ok := results[repo]
		if !ok {
			continue
		}
		if res.err != nil {
			// Keep original authors value on error.
			continue
		}
		authorsVal := strings.Join(res.emails, ",")
		if cfg.maxAuthorsListByte > 0 && len(authorsVal) > cfg.maxAuthorsListByte {
			authorsVal = fmt.Sprintf("=%d", len(res.emails))
		}
		if cf.authIdx >= 0 && cf.authIdx < len(row) {
			row[cf.authIdx] = authorsVal
			updated++
		}
		if cfg.updateAuthorsAlt2 && cf.auth2Idx >= 0 && cf.auth2Idx < len(row) {
			row[cf.auth2Idx] = fmt.Sprintf("%d", len(res.emails))
		}
	}
	logf("Updated %d/%d rows", updated, len(cf.rows))

	if err := writeCSV(cfg.outPath, cf); err != nil {
		fatalf("write CSV: %v", err)
	}
	logf("Wrote %s", cfg.outPath)
}

func normalizeGitDate(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	// YYYYMMDD -> YYYY-MM-DD
	if len(s) == 8 {
		isDigits := true
		for _, r := range s {
			if r < '0' || r > '9' {
				isDigits = false
				break
			}
		}
		if isDigits {
			return fmt.Sprintf("%s-%s-%s", s[0:4], s[4:6], s[6:8])
		}
	}
	return s
}

func readCSV(path string) (*csvFile, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	records, err := r.ReadAll()
	if err != nil {
		return nil, err
	}
	if len(records) == 0 {
		return nil, errors.New("empty CSV")
	}

	cf := &csvFile{}
	first := records[0]
	cf.hasHeader = looksLikeHeader(first)
	if cf.hasHeader {
		cf.header = first
		cf.rows = records[1:]
	} else {
		// BigQuery output should have headers, but be defensive.
		cf.header = defaultHeader(len(first))
		cf.rows = records
	}

	cf.repoIdx = findHeaderIdx(cf.header, "repo")
	cf.authIdx = findHeaderIdx(cf.header, "authors")
	cf.auth2Idx = findHeaderIdx(cf.header, "authors_alt2")

	// If header missing (headless CSV) fall back to known column order.
	if cf.repoIdx < 0 || cf.authIdx < 0 {
		if !cf.hasHeader {
			// Expected: org,repo,activity,comments,prs,commits,issues,authors_alt2,authors_alt1,authors,pushes
			if len(cf.header) >= 10 {
				cf.repoIdx = 1
				cf.authIdx = 9
				if len(cf.header) >= 8 {
					cf.auth2Idx = 7
				}
			}
		}
	}

	if cf.repoIdx < 0 {
		return nil, fmt.Errorf("cannot find 'repo' column")
	}
	if cf.authIdx < 0 {
		return nil, fmt.Errorf("cannot find 'authors' column")
	}

	return cf, nil
}

func writeCSV(path string, cf *csvFile) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		// If path has no directory component, MkdirAll(".") is fine.
		if filepath.Dir(path) != "." {
			return err
		}
	}

	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	w := csv.NewWriter(f)
	if cf.hasHeader {
		if err := w.Write(cf.header); err != nil {
			return err
		}
	}
	for _, row := range cf.rows {
		if err := w.Write(row); err != nil {
			return err
		}
	}
	w.Flush()
	return w.Error()
}

func looksLikeHeader(rec []string) bool {
	if len(rec) == 0 {
		return false
	}
	hit := 0
	for _, v := range rec {
		v = strings.ToLower(strings.TrimSpace(v))
		switch v {
		case "repo", "org", "authors", "commits", "activity":
			hit++
		}
	}
	return hit >= 2
}

func defaultHeader(n int) []string {
	// Best-effort fallback.
	def := []string{"org", "repo", "activity", "comments", "prs", "commits", "issues", "authors_alt2", "authors_alt1", "authors", "pushes"}
	if n <= len(def) {
		return def[:n]
	}
	out := make([]string, 0, n)
	out = append(out, def...)
	for i := len(def); i < n; i++ {
		out = append(out, fmt.Sprintf("col_%d", i))
	}
	return out
}

func findHeaderIdx(header []string, name string) int {
	name = strings.ToLower(strings.TrimSpace(name))
	for i, h := range header {
		if strings.ToLower(strings.TrimSpace(h)) == name {
			return i
		}
	}
	return -1
}

func uniqueRepos(rows [][]string, repoIdx int) []string {
	set := make(map[string]struct{}, len(rows))
	for _, row := range rows {
		if repoIdx < 0 || repoIdx >= len(row) {
			continue
		}
		repo := strings.TrimSpace(row[repoIdx])
		if repo == "" {
			continue
		}
		set[repo] = struct{}{}
	}
	out := make([]string, 0, len(set))
	for repo := range set {
		out = append(out, repo)
	}
	sort.Strings(out)
	return out
}

func processRepo(parent context.Context, cfg config, repo string) ([]string, error) {
	// Create a temp dir per repo.
	prefix := "velrepo-"
	if repo != "" {
		s := strings.NewReplacer("/", "_", "\\", "_", " ", "_").Replace(repo)
		if len(s) > 40 {
			s = s[:40]
		}
		prefix += s + "-"
	}
	dir, err := os.MkdirTemp(cfg.tmpDir, prefix)
	if err != nil {
		return nil, err
	}
	if !cfg.keepRepo {
		defer func() { _ = os.RemoveAll(dir) }()
	}

	cloneURL := fmt.Sprintf(cfg.cloneURLFormat, repo)
	if cfg.verbose {
		logf("cloning %s -> %s", cloneURL, dir)
	}
	if err := gitClone(parent, cfg, cloneURL, dir); err != nil {
		return nil, err
	}

	emails, err := gitCollectEmails(parent, cfg, dir)
	if err != nil {
		return nil, err
	}
	return emails, nil
}

func gitClone(parent context.Context, cfg config, url, dir string) error {
	ctx, cancel := context.WithTimeout(parent, cfg.cloneTimeout)
	defer cancel()

	args := []string{"clone", "--filter=blob:none", "--no-checkout", "--quiet"}
	if cfg.since != "" && cfg.shallowSince {
		args = append(args, "--shallow-since="+cfg.since)
	}
	args = append(args, url, dir)

	cmd := exec.CommandContext(ctx, cfg.gitBin, args...)
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0")
	out, err := cmd.CombinedOutput()
	if err != nil {
		msg := strings.TrimSpace(string(out))
		if msg == "" {
			msg = err.Error()
		}
		return fmt.Errorf("git clone failed: %s", msg)
	}
	return nil
}

func gitCollectEmails(parent context.Context, cfg config, repoDir string) ([]string, error) {
	ctx, cancel := context.WithTimeout(parent, cfg.logTimeout)
	defer cancel()

	args := []string{"-C", repoDir, "log", "--all"}
	if cfg.since != "" {
		args = append(args, "--since="+cfg.since)
	}
	if cfg.until != "" {
		args = append(args, "--until="+cfg.until)
	}
	// NUL-separated stream per commit: authorEmail\0committerEmail\0body\0
	args = append(args, "--format=%ae%x00%ce%x00%B%x00")

	cmd := exec.CommandContext(ctx, cfg.gitBin, args...)
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

	// Drain stderr to avoid blocking; keep a tail for error messages.
	var stderrBuf strings.Builder
	stderrDone := make(chan struct{})
	go func() {
		defer close(stderrDone)
		scanner := bufio.NewScanner(stderr)
		// Allow longer stderr lines.
		buf := make([]byte, 0, 64*1024)
		scanner.Buffer(buf, 1024*1024)
		for scanner.Scan() {
			line := scanner.Text()
			// Keep last ~64KB.
			if stderrBuf.Len() < 64*1024 {
				stderrBuf.WriteString(line)
				stderrBuf.WriteString("\n")
			}
		}
	}()

	emailSet := make(map[string]struct{}, 256)

	br := bufio.NewReader(stdout)
	for {
		ae, err := readNULField(br)
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			_ = cmd.Process.Kill()
			<-stderrDone
			_ = cmd.Wait()
			return nil, fmt.Errorf("git log parse author email: %w", err)
		}
		ce, err := readNULField(br)
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			_ = cmd.Process.Kill()
			<-stderrDone
			_ = cmd.Wait()
			return nil, fmt.Errorf("git log parse committer email: %w", err)
		}
		body, err := readNULField(br)
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			_ = cmd.Process.Kill()
			<-stderrDone
			_ = cmd.Wait()
			return nil, fmt.Errorf("git log parse body: %w", err)
		}

		addEmail(emailSet, ae)
		addEmail(emailSet, ce)
		addEmailsFromBody(emailSet, body)
	}

	err = cmd.Wait()
	<-stderrDone
	if err != nil {
		errMsg := strings.TrimSpace(stderrBuf.String())
		if errMsg == "" {
			errMsg = err.Error()
		}
		return nil, fmt.Errorf("git log failed: %s", errMsg)
	}

	emails := make([]string, 0, len(emailSet))
	for e := range emailSet {
		emails = append(emails, e)
	}
	sort.Strings(emails)
	return emails, nil
}

func readNULField(r *bufio.Reader) (string, error) {
	b, err := r.ReadBytes(0)
	if err != nil {
		return "", err
	}
	if len(b) == 0 {
		return "", nil
	}
	// Drop trailing NUL.
	b = b[:len(b)-1]
	return string(b), nil
}

func addEmail(set map[string]struct{}, email string) {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return
	}
	// Some repos have literally "<>", or malformed values; ignore obvious junk.
	if !strings.Contains(email, "@") {
		return
	}
	set[email] = struct{}{}
}

func addEmailsFromBody(set map[string]struct{}, body string) {
	for _, m := range emailAngleRe.FindAllStringSubmatch(body, -1) {
		if len(m) < 2 {
			continue
		}
		addEmail(set, m[1])
	}
}

func logf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
}

func fatalf(format string, args ...any) {
	logf(format, args...)
	os.Exit(2)
}
