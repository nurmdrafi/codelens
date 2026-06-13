---
name: review-pr
description: |
  Use when reviewing a pull request or commit range. Scans only the diff for changed files. Triggers: "PR review", "review pull request", "review diff", "/codelens:review-pr".
user-invocable: true
argument-hint: "[base..head | commit-sha | preset | help]"
---

# Codelens PR Review

Reviews only the files changed in a git diff. Uses presets from `.claude/review-presets.json` (default: `pr-check` runs security + code-quality).

## What it does

1. Resolve the commit range (default: `main...HEAD`).
2. List changed files via `git diff --name-only <base>...<head>` — this literal file list becomes `scopePath`.
3. Dispatch the `codelens-reviewer` agent with the preset's selected domains as pre-filtered `step2Commands`, scoped to the file list. The agent executes verbatim — it cannot scan files outside the diff because `scopePath` is the resolved file list, and it cannot run non-preset domains because their commands aren't in the config.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-pr` | Review `main...HEAD` using `pr-check` preset |
| `/codelens:review-pr <base>..<head>` | Review specific range using `pr-check` preset |
| `/codelens:review-pr <commit-sha>` | Review single commit |
| `/codelens:review-pr <preset>` | Review `main...HEAD` using `<preset>` from `.claude/review-presets.json` |
| `/codelens:review-pr help` | Show this skill's help |

## Execution

1. Parse args (range, commit, or preset). Load preset `domains` from `.claude/review-presets.json` (default: `pr-check` → `["security", "quality"]`).
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Resolve the changed file list: `git diff --name-only <range>`. This literal list is `scopePath` — every rg command will target exactly these files.
4. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + each preset domain's `byDomain` entry, minus `keepInScope` matches.
5. For each domain in the preset's `domains`, construct the literal rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` (the file list) and `EXCL`. Assemble into `step2Commands`.
6. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "diff",
     "scopePath": "<literal file list from git diff --name-only>",
     "outputFile": "PR_REVIEW_<base>-<head>.md",
     "step2Commands": [<one command per preset domain>],
     "step2Sources": [<label per preset domain>],
     "step3Checks": [<domain id per preset domain>],
     "criteriaDomains": [<domain name per preset domain>]
   }
   ```
7. On completion: report at `PR_REVIEW_<base>-<head>.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `scopePath` is the resolved file list — the agent's rg commands cannot scan outside the diff. `step2Commands` contains only the preset's domains — for `pr-check`, that's 2 commands (security + quality); the agent cannot run architecture or a11y because their commands aren't in the config.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
