# Setup Check (shared)

Included by `skills/help/SKILL.md` and any skill that needs to verify the environment before running.

## Required tools

| Tool | Check command | Required? |
|---|---|---|
| `rg` (ripgrep) | `rg --version` | Required — primary search tool |
| context-mode MCP | `ctx_stats` (in Claude Code) | Strongly recommended — saves ~3x tokens without it |
| Context7 MCP | `mcp__plugin_context7_context7__resolve-library-id` available | Required for library version/CVE verification |

## Optional tools

| Tool | Check command | Used by |
|---|---|---|
| `fallow` | `npx fallow --version` (in TS/JS projects) | Scanner — dead-code + duplication |
| `sg` (ast-grep) | `sg --version` | Scanner — structural code search |

## Setup-check output format

```
codelens setup check
─────────────────────
[OK]   rg (ripgrep) 14.1.0
[OK]   context-mode MCP available
[OK]   Context7 MCP available
[SKIP] fallow — not a TS/JS project
[OK]   ast-grep 0.34.0

All required tools present.
Optional: 1 skipped, 1 OK.
```

## Fallback warning

If context-mode MCP is not available, print this warning before any review runs:

```
⚠ context-mode MCP not detected. Codelens will work, but expect ~3x token usage.
  Install: https://github.com/<maintainer>/context-mode
```

The review proceeds; the methodology table records `"contextMode": "unavailable — used raw rg"` so users can diagnose high token counts.
