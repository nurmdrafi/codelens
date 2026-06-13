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

3. If your check needs a new ripgrep pattern, add it to the relevant domain's pattern command in Step 2's `ctx_batch_execute` block (conditionally included when the domain is requested).

4. If the check needs Step 3 deep-dive verification, add a matching check to the processing code template in Step 3.

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
2. Pattern command added to Step 2's `ctx_batch_execute` (conditionally included when the domain is requested)
3. Domain checks added to Step 3's processing code template
4. New skill at `skills/review-<yourdomain>/SKILL.md` as a thin dispatch wrapper
5. Optionally add a preset to `.claude/review-presets.json`

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
  codelens-reviewer.md     # Single domain-aware agent (scans, analyzes, compiles)
                           # Contains <security-criteria>, <architecture-criteria>,
                           # <code-quality-criteria>, <accessibility-criteria> blocks
                           # plus the 4-step workflow
skills/
  review/SKILL.md          # /codelens:review — full multi-domain
  review-security/SKILL.md     # /codelens:review-security
  review-architecture/SKILL.md # /codelens:review-architecture
  review-quality/SKILL.md      # /codelens:review-quality
  review-a11y/SKILL.md         # /codelens:review-a11y
  review-pr/SKILL.md           # /codelens:review-pr (diff scope)
  help/SKILL.md                # /codelens:help
  _shared/report-template.md   # Report format single-source-of-truth
  _shared/setup-check.md       # Dependency gate
.claude/
  review-presets.json      # Default presets (pr-check, a11y-audit, full-audit)
  codelens-exclusions.json # Exclusion patterns
docs/
  pipeline-diagram.md          # Developer-facing pipeline diagram (mermaid)
  superpowers/
    plan-single-agent-collapse.md # Why we collapsed from 6 agents to 1
CLAUDE.md                  # Project instructions for Claude Code
```
