# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
