# Codelens Pipeline Diagram

Developer reference for reasoning about the codelens review flow. Not consumed by any agent.

## Architecture

Codelens runs as **one agent** (`codelens-reviewer`) behind **seven thin dispatcher skills**. The skills pre-filter everything — which domains, which scope, which optional analyzers — so the agent receives a literal config and executes it verbatim.

This follows Anthropic's [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) guidance: code review is a *well-defined task*, so it should be a *workflow* (predefined code paths) with deterministic filtering in the dispatcher, not agent discretion.

### System overview

The shape of a review: dispatcher skills pre-process the request, the agent runs, two artifacts land at repo root.

```mermaid
flowchart LR
    classDef dispatch fill:#e8f0fe,stroke:#4285f4,color:#1a3a6b
    classDef preprocess fill:#f1f3f4,stroke:#9aa0a6,color:#202124
    classDef agent fill:#e6f4ea,stroke:#34a853,color:#0d652d
    classDef output fill:#fef7e0,stroke:#f9ab00,color:#7a5400

    subgraph S1["Dispatcher skills"]
        R["/codelens:review"]:::dispatch
        RS["/codelens:review-security"]:::dispatch
        RA["/codelens:review-architecture"]:::dispatch
        RQ["/codelens:review-quality"]:::dispatch
        RX["/codelens:review-a11y"]:::dispatch
        RP["/codelens:review-pr"]:::dispatch
        H["/codelens:help"]:::dispatch
    end

    subgraph S2["Pre-processing"]
        P["Parse args & resolve scope<br/>Build literal config"]:::preprocess
    end

    subgraph S3["Execution"]
        A["codelens-reviewer agent<br/>single context, single pass"]:::agent
    end

    subgraph S4["Artifacts"]
        O1["*_REPORT.md<br/>at repo root"]:::output
        O2[".codelens/scan.log<br/>human trace"]:::output
    end

    R --> P
    RS --> P
    RA --> P
    RQ --> P
    RX --> P
    RP --> P
    P --> A
    A --> O1
    A --> O2
```

The dispatcher builds a `{scope, scopePath, outputFile, step2Commands, step2Sources, step2Queries, step3Checks, criteriaDomains}` config object and passes it to the agent. The agent cannot analyze a non-requested domain or scan outside the resolved scope — those commands aren't in the config.

### Agent execution detail

What happens inside the agent invocation. Each step has one job and reads each source file at most once.

```mermaid
flowchart TD
    classDef gate fill:#f1f3f4,stroke:#9aa0a6,color:#202124
    classDef analysis fill:#e6f4ea,stroke:#34a853,color:#0d652d
    classDef verify fill:#e8f0fe,stroke:#4285f4,color:#1a3a6b
    classDef output fill:#fef7e0,stroke:#f9ab00,color:#7a5400
    classDef decision fill:#fff,stroke:#9aa0a6,color:#202124

    G0["Step 0 — ctx_stats + rg --version"]:::gate
    G0h["Step 0.5 — confirm config fields"]:::gate
    S1["Step 1 — Inventory<br/>ctx_batch_execute<br/>codelens:inventory · file-stats · tech-stack"]:::analysis
    S2["Step 2 — Pattern analysis<br/>ctx_batch_execute (verbatim)<br/>ctx_search per source"]:::analysis
    S25["Step 2.5 — Doc & CVE verification<br/>Context7 + WebSearch (on-flag)"]:::verify
    S3["Step 3 — Hotspot deep-dive<br/>ctx_execute_file × ≤ 15 files<br/>all domains in one pass"]:::analysis
    S4["Step 4 — Compile report<br/>severity-first, cross-domain dedup"]:::output

    G0 --> G0h
    G0h --> S1
    S1 --> S2
    S2 --> S25
    S25 --> S3
    S3 --> S4

    D{"Runtime detection<br/>package.json? sg installed?"}:::decision
    D -->|fallow + ast-grep appended| S2
```

Step 2 consumes `config.step2Queries[i]` verbatim for `ctx_search` — the agent never improvises query strings. The runtime-detection branch reflects that fallow and ast-grep commands, when present, flow through Step 2 like any other source — the agent does not special-case them.

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
