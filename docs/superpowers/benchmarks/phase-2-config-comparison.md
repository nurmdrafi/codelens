# Phase 2 — Empirical 4-Config Comparison

**Date:** 2026-06-17
**Target:** `dockerize-react-app/src` (8 JS files, ~155 LoC)
**Shape:** quality + a11y domains, scope `./src`
**Purpose:** Pick the Phase 2 configuration that best trades prompt size for findings quality.

## Results

| Config | T_prompt | N_tools | t_wall (s) | Findings | Critical/High | Δ T_prompt |
|---|---|---|---|---|---|---|
| 1 (rg-only baseline) | 5,420 | 108 | 194 | 9 | 1 | — |
| 2 (Biome-only) | 5,570 | 135 | 227 | 15 | 5 | +150 |
| 3 (fallow-only) | 5,659 | 126 | 304 | 13 | 4 | +239 |
| 4 (Biome + fallow + semgrep full) | 5,743 | 141 | 326 | 17 | 5 | +323 |

All 4 runs: same target, same domains, same scope. Variance from agent non-determinism established earlier (N_tools ±15, t_wall ±30s, findings ±3) means the N_tools/t_wall deltas are within noise. **T_prompt is deterministic. Findings counts are directionally meaningful.**

## What each config catches that the baseline misses

- **Config 1 (rg baseline)** catches: console.log usage, TODO/FIXME markers, eslint-disable, empty catch, basic alt/aria attribute counts, img without alt. **Misses:** SVG a11y (Biome catches), dead files/deps (fallow catches), duplication (fallow catches), complexity hotspots (fallow catches), circular deps (fallow catches).

- **Config 2 (Biome)** adds: 491 lint rules covering correctness/suspicious patterns, 15+ a11y rules including SVG-specific checks. Caught the SVG-missing-title issue on `logo.svg` in 9ms.

- **Config 3 (fallow)** adds: AST-based dead-code analysis (caught 2 dead files + 1 unused dep), duplication (0 on this target), maintainability scoring (90.3 avg), complexity hotspots. 38ms total.

- **Config 4 (full combo)** adds all of the above, plus semgrep SAST (0 findings on this clean target — would matter on real code).

## Cost-benefit analysis

**Prompt cost (T_prompt delta):**
- Config 2: +150 tokens (2.8% increase)
- Config 3: +239 tokens (4.4% increase)
- Config 4: +323 tokens (6.0% increase)

**Findings quality gain:**
- Config 2: +6 findings, +4 CH (67% more findings, 5× more CH)
- Config 3: +4 findings, +3 CH (44% more findings, 4× more CH)
- Config 4: +8 findings, +4 CH (89% more findings, 5× more CH)

**The tradeoff:** every config trades ~150-323 prompt tokens (paid once per invocation, loaded into context) for substantially richer findings. The tokens-per-finding-gained ratio is favorable in all cases.

**Mitigation for prompt cost:** Phase 4 (extract report template, separate task) reclaims ~284 prompt tokens — more than offsets Config 2's +150. Net prompt change for v0.0.4 with Config 2 + Phase 4: ~-134 tokens (5,286 vs 5,420). Config 4 + Phase 4: -~39 tokens.

## Winner: Config 4 (full combo)

**Rationale:**
1. **Highest findings count (17) and tied-highest CH (5)** — the point of the optimization is better reviews, and Config 4 delivers the best signal.
2. **Covers all 4 domains** with validated tools: semgrep (security), fallow (architecture + dead-code + duplication + complexity), Biome (lint + a11y). Configs 2 and 3 each leave one domain on rg-only.
3. **Prompt cost (+323 tokens) is more than offset by Phase 4 template extraction (-284)** — net change is roughly neutral.
4. **Detect-and-fallback design** means users without any tools installed get exactly the v0.0.3 rg experience. No regression for them.
5. **fallow alone collapses 3 tools into 1** — knip and jscpd were redundant once fallow was in the stack. Config 4 is the leanest way to get full coverage.

## Caveats and open questions

- **semgrep's 0 findings here don't validate it** — the target is a clean CRA scaffold. semgrep's value (per the tool-validation report: 87% TPR, but 42% FPR) needs validation on a target with actual security issues. The my-portfolio target (with its `window._env_` injection pattern) would be a better test in a future cycle.
- **Agent non-determinism** means the absolute N_tools/t_wall numbers in this table aren't reproducible — re-running Config 1 might give 95 or 120 tools. What IS reproducible: T_prompt (file size) and the directional findings improvement.
- **Phase 3 confirmation is mandatory for semgrep findings** — the report's 42% FPR means every semgrep-surfaced issue needs human/agent verification before going in the report as a confirmed bug.

## Decision

**Config 4 is the winner — with one revision.** Apply to `agents/codelens-reviewer.md` Phase 2 as the final v0.0.4 implementation. Pair with Phase 4 template extraction (Task 3 in the plan) to keep the net prompt size near v0.0.3 baseline.

### Revision: drop semgrep

**Post-comparison validation** ran semgrep directly against my-portfolio/components (which has real security-adjacent surface: `process.env.NEXT_PUBLIC_EMAILJS_API_KEY` client exposure at components/contact/index.tsx:30, `dangerouslySetInnerHTML` at components/common/meta.tsx:51, `catch (error: any)` at components/contact/index.tsx:42). semgrep found **0 findings across 3 rulesets** (`--config auto`, `--config p/owasp-top-ten`, `--config p/react --config p/typescript --config p/javascript`).

The existing rg security patterns catch all three of those patterns. semgrep CE adds:
- 2-minute pip install cost
- ~42% FPR per the tool-validation report (mandatory Phase 3 confirmation)
- 0 incremental findings on real code

**Verdict: drop semgrep from v0.0.4.** The final stack is **Biome + fallow + rg**. Security stays on rg patterns (unchanged from v0.0.3). Architecture moves to fallow. Quality splits: lint+a11y via Biome, dead-code+duplication+complexity via fallow.

This is effectively Config 4 minus the semgrep block. Expected final T_prompt: ~5,600 tokens (Config 4 was 5,743; semgrep block was ~143 tokens). Combined with Phase 4 template extraction (-284), net prompt change vs v0.0.3: roughly -100 tokens, while findings quality improves significantly on quality + architecture + a11y domains.
