# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.10] - 2026-06-21

v0.0.10 is the extensibility + self-contained release. Beta — no backward compatibility. The reviews.log shape is the canonical form; schema v1.

### Added

- `config/custom-checks.json` — evidence-based company-specific checks. Ships 2 examples (env-example-exists, readme-exists). Each check has id/domain/severity/detect/passSignal/title/description; the agent runs them at Phase 1+2 and emits findings at Phase 4 Step 1.5.
- `scripts/validate-custom-checks.js` — schema validator for custom-checks.json. Enforces id kebab-case + unique, domain/severity in allowed sets, detect non-empty. Run from doctor's check 14.
- `config/languages.json` — multi-language mechanism. js-ts fully populated (faithful transcription of all current agent severity mappings); python/php/go/rust placeholders for follow-up PRs. Adding a language is now a config edit only.
- `mcpServers` block in `plugin.json` — context-mode + context7 auto-provision on `/plugin install codelens`. No separate MCP plugin installs needed.
- `permissions.allow` block in `plugin.json` — 27 rules eliminating per-review Bash permission prompts.
- Stack-aware doctor — detects js-ts/python/php/go/rust via `config/languages.json`, `[SKIP]`s biome/tsc/fallow/ast-grep checks when the stack doesn't match. `[SKIP]` is a fourth doctor status (alongside OK/WARN/FAIL).
- Doctor check 14 (custom-checks.json valid) — critical if file is present and invalid.
- `schema` field on reviews.log entries — **required**, current `"1"`. Numeric-string bump policy.
- Single-domain Scorecard worked example in `templates/report.md` (drops the Domain column when only one domain is requested).
- Phase 4 Step 8 — diff-scope temp-file cleanup.
- Phase 4 Step 1.5 — collect custom-check findings before building the report.
- `docs/superpowers/benchmarks/2026-06-19-v0.0.10-token-reduction.md` — Part E benchmark tracking with honest accounting of the missed 25% gate.

### Changed

- npm CLIs (biome/fallow/ast-grep) auto-fetched via `npx` with `command -v <binary>` fast-path. Only rg remains user-installed (native binary, can't bundle).
- Agent prompt restructured around a shared `<severity-ladder>` block (single source of truth for severity assignments; per-domain criteria reference it). Phase 2.5 triggers enumerated concretely with WebSearch caps (5 libraries × 2 queries). Phase 3 two-batch queries are deterministic (no `...` ellipsis).
- Phase 4 inline restatements of `<constraints>` replaced with `*Per <constraints>:*` pointers.
- Doctor's 14 checks batched into 3 groups (CLI existence concurrency 5, MCP probes concurrency 3, filesystem+tsc sequential) for fewer LLM turns.
- Agent Phase 0.5 loads both `custom-checks.json` and `languages.json`; Phase 1 stack detection is config-driven; Phase 1+2 batch, Phase 3 ast-grep, and Phase 4 severity mappings all built from `primaryLang`'s config entry.
- Diff-scope `scopePath` mechanism rewritten — file list materialized once to a PID-suffixed temp file, consumed via `rg --files-from` / `xargs`, cleaned up in Phase 4 Step 8. Fixes the multi-line word-splitting bug.

### Fixed

- Doc drift: 6-field/reviews.json → 11-field/reviews.log everywhere (templates/README.md, CLAUDE.md, README.md, CONTRIBUTING.md, skills/review/SKILL.md). Plus the new schema-required field documented consistently.
- "No phase gates" claim in agent `<role>` block → accurate description of three Phase 4 STATUS gates.
- Stale v0.0.1 banner → v0.0.10 beta framing.
- `templates/report.md` no longer hardcodes the plugin name (was violating its own abstraction rule #2). Same fix applied to one residual codelens self-reference in the agent body's Step 2 example.
- Diff-scope word-splitting: `scopePath = git diff --name-only` broke every command substituting it as a single path arg. Fixed via the temp-file mechanism.

### Notes

- **Token-reduction gate adjusted.** The original ≥25% reduction target (final ≤22,180 bytes) was not achievable through E1–E4 as prescribed. The agent ended at 41,277 bytes — larger than v0.0.9 (29,574) because Parts B+C added load-bearing functionality (diff temp-file, npx wrappers) and Part I added config-driven indirection (~84 lines). New gate: "no accidental bloat" + clarity invariants (single severity-ladder source, enumerated Phase 2.5 triggers, deterministic Phase 3 queries) + unchanged severity-drift gate. See `docs/superpowers/benchmarks/2026-06-19-v0.0.10-token-reduction.md` for full accounting.
- **End-to-end smoke test (security + a11y severity regression check, clean-install /plugin install) deferred.** Requires an interactive Claude Code session. Flagged for follow-up before tagging the GitHub release.

## [0.0.9] - 2026-06-19

Schema-driven output contracts + deterministic validation gates + Phase 4 gate-hardening. This release absorbs the previously-unreleased v0.0.8 work (output contracts, validators, directory reorg) and the v0.0.9 gate-hardening that makes those gates actually fire.

### Added

- **Output contracts externalized** — report template, reviews-log entry schema, and abstraction rules moved out of the agent body into `templates/report.md`, `templates/reviews-entry.json`, and `templates/README.md`. The agent loads them at Phase 4 start instead of carrying the structures inline.
- **Reviews-log entry schema** — flat 11-field shape (`ts`, `scope`, `crit`, `high`, `med`, `low`, `info`, `report`, `v`, `tokIn`, `tokOut`) with `additionalProperties: false`. Replaces the prior 6-field long-key shape (`timestamp`/`summary`/`findings`/`reportPath`/`reviewerVersion`) that had drifted.
- **Deterministic validators** — `scripts/validate-report.sh` (markdown structural lint) and `scripts/validate-entry.js` (hand-written JSON shape check). Both print `OK` / `FAIL: <reason>` and exit 0/1.
- **Phase 4 validation gates** — Step 1 loads the three output contracts; Step 4 runs the report validator; Step 6 runs the entry validator. Step 7's append is conditional on all three gates having fired.
- **Phase 4 preflight banner** — a `⛔ PHASE 4 PREFLIGHT` block at the top of Phase 4 listing the three gates, their exact tool calls, and required `STATUS:` markers. Reframes the gates as an observable contract with the smoke-test harness rather than internal hygiene.
- **Required STATUS markers** — `STATUS: gates-loaded`, `STATUS: report-ok`, `STATUS: entry-ok`, `STATUS: complete` (success) and `STATUS: partial` (failure) — emitted to the transcript so the smoke test can verify the gates fired.
- **`ctx_stats` added to agent tools array** — Phase 0 calls `ctx_stats()` but the frontmatter was missing the permission entry (latent since v0.0.4). Now explicit.

### Changed

- **Directory reorganization** — `reports/` → `archive/reports/`, `.claude/codelens-exclusions.json` → `config/exclusions.json`, `.claude/review-presets.json` → `config/presets.json`, `schema/` → `templates/`, `references/` → `archive/references/` (gitignored), `examples/sample-report.md` and `references/report-template.md` removed (folded into `templates/report.md`). `scripts/bench-settings.json` → `scripts/bench-mcp-settings.json`.

### Fixed

- **Schema drift on reviews.log entry (persistent since v0.0.1)** — the agent repeatedly produced entries with wrong keys (`timestamp`, `scopeTarget`, `domains`, `outputFile`, `summary: {...}`, `topFindings`, `reviewer`, `methodology`) instead of the flat 11-field schema, because the gate instructions were pseudo-syntax in prose (`ctx_execute_file path: "..."`) that the agent treated as descriptive. Phase 4 now uses real, copy-pasteable JSON tool-call blocks.
- **Step 1 path resolution (v0.0.9-r1 bug)** — `ctx_execute_file` resolved `path: "templates/..."` against the target repo's cwd, not the plugin root. Fixed by switching Step 1 to `ctx_execute` with `fs.readFileSync(process.env.CLAUDE_PROJECT_DIR + '/templates/...')`, matching the pattern already used by Steps 4/6.
- **Agent improvisation on gate failure (v0.0.9-r1 bug)** — when a gate call errored, the agent would substitute its own ad-hoc logic and bypass the remaining gates. Fixed by a Phase-4-wide preflight rule: "If ANY gate call errors or returns empty: do NOT substitute your own logic, do NOT fall back to training data. Print `STATUS: partial` and halt."
- **Step 4 report-path prefix (v0.0.9-r1 bug)** — the validator command incorrectly prefixed the report path with `$CLAUDE_PROJECT_DIR/`, but the report lives at the target repo's root (runtime cwd), not the plugin root. Prefix kept only on the script path.
- **Report format drift (v0.0.8 smoke-test Issue #2)** — agent produced letter-grade scorecards (`Domain | Score | Notes`) instead of the required `Severity | Count | Domain | Count` shape. Fixed by Step 1 loading `templates/report.md` and Step 4's `validate-report.sh` enforcing the structure.

### Smoke test context

The v0.0.9 round 2 smoke test (`docs/smoke-tests/2026-06-19-codelens-v0.0.9-r2-smoke.md`) on my-portfolio (151 files) gave v0.0.9 a PASS:
- ✅ Entry validator: `OK` (was `FAIL: missing required field ts` in v0.0.8 + v0.0.9-r1)
- ✅ Entry uses exactly the 11 short-key schema — no `timestamp`/`scopeTarget`/`topFindings` drift
- ✅ Report validator: `OK` — scorecard has correct `Severity | Count | Domain | Count` shape
- ✅ Both gates ran: `validate-report.sh` → `OK`, `validateEntry(candidate)` → `OK`
- ⚠️ Cosmetic gap: agent emitted `STATUS: complete` but skipped intermediate markers (`gates-loaded`/`report-ok`/`entry-ok`) — substance met, only the test-harness grep affected. Low-priority future tightening.
- The agent hit a context-mode sandbox quirk (an IIFE that overrides `fs.readFileSync`) on its first Step 1 attempt, recovered correctly by routing through `Bash` + hardcoded absolute paths, and proceeded through all gates — demonstrating the "no improvisation" rule works as designed.

---

## [0.0.7] - 2026-06-18

### Changed

- **Phase 3 single-batch refactor** — replaced 15 sequential `ctx_batch_execute` calls (one per hotspot) with ONE batched call containing all hotspot × pattern commands. Validated on pickaboo-frontend (462 files, 15 hotspots, 90 commands): wall-clock 570ms → 230ms (2.48× faster), LLM turns 15 → 1 (~93% reduction). Findings preserved (31 = 31). Same leverage pattern as v0.0.5 Phase 1+2 win, applied to Phase 3. Adds 100-command batch guard: if cmds.length > 100, split into two sequential batches.
- **Phase 3 concurrency 4 → 8** — higher parallelism justified by larger command count per batch.

### Fixed

- **ast-grep pipe-logic fallback bug (silent since v0.0.6)** — `ag-btn-no-aria` and `ag-img-no-alt` commands used `sg ... | rg -v ... | head -20 || rg fallback`. When sg is missing, the pipeline `sg ... | rg -v ... | head` **succeeds with empty output** (exit 0), so the `|| rg fallback` branch never fired. Result: 0 a11y findings on button/img patterns in any environment without ast-grep installed. Fixed by routing on `command -v sg >/dev/null 2>&1 && (sg ...) || (rg ...)` — explicit availability check instead of pipe-empty-success short-circuit. Validated: pickaboo-frontend button-without-aria findings went from 0 → 23 after fix.

## [0.0.6] - 2026-06-18

### Fixed (post-release patch — smoke test 2026-06-18)

Three silent bugs surfaced by the v0.0.6 smoke test (`docs/smoke-tests/2026-06-18-codelens-v0.0.6-smoke-test.md`). All produced empty output that the `|| echo '*-not-available'` terminator swallowed, masking real failures as "tool missing".

- **`p2-tsc` wrong package + missing project flag** — `npx --no-install tsc` resolved to npm package `tsc@2.0.4` (an unrelated Haskell lib). Fixed: `sh -c '( test -x ./node_modules/.bin/tsc && ./node_modules/.bin/tsc -p . ... || npx --yes --package=typescript tsc -p . ... )'`. Tries project-local tsc first, falls back to npx with explicit `--package=typescript`. Also added `-p .` so tsc finds the project tsconfig. Same fix applied to doctor check #11. Verified: produces 18 expected TS6133/TS2307/TS2322 errors on smoke fixture.
- **`r3-complexity` wrong biome JSON field** — grep matched `"file":"..."` but biome v2.2.x emits `"path":"<file>"` (string, not nested object). Fixed command + parse rule in the P2 post-processor. Verified: correctly extracts 13 diagnostics for the fixture file.
- **`p2-biome` non-existent `--quiet` flag** — biome v2.2.x has no `--quiet` flag (`Error: no such flag`). Dropped the flag. Verified: summary reporter now emits rule-level violations (`noGlobalEval`, `useAltText`, `useButtonType`, etc.).

### Added

- **Doctor overhaul (P0)** — `/codelens:doctor` now runs 13 checks (up from 5): validates every context-mode MCP tool individually (`ctx_stats`, `ctx_execute`, `ctx_execute_file`, `ctx_search` via seed+lookup, `ctx_batch_execute`), every required CLI (`rg`, `git`), and the plugin manifest + agent file. Optional-tool warn-only checks for `biome`, `fallow`, `tsc` (via `npx --no-install`), and `ast-grep`. Critical-halt on 8 core dependencies; warn-only on 5 optional tools. Closes the gap where doctor passed but Phase 3 silently failed because only `ctx_stats` was pinged.
- **TypeScript semantic analysis (P3)** — `tsc --noEmit --skipLibCheck` integrated into Phase 2 batched commands. Findings mapped: TS2xxx type errors → Quality High; TS2531/2532 null deref → Quality High; TS6133 unused → Quality Medium; TS2304/2307 cannot find name/module → Quality Medium. Output capped at 4KB to control token cost. Falls back to `tsc-not-available` when typescript isn't installed.

### Changed

- **Phase 3 tool-driven findings (P1)** — replaced 9 embedded JS regex patterns (the `lines.forEach` block) with deterministic AST tools. Per hotspot, one `ctx_batch_execute` runs ast-grep patterns (with rg fallback) for xss/eval/empty-catch/a11y signals. The model now reasons about tool output and assigns severity — no pattern matching in prompt text. Coverage: `innerHTML|dangerouslySetInnerHTML` → ast-grep + biome; `catch(){}` → ast-grep + biome; `<button>/<img>/<input>` a11y → ast-grep + biome. Imports/exports and function-declaration regex dropped (Fallow dead-code + biome complexity cover them in Phase 2).
- **Weighted hotspot selection (P2)** — Phase 1 hotspot ranking replaced pure LOC (`wc -l | sort -rn`) with Risk Score = 0.4×finding_density + 0.2×loc + 0.2×complexity + 0.2×import_centrality. Four new `ctx_batch_execute` commands (`r1-loc`, `r2-finding-density`, `r3-complexity` from biome JSON, `r4-centrality` from import-edge count) feed a single `ctx_execute` post-processor that normalizes and ranks. Top 15 by risk score become Phase 3 hotspots. Catches high-risk small files (high finding density, high inbound imports, high biome complexity) that LOC-only ranking missed. If any signal source is unavailable (e.g., biome missing), that signal is zeroed and remaining re-weighted to 1.0.

### Fixed

- **Version drift** — `plugin.json` and `marketplace.json` were stuck at `0.0.4` while CHANGELOG showed `0.0.5`. All three version fields now synced at `0.0.6`.

---

## [0.0.5] - 2026-06-17

### Changed

- **Phase 1+2 merged into single `ctx_batch_execute` call** — inventory (file count, top files, tech stack) and pattern analysis (security, quality, a11y rg patterns + Biome summary) now run in parallel via one MCP call with concurrency=8. Measured on akg-frontend/components (147 TS/TSX files): Phase 1+2 reduced from ~8 LLM turns to **1 LLM turn**. Token budget: ~5.5K → ~1K. rg verified reachable from sandbox (`which rg` returns `/opt/homebrew/bin/rg`) — no need for Bash-wrapping. Shell-quoting bug from v0.0.1 bypassed entirely (commands are structured strings, not concatenated).
- **Phase 2 AST tools validated** — Biome and Fallow run through `ctx_execute` (for long-lived processes) or `ctx_batch_execute` (when batching). Measured: no token/time difference between approaches — both produce indexed summaries. Current choice validated.
- **Phase 2.5 tool path validated** — Context7 (docs) + WebSearch (CVEs) compared against WebSearch-only. Both are complementary; current spec choice (Context7 for docs, WebSearch for CVEs) validated with ~2-3K combined token cost for comprehensive coverage.
- **Phase 0 preflight restored** — one `ctx_stats` call before Phase 1. Fail-fast on missing dependencies saves more tokens than blind execution costs.

### Fixed

- **Phase 3 FILE_PATH bug** — example code in spec used undefined `FILE_PATH` variable. `ctx_execute_file` only auto-injects `FILE_CONTENT` and `FILE_CONTENT_PATH`. Changed to use `FILE_CONTENT_PATH`. This bug likely caused v0.0.3's "Bash cat fallback" violation.
- **Constraints section updated** — removed "rg must use Bash, not ctx_batch_execute" rule (no longer true; rg runs in sandbox). Added "Phase 1+2: one ctx_batch_execute call" discipline.

### Measured Outcomes

Per-review token budget: ~14K → ~8.5K (**~40% reduction**). Per-review LLM turns: ~25 → ~18 (**~30% reduction**). Findings quality: strictly improved (Biome+Fallow primary alongside rg, not additive).

---

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
