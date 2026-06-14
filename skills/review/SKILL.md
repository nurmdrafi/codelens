---
name: review
description: |
  Use when running a multi-domain codebase review. Triggers: "code review", "review codebase", "codebase analysis", "/codelens:review". Defaults to all 4 domains (security, architecture, quality, a11y) on the entire repo. Accepts a domain keyword, a path, both, or NL description.
user-invocable: true
argument-hint: "[security|architecture|quality|a11y|all] [path] [--preset <name>]"
---

# Codelens Full Review

Dispatches `codelens-reviewer` with `domains` from args, defaulting to all four. Supports path scope and presets.

## Execution

1. Parse `$ARGUMENTS`:
   - Empty → invoke `AskUserQuestion` with two questions: (a) domains — options `[All 4 domains (Recommended), Security only, Architecture only, Quality only, A11y only]`, multiSelect false; (b) scope — options `[Entire repo (Recommended), Specific path, PR diff (main..HEAD)]`. If user picks Specific path, follow up with one question asking for the path string.
   - Contains a domain keyword (`security|architecture|quality|a11y|all`) → set `domains` to `["<domain>"]` (or all four for `all`). If multiple keywords present, include all matched.
   - Contains a path-like token (starts with `./` or `/` or contains `/` and exists as a directory) → set `scope = "path"`, `scopeTarget = "<that token>"`, and remove it from the domains parse.
   - Contains `--preset <name>` → load `.claude/review-presets.json` and use that preset's `domains` and `scope`. Unknown preset name → STOP with error.
   - NL description (no keywords matched) → infer which domain(s) apply from the text; default to all four if unclear.

2. Resolve final config:
   ```json
   {
     "domains": <resolved array, default ["security","architecture","quality","a11y"]>,
     "scope": <"full" | "path" | "diff", default "full">,
     "scopeTarget": <"" | "<path>" | "main..HEAD", default "">,
     "outputFile": "CODEBASE_ANALYSIS_REPORT.md"
   }
   ```

3. Dispatch the `codelens-reviewer` agent with this config. The agent runs Phases 0–4 in one turn and writes the report + log entry.

4. On completion: report path is `CODEBASE_ANALYSIS_REPORT.md` at repo root; review log appended at `.codelens/reviews.json`.

## See Also

- `/codelens:review-pr` for diff-scoped review
- `/codelens:review-<domain>` for single-domain shortcuts
- `/codelens:doctor` for setup diagnostics
