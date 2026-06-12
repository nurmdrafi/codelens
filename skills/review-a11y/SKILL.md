---
name: review-a11y
description: |
  Use when running an accessibility-only review on a codebase. Triggers: "accessibility review", "a11y audit", "WCAG check", "screen reader test", "/codelens:review-a11y".
  For full multi-domain review, use /codelens:review instead.
user-invocable: true
argument-hint: "[path | help]"
---

# Codelens Accessibility Review

Accessibility-only review: WCAG 2.1 AA analysis, ARIA patterns, keyboard navigation, semantic HTML. Produces `ACCESSIBILITY_REPORT.md` at repo root.

## What it does

1. **Phase A — Scan:** `codelens-scanner` extracts patterns tagged `a11y` and writes `.codelens/extraction.json`.
2. **Phase B — Analyze:** `a11y-reviewer` reads extraction.json and writes `.codelens/findings/a11y.json`.
3. **Phase C — Compile:** `codelens-reviewer` applies `skills/_shared/report-template.md` and writes `ACCESSIBILITY_REPORT.md` at repo root.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-a11y` | Accessibility review on current directory |
| `/codelens:review-a11y <path>` | Accessibility review scoped to `<path>` |
| `/codelens:review-a11y help` | Show this skill's help |

## Execution

1. Parse args
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Dispatch to `codelens-reviewer` orchestrator with `mode=single`, `domain=a11y`
4. On completion: report at `ACCESSIBILITY_REPORT.md`; raw findings at `.codelens/findings/a11y.json`

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
