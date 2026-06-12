---
name: review-quality
description: |
  Use when running a code-quality-only review on a codebase. Triggers: "code quality review", "quality check", "complexity analysis", "duplication check", "/codelens:review-quality".
  For full multi-domain review, use /codelens:review instead.
user-invocable: true
argument-hint: "[path | help]"
---

# Codelens Code Quality Review

Code-quality-only review: complexity, duplication, async patterns, code smells. Produces `CODE_QUALITY_REPORT.md` at repo root.

## What it does

1. **Phase A — Scan:** `codelens-scanner` extracts patterns tagged `quality` and writes `.codelens/extraction.json`.
2. **Phase B — Analyze:** `code-quality-reviewer` reads extraction.json and writes `.codelens/findings/quality.json`.
3. **Phase C — Compile:** `codelens-reviewer` applies `skills/_shared/report-template.md` and writes `CODE_QUALITY_REPORT.md` at repo root.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-quality` | Code quality review on current directory |
| `/codelens:review-quality <path>` | Code quality review scoped to `<path>` |
| `/codelens:review-quality help` | Show this skill's help |

## Execution

1. Parse args
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Dispatch to `codelens-reviewer` orchestrator with `mode=single`, `domain=quality`
4. On completion: report at `CODE_QUALITY_REPORT.md`; raw findings at `.codelens/findings/quality.json`

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
