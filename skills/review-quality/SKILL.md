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

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing ONLY code-quality pattern commands. The agent executes the commands verbatim — it cannot analyze other domains because their commands are not in the config. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-quality` | Code quality review on current directory |
| `/codelens:review-quality <path>` | Code quality review scoped to `<path>` |
| `/codelens:review-quality help` | Show this skill's help |

## Execution

1. Parse args. Resolve `scopePath`: bare → `.`, `<path>` → the path string.
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + `byDomain.quality`, minus `keepInScope` matches.
4. Construct the literal quality rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `<exclusion-flags>`.
5. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "CODE_QUALITY_REPORT.md",
     "step2Commands": [
       {"label": "codelens:quality-patterns", "command": "<the literal quality rg command with scopePath + EXCL baked in>"}
     ],
     "step2Sources": ["codelens:quality-patterns"],
     "step3Checks": ["quality"],
     "criteriaDomains": ["quality"]
   }
   ```
6. On completion: report at `CODE_QUALITY_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `step2Commands` contains exactly ONE command (quality). `step3Checks` is exactly `["quality"]`. The agent cannot run security/architecture/a11y checks because they are not in the config.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
