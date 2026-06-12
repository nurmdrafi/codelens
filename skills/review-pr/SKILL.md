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
2. List changed files via `git diff --name-only <base>...<head>`.
3. **Phase A — Scan:** `codelens-scanner` extracts patterns from changed files only → `.codelens/extraction.json`.
4. **Phase B — Analyze:** Domain reviewers per preset (default: security + code-quality) write findings JSONs.
5. **Phase C — Compile:** `codelens-reviewer` applies `skills/_shared/report-template.md` and writes `PR_REVIEW_<base>-<head>.md` at repo root.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-pr` | Review `main...HEAD` using `pr-check` preset |
| `/codelens:review-pr <base>..<head>` | Review specific range using `pr-check` preset |
| `/codelens:review-pr <commit-sha>` | Review single commit |
| `/codelens:review-pr <preset>` | Review `main...HEAD` using `<preset>` from `.claude/review-presets.json` |
| `/codelens:review-pr help` | Show this skill's help |

## Execution

1. Parse args (range, commit, or preset)
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Resolve changed files via git
4. Dispatch to `codelens-reviewer` orchestrator with `mode=pr`, `range=<resolved>`
5. On completion: report at `PR_REVIEW_<base>-<head>.md`

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
