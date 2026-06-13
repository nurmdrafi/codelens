# Domain Patterns (shared reference)

This is the canonical source of rg pattern commands per domain. Dispatching skills copy the patterns for their requested domain(s) into the config's `step2Commands` array, substituting `<scopePath>` and `<exclusion-flags>`.

**This file is a reference, not executed.** Skills construct literal strings from it; the agent receives the already-filtered list and emits it verbatim via `ctx_batch_execute`.

## How skills use this

1. Determine which domains the command runs (e.g., `/codelens:review-security` → `["security"]`).
2. For each requested domain, copy that domain's command below into `step2Commands`, substituting:
   - `<scopePath>` — the resolved scope (full → `.`, path → `scopeTarget`, diff → file list from `git diff --name-only`)
   - `<exclusion-flags>` — rg `-g '!<pattern>'` flags derived from `.claude/codelens-exclusions.json`
3. Pass `step2Commands`, `step2Sources`, `step3Checks`, `criteriaDomains` in the agent config.

## Domain pattern commands

### security

```bash
rg --no-heading -n \
  -e 'localStorage\.(getItem|setItem)' \
  -e 'dangerouslySetInnerHTML' \
  -e 'innerHTML|outerHTML' \
  -i -e 'SECRET|PASSWORD|API_KEY|TOKEN' \
  -e 'Authorization.*Bearer' \
  <scopePath> <exclusion-flags>
```

- **Label:** `codelens:security-patterns`
- **Step 3 check id:** `security`
- **Criteria block:** `<security-criteria>` in `agents/codelens-reviewer.md`

### architecture

```bash
rg --no-heading -n \
  -e 'React\.memo|useMemo|useCallback' \
  -e '\.then\(' \
  -e 'await ' \
  -e 'export default' \
  <scopePath> <exclusion-flags>
```

- **Label:** `codelens:arch-patterns`
- **Step 3 check id:** `architecture`
- **Criteria block:** `<architecture-criteria>`

### quality

```bash
rg --no-heading -n \
  -e 'console\.log' \
  -e 'TODO|FIXME|HACK|XXX' \
  -e 'eslint-disable' \
  -e 'useState' \
  -e 'useEffect' \
  <scopePath> <exclusion-flags>
```

- **Label:** `codelens:quality-patterns`
- **Step 3 check id:** `quality`
- **Criteria block:** `<code-quality-criteria>`

### a11y

```bash
rg --no-heading -n \
  -e 'alt=' \
  -e 'aria-label' \
  -e 'aria-describedby' \
  -e 'aria-live' \
  -e 'role=' \
  -e '<img' \
  -e '<button' \
  <scopePath> <exclusion-flags>
```

- **Label:** `codelens:a11y-patterns`
- **Step 3 check id:** `a11y`
- **Criteria block:** `<accessibility-criteria>`

## Domain → command mapping summary

| Domain | Step 2 label | Step 3 check id |
|---|---|---|
| security | `codelens:security-patterns` | `security` |
| architecture | `codelens:arch-patterns` | `architecture` |
| quality | `codelens:quality-patterns` | `quality` |
| a11y | `codelens:a11y-patterns` | `a11y` |

## Optional tools (skill adds these to step2Commands conditionally)

### fallow (TS/JS only — add to step2Commands if `package.json` exists AND `quality` or `architecture` in domains)

```bash
mkdir -p .codelens && npx -y fallow dead-code --format human --quiet -o .codelens/fallow-dead-code.md 2>/dev/null || true
```
```bash
npx -y fallow dupes --format human --quiet -o .codelens/fallow-dupes.md 2>/dev/null || true
```

Labels: `codelens:fallow-deadcode`, `codelens:fallow-dupes`.

### ast-grep (add if `sg --version` succeeds AND corresponding domain in scope)

| Domain(s) | Pattern | Label |
|---|---|---|
| architecture | `sg run --pattern 'import $$$ from $MOD' --json <scopePath>` | `codelens:astgrep-imports` |
| architecture | `sg run --pattern 'class $NAME extends $BASE' --json <scopePath>` | `codelens:astgrep-classes` |
| quality | `sg run --pattern 'catch($ERR) { }' --json <scopePath>` | `codelens:astgrep-emptycatch` |
| security | `sg run --pattern 'eval($$$)' --json <scopePath>` | `codelens:astgrep-eval` |
| quality | `sg run --pattern 'var $NAME = $VALUE' --json <scopePath>` | `codelens:astgrep-var` |
| quality | `sg run --pattern '$A && $A' --json <scopePath>` | `codelens:astgrep-dupcond` |

Append `2>/dev/null || true` to each ast-grep command.

## Exclusion flags

Skills load `.claude/codelens-exclusions.json` and build `<exclusion-flags>` as a series of `-g '!<pattern>'` entries (one per pattern from `defaults` + `byDomain[<each-requested-domain>]`, minus anything in `keepInScope`). If the config file is missing, use the fallback list documented in `agents/codelens-reviewer.md` under "Default Exclusions".
