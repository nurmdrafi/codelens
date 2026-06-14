# Smoke Test Audit Summary — codelens v0.0.1

**Date:** 2026-06-15
**Target:** `my-portfolio` (Next.js 13.4.7 personal portfolio, 45 files / 2,472 LoC)
**Baseline:** Prior v1.x run on same repo, 2026-06-13 (see `prior-v1.x-report-portfolio-2026-06-13.md`)
**Verdict:** ⚠️ **PARTIAL PASS** — agent runs end-to-end and produces a stronger report than v1.x, but 4 spec violations surfaced (3 real bugs + 1 schema drift).

---

## 1. Token efficiency — actual vs spec targets

| Layer | Spec target | Actual | Verdict |
|---|---|---|---|
| L1 skill-load (`/codelens:review`) | ≤ 1,200 tok | **591 tok** (static, 2,366 bytes / 4 chars-per-tok) | ✅ **PASS** (2.0× margin) |
| L2 agent-prompt | ≤ 2,500 tok | **4,763 tok** (static, 19,052 bytes) | ❌ **OVER** by 1.9× (known deviation, documented in CHANGELOG; still 1.36× smaller than v1.8.0) |
| L3 execution | ≤ 8,000 tok | **~12,800 tok** (measured via ctx_stats delta: 524.2K → 537.0K) | ❌ **OVER** by 1.6× |
| **Total per invocation** | ≤ 12,000 tok | **~18,154 tok** | ❌ **OVER** by 1.5× |

### Why L3 went over

L3 overage has three causes, all addressable:

1. **Phase 2.5 was triggered (and should have been).** Next.js 13.4.7 → 3 CVEs verified via WebSearch. This added ~1.5K tokens of high-value content (sourced CVE links). Not waste.
2. **Phase 1 + Phase 2 spec bugs forced re-runs.** Agent hit `rg not on sandbox PATH` and shell-quoting failures, had to split commands. Each retry adds ~500 tokens. ~1K wasted.
3. **15 hotspots vs spec's 10-15 range.** v1.x deep-read 8 files; v0.0.1 deep-read 15. Each `ctx_execute_file` returns a ~300-500 token summary. Hitting the cap costs ~3.5K more than v1.x's 8-file scan.

**True waste:** ~1K tokens (Phase 1+2 retries). Fix the spec bugs → L3 drops to ~11.8K. Still over the 8K target but close.

### Why L2 is over and unlikely to drop without major surgery

The 4 `<*-criteria>` blocks (~150 lines / ~1,800 tok) are essential — they encode the domain knowledge. The Phase 1-4 recipe + report template add ~2,900 tok. Trimming to 2,500 would require dropping a criteria block entirely (lose a domain) or radically compressing the report template.

**Recommendation:** Accept L2 at ~4.8K. Update spec target to ≤ 5,000 tok for v0.0.2.

---

## 2. Findings comparison — v0.0.1 vs v1.x

| Metric | v1.x (2026-06-13) | v0.0.1 (2026-06-15) | Delta |
|---|---|---|---|
| Files scanned | 45 | 45 | same |
| LoC counted | 2,472 | 2,983 | +511 (v0.0.1 counted CSS) |
| Hotspots deep-read | 8 | **15** (cap) | +7 |
| Critical | 0 | **1** (Next.js CVEs) | +1 |
| High | 0 | **3** (form labels, aria-describedby, silent catch) | +3 |
| Medium | 3 | **8** | +5 |
| Low | 5 | 5 | same |
| Informational | 3 | **7** | +4 |
| **Total findings** | **11** | **24** | **+13 (2.2×)** |
| Report length | 308 lines / 19.7KB | 337 lines / 26KB | +29 lines |

**Verdict:** v0.0.1 produces **strictly more thorough** reports than v1.x. The Critical + High tiers are entirely new — v1.x missed the Next.js CVEs, the form-label a11y gap, and the silent-catch UX bug.

### Regression test results

| Issue | v1.x | v0.0.1 | Verdict |
|---|---|---|---|
| EmailJS public-key exposure | M1 (medium) | **M4** (medium) — more nuanced (correctly identifies that EmailJS keys are public by design; flags the mislabeling instead) | ✅ Caught, analysis improved |
| Toast live-region (WCAG 4.1.3) | M1 (medium) | **NOT CAUGHT** | ❌ **True regression** |

---

## 3. Behavioral verification checklist

- [x] Phase 0 first-call rule — **VIOLATED** (agent substituted `ctx_batch_execute` for `ctx_stats`, claiming schema unavailability; controller verified `ctx_stats` IS available)
- [x] Phase 1 single ctx_batch_execute — **SPEC BUG** (`rg` not on sandbox PATH; agent routed through host Bash)
- [x] Phase 2 single ctx_batch_execute — **SPEC BUG** (shell-quoting failures forced split into 4 parallel Bash calls)
- [x] Phase 2.5 on-flag trigger — **PASS** (correctly fired for Next.js + EmailJS)
- [x] Phase 3 ≤ 15 hotspots, no re-reads — **PASS** (15/15 cap, single-pass verified)
- [x] Phase 4 report Write — **PASS** (337-line report written)
- [x] Phase 4 reviews.json append — **PARTIAL** (file created, but schema is 8 fields not 6; missing `command`, `summary`, `status`)
- [x] EmailJS regression — **PASS** (caught as M4 with improved analysis)
- [x] Toast live-region regression — **FAIL** (not caught)

---

## 4. Stale-reference audit

| File | Match | Verdict |
|---|---|---|
| `agents/codelens-reviewer.md` | zero hits on `config.manifest`, `ctxSearchQueries`, `step2Commands`, `_methodology` | ✅ Clean |
| `skills/**/*.md` (all 7) | zero hits | ✅ Clean |
| `CLAUDE.md:27` | mentions `_methodology` to describe its absence | ✅ Legitimate |
| `README.md:11, 224` | mentions `/codelens:help`, `--fallow`, `--ast-grep`, `_methodology` in changelog/stateless description | ✅ Legitimate |
| `CHANGELOG.md` (9 hits) | documents what was removed | ✅ Legitimate |
| `CONTRIBUTING.md:156-163` | **file-tree references deleted files** (`help/SKILL.md`, `_shared/*`, `docs/pipeline-diagram.md`) | ❌ **Real bug — fix in v0.0.2** |

---

## 5. Artifacts in this directory

| File | Purpose |
|---|---|
| `audit-summary.md` | This file. Read first. |
| `report-portfolio-2026-06-15.md` | v0.0.1 output, frozen. (Portfolio's own copy will get overwritten on next review.) |
| `prior-v1.x-report-portfolio-2026-06-13.md` | v1.x baseline, frozen. Side-by-side diff source. |
| `reviews-entry.json` | Exact 6 (well, 8) -field entry the agent appended to `.codelens/reviews.json`. Shows the schema drift. |
| `tool-call-trace.md` | Phase-by-phase adherence analysis with recommendations. |

---

## 6. Recommendations for v0.0.2

### High priority (real bugs)

1. **Phase 1: move `rg` out of ctx_batch_execute.** Sandbox PATH doesn't include ripgrep. Spec should say "use Bash for `rg`, use ctx_batch_execute for non-rg inventory commands."
2. **Phase 2: fix shell-quoting.** Split each rg into its own labeled command in the batch to avoid nested-quote concatenation failures.
3. **Phase 4: tighten reviews.json schema.** Spec lists 6 fields; agent produced 8. Use a literal JSON example with `EXACTLY this shape` language.
4. **CONTRIBUTING.md: fix file-tree.** Lines 156-163 reference 4 deleted files. Replace with actual v0.0.1 tree.
5. **a11y: add toast container pattern.** `rg --no-heading -n '<Toaster'` to flag for missing `aria-live` review. Toast regression must be caught.

### Medium priority (rule-strengthening)

6. **Phase 0: harden first-call rule.** Add explicit "do not substitute" language. Agent improvised when it shouldn't have.
7. **L2 spec target:** revise from ≤ 2,500 to ≤ 5,000 tok. Current 4,763 tok is realistic given 4 criteria blocks are essential.

### Low priority (observations)

8. **LoC counting inconsistency:** v0.0.1 counted 2,983 LoC (included CSS); v1.x counted 2,472 (TS/JS only). Standardize on source files only.
9. **`.codelens/scan.log` cleanup:** v1.x artifact in target repo, not written by v0.0.1. Can be deleted manually; not a bug.

---

## 7. Bottom line

**The v0.0.1 rebuild works.** It produces better reports than v1.x (2.2× more findings, Critical tier that v1.x missed entirely, sourced CVE evidence). The single-pass invariant held. The architecture is sound.

**But the spec has 4 bugs** that the smoke test exposed. None are architectural — all are recipe-level fixes in `agents/codelens-reviewer.md`. A focused v0.0.2 patch (Phase 1+2 spec fixes, Phase 4 schema fix, CONTRIBUTING.md cleanup, toast regression pattern) would close the gap.

**Token efficiency:** L1 is excellent (2× margin). L2 and L3 are over spec targets but the overage is well-spent (more hotspots, real CVE verification, 2.2× more findings). Update the spec targets to match reality rather than treating the overage as failure.
