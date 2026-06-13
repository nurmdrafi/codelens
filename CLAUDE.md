# CLAUDE.md — codelens

## Project Identity

codelens is an open-source Claude Code plugin for multi-domain code review. It scans codebases across four domains — security, architecture, code quality, and accessibility — and produces a severity-first report with actionable findings.

## Origin

This project evolved through four stages:
1. **4 separate agents** — `security-auditor`, `architect-reviewer`, `code-reviewer`, `accessibility-auditor` (see `references/` for originals)
2. **Merged into one** — `full-codebase-reviewer.md` combined all four into a single monolithic agent
3. **Decomposed into pipeline** — 3-phase pipeline with 6 agents (scanner + 4 reviewers + orchestrator)
4. **Collapsed back to single agent** — current architecture: one domain-aware `codelens-reviewer` agent + 7 thin skill wrappers

Stage 4 reverted to stage 2's single-agent model after Anthropic's own engineering guidance confirmed multi-agent systems use ~15× more tokens and are a poor fit for coding tasks where all agents share the same file context. The single agent preserves the one thing the monolith lacked — domain-awareness (the input `domains` array lets `/codelens:review-security` cost roughly 1/3 of a full review).

## Tech Stack

Markdown-based agents and skills. No build step, no runtime dependencies, no compiled code. Everything is prompt engineering — markdown files that instruct Claude agents.

## Architecture

```
Single agent: codelens-reviewer (domain-aware, single-pass)
  receives config {domains, scope, scopeTarget, diffRange, outputFile}
  │
  Step 1: Inventory (ctx_batch_execute)
    → rg --files + find/wc -l + manifest
    → indexed: codelens:inventory, codelens:file-stats, codelens:tech-stack
  │
  Step 2: Pattern Analysis (ctx_batch_execute, domain-aware)
    → ONE rg command per requested domain, scoped to scopePath
    → indexed: codelens:<domain>-patterns (only requested domains)
    → opt-in fallow + ast-grep batches (appended by skill ONLY when user passes --fallow / --ast-grep AND tool + project type match; default OFF)
    → ctx_search per source uses config.step2Queries verbatim (no improvisation)
  │
  Step 2.5: Doc/CVE verification (on-flag)
    → Context7 + WebSearch for suspect libraries
  │
  Step 3: Hotspot Deep-Dive (SINGLE-PASS — only source-read step)
    → for top 10-15 hotspots: ONE ctx_execute_file per file
    → processing code analyzes ALL requested domains SIMULTANEOUSLY
    → intent: "codelens:file:<path>" auto-indexes content
  │
  Step 4: Compile Report
    → native Write to outputFile at repo root
    → cross-domain dedup, severity sort
    → also writes .codelens/scan.log (human trace, NOT agent-consumed)
```

The 7 `/codelens:*` skills are thin dispatch wrappers: parse args → dependency gate → invoke the single agent with a config object.

## Hard Dependencies

These are NOT optional. All must be installed and configured:

| Dependency | Used By | Purpose |
|---|---|---|
| **`rg` (ripgrep)** | codelens-reviewer (Steps 1-2) | Primary search tool. Run via `ctx_batch_execute`'s host shell. Always prefer `rg` over `grep`, `find`, or `Glob`. |
| **context-mode MCP** | codelens-reviewer (all steps) | Sandboxed extraction (`ctx_batch_execute`, `ctx_execute_file`) + persistent FTS5 index (`ctx_search`). Mandatory first call: `ctx_stats`. |
| **Context7 MCP** | codelens-reviewer (Step 2.5) | Library version verification, CVE checks, deprecated API detection, component-library accessibility pattern checks |

## Optional Dependencies

| Dependency | Used By | Purpose |
|---|---|---|
| **`fallow`** | codelens-reviewer (Step 2) | TS/JS dead-code and duplication analysis. **Opt-in via `--fallow` flag** (default OFF). Detection still runs in setup-check. Skipped silently when flag absent, `package.json` absent, or no `quality`/`architecture` domain in scope. |
| **`sg` (ast-grep)** | codelens-reviewer (Step 2) | AST-accurate structural code search. **Opt-in via `--ast-grep` flag** (default OFF). Supports 20+ languages. Used for imports, class declarations, empty catch blocks, eval detection. Skipped silently when flag absent or `sg` not installed. |

## File Map

```
.claude-plugin/
  plugin.json              # Plugin manifest (name, version, author, skills path)
  marketplace.json         # Marketplace listing metadata
skills/
  review/
    SKILL.md               # /codelens:review — full review (all 4 domains)
  review-security/
    SKILL.md               # /codelens:review-security
  review-architecture/
    SKILL.md               # /codelens:review-architecture
  review-quality/
    SKILL.md               # /codelens:review-quality
  review-a11y/
    SKILL.md               # /codelens:review-a11y
  review-pr/
    SKILL.md               # /codelens:review-pr — PR diff review
  help/
    SKILL.md               # /codelens:help — setup check + command list
  _shared/
    report-template.md     # Single source of truth for Markdown report format
    setup-check.md         # Shared setup-verification logic
    domain-patterns.md     # Per-domain rg + ast-grep command catalog (sync-coupled to step2Queries)
agents/
  codelens-reviewer.md     # The single domain-aware agent (scans, analyzes, compiles)
docs/
  pipeline-diagram.md      # Developer-facing pipeline diagram (mermaid)
.claude/
  review-presets.json      # Default presets (pr-check, a11y-audit, full-audit)
  codelens-exclusions.json # Exclusion config (defaults + byDomain + keepInScope)
examples/
  sample-report.md         # Anonymized real report for README
.github/
  workflows/
    release.yml            # Tag-triggered release from CHANGELOG.md
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

The single `codelens-reviewer` agent follows these rules:
- **Severity-first ordering** — findings are Critical > High > Medium > Low > Informational, never grouped by domain
- **Single-pass reading** — source files are read exactly ONCE, in Step 3's hotspot deep-dive. The processing code analyzes all requested domains simultaneously per file. Pattern evidence comes via `ctx_search` against auto-indexed Step 2 output, never re-reading source. Single-context execution makes this structural — no second agent to lose track.
- **Domain-awareness** — only run pattern commands, Step 3 checks, and report sections for domains in the input `domains` array. Never analyze or report on non-requested domains. The agent consumes `config.step2Queries[i]` verbatim for Step 2's `ctx_search` calls — never improvises query strings.
- **Optional tools are uniform** — when `fallow` or `ast-grep` commands are present in `config.step2Commands` (appended only when the user passes `--fallow` / `--ast-grep` at the skill dispatch, AND the tool's detection gate passes), the agent runs them like any other command. No special-casing in Step 2 or Step 3. Default invocation (no flags) runs neither.
- **`.codelens/` discipline** — the agent writes ONLY `scan.log` to `.codelens/`. It must NEVER create `fallow-dead-code.md`, `fallow-dupes.md`, `quality-patterns.txt`, `eval.txt`, `empty-catch.txt`, `var-source.txt`, `async-patterns.txt`, or any `findings/` directory. fallow/ast-grep output is captured by `ctx_batch_execute`'s auto-index — never written to disk. The fallow command MUST NOT use the `-o` flag.
- **Scope-awareness** — every `rg` command targets `scopePath` (full → repo root, path → `scopeTarget`, diff → files in diff range).
- **rg over Glob** — always prefer `rg` (ripgrep) over `Glob` for codebase searches
- **ctx_batch_execute** — mandatory for Steps 1-2 (batched analysis); never run sequentially via raw Bash
- **ctx_execute_file** — mandatory for Step 3 (file content analysis); never load raw file contents via Read or Bash
- **ctx_stats first** — the agent's first tool call must be `ctx_stats`; skipping it is a protocol violation
- **Evidence-backed findings** — every finding must have file path, line number, code snippet
- **Cross-domain dedup** — same file:line (±2 lines) across domains → merge into single row
- **No token counts in report** — the Methodology section documents scope/files/tools, not cost
- **Exclusions honored** — every search call applies patterns from `.claude/codelens-exclusions.json`. `.env` and CI/CD files remain in scope via `keepInScope` rules.

## Common Workflows

### Add a new pattern check
1. Add the `rg` pattern to `skills/_shared/domain-patterns.md` (in the relevant domain's section — note the sync-coupling comment)
2. Add the evaluation logic to the relevant `<*-criteria>` section in `agents/codelens-reviewer.md`
3. If the new pattern introduces signal terms not already present, add them to the domain's `step2Queries` array in `skills/review-<domain>/SKILL.md`, `skills/review/SKILL.md`, and `skills/review-pr/SKILL.md`. Positional linkage requires the same index across `step2Commands`/`step2Sources`/`step2Queries`.
4. If the pattern needs Step 3 deep-dive verification, add a check to the processing code template in `agents/codelens-reviewer.md`
5. Test by running `/codelens:review-<domain>` on a codebase that has the pattern

### Add a new domain
1. Add a `<yourdomain-criteria>` block to `agents/codelens-reviewer.md`
2. Add a pattern command for the domain in `skills/_shared/domain-patterns.md` (with a sync-coupling comment)
3. Define the domain's `step2Queries` vocabulary array — add it to every skill that can dispatch this domain (the new single-domain skill + `skills/review/SKILL.md` + `skills/review-pr/SKILL.md`)
4. Add the domain's checks to Step 3's processing code template in `agents/codelens-reviewer.md`
5. Create `skills/review-<yourdomain>/SKILL.md` as a thin dispatch wrapper
6. Optionally add a preset to `.claude/review-presets.json`

### Modify the report format
Edit the report template at `skills/_shared/report-template.md`. The agent applies this template in Step 4 when compiling.

### Test locally
Copy `agents/` and `skills/` into a test project's `.claude/` dir, then run `/codelens:review` variants. fallow (`npm i -D fallow`) and ast-grep are **opt-in** — pass `--fallow` and/or `--ast-grep` to enable dead-code, duplication, and structural analysis. Default invocation runs neither.

### Release a new version
1. Update the version header in `CHANGELOG.md` (e.g., add `## [1.2.0] - YYYY-MM-DD`)
2. Commit: `git commit -m "chore: bump version to X.Y.Z"`
3. Push: `git push origin main`
4. The GitHub Actions workflow (`.github/workflows/release.yml`) triggers on push to `main`, extracts the version + release notes from CHANGELOG.md, and creates a GitHub Release

No Docker, no secrets beyond the auto-provided `GITHUB_TOKEN`. The workflow reads CHANGELOG.md for release content — keep changelog entries well-formatted.

## Plugin Marketplace

Users install via:
```
/plugin marketplace add nurmdrafi/codelens
/plugin install codelens
```

The marketplace.json at repo root is the marketplace manifest. The plugin.json inside .claude-plugin/ is the plugin manifest.
