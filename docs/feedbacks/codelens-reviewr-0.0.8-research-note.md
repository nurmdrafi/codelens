# Agent Research Notes

## Goal
Improve the existing Claude Code agent workflow for large-project reviews.

## Session Observations
- Large-project runs trigger repeated permission prompts for MCP/tool execution.
- The agent sometimes fails to match the exact output format.
- After generating output files, the agent may execute again and rewrite files.
- The current agent file feels too large and hard to manage.
- Subagents can help with separation of concerns, but they do not inherit full main-thread context.
- Context-mode MCP is useful for reducing tool-output bloat and preserving session continuity.

## Main Questions
1. How should agent orchestration be structured for maintainability?
2. When should I use a single agent vs subagents?
3. When should I use single-turn vs multi-turn execution?
4. How much context does a subagent actually get?
5. Is context-mode MCP helpful in large review workflows?
6. How can I reduce permission prompts and output-format drift?

## Current Working Hypothesis
- The agent architecture is too monolithic.
- The prompt contains too many phases, fallback rules, and execution details.
- Execution, evidence gathering, and report writing should be separated.
- A thin orchestrator plus specialized subagents is likely better than one giant agent file.

## Desired Improvements
- Smaller, modular agent files.
- Clear delegation rules for subagents.
- Strict, schema-driven output format.
- Fewer permission interruptions.
- Less repeated execution after final output.
- Better token efficiency on large projects.

## Concepts to Research
- Claude Code subagent context behavior.
- Single-agent vs multi-agent orchestration.
- Single-turn vs multi-turn cost tradeoffs.
- Structured outputs / schema enforcement.
- Permission hygiene for Claude Code tools.
- Context-mode MCP as a session-efficiency layer.
- Best practices for large review workflows.

## Constraints
- Keep the final design token-efficient.
- Avoid unnecessary orchestration complexity.
- Prefer evidence-backed findings.
- Avoid re-reading the same files multiple times.
- Keep the final workflow easy to maintain.

## Expected Output From Research
- Recommended agent architecture.
- Recommended subagent boundaries.
- Recommended execution flow.
- Recommended prompt/file organization.
- Risks and tradeoffs.
- A concrete refactor plan for the current agent.