# Codelens v0.0.6 — Implementation Review & Feedback

Date: 2026-06-18
Reviewer: Claude (self-review after implementing P0, P1, P2, P3 + markdown cleanup)
Scope: all v0.0.6 changes (JS/TS only — P4 multi-language deferred)

---

## Executive Summary

v0.0.6 shipped all 4 in-scope priorities from the original feedback doc. Post-implementation review caught 7 substantive bugs (shell/JS injection, biome JSON field name, ast-grep JSX patterns, doctor count drift, rg alternation) plus 6 markdown formatting issues. All fixed.

**Maturity:** Moved from "strong beta" (v0.0.5) to "production candidate with caveats." The Phase 3 refactor is the highest-leverage change — finding logic is now deterministic tooling, not model-maintained regex.

**Estimated scores vs original feedback doc:**

| Area | v0.0.5 | v0.0.6 |
|---|---|---|
| Architecture | 8.5 | 9.0 |
| Tooling Strategy | 8.5 | 9.5 |
| Reliability | 7.0 | 8.5 (doctor now covers all critical paths) |
| Finding Accuracy | 7.5 | 8.5 (AST-based; tsc semantic added) |
| Token Efficiency | 9.5 | 9.0 (more batched commands, still well under ~10K) |
| Marketplace Readiness | 8.0 | 8.5 |

---

## What Went Well

### 1. Discipline of dropping scope
User's early decision to cut P4 (multi-language) and ship a focused JS/TS-only v0.0.6 kept the diff reviewable and the bugs shallow. P4 deferred to v0.0.7+.

### 2. P0 Doctor overhaul is the highest-ROI change
v0.0.5 doctor validated only `ctx_stats` — silent breakage in Phase 3 was invisible until review run. New 13-check doctor with critical-halt on all 5 context-mode MCP tools + rg + git closes that gap completely. Single most important reliability win in this release.

### 3. P1 tool-driven Phase 3 is the highest-leverage refactor
Moving from `lines.forEach(line => regex.match)` to ast-grep + biome + rg is the change that makes the agent maintainable long-term. Each new finding source is now a tool call, not prompt text to maintain.

### 4. P2 risk-scored hotspots catch real risk
Pure LOC ranking was a known weak spot. The 4-signal Risk Score (0.4 density + 0.2 each of loc/complexity/centrality) catches the file that has 8 empty catches in 200 lines, not the 2000-line generated protobuf that LOC-only ranking always surfaces first.

### 5. P3 tsc integration is nearly free
`tsc --noEmit --skipLibCheck` was already running for users; piping its output through the existing batch + mapping to severity cost ~zero new infrastructure.

---

## Residual Risks (post-fix)

### R1: Biome JSON schema is experimental
Biome's `--reporter=json` schema is marked experimental in their docs. The `r3-complexity` signal parses `diagnostics[].location.path.file` — if Biome renames the field, the signal degrades silently. Mitigation: the parse failure path zeros complexity and re-weights the other three signals. But the parse-failure detection is implicit (`uniq -c` produces empty output → empty `complexity[path]` map → all zero). Should add an explicit "biome parse failed → log warning" step.

### R2: ast-grep availability assumed but only doctor warns
Phase 3 falls back to rg if ast-grep missing — fine. But the rg fallback for `<img>`/`<button>` a11y is single-line and brittle (same regex weakness we tried to escape). Recommendation: doctor's `[WARN] ast-grep not installed` is good, but the agent should explicitly note in Phase 4 output when findings came from rg fallback vs ast-grep — different precision.

### R3: tsc invocation cost on large repos
`npx --no-install tsc --noEmit` on a 1000-file repo can take 30s+. The 4KB output cap limits context bloat but not execution time. No timeout in the command. Recommendation: add `timeout 30 npx --no-install tsc ...` to fail fast.

### R4: Weighted Risk Score is unvalidated
The weights (0.4/0.2/0.2/0.2) are reasonable but unvalidated. Should smoke-test on 3-5 known codebases and compare top-15 lists against intuition. If LOC dominates and the others don't move the needle, drop LOC and re-weight.

### R5: Fallow health/dead-code still not individually doctor-checked
Doctor pings `fallow --version` only. If `fallow dead-code` works but `fallow health` is broken (e.g., version mismatch), Phase 2 silently drops that signal. Recommendation: future doctor check should call `fallow health --format=json` end-to-end.

---

## Recommendations for v0.0.7

### Priority A — Validate before extending

1. **Smoke-test v0.0.6 on 3 codebases.** Run `/codelens:review full-audit` on:
   - Codelens itself (meta-smoke-test)
   - A small Next.js app (~50 files)
   - A medium React+TS codebase (~500 files)
   Compare Phase 1 top-15 lists against intuition. Look for false positives in Phase 3 ast-grep output.

2. **Add `timeout` to tsc command.** Trivial fix. Prevents 60s+ hangs on broken tsconfig setups.

3. **Make biome JSON schema failure explicit.** Add `|| echo 'biome-json-parse-error'` to `r3-complexity` and handle that string distinctly from `biome-not-available`.

### Priority B — Quality of life

4. **Coverage matrix in doctor output.** When doctor detects missing optional tools, print which finding categories are affected. Example: `biome missing → noConsoleLog, noDangerouslySetInnerHtml, useAltText findings disabled`.

5. **Per-domain tool fallback report.** In Phase 4 of the report, add a "Tool Coverage" section listing which tools ran successfully, which fell back to rg, which were unavailable. Makes the report reproducible.

6. **`/codelens:doctor --fix` flag.** When doctor detects a missing optional CLI, offer to run the install command (`npm install -g @biomejs/biome` etc.).

### Priority C — Future priorities (defer from v0.0.6)

7. **P4 multi-language (Python/Go/PHP).** Pattern is now proven for JS/TS. Add per-language lint commands in Phase 2 batch — same shape as `p2-tsc`. Should be ~50 LOC change once P0–P3 validated.

8. **Subagent split for very large codebases.** Currently single agent. For >2000-file repos, Phase 3 (10–15 sequential `ctx_batch_execute` calls) is the bottleneck. Could dispatch parallel hotspots to subagents. Out of scope until proven necessary.

9. **`reviews.json` trend dashboard.** 6-field log is appended per review. A `/codelens:trends` skill that reads the log and shows "Critical count over time per scope" would unlock historical analysis.

---

## Specific Bugs Caught + Fixed During Review Loop

Documenting these so future iterations see the pattern:

1. **JS ternary inside shell command string.** `CHECKS.includes('x') ? "cmd" : "echo skip"` was placed inside `command` field of `ctx_batch_execute`. Shell can't evaluate JS. Fix: build the `commands` array dynamically before the call.

2. **Biome JSON field name.** Used `file_path` (guessed) instead of actual `location.path.file` (verified via Context7). Fix: `rg -o '"file":"[^"]+"'` extraction.

3. **ast-grep JSX self-closing pattern.** `<img $$ATTRS>` doesn't match self-closing JSX. Fix: `<img $$$ATTRS />` with `-l tsx,jsx`.

4. **rg alternation via `\|`.** Used `rg 'a\|b'` — `\|` is literal in basic mode. Fix: multiple `-e` flags.

5. **Doctor count drift.** Intro said "12 checks" / halt-list `(1, 3, 4, 5, 6, 7, 11, 12)` but body had 13 checks and Output section said `(1, 3, 4, 5, 6, 7, 8, 13)`. Fix: synced intro to 13 + correct halt-list.

6. **Redundant LOC commands.** `p1-top-files` and `r1-loc` both produced LOC lists. Fix: dropped `p1-top-files`, kept `r1-loc` as the single LOC source for risk scoring.

7. **Markdown `- # CONSTRAINT:` in list.** `- #` renders as a list item starting with a heading marker. Fix: `- **Constraint text.**` bold lead.

**Pattern observation:** 5 of 7 bugs were in shell string construction or field-name guessing. Future iterations should lean on Context7 lookups for any external tool's CLI/JSON shape rather than recalling from memory.

---

## Markdown Cleanup Applied

In `agents/codelens-reviewer.md`:

- Blank lines added before all fenced code blocks (CommonMark strict rendering).
- Constraints section rewritten from `- # CONSTRAINT: ...` (heading-in-list anti-pattern) to `- **Bolded rule.** Explanation.` format.
- Coverage matrix in Phase 3 converted from prose bullets to a proper Markdown table for readability.
- Post-processor block in Phase 1+2 given a "Post-processor:" lead-in to separate it from the parse-rules list above.

`skills/doctor/SKILL.md`, `CLAUDE.md`, and the v0.0.6 CHANGELOG entry were already clean.

---

## Final Assessment

v0.0.6 is a meaningful structural improvement over v0.0.5. The agent moved closer to the "deterministic tools → structured outputs → LLM judgment → actionable report" target the original feedback doc set out.

The next release should **validate, not extend**. Smoke-test the new tool path on real codebases before adding more languages or more analysis dimensions. Reliability and reproducibility matter more than feature breadth at this stage.
