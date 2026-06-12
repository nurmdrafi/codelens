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

Each domain agent has a criteria section listing what it checks for. To add a new check:

1. Open the relevant agent file:
   - `agents/security-reviewer.md` — security patterns (OWASP)
   - `agents/architecture-reviewer.md` — architecture patterns (SOLID)
   - `agents/code-quality-reviewer.md` — code quality patterns
   - `agents/accessibility-reviewer.md` — accessibility patterns (WCAG)

2. Add your check to the criteria section with:
   - **What to check** — specific pattern or anti-pattern
   - **Why it matters** — the risk or impact
   - **Severity guidance** — when is it Critical vs Low

3. If your check needs a new ripgrep pattern, add it to `agents/codelens-scanner.md` in the "All patterns to scan" section. Tag it with the correct domain.

4. Test your change (see below).

## Proposing a New Domain

To add an entirely new review domain (e.g., performance, i18n, SEO), open an issue at [github.com/nurmdrafi/codelens/issues](https://github.com/nurmdrafi/codelens/issues) with the label `new-domain` and include:

1. **Domain name** — short identifier (e.g., `performance`, `i18n`)
2. **Criteria checklist** — specific checks the domain covers, with severity rules
3. **Example patterns** — 5-10 ripgrep patterns the scanner should detect
4. **Classification system** — how findings are categorized (e.g., OWASP for security, WCAG for accessibility)
5. **Expected output** — what a typical finding looks like (title, location, evidence, impact, fix)

After discussion, the domain is implemented as:
1. New agent: `agents/<domain>-reviewer.md`
2. Scanner patterns added to `agents/codelens-scanner.md`
3. Domain registered in `agents/codelens-reviewer.md` dispatch table
4. Command parsing updated in `skills/review/SKILL.md`

## Testing Locally

The easiest way to test changes:

1. Copy the `agents/` and `skills/` directories into a test project's `.claude/` directory:
   ```bash
   cp -r agents/ /path/to/test-project/.claude/
   cp -r skills/ /path/to/test-project/.claude/
   ```

2. In the test project, run review commands:
   ```
   /review all                    # Full audit
   /review security               # Single domain
   /review pr-check               # Preset
   /review all src/specific-path  # Path scope
   ```

3. Verify the report:
   - Does your new pattern appear in findings?
   - Is the severity correct?
   - Is the evidence accurate (file path, line number, code snippet)?
   - Does the fix suggestion make sense?

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

The `references/` directory (gitignored, not shipped with the plugin) contains the original agents and execution plan that codelens was built from. Useful for understanding the design decisions:

- `references/full-codebase-reviewer.md` — the monolithic agent that was decomposed into the pipeline
- `references/security-auditor.md`, `architect-reviewer.md`, `code-reviewer.md`, `accessibility-reviewer.md` — the original 4 separate agents
- `references/EXECUTION_PLAN.md` — the detailed design document for the 3-phase pipeline

## File Structure Reference

```
agents/
  codelens-scanner.md      # Phase A — patterns go here
  codelens-reviewer.md     # Orchestrator — report compilation
  security-reviewer.md     # Security criteria + analysis
  architecture-reviewer.md # Architecture criteria + analysis
  code-quality-reviewer.md # Code quality criteria + analysis
  accessibility-reviewer.md # Accessibility criteria + analysis
skills/
  review/
    SKILL.md               # /review command + report template
.claude/
  review-presets.json      # Default presets
CLAUDE.md                  # Project instructions for Claude Code
```
