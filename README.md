# codelens

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://github.com/nurmdrafi/codelens)

Configurable multi-domain code review for Claude Code: **security**, **architecture**, **code quality**, and **accessibility** — on your full repo, a module, or a PR diff.

---

## Install

```
/plugin marketplace add nurmdrafi/codelens
/plugin install codelens
```

Requires [Claude Code](https://claude.ai/code) CLI, desktop app, or IDE extension.

## Quick Start

```bash
# Guided mode — walks you through domain and scope selection
/review

# Full audit — all four domains, entire codebase
/review all

# PR review — security + code quality on your unmerged changes
/review pr-check
```

After scanning, codelens writes a `CODEBASE_ANALYSIS_REPORT.md` (or `PR_REVIEW_<range>.md` for diffs) at your project root with findings organized by severity.

## Recommended Setup

codelens works out of the box, but benefits from optional tools:

| Tool | Required? | Benefit |
|------|-----------|---------|
| **[ripgrep](https://github.com/BurntSushi/ripgrep)** (`rg`) | Recommended | Fast pattern scanning. Install: `brew install ripgrep` or `apt install ripgrep` |
| **[Context7 MCP](https://github.com/nurmdrafi/codelens)** | Optional | Library version verification, CVE checks for security findings |
| **[context-mode MCP](https://github.com/mksglu/context-mode)** | Optional | Reduces token usage on large repos via sandboxed extraction |

Run `/review setup-check` to verify tool availability.

**Note:** Without optional MCPs, codelens still produces full findings — just with reduced accuracy on library-version-dependent checks (security, architecture) and higher token usage on large repos.

## Command Reference

| Command | Domains | Scope |
|---------|---------|-------|
| `/review` | Guided prompt | Guided prompt |
| `/review all` | All four | Full repo |
| `/review security` | Security only | Full repo |
| `/review architecture` | Architecture only | Full repo |
| `/review code-quality` | Code quality only | Full repo |
| `/review accessibility` (or `a11y`) | Accessibility only | Full repo |
| `/review security,architecture` | Custom combination | Full repo |
| `/review all src/lib/payments` | All four | Specific path |
| `/review security diff:main..HEAD` | Security only | Git diff |
| `/review pr-check` | Security + code quality | Diff vs default branch |
| `/review a11y-audit` | Accessibility | Full repo |
| `/review full-audit` | All four | Full repo |
| `/review setup-check` | — | Diagnostic |
| `/review help` | — | Usage cheatsheet |

### Diff Scope

`diff:<range>` scans only changed files:
- `diff:main..HEAD` — all unmerged changes
- `diff:abc123..def456` — specific commit range
- `diff:` (no range) — auto-detects current branch vs default branch

### Presets

Presets define domain + scope combinations. Built-in presets:

| Preset | Domains | Scope |
|--------|---------|-------|
| `pr-check` | security, code-quality | diff |
| `a11y-audit` | accessibility | full |
| `full-audit` | all | full |

Create `.claude/review-presets.json` in your project to override or add presets:

```json
{
  "my-preset": {
    "domains": ["security", "accessibility"],
    "scope": "path",
    "scopeTarget": "src/components"
  }
}
```

## Domains Covered

### Security (OWASP Top 10)
Evaluates against OWASP Top 10 (2021): broken access control, cryptographic failures, injection, insecure design, security misconfiguration, vulnerable components, authentication failures, data integrity failures, logging failures, and SSRF.

### Architecture (SOLID + Patterns)
Evaluates pattern adherence, SOLID compliance (single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion), dependency direction, abstraction levels, service boundaries, data flow, state management, scalability, and maintainability.

### Code Quality
Evaluates logic correctness, error handling at system boundaries, resource management, naming clarity, cyclomatic complexity (<10), duplication, DRY without premature abstraction, performance, async patterns, and test coverage.

### Accessibility (WCAG 2.1 AA)
Evaluates keyboard navigation, screen reader compatibility, visual/color contrast, ARIA attributes, form labeling, heading hierarchy, focus management, and dynamic content announcements.

## How It Works

codelens uses a **3-phase pipeline** designed to minimize token cost:

```
Phase A: Single-Pass Scan
  → One pass over scoped files using ripgrep
  → Combined pattern scan across ALL domains
  → Deep-dive on top 10-15 complexity hotspots
  → Produces: .claude-review/extraction.json

Phase B: Domain Analysis (parallel)
  → Each domain reviewer reads extraction.json (not source files)
  → Security reviewer optionally verifies via Context7 + CVE databases
  → Produces: .claude-review/findings/<domain>.json

Phase C: Merge & Report
  → Cross-domain deduplication (same file:line merged)
  → Severity-first ordering (Critical → Informational)
  → Writes: CODEBASE_ANALYSIS_REPORT.md
  → Cleans up working directory
```

Files are read **at most once** — the extraction data is shared across all domain reviewers, avoiding the 4x token cost of independent scanning.

## Sample Output

See [`examples/sample-report.md`](examples/sample-report.md) for a full anonymized report from a real Next.js e-commerce project (7 Critical, 16 High, 25 Medium, 13 Low, 1 Informational findings).

## Architecture

```
codelens/
├── .claude-plugin/
│   ├── plugin.json            # Plugin manifest
│   └── marketplace.json       # Marketplace listing
├── skills/
│   └── review/
│       └── SKILL.md           # /review command logic
├── agents/
│   ├── codelens-scanner.md    # Phase A: single-pass extractor
│   ├── codelens-reviewer.md   # Orchestrator: Phase C + dispatch
│   ├── security-reviewer.md   # Phase B: security domain
│   ├── architecture-reviewer.md   # Phase B: architecture domain
│   ├── code-quality-reviewer.md   # Phase B: code quality domain
│   └── accessibility-reviewer.md  # Phase B: accessibility domain
├── .claude/
│   └── review-presets.json    # Default presets
└── examples/
    └── sample-report.md       # Anonymized sample report
```

## Customization

### Add/Modify Presets
Edit `.claude/review-presets.json` in your project.

### Modify Domain Criteria
Each domain agent is a markdown file in `agents/`. Edit the criteria section to add/remove checks:
- `agents/security-reviewer.md` — OWASP classification, severity rules
- `agents/architecture-reviewer.md` — SOLID, patterns, state management
- `agents/code-quality-reviewer.md` — complexity, duplication, async
- `agents/accessibility-reviewer.md` — WCAG 2.1 AA, keyboard, ARIA

### Report Format
The report template is in `skills/review/SKILL.md`. Modify sections, severity names, or output format.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Adding new pattern checks to domain agents
- Testing changes locally
- Reporting false positives or missing patterns
- Proposing new domains

PRs welcome! Especially for:
- New domain-specific patterns (security, a11y, architecture, quality)
- New presets for common workflows
- False positive reports with reproduction steps

## License

[MIT](LICENSE) © 2026 nurmdrafi

## Roadmap

- **Delta reports** (`/review all --since-last`) — compare against previous run
- **GitHub Action** — run `pr-check` automatically on every PR
- **Additional domains** — performance, i18n, SEO
- **Config file** — `.codelensrc.json` for project-specific overrides
