# CLAUDE.md — codelens

## Project Identity

codelens is a Claude Code plugin for multi-domain code review. It scans codebases across four domains — security, architecture, code quality, accessibility — and produces a severity-first Markdown report.

Current version: **0.0.1 (beta)**. Architecture: single agent + 7 thin skill dispatchers.

## Tech Stack

Markdown only — skills, agents, configs. No build step, no runtime dependencies, no compiled code. Everything is prompt engineering.

## Architecture

```
/codelens:* skill (thin dispatcher, 0.7–2.4KB)
  → emits {domains, scope, scopeTarget, outputFile}
  → codelens-reviewer agent (single invocation, ~400 lines):
      Phase 0: ctx_stats (mandatory first call)
      Phase 1: Inventory (ctx_batch_execute: rg --files, wc -l, top-30)
      Phase 2: Patterns (ctx_batch_execute: per-domain rg commands, filtered by config.domains)
      Phase 2.5: Doc/CVE verify (on-flag only, Context7 + WebSearch)
      Phase 3: Hotspots (ctx_execute_file × 10–15, single-pass, all domains per file)
      Phase 4: Compile (Write report + append to .codelens/reviews.json)
```

The agent is **stateless**: no persisted intermediate JSON, no checkpoints, no `_methodology` self-reports. Structural guarantees are encoded as imperative constraints in the agent body (matching `references/codebase-analyzer.md`).

## Hard Dependencies

| Dependency | Used By | Purpose |
|---|---|---|
| `rg` (ripgrep) | agent Phases 1–2 | Primary search tool via Bash |
| context-mode MCP | agent all phases | `ctx_batch_execute`, `ctx_execute_file`, `ctx_search`, `ctx_stats` |
| Context7 MCP | agent Phase 2.5 | `resolve-library-id`, `query-docs` for doc/CVE verification |

Optional: WebSearch (built-in) for CVE lookups in Phase 2.5.

## File Map

```
.claude-plugin/
  plugin.json              # Plugin manifest
  marketplace.json         # Marketplace listing
skills/
  review/SKILL.md          # /codelens:review (multi-domain, picker)
  review-security/SKILL.md # /codelens:review-security
  review-architecture/SKILL.md
  review-quality/SKILL.md
  review-a11y/SKILL.md
  review-pr/SKILL.md       # /codelens:review-pr (diff scope)
  doctor/SKILL.md          # /codelens:doctor (setup diagnostics)
agents/
  codelens-reviewer.md     # The single agent
.claude/
  codelens-exclusions.json # Exclusion patterns applied by agent
  review-presets.json      # Presets (pr-check, a11y-audit, full-audit)
examples/
  sample-report.md
references/                # Source-of-truth docs (gitignored)
```

## Conventions

### Agent Frontmatter

```yaml
---
name: agent-name
description: |
  When to use this agent...
  <example> blocks for trigger matching
tools: ["Read", "Write", "Bash", ...MCP tools]
color: green|yellow|red|cyan
---
```

### Skill Frontmatter

```yaml
---
name: skill-name
description: |
  Use when [trigger conditions]...
user-invocable: true
argument-hint: "[args]"
---
```

## Constraints

The `codelens-reviewer` agent obeys these structural rules (encoded as `<constraints>` prose, not runtime gates):

- **Single-pass file reads** — track hotspot files, never re-read.
- **Domain-aware** — only run commands and report sections for domains in `config.domains`.
- **Scope-aware** — every rg command targets the resolved `scopePath`.
- **rg over Glob/Grep** — always.
- **ctx_batch_execute** for Phases 1–2 — never sequential Bash.
- **ctx_execute_file** for Phase 3 — never raw Read of source files.
- **ctx_stats first** — agent's first tool call must be `ctx_stats`.
- **Severity-first ordering** — Critical > High > Medium > Low > Informational.
- **Evidence-backed** — every finding has file path, line number, snippet.
- **Cross-domain dedup** — same `file:line` (±2 lines) across domains merges into one row.
- **Exclusions honored** — read `.claude/codelens-exclusions.json` in Phase 2's first sub-step.
- **Append-only log** — every review appends one entry to `.codelens/reviews.json` (6 fields).

## Common Workflows

### Add a new pattern check

1. Add the `rg` command to the relevant domain's section in `agents/codelens-reviewer.md` Phase 2.
2. Add the evaluation logic to the relevant `<*-criteria>` block.
3. If the pattern needs Step 3 deep-dive verification, add a check to the `ctx_execute_file` processing code in Phase 3.
4. Test by running `/codelens:review-<domain>` on a codebase that has the pattern.

### Modify the report format

Edit the report template inline in `agents/codelens-reviewer.md` Phase 4. There is no separate `report-template.md` file (folded in v0.0.1).

### Release a new version

1. Update the version header in `CHANGELOG.md` (e.g., add `## [0.0.2] - YYYY-MM-DD`).
2. Update `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` versions.
3. Commit: `git commit -m "chore: bump version to X.Y.Z"`.
4. Push: `git push origin main`.
5. The GitHub Actions workflow (`.github/workflows/release.yml`) extracts the version + release notes from CHANGELOG.md and creates a GitHub Release.

## Plugin Marketplace

Users install via:
```
/plugin marketplace add nurmdrafi/codelens
/plugin install codelens
```
