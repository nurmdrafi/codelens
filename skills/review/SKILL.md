---
name: review
description: |
  Use when running a codebase review across any combination of security, architecture, code quality, and accessibility. Triggers: "code review", "review codebase", "security review", "PR review", "review diff", "/codelens:review". Defaults to all 4 domains on the entire repo. Accepts NL description of domains, scope, path, or PR range.
user-invocable: true
argument-hint: "[NL: domains + scope + path or PR range]"
---

# Codelens Review

Single entry point. Resolves `{domains, scope, scopeTarget, outputFile}` from the user's prompt, then dispatches `codelens-reviewer`.

## Execution

1. Read `$ARGUMENTS` and infer config:
   - **domains** — subset of `security|architecture|quality|a11y`. Match domain keywords (or OWASP/WCAG/SOLID/"code quality"/"a11y"/"accessibility"). Unspecified → all four: `["security","architecture","quality","a11y"]`.
   - **scope** — `full` (default) | `path` (prompt names a real directory/file) | `diff` (prompt says "PR", "diff", "changes", or a `<base>..<head>` range / commit SHA).
   - **scopeTarget** — `""` for full | `<path>` for path | `<base>..<head>` for diff. Single SHA → `<sha>^..<sha>`.
   - **preset** — if prompt names a preset in `config/presets.json` (`pr-check`, `a11y-audit`, `full-audit`), use its domains/scope as base, then apply NL overrides. Preset domains `"all"` → all four.
   - **outputFile** — single domain → `<DOMAIN>_REPORT.md` (e.g. `SECURITY_REPORT.md`); multiple domains + full/path → `CODEBASE_ANALYSIS_REPORT.md`; diff scope → `PR_REVIEW_<sanitized>.md` (replace `..` with `-`, strip slashes).

2. If `$ARGUMENTS` is empty OR any field is ambiguous, call `AskUserQuestion` to resolve only the ambiguous fields. Defaults: domains=[all four], scope picker [full, path, diff]. If scope=path chosen, follow up for the path string. Do not ask about fields the prompt already disambiguated.

3. Dispatch `codelens-reviewer` with the resolved config. Agent runs Phases 0–4 in one turn and writes the report + appends one 11-field entry to `.codelens/reviews.log`.

## Examples

- `/codelens:review` → AskUserQuestion (bare invocation)
- `/codelens:review full codebase only for security` → `{domains:["security"], scope:"full"}`, output `SECURITY_REPORT.md`
- `/codelens:review src/auth` → `{domains:[all 4], scope:"path", scopeTarget:"src/auth"}`, output `CODEBASE_ANALYSIS_REPORT.md`
- `/codelens:review security and quality of the PR` → `{domains:["security","quality"], scope:"diff", scopeTarget:"main..HEAD"}`, output `PR_REVIEW_main-HEAD.md`
- `/codelens:review abc123..def456` → `{domains:[all 4], scope:"diff", scopeTarget:"abc123..def456"}`
- `/codelens:review abc1234` → single SHA expands to `abc1234^..abc1234`
- `/codelens:review pr-check` → loads preset, `{domains:["security","quality"], scope:"diff", scopeTarget:"main..HEAD"}`

## See Also

`/codelens:doctor` for setup diagnostics.
