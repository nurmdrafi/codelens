# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-06-12

### ⚠ Breaking Changes
- **Command surface renamed.** `/review` and its subcommands are now `/codelens:review`, `/codelens:review-security`, `/codelens:review-architecture`, `/codelens:review-quality`, `/codelens:review-a11y`, `/codelens:review-pr`, `/codelens:help`. The plugin now follows the superpowers-style multi-skill convention — one skill per command. There is no backwards-compat shim.
- **Working directory renamed.** `.claude-review/` → `.codelens-review/`. Existing `.claude-review/` directories from previous runs are not migrated — delete them manually.
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
- **Agents write JSON only.** Phase B reviewers (security, architecture, code-quality, a11y) now write `.codelens-review/findings/<domain>.json` exclusively. The orchestrator (`codelens-reviewer`) compiles the Markdown report from JSON via the shared template. Eliminates output-format drift.
- **Working directory kept after run.** The orchestrator no longer suggests `rm -rf .codelens-review/`. Re-running overwrites; users delete manually if needed.
- **context-mode MCP mandated in prompts.** Every Phase B agent's Analysis Process now defaults to `ctx_batch_execute`, `ctx_execute_file`, `ctx_search`. Raw `Bash`/`Grep` kept as logged fallback when context-mode MCP is unavailable. Target: ~25k tokens for single-domain security review (down from ~58k observed in UAT-01).
- **OWASP classification rules tightened** (security-reviewer). A09 reserved for missing audit logs (not over-logging). A01 requires actual authorization bypass (not race conditions or PII exposure). PCI DSS noted in `impact` field, not `classification`.
- **Dedup rule** added to all Phase B agents — findings on same `file:line` (±2 lines) consolidated.
- **positiveFindings location requirement** — vague locations like `"project-wide"` rejected; specific file paths required.

### Fixed
- **Scanner self-exclusion.** Scanner no longer analyzes its own working directory (`.codelens-review/`) or previous reports (`*_REPORT.md`, `PR_REVIEW_*.md`) from earlier runs. Fixes UAT-01 finding where the scanner re-analyzed its own output.
- **OWASP mis-tags from UAT-01.** `console.log` leaks no longer tagged A09. Race conditions no longer tagged A01. Payment-data findings tagged with primary OWASP category, PCI DSS in impact field.
- **Overlapping findings consolidated.** UAT-01's SEC-001/005/006 overlap on `paymentApi.ts` query-param pattern now covered by the dedup rule.

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
