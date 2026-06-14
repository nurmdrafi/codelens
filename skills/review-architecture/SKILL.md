---
name: review-architecture
description: |
  Use for architecture-only review (SOLID, coupling, dependency direction). Triggers: "architecture review", "SOLID check", "/codelens:review-architecture".
user-invocable: true
argument-hint: "[path]"
---

# Codelens Architecture Review

Dispatches `codelens-reviewer` with `domains=["architecture"]`. Parses `$ARGUMENTS` for a path.

## Execution

1. Parse `$ARGUMENTS`: empty → `scope="full"`. Path-like token → `scope="path"`, `scopeTarget="<token>"`.
2. Dispatch `codelens-reviewer` with `{domains:["architecture"], scope, scopeTarget, outputFile:"ARCHITECTURE_REPORT.md"}`.
3. Report at `ARCHITECTURE_REPORT.md`; log appended at `.codelens/reviews.json`.

## See Also

`/codelens:review` for multi-domain, `/codelens:doctor` for setup.
