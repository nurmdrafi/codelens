---
name: review-pr
description: |
  Use when reviewing a pull request or commit range. Scans only the diff for changed files. Triggers: "PR review", "review pull request", "review diff", "/codelens:review-pr".
user-invocable: true
argument-hint: "[base..head | commit-sha | preset | help]"
---

# Codelens PR Review

Reviews only the files changed in a git diff. Uses presets from `.claude/review-presets.json` (default: `pr-check` runs security + code-quality).

## What it does

1. Resolve the commit range (default: `main...HEAD`).
2. List changed files via `git diff --name-only <base>...<head>` — this literal file list becomes `scopePath`.
3. Dispatch the `codelens-reviewer` agent with the preset's selected domains as pre-filtered `step2Commands`, scoped to the file list. The agent executes verbatim — it cannot scan files outside the diff because `scopePath` is the resolved file list, and it cannot run non-preset domains because their commands aren't in the config.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review-pr` | Review `main...HEAD` using `pr-check` preset |
| `/codelens:review-pr <base>..<head>` | Review specific range using `pr-check` preset |
| `/codelens:review-pr <commit-sha>` | Review single commit |
| `/codelens:review-pr <preset>` | Review `main...HEAD` using `<preset>` from `.claude/review-presets.json` |
| `/codelens:review-pr help` | Show this skill's help |

## Execution

1. Parse args (range, commit, or preset). Load preset `domains` from `.claude/review-presets.json` (default: `pr-check` → `["security", "quality"]`).
2. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
3. Resolve the changed file list: `git diff --name-only <range>`. This literal list is `scopePath` — every rg command will target exactly these files.
4. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + each preset domain's `byDomain` entry, minus `keepInScope` matches.
5. For each domain in the preset's `domains`, construct the literal rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` (the file list) and `EXCL`. Append to `step2Commands`. Append the domain's source label to `step2Sources`. Append the domain's query vocabulary array to `step2Queries` (positional linkage preserved — same vocabulary table as `/codelens:review`):

   | Domain | Source label | step2Queries vocabulary |
   |---|---|---|
   | security | `codelens:security-patterns` | `["localStorage", "sessionStorage", "SECRET", "TOKEN", "API_KEY", "password", "eval(", "innerHTML", "outerHTML", "dangerouslySetInnerHTML", "exec(", "System.run", "os.system", "subprocess", "DELETE", "DROP TABLE"]` |
   | architecture | `codelens:arch-patterns` | `["import", "from ", "require(", "export ", "class ", "extends", "implements", "interface ", "module", "dependency", "circular", "layer"]` |
   | quality | `codelens:quality-patterns` | `["function ", "const ", "let ", "var ", "TODO", "FIXME", "HACK", "console.log", "print(", "System.out", "any", "@ts-ignore", "eslint-disable", "catch (", "catch (e) {}"]` |
   | a11y | `codelens:a11y-patterns` | `["aria-", "role=", "tabIndex", "tabindex", "alt=\"\"", "alt=''", "onClick", "onKeyDown", "focus", "<img", "<input", "<button", "htmlFor", "for="]` |

6. **Conditional fallow union (diff-scoped).** If `test -f package.json` succeeds AND (`architecture` OR `quality` is in preset.domains): run `mkdir -p .codelens`, then append the following entries to `step2Commands`/`step2Sources`/`step2Queries`. These use `--changed-since <base>` to scope to the diff:

   - `{"label": "codelens:fallow-deadcode", "command": "npx -y fallow dead-code --changed-since <base> --format human --quiet -o .codelens/fallow-dead-code.md 2>/dev/null || true"}` → source `codelens:fallow-deadcode`, queries `["dead code", "unused", "unreferenced"]`
   - `{"label": "codelens:fallow-dupes", "command": "npx -y fallow dupes --changed-since <base> --format human --quiet -o .codelens/fallow-dupes.md 2>/dev/null || npx -y fallow dupes --format human --quiet -o .codelens/fallow-dupes.md 2>/dev/null || true"}` → source `codelens:fallow-dupes`, queries `["duplicate", "duplication", "repeated"]`

   The `fallow-dupes` command uses a fallback chain: try `--changed-since <base>` first (the diff-scoped form confirmed for `dead-code`); if `dupes` doesn't support `--changed-since` (unverified as of 1.7.1 — see spec Section 3), fall back to project-wide. Both paths are guarded by `2>/dev/null || true`. The scan.log will reflect which path actually ran via the command string.

7. **Conditional ast-grep union (diff-scoped via xargs).** If `command -v sg >/dev/null 2>&1` succeeds, derive the ast-grep pattern set by intersecting the per-domain mapping with `preset.domains`, then dedupe by source label:

   | Domain | Adds patterns |
   |---|---|
   | security | `emptycatch`, `eval` |
   | architecture | `imports`, `classes` |
   | quality | `emptycatch`, `eval`, `var`, `dupcond` |
   | a11y | (none) |

   Dedup rule: `emptycatch` and `eval` may appear under both security and quality; append each only once. Check whether `codelens:astgrep-<name>` is already in `step2Sources` before appending; if so, skip the append for all three positionally-coupled arrays at that index.

   For each pattern in the deduped set, append:
   - `{"label": "codelens:astgrep-<name>", "command": "git diff --name-only <base>...<head> | xargs sg run --pattern '<PATTERN>' --json 2>/dev/null || true"}` → source `codelens:astgrep-<name>`, queries `["<query>", "<query>"]`

   The `xargs` expansion is required because ast-grep takes variadic positional paths (no `--paths` flag, no native file-list mechanism). The pattern strings and per-source queries are identical to `/codelens:review`'s ast-grep table — this is the same mapping, just with diff-scoped invocation:

   | Label | sg --pattern | Queries |
   |---|---|---|
   | `codelens:astgrep-emptycatch` | `'catch ($_) {}'` | `["catch", "empty"]` |
   | `codelens:astgrep-eval` | `'eval($$$)'` | `["eval"]` |
   | `codelens:astgrep-imports` | `'import {$$} from \"$\"'` | `["import", "require"]` |
   | `codelens:astgrep-classes` | `'class $NAME extends $$$'` | `["class", "extends"]` |
   | `codelens:astgrep-var` | `'var $NAME = $VALUE'` | `["var"]` |
   | `codelens:astgrep-dupcond` | `'if ($COND) $$$ else if ($COND) $$$'` | `["duplicate", "condition"]` |

8. Dispatch the `codelens-reviewer` agent with config:
   ```json
   {
     "scope": "diff",
     "scopePath": "<literal file list from git diff --name-only>",
     "outputFile": "PR_REVIEW_<base>-<head>.md",
     "step2Commands": [<one rg command per preset domain>, ...optional fallow/ast-grep],
     "step2Sources": [<label per preset domain>, ...optional],
     "step2Queries": [<query array per preset domain>, ...optional],
     "step3Checks": [<domain id per preset domain>],
     "criteriaDomains": [<domain name per preset domain>]
   }
   ```

   `step2Commands`/`step2Sources`/`step2Queries` are positionally linked — same length, same index → same source.
9. On completion: report at `PR_REVIEW_<base>-<head>.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** `scopePath` is the resolved file list — the agent's rg commands cannot scan outside the diff. `step2Commands` starts with the preset's domains only — for `pr-check`, that's 2 rg commands (security + quality); the agent cannot run architecture or a11y because their commands aren't in the config. fallow and ast-grep commands are appended only when their detection conditions succeed AND their domain is in the preset, and they use diff-scoped invocation (`--changed-since <base>` / `xargs git diff --name-only`) so they also respect the PR range.

## See Also

- `/codelens:review` — full multi-domain review
- `/codelens:help` — setup check and command list
