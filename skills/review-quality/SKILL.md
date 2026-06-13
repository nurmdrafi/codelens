---
name: review-quality
description: |
  Use when running a code-quality-only review on a codebase. Triggers: "code quality review", "quality check", "complexity analysis", "duplication check", "/codelens:review-quality".
  For full multi-domain review, use /codelens:review instead.
user-invocable: true
argument-hint: "[--fallow | --ast-grep | path | help]"
---

# Codelens Code Quality Review

Code-quality-only review: complexity, duplication, async patterns, code smells. Produces `CODE_QUALITY_REPORT.md` at repo root.

## What it does

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing ONLY code-quality pattern commands. The agent executes the commands verbatim — it cannot analyze other domains because their commands are not in the config. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-quality` | Code quality review on current directory (no optional tools) |
| `/codelens:review-quality <path>` | Code quality review scoped to `<path>` |
| `/codelens:review-quality --fallow` | Also run fallow dead-code + duplication analysis (TS/JS projects only) |
| `/codelens:review-quality --ast-grep` | Also run ast-grep structural patterns (empty catch, eval, var, dupcond) |
| `/codelens:review-quality --fallow --ast-grep <path>` | All optional tools + scoped path |
| `/codelens:review-quality help` | Show this skill's help |

**Flags compose freely with `<path>`** — order does not matter. Unknown flag → STOP with `Unknown flag: '--<x>'. Valid: --fallow, --ast-grep, <path>, help`, do not dispatch.

## Execution

1. Parse args. Resolve `scopePath`: bare → `.`, `<path>` → the path string.
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + `byDomain.quality`, minus `keepInScope` matches.
4. Construct the literal quality rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `<exclusion-flags>`.
5. **Conditional fallow (opt-in, quality is in fallow's domain set).** If the user passed `--fallow` AND `test -f package.json` succeeds, append the following two commands to `step2Commands`, their labels to `step2Sources`, and their query arrays to `step2Queries` (positional linkage — all three arrays must stay aligned). **No `-o` flag, no `mkdir -p .codelens`** — `ctx_batch_execute` captures stdout via auto-index:
   - `{"label": "codelens:fallow-deadcode", "command": "npx -y fallow dead-code --format human --quiet 2>/dev/null || true"}` → source `codelens:fallow-deadcode`, queries `["dead code", "unused", "unreferenced"]`
   - `{"label": "codelens:fallow-dupes", "command": "npx -y fallow dupes --format human --quiet 2>/dev/null || true"}` → source `codelens:fallow-dupes`, queries `["duplicate", "duplication", "repeated"]`

   If `--fallow` was NOT passed, skip silently — do not append. If `package.json` is not present (non-TS/JS project), skip silently — do not append, do not error.
6. **Conditional ast-grep (opt-in, quality domain — `emptycatch` + `eval` + `var` + `dupcond` patterns).** If the user passed `--ast-grep` AND `command -v sg >/dev/null 2>&1` succeeds, append the following four commands to `step2Commands`, their labels to `step2Sources`, and their query arrays to `step2Queries` (positional linkage preserved):
   - `{"label": "codelens:astgrep-emptycatch", "command": "sg run --pattern 'catch ($_) {}' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-emptycatch`, queries `["catch", "empty"]`
   - `{"label": "codelens:astgrep-eval", "command": "sg run --pattern 'eval($$$)' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-eval`, queries `["eval"]`
   - `{"label": "codelens:astgrep-var", "command": "sg run --pattern 'var $NAME = $VALUE' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-var`, queries `["var"]`
   - `{"label": "codelens:astgrep-dupcond", "command": "sg run --pattern 'if ($COND) $$$ else if ($COND) $$$' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-dupcond`, queries `["duplicate", "condition"]`

   If `--ast-grep` was NOT passed, skip silently. If `sg` is not installed, skip silently.
7. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "CODE_QUALITY_REPORT.md",
     "step2Commands": [
       {"label": "codelens:quality-patterns", "command": "<the literal quality rg command with scopePath + EXCL baked in>"}
     ],
     "step2Sources": ["codelens:quality-patterns"],
     "step2Queries": [
       ["function ", "const ", "let ", "var ", "TODO", "FIXME", "HACK", "console.log", "print(", "System.out", "any", "@ts-ignore", "eslint-disable", "catch (", "catch (e) {}"]
     ],
     "step3Checks": ["quality"],
     "criteriaDomains": ["quality"]
   }
   ```

   When fallow/ast-grep commands were appended in steps 5-6, the dispatched config extends `step2Commands`/`step2Sources`/`step2Queries` with those entries (positional alignment preserved).
8. On completion: report at `CODE_QUALITY_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `step2Commands` starts with exactly ONE command (quality). `step3Checks` is exactly `["quality"]`. The agent cannot run security/architecture/a11y checks because they are not in the config. fallow commands are appended ONLY when the user passes `--fallow` AND `package.json` is present; ast-grep commands ONLY when the user passes `--ast-grep` AND `sg` is installed. Default invocation (no flags) runs neither optional tool.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
