---
name: doctor
description: |
  Use to verify codelens setup — validates every MCP tool individually (ctx_stats, ctx_execute, ctx_execute_file, ctx_search, ctx_batch_execute), every CLI (rg, git, biome, fallow, tsc, ast-grep), plus Context7 and plugin manifest. Prints [OK]/[WARN]/[FAIL] with fix commands. Triggers: "codelens doctor", "codelens setup check", "/codelens:doctor".
user-invocable: true
argument-hint: "(no arguments)"
---

# Codelens Doctor

Run 13 checks sequentially. Print one line per check with status prefix. Halt on critical fails (1, 3, 4, 5, 6, 7, 8, 13). Warn-only on optional-tool failures (2, 9, 10, 11, 12).

## Checks

1. **`rg` (ripgrep) installed.** Run `rg --version`. On success: `[OK] ripgrep <version>`. On fail: `[FAIL] ripgrep not installed. Install: brew install ripgrep (macOS) or sudo apt-get install ripgrep (Ubuntu/Debian) or choco install ripgrep (Windows).`

2. **Context7 MCP loaded.** Call `mcp__plugin_context7_context7__resolve-library-id` with `libraryName:"react"`, `query:"test"` and 5s timeout. On success: `[OK] Context7 MCP responding`. On timeout: `[WARN] Context7 MCP slow/unreachable`. On error: `[WARN] Context7 MCP not loaded. Install: /plugin marketplace add upstash/context7 then /plugin install context7`.

3. **context-mode `ctx_stats` working.** Call `mcp__plugin_context-mode_context-mode__ctx_stats` with 5s timeout. On success: `[OK] ctx_stats responding`. On timeout: `[FAIL] ctx_stats slow/unreachable; context-mode MCP may need restart`. On error: `[FAIL] ctx_stats not loaded. Install: /plugin marketplace add nurmdrafi/context-mode then /plugin install context-mode`.

4. **context-mode `ctx_execute` working.** Call `mcp__plugin_context-mode_context-mode__ctx_execute` with `language:"javascript"`, `code:"console.log('pong')"` and 5s timeout. On success: `[OK] ctx_execute responding (pong)`. On timeout/error: `[FAIL] ctx_execute not working. Same fix as ctx_stats.`

5. **context-mode `ctx_execute_file` working.** Call `mcp__plugin_context-mode_context-mode__ctx_execute_file` with `path:"agents/codelens-reviewer.md"`, `language:"javascript"`, `code:"console.log('file bytes:', FILE_CONTENT.length)"` and 5s timeout. On success: `[OK] ctx_execute_file responding (N bytes)`. On timeout/error: `[FAIL] ctx_execute_file not working. Phase 3 hotspot analysis depends on this.`

6. **context-mode `ctx_search` working.** Seed by calling `mcp__plugin_context-mode_context-mode__ctx_index` with `content:"codelens-doctor-ping"`, `source:"doctor-self-test"`. Then call `mcp__plugin_context-mode_context-mode__ctx_search` with `queries:["codelens-doctor-ping"]` and 5s timeout. On success: `[OK] ctx_search responding`. On timeout/error: `[FAIL] ctx_search not working. Findings retrieval depends on this.`

7. **context-mode `ctx_batch_execute` working.** Call `mcp__plugin_context-mode_context-mode__ctx_batch_execute` with `commands:[{label:"d", command:"echo codelens-doctor-pong"}]`, `queries:["codelens-doctor-pong"]` and 5s timeout. On success: `[OK] ctx_batch_execute responding`. On timeout/error: `[FAIL] ctx_batch_execute not working. Phase 1+2 inventory depends on this.`

8. **`git` installed.** Run `git --version`. On success: `[OK] git <version>`. On fail: `[FAIL] git not installed. Install: brew install git (macOS) or sudo apt-get install git (Ubuntu/Debian).`

9. **`biome` installed (optional).** Run `biome --version`. On success: `[OK] biome <version>`. On fail: `[WARN] biome not installed (optional — JS/TS lint/a11y/correctness findings disabled). Install: npm install -g @biomejs/biome.`

10. **`fallow` installed (optional).** Run `fallow --version`. On fail-pattern: `[WARN] fallow not installed (optional — dead-code/dupes/circular-deps disabled). Install: see fallow docs.` On success: `[OK] fallow <version>`.

11. **`tsc` available (optional).** Try `./node_modules/.bin/tsc --version` first (project-local). If missing, try `npx --yes --package=typescript tsc --version` with 15s timeout (downloads typescript if needed). Phase 2 invocation uses `-p .` to pick up the project's tsconfig. On success: `[OK] tsc <version>`. On fail/timeout: `[WARN] tsc not available (optional — TypeScript semantic analysis disabled). Install: npm install -D typescript.`

12. **`ast-grep` installed (optional).** Run `sg --version`. On success: `[OK] ast-grep <version>`. On fail: `[WARN] ast-grep not installed (optional — AST-based findings fall back to rg). Install: npm install -g @ast-grep/cli.`

13. **plugin.json valid + agent present.** Read `.claude-plugin/plugin.json`, parse as JSON; also read `agents/codelens-reviewer.md` (existence only). On success: `[OK] plugin manifest valid (name: <name>, version: <version>); agent file present`. On JSON fail: `[FAIL] plugin.json invalid. Reinstall: /plugin install codelens`. On agent missing: `[FAIL] agents/codelens-reviewer.md missing. Reinstall: /plugin install codelens`.

## Output

After all checks, print summary: `codelens setup: <N> OK, <M> WARN, <K> FAIL of 13 checks`. If any FAIL on critical checks (1, 3, 4, 5, 6, 7, 8, 13), exit with guidance: `Critical checks failed — fix before running /codelens:review.`

## See Also

`/codelens:review` to run a review once setup is verified.
