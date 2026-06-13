# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0] - 2026-06-13

### Changed
- **Collapsed the 6-agent pipeline into a single domain-aware agent.** The former 3-phase pipeline (`codelens-scanner` + 4 domain reviewers + `codelens-reviewer` orchestrator) is replaced by one agent: `codelens-reviewer`. The 7 `/codelens:*` skills are now thin dispatch wrappers that parse args, run the dependency gate, and invoke this single agent with a config object.

- **Single-pass reading is structural.** In the multi-agent pipeline, hotspot files could be read up to 5 times across a full review (scanner + 4 independent reviewer contexts), with no shared memory of what had been read. In the single agent, Step 3's hotspot deep-dive is the only source-read step, and the processing code analyzes all requested domains simultaneously per file. One file read → N domains extracted.

- **Domain + scope enforcement is structural, not instructional.** The dispatching skill pre-filters everything before the agent runs:
  - The skill builds a literal `step2Commands` array containing ONLY the requested domains' rg commands, with `scopePath` and exclusion flags already baked in.
  - The skill resolves `scopePath` upfront: full → `.`, path → the path string, diff → the literal file list from `git diff --name-only`.
  - The agent emits `ctx_batch_execute(commands: config.step2Commands, ...)` verbatim — there is nothing to decide, nothing to ignore.
  - Step 3's processing code reads `config.step3Checks` and runs `if (CHECKS.includes("security")) {...}` branches — real code, not comments.
  - The agent literally cannot analyze a non-requested domain or scan outside the scope, because the filtered command list arrives as input.

- **Eliminated `extraction.json` and all disk handoff.** context-mode's persistent FTS5 index is the analysis substrate. Pattern matches auto-index under `codelens:<domain>-patterns`; hotspot file contents auto-index under `codelens:file:<path>` via the `intent` parameter. No intermediate JSON files. A human-readable `.codelens/scan.log` trace is written for inspection.

- **No token counts in the report.** The Methodology section documents scope, domains, files, and tools — not cost. Terminal token reporting has proven unreliable (UAT-05 showed 69.8k claimed vs ~22k actual).

- **Prompt overhead reduced ~70%.** The 6 former agents collectively loaded ~18k tokens of prompt definitions per run (6 contexts × ~3k each). The single agent loads ~5k once.

### Research grounding
Anthropic's [multi-agent research system post](https://www.anthropic.com/engineering/multi-agent-research-system): "multi-agent systems use about 15× more tokens than chats" and "some domains that require all agents to share the same context... are not a good fit for multi-agent systems today. For instance, most coding tasks involve fewer truly parallelizable tasks than research." Code review is exactly this case.

Anthropic's [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents): "Workflows are systems where LLMs and tools are orchestrated through predefined code paths... Workflows offer predictability and consistency for well-defined tasks." Code review is a well-defined task — the skill knows the domains and scope at dispatch time, so the deterministic filtering belongs in the dispatcher, not in agent discretion.

Full design rationale: `docs/plan-single-agent-collapse.md`.

### Added
- `agents/codelens-reviewer.md` — the single domain-aware agent (absorbs scanner + 4 reviewers + orchestrator).
- `skills/_shared/domain-patterns.md` — reference table of rg patterns per domain. Skills copy from this to build `step2Commands`.
- `docs/pipeline-diagram.md` — developer-facing pipeline diagram.
- `docs/plan-single-agent-collapse.md` — design doc with research grounding.

### Removed
- `agents/codelens-scanner.md` — folded into `codelens-reviewer.md`.
- `agents/security-reviewer.md`, `architecture-reviewer.md`, `code-quality-reviewer.md`, `a11y-reviewer.md` — criteria folded into `<*-criteria>` blocks in the single agent.
- `extraction.json` — replaced by the indexed-handoff model.
- Token counts from reports.

### Preserved (unchanged from 1.6.0)
- All 7 user-facing commands and their argument forms (`/codelens:review`, `/codelens:review-{security,architecture,quality,a11y}`, `/codelens:review-pr`, `/codelens:help`).
- All output filenames (`CODEBASE_ANALYSIS_REPORT.md`, `SECURITY_REPORT.md`, `ARCHITECTURE_REPORT.md`, `CODE_QUALITY_REPORT.md`, `ACCESSIBILITY_REPORT.md`, `PR_REVIEW_<range>.md`).
- All 3 presets (`pr-check`, `a11y-audit`, `full-audit`) and user-preset support.
- `.claude/codelens-exclusions.json` exclusion semantics.
- Dependency gate, setup-check, and report template.

## [1.6.0] - 2026-06-13

### Added
- **Scanner Step 0: context-mode verification** — scanner now verifies context-mode availability via `ctx_stats` before proceeding. If unavailable, writes an error to `extraction.json` and stops.

### Changed
- **Working directory renamed.** `.codelens-review/` → `.codelens/`. Shorter, more standard. Existing `.codelens-review/` directories are not migrated — delete them manually.
- **`Read` removed from Phase B agent tools.** All 4 Phase B agents (security, architecture, code-quality, a11y) no longer have `Read` in their `tools` frontmatter array. Extraction data is read via `ctx_execute_file` instead. This is structural enforcement — the model cannot use `Read` even if it tries. Addresses UAT-03 finding where the security reviewer used 28 raw `Read` calls on source files despite claiming context-mode was "available".
- **Escape hatch sections removed from all Phase B agents.** The escape hatch ("you MAY Read that specific file") contradicted the "NEVER use Read on source files" rule. Removing it eliminates the contradiction that caused UAT-03's 0 ctx_* tool calls.
- **Phase B Step 0 reordered.** `ctx_stats` check now comes first (before extraction check). If context-mode is unavailable, the agent stops immediately instead of falling back to raw Bash/rg.
- **Orchestrator reads findings via `ctx_execute_file`.** Added `ctx_execute_file` to orchestrator tools. Findings JSONs are now read through the sandbox instead of raw `Read`.
- **Report template methodology table updated.** "Extraction read" tool changed from `Read` to `ctx_execute_file`.
- **Dependency gate added to all review skills.** Skills now check for ripgrep, context-mode MCP, and Context7 MCP before dispatching the pipeline. If any hard dependency is missing, the review is blocked immediately with install instructions — no tokens wasted on a pipeline that will fail.
- **context-mode promoted from "strongly recommended" to "required"** in setup-check. The fallback to raw Bash/rg was removed; the setup check now reflects this.
- **Orchestrator pre-flight hard-aborts on missing context-mode** instead of warning and continuing (the fallback path no longer exists).

## [1.5.0] - 2026-06-12

### Added
- **Pipeline integrity gate (Step 0)** in all Phase B agents — agents abort with structured error JSON if `extraction.json` is missing, empty, or contains an `error` key from a failed scanner run. Agents no longer improvise extraction from scratch.
- **Mandatory context-mode protocol** — all Phase B agents now require `ctx_stats` as the very first tool call (protocol violation if skipped). Once context-mode is confirmed available, agents MUST use `ctx_batch_execute`/`ctx_execute_file` exclusively — no fallback to raw Bash/Grep permitted. Addresses UAT-01 and UAT-02 finding where agents used zero context-mode tools despite declaring them as hard dependencies.
- **`status` field in findings JSON** — all Phase B agents now write `"status": "complete"`, `"error"`, or `"partial_failure"` in their output JSON. The orchestrator branches on this field in Phase C to handle failed or incomplete domains gracefully.
- **Pre-flight dependency check** — orchestrator now runs `ctx_stats` and `rg --version` before dispatching any agent, catching missing dependencies early instead of failing silently mid-pipeline.
- **Pipeline Caveat section** in reports — when any domain has non-complete status, a warning block appears before the Executive Summary alerting users to incomplete results with re-run instructions.
- **Methodology validation** — orchestrator now detects fabricated `_methodology` blocks (agent claims `contextMode: "available"` but all `ctx_*` counts are 0) and flags it as a warning in the report.
- **Scanner output shape validation** — scanner validates that `extraction.json` contains required keys (`metadata`, `patternMatches`, `exclusionsUsed`) before writing. Malformed output writes an `error` JSON instead, which Phase B agents catch in their Step 0 gate.

### Changed
- **context-mode MCP promoted to hard dependency for all agents.** Previously declared as hard dependency only for scanner. Now explicitly required by all Phase B agents and the orchestrator. Dependency tables in CLAUDE.md and README updated.
- **Context7 MCP promoted to hard dependency for a11y-reviewer.** Previously the a11y agent's Dependencies section said "No Context7 needed" despite having Context7 tools in frontmatter and usage instructions in body. Now correctly declared as hard requirement for component-library accessibility checks.
- **Orchestrator Context7 dependency list updated** — now includes `a11y-reviewer` alongside security, architecture, and code-quality reviewers.
- **Removed all conditional "if context-mode is available" language** from scanner agent. Context-mode is now mandatory — no alternative paths.
- **Replaced preference-based "ALWAYS prefer" instructions** with mandatory "you MUST use" protocol with exact tool call syntax examples.
- **Post-Report Follow-up** now conditionally warns about error/partial_failure domains with re-run instructions.

### Fixed
- **Agents silently skipping context-mode MCP tools.** Two UAT runs (01.security, 02.security) confirmed agents used 26+ raw `Read` calls and 6 raw `rg` via Bash instead of `ctx_batch_execute`/`ctx_execute_file`, consuming 52.8k tokens for a single domain. Root cause: conditional language, easy fallback paths, and no hard gate preventing self-bootstrapping. Fixed by Step 0 gate, mandatory protocol, no-fallback-once-available, dual methodology validation, and scanner output shape validation.

## [1.4.0] - 2026-06-12

### ⚠ Breaking Changes
- **Command surface renamed.** `/review` and its subcommands are now `/codelens:review`, `/codelens:review-security`, `/codelens:review-architecture`, `/codelens:review-quality`, `/codelens:review-a11y`, `/codelens:review-pr`, `/codelens:help`. The plugin now follows the superpowers-style multi-skill convention — one skill per command. There is no backwards-compat shim.
- **Working directory renamed.** `.claude-review/` → `.codelens/`. Existing `.claude-review/` directories from previous runs are not migrated — delete them manually.
- **Agent renamed.** `agents/accessibility-reviewer.md` → `agents/a11y-reviewer.md`.

### Added
- **New per-domain skills:** `/codelens:review-security`, `/codelens:review-architecture`, `/codelens:review-quality`, `/codelens:review-a11y`, `/codelens:review-pr`, `/codelens:help` — one skill per command, superpowers-style.
- **Reserved `/codelens:fix-*` namespace** for future remediation skills. Calling today returns a graceful "coming soon" message.
- **Exclusion config** (`.claude/codelens-exclusions.json`) — comprehensive default list (192 patterns) covering JS/TS, Python, Rust, Java, Go, PHP, Ruby, .NET, Swift, Flutter, mobile, IDE, OS, lockfiles, and build artifacts. Applies to all agents. User-overridable. `keepInScope` rules protect `.env` files and CI/CD pipelines from exclusion.
- **Shared report template** (`skills/_shared/report-template.md`) — single source of truth for Markdown report format. Compiled by orchestrator from JSON, never written directly by agents.
- **Shared setup-check snippet** (`skills/_shared/setup-check.md`) — verifies rg, context-mode MCP, Context7 MCP, fallow, ast-grep. Reports graceful fallback when context-mode is unavailable.
- **Methodology table** appended to every report — records tool usage, token count, context-mode status, exclusions applied.

### Changed
- **Domain-specific output filenames.** Standalone single-domain runs produce `<DOMAIN>_REPORT.md` at repo root (e.g., `SECURITY_REPORT.md`, `ARCHITECTURE_REPORT.md`, `CODE_QUALITY_REPORT.md`, `ACCESSIBILITY_REPORT.md`). Full review still produces `CODEBASE_ANALYSIS_REPORT.md`. PR review produces `PR_REVIEW_<range>.md`.
- **Agents write JSON only.** Phase B reviewers (security, architecture, code-quality, a11y) now write `.codelens/findings/<domain>.json` exclusively. The orchestrator (`codelens-reviewer`) compiles the Markdown report from JSON via the shared template. Eliminates output-format drift.
- **Working directory kept after run.** The orchestrator no longer suggests `rm -rf .codelens/`. Re-running overwrites; users delete manually if needed.
- **context-mode MCP mandated in prompts.** Every Phase B agent's Analysis Process now defaults to `ctx_batch_execute`, `ctx_execute_file`, `ctx_search`. Raw `Bash`/`Grep` kept as logged fallback when context-mode MCP is unavailable. Target: ~25k tokens for single-domain security review (down from ~58k observed in UAT-01).
- **OWASP classification rules tightened** (security-reviewer). A09 reserved for missing audit logs (not over-logging). A01 requires actual authorization bypass (not race conditions or PII exposure). PCI DSS noted in `impact` field, not `classification`.
- **Dedup rule** added to all Phase B agents — findings on same `file:line` (±2 lines) consolidated.
- **positiveFindings location requirement** — vague locations like `"project-wide"` rejected; specific file paths required.

### Fixed
- **Scanner self-exclusion.** Scanner no longer analyzes its own working directory (`.codelens/`) or previous reports (`*_REPORT.md`, `PR_REVIEW_*.md`) from earlier runs. Fixes UAT-01 finding where the scanner re-analyzed its own output.

## [1.3.0] - 2026-06-12

### Added
- **ast-grep integration** — optional AST-aware structural code search using tree-sitter
  - Phase A scanner runs `sg` (ast-grep) for patterns that need AST understanding
  - Supports 20+ languages (TS, JS, Python, Go, Java, Rust, etc.) — not limited to TS/JS
  - Replaces 4 rg patterns with AST-accurate equivalents (imports, class extends, empty catch, eval)
  - New checks rg can't do: `var` usage detection, duplicate boolean conditions (`$A && $A`)
  - Zero false positives on eval — only matches real eval() calls, not strings/comments
  - JSON output parsed via `ctx_execute_file` sandbox — only ~2-4KB summaries enter context
  - Phase B code-quality reviewer consumes empty catch, var usage, duplicate conditions
  - Phase B architecture reviewer consumes AST-accurate imports and class declarations
  - Phase B security reviewer consumes AST-accurate eval calls
  - `/review setup-check` shows ast-grep availability (soft check, does not fail if missing)

### Changed
- Removed 4 patterns from rg combined command (eval, import, class extends, empty catch) — now handled by ast-grep
- `CLAUDE.md` — added ast-grep to Optional Dependencies, updated architecture diagram
- `agents/codelens-scanner.md` — added Step 2.6 (ast-grep Structural Scan), updated extraction.json schema
- `agents/code-quality-reviewer.md` — added ast-grep data to Input, criteria, and analysis process
- `agents/architecture-reviewer.md` — added ast-grep imports and class data to Input and analysis
- `agents/security-reviewer.md` — added ast-grep eval data to Input and analysis

## [1.2.0] - 2026-06-12

### Added
- **Fallow integration** — optional TS/JS codebase intelligence for dead-code and duplication analysis
  - Phase A scanner auto-detects TS/JS projects via `package.json` and runs `fallow dead-code` + `fallow dupes`
  - Human-format output (~5-7KB per command) parsed via `ctx_execute_file` sandbox — only ~2-4KB summaries enter context
  - Dead-code findings (unused exports, files, types, deps, circular deps) folded into `extraction.json`
  - Duplication findings (clone families, line ranges, extraction suggestions) folded into `extraction.json`
  - Phase B code-quality reviewer consumes fallow dead-code + duplication data
  - Phase B architecture reviewer consumes fallow circular dependency data
  - Phase B security reviewer consumes fallow unlisted dependency data
  - `/review setup-check` shows fallow availability (soft check, does not fail if missing)
- `docs/superpowers/specs/2026-06-12-fallow-integration-design.md` — integration design spec

### Changed
- `CLAUDE.md` — added Optional Dependencies section with fallow, updated architecture diagram
- `agents/codelens-scanner.md` — added Step 2.5 (Fallow Extraction), updated extraction.json schema
- `agents/code-quality-reviewer.md` — added fallow data to Input, criteria, and analysis process
- `agents/architecture-reviewer.md` — added fallow circular deps to Input, criteria, and analysis
- `agents/security-reviewer.md` — added fallow unlisted deps to Input and analysis process
- `skills/review/SKILL.md` — added fallow soft check to setup-check

## [1.1.0] - 2026-06-12

### Fixed
- MCP dependencies (Context7, context-mode) hardened to required — removed all optional/fallback language from agents
- Added missing tools to agent frontmatter: `Glob`, `Grep`, `Edit`, `WebSearch`, Context7 MCP tools, `ctx_fetch_and_index`
- Added explicit Dependencies sections to all 6 agents listing `rg`, context-mode, and Context7 as hard requirements
- README dependency section corrected from "Recommended Setup" (optional) to "Required Setup" (mandatory)

### Added
- `CLAUDE.md` — full project documentation for Claude Code (identity, origin, architecture, constraints, workflows)
- `CONTRIBUTING.md` — development prerequisites, branching strategy, commit conventions, testing guide
- `LICENSE` — MIT license
- `examples/sample-report.md` — anonymized real report (62 findings) for README preview
- GitHub Actions release workflow (`.github/workflows/release.yml`) — tag-triggered, extracts version + notes from CHANGELOG.md

### Changed
- README restructured with Problem/Solution framing, agent inventory table, docs hub, report preview, troubleshooting (6 issues), FAQ (6 questions)
- CONTRIBUTING expanded with prerequisites table, edge case testing, false-positive/missing-pattern reporting templates

## [1.0.0] - 2026-06-12

### Added
- Initial release
- 3-phase pipeline architecture: single-pass scan, parallel domain analysis, merged report
- 4 domain reviewers: security (OWASP Top 10), architecture (SOLID), code quality (complexity, duplication), accessibility (WCAG 2.1 AA)
- `/review` slash command with guided mode, domain selection, and scope control
- Full repo, path-scoped, and git diff review modes
- Built-in presets: `pr-check`, `a11y-audit`, `full-audit`
- User-overridable presets via `.claude/review-presets.json`
- Severity-first report format with cross-domain summary tables
- Context7 MCP integration for library version and CVE verification (optional)
- context-mode MCP integration for token-efficient extraction (optional)
- Graceful degradation when optional MCPs are unavailable
- `/review setup-check` diagnostic command
- `/review help` usage cheatsheet
- Post-report follow-up prompt with fix/GitHub issues options
- Sample report in `examples/sample-report.md`
