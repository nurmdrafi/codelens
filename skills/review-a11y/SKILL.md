---
name: review-a11y
description: |
  Use for accessibility-only review (WCAG 2.1 AA, keyboard, screen reader, ARIA). Triggers: "a11y audit", "WCAG check", "/codelens:review-a11y".
user-invocable: true
argument-hint: "[path]"
---

# Codelens Accessibility Review

Dispatches `codelens-reviewer` with `domains=["a11y"]`. Parses `$ARGUMENTS` for a path.

## Execution

1. Parse `$ARGUMENTS`: empty → `scope="full"`. Path-like token → `scope="path"`, `scopeTarget="<token>"`.
2. Dispatch `codelens-reviewer` with `{domains:["a11y"], scope, scopeTarget, outputFile:"A11Y_REPORT.md"}`.
3. Report at `A11Y_REPORT.md`; log appended at `.codelens/reviews.json`.

## See Also

`/codelens:review` for multi-domain, `/codelens:doctor` for setup.
