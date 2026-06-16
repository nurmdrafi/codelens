# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.4] - 2026-06-17

### Changed

- **Phase 2 tool substitution** — codelens now uses Biome (JS/TS lint + a11y, 491 rules) and fallow (dead-code, duplication, complexity, circular deps, architecture boundaries) when installed, with rg fallback per missing tool. Catches findings rg patterns cannot: SVG a11y (Biome `noSvgWithoutTitle`), unused files/exports/dependencies (fallow `dead-code`), code duplication (fallow `dupes`), maintainability hotspots (fallow `health`). Empirical comparison documented in `docs/superpowers/benchmarks/phase-2-config-comparison.md`. Install both via `npm i -g @biomejs/biome fallow` for the enhanced path; codelens works without them via rg fallback.
- **Phase 0 preflight removed** — replaced 3 mandatory upfront dependency pings with graceful degradation. The Claude Code runtime already knows which MCP servers and CLI tools are loaded; per-tool errors now halt with install hints at the point of use instead of upfront. Saves 3 round-trips per review.
- **Phase 4 report template extracted** — inlined 4.2KB template moved to `references/report-template.md`, read via `ctx_execute_file` at Phase 4 start. Net prompt change across all v0.0.4 edits: +72 tokens (1.3% increase over v0.0.3's 5,420) in exchange for substantially richer findings on quality, architecture, and accessibility domains.

### Added

- **Explicit JS/TS language scope** — Phase 1 now detects whether the target is JS/TS code. Non-JS/TS code receives a partial rg-only review with a "Language Support Note" section in the report explaining the gap. Multi-language tool integration (PHPStan for PHP, ruff for Python, etc.) is planned for v0.0.5+.
- **Optional tools documented** — README now explains Biome and fallow as recommended-but-not-required installations.

### Resolved smoke-test follow-ups

- The v0.0.3 follow-up "doctor should verify each codelens MCP tool individually" remains open. Phase 0 graceful degradation makes this less critical (per-tool errors now surface at use, not at a doctor-time preflight), but `/codelens:doctor` still does not enumerate individual MCP tools.

### Notes

- **semgrep considered, dropped.** Validated semgrep 1.99.0 against both dockerize-react-app and my-portfolio across `--config auto`, `--config p/owasp-top-ten`, and combined react+typescript+javascript rulesets. semgrep found 0 findings on real code with actual security surface (env var exposure, `dangerouslySetInnerHTML`, `any`-typed catches). The existing rg security patterns catch these signals. semgrep's 2-minute pip install cost and 42% documented FPR (per `reports/codelens-reviewer-tool-validation.md`) did not justify inclusion.
- **Omniroute routing deferred.** Model routing for agent execution (Omniroute vs default GLM) will be evaluated post-v0.0.4 with real benchmark numbers.

---

## Unreleased

### Added (developer experience)

- **Documented `--plugin-dir` local-testing method in CONTRIBUTING.md.** This is the recommended primary approach for testing codelens against a real target repo: `claude --plugin-dir /path/to/codelens` (optionally with `-p` for headless smoke tests). Replaces the v0.0.1-vintage `cp -r agents/ skills/ → .claude/` recipe as the primary method; the copy method is retained as a labeled fallback for older Claude Code versions. Discovered during the 2026-06-15 optimus-marchant smoke test — `--plugin-dir` requires no install, no copy, and no `.claude/` modifications in the target repo, making repeated smoke tests far less invasive.

### Fixed (developer experience)

- **`/codelens:doctor` MCP permission gap surfaced.** First headless run against optimus-marchant produced zero output because `mcp__plugin_context-mode_context-mode__ctx_stats` was missing from the target repo's `.claude/settings.local.json` allowlist. The allowlist had 6 codelens MCP tools but not `ctx_stats`, which is the agent's mandatory Phase 0 first call. `/codelens:doctor` reported "context-mode MCP responding" generically and did not catch the per-tool gap. CONTRIBUTING.md's new Testing Locally section now documents the full required allowlist. Follow-up: doctor should verify each codelens MCP tool individually (tracked as a v0.0.4 candidate in `docs/smoke-tests/2026-06-15-optimus-marchant-v0.0.3/audit-summary.md` §6).

### Smoke Test Context

The 2026-06-15 optimus-marchant smoke test (`docs/smoke-tests/2026-06-15-optimus-marchant-v0.0.3/audit-summary.md`) gave v0.0.3 a PARTIAL PASS:
- ✅ reviews.json 6-field schema holds (v0.0.2 fix verified in production)
- ✅ Phase 1 rg-via-host-Bash and Phase 2 per-pattern Bash calls both correct
- ✅ v0.0.3 single NL entry point dispatches headlessly with zero interactive prompts
- ✅ Report quality strong — 48 findings (2 Critical / 17 High / 14 Medium / 9 Low / 6 Info); both Criticals are real security issues
- ❌ Phase 0 `ctx_stats`-first rule still violated (agent substituted `ctx_search`; `ctx_stats` never called) — same pattern flagged in v0.0.1 portfolio audit, v0.0.2 hardening did not hold
- ❌ Phase 3 `ctx_execute_file` rule violated (agent used `Bash cat` for all 21 hotspot reads)

## [0.0.3] - 2026-06-15

Skill dispatcher consolidation. 5 slash commands removed, `/codelens:review` is now the single NL-driven entry point.

### Changed

- **`/codelens:review` is now the single review entry point.** Resolves `{domains, scope, scopeTarget, outputFile}` from the user's prompt via NL inference. `AskUserQuestion` fires when invocation is bare or any field is ambiguous. Diff scope (formerly `/codelens:review-pr`) and all single-domain scopes (formerly `/codelens:review-<domain>`) handled inline.
- **Agent body unchanged.** `codelens-reviewer` Phase 0–4 pipeline untouched. Config contract `{domains, scope, scopeTarget, outputFile}` preserved.

### Removed

- `/codelens:review-security` — use `/codelens:review security` (or any NL equivalent).
- `/codelens:review-architecture` — use `/codelens:review architecture`.
- `/codelens:review-quality` — use `/codelens:review quality`.
- `/codelens:review-a11y` — use `/codelens:review a11y`.
- `/codelens:review-pr` — use `/codelens:review <base>..<head>` or `/codelens:review the PR`.
- `--domains` flag — state domains in natural language: `/codelens:review security quality`.
- `skills/review-security/`, `skills/review-architecture/`, `skills/review-quality/`, `skills/review-a11y/`, `skills/review-pr/` — 5 skill directories (~3KB duplicate dispatch logic). Capabilities folded into `skills/review/SKILL.md`.

## [0.0.2] - 2026-06-15

Patch release addressing 4 spec violations exposed by the first end-to-end smoke test (`docs/smoke-tests/2026-06-15-portfolio-v0.0.1/`). No breaking changes. All fixes are agent-side recipe corrections and a documentation cleanup.

### Added

- **Phase 0 dependency preflight** — agent now verifies `rg`, context-mode MCP, AND Context7 MCP before any review work. Each check has explicit `[FAIL] ... Agent revoking execution.` language and concrete install commands. Replaces the single `ctx_stats` check from v0.0.1.
- **Toast container a11y pattern** — `rg --no-heading -n '<Toaster|toast\('` added to Phase 2 a11y block. Catches toast components that may lack `aria-live` regions.

### Changed

- **Phase 1 rg routing** — `rg --files` now runs through native Bash (host shell), not inside `ctx_batch_execute`. The ctx-mode sandbox PATH excludes ripgrep; v0.0.1's recipe caused `command not found: rg` failures. Non-rg inventory commands (`find`, `cat package.json`) stay in `ctx_batch_execute`.
- **Phase 2 rg rule relaxed** — the v0.0.1 "ONE ctx_batch_execute" contract is relaxed for Phase 2 because (a) rg must use Bash (per Phase 1 fix) and (b) nested-quote regex concatenation (e.g. `'SECRET|PASSWORD' | rg -v 'process\.env|\.env'`) breaks shell parsing. Each rg is now its own Bash call.
- **Phase 4 reviews.json schema tightened** — explicit "EXACTLY 6 fields, no more, no less" language with literal JSON example and per-field rules. v0.0.1's loose phrasing ("appends this entry") produced an 8-field drift in the smoke test.

### Fixed

- **CONTRIBUTING.md file-tree** — replaced stale v1.7.x references (`help/SKILL.md`, `_shared/*`, `docs/pipeline-diagram.md`) with the actual v0.0.1+ tree (`doctor/SKILL.md`, `.claude-plugin/`, `examples/`, `docs/smoke-tests/`).
- **Toast live-region regression** — v1.x flagged missing `aria-live` on `react-hot-toast` containers; v0.0.1 dropped the pattern during the rebuild. Smoke test confirmed the regression; the new `<Toaster` pattern restores coverage.

### Smoke Test Context

The 2026-06-15 portfolio smoke test (`docs/smoke-tests/2026-06-15-portfolio-v0.0.1/audit-summary.md`) gave v0.0.1 a PARTIAL PASS:
- ✅ v0.0.1 found 2.2× more issues than v1.x on the same codebase (24 vs 11 findings)
- ✅ Critical tier entirely new (Next.js CVEs v1.x missed)
- ✅ Single-pass invariant held (15/15 hotspots, no re-reads)
- ❌ 4 spec violations documented above

## [0.0.1] - 2026-06-15

Beta rebuild. Architecture overhauled for token efficiency — full rebuild of skills, agent, and supporting files. **Breaking changes from 1.x.**

### ⚠ Breaking Changes

- **`/codelens:help` removed.** Use `/codelens:doctor` instead (richer diagnostics with fix commands).
- **`--fallow` and `--ast-grep` flags removed.** Both features dropped for v0.0.1. Detection runs no longer include fallow dead-code or ast-grep structural patterns.
- **`.codelens/scan.log` no longer produced.** Replaced by `.codelens/reviews.json` (append-only history of every review).
- **Skill configs simplified.** Skills now emit `{domains, scope, scopeTarget, outputFile}` only — no `step2Commands`/`step2Sources`/`step2Queries`/`step3Checks`/`criteriaDomains` positional arrays.

### Added

- **`/codelens:doctor` command** — 5 sequential setup checks with `[OK]`/`[WARN]`/`[FAIL]` output and concrete fix commands.
- **`.codelens/reviews.json`** — persistent append-only log of every review (6-field entries: timestamp, command, scope, summary, status, reportPath).
- **Natural-language arg parsing on `/codelens:review`** — bare invocation triggers `AskUserQuestion` picker; NL descriptions accepted.
- **Per-domain report files** — `/codelens:review-security` writes `SECURITY_REPORT.md`, `/codelens:review-architecture` writes `ARCHITECTURE_REPORT.md`, etc.

### Changed

- **Agent rewrite.** `agents/codelens-reviewer.md` reduced from 421 lines (~6,475 tokens) to ~400 lines (~4,750 tokens). Phase 2 commands now inlined in agent body (matching `references/codebase-analyzer.md`); no more manifest forwarding.
- **Skill files trimmed.** All 7 skills reduced by 4–6×. Worst case `/codelens:review` skill: 9.9KB → 2.4KB.
- **No persisted intermediate state.** Phases 0–4 run in one continuous turn. No `.codelens/findings/*.json` status objects. No `_methodology` self-reports.
- **`CLAUDE.md`** reduced from 12KB to ~3KB. Drops fallow, ast-grep, scanner/orchestrator references.
- **Report `.codelens/scan.log` trace** removed; replaced by single `reviews.json` append at end of run.

### Removed

- `skills/help/SKILL.md` — replaced by `skills/doctor/SKILL.md`.
- `skills/_shared/domain-patterns.md` — folded into agent Phase 2.
- `skills/_shared/report-template.md` — folded into agent Phase 4.
- `skills/_shared/setup-check.md` — folded into `skills/doctor/SKILL.md`.
- ast-grep integration (all `sg` commands, detection logic, --ast-grep flag).
- fallow integration (all fallow commands, --fallow flag).
- v1.7.x / v1.8.x phase-gate JSON contracts and `_methodology` self-report system.

### Token Efficiency

Significant reduction in per-invocation cost vs v1.8.0:

| Layer | v1.8.0 | v0.0.1 |
|---|---|---|
| L1 Skill-load (triggered skill) | ~2,477 tok | ~600 tok |
| L2 Agent prompt | ~6,475 tok | ~4,750 tok |
| L3 Execution | ~10–14K tok | ~5–8K tok |
| **Total worst case** | **~19–23K tok** | **~10–13K tok** |

The agent body remains smaller than the gold-standard baseline `references/codebase-analyzer.md` (~5,210 tokens).
