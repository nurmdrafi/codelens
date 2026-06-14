---
name: review-quality
description: |
  Use for code-quality-only review (complexity, error handling, DRY). Triggers: "code quality review", "complexity check", "/codelens:review-quality".
user-invocable: true
argument-hint: "[path]"
---

# Codelens Code Quality Review

Dispatches `codelens-reviewer` with `domains=["quality"]`. Parses `$ARGUMENTS` for a path.

## Execution

1. Parse `$ARGUMENTS`: empty → `scope="full"`. Path-like token → `scope="path"`, `scopeTarget="<token>"`.
2. Dispatch `codelens-reviewer` with `{domains:["quality"], scope, scopeTarget, outputFile:"QUALITY_REPORT.md"}`.
3. Report at `QUALITY_REPORT.md`; log appended at `.codelens/reviews.json`.

## See Also

`/codelens:review` for multi-domain, `/codelens:doctor` for setup.
