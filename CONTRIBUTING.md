# Contributing to codelens

Thank you for contributing to codelens! This guide covers how to set up your development environment, make changes, and submit PRs.

## Development Prerequisites

Before working on codelens, ensure you have:

| Tool | Install |
|------|---------|
| [Claude Code](https://claude.ai/code) | CLI, desktop app, or IDE extension |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) | `brew install ripgrep` or `apt install ripgrep` |
| [Context7 MCP](https://github.com/nurmdrafi/codelens) | `/plugin install context7` |
| [context-mode MCP](https://github.com/mksglu/context-mode) | `/plugin marketplace add mksglu/context-mode` then `/plugin install context-mode` |

## Quick Start

1. Fork and clone the repo
2. Edit agent/skill files (they're markdown — no build step needed)
3. Test locally (see below)
4. Submit a PR

## Branching Strategy

- Branch from `main`
- Use descriptive branch names with prefixes:
  - `feat/add-performance-domain` — new features
  - `fix/false-positive-console-log` — bug fixes
  - `docs/improve-troubleshooting` — documentation changes
- Keep PRs focused — one feature or fix per PR

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add performance domain reviewer
fix: remove false positive on test file console.log
docs: add troubleshooting section to README
```

## Adding a New Pattern Check

The single `codelens-reviewer` agent has a `<*-criteria>` block per domain. To add a new check:

1. Open `agents/codelens-reviewer.md` and find the relevant criteria block:
   - `<security-criteria>` — security patterns (OWASP)
   - `<architecture-criteria>` — architecture patterns (SOLID)
   - `<code-quality-criteria>` — code quality patterns
   - `<accessibility-criteria>` — accessibility patterns (WCAG)

2. Add your check to that block with:
   - **What to check** — specific pattern or anti-pattern
   - **Why it matters** — the risk or impact
   - **Severity guidance** — when is it Critical vs Low

3. If your check needs a new ripgrep pattern, add it to the relevant domain's pattern command in Phase 2's rg block (conditionally included when the domain is requested).

4. If the check needs Phase 3 deep-dive verification, add a matching check to the processing code template in Phase 3.

5. Test your change (see below).

## Proposing a New Domain

To add an entirely new review domain (e.g., performance, i18n, SEO), open an issue at [github.com/nurmdrafi/codelens/issues](https://github.com/nurmdrafi/codelens/issues) with the label `new-domain` and include:

1. **Domain name** — short identifier (e.g., `performance`, `i18n`)
2. **Criteria checklist** — specific checks the domain covers, with severity rules
3. **Example patterns** — 5-10 ripgrep patterns the agent should detect
4. **Classification system** — how findings are categorized (e.g., OWASP for security, WCAG for accessibility)
5. **Expected output** — what a typical finding looks like (title, location, evidence, impact, fix)

After discussion, the domain is implemented as:
1. New `<yourdomain-criteria>` block in `agents/codelens-reviewer.md`
2. Pattern command added to Phase 2's rg block (conditionally included when the domain is requested)
3. Domain checks added to Phase 3's processing code template
4. Optionally add a preset to `config/presets.json`

Users then invoke the new domain via `/codelens:review <yourdomain>` — no new skill file needed.

## Testing Locally

There are two ways to test codelens against a real codebase. The `--plugin-dir` flag is the recommended primary method — it loads the plugin for one session with no install, no copy, and no marketplace state. The `cp -r` fallback is for older Claude Code versions that lack `--plugin-dir`.

### Method 1 (recommended): `--plugin-dir` flag

Loads the plugin from its source directory for the current session only. No install, no copy, no `.claude/` modifications in the target repo. Works for both interactive and headless (`-p`) sessions.

```bash
# 1. (optional) validate the plugin manifest before launching
claude plugin validate /path/to/codelens

# 2. launch Claude Code from INSIDE the target repo with the plugin loaded
cd /path/to/test-project
claude --plugin-dir /path/to/codelens

# 3. inside Claude Code, invoke skills namespaced as /<plugin-name>:<skill-name>
/codelens:doctor                       # setup diagnostics — run this first
/codelens:review                       # full audit (bare → AskUserQuestion picker)
/codelens:review security              # single domain
/codelens:review pr-check              # preset (security + quality, diff scope)
/codelens:review all src/specific-path # path scope
/codelens:review the PR                # diff scope

# 4. after editing plugin files (hot reload — no restart needed)
/reload-plugins

# 5. debug plugin-loading issues on next launch
claude --debug --plugin-dir /path/to/codelens
```

Notes:
- Plugin name comes from `.claude-plugin/plugin.json` → `name: "codelens"`. Rename the field and the `/codelens:...` prefix changes accordingly.
- Skills are at `skills/<name>/SKILL.md`. Agents are auto-discovered from `agents/`. MCP servers from `.mcp.json` (codelens ships none — it relies on the user-installed context-mode and Context7 MCPs).
- The target repo's `.claude/settings.local.json` controls MCP tool permissions. codelens's Phase 0–3 phases call context-mode + Context7 MCPs, so those tools must be in the target's allowlist (or approved on first use).

#### Headless smoke testing

For automated smoke tests against a target repo without an interactive session, use `claude -p` (print mode). Output goes to stdout, exit code reflects success. Useful for CI or scripted test runs:

```bash
cd /path/to/test-project

# run the full audit headlessly, capture output to a log
claude --plugin-dir /path/to/codelens -p '/codelens:review' 2>&1 | tee smoke-test.log

# single domain, fast iteration on a pattern you're developing
claude --plugin-dir /path/to/codelens -p '/codelens:review security'

# stream-json output for programmatic parsing
claude --plugin-dir /path/to/codelens -p --output-format json '/codelens:review' > result.json
```

### Method 2 (fallback): copy into `.claude/`

For Claude Code versions without `--plugin-dir`, copy `agents/` and `skills/` into the target repo's `.claude/` directory. This is more invasive — it writes into the target repo and requires a re-copy after every change.

```bash
# 1. copy the plugin files into the target's .claude/ directory
cp -r /path/to/codelens/agents/ /path/to/test-project/.claude/
cp -r /path/to/codelens/skills/ /path/to/test-project/.claude/

# 2. launch Claude Code normally — skills are auto-discovered
cd /path/to/test-project
claude

# 3. invoke as Method 1 (commands are identical once loaded)
/codelens:review
```

⚠️ **Caveats:**
- If the target repo already has `.claude/settings.local.json`, do not overwrite it — only merge the codelens MCP permissions in.
- After every edit to codelens source, re-copy the changed files (`cp -r` again) since the target's `.claude/` is a snapshot.
- Clean up: `rm -rf /path/to/test-project/.claude/agents/codelens-reviewer.md /path/to/test-project/.claude/skills/{review,doctor}` when finished.

### Verifying the report

Regardless of method, after `/codelens:review` completes check:
- Does your new pattern appear in findings?
- Is the severity correct?
- Is the evidence accurate (file path, line number, code snippet)?
- Does the fix suggestion make sense?
- For the reviews log: did `.codelens/reviews.json` get one entry appended with the expected 6 fields (`timestamp`, `scope`, `summary`, `findings`, `reportPath`, `reviewerVersion`)?

### Edge Cases to Test

- **Empty/small repos** — should complete with "no findings" or minimal findings
- **Non-JS/TS codebases** — Python, Go, Ruby files should still produce pattern matches
- **Large files** — scanner should handle 500+ line files without errors
- **Diff scope** — `pr-check` should only flag issues in changed files

## Reporting Issues

Open an issue at [github.com/nurmdrafi/codelens/issues](https://github.com/nurmdrafi/codelens/issues):

### False Positives
If codelens reports a finding that isn't actually an issue:
- Label: `false-positive`
- Include: the finding (title, location, evidence), why it's incorrect, what the correct behavior should be

### Missing Patterns
If codelens misses something it should catch:
- Label: `missing-pattern`
- Include: the pattern it should detect, a code example, which domain it belongs to, expected severity

## PR Guidelines

- Keep PRs focused — one feature or fix per PR
- Test against a real codebase before submitting
- Include a description of what changed and why
- If modifying report format, include a sample output snippet
- Follow commit conventions (see above)

## Background Reading

The `archive/` directory contains the original agents and design docs that codelens was built from. Useful for understanding the design decisions:

- `archive/agents/full-codebase-reviewer.md` — the monolithic agent that was decomposed into the pipeline
- `archive/agents/security-auditor.md`, `architect-reviewer.md`, `code-reviewer.md`, `accessibility-reviewer.md` — the original 4 separate agents
- `archive/reports/codelens-reviewer-refactor-spec-v3-addendum.md` — prior-version multi-stack refactor design (deferred)
- `archive/reports/codelens-reviewer-tool-validation.md` — prior-version tool-validation work

## File Structure Reference

```
agents/
  codelens-reviewer.md     # Single domain-aware agent (scans, analyzes, compiles)
                           # Contains <security-criteria>, <architecture-criteria>,
                           # <code-quality-criteria>, <accessibility-criteria> blocks
                           # plus the 5-phase workflow (Phase 0 preflight → Phase 4 report)
skills/
  review/SKILL.md              # /codelens:review — single NL-driven entry point (all domains + scopes)
  doctor/SKILL.md              # /codelens:doctor (setup diagnostics)
config/
  presets.json                 # Default presets (pr-check, a11y-audit, full-audit)
  exclusions.json              # Exclusion patterns (defaults + byDomain + keepInScope)
templates/                       # Output contracts (agent-loaded at Phase 4)
  report.md                    # Markdown report template (placeholder skeleton)
  reviews-entry.json           # Minimal 6-field entry shape for .codelens/reviews.json
  README.md                    # Abstraction rules + translation maps
.claude-plugin/
  plugin.json                  # Plugin manifest
  marketplace.json             # Marketplace listing
references/                       # Local-only design references (gitignored)
  codebase-analyzer.md             # Structural pattern the agent body follows
scripts/
  bench-phase.sh               # Benchmark harness
  bench-mcp-settings.json      # MCP allowlist for headless bench runs
archive/                       # Prior-version artifacts (shipped for reference)
  agents/                      # Superseded agent bodies from v1.x
  reports/                     # Prior-version design docs
docs/
  smoke-tests/                 # End-to-end test runs (reference for refactoring)
CLAUDE.md                  # Project instructions for Claude Code
```
