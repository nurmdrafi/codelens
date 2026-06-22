# Agent Body Shrink Plan — v0.0.10 → target T_prompt ≤ 7500

**Baseline:** agent body = 41,276 bytes, T_prompt = 10,319. Target: ≤ 30,000 bytes (T_prompt ≤ 7,500).

**Anatomy (by byte size):**

| Section | Bytes | % of body |
|---|---|---|
| `<workflow>` | 31,624 | 77% |
| `<accessibility-criteria>` | 1,647 | 4% |
| `<constraints>` | 1,555 | 4% |
| `<severity-ladder>` | 1,204 | 3% |
| `<security-criteria>` | 983 | 2% |
| `<role>` | 838 | 2% |
| `<architecture-criteria>` | 826 | 2% |
| `<code-quality-criteria>` | 550 | 1% |
| `<responsibilities>` | 287 | 1% |

**Top shrink targets inside `<workflow>`:**

| Block | Bytes | Lines | Shrink strategy |
|---|---|---|---|
| Phase 3 per-file loop | 2,998 | ~50 | Strip inline JS comments that explain what code does. Keep only WHY comments. |
| Phase 1+2 ctx_batch_execute | 2,826 | ~40 | Move domain-conditional commands to a separate block. Collapse common ones. |
| Phase 4 preflight blockquote | 1,315 | ~25 | Convert prose to a 5-bullet checklist. |
| Batch-size guard (split > 100) | 1,190 | ~20 | One-liner conditional + comment. |
| Phase 2 fallow command | 789 | ~15 | Pre-built shell, no commentary. |
| Risk-score post-processor | 775 | ~15 | Tighter JS, drop comments. |

**Cumulative target:** ~7,000 B savings from these six blocks alone = T_prompt ~8,500. Need more from `<constraints>` and `<role>` trims to hit 7,500.

**Iteration plan (first 5):**

1. **Iter 1:** Strip JS comments from Phase 3 per-file loop. Estimated saving: ~1,500 B.
2. **Iter 2:** Condense Phase 4 preflight blockquote → checklist. Estimated saving: ~900 B.
3. **Iter 3:** Compress batch-size guard to one-liner. Estimated saving: ~800 B.
4. **Iter 4:** Trim risk-score post-processor comments. Estimated saving: ~400 B.
5. **Iter 5:** Slim `<constraints>` (1,555 B → target 800 B) by removing overlap with `<severity-ladder>`.

**Guard rails (non-negotiable):**
- Don't remove any actual shell command or JS code logic.
- Don't remove any of: ctx_stats first-call, STATUS: marker triple, schema="1" requirement.
- Don't change agent frontmatter `tools:` list.
- After each iter: run bench, verify findings_total ≥ 20 AND findings_CH ≥ 5 AND exit_code = 0.
- If guard fails: `git revert HEAD --no-edit`, log as discard, move on.
