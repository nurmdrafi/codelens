---
name: review-security
description: |
  Use for security-only code review. Triggers: "security review", "OWASP check", "/codelens:review-security". Single domain, full or path scope.
user-invocable: true
argument-hint: "[path]"
---

# Codelens Security Review

Dispatches `codelens-reviewer` with `domains=["security"]`. Parses `$ARGUMENTS` for a path (defaults to repo root).

## Execution

1. Parse `$ARGUMENTS`: empty → `scope="full"`, `scopeTarget=""`. Contains path-like token → `scope="path"`, `scopeTarget="<token>"`.
2. Dispatch `codelens-reviewer` with config `{domains:["security"], scope, scopeTarget, outputFile:"SECURITY_REPORT.md"}`.
3. Report at `SECURITY_REPORT.md`; log appended at `.codelens/reviews.json`.

## See Also

`/codelens:review` for multi-domain, `/codelens:doctor` for setup.
