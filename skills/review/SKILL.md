---
name: review
description: |
  Use when running a full multi-domain code review (security + architecture + code quality + accessibility) on a codebase. Triggers: "full code review", "review everything", "audit codebase", "comprehensive review", "/codelens:review".
  For single-domain reviews, use /codelens:review-security, /codelens:review-architecture, /codelens:review-quality, or /codelens:review-a11y instead.
user-invocable: true
argument-hint: "[path | preset | help]"
---

# Codelens Full Review

Runs all four domains (security, architecture, code quality, accessibility) against the codebase. Produces a combined `CODEBASE_ANALYSIS_REPORT.md` at repo root.

## What it does

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing all four domains' pattern commands (or the preset's selected domains). The agent executes the commands verbatim. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review` | Full review on current directory (all 4 domains) |
| `/codelens:review <path>` | Full review scoped to `<path>` (all 4 domains) |
| `/codelens:review <preset>` | Review using a preset from `.claude/review-presets.json` (preset selects domains + scope) |
| `/codelens:review help` | Show this skill's help |

## Setup

Before running, verify environment by invoking `/codelens:help` (runs the shared setup-check at `skills/_shared/setup-check.md`).

## Execution

1. Parse args. Determine `domains`:
   - Bare or `<path>` → `["security", "architecture", "quality", "a11y"]`
   - `<preset>` → load `domains` from `.claude/review-presets.json` (map `"all"` to all 4)
   - For preset, also load `scope` + `scopeTarget`/`diffRange`
2. Resolve `scopePath`: bare → `.`; `<path>` → the path string; preset path scope → `scopeTarget`.
3. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
4. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + each requested domain's `byDomain` entry, minus `keepInScope` matches.
5. For each domain in `domains`, construct the literal rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `EXCL`. Assemble into `step2Commands`.
6. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "CODEBASE_ANALYSIS_REPORT.md",
     "step2Commands": [<one command per requested domain, full review = 4 commands>],
     "step2Sources": [<label per requested domain>],
     "step3Checks": [<domain id per requested domain>],
     "criteriaDomains": [<domain name per requested domain>]
   }
   ```
7. On completion: report at `CODEBASE_ANALYSIS_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** the agent receives the literal commands for the requested domains only. For a full review, that's 4 commands. For a preset like `a11y-audit`, that's 1 command — the agent cannot run the other 3 because their commands are not in the config.

## See Also

- `/codelens:review-security`, `/codelens:review-architecture`, `/codelens:review-quality`, `/codelens:review-a11y` — single-domain reviews
- `/codelens:review-pr` — PR diff review
- `/codelens:help` — setup check and command list
