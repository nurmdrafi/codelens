---
name: review-security
description: |
  Use when running a security-only code review on a codebase. Triggers: "security review", "security audit", "check security", "OWASP review", "/codelens:review-security".
  For full multi-domain review, use /codelens:review instead.
user-invocable: true
argument-hint: "[path | help]"
---

# Codelens Security Review

Security-only review: OWASP Top 10 analysis, secret detection, injection patterns, auth issues. Produces `SECURITY_REPORT.md` at repo root.

## What it does

1. **Phase A — Scan:** `codelens-scanner` extracts patterns tagged `security` and writes `.codelens/extraction.json`.
2. **Phase B — Analyze:** `security-reviewer` reads extraction.json and writes `.codelens/findings/security.json`.
3. **Phase C — Compile:** `codelens-reviewer` applies `skills/_shared/report-template.md` and writes `SECURITY_REPORT.md` at repo root.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-security` | Security review on current directory |
| `/codelens:review-security <path>` | Security review scoped to `<path>` |
| `/codelens:review-security help` | Show this skill's help |

## Execution

1. Parse args
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Dispatch to `codelens-reviewer` orchestrator with `mode=single`, `domain=security`
4. On completion: report at `SECURITY_REPORT.md`; raw findings at `.codelens/findings/security.json`

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
