# Contributing to codelens

Thank you for contributing! This guide covers how to add patterns, test changes, and submit PRs.

## Quick Start

1. Fork and clone the repo
2. Edit agent/skill files (they're markdown — no build step)
3. Test locally (see below)
4. Submit a PR

## Adding a New Pattern Check

Each domain agent has a criteria section listing what it checks for. To add a new check:

1. Open the relevant agent file:
   - `agents/security-reviewer.md` — security patterns
   - `agents/architecture-reviewer.md` — architecture patterns
   - `agents/code-quality-reviewer.md` — code quality patterns
   - `agents/accessibility-reviewer.md` — accessibility patterns

2. Add your check to the criteria section with:
   - **What to check** — specific pattern or anti-pattern
   - **Why it matters** — the risk or impact
   - **Severity guidance** — when is it Critical vs Low

3. If your check needs a new ripgrep pattern, add it to `agents/codelens-scanner.md` in the "All patterns to scan" section. Tag it with the correct domain.

4. Test your change (see below).

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

## Reporting Issues

### False Positives
If codelens reports a finding that isn't actually an issue:
- Open an issue with the label `false-positive`
- Include: the finding (title, location, evidence), why it's incorrect, and what the correct behavior should be

### Missing Patterns
If codelens misses something it should catch:
- Open an issue with the label `missing-pattern`
- Include: the pattern it should detect, a code example, which domain it belongs to, and expected severity

### New Domain Proposals
If you want to add a new review domain (e.g., performance, i18n, SEO):
- Open an issue with the label `new-domain`
- Include: domain name, criteria checklist, severity classification rules, example patterns to detect

## PR Guidelines

- Keep PRs focused — one feature or fix per PR
- Test against a real codebase before submitting
- Include a description of what changed and why
- If modifying report format, include a sample output snippet

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
```
