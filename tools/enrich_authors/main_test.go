package main

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

func TestCanonicalBotPatterns(t *testing.T) {
	data, err := os.ReadFile("../../sql/exclude_bots.sql")
	if err != nil {
		t.Fatal(err)
	}
	patterns := regexp.MustCompile(`'([^']*)'`).FindAllStringSubmatch(string(data), -1)
	if len(patterns) == 0 {
		t.Fatal("canonical bot patterns are missing")
	}
	for _, pattern := range patterns {
		for _, wildcard := range []string{"", "example"} {
			login := strings.NewReplacer("%", wildcard, "_", "x").Replace(pattern[1])
			if !devstatsBotRE.MatchString(login) {
				t.Errorf("canonical pattern %q does not match %q", pattern[1], login)
			}
		}
	}
}

func TestBotIdentities(t *testing.T) {
	for _, login := range []string{
		"MentatBot", "AmplabJenkins", "msftclas", "CodeLingoBot",
		"IssueHuntBot", "stacklokbot", "gocursor", "oai-codex",
		"EricWittbot", "codspeedbot", "RepoBirdBot", "grafanabot",
		"gemini-code-assist", "coderabbitai", "grpc-kokoro",
		"Copilot", "claude[bot]", "cursoragent", "dependabot[bot]",
		"github-harold_pins", "github-haroldxpins",
	} {
		t.Run(login, func(t *testing.T) {
			for _, email := range []string{
				login + "@users.noreply.github.com",
				"12345+" + login + "@users.noreply.github.com",
			} {
				if !isBotIdentity("Automation identity", email) {
					t.Errorf("bot email not recognized: %s", email)
				}
			}
			if !isBotIdentity(login, "") {
				t.Errorf("bot login not recognized: %s", login)
			}
		})
	}
}

func TestHumanIdentityControls(t *testing.T) {
	for _, tc := range []struct {
		name  string
		email string
	}{
		{"Claude Warren", "claude.warren@example.org"},
		{"Gemini Agaloos", "gemini.agaloos@example.org"},
		{"Alex Miller", "12345+Codex-@users.noreply.github.com"},
		{"Raunak Madan", "12345+CodexRaunak@users.noreply.github.com"},
		{"George Jenkins", "gjenkins8@users.noreply.github.com"},
		{"Alan Chiu", "buildbreaker@users.noreply.github.com"},
		{"Jesse Hitch", "jessebot@users.noreply.github.com"},
		{"Human Contributor", "dosullivan@users.noreply.github.com"},
		{"Human Contributor", "machine424@users.noreply.github.com"},
		{"Human Contributor", "agentofreality@users.noreply.github.com"},
		{"Human Contributor", "jlewi-openai@users.noreply.github.com"},
		{"Human Contributor", "nayuta-ai@users.noreply.github.com"},
		{"Human Contributor", "verybluebot@users.noreply.github.com"},
	} {
		t.Run(tc.name+"/"+tc.email, func(t *testing.T) {
			if isNonHumanOrGroupIdentity(tc.name, tc.email) {
				t.Errorf("human identity excluded: %s <%s>", tc.name, tc.email)
			}
		})
	}
}

func TestVerifiedAIMailbox(t *testing.T) {
	if !isNonHumanOrGroupIdentity("Claude Opus 5", "noreply@anthropic.com") {
		t.Fatal("Claude's documented co-author mailbox must be excluded")
	}
	if isNonHumanOrGroupIdentity("Human Contributor", "engineer@anthropic.com") {
		t.Fatal("a vendor domain alone does not make a contributor a bot")
	}
}

func TestBotPatternsDoNotMatchMailDomains(t *testing.T) {
	for _, email := range []string{
		"engineer@snyk.io",
		"engineer@codecov.io",
		"engineer@renovate.example",
		"engineer@ordinary-service.example",
	} {
		if isNonHumanOrGroupIdentity("Human Contributor", email) {
			t.Errorf("mail domain incorrectly matched as a bot login: %s", email)
		}
	}
}
