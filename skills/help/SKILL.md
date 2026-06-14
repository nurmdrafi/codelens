---
name: help
description: |
  Use when getting help with codelens commands, listing available skills, or running the setup check. Triggers: "codelens help", "list codelens commands", "codelens setup", "/codelens:help".
user-invocable: true
argument-hint: "[<command-name>]"
---

# Codelens Help

Lists all codelens commands and runs the setup check.

## What it does

1. Prints the **Quick reference** table (at-a-glance overview of all commands + accepted flags).
2. Runs the shared setup check (see `skills/_shared/setup-check.md`).
3. Lists all available `/codelens:*` commands with one-line descriptions and optional-tool flag detail.
4. If invoked as `/codelens:help <command-name>`, shows detailed help for that command (after the quick reference).

## Quick reference

Print this table FIRST when the user runs `/codelens:help` (with or without a command-name arg). It's the at-a-glance overview — purpose, accepted flags, and a quick example for each command. The detail sections below drill in if the user wants more.

| Command | Purpose | Accepts flags | Quick example |
|---|---|---|---|
| `/codelens:review` | All 4 domains (security + architecture + quality + a11y) | `--domains`, `--preset`, `--fallow`, `--ast-grep` | `/codelens:review --preset full-audit --fallow` |
| `/codelens:review-security` | OWASP / secrets / injection scan | `--ast-grep` | `/codelens:review-security --ast-grep` |
| `/codelens:review-architecture` | SOLID + dependency analysis | `--fallow`, `--ast-grep` | `/codelens:review-architecture --fallow` |
| `/codelens:review-quality` | Complexity, duplication, async patterns | `--fallow`, `--ast-grep` | `/codelens:review-quality --fallow --ast-grep` |
| `/codelens:review-a11y` | WCAG 2.1 AA accessibility | (none) | `/codelens:review-a11y` |
| `/codelens:review-pr` | Diff-only scan (PRs, commit ranges) | `--fallow`, `--ast-grep` | `/codelens:review-pr --ast-grep` |
| `/codelens:help` | This output + setup check | `<command-name>` | `/codelens:help review-quality` |

**Opt-in flags (default OFF):**
- `--fallow` — dead-code + duplication analysis (TS/JS only; requires `package.json`). Adds unused files/exports/dependencies, circular imports, code duplication findings.
- `--ast-grep` — structural pattern search (requires `sg` installed). Adds exact detection of `eval()`, empty catch, imports, class hierarchy, `var`, duplicate boolean conditions.

Flags compose freely with `<path>`, `--domains`, and `--preset`. Silent no-op if detection fails (no error).

## Available Commands

| Command | Purpose |
|---|---|
| `/codelens:review` | Full multi-domain review (security + architecture + quality + a11y) |
| `/codelens:review-security` | Security-only review |
| `/codelens:review-architecture` | Architecture-only review |
| `/codelens:review-quality` | Code quality-only review |
| `/codelens:review-a11y` | Accessibility-only review |
| `/codelens:review-pr` | PR diff review |
| `/codelens:help` | This command |

## Optional tool flags

Review commands accept opt-in flags for optional analysis tools. **Default: off.** Tools only run when the user passes the flag AND the tool's detection gate succeeds (fallow requires `package.json`; ast-grep requires `sg` installed).

| Flag | Tool | Effect | Applies to |
|---|---|---|---|
| `--fallow` | fallow | Add dead-code + duplication analysis (TS/JS projects only) | `review`, `review-architecture`, `review-quality`, `review-pr` |
| `--ast-grep` | ast-grep (`sg`) | Add structural pattern search (imports, classes, empty catch, eval, var, dupcond) | `review`, `review-security`, `review-architecture`, `review-quality`, `review-pr` |

(`review-a11y` accepts neither — a11y has no optional tools.)

**Compose freely with `<path>`, `--domains`, `--preset`:**
- `/codelens:review-quality --fallow --ast-grep` — quality review + both optional tools
- `/codelens:review --preset full-audit --fallow` — full review + dead-code analysis
- `/codelens:review-pr --ast-grep` — PR review + ast-grep structural patterns on the diff

**Silent no-op cases** (no error, just skipped): `--fallow` on a non-TS/JS project, `--ast-grep` when `sg` is not installed, `--fallow` when no `quality`/`architecture` domain is in scope.

## Future Commands (reserved)

| Command | Status |
|---|---|
| `/codelens:fix` | Coming soon — automated remediation |
| `/codelens:fix-security` | Coming soon |
| `/codelens:fix-a11y` | Coming soon |

## Execution

1. Print the Quick reference table (above) — first thing the user sees
2. Run setup check per `skills/_shared/setup-check.md`
3. Print the Available Commands list and Optional tool flags detail (below)
4. If arg matches a command name, print that skill's full body
5. If arg is `fix` or `fix-*`, print "coming soon" message

## Setup Check Details

See `skills/_shared/setup-check.md` for the full check matrix. All three required tools (ripgrep, context-mode, Context7) must be available for reviews to run.
