# Setup Check (shared)

Included by `skills/help/SKILL.md` and any skill that needs to verify the environment before running.

## Required tools

| Tool | Check command | Required? |
|---|---|---|
| `rg` (ripgrep) | `rg --version` | Required — primary search tool |
| context-mode MCP | `mcp__plugin_context-mode_context-mode__ctx_stats` | Required — sandboxed extraction, no fallback |
| Context7 MCP | `mcp__plugin_context7_context7__resolve-library-id` available | Required — library version/CVE verification |

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

## Gate (pre-dispatch check)

Before dispatching any review, run these checks IN ORDER. If any REQUIRED check fails, STOP and print the error message. Do NOT dispatch the agent yet.

1. **ripgrep:** Run `rg --version` via Bash. If it fails: "ripgrep not installed. Install: `brew install ripgrep` (macOS) or `sudo apt install ripgrep` (Linux). Cannot proceed."

2. **context-mode MCP:** Call `mcp__plugin_context-mode_context-mode__ctx_stats`. If it errors: "context-mode MCP not connected. Install: `/plugin marketplace add mksglu/context-mode` then `/plugin install context-mode`. Restart Claude Code after installing. Cannot proceed."

3. **Context7 MCP:** Call `mcp__plugin_context7_context7__resolve-library-id` with `libraryName: "react"`, `query: "test"`. If it errors: "Context7 MCP not connected. Install: `/plugin marketplace add anthropics/claude-plugins-official` then `/plugin install context7`. Restart Claude Code after installing. Cannot proceed."

If all three pass, proceed with dispatch.
