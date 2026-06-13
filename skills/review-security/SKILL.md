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

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing ONLY security pattern commands. The agent executes the commands verbatim — it cannot analyze other domains because their commands are not in the config. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-security` | Security review on current directory |
| `/codelens:review-security <path>` | Security review scoped to `<path>` |
| `/codelens:review-security help` | Show this skill's help |

## Execution

1. Parse args. Resolve `scopePath`: bare → `.`, `<path>` → the path string.
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + `byDomain.security`, minus `keepInScope` matches.
4. Construct the literal security rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `<exclusion-flags>`.
5. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "SECURITY_REPORT.md",
     "step2Commands": [
       {"label": "codelens:security-patterns", "command": "<the literal security rg command with scopePath + EXCL baked in>"}
     ],
     "step2Sources": ["codelens:security-patterns"],
     "step3Checks": ["security"],
     "criteriaDomains": ["security"]
   }
   ```
6. On completion: report at `SECURITY_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `step2Commands` contains exactly ONE command (security). `step3Checks` is exactly `["security"]`. The agent cannot run architecture/quality/a11y checks because they are not in the config.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
