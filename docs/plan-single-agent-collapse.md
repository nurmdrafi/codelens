# Plan: Collapse to a Single Domain-Aware Agent

> **Status:** Shipped in v1.7.0.
> **Supersedes:** the former 6-agent pipeline (`codelens-scanner` + 4 domain reviewers + `codelens-reviewer` orchestrator).

## Context

The 3-phase pipeline's multi-agent decomposition was itself the root inefficiency. Coordinating "don't re-read files" across 6 separate agent contexts (orchestrator + scanner + 4 reviewers) is fundamentally hard, and each agent context loads its own ~3k-token prompt — ~18k tokens of prompt overhead alone, before any analysis. The monolith this project replaced (`references/full-codebase-reviewer.md`) had one context (~5k prompt) and read each file once because there was no second agent to forget.

## Research grounding

Anthropic's own engineering posts, indexed and queried directly:

From [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system):
> "multi-agent systems use about **15× more tokens** than chats"
> "some domains that require all agents to **share the same context** or involve many **dependencies between agents** are **not a good fit** for multi-agent systems today. For instance, **most coding tasks involve fewer truly parallelizable tasks** than research"

Code review is exactly this case: all domains analyze the same source files (shared context), and the "parallelism" is illusory when every reviewer would read the same hotspots. Anthropic explicitly classes coding tasks as a poor fit for multi-agent.

From [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents):
> "good context engineering means finding the **smallest possible set of high-signal tokens** that maximize the likelihood of some desired outcome"
> "System prompts should... present ideas at the **right altitude**... specific enough to guide behavior effectively, yet flexible enough to provide the model with strong heuristics"

From [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents):
> "**Workflows** are systems where LLMs and tools are orchestrated through **predefined code paths**."
> "**Workflows offer predictability and consistency for well-defined tasks**, whereas agents are the better option when flexibility and model-driven decision-making is needed."

Code review is a **well-defined task** — domains and scope are known at dispatch time. The deterministic parts belong in the dispatcher (skill), not in agent discretion. This is why v1.7.0 moved domain/scope filtering into structural dispatcher-side config, not agent instructions.

## Goal (achieved in v1.7.0)

Replace the 6-agent pipeline with **one domain-aware agent** that:
1. Preserves every user-facing feature (all 7 skill commands, presets, scope/path/diff, output filenames, argument forms)
2. Reads each source file exactly once — enforced structurally by single-context execution + simultaneous-multi-domain analysis in `ctx_execute_file` processing code (monolith line 290's trick)
3. Uses context-mode's SQL DB as the analysis substrate (auto-indexed `ctx_batch_execute` + `ctx_search`), not as inter-agent transport
4. Has domain + scope filtering enforced **structurally** by the dispatcher — the skill passes a literal pre-filtered `step2Commands` array and `step3Checks` list; the agent emits them verbatim and cannot leak to non-requested domains

## What shipped

### Single agent (`agents/codelens-reviewer.md`)
- One context. Step 3's hotspot deep-dive is the only source-read step.
- Step 2 emits `config.step2Commands` verbatim — the skill pre-filtered to requested domains.
- Step 3 runs `if (CHECKS.includes("security")) {...}` branches — real code, not comments.
- Step 4 limits Executive Summary and Methodology to `config.criteriaDomains`.

### Thin dispatch wrappers (7 skills)
Each skill parses args, resolves `scopePath`, loads exclusions, copies patterns from `skills/_shared/domain-patterns.md`, and constructs a literal `step2Commands` array for the requested domains only.

### Structural enforcement
The agent literally cannot:
- Run a non-requested domain's patterns (the command isn't in `step2Commands`)
- Scan outside the requested scope (`scopePath` is baked into every command by the skill)
- Report on a domain that wasn't requested (`criteriaDomains` controls the report sections)

### Removed
- `agents/codelens-scanner.md`, `security-reviewer.md`, `architecture-reviewer.md`, `code-quality-reviewer.md`, `a11y-reviewer.md` — folded into the single agent.
- `extraction.json` and all disk handoff — context-mode's index is the substrate.
- Token counts from reports.

### Preserved (unchanged from v1.6.0)
- All 7 user-facing commands and argument forms.
- All output filenames.
- All 3 presets (`pr-check`, `a11y-audit`, `full-audit`) and user-preset support.
- `.claude/codelens-exclusions.json` exclusion semantics.
- Dependency gate, setup-check, and report template.
