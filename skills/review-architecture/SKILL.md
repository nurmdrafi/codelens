---
name: review-architecture
description: |
  Use when running an architecture-only code review on a codebase. Triggers: "architecture review", "design review", "SOLID analysis", "dependency check", "/codelens:review-architecture".
  For full multi-domain review, use /codelens:review instead.
user-invocable: true
argument-hint: "[--fallow | --ast-grep | path | help]"
---

# Codelens Architecture Review

Architecture-only review: SOLID principles, dependency analysis, design patterns, module boundaries. Produces `ARCHITECTURE_REPORT.md` at repo root.

## What it does

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing ONLY architecture pattern commands. The agent executes the commands verbatim — it cannot analyze other domains because their commands are not in the config. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-architecture` | Architecture review on current directory (no optional tools) |
| `/codelens:review-architecture <path>` | Architecture review scoped to `<path>` |
| `/codelens:review-architecture --fallow` | Also run fallow dead-code + duplication analysis (TS/JS projects only) |
| `/codelens:review-architecture --ast-grep` | Also run ast-grep structural patterns (imports, classes) |
| `/codelens:review-architecture --fallow --ast-grep <path>` | All optional tools + scoped path |
| `/codelens:review-architecture help` | Show this skill's help |

**Flags compose freely with `<path>`** — order does not matter. Unknown flag → STOP with `Unknown flag: '--<x>'. Valid: --fallow, --ast-grep, <path>, help`, do not dispatch.

## Execution

1. Parse args. Resolve `scopePath`: bare → `.`, `<path>` → the path string.
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + `byDomain.architecture`, minus `keepInScope` matches.
4. Construct the literal architecture rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `<exclusion-flags>`.
5. **Conditional fallow (opt-in, architecture is in fallow's domain set).** If the user passed `--fallow` AND `test -f package.json` succeeds, append the following two commands to `step2Commands`, their labels to `step2Sources`, and their query arrays to `step2Queries` (positional linkage — all three arrays must stay aligned). **No `-o` flag, no `mkdir -p .codelens`** — `ctx_batch_execute` captures stdout via auto-index:
   - `{"label": "codelens:fallow-deadcode", "command": "npx -y fallow dead-code --format human --quiet 2>/dev/null || true"}` → source `codelens:fallow-deadcode`, queries `["dead code", "unused", "unreferenced"]`
   - `{"label": "codelens:fallow-dupes", "command": "npx -y fallow dupes --format human --quiet 2>/dev/null || true"}` → source `codelens:fallow-dupes`, queries `["duplicate", "duplication", "repeated"]`

   If `--fallow` was NOT passed, skip silently — do not append. If `package.json` is not present (non-TS/JS project), skip silently — do not append, do not error.
6. **Conditional ast-grep (opt-in, architecture domain — `imports` + `classes` patterns).** If the user passed `--ast-grep` AND `command -v sg >/dev/null 2>&1` succeeds, append the following two commands to `step2Commands`, their labels to `step2Sources`, and their query arrays to `step2Queries` (positional linkage preserved):
   - `{"label": "codelens:astgrep-imports", "command": "sg run --pattern 'import {$$} from \"$\"' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-imports`, queries `["import", "require"]`
   - `{"label": "codelens:astgrep-classes", "command": "sg run --pattern 'class $NAME extends $$$' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-classes`, queries `["class", "extends"]`

   If `--ast-grep` was NOT passed, skip silently. If `sg` is not installed, skip silently.
7. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "ARCHITECTURE_REPORT.md",
     "step2Commands": [
       {"label": "codelens:arch-patterns", "command": "<the literal arch rg command with scopePath + EXCL baked in>"}
     ],
     "step2Sources": ["codelens:arch-patterns"],
     "step2Queries": [
       ["import", "from ", "require(", "export ", "class ", "extends", "implements", "interface ", "module", "dependency", "circular", "layer"]
     ],
     "step3Checks": ["architecture"],
     "criteriaDomains": ["architecture"]
   }
   ```

   When fallow/ast-grep commands were appended in steps 5-6, the dispatched config extends `step2Commands`/`step2Sources`/`step2Queries` with those entries (positional alignment preserved).
8. On completion: report at `ARCHITECTURE_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `step2Commands` starts with exactly ONE command (architecture). `step3Checks` is exactly `["architecture"]`. The agent cannot run security/quality/a11y checks because they are not in the config. fallow commands are appended ONLY when the user passes `--fallow` AND `package.json` is present; ast-grep commands ONLY when the user passes `--ast-grep` AND `sg` is installed. Default invocation (no flags) runs neither optional tool.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
