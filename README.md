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
| `codelens-scanner` | A | Single-pass extraction: ripgrep + ast-grep + fallow + hotspot deep-dive | `agents/codelens-scanner.md` |
| `security-reviewer` | B | OWASP Top 10 analysis with Context7 CVE checks | `agents/security-reviewer.md` |
| `architecture-reviewer` | B | SOLID compliance, dependency direction, pattern verification | `agents/architecture-reviewer.md` |
| `code-quality-reviewer` | B | Complexity, duplication, error handling, async patterns | `agents/code-quality-reviewer.md` |
| `a11y-reviewer` | B | WCAG 2.1 AA: keyboard nav, screen readers, ARIA, forms | `agents/a11y-reviewer.md` |
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
# Full review — all four domains, entire codebase
/codelens:review

# Security-only review
/codelens:review-security

# PR review — security + code quality on your unmerged changes
/codelens:review-pr

# Setup check + list all commands
/codelens:help
```

After scanning, codelens writes a domain-specific report (`SECURITY_REPORT.md`, `ARCHITECTURE_REPORT.md`, `CODE_QUALITY_REPORT.md`, `ACCESSIBILITY_REPORT.md`) for standalone runs, `CODEBASE_ANALYSIS_REPORT.md` for full reviews, or `PR_REVIEW_<range>.md` for PR reviews — all at your project root with findings organized by severity.

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
/codelens:help
```

This prints a checklist showing which tools are connected and install commands for any missing ones.

### Optional Enhancements

These tools enhance specific analysis domains. codelens works without them — they're detected automatically and skipped gracefully when absent.

#### fallow — TS/JS Dead-Code & Duplication

Deterministic codebase intelligence for TypeScript/JavaScript. Finds unused exports, files, dependencies, circular imports, and code duplication.

```bash
npm install --save-dev fallow
```

Only activated when a `package.json` is present. Not applicable to Python, Go, or other language projects.

#### ast-grep — Structural Code Search

AST-aware pattern matching using tree-sitter. Supports 20+ languages. Provides zero-false-positive detection for imports, class declarations, empty catch blocks, `eval()` calls, and duplicate boolean conditions — things ripgrep can only approximate with text regex.

```bash
# npm
npm install --global @ast-grep/cli

# Homebrew (macOS/Linux)
brew install ast-grep
```

## Commands

| Command | Purpose |
|---|---|
| `/codelens:review` | Full multi-domain review (security + architecture + quality + a11y) |
| `/codelens:review-security` | Security-only review |
| `/codelens:review-architecture` | Architecture-only review |
| `/codelens:review-quality` | Code quality-only review |
| `/codelens:review-a11y` | Accessibility-only review |
| `/codelens:review-pr` | PR diff review |
| `/codelens:help` | Setup check + command list |

**Coming soon:** `/codelens:fix-*` for automated remediation.

### Path Scope

Any review command accepts a path:
- `/codelens:review src/lib/payments` — full review scoped to a path
- `/codelens:review-security src/auth` — security review of one module

### Diff Scope (PR review)

`/codelens:review-pr` scans only changed files:
- `/codelens:review-pr` — defaults to `main...HEAD` using `pr-check` preset (security + code-quality)
- `/codelens:review-pr main..HEAD` — explicit range
- `/codelens:review-pr abc123..def456` — specific commit range
- `/codelens:review-pr <preset>` — use a preset from `.claude/review-presets.json`

### Presets

Presets define domain + scope combinations for `/codelens:review-pr`. Built-in presets:

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

**Phase A — Single-Pass Scan:** The scanner walks your scoped file set using three complementary tools:
- **ripgrep** for text pattern matching (secrets, console.log, TODO markers, ARIA attributes)
- **ast-grep** for structural AST patterns (imports, class declarations, empty catch blocks, eval calls) — supports 20+ languages
- **fallow** for TS/JS dead-code and duplication analysis (unused exports, circular deps, clone families)

For the top 10-15 largest files (complexity hotspots), it extracts structural data: function lists, JSX elements, imports, security signals. Everything is written to `.codelens-review/extraction.json`.

**Phase B — Domain Analysis:** Each domain reviewer reads only the extraction data — never your source files directly. Security uses Context7 to verify library versions and check for known CVEs. Architecture verifies patterns against current best practices. All findings are written to `.codelens-review/findings/<domain>.json`.

**Phase C — Merge & Report:** The orchestrator reads all findings, deduplicates cross-domain issues (same file:line merged into a single row), sorts by severity, and compiles the final report. Raw findings are kept in `.codelens-review/`; the orchestrator compiles the final Markdown report from JSON using the shared template at `skills/_shared/report-template.md`.

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
- Run `/codelens:review` for a full scan instead of a single domain
- Check that the path scope matches actual file locations

### Too many false positives
- Use `/codelens:review-security src/specific-path` to narrow scope
- Edit domain agent files in `agents/` to remove patterns that don't apply to your stack
- Create a `.claude/review-presets.json` with domains relevant to your project

### Review is slow on large repos
- Use path scope: `/codelens:review src/module` instead of scanning the whole repo
- Use diff scope for PRs: `/codelens:review-pr` only scans changed files
- The single-pass pipeline already minimizes token cost — large repos simply take longer

### "fallow not found" or missing dead-code findings
fallow is optional and only runs on TS/JS projects (when `package.json` exists). Install it with `npm i -D fallow`. Without it, dead-code and duplication analysis falls back to ripgrep-based heuristic patterns.

### "ast-grep not found" or structural patterns missing
ast-grep is optional. Without it, import analysis, class declaration detection, empty catch block detection, and eval matching use ripgrep regex (which may have false positives from strings/comments). Install with `npm i -g @ast-grep/cli` or `brew install ast-grep`.

## FAQ

**Does it work on non-JS/TS codebases?**
Yes. The pattern matching works on any language (Python, Go, Ruby, etc.). The JS/TS-specific patterns (React hooks, Next.js config) produce fewer findings on other stacks. Security and accessibility patterns are language-agnostic.

**How long does a review take?**
Depends on repo size. A 100-file project takes ~2-3 minutes. A 1000-file project can take 5-10 minutes. Diff-scoped reviews (`pr-check`) are faster since they only scan changed files.

**Can I use it in CI/CD?**
Not yet — this is planned. The current design requires an interactive Claude Code session. A GitHub Action wrapper is on the roadmap.

**How do I suppress false positives?**
Edit the relevant domain agent in `agents/` to remove or adjust the pattern that triggered the false positive. Each agent's criteria section lists all checks — comment out or modify the ones that don't apply to your stack.

**What about large monorepos?**
Use path scope to scan specific packages: `/codelens:review packages/auth`. The single-pass scanner handles large file counts efficiently, but scanning an entire monorepo at once consumes more tokens.

**Can I add custom domains?**
Yes. See [CONTRIBUTING.md](CONTRIBUTING.md) for the process: create a new agent file, add patterns to the scanner, register in the orchestrator's dispatch table, and add to the skill's command parsing.

## Architecture

```
codelens/
├── .claude-plugin/
│   ├── plugin.json            # Plugin manifest (v1.4.0+)
│   └── marketplace.json       # Marketplace listing
├── skills/
│   ├── review/
│   │   └── SKILL.md           # /codelens:review (full review)
│   ├── review-security/
│   │   └── SKILL.md           # /codelens:review-security
│   ├── review-architecture/
│   │   └── SKILL.md           # /codelens:review-architecture
│   ├── review-quality/
│   │   └── SKILL.md           # /codelens:review-quality
│   ├── review-a11y/
│   │   └── SKILL.md           # /codelens:review-a11y
│   ├── review-pr/
│   │   └── SKILL.md           # /codelens:review-pr
│   ├── help/
│   │   └── SKILL.md           # /codelens:help
│   └── _shared/
│       ├── report-template.md # Single source of truth for report format
│       └── setup-check.md     # Shared setup verification
├── agents/
│   ├── codelens-scanner.md    # Phase A: single-pass extractor
│   ├── codelens-reviewer.md   # Orchestrator: Phase C + dispatch
│   ├── security-reviewer.md   # Phase B: OWASP Top 10
│   ├── architecture-reviewer.md   # Phase B: SOLID + patterns
│   ├── code-quality-reviewer.md   # Phase B: complexity, duplication
│   └── a11y-reviewer.md       # Phase B: WCAG 2.1 AA
├── .claude/
│   ├── review-presets.json    # Default presets
│   └── codelens-exclusions.json # Exclusion patterns (defaults + byDomain + keepInScope)
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
- `agents/a11y-reviewer.md` — WCAG 2.1 AA, keyboard, ARIA

### Report Format
The report template is in `skills/_shared/report-template.md`. Modify sections, severity names, or output format.

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
