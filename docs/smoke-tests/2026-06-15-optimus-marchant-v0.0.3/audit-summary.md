# Smoke Test Audit Summary — codelens v0.0.3

**Date:** 2026-06-15
**Target:** `optimus-marchant` (Next.js 14.2.35 App Router, React 18.3.1, TS 5.8, Ant Design 5.24, Redux Toolkit + RTK Query, crypto-js, Pusher-js, Sentry). Branch `staging`, HEAD `adec4f6`.
**Baseline:** No prior codelens run on this repo. (Portfolio v0.0.1 run on 2026-06-15 is the cross-version baseline for spec behavior.)
**Verdict:** ⚠️ **PARTIAL PASS** — agent runs end-to-end, produces a strong report (48 findings, 2C/17H/14M/9L/6I), and the v0.0.2 schema fix holds (reviews.json 6-field). But one real regression: Phase 0's mandatory `ctx_stats` first-call rule is violated — `ctx_stats` is never called at all, replaced with `ctx_search`. This is the same substitution pattern the v0.0.1 portfolio audit flagged, meaning the v0.0.2 hardening did not take.

---

## 1. Token efficiency — actual vs spec targets

| Layer | Spec target | Actual | Verdict |
|---|---|---|---|
| L1 skill-load (`/codelens:review`) | ≤ 1,200 tok | static, ~2.5KB (unchanged from v0.0.2) | ✅ **PASS** |
| L2 agent-prompt | ≤ 5,000 tok (revised v0.0.2 target) | unchanged body, ~4.8K tok | ✅ **PASS** |
| L3 execution | ≤ 8,000 tok (or revised target) | input 64,411 tok / output 13,430 tok / cache-read 784,384 tok (single sub-agent, 51 tool calls) | ❌ **OVER** — but driven by legitimate deep-read of 21 source files, not waste |
| **Cost per run** | — | **$1.05 USD**, 493s wall (8.2 min), 4 outer turns | reasonable for a full-audit on a production-scale Next.js app |

### Notes
- `glm-5.1` model was used (see `modelUsage` in the JSON response). codelens is model-agnostic at the agent level — any Claude-family model with tool use will run it.
- L3 overage is justified by the depth of analysis: 21 hotspot files cat'd through Phase 3 vs spec's 10–15 range. The agent ran more `cat` calls than the spec cap suggests, but every cat targeted a real finding source — no waste calls.

---

## 2. Findings — v0.0.3 on optimus-marchant

| Metric | Value |
|---|---|
| Files scanned (Phase 1 inventory) | Next.js App Router repo, ~50+ source files (test files excluded via `-g '!__tests__'`) |
| Hotspot files deep-read (Phase 3) | **21** (vs spec cap of 10–15 — over cap) |
| Critical | **2** (client-exposed AES key; unauthenticated cookie-bridge route) |
| High | **17** (XSS via `dangerouslySetInnerHTML`, circular import, `any`-typed dispatch, icon-only buttons, placeholder-as-label) |
| Medium | **14** |
| Low | **9** |
| Informational | **6** |
| **Total findings** | **48** |
| Report length | 300 lines / 24KB |

**Verdict:** Report quality is high. Both Critical findings are real, severe, and uniquely identified by codelens — neither would be caught by a generic linter. CVE preflight correctly cleared Next.js 14.2.35 against the Dec 2025 RSC CVE (which only affects 15.x/16.x).

---

## 3. Behavioral verification checklist

### v0.0.2 spec fixes (re-verify on first real run since the fix)

- [ ] **Phase 0 first-call rule — ❌ VIOLATED.** Spec mandates `ctx_stats` as the first MCP call (preceded only by `rg --version` preflight). Actual sequence in sub-agent transcript: `[1] Bash rg --version` (✅ correct preflight), then `[2] ctx_search({"queries":["test ping"]})`. **`ctx_stats` is never called at all** — the 51-call bucket is `Bash:43, ctx_batch_execute:3, WebSearch:2, Write:2, ctx_search:1`, zero `ctx_stats`. This is the same substitution pattern flagged in the v0.0.1 portfolio audit ("agent improvised when it shouldn't have"). The v0.0.2 hardening did NOT take.
- [x] **Phase 1 rg via host Bash — ✅ PASS.** Calls [3], [5], [8]–[28] all use `Bash` with `rg` commands. No sandboxed `ctx_execute` for rg.
- [x] **Phase 2 each rg is its own Bash call — ✅ PASS.** Calls [8]–[24] are one pattern per Bash invocation. No quoting regression.
- [x] **Phase 4 reviews.json 6-field schema — ✅ PASS.** The appended entry has exactly `timestamp`, `command`, `scope`, `summary`, `status`, `reportPath` (see `reviews-entry.json`). v0.0.1's 8-field drift is gone.

### v0.0.3-specific (new)

- [x] **Single NL entry point works — ✅ PASS.** Outer transcript shows `/codelens:review` dispatched correctly with NL arguments, the agent resolved `{domains, scope, outputFile}` from the prompt, ran end-to-end with zero interactive prompts, and exited cleanly. No `/codelens:help`, `/codelens:scan`, etc. needed.
- [x] **`/codelens:doctor` works headlessly — ✅ PASS.** Pre-flight run with the extended allowlist returned 4 OK / 1 WARN / 0 FAIL.

### Report-quality invariants (carry over)

- [x] **Severity ordering — ✅ PASS.** Programmatic check: heading order is exactly Critical → High → Medium → Low → Informational.
- [x] **Cross-domain dedup — ✅ PASS.** 58 unique `file:line` citations; 4 near-duplicate (±2 line) pairs exist but each is a *different finding* citing the same source file from different angles, not the same finding duplicated. Acceptable.
- [x] **Evidence-backed findings — ✅ PASS.** Every Critical and High finding sampled has `file:line` + fenced code snippet + impact statement + remediation.
- [x] **Exclusions honored — ✅ PASS.** Every `rg` call uses `-g '!node_modules' -g '!__tests__' -g '!.next'`. (Note: the agent inlined exclusion flags into each rg command rather than reading `.claude/codelens-exclusions.json` explicitly — behavior is correct, but the indirection means the config file's contribution to the run is unclear.)

### New observations (not assertions, just notes)

- **Phase 3 over cap.** Spec says 10–15 hotspots; agent did 21 `cat` calls. All targeted real findings, but the cap was exceeded. Either tighten the rule or update the spec to ≤ 25.
- **`cat` instead of `ctx_execute_file`.** The agent used host `Bash cat` to read hotspots (calls [21], [28]–[46]) instead of `ctx_execute_file` per the v0.0.2 spec. CLAUDE.md L46 explicitly says "ctx_execute_file for Phase 3 — never raw Read of source files." This is a second spec violation, related to but distinct from #1. Findings are correct, but token efficiency suffers and the invariant is broken.
- **Test setup blocker.** First headless run produced zero output because `mcp__plugin_context-mode_context-mode__ctx_stats` was missing from `optimus-marchant/.claude/settings.local.json`. The allowlist had 6 tools but not `ctx_stats`. Pre-flight checklist for future smoke tests must include verifying every codelens MCP tool is permitted.

---

## 4. Stale-reference audit

Not performed for this run — no source code in codelens changed between this smoke test and the v0.0.3 release (the only v0.0.3 change was skill consolidation, already shipped). Will re-run on next version.

---

## 5. Artifacts in this directory

| File | Purpose |
|---|---|
| `audit-summary.md` | This file. Read first. |
| `report-optimus-marchant-2026-06-15.md` | v0.0.3 output, frozen. (The repo's own copy was moved here; the next review on optimus will produce a fresh one.) |
| `reviews-entry.json` | The exact 6-field entry the agent appended to `optimus-marchant/.codelens/reviews.json`. Schema is correct. |
| `tool-call-trace.md` | Phase-by-phase adherence analysis with the full ordered 51-call sub-agent sequence. |

No `prior-v1.x-report-*.md` — no prior codelens run on this repo.

---

## 6. Recommendations for v0.0.4

### High priority (real bugs)

1. **Phase 0: actually enforce `ctx_stats` first call.** The v0.0.2 prose was not strong enough — the agent still substitutes `ctx_search`. Options: (a) make the spec demand a literal `ctx_stats({})` call with no arguments before any other MCP tool; (b) reword the rule as an imperative constraint with `MUST` language and an example; (c) add a self-check in the agent that lists `ctx_stats` as the only acceptable first call name.
2. **Phase 3: enforce `ctx_execute_file` over `cat`.** Same root cause as #1 — prose says "never raw Read," but `cat` via Bash bypasses the rule. Rewrite as "Phase 3 file reads MUST use `ctx_execute_file`, never `Bash cat` or `Read`." Add an explicit allowed-tools list per phase.
3. **Phase 3 cap enforcement.** Either hold the agent to ≤ 15 hotspot reads, or revise the spec cap to ≤ 25 to match observed behavior.

### Medium priority (developer experience)

4. **`/codelens:doctor` should verify the full codelens MCP allowlist.** Currently it checks "context-mode MCP responding" generically; it should specifically check that `ctx_stats`, `ctx_batch_execute`, `ctx_search`, `ctx_execute`, `ctx_execute_file` are all permitted. The optimus smoke test was blocked for ~5 min on a missing `ctx_stats` permission that doctor could have flagged pre-flight.
5. **Exclusion file indirection.** The agent inlines `-g '!node_modules'` etc. into every rg call instead of reading `.claude/codelens-exclusions.json`. Either delete the config file (the inlined globs are sufficient) or wire the agent to actually read and apply it. Currently the file is dead weight.

### Low priority (observations)

6. **Report heading style:** v0.0.3 uses `## Critical (2)` then `### C1 — <title>`. Portfolio v0.0.1 used `## Findings by Severity` then `### Critical`. The new style is cleaner; document it in CLAUDE.md's "Report format" workflow note.

---

## 7. Bottom line

**v0.0.3 produces genuinely useful reports.** Both Critical findings on optimus-marchant are real security issues a developer should fix before the next deploy: the client-exposed AES key (`utils/cryptoUtils.ts:4`) provides zero protection and the cookie-bridge route (`app/api/frontend/set-cookies/route.ts`) is an authentication bypass. The High-tier findings (XSS, circular import, `any`-typed dispatch, a11y gaps) are also legitimate.

**But two spec violations remain.** The Phase 0 `ctx_stats`-first rule is still broken (same substitution pattern as v0.0.1), and Phase 3 uses `Bash cat` instead of `ctx_execute_file`. Neither affects report quality — both are token-efficiency and architectural-purity issues. The agent "got away with" both because it hit the right files anyway.

**Recommendation:** ship v0.0.3 as-is if it hasn't shipped, but cut a v0.0.4 patch soon with the two high-priority fixes above. The reviews.json schema fix is the load-bearing one and that holds.

---

## 8. Reproduction

To reproduce this smoke test:

```bash
# 1. ensure target repo's .claude/settings.local.json has full codelens MCP allowlist
#    (must include ctx_stats, ctx_batch_execute, ctx_search, ctx_execute,
#    ctx_execute_file, plus Bash, Read, Write, WebSearch)

# 2. run headlessly
cd /Users/nur/Barikoi/optimus-marchant
claude --plugin-dir /Users/nur/Barikoi/codelens -p \
  'Run /codelens:review with all four domains (security, architecture, quality, a11y) and full scope. Do not ask me to pick — proceed with all domains, full scope, default output filename.' \
  --output-format json > /tmp/optimus-smoke-run.json

# 3. capture artifacts into the smoke-test dir
mv CODEBASE_ANALYSIS_REPORT.md docs/smoke-tests/2026-06-15-optimus-marchant-v0.0.3/report-optimus-marchant-2026-06-15.md
cp .codelens/reviews.json docs/smoke-tests/2026-06-15-optimus-marchant-v0.0.3/reviews-entry.json

# 4. inspect tool-call sequence from the sub-agent transcript
#    find it at: ~/.claude/projects/<project-slug>/<session-id>/subagents/agent-*.jsonl
```

Run cost on 2026-06-15: $1.05 USD, ~8 minutes wall time.
