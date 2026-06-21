---
name: doctor
description: |
  Use to verify codelens setup — validates every MCP tool individually (ctx_stats, ctx_execute, ctx_execute_file, ctx_search, ctx_batch_execute), every CLI (rg, git, biome, fallow, tsc, ast-grep), plus Context7 and plugin manifest. Prints [OK]/[WARN]/[FAIL] with fix commands. Triggers: "codelens doctor", "codelens setup check", "/codelens:doctor".
user-invocable: true
argument-hint: "(no arguments)"
---

# Codelens Doctor

Run 13 checks in 3 batched groups (reduces LLM turns vs sequential). Print one line per check with status prefix, sorted by check number within each group. Halt on critical fails (1, 3, 4, 5, 6, 7, 8, 13). Warn-only on optional-tool failures (2, 9, 10, 11, 12).

## Check definitions (reference — same as before batching)

1. **`rg` (ripgrep) installed.** Run `rg --version`. On success: `[OK] ripgrep <version>`. On fail: `[FAIL] ripgrep not installed. Install: brew install ripgrep (macOS) or sudo apt-get install ripgrep (Ubuntu/Debian) or choco install ripgrep (Windows).`

2. **Context7 MCP loaded.** Call `mcp__plugin_context7_context7__resolve-library-id` with `libraryName:"react"`, `query:"test"` and 5s timeout. On success: `[OK] Context7 MCP responding`. On timeout: `[WARN] Context7 MCP slow/unreachable`. On error: `[WARN] Context7 MCP not loaded. Reinstall: /plugin install codelens (Context7 is bundled in plugin.json mcpServers).`

3. **context-mode `ctx_stats` working.** Call `mcp__plugin_context-mode_context-mode__ctx_stats` with 5s timeout. On success: `[OK] ctx_stats responding`. On timeout: `[FAIL] ctx_stats slow/unreachable; context-mode MCP may need restart`. On error: `[FAIL] ctx_stats not loaded. Reinstall: /plugin install codelens (context-mode is bundled in plugin.json mcpServers).`

4. **context-mode `ctx_execute` working.** Call `mcp__plugin_context-mode_context-mode__ctx_execute` with `language:"javascript"`, `code:"console.log('pong')"` and 5s timeout. On success: `[OK] ctx_execute responding (pong)`. On timeout/error: `[FAIL] ctx_execute not working. Same fix as ctx_stats.`

5. **context-mode `ctx_execute_file` working.** Call `mcp__plugin_context-mode_context-mode__ctx_execute_file` with `path:"agents/codelens-reviewer.md"`, `language:"javascript"`, `code:"console.log('file bytes:', FILE_CONTENT.length)"` and 5s timeout. On success: `[OK] ctx_execute_file responding (N bytes)`. On timeout/error: `[FAIL] ctx_execute_file not working. Phase 3 hotspot analysis depends on this.`

6. **context-mode `ctx_search` working.** Seed by calling `mcp__plugin_context-mode_context-mode__ctx_index` with `content:"codelens-doctor-ping"`, `source:"doctor-self-test"`. Then call `mcp__plugin_context-mode_context-mode__ctx_search` with `queries:["codelens-doctor-ping"]` and 5s timeout. On success: `[OK] ctx_search responding`. On timeout/error: `[FAIL] ctx_search not working. Findings retrieval depends on this.`

7. **context-mode `ctx_batch_execute` working.** Call `mcp__plugin_context-mode_context-mode__ctx_batch_execute` with `commands:[{label:"d", command:"echo codelens-doctor-pong"}]`, `queries:["codelens-doctor-pong"]` and 5s timeout. On success: `[OK] ctx_batch_execute responding`. On timeout/error: `[FAIL] ctx_batch_execute not working. Phase 1+2 inventory depends on this.`

8. **`git` installed.** Run `git --version`. On success: `[OK] git <version>`. On fail: `[FAIL] git not installed. Install: brew install git (macOS) or sudo apt-get install git (Ubuntu/Debian).`

9. **`biome` available (optional, auto-fetched via npx).** Run `command -v biome >/dev/null 2>&1 && biome --version || npx --yes @biomejs/biome --version` with 30s timeout (first npx fetch is slow). On success: `[OK] biome <version>`. On fail: `[WARN] biome not available (optional — JS/TS lint/a11y/correctness findings disabled, or set npm config to allow npx auto-fetch).`

10. **`fallow` available (optional, auto-fetched via npx).** Run `command -v fallow >/dev/null 2>&1 && fallow --version || npx --yes fallow --version` with 30s timeout. On fail-pattern: `[WARN] fallow not available (optional — dead-code/dupes/circular-deps disabled).` On success: `[OK] fallow <version>`.

11. **`tsc` available (optional, auto-fetched via npx).** Try `./node_modules/.bin/tsc --version` first (project-local). If missing, try `npx --yes --package=typescript tsc --version` with 30s timeout (downloads typescript if needed). Phase 2 invocation uses `-p .` to pick up the project's tsconfig. On success: `[OK] tsc <version>`. On fail/timeout: `[WARN] tsc not available (optional — TypeScript semantic analysis disabled).`

12. **`ast-grep` available (optional, auto-fetched via npx).** Run `command -v sg >/dev/null 2>&1 && sg --version || npx --yes @ast-grep/cli --version` with 30s timeout. On success: `[OK] ast-grep <version>`. On fail: `[WARN] ast-grep not available (optional — AST-based findings fall back to rg).`

13. **plugin.json valid + agent present.** Read `.claude-plugin/plugin.json`, parse as JSON; also read `agents/codelens-reviewer.md` (existence only). On success: `[OK] plugin manifest valid (name: <name>, version: <version>); agent file present`. On JSON fail: `[FAIL] plugin.json invalid. Reinstall: /plugin install codelens`. On agent missing: `[FAIL] agents/codelens-reviewer.md missing. Reinstall: /plugin install codelens`.

## Execution — 3 batched groups

Run checks in three `ctx_batch_execute` calls instead of 13 sequential tool calls. Within each batch, results are indexed under the check's `label`; print them sorted by check number before moving to the next batch.

### Group 1 — CLI existence (concurrency 5)

Single `ctx_batch_execute` with these 5 commands running in parallel. Halve the wall-clock vs sequential.

```javascript
ctx_batch_execute({
  commands: [
    {label: "check-01-rg",       command: "rg --version 2>&1 | head -1"},
    {label: "check-08-git",      command: "git --version 2>&1"},
    {label: "check-09-biome",    command: "command -v biome >/dev/null 2>&1 && biome --version 2>&1 | head -1 || (npx --yes @biomejs/biome --version 2>&1 | head -1) || echo 'biome-not-available'"},
    {label: "check-10-fallow",   command: "command -v fallow >/dev/null 2>&1 && fallow --version 2>&1 | head -1 || (npx --yes fallow --version 2>&1 | head -1) || echo 'fallow-not-available'"},
    {label: "check-12-astgrep",  command: "command -v sg >/dev/null 2>&1 && sg --version 2>&1 | head -1 || (npx --yes @ast-grep/cli --version 2>&1 | head -1) || echo 'astgrep-not-available'"}
  ],
  concurrency: 5,
  queries: ["check-01", "check-08", "check-09", "check-10", "check-12"]
})
```

Map each result to its `[OK]`/`[WARN]`/`[FAIL]` line per the check definitions above.

### Group 2 — MCP probes (concurrency 3)

Single `ctx_batch_execute`-style sequence, but these are MCP tool calls (not shell). Issue all six; concurrency 3 keeps the MCP server from saturating. Sort by check number when printing.

- check-02: `mcp__plugin_context7_context7__resolve-library-id` (`libraryName:"react"`, `query:"test"`)
- check-03: `mcp__plugin_context-mode_context-mode__ctx_stats`
- check-04: `mcp__plugin_context-mode_context-mode__ctx_execute` (`language:"javascript"`, `code:"console.log('pong')"`)
- check-05: `mcp__plugin_context-mode_context-mode__ctx_execute_file` (`path:"agents/codelens-reviewer.md"`, `language:"javascript"`, `code:"console.log('file bytes:', FILE_CONTENT.length)"`)
- check-06: seed via `mcp__plugin_context-mode_context-mode__ctx_index` (`content:"codelens-doctor-ping"`, `source:"doctor-self-test"`), then `mcp__plugin_context-mode_context-mode__ctx_search` (`queries:["codelens-doctor-ping"]`)
- check-07: `mcp__plugin_context-mode_context-mode__ctx_batch_execute` (`commands:[{label:"d",command:"echo codelens-doctor-pong"}]`, `queries:["codelens-doctor-pong"]`)

Map each result to its `[OK]`/`[WARN]`/`[FAIL]` line per the check definitions.

### Group 3 — Filesystem + special (sequential)

These can't batch cleanly — check-11 has a two-tier binary-then-npx flow with a 30s timeout, and check-13 reads files. Run them sequentially.

- check-11 (tsc): `test -x ./node_modules/.bin/tsc && ./node_modules/.bin/tsc --version || npx --yes --package=typescript tsc --version` (30s timeout).
- check-13 (plugin.json + agent): `ctx_execute({language:"javascript", code:"const fs=require('fs');try{const j=JSON.parse(fs.readFileSync(process.env.CLAUDE_PROJECT_DIR+'/.claude-plugin/plugin.json','utf8'));const a=fs.existsSync(process.env.CLAUDE_PROJECT_DIR+'/agents/codelens-reviewer.md');console.log('OK name='+j.name+' version='+j.version+' agent='+a);}catch(e){console.log('FAIL '+e.message);}"}`).

## Output

After all 3 groups complete, print summary: `codelens setup: <N> OK, <M> WARN, <K> FAIL of 13 checks`. If any FAIL on critical checks (1, 3, 4, 5, 6, 7, 8, 13), exit with guidance: `Critical checks failed — fix before running /codelens:review.`

## See Also

`/codelens:review` to run a review once setup is verified.
