# CLAUDE.md — codelens

## Project Identity

codelens is a Claude Code plugin for multi-domain code review. It scans codebases across four domains — security, architecture, code quality, accessibility — and produces a severity-first Markdown report.

Current version: **0.0.7 (beta)**. Architecture: single agent + 2 thin skill dispatchers (`/codelens:review`, `/codelens:doctor`).

## Tech Stack

Markdown only — skills, agents, configs. No build step, no runtime dependencies, no compiled code. Everything is prompt engineering.

## Architecture

```
/codelens:review (NL-driven dispatcher, ~2.5KB)
  → reads $ARGUMENTS, infers {domains, scope, scopeTarget, outputFile}
  → AskUserQuestion fallback when bare/ambiguous
  → codelens-reviewer agent (single invocation, ~310 lines):
      Phase 0: Dependency preflight (ctx_stats only — fail-fast on missing MCP)
      Phase 1+2: Inventory + Patterns + Risk Signals (ONE ctx_batch_execute, concurrency=8)
                → weighted hotspot selection via one ctx_execute post-processor (Risk Score)
      Phase 2.5: Doc/CVE verify (on-flag only, Context7 + WebSearch)
      Phase 3: Hotspots (ctx_batch_execute per file × 10–15, ast-grep + rg fallback, tool-driven)
      Phase 4: Compile (Write report + append to .codelens/reviews.json)
```

The agent is **stateless**: no persisted intermediate JSON, no checkpoints, no `_methodology` self-reports. Structural guarantees are encoded as imperative constraints in the agent body (matching `references/codebase-analyzer.md`).

**v0.0.5 optimization:** Phase 1 + Phase 2 merged into a single `ctx_batch_execute` call (1 LLM turn vs ~8 in v0.0.4). Phase 0 reduced to one `ctx_stats` call. Token budget: ~8.5K per review vs ~14K in v0.0.4 (~40% reduction).

**v0.0.6 changes:**
- **Doctor overhaul (P0):** `/codelens:doctor` now runs 13 checks (was 5). Validates every context-mode MCP tool individually (`ctx_stats`, `ctx_execute`, `ctx_execute_file`, `ctx_search`, `ctx_batch_execute`), required CLIs (`rg`, `git`), and plugin manifest. Warn-only checks for `biome`, `fallow`, `tsc`, `ast-grep`, Context7.
- **Phase 3 tool-driven (P1):** Replaced 9 embedded JS regex patterns with ast-grep commands (rg fallback). Domain filtering happens at command-construction time, not via JS ternary inside shell strings. Model reasons about tool output; no pattern matching in prompt.
- **Weighted hotspot selection (P2):** Phase 1 ranking uses Risk Score = 0.4×finding_density + 0.2×loc + 0.2×complexity + 0.2×import_centrality via 4 batched signals (`r1-loc`, `r2-finding-density`, `r3-complexity`, `r4-centrality`) + one `ctx_execute` post-processor. Drops the old LOC-only `p1-top-files` command.
- **TypeScript semantic analysis (P3):** `tsc --noEmit --skipLibCheck` added to Phase 2 batch (capped at 4KB). Mapping: TS2/TS2531/2532 → Quality High; TS6133/TS2304/2307 → Quality Medium.

## Hard Dependencies

| Dependency | Used By | Purpose |
|---|---|---|
| `rg` (ripgrep) | agent Phases 1–3 | Primary search tool, rg fallback in Phase 3 |
| context-mode MCP | agent all phases | `ctx_batch_execute`, `ctx_execute`, `ctx_execute_file`, `ctx_search`, `ctx_stats` |
| Context7 MCP | agent Phase 2.5 | `resolve-library-id`, `query-docs` for doc/CVE verification |

Optional: `biome` (lint/a11y/complexity), `fallow` (dead-code/dupes/circular-deps), `tsc` (TS semantic), `ast-grep` (AST-based Phase 3 findings), WebSearch (built-in, CVE lookups in Phase 2.5). Missing optional tools fall back to rg with no crash.

## File Map

```
.claude-plugin/
  plugin.json              # Plugin manifest
  marketplace.json         # Marketplace listing
skills/
  review/SKILL.md          # /codelens:review (single entry point, NL-driven)
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
- **Domain-aware** — only run commands and report sections for domains in `config.domains`. Phase 3 filters ast-grep commands at construction time, not via JS inside shell strings.
- **Scope-aware** — every rg command targets the resolved `scopePath`.
- **rg over Glob/Grep** — always.
- **ctx_batch_execute** for non-rg Phase 1–2 commands — rg uses native Bash (v0.0.2 fix).
- **ctx_batch_execute** for Phase 3 ast-grep/rg fallback — per hotspot, domain-filtered command list.
- **ctx_stats first** — agent's first Phase 0 call is `ctx_stats` (preceded only by `rg --version` preflight).
- **Risk-scored hotspots** — Phase 1 produces top 15 by Risk Score (density + complexity + centrality + loc), not LOC-only.
- **Tool-driven findings** — Phase 3 sources findings from ast-grep + biome + tsc + fallow + rg; no JS regex in the prompt.
- **Severity-first ordering** — Critical > High > Medium > Low > Informational.
- **Evidence-backed** — every finding has file path, line number, snippet.
- **Cross-domain dedup** — same `file:line` (±2 lines) across domains merges into one row.
- **Exclusions honored** — read `.claude/codelens-exclusions.json` in Phase 2's first sub-step.
- **Append-only log** — every review appends one entry to `.codelens/reviews.json` (6 fields).

## Common Workflows

### Add a new pattern check

1. **Phase 2 (broad scan):** Add the `rg` command to the Phase 2 `ctx_batch_execute` block in `agents/codelens-reviewer.md`. Update the `queries` array so the finding can be retrieved.
2. **Phase 3 (per-hotspot verification):** Prefer ast-grep over rg when AST structure matters. Add the command to the relevant domain branch in Phase 3's `cmds.push(...)` block (built dynamically per `config.domains`). Always pair ast-grep with `|| rg ...` fallback.
3. Add the evaluation logic to the relevant `<*-criteria>` block.
4. Test by running `/codelens:review <domain>` on a codebase that has the pattern.

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
