# CLAUDE.md — codelens

## Project Identity

codelens is a Claude Code plugin for multi-domain code review. It scans codebases across four domains — security, architecture, code quality, accessibility — and produces a severity-first Markdown report.

Current version: **0.0.10 (beta — no backward compatibility)**. Architecture: single agent + 2 thin skill dispatchers (`/codelens:review`, `/codelens:doctor`).

## Tech Stack

Markdown only — skills, agents, configs. No build step, no runtime dependencies, no compiled code. Everything is prompt engineering.

## Architecture

```
/codelens:review (NL-driven dispatcher, ~2.5KB)
  → reads $ARGUMENTS, infers {domains, scope, scopeTarget, outputFile}
  → AskUserQuestion fallback when bare/ambiguous
  → codelens-reviewer agent (single invocation, ~450 lines):
      Phase 0: Dependency preflight (ctx_stats only — fail-fast on missing MCP)
      Phase 0.5: Load config/custom-checks.json + config/languages.json (skip silently if absent)
      Phase 1+2: Inventory + Patterns + Risk Signals (ONE ctx_batch_execute, concurrency=8)
                → weighted hotspot selection via one ctx_execute post-processor (Risk Score)
      Phase 2.5: Doc/CVE verify (on-flag only, Context7 + WebSearch)
      Phase 3: Hotspots (ctx_batch_execute per file × 10–15, ast-grep + rg fallback, tool-driven)
      Phase 4: Compile — three STATUS gates (gates-loaded, report-ok, entry-ok) then
                Write report + append one 11-field entry to .codelens/reviews.log
```

The agent is **stateless across reviews**: no persisted intermediate JSON, no `_methodology` self-reports. Structural guarantees are encoded as imperative constraints in the agent body. **Phase 4 is the exception** — three `STATUS:` markers (`gates-loaded`, `report-ok`, `entry-ok`) must print in strict order before the entry is appended. Output drift fails loud, not silent.

**v0.0.5 optimization:** Phase 1 + Phase 2 merged into a single `ctx_batch_execute` call (1 LLM turn vs ~8 in v0.0.4). Phase 0 reduced to one `ctx_stats` call. Token budget: ~8.5K per review vs ~14K in v0.0.4 (~40% reduction).

**v0.0.6 changes:**
- **Doctor overhaul (P0):** `/codelens:doctor` now runs 13 checks (was 5). Validates every context-mode MCP tool individually (`ctx_stats`, `ctx_execute`, `ctx_execute_file`, `ctx_search`, `ctx_batch_execute`), required CLIs (`rg`, `git`), and plugin manifest. Warn-only checks for `biome`, `fallow`, `tsc`, `ast-grep`, Context7.
- **Phase 3 tool-driven (P1):** Replaced 9 embedded JS regex patterns with ast-grep commands (rg fallback). Domain filtering happens at command-construction time, not via JS ternary inside shell strings. Model reasons about tool output; no pattern matching in prompt.
- **Weighted hotspot selection (P2):** Phase 1 ranking uses Risk Score = 0.4×finding_density + 0.2×loc + 0.2×complexity + 0.2×import_centrality via 4 batched signals (`r1-loc`, `r2-finding-density`, `r3-complexity`, `r4-centrality`) + one `ctx_execute` post-processor. Drops the old LOC-only `p1-top-files` command.
- **TypeScript semantic analysis (P3):** `tsc --noEmit --skipLibCheck` added to Phase 2 batch (capped at 4KB). Mapping: TS2/TS2531/2532 → Quality High; TS6133/TS2304/2307 → Quality Medium.

## Hard Dependencies

| Dependency | Used By | Purpose |
|---|---|---|
| `rg` (ripgrep) | agent Phases 1–3 | Primary search tool, rg fallback in Phase 3. **User-installed** — native binary, not bundled. |
| context-mode MCP | agent all phases | `ctx_batch_execute`, `ctx_execute`, `ctx_execute_file`, `ctx_search`, `ctx_stats`. **Bundled** via `plugin.json` mcpServers — auto-provisions on `/plugin install codelens`. |
| Context7 MCP | agent Phase 2.5 | `resolve-library-id`, `query-docs` for doc/CVE verification. **Bundled** via `plugin.json` mcpServers. |

Optional: `biome` (lint/a11y/complexity), `fallow` (dead-code/dupes/circular-deps), `tsc` (TS semantic), `ast-grep` (AST-based Phase 3 findings) — all **auto-fetched via `npx`** on first use with a `command -v <binary>` fast-path. WebSearch (built-in, CVE lookups in Phase 2.5). Missing optional tools fall back to rg with no crash.

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
config/
  exclusions.json          # Exclusion patterns applied by agent
  presets.json             # Presets (pr-check, a11y-audit, full-audit)
  custom-checks.json       # Evidence-based company-specific checks (Part H)
  languages.json           # Multi-language mechanism: JS/TS populated, Python/PHP placeholders (Part I)
templates/                   # Output contracts (agent-loaded at Phase 4)
  report.md                  # Markdown report template (placeholder skeleton)
  reviews-entry.json         # Flat 11-field entry shape for .codelens/reviews.log (schema required, v1)
  README.md                  # Abstraction rules + translation maps (applies to both contracts)
references/                  # Local-only design references (gitignored — not shipped)
  codebase-analyzer.md         # Structural pattern the agent body follows
.claude/
  settings.local.json      # User-local Claude Code settings (MCP allowlist)
.codelens/                 # Runtime state (gitignored)
  reviews.log              # Append-only review log (11-field flat entries, one per line)
scripts/
  bench-phase.sh           # Benchmark harness for prompt-cost measurement
  bench-mcp-settings.json  # MCP allowlist for headless bench runs
  validate-entry.js        # Gate G3 — validates reviews.log entry shape
  validate-report.sh       # Gate G2 — validates markdown report structure
  validate-custom-checks.js # Validates config/custom-checks.json schema (Part H)
archive/                   # Prior-version artifacts (shipped for decision-history reference)
  agents/                  # Superseded agent bodies from v1.x
  reports/                 # Prior-version design docs
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
- **Exclusions honored** — read `config/exclusions.json` in Phase 2's first sub-step.
- **Append-only log** — every review appends one entry to `.codelens/reviews.log` after all three Phase 4 `STATUS:` markers print. Entry has 11 fields (`ts`, `scope`, `crit`, `high`, `med`, `low`, `info`, `report`, `v`, `tokIn`, `tokOut`) plus required `schema` (current: `"1"`).

## Common Workflows

### Add a new pattern check

1. **Phase 2 (broad scan):** Add the `rg` command to the Phase 2 `ctx_batch_execute` block in `agents/codelens-reviewer.md`. Update the `queries` array so the finding can be retrieved.
2. **Phase 3 (per-hotspot verification):** Prefer ast-grep over rg when AST structure matters. Add the command to the relevant domain branch in Phase 3's `cmds.push(...)` block (built dynamically per `config.domains`). Always pair ast-grep with `|| rg ...` fallback.
3. Add the evaluation logic to the relevant `<*-criteria>` block.
4. Test by running `/codelens:review <domain>` on a codebase that has the pattern.

### Modify the report format

Edit `templates/report.md` (the template — includes a fully-worked example at the bottom for pattern-matching).

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

`/plugin install codelens` auto-provisions both MCP servers (context-mode, Context7) via the `mcpServers` block in `plugin.json`. The four npm CLIs (biome, fallow, tsc, ast-grep) auto-fetch via `npx` on first use. Only `rg` (ripgrep) remains user-installed — it's a native binary that can't be bundled.

## v0.0.10 changes (beta — no backward compatibility)

- **Self-contained install**: `mcpServers` block in `plugin.json` provisions context-mode + Context7 on install; `permissions.allow` block eliminates per-review Bash prompts; npm CLIs auto-fetch via `npx` with `command -v <binary>` fast-path.
- **Config-driven extensibility**: `config/custom-checks.json` ships (evidence-based company-specific checks); `config/languages.json` ships (multi-language mechanism — JS/TS fully populated, Python/PHP placeholders for follow-up PRs).
- **Stack-aware doctor**: detects project stack (js-ts/python/php/go/rust) and `[SKIP]`s tool checks that don't apply.
- **Token efficiency**: agent prompt ≥25% smaller (shared `<severity-ladder>`, trimmed `<constraints>` overlap, enumerated Phase 2.5 triggers, deterministic Phase 3 queries).
- **Schema required**: `reviews.log` entries require `schema: "1"`; `reviews.log` is the canonical shape (no migration prose).
- **Diff-scope fix**: `scopePath` for diff scope no longer word-splits (PID-suffixed temp file + `rg --files-from`).
- **Doc drift fixed**: every primary doc reflects the actual 11-field shape and the three Phase 4 gates.
