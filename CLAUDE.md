# CLAUDE.md — codelens

## Project Identity

codelens is an open-source Claude Code plugin for multi-domain code review. It scans codebases across four domains — security, architecture, code quality, and accessibility — and produces a severity-first report with actionable findings.

## Origin

This project evolved through three stages:
1. **4 separate agents** — `security-auditor`, `architect-reviewer`, `code-reviewer`, `accessibility-reviewer` (see `references/` for originals)
2. **Merged into one** — `full-codebase-reviewer.md` combined all four into a single monolithic agent
3. **Decomposed into pipeline** — current architecture: 3-phase pipeline with 6 agents + 1 skill

The pipeline design saves tokens by reading files once (Phase A) and sharing extraction data across domain reviewers (Phase B).

## Tech Stack

Markdown-based agents and skills. No build step, no runtime dependencies, no compiled code. Everything is prompt engineering — markdown files that instruct Claude agents.

## Architecture

```
Phase A: codelens-scanner (single-pass extraction)
  → rg pattern scan + hotspot deep-dive
  → writes .claude-review/extraction.json

Phase B: 4 domain reviewers (parallel, read extraction.json only)
  → security-reviewer, architecture-reviewer, code-quality-reviewer, accessibility-reviewer
  → each writes .claude-review/findings/<domain>.json

Phase C: codelens-reviewer (orchestrator)
  → cross-domain dedup, severity sort, report compilation
  → writes CODEBASE_ANALYSIS_REPORT.md or PR_REVIEW_<range>.md
```

## Hard Dependencies

These are NOT optional. All must be installed and configured:

| Dependency | Used By | Purpose |
|---|---|---|
| **`rg` (ripgrep)** | scanner, all Phase B agents | Primary search tool. Always prefer `rg` over `grep`, `find`, or `Glob`. |
| **context-mode MCP** | codelens-scanner | Sandboxed extraction (`ctx_batch_execute`, `ctx_execute_file`) prevents context flooding |
| **Context7 MCP** | security, architecture, code-quality reviewers | Library version verification, CVE checks, deprecated API detection |

## File Map

```
.claude-plugin/
  plugin.json              # Plugin manifest (name, version, author, skills path)
  marketplace.json         # Marketplace listing metadata
skills/
  review/
    SKILL.md               # /review command: parsing, guided mode, setup-check, help, report template
agents/
  codelens-scanner.md      # Phase A: single-pass extraction
  codelens-reviewer.md     # Orchestrator: dispatch + compile
  security-reviewer.md     # Phase B: OWASP Top 10
  architecture-reviewer.md # Phase B: SOLID, patterns, dependencies
  code-quality-reviewer.md # Phase B: complexity, duplication, async
  accessibility-reviewer.md# Phase B: WCAG 2.1 AA
.claude/
  review-presets.json      # Default presets (pr-check, a11y-audit, full-audit)
examples/
  sample-report.md         # Anonymized real report for README
references/                # (gitignored) Original agents, execution plan, sample data
```

## Conventions

### Agent Frontmatter
```yaml
---
name: agent-name
description: |
  When to use this agent...
  <example> blocks for trigger matching
tools: ["Read", "Write", "Bash", "Glob", "Grep", ...MCP tools]
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

### Tools in Frontmatter
Always list ALL tools the agent needs. The runtime grants access based on this list. Missing tools = agent can't use them. Include:
- Native: `Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `WebSearch`
- context-mode: `mcp__plugin_context-mode_context-mode__ctx_batch_execute`, `ctx_execute_file`, `ctx_execute`, `ctx_index`, `ctx_search`, `ctx_fetch_and_index`
- Context7: `mcp__plugin_context7_context7__resolve-library-id`, `mcp__plugin_context7_context7__query-docs`

## Constraints

Every agent in this pipeline follows these rules:
- **Severity-first ordering** — findings are Critical > High > Medium > Low > Informational, never grouped by domain
- **Single-pass reading** — files are read at most once by the scanner; Phase B agents read extraction.json, not source files
- **rg over Glob** — always prefer `rg` (ripgrep) over `Glob` for codebase searches
- **ctx_batch_execute** — always batch multiple analysis commands, never run sequentially
- **ctx_execute_file** — never load raw file contents into context for analysis
- **Evidence-backed findings** — every finding must have file path, line number, code snippet
- **Cross-domain dedup** — same file:line (±2 lines) across domains → merge into single row

## Common Workflows

### Add a new pattern check
1. Add the `rg` pattern to `agents/codelens-scanner.md` in the combined pattern list (tagged by domain)
2. Add the evaluation logic to the relevant Phase B agent's criteria section
3. Test by running `/review <domain>` on a codebase that has the pattern

### Add a new domain
1. Create `agents/<domain>-reviewer.md` with frontmatter, dependencies, criteria, analysis process, output format
2. Add domain patterns to `agents/codelens-scanner.md` combined pattern list
3. Register in `agents/codelens-reviewer.md` domain dispatch table
4. Add to `skills/review/SKILL.md` command parsing table

### Modify the report format
Edit the report template section in `skills/review/SKILL.md`. The orchestrator reads this template when compiling.

### Test locally
Copy `agents/` and `skills/` into a test project's `.claude/` dir, then run `/review` variants.

## Plugin Marketplace

Users install via:
```
/plugin marketplace add nurmdrafi/codelens
/plugin install codelens
```

The marketplace.json at repo root is the marketplace manifest. The plugin.json inside .claude-plugin/ is the plugin manifest.
