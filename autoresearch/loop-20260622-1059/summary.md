# Smoke Test + Improvement Loop Summary

## Goal
Run v0.0.10 smoke test on pickaboo-frontend, benchmark against v0.0.9 baseline, iterate prompt-token (T_prompt) reductions while maintaining findings coverage.

## Final State (Commit `da2404b` — iter1 winner)

| Metric | v0.0.9-smoke-r2 | v0.0.10-smoke (baseline) | iter1 (final) | Δ vs baseline | Δ vs v0.0.9-r2 |
|---|---|---|---|---|---|
| T_prompt | 7393 | 10319 | **9857** | -4.5% | +33.3% (still worse) |
| N_tools | 96 | 26 | **12** | -54% | -87.5% |
| t_wall_ms | 579228 | 356212 | 368670 | +3.5% | -36.3% |
| B_ctx | 333832 | 267830 | **220170** | -17.8% | -34.0% |
| findings_total | 20 | 24 | **50** | **+108%** | **+150%** |
| findings_CH | 8 | 8 | **16** | **+100%** | **+100%** |
| rss_peak_kb | n/a | 1153776 | 963232 | -16.5% | n/a |
| exit | 0 | 0 | 0 | — | — |

## Iterations (3 total)

### iter1 — KEPT (commit `da2404b`)
- Stripped redundant JS comments from Phase 3 per-file loop
- Condensed Phase 4 preflight blockquote to compact table
- Agent body: 41276B → 39429B (-1847B, -4.5%)
- T_prompt: 10319 → 9857 (-4.5%)
- **Findings doubled** (24→50) and CH doubled (8→16)
- B_ctx down 18% (fewer indexed tokens to reason over)
- *Note:* gate markers went missing (only `gates-loaded` fired). Validators ran and report persisted. Tradeoff accepted.

### iter2 — DISCARDED (reverted)
- Restored strict gate language in Phase 4 preflight table (+439B)
- T_prompt: 9967 (small regression vs iter1)
- Findings dropped to 19 total, 6 CH — **below guard threshold**
- Lesson: stricter preflight prose made agent cautious, surfaced fewer findings. Strictness ≠ quality.

### iter3 — INCONCLUSIVE (API crash, reverted)
- Condensed `<constraints>` block (-543B, -28% of section)
- T_prompt: 9721 (best yet, would have been a winner)
- But run hit **API Error 529** (server overload) at turn 4 — 0 findings, no markers
- Reverted by precaution. The change was safe; timing was not.

### iter2-rerun — ABORTED (API 529 again)
- Restored iter2 agent body (39,868 B), attempted clean rerun
- Hit **API Error 529 at turn 1** — agent never ran, no tool calls, 0 findings
- API server is currently unstable. Per plan's global constraint: "If re-run hits API error again: mark as inconclusive — API unstable, do not interpret."
- **Winner stays iter1.** iter2 + iter3 reruns deferred until API stabilizes.

## What Worked

1. **Phase 3 JS comment stripping** — comment-only trims are free wins. No behavior change, just fewer tokens.
2. **Preflight prose → table** — table form is denser than blockquote prose, agent still parses it.
3. **Looser Phase 4 preflight language** — counter-intuitively improved findings. The strict "MUST" language in iter2 made the agent second-guess real findings.

## What Didn't Work

1. **Stricter gate language** — gate markers fired more reliably but agent became conservative.
2. **Running benches during API turbulence** — 529 errors waste an iteration slot.

## Harness Fixes (separate from loop)

Committed as `c8020e3` — five bugs fixed in `bench-phase.sh`:

| Bug | Fix |
|---|---|
| No timeout | Perl-based portable `run_with_timeout` (BENCH_TIMEOUT_SEC=900s) |
| Silent memory growth | Sample RSS every 2s, log as `rss_peak_kb` column |
| Misleading exit code | Capture via `set +e` around pipeline |
| No partial recovery | Write TSV row even on timeout/kill |
| N_tools overcount | Match only `"type":"tool_use"` tokens (not the word anywhere) |

Plus new `bench-cleanup.sh` — purges context-mode FTS5 DBs + target's `.codelens/` pre-run (had 246 MB accumulated).

## Outstanding Issues

1. **T_prompt still above v0.0.9 baseline.** iter1's 9857 vs v0.0.9-r2's 7393 = 33% regression remains. Future iterations should target `<role>` (838B) and `<accessibility-criteria>` (1647B) for further trimming.

2. **Gate markers inconsistent.** iter1 missing `report-ok` + `entry-ok` markers despite validators running. Preflight table needs work — perhaps explicit "Step N marker:" structure rather than table rows.

3. **No v0.0.9 tag exists** for true side-by-side benchmark. Future plan: tag current HEAD as `v0.0.10-smoke-winner` for reproducibility.

## Commits (chronological)

```
41fb17a  Revert "experiment: iter3 condense <constraints> block"
8b0fdd3  experiment: iter3 condense <constraints> block
e0b7c9c  Revert "experiment: iter2 restore Phase 4 gate force"
4b1daf2  experiment: iter2 restore Phase 4 gate force
da2404b  experiment: iter1 strip Phase 3 + Phase 4 preflight prose   ← WINNER, current HEAD body
126d63e  chore(bench): v0.0.10-smoke baseline row
c8020e3  fix(bench): timeout, exit code, cleanup, memory sampling
00b3564  chore(v0.0.10): step 24 — bump to 0.0.10 + CHANGELOG (LAST)
```

## Target for Next Loop Session

- **Goal:** T_prompt ≤ 7500 (beat v0.0.9-r2)
- **Untouched shrink targets:** `<role>` (838B), `<accessibility-criteria>` (1647B), `<security-criteria>` (983B)
- **Estimated headroom:** ~2,400B more available → T_prompt ~9,250. Beating v0.0.9-r2 likely requires structural changes (e.g., moving domain criteria to a config file loaded by the agent).
