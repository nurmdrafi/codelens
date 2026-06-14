# Tool-Call Trace — 2026-06-15 Portfolio Smoke Test

Source: agent's self-report + observed constraints. The agent was dispatched via `Agent` tool with `subagent_type: codelens:codelens-reviewer` and a hand-crafted config mimicking `skills/review/SKILL.md`'s output for bare `/codelens:review`.

## Phase-by-phase adherence to spec

| Phase | Spec requirement | Observed | Verdict |
|---|---|---|---|
| 0 | FIRST tool call MUST be `ctx_stats` | Agent claimed `ctx_stats` "unavailable on schema" (it isn't — controller called it twice successfully) and substituted `ctx_batch_execute` as the first MCP probe. | ❌ **Spec violation** — agent improvised instead of following the mandatory-first-call rule. Phase 0's purpose (verify MCP loaded) was achieved, but the rule itself was broken. |
| 1 | ONE `ctx_batch_execute` with 3 inventory commands | Agent's `rg --files` inside `ctx_batch_execute` failed with `command not found: rg` — the ctx-mode sandbox has a restricted PATH that excludes ripgrep. Agent routed `rg` through host `Bash` and used `find`-based commands inside the sandbox. | ❌ **Spec bug** — the recipe literally says `rg --files <scopePath>` inside `ctx_batch_execute`. This will always fail when `rg` is in a non-sandbox PATH. |
| 2 | ONE `ctx_batch_execute` with all-4-domain rg gated by `config.domains` | First combined security rg command failed with unmatched-quote error (nested single quotes in `SECRET\|PASSWORD\|API_KEY\|TOKEN` regex alternation broke zsh parsing). Agent split into 4 parallel per-domain Bash calls. | ❌ **Spec bug** — shell-quoting issues undermine the "single ctx_batch_execute" parallelism claim. Agent recovered but spec contract broken. |
| 2.5 | On-flag only — skip if Phase 2 found nothing flag-worthy | Agent correctly triggered Phase 2.5: Phase 2 flagged `next: "13.4.7"` and EmailJS SDK → Context7/WebSearch used for 3 Next.js CVEs (CVE-2025-29927, CVE-2025-55182, CVE-2025-66478). | ✅ Pass — triggered correctly with strong evidence. |
| 3 | `ctx_execute_file` per hotspot (hard cap: 15), single-pass | Agent hit the 15-file cap. Files: `contact/index.tsx`, `timeline/index.tsx`, `common/card-3d.tsx`, `about/index.tsx`, `blog/blog-card.tsx`, `common/meta.tsx`, `common/footer.tsx`, `banner/social-links.tsx`, `common/scroll-to-top.tsx`, `pages/_app.tsx`, `pages/index.tsx`, `navbar/menu-items.tsx`, `banner/full-name.tsx`, `customers/client-logo.tsx`, `lib/utils.ts`. | ✅ **Pass** — 15/15 cap, single pass, no file read twice. |
| 4 | `Write` report + append to `.codelens/reviews.json` | Both succeeded. BUT: the reviews.json entry has **8 fields instead of the spec's 6**. Actual fields: `date` (should be `timestamp`), `scope`, `scopeTarget` (extra), `domains` (extra), `filesScanned` (extra), `findings` (extra), `reportPath`. **Missing from spec:** `command`, `summary`, `status`. | ⚠️ **Partial pass** — files written, but log schema wrong. |

## Summary of findings

- 2 spec **bugs** requiring code changes (Phase 1 rg-in-sandbox, Phase 2 shell quoting)
- 1 spec **rule violated** by agent improvisation (Phase 0 first-call rule)
- 1 spec **schema mismatch** in Phase 4 (reviews.json fields)
- 1 Phase (2.5) and 1 Phase (3) fully compliant
- Phase 3 single-pass invariant: **HELD** ✅

## What went well

- Critical CVE finding with 3 sourced links — strongest possible evidence
- 2.2× more findings than v1.x baseline on the same codebase
- Single-pass file reads — the most important invariant held
- Phase 2.5 (Context7/WebSearch) triggered correctly and produced high-value additions
- EmailJS issue caught with MORE nuance than v1.x (correctly identified that the "API_KEY" is a public key by design; real issue is the mislabeling)

## What regressed vs v1.x

- **Toast live-region (WCAG 4.1.3) NOT flagged.** v1.x caught this as M1. v0.0.1 mentions `react-hot-toast` only in tech-stack and catch-block contexts, never flags the missing `aria-live` on toast notifications. The a11y Phase 2 pattern `'aria-live'` should have surfaced this gap. **True regression to fix in v0.0.2.**

## Recommendations for next refactoring (v0.0.2)

1. **Fix Phase 1 rg-in-sandbox bug.** Move `rg` commands out of `ctx_batch_execute` into host `Bash`. Keep `ctx_batch_execute` for `find`, `wc`, `cat package.json` etc. that work fine in the sandbox.
2. **Fix Phase 2 shell-quoting.** Either (a) split each rg into its own labeled command in the batch (avoiding nested-quote concatenation), or (b) escape quotes more carefully in the spec examples.
3. **Strengthen Phase 0 first-call rule.** Add explicit instruction: "If you are tempted to substitute `ctx_batch_execute` for `ctx_stats` as your first call, STOP — the rule is non-negotiable. Call `ctx_stats` even if you believe it will fail."
4. **Fix reviews.json schema.** The agent file's Phase 4 spec lists 6 fields (`timestamp`, `command`, `scope`, `summary`, `status`, `reportPath`). The agent produced 8 different fields. Tighten the spec language from "appends one entry" to "appends EXACTLY this object shape" with a literal JSON example.
5. **Add toast/live-region to a11y Phase 2 patterns.** Current patterns include `aria-live` count, but the agent didn't surface the *absence* of `aria-live` on `react-hot-toast`'s `<Toaster />`. Consider a pattern like `rg --no-heading -n '<Toaster' <scopePath> <EXCL>` to flag toast containers for manual review.
6. **Fix CONTRIBUTING.md file tree.** Lines 156-163 reference deleted files (`help/SKILL.md`, `_shared/*`, `docs/pipeline-diagram.md`). Replace with the actual v0.0.1 tree including `doctor/SKILL.md`, `examples/`, `references/`.
