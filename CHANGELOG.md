# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
