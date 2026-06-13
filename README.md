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

**codelens** runs as **one domain-aware agent** (`codelens-reviewer`) behind **seven thin dispatcher skills** (`/codelens:review`, `/codelens:review-{security,architecture,quality,a11y,pr}`, `/codelens:help`). The dispatcher skills pre-filter everything — which domains, which scope, which optional analyzers — so the agent receives a literal config and executes it verbatim. Coverage spans all four review perspectives:

- **Security** — OWASP Top 10 classification with Context7-powered CVE verification
- **Architecture** — SOLID compliance, dependency analysis, pattern verification
- **Code quality** — Complexity scoring, duplication detection, async pattern analysis
- **Accessibility** — WCAG 2.1 AA compliance, keyboard navigation, screen reader compatibility

The single agent reads each source file exactly once and analyzes all requested domains in that one pass — no multi-agent coordination tax, no re-reading. Cross-domain deduplication and severity-first report compilation happen in the same context.

## Agent Inventory

| Agent | Purpose | File |
|-------|---------|------|
| `codelens-reviewer` | Single domain-aware agent: scans, analyzes all requested domains in one pass, compiles report. Absorbs the former scanner + 4 reviewers + orchestrator. | `agents/codelens-reviewer.md` |

The 7 `/codelens:*` skills are thin dispatch wrappers that parse args, run the dependency gate, and invoke this single agent with a config object (`{domains, scope, scopeTarget, diffRange, outputFile}`).

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

Library documentation lookup for security CVE verification, deprecated API detection, architecture pattern validation, and component-library accessibility checks. Required by the `codelens-reviewer` agent.

```bash
/plugin marketplace add anthropics/claude-plugins-official   # if not already added
/plugin install context7
```

Source: [github.com/nurmdrafi/codelens](https://github.com/nurmdrafi/codelens) | [Context7 docs](https://context7.com)

### 3. context-mode MCP

Sandboxed file processing that prevents context window flooding during large-scale analysis. Required by the `codelens-reviewer` agent. Verified via `ctx_stats` before proceeding.

```bash
/plugin marketplace add mksglu/context-mode
/plugin install context-mode
```

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

### Domain Subset

`/codelens:review` accepts `--domains <comma-separated-list>` for an ad-hoc subset without editing presets:
- `/codelens:review --domains security,quality` — only security + quality sections
- `/codelens:review --domains a11y` — single domain (equivalent to `/codelens:review-a11y`)
- `/codelens:review --domains security,architecture src/lib` — combine with path scope

Precedence: `--domains` > `--preset` > default (all 4). Validation: domain names must be from `{security, architecture, quality, a11y}` (case-insensitive); invalid names fail fast with a clear error.

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

codelens runs as a **single agent** with **dispatcher-side filtering**. The skill you invoke (e.g., `/codelens:review-security`) knows exactly which domains and scope you requested, so it pre-filters everything before the agent runs — it builds a literal command list containing only the requested domains' patterns, scoped to your path. The agent executes that list verbatim.

This follows Anthropic's [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) guidance: code review is a *well-defined task*, so it should be a *workflow* (predefined code paths) with deterministic filtering in the dispatcher, not agent discretion. The agent cannot analyze a domain you didn't request or scan outside your scope — those commands simply aren't in the config it receives.

**Dispatcher (skill) — runs before the agent:**
1. Parses your command (`/codelens:review-security src/auth` → domains=`["security"]`, scope=`src/auth`)
2. Resolves `scopePath` (full → `.`, path → the path, diff → file list from `git diff --name-only`)
3. Loads exclusions, builds the `-g '!...'` flags
4. Copies patterns from `skills/_shared/domain-patterns.md` for the requested domains only
5. Builds three positionally-linked arrays: `step2Commands` (literal rg commands with scope + exclusions baked in), `step2Sources` (labels), and `step2Queries` (per-domain signal vocabulary for `ctx_search`)
6. Runtime detection: if `package.json` exists AND architecture/quality is in domains → appends fallow dead-code + dupes commands. If `sg` (ast-grep) is installed AND a requested domain has ast-grep patterns → appends those (deduped by source label when multiple domains share a pattern)
7. Passes the config `{scopePath, outputFile, step2Commands, step2Sources, step2Queries, step3Checks, criteriaDomains}` to the agent

**Agent (codelens-reviewer) — executes verbatim:**

**Step 1 — Inventory:** Maps the scoped file set (`rg --files`, line counts, tech-stack) via one `ctx_batch_execute`. Uses `config.scopePath` as-is.

**Step 2 — Pattern Analysis:** Emits `config.step2Commands` verbatim — does not add, remove, or modify commands. Results auto-index under `codelens:<domain>-patterns`; the agent retrieves evidence via `ctx_search` using `config.step2Queries[i]` verbatim — no improvised query strings. **The agent cannot run a non-requested domain's patterns because that command isn't in the array.**

**Step 2.5 — Doc & CVE Verification (on-flag):** Context7 + WebSearch only when Step 2 flags suspect libraries. CVE lookup only if security was requested.

**Step 3 — Hotspot Deep-Dive (single-pass):** For the top 10-15 largest files, ONE `ctx_execute_file` call per file. Processing code reads `const CHECKS = config.step3Checks` and runs `if (CHECKS.includes("security")) {...}` branches — real code, not comments. One file read → only requested domains' signals extracted.

**Step 4 — Compile Report:** Native `Write` to the report file at repo root. Severity-first ordering, cross-domain dedup (same file:line merged). Only `config.criteriaDomains` appear in Executive Summary and Methodology. No token counts. A human-readable `.codelens/scan.log` trace is also written.

Files are read **exactly once** — by the agent's Step 3. Pattern evidence comes via `ctx_search` against auto-indexed Step 2 output, never re-reading source. Domain and scope filtering happen in the dispatcher before the agent runs, so they cannot be silently violated.

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
The pipeline requires context-mode for sandboxed extraction. Without it, agents fall back to raw tools (higher token usage, slower). Install it:
```
/plugin marketplace add mksglu/context-mode
/plugin install context-mode
```
Then restart your Claude Code session.

### "Context7 MCP not connected"
The `codelens-reviewer` agent needs Context7 for library verification. Install it:
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
Use path scope to scan specific packages: `/codelens:review packages/auth`. The single-pass agent handles large file counts efficiently, but scanning an entire monorepo at once consumes more tokens.

**Can I add custom domains?**
Yes. See [CONTRIBUTING.md](CONTRIBUTING.md) for the process: add a new `<yourdomain-criteria>` block to `agents/codelens-reviewer.md`, add a pattern command to Step 2, and add a dispatch skill under `skills/review-<yourdomain>/`.

## Architecture

```
codelens/
├── .claude-plugin/
│   ├── plugin.json            # Plugin manifest (v1.5.0+)
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
│   └── codelens-reviewer.md   # Single domain-aware agent (scans, analyzes, compiles)
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
All four domains' criteria live in `agents/codelens-reviewer.md` as `<security-criteria>`, `<architecture-criteria>`, `<code-quality-criteria>`, `<accessibility-criteria>` blocks. Edit the relevant block to add/remove checks.

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
