---
name: review-architecture
description: |
  Use when running an architecture-only code review on a codebase. Triggers: "architecture review", "design review", "SOLID analysis", "dependency check", "/codelens:review-architecture".
  For full multi-domain review, use /codelens:review instead.
user-invocable: true
argument-hint: "[path | help]"
---

# Codelens Architecture Review

Architecture-only review: SOLID principles, dependency analysis, design patterns, module boundaries. Produces `ARCHITECTURE_REPORT.md` at repo root.

## What it does

1. **Phase A — Scan:** `codelens-scanner` extracts patterns tagged `architecture` and writes `.codelens/extraction.json`.
2. **Phase B — Analyze:** `architecture-reviewer` reads extraction.json and writes `.codelens/findings/architecture.json`.
3. **Phase C — Compile:** `codelens-reviewer` applies `skills/_shared/report-template.md` and writes `ARCHITECTURE_REPORT.md` at repo root.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-architecture` | Architecture review on current directory |
| `/codelens:review-architecture <path>` | Architecture review scoped to `<path>` |
| `/codelens:review-architecture help` | Show this skill's help |

## Execution

1. Parse args
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Dispatch to `codelens-reviewer` orchestrator with `mode=single`, `domain=architecture`
4. On completion: report at `ARCHITECTURE_REPORT.md`; raw findings at `.codelens/findings/architecture.json`

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
