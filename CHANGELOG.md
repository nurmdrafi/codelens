# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
