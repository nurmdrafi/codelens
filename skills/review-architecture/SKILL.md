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

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing ONLY architecture pattern commands. The agent executes the commands verbatim — it cannot analyze other domains because their commands are not in the config. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-architecture` | Architecture review on current directory |
| `/codelens:review-architecture <path>` | Architecture review scoped to `<path>` |
| `/codelens:review-architecture help` | Show this skill's help |

## Execution

1. Parse args. Resolve `scopePath`: bare → `.`, `<path>` → the path string.
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + `byDomain.architecture`, minus `keepInScope` matches.
4. Construct the literal architecture rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `<exclusion-flags>`.
5. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "ARCHITECTURE_REPORT.md",
     "step2Commands": [
       {"label": "codelens:arch-patterns", "command": "<the literal arch rg command with scopePath + EXCL baked in>"}
     ],
     "step2Sources": ["codelens:arch-patterns"],
     "step3Checks": ["architecture"],
     "criteriaDomains": ["architecture"]
   }
   ```
6. On completion: report at `ARCHITECTURE_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `step2Commands` contains exactly ONE command (architecture). `step3Checks` is exactly `["architecture"]`. The agent cannot run security/quality/a11y checks because they are not in the config.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
