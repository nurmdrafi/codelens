---
name: review
description: |
  Use when performing code review, security audit, accessibility audit, architecture review, or code quality analysis on a codebase. Triggers: "review code", "audit codebase", "analyze code", "security review", "architecture review", "accessibility audit", "code quality check", "pr review", "code review", "review my code", "check code quality", "check security", "check accessibility".
user-invocable: true
argument-hint: "[all|security|architecture|code-quality|accessibility|a11y] [path|diff:range|preset|setup-check|help]"
---

# Code Review

Multi-domain code review: security, architecture, code quality, and accessibility — on your full repo, a module, or a PR diff.

## Overview

This skill invokes the codelens 3-phase pipeline:
1. **Phase A — Scan**: A single-pass extractor reads each file once, runs a combined pattern scan across all domains, and produces structured extraction data.
2. **Phase B — Analyze**: Domain-specific reviewers analyze the extraction data in parallel, each producing findings.
3. **Phase C — Merge**: The orchestrator deduplicates cross-domain findings and compiles a severity-first report.

## Command Parsing

Parse the arguments from `<argument-hint>`:

| Input | Domains | Scope |
|---|---|---|
| `/review` | guided prompt | guided prompt |
| `/review all` | all | full repo |
| `/review security` | security | full repo |
| `/review architecture` | architecture | full repo |
| `/review code-quality` | code-quality | full repo |
| `/review accessibility` or `/review a11y` | accessibility | full repo |
| `/review security,architecture` | specified domains | full repo |
| `/review all src/lib/payments` | all | path |
| `/review security diff:main..HEAD` | security | git diff |
| `/review pr-check` | security + code-quality | diff vs default branch |
| `/review a11y-audit` | accessibility | full repo |
| `/review full-audit` | all | full repo |
| `/review setup-check` | — | diagnostic |
| `/review help` | — | usage cheatsheet |

**Parsing rules:**
- **Token 1**: domain name(s) (comma-separated, no spaces), `all`, or a preset name. Default `all` if unrecognized or omitted. Map `a11y` to `accessibility`.
- **Token 2**: `diff:<range>` → git diff scope; otherwise treated as a file path. If `diff:` has no range, default to `<current-branch>..<default-branch>` (auto-detect via `git symbolic-ref refs/remotes/origin/HEAD`, fallback `main`/`master`).
- **Presets**: Check `.claude/review-presets.json` for preset definitions. Default presets: `pr-check` (security + code-quality, diff), `a11y-audit` (accessibility, full), `full-audit` (all, full).
- **Unrecognized input**: fall back to guided mode (ask, don't guess).

## Execution

After parsing arguments, invoke the `codelens-reviewer` agent with a configuration object:

```
{
  "domains": ["security", "architecture", "code-quality", "accessibility"],  // or subset
  "scope": "full" | "path" | "diff",
  "scopeTarget": "src/lib/payments" | "",           // for path scope
  "diffRange": "main..HEAD" | "",                    // for diff scope
  "reportFormat": "full" | "scoped" | "diff"         // auto-determined from scope
}
```

The orchestrator agent handles Phase A → Phase B → Phase C and writes the final report.

## Guided Mode

If no valid arguments are provided, ask the user:

1. **Which domains?** Present options: `all`, `security`, `architecture`, `code-quality`, `accessibility`, or custom combination
2. **What scope?** Present options: `full repo`, `specific path`, `git diff`
3. If path: ask for the path
4. If diff: ask for the range (or suggest `current-branch..default-branch`)
5. Confirm and dispatch

## Setup Check

If argument is `setup-check`, run these diagnostics and print a checklist:

```
1. ripgrep — run `rg --version` → ✅ installed / ❌ missing (install: brew install ripgrep / apt install ripgrep)
2. git — run `git --version` → ✅ / ❌
3. context-mode MCP — try calling ctx_stats → ✅ connected / ⚠️ not connected (optional: reduces token usage on large repos)
4. Context7 MCP — try calling resolve-library-id → ✅ connected / ⚠️ not connected (optional: enables library version checks for security findings)
```

Print: "Plugin works without optional MCPs, but with reduced accuracy (security/architecture library checks) and higher token usage."

## Help

If argument is `help`, print:

```
codelens — Multi-domain code review for Claude Code

Usage: /review [domains] [scope]

Domains:
  all                    All four domains (default)
  security               Security audit (OWASP Top 10)
  architecture           Architecture review (SOLID, patterns)
  code-quality           Code quality (complexity, duplication, async)
  accessibility, a11y    Accessibility audit (WCAG 2.1 AA)

Scope:
  (none)                 Full repository
  <path>                 Specific directory or file
  diff:<range>           Git diff (e.g. diff:main..HEAD)

Presets:
  pr-check               Security + code-quality on diff vs default branch
  a11y-audit             Accessibility audit on full repo
  full-audit             All domains on full repo

Other:
  setup-check            Check tool availability
  help                   This message

Examples:
  /review                           → guided mode
  /review all                       → full audit
  /review security                  → security-only audit
  /review security,a11y src/auth    → security + accessibility on src/auth
  /review pr-check                  → PR review preset
  /review security diff:main..HEAD  → security review of unmerged changes
```

## Finding Schema

Each domain reviewer writes findings to `.claude-review/findings/<domain>.json` using this schema:

```json
{
  "domain": "security",
  "severity": "Critical | High | Medium | Low | Informational",
  "title": "string",
  "location": "file/path:line",
  "classification": "OWASP A02:2021 | WCAG 2.4.1 | N/A",
  "evidence": "code snippet or pattern description",
  "impact": "what could go wrong",
  "fix": "specific remediation, with code example if applicable"
}
```

Severity definitions:
- **Critical**: Actively exploitable, data breach risk, immediate remediation required
- **High**: Significant risk, exploitable with effort, remediate within days
- **Medium**: Moderate risk, requires specific conditions, remediate within weeks
- **Low**: Minor risk, defense-in-depth improvement, normal development cycle
- **Informational**: Best practice recommendations, no direct exploit path

## Report Format

The final report is written using the native Write tool. Report filename:
- Full/scope review: `CODEBASE_ANALYSIS_REPORT.md` at project root
- Diff/PR review: `PR_REVIEW_<range-sanitized>.md` at project root

### Base Report Template

````markdown
# Codebase Analysis Report: [project-name]

**Date:** [date]
**Stack:** [detected tech stack]
**Domains:** [domains analyzed]
**Scope:** [full repo | path | diff range]

---

## Executive Summary

**Security:** [1-2 sentence posture assessment with critical/high count]

**Architecture:** [1-2 sentence structural health assessment]

**Code Quality:** [1-2 sentence quality assessment with key metrics]

**Accessibility:** [1-2 sentence WCAG compliance assessment]

---

## Critical ([count])

| # | Domain | Issue | Location |
|---|--------|-------|----------|
| 1 | Security | **[title]** — [one-line description] | `file:line` |

### Details

**1. [Issue Title]**
- **OWASP/WCAG:** [classification code and name]
- **Evidence:** [code snippet or pattern found]
- **Impact:** [what could go wrong]
- **Fix:** [specific remediation with code example where applicable]

---

## High ([count])

| # | Domain | Issue | Location |
|---|--------|-------|----------|

### Details

[Same detail format as Critical]

---

## Medium ([count])

| # | Domain | Issue | Location |
|---|--------|-------|----------|

### Details

[Same detail format]

---

## Low ([count])

| # | Domain | Issue | Location |
|---|--------|-------|----------|

### Details

[Same detail format — can be briefer]

---

## Informational ([count])

| # | Domain | Issue | Location |
|---|--------|-------|----------|

[No details subsection — the table is sufficient]

---

## What's Done Well

### Security
- [Positive finding with file reference]

### Architecture
- [Positive finding with file reference]

### Code Quality
- [Positive finding with file reference]

### Accessibility
- [Positive finding with file reference]

---

## Priority Actions

### Immediate (Week 1) — Critical
1. [Action from Critical findings — specific, with file reference]

### Short-Term (Week 2-3) — High
8. [Action from High findings]

### Medium-Term (Month 1) — Architecture + Quality
16. [Action from Medium findings]

### Backlog
27. [Remaining improvements]

---

## Methodology

| Domain | Files Scanned | Focus |
|--------|---------------|-------|
| **Security** | [count] | OWASP Top 10, auth, encryption, API security |
| **Architecture** | [count] | SOLID, patterns, dependency direction, state management |
| **Code Quality** | [count] | Complexity, duplication, async patterns, test coverage |
| **Accessibility** | [count] | WCAG 2.1 AA, keyboard nav, screen readers, forms |

Each domain analyzed extraction data from the single-pass scan and produced evidence-backed findings with file paths and code snippets. Findings were consolidated across domains and ranked by severity.
````

### Scoped-Path Variant
- Header adds: `**Scope:** <path(s)>`
- Methodology: file counts reflect scanned subtree only; note files outside scope were not analyzed.

### Diff/PR Variant
- Header adds: `**Diff Range:** base..head`, `**Files Changed:** N`
- Findings split into:
  - **🆕 New Issues Introduced by This Change** (evidence on `+` diff lines)
  - **⚠️ Pre-Existing Issues in Touched Files** (evidence on unchanged lines)
- Replace "What's Done Well" with "✅ Good Practices in This Diff"
- Replace Priority Actions with "Must Fix Before Merge" / "Consider Fixing"
- Methodology adds Base/Head commit SHAs.

### Cross-Domain Dedup Rule
Same `file:line` (±2 lines) across domains → merge into single row. `Domain` column lists all contributing domains (e.g. "Security + Architecture"). `Fix` addresses both angles.
