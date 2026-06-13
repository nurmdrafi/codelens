# Codelens Pipeline Diagram

Developer reference for reasoning about the codelens review flow. Not consumed by any agent.

## Architecture: single agent + structural dispatcher filtering

Codelens runs as **one agent** (`codelens-reviewer`). The 7 user-facing skills are **dispatchers that pre-filter everything** before the agent runs. The skill knows which domains and scope the user requested, so it constructs a literal `step2Commands` array and `step3Checks` list — the agent executes them verbatim and cannot leak to non-requested domains or out-of-scope paths.

This follows Anthropic's [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) guidance: code review is a *well-defined task*, so it should be a *workflow* (predefined code paths), with deterministic filtering in the dispatcher rather than agent discretion.

```
/codelens:review [path | preset | help]      ─┐
/codelens:review-security [path | help]       │  Each skill (dispatcher):
/codelens:review-architecture [path | help]   │  1. Parse args → determine domains + scope
/codelens:review-quality [path | help]        │  2. Resolve scopePath (full=. / path=string / diff=file list)
/codelens:review-a11y [path | help]           │  3. Load exclusions, build EXCL flags
/codelens:review-pr [range | preset | help]  ─┘  4. Copy patterns from skills/_shared/domain-patterns.md
                                               │  5. Build literal step2Commands (one per requested domain,
                                               │     with scopePath + EXCL baked in)
                                               │  6. Pass config to agent
                                               ▼
               ┌────────────────────────────────────────────────────────┐
               │  codelens-reviewer (single agent, one context)          │
               │  Input config:                                          │
               │    {scope, scopePath, outputFile,                       │
               │     step2Commands: [...pre-filtered...],                │
               │     step2Sources: [...], step3Checks: [...],            │
               │     criteriaDomains: [...]}                             │
               │                                                         │
               │  Step 0:    ctx_stats + rg --version (gate)             │
               │  Step 0.5:  confirm config fields present               │
               │                                                         │
               │  Step 1: Inventory  ── ctx_batch_execute ──┐            │
               │          rg --files + find + wc + manifest │            │
               │          (uses config.scopePath verbatim)  │            │
               │                                                         │
               │  Step 2: Pattern Analysis ── ctx_batch_execute          │
               │          EMITS config.step2Commands VERBATIM            │
               │          *** Agent cannot add/remove commands ***       │
               │          then ctx_search per source in step2Sources     │
               │                                                         │
               │  Step 2.5: Doc/CVE verification (on-flag)               │
               │            Context7 + WebSearch (CVE only if security)  │
               │                                                         │
               │  Step 3: Hotspot Deep-Dive (SINGLE-PASS)                │
               │          For top 10-15 hotspots from Step 1:            │
               │          ONE ctx_execute_file per file.                 │
               │          Processing code: const CHECKS = step3Checks;   │
               │          if (CHECKS.includes('security')) {...}         │
               │          *** Real branches, not comments ***            │
               │          intent: 'codelens:file:<path>' auto-indexes    │
               │                                                         │
               │  Step 4: Compile Report                                 │
               │          native Write to config.outputFile              │
               │          severity-first, cross-domain dedup             │
               │          only criteriaDomains in Executive Summary      │
               │          applies skills/_shared/report-template.md      │
               │          NO token counts anywhere                       │
               │          also writes .codelens/scan.log                 │
               └─────────────────────────────────────────────────────────┘
                                              │
                                              ▼
               Report at repo root:           Scanner trace:
               CODEBASE_ANALYSIS_REPORT.md    .codelens/scan.log
               SECURITY_REPORT.md             (human-readable,
               ARCHITECTURE_REPORT.md          not agent-consumed)
               CODE_QUALITY_REPORT.md
               ACCESSIBILITY_REPORT.md
               PR_REVIEW_<range>.md
```

## What lands where

| Artifact | Location | Notes |
|---|---|---|
| Pattern matches | index: `codelens:<domain>-patterns` | auto-indexed by `ctx_batch_execute` labels; one source per requested domain (filtered by the skill) |
| Inventory + file stats | index: `codelens:inventory`, `codelens:file-stats`, `codelens:tech-stack` | auto-indexed |
| Hotspot file contents | index: `codelens:file:<path>` | single-pass, Step 3 only; auto-indexed via `intent` param |
| Scanner trace | `.codelens/scan.log` | human-readable, NOT agent-consumed |
| Final report | repo root (`*_REPORT.md` or `PR_REVIEW_*.md`) | user-facing |

## Key invariants

1. **One agent context.** The entire review runs in a single agent invocation. No subagent dispatch, no cross-context handoff. This is the structural fix for the re-read coordination problem — there's no second context to lose track of what's been read.

2. **Single-pass source reading.** Source files are read exactly once — by Step 3's hotspot deep-dive (max 15 files). Each `ctx_execute_file` call's processing code runs only the `if (CHECKS.includes(...))` branches for requested domains. Pattern evidence comes via `ctx_search` against auto-indexed Step 2 output, never re-reading source.

3. **Domain filtering is structural.** The skill builds `step2Commands` and `step3Checks` BEFORE dispatch. The agent emits `config.step2Commands` verbatim in Step 2 and substitutes `config.step3Checks` into Step 3's processing code. The agent literally cannot run a non-requested domain — the command and the check id aren't in the config. `/codelens:review-security` runs exactly ONE rg command and ONE Step 3 branch.

4. **Scope filtering is structural.** The skill resolves `scopePath` upfront (full → `.`, path → the path string, diff → literal file list from `git diff --name-only`) and bakes it into every command in `step2Commands`. The agent never computes scope — it receives it.

5. **Mandatory `ctx_batch_execute`.** Steps 1 and 2 run via `ctx_batch_execute` (host shell where `rg` is on PATH). No raw Bash pattern searches.

6. **No token counts in the report.** The Methodology section documents scope/files/tools — not cost.

## Why this design (research grounding)

From Anthropic's [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents):
> "**Workflows** are systems where LLMs and tools are orchestrated through **predefined code paths**."
> "**Workflows offer predictability and consistency for well-defined tasks**, whereas agents are the better option when flexibility and model-driven decision-making is needed."

Code review is a well-defined task — domains and scope are known at dispatch time, not discovered mid-run. The deterministic parts (which rg commands, which file list) belong in the dispatcher, not in agent discretion.

From Anthropic's [multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) post:
> "multi-agent systems use about **15× more tokens** than chats"
> "some domains that require all agents to share the same context... are not a good fit for multi-agent systems today. For instance, **most coding tasks** involve fewer truly parallelizable tasks than research"

Code review shares the same file context across all domains, so the former 6-agent pipeline paid the multi-agent tax without real parallelism benefit.
