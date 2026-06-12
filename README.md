# codelens

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://github.com/nurmdrafi/codelens) [![GitHub stars](https://img.shields.io/github/stars/nurmdrafi/codelens)](https://github.com/nurmdrafi/codelens/stargazers) [![GitHub contributors](https://img.shields.io/github/contributors/nurmdrafi/codelens)](https://github.com/nurmdrafi/codelens/graphs/contributors)

> **AI code review is not a substitute for human review.** Automated tools miss context, produce false positives, and cannot fully understand business logic or user experience. Always verify findings with manual code review. This tool is a starting point, not a final verdict.

**An open-source Claude Code plugin that performs multi-domain code review — security, architecture, code quality, and accessibility — on your full repo, a module, or a PR diff.**

Built on a token-efficient 3-phase pipeline that reads files once and shares extraction data across all domain reviewers.

> **We want contributors!** If you care about code quality, security, or accessibility, please consider [submitting a PR](CONTRIBUTING.md). Every new pattern check helps developers ship better software.

---

## The Problem

Code review is essential but inconsistent. Security vulnerabilities slip through. Accessibility is an afterthought. Architecture drifts. Developers review code under time pressure and miss things — especially outside their domain of expertise. A frontend developer may catch CSS issues but miss a SQL injection. A backend developer may catch API design flaws but miss missing ARIA labels.

Even with linters and CI checks, significant issues evade detection because they require **cross-domain understanding** — a security issue that's also an architecture problem, an accessibility gap that's also a code quality issue.

## The Solution

**codelens** provides six specialized AI agents working as a coordinated pipeline:

- **Security reviewer** — OWASP Top 10 classification with Context7-powered CVE verification
- **Architecture reviewer** — SOLID compliance, dependency analysis, pattern verification
- **Code quality reviewer** — Complexity scoring, duplication detection, async pattern analysis
- **Accessibility reviewer** — WCAG 2.1 AA compliance, keyboard navigation, screen reader compatibility
- **Scanner** — Single-pass extraction that reads each file once, not four times
- **Orchestrator** — Cross-domain deduplication and severity-first report compilation

## Agent Inventory

| Agent | Phase | Purpose | File |
|-------|-------|---------|------|
| `codelens-scanner` | A | Single-pass extraction: ripgrep patterns + hotspot deep-dive | `agents/codelens-scanner.md` |
| `security-reviewer` | B | OWASP Top 10 analysis with Context7 CVE checks | `agents/security-reviewer.md` |
| `architecture-reviewer` | B | SOLID compliance, dependency direction, pattern verification | `agents/architecture-reviewer.md` |
| `code-quality-reviewer` | B | Complexity, duplication, error handling, async patterns | `agents/code-quality-reviewer.md` |
| `accessibility-reviewer` | B | WCAG 2.1 AA: keyboard nav, screen readers, ARIA, forms | `agents/accessibility-reviewer.md` |
| `codelens-reviewer` | C | Orchestrator: dispatch, dedup, compile report | `agents/codelens-reviewer.md` |

## Documentation

| Guide | What It Covers |
|-------|----------------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development setup, adding patterns, proposing domains, testing locally |
| [CLAUDE.md](CLAUDE.md) | Project architecture, conventions, constraints, common workflows |
| [examples/sample-report.md](examples/sample-report.md) | Full anonymized report from a real project (62 findings) |
| [CHANGELOG.md](CHANGELOG.md) | Release history and version changes |

---

## Install

```
/plugin marketplace add nurmdrafi/codelens
/plugin install codelens
```

Requires [Claude Code](https://claude.ai/code) CLI, desktop app, or IDE extension.

## Quick Start

```bash
# Guided mode — walks you through domain and scope selection
/review

# Full audit — all four domains, entire codebase
/review all

# PR review — security + code quality on your unmerged changes
/review pr-check
```

After scanning, codelens writes a `CODEBASE_ANALYSIS_REPORT.md` (or `PR_REVIEW_<range>.md` for diffs) at your project root with findings organized by severity.

## Required Setup

codelens requires three external tools. Install them before using:

### 1. ripgrep (`rg`)

Fast pattern-based code search. Required by all agents.

```bash
# macOS
brew install ripgrep

# Ubuntu/Debian
sudo apt install ripgrep

# Windows
winget install BurntSushi.ripgrep.MSVC
```

### 2. Context7 MCP

Library documentation lookup for security CVE verification, deprecated API detection, and architecture pattern validation. Required by security, architecture, and code-quality reviewers.

```bash
/plugin marketplace add anthropics/claude-plugins-official   # if not already added
/plugin install context7
```

Source: [github.com/nurmdrafi/codelens](https://github.com/nurmdrafi/codelens) | [Context7 docs](https://context7.com)

### 3. context-mode MCP

Sandboxed file processing that prevents context window flooding during large-scale analysis. Required by the scanner agent.

```bash
/plugin marketplace add mksglu/context-mode
/plugin install context-mode
```

Source: [github.com/mksglu/context-mode](https://github.com/mksglu/context-mode)

### Verify installation

```
/review setup-check
```

This prints a checklist showing which tools are connected and install commands for any missing ones.

## Command Reference

| Command | Domains | Scope |
|---------|---------|-------|
| `/review` | Guided prompt | Guided prompt |
| `/review all` | All four | Full repo |
| `/review security` | Security only | Full repo |
| `/review architecture` | Architecture only | Full repo |
| `/review code-quality` | Code quality only | Full repo |
| `/review accessibility` (or `a11y`) | Accessibility only | Full repo |
| `/review security,architecture` | Custom combination | Full repo |
| `/review all src/lib/payments` | All four | Specific path |
| `/review security diff:main..HEAD` | Security only | Git diff |
| `/review pr-check` | Security + code quality | Diff vs default branch |
| `/review a11y-audit` | Accessibility | Full repo |
| `/review full-audit` | All four | Full repo |
| `/review setup-check` | — | Diagnostic |
| `/review help` | — | Usage cheatsheet |

### Diff Scope

`diff:<range>` scans only changed files:
- `diff:main..HEAD` — all unmerged changes
- `diff:abc123..def456` — specific commit range
- `diff:` (no range) — auto-detects current branch vs default branch

### Presets

Presets define domain + scope combinations. Built-in presets:

| Preset | Domains | Scope |
|--------|---------|-------|
| `pr-check` | security, code-quality | diff |
| `a11y-audit` | accessibility | full |
| `full-audit` | all | full |

Create `.claude/review-presets.json` in your project to override or add presets:

```json
{
  "my-preset": {
    "domains": ["security", "accessibility"],
    "scope": "path",
    "scopeTarget": "src/components"
  }
}
```

## Domains Covered

### Security ([OWASP Top 10](https://owasp.org/Top10/))
Evaluates against [OWASP Top 10 (2021)](https://owasp.org/Top10/): broken access control (A01), cryptographic failures (A02), injection (A03), insecure design (A04), security misconfiguration (A05), vulnerable components (A06), authentication failures (A07), data integrity failures (A08), logging failures (A09), and SSRF (A10).

### Architecture ([SOLID](https://en.wikipedia.org/wiki/SOLID) + Patterns)
Evaluates pattern adherence, [SOLID compliance](https://en.wikipedia.org/wiki/SOLID) (single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion), dependency direction, abstraction levels, service boundaries, data flow, state management, scalability, and maintainability.

### Code Quality
Evaluates logic correctness, error handling at system boundaries, resource management, naming clarity, cyclomatic complexity (<10), duplication, DRY without premature abstraction, performance, async patterns, and test coverage.

### Accessibility ([WCAG 2.1 AA](https://www.w3.org/TR/WCAG21/))
Evaluates keyboard navigation, screen reader compatibility, visual/color contrast, [ARIA attributes](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA), form labeling, heading hierarchy, focus management, and dynamic content announcements against [WCAG 2.1 AA](https://www.w3.org/TR/WCAG21/) standards.

## How It Works

codelens uses a **3-phase pipeline** designed to minimize token cost:

**Phase A — Single-Pass Scan:** The scanner walks your scoped file set using ripgrep, running one combined pattern pass across all four domains. For the top 10-15 largest files (complexity hotspots), it extracts structural data: function lists, JSX elements, imports, security signals. Everything is written to `.claude-review/extraction.json`.

**Phase B — Domain Analysis:** Each domain reviewer reads only the extraction data — never your source files directly. Security uses Context7 to verify library versions and check for known CVEs. Architecture verifies patterns against current best practices. All findings are written to `.claude-review/findings/<domain>.json`.

**Phase C — Merge & Report:** The orchestrator reads all findings, deduplicates cross-domain issues (same file:line merged into a single row), sorts by severity, and compiles the final report. Working files are cleaned up automatically.

Files are read **at most once** — the extraction data is shared across all domain reviewers, avoiding the 4x token cost of independent scanning.

## Report Preview

codelens produces a severity-first markdown report at your project root:

```markdown
# Codebase Analysis Report: my-app

**Date:** 2026-06-12
**Stack:** React 18 · TypeScript · Tailwind CSS · Redux Toolkit
**Domains:** security, architecture, code-quality, accessibility

---

## Executive Summary

**Security:** 2 Critical, 3 High. Weak auth secret and client-side encryption key exposure.
**Architecture:** Clean server/client boundary, but carries tech debt in duplicated data-fetching paths.
**Code Quality:** Strong type safety, but 15+ debug console.log statements in production code.
**Accessibility:** Significant WCAG gaps — 92% of buttons missing accessible names.

---

## Critical (2)

| # | Domain | Issue | Location |
|---|--------|-------|----------|
| 1 | Security | **Weak AUTH_SECRET** — Guessable string allows JWT forgery | `.env:2` |
| 2 | A11y | **No skip link or <main> landmark** — Keyboard users cannot bypass nav | `app/layout.tsx` |

### Details

**1. Weak AUTH_SECRET**
- **OWASP:** A02:2021 – Cryptographic Failures
- **Evidence:** `AUTH_SECRET=my-app-secret-2024`
- **Impact:** Attacker can forge session tokens, impersonate users.
- **Fix:** Generate with `openssl rand -base64 48`. Rotate immediately.
```

See [`examples/sample-report.md`](examples/sample-report.md) for a full anonymized report from a real project (62 total findings).

## Troubleshooting

### "ripgrep not found" or `rg` errors
Install ripgrep: `brew install ripgrep` (macOS) or `apt install ripgrep` (Linux).

### "context-mode MCP not connected"
The scanner needs context-mode for sandboxed extraction. Install it:
```
/plugin marketplace add mksglu/context-mode
/plugin install context-mode
```
Then restart your Claude Code session.

### "Context7 MCP not connected"
Security, architecture, and code-quality reviewers need Context7 for library verification. Install it:
```
/plugin install context7
```

### Review produces no findings
- Verify the scan path contains source files (not just config/data files)
- Run `/review all` for a full scan instead of a single domain
- Check that the path scope matches actual file locations

### Too many false positives
- Use `/review security src/specific-path` to narrow scope
- Edit domain agent files in `agents/` to remove patterns that don't apply to your stack
- Create a `.claude/review-presets.json` with domains relevant to your project

### Review is slow on large repos
- Use path scope: `/review all src/module` instead of scanning the whole repo
- Use diff scope for PRs: `/review pr-check` only scans changed files
- The single-pass pipeline already minimizes token cost — large repos simply take longer

## FAQ

**Does it work on non-JS/TS codebases?**
Yes. The pattern matching works on any language (Python, Go, Ruby, etc.). The JS/TS-specific patterns (React hooks, Next.js config) produce fewer findings on other stacks. Security and accessibility patterns are language-agnostic.

**How long does a review take?**
Depends on repo size. A 100-file project takes ~2-3 minutes. A 1000-file project can take 5-10 minutes. Diff-scoped reviews (`pr-check`) are faster since they only scan changed files.

**Can I use it in CI/CD?**
Not yet — this is on the [Roadmap](#roadmap). The current design requires an interactive Claude Code session. A GitHub Action wrapper is planned.

**How do I suppress false positives?**
Edit the relevant domain agent in `agents/` to remove or adjust the pattern that triggered the false positive. Each agent's criteria section lists all checks — comment out or modify the ones that don't apply to your stack.

**What about large monorepos?**
Use path scope to scan specific packages: `/review all packages/auth`. The single-pass scanner handles large file counts efficiently, but scanning an entire monorepo at once consumes more tokens.

**Can I add custom domains?**
Yes. See [CONTRIBUTING.md](CONTRIBUTING.md) for the process: create a new agent file, add patterns to the scanner, register in the orchestrator's dispatch table, and add to the skill's command parsing.

## Architecture

```
codelens/
├── .claude-plugin/
│   ├── plugin.json            # Plugin manifest
│   └── marketplace.json       # Marketplace listing
├── skills/
│   └── review/
│       └── SKILL.md           # /review command logic + report template
├── agents/
│   ├── codelens-scanner.md    # Phase A: single-pass extractor
│   ├── codelens-reviewer.md   # Orchestrator: Phase C + dispatch
│   ├── security-reviewer.md   # Phase B: OWASP Top 10
│   ├── architecture-reviewer.md   # Phase B: SOLID + patterns
│   ├── code-quality-reviewer.md   # Phase B: complexity, duplication
│   └── accessibility-reviewer.md  # Phase B: WCAG 2.1 AA
├── .claude/
│   └── review-presets.json    # Default presets
├── examples/
│   └── sample-report.md       # Anonymized real report
├── CLAUDE.md                  # Project instructions for Claude Code
└── CONTRIBUTING.md            # Contribution guidelines
```

## Customization

### Add/Modify Presets
Edit `.claude/review-presets.json` in your project.

### Modify Domain Criteria
Each domain agent is a markdown file in `agents/`. Edit the criteria section to add/remove checks:
- `agents/security-reviewer.md` — OWASP classification, severity rules
- `agents/architecture-reviewer.md` — SOLID, patterns, state management
- `agents/code-quality-reviewer.md` — complexity, duplication, async
- `agents/accessibility-reviewer.md` — WCAG 2.1 AA, keyboard, ARIA

### Report Format
The report template is in `skills/review/SKILL.md`. Modify sections, severity names, or output format.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Adding new pattern checks to domain agents
- Testing changes locally
- Reporting false positives or missing patterns
- Proposing new domains

PRs welcome! Especially for:
- New domain-specific patterns (security, a11y, architecture, quality)
- New presets for common workflows
- False positive reports with reproduction steps

## License

[MIT](LICENSE) © 2026 nurmdrafi
