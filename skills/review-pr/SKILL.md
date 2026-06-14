---
name: review-pr
description: |
  Use when reviewing a PR or commit range — scans only the diff. Triggers: "PR review", "review pull request", "review diff", "/codelens:review-pr". Defaults to pr-check preset (security+quality on main..HEAD).
user-invocable: true
argument-hint: "[base..head | commit-sha | preset]"
---

# Codelens PR Review

Dispatches `codelens-reviewer` with `scope="diff"`. Parses `$ARGUMENTS` for a range, commit, or preset name.

## Execution

1. Parse `$ARGUMENTS`:
   - Empty → use `pr-check` preset from `.claude/review-presets.json`. Default scopeTarget is `main..HEAD`.
   - `<base>..<head>` (contains `..`) → `scopeTarget = "<base>..<head>"`. Domains from `pr-check` preset (security + quality) unless overridden.
   - `<commit-sha>` (single 7–40 char hex) → `scopeTarget = "<sha>^..<sha>"`. Same default domains.
   - `<preset-name>` (matches a key in `review-presets.json`) → use that preset's `domains` and `scopeTarget`.

2. Resolve config:
   ```json
   {
     "domains": <from preset, default ["security","quality"]>,
     "scope": "diff",
     "scopeTarget": "<resolved range>",
     "outputFile": "PR_REVIEW_<sanitized-scopeTarget>.md"
   }
   ```
   Sanitize `scopeTarget` for filename (replace `..` with `-`, strip slashes).

3. Dispatch `codelens-reviewer`. Report at `outputFile`; log appended at `.codelens/reviews.json`.

## See Also

`/codelens:review` for non-diff scope, `/codelens:doctor` for setup.
