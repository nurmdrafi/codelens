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
5. **Conditional ast-grep (security domain — `emptycatch` + `eval` patterns).** If `command -v sg >/dev/null 2>&1` succeeds, append the following two commands to `step2Commands`, their labels to `step2Sources`, and their query arrays to `step2Queries` (positional linkage — all three arrays must stay aligned):
   - `{"label": "codelens:astgrep-emptycatch", "command": "sg run --pattern 'catch ($_) {}' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-emptycatch`, queries `["catch", "empty"]`
   - `{"label": "codelens:astgrep-eval", "command": "sg run --pattern 'eval($$$)' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-eval`, queries `["eval"]`

   If `sg` is not installed, skip silently — do not append, do not error.
6. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "SECURITY_REPORT.md",
     "step2Commands": [
       {"label": "codelens:security-patterns", "command": "<the literal security rg command with scopePath + EXCL baked in>"}
     ],
     "step2Sources": ["codelens:security-patterns"],
     "step2Queries": [
       ["localStorage", "sessionStorage", "SECRET", "TOKEN", "API_KEY", "password", "eval(", "innerHTML", "outerHTML", "dangerouslySetInnerHTML", "exec(", "System.run", "os.system", "subprocess", "DELETE", "DROP TABLE"]
     ],
     "step3Checks": ["security"],
     "criteriaDomains": ["security"]
   }
   ```

   When ast-grep commands were appended in step 5, the dispatched config extends `step2Commands`/`step2Sources`/`step2Queries` with those entries (positional alignment preserved).
7. On completion: report at `SECURITY_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `step2Commands` starts with exactly ONE command (security). `step3Checks` is exactly `["security"]`. The agent cannot run architecture/quality/a11y checks because they are not in the config. ast-grep commands are appended only when `sg` is installed and are scoped to security-relevant patterns.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
