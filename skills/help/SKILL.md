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

1. Runs the shared setup check (see `skills/_shared/setup-check.md`).
2. Lists all available `/codelens:*` commands with one-line descriptions.
3. If invoked as `/codelens:help <command-name>`, shows detailed help for that command.

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

1. Run setup check per `skills/_shared/setup-check.md`
2. Print command list (table above)
3. If arg matches a command name, print that skill's full body
4. If arg is `fix` or `fix-*`, print "coming soon" message

## Setup Check Details

See `skills/_shared/setup-check.md` for the full check matrix. All three required tools (ripgrep, context-mode, Context7) must be available for reviews to run.
