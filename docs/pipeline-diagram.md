# Codelens Pipeline Diagram

Developer reference for reasoning about the codelens review flow. Not consumed by any agent.

## Architecture: single agent + structural dispatcher filtering

Codelens runs as **one agent** (`codelens-reviewer`). The 7 user-facing skills are **dispatchers that pre-filter everything** before the agent runs. The skill knows which domains and scope the user requested, so it constructs a literal `step2Commands` array and `step3Checks` list — the agent executes them verbatim and cannot leak to non-requested domains or out-of-scope paths.

This follows Anthropic's [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) guidance: code review is a *well-defined task*, so it should be a *workflow* (predefined code paths), with deterministic filtering in the dispatcher rather than agent discretion.

```mermaid
flowchart TD
    subgraph dispatch["7 dispatcher skills (pre-filter everything)"]
        A["/codelens:review [--domains list | --preset name | path]<br/>/codelens:review-security<br/>/codelens:review-architecture<br/>/codelens:review-quality<br/>/codelens:review-a11y<br/>/codelens:review-pr [range | preset]"]
        A --> B["1. Parse args → determine domains + scope<br/>(--domains overrides --preset > default all 4)"]
        B --> C["2. Resolve scopePath<br/>(full=. / path=string / diff=file list)"]
        C --> D["3. Load exclusions, build EXCL flags"]
        D --> E["4. Copy patterns from domain-patterns.md"]
        E --> F["5. Build literal step2Commands + step2Sources + step2Queries<br/>(positional linkage: index i across all three)"]
        F --> G{"6. Runtime detection<br/>(test -f package.json, command -v sg)"}
        G -->|"package.json AND arch/quality in domains"| H["Append fallow dead-code + dupes"]
        G -->|"sg installed AND domain has patterns"| I["Append ast-grep patterns per domain<br/>(dedupe by source label)"]
        H --> J["7. Pass config to agent"]
        I --> J
        G -->|"neither detected"| J
    end

    J --> K["codelens-reviewer (single agent, one context)"]

    subgraph agent["Agent execution"]
        K --> L["Step 0: ctx_stats + rg --version (gate)"]
        L --> M["Step 0.5: confirm config fields present"]
        M --> N["Step 1: Inventory<br/>ctx_batch_execute<br/>(codelens:inventory, codelens:file-stats, codelens:tech-stack)"]
        N --> O["Step 2: Pattern Analysis<br/>EMITS config.step2Commands VERBATIM<br/>then ctx_search per source<br/>USING config.step2Queries VERBATIM"]
        O --> P["Step 2.5: Doc/CVE verification (on-flag)<br/>Context7 + WebSearch"]
        P --> Q["Step 3: Hotspot Deep-Dive (SINGLE-PASS, max 15 files)<br/>ONE ctx_execute_file per file<br/>Processing code: const CHECKS = step3Checks<br/>if CHECKS.includes('security') {...}<br/>intent: 'codelens:file:path'"]
        Q --> R["Step 4: Compile Report<br/>native Write to outputFile<br/>severity-first, cross-domain dedup"]
    end

    R --> S["Report at repo root<br/>(CODEBASE_ANALYSIS_REPORT.md, etc.)"]
    R --> T[".codelens/scan.log<br/>(human-readable, not agent-consumed)"]
```

**Input config object** (built by the dispatcher, consumed verbatim by the agent):

```
{scope, scopePath, outputFile,
 step2Commands: [...pre-filtered...],
 step2Sources: [...],
 step2Queries: [...],         # 1.7.1: positional query vocabulary per source
 step3Checks: [...],
 criteriaDomains: [...]}
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

3. **Domain filtering is structural.** The skill builds `step2Commands`, `step2Sources`, `step2Queries`, and `step3Checks` BEFORE dispatch (all four positionally linked). The agent emits `config.step2Commands` verbatim in Step 2, consumes `config.step2Queries[i]` verbatim for `ctx_search`, and substitutes `config.step3Checks` into Step 3's processing code. The agent literally cannot run a non-requested domain — the command and the check id aren't in the config. `/codelens:review-security` runs exactly ONE rg command and ONE Step 3 branch.

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
