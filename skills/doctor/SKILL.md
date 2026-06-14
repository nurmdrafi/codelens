---
name: doctor
description: |
  Use to verify codelens setup — checks ripgrep, context-mode MCP, Context7 MCP, plugin manifest, shared resources. Prints [OK]/[WARN]/[FAIL] with fix commands. Triggers: "codelens doctor", "codelens setup check", "/codelens:doctor".
user-invocable: true
argument-hint: ""
---

# Codelens Doctor

Run 5 checks sequentially. Print one line per check with status prefix. Halt on critical fails (1, 4, 5). Warn-only on MCP timeouts (2, 3).

## Checks

1. **`rg` (ripgrep) installed.** Run `rg --version`. On success: `[OK] ripgrep <version>`. On fail: `[FAIL] ripgrep not installed. Install: brew install ripgrep (macOS) or sudo apt-get install ripgrep (Ubuntu/Debian) or choco install ripgrep (Windows).`

2. **context-mode MCP loaded.** Call `mcp__plugin_context-mode_context-mode__ctx_stats` with 5s timeout. On success: `[OK] context-mode MCP responding`. On timeout: `[WARN] context-mode MCP slow/unreachable; may need restart`. On error: `[FAIL] context-mode MCP not loaded. Install: /plugin marketplace add nurmdrafi/context-mode then /plugin install context-mode`.

3. **Context7 MCP loaded.** Call `mcp__plugin_context7_context7__resolve-library-id` with `libraryName:"react"`, `query:"test"` and 5s timeout. On success: `[OK] Context7 MCP responding`. On timeout: `[WARN] Context7 MCP slow/unreachable`. On error: `[FAIL] Context7 MCP not loaded. Install: /plugin marketplace add upstash/context7 then /plugin install context7`.

4. **plugin.json valid.** Read `.claude-plugin/plugin.json`, parse as JSON. On success: `[OK] plugin.json valid (name: <name>, version: <version>)`. On fail: `[FAIL] plugin.json invalid. Reinstall: /plugin install codelens`.

5. **Agent file present.** Read `agents/codelens-reviewer.md` (just check it exists, no parsing). On success: `[OK] agent file present`. On fail: `[FAIL] agents/codelens-reviewer.md missing. Reinstall: /plugin install codelens`.

## Output

After all 5 checks, print summary: `codelens setup: <N> OK, <M> WARN, <K> FAIL`. If any FAIL on critical checks (1, 4, 5), exit with guidance: `Critical checks failed — fix before running /codelens:review.`

## See Also

`/codelens:review` to run a review once setup is verified.
