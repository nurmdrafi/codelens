---
name: review-a11y
description: |
  Use when running an accessibility-only review on a codebase. Triggers: "accessibility review", "a11y audit", "WCAG check", "screen reader test", "/codelens:review-a11y".
  For full multi-domain review, use /codelens:review instead.
user-invocable: true
argument-hint: "[path | help]"
---

# Codelens Accessibility Review

Accessibility-only review: WCAG 2.1 AA analysis, ARIA patterns, keyboard navigation, semantic HTML. Produces `ACCESSIBILITY_REPORT.md` at repo root.

## What it does

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing ONLY accessibility pattern commands. The agent executes the commands verbatim — it cannot analyze other domains because their commands are not in the config. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-a11y` | Accessibility review on current directory |
| `/codelens:review-a11y <path>` | Accessibility review scoped to `<path>` |
| `/codelens:review-a11y help` | Show this skill's help |

## Execution

1. Parse args. Resolve `scopePath`: bare → `.`, `<path>` → the path string.
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + `byDomain.a11y` (a11y also excludes image binaries: `*.svg`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.webp`), minus `keepInScope` matches.
4. Construct the literal a11y rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `<exclusion-flags>`.
5. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "ACCESSIBILITY_REPORT.md",
     "step2Commands": [
       {"label": "codelens:a11y-patterns", "command": "<the literal a11y rg command with scopePath + EXCL baked in>"}
     ],
     "step2Sources": ["codelens:a11y-patterns"],
     "step3Checks": ["a11y"],
     "criteriaDomains": ["a11y"]
   }
   ```
6. On completion: report at `ACCESSIBILITY_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `step2Commands` contains exactly ONE command (a11y). `step3Checks` is exactly `["a11y"]`. The agent cannot run security/architecture/quality checks because they are not in the config.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
