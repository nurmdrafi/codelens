---
name: review
description: |
  Use when running a full multi-domain code review (security + architecture + code quality + accessibility) on a codebase. Triggers: "full code review", "review everything", "audit codebase", "comprehensive review", "/codelens:review".
  For single-domain reviews, use /codelens:review-security, /codelens:review-architecture, /codelens:review-quality, or /codelens:review-a11y instead.
user-invocable: true
argument-hint: "[--domains <list> | --preset <name> | path | help]"
---

# Codelens Full Review

Runs all four domains (security, architecture, code quality, accessibility) against the codebase — or any subset the user requests via `--domains` or a preset. Produces a combined `CODEBASE_ANALYSIS_REPORT.md` at repo root.

## What it does

Dispatches the `codelens-reviewer` agent with a pre-filtered config containing the requested domains' pattern commands (default: all four). The agent executes the commands verbatim. See `skills/_shared/domain-patterns.md` for the pattern source.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review` | Full review on current directory (all 4 domains) |
| `/codelens:review <path>` | Full review scoped to `<path>` (all 4 domains) |
| `/codelens:review --domains <list>` | Ad-hoc domain subset (e.g. `security,quality`). Comma-separated, case-insensitive. Overrides `--preset`. |
| `/codelens:review --preset <name>` | Review using a preset from `.claude/review-presets.json` (preset selects domains + scope) |
| `/codelens:review help` | Show this skill's help |

### `--domains` flag

**Syntax:** `--domains` followed by a comma-separated list of domains from the set `{security, architecture, quality, a11y}`. Case-insensitive (lowercased after parse).

**Examples:**
- `/codelens:review --domains security,quality` — only security + quality sections
- `/codelens:review --domains a11y` — single domain (equivalent to `/codelens:review-a11y`)
- `/codelens:review --domains security,quality --preset pr-check` — `--domains` wins; warning printed: `--domains overrides --preset`

**Precedence:** `--domains` > `--preset` > default (all 4).

**Validation (fail fast, no silent fallback):**
- Unknown domain → error `Unknown domain: '<x>'. Valid: security, architecture, quality, a11y`, do not dispatch.
- Empty list (e.g. `--domains ""`) → error `--domains requires at least one value`, do not dispatch.

## Setup

Before running, verify environment by invoking `/codelens:help` (runs the shared setup-check at `skills/_shared/setup-check.md`).

## Execution

1. Parse args. Determine `domains`:
   - `--domains <value>` present → parse the comma-separated value, lowercase each, validate against `{security, architecture, quality, a11y}`. If any invalid: STOP with the error above. If empty: STOP with the empty-list error. If `--preset` also present: print warning `--domains overrides --preset`. Skip preset resolution.
   - Else if `--preset <name>` present → load `domains` from `.claude/review-presets.json` (map `"all"` to all 4). For preset, also load `scope` + `scopeTarget`/`diffRange`.
   - Else (bare or `<path>`) → `domains = ["security", "architecture", "quality", "a11y"]`.
2. Resolve `scopePath`: bare → `.`; `<path>` → the path string; preset path scope → `scopeTarget`.
3. Run dependency gate per `skills/_shared/setup-check.md` Gate section. If any required dependency is missing, STOP — do not dispatch.
4. Load exclusions from `.claude/codelens-exclusions.json` (or fallback list from `agents/codelens-reviewer.md`). Build `EXCL` = the `-g '!...'` flags for `defaults` + each requested domain's `byDomain` entry, minus `keepInScope` matches.
5. For each domain in `domains`, construct the literal rg command from `skills/_shared/domain-patterns.md`, substituting `<scopePath>` and `EXCL`. Append to `step2Commands`. Append the domain's source label to `step2Sources`. Append the domain's query vocabulary array to `step2Queries` (positional linkage — index `i` across all three arrays refers to the same domain):

   | Domain | Source label | step2Queries vocabulary |
   |---|---|---|
   | security | `codelens:security-patterns` | `["localStorage", "sessionStorage", "SECRET", "TOKEN", "API_KEY", "password", "eval(", "innerHTML", "outerHTML", "dangerouslySetInnerHTML", "exec(", "System.run", "os.system", "subprocess", "DELETE", "DROP TABLE"]` |
   | architecture | `codelens:arch-patterns` | `["import", "from ", "require(", "export ", "class ", "extends", "implements", "interface ", "module", "dependency", "circular", "layer"]` |
   | quality | `codelens:quality-patterns` | `["function ", "const ", "let ", "var ", "TODO", "FIXME", "HACK", "console.log", "print(", "System.out", "any", "@ts-ignore", "eslint-disable", "catch (", "catch (e) {}"]` |
   | a11y | `codelens:a11y-patterns` | `["aria-", "role=", "tabIndex", "tabindex", "alt=\"\"", "alt=''", "onClick", "onKeyDown", "focus", "<img", "<input", "<button", "htmlFor", "for="]` |

6. **Conditional fallow union.** If `test -f package.json` succeeds AND (`architecture` OR `quality` is in `domains`): run `mkdir -p .codelens`, then append the following two entries to `step2Commands`/`step2Sources`/`step2Queries` (positional linkage preserved):
   - `{"label": "codelens:fallow-deadcode", "command": "npx -y fallow dead-code --format human --quiet -o .codelens/fallow-dead-code.md 2>/dev/null || true"}` → source `codelens:fallow-deadcode`, queries `["dead code", "unused", "unreferenced"]`
   - `{"label": "codelens:fallow-dupes", "command": "npx -y fallow dupes --format human --quiet -o .codelens/fallow-dupes.md 2>/dev/null || true"}` → source `codelens:fallow-dupes`, queries `["duplicate", "duplication", "repeated"]`

   If neither architecture nor quality is in `domains`, fallow is not appended even if `package.json` exists.
7. **Conditional ast-grep union (deduped).** If `command -v sg >/dev/null 2>&1` succeeds, derive the ast-grep pattern set from `domains`:

   | Domain | Adds patterns |
   |---|---|
   | security | `emptycatch`, `eval` |
   | architecture | `imports`, `classes` |
   | quality | `emptycatch`, `eval`, `var`, `dupcond` |
   | a11y | (none) |

   Union the patterns across all in-scope domains, then **dedupe by source label** — `emptycatch` and `eval` appear under both security and quality; append each only once. Before appending any ast-grep entry, check whether its `codelens:astgrep-<name>` label is already in `step2Sources`; if so, skip the append for all three positionally-coupled arrays (`step2Sources`, `step2Commands`, `step2Queries`) at that index.

   For each pattern in the deduped set, append:
   - `{"label": "codelens:astgrep-<name>", "command": "sg run --pattern '<PATTERN>' --json <scopePath> 2>/dev/null || true"}` → source `codelens:astgrep-<name>`, queries `["<query>", "<query>"]`

   Pattern strings and queries per source label:

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
     "scope": "full" | "path",
     "scopePath": "<resolved>",
     "outputFile": "CODEBASE_ANALYSIS_REPORT.md",
     "step2Commands": [<one rg command per requested domain>, ...optional fallow/ast-grep],
     "step2Sources": [<label per requested domain>, ...optional],
     "step2Queries": [<query array per requested domain>, ...optional],
     "step3Checks": [<domain id per requested domain>],
     "criteriaDomains": [<domain name per requested domain>]
   }
   ```

   `step2Commands`/`step2Sources`/`step2Queries` are positionally linked — same length, same index → same source.
9. On completion: report at `CODEBASE_ANALYSIS_REPORT.md`; scanner trace at `.codelens/scan.log`.

**Structural guarantee:** the agent receives the literal commands for the requested domains only. For a full review, that's 4 commands. For `--domains security,quality`, that's 2 commands plus (conditionally) fallow + ast-grep entries. The agent cannot run commands for non-requested domains because their commands are not in the config.

## See Also

- `/codelens:review-security`, `/codelens:review-architecture`, `/codelens:review-quality`, `/codelens:review-a11y` — single-domain reviews
- `/codelens:review-pr` — PR diff review
- `/codelens:help` — setup check and command list
