---
name: review
description: |
  Use when running a full multi-domain code review (security + architecture + code quality + accessibility) on a codebase. Triggers: "full code review", "review everything", "audit codebase", "comprehensive review", "/codelens:review".
  For single-domain reviews, use /codelens:review-security, /codelens:review-architecture, /codelens:review-quality, or /codelens:review-a11y instead.
user-invocable: true
argument-hint: "[path | preset | help]"
---

# Codelens Full Review

Runs all four domains (security, architecture, code quality, accessibility) against the codebase. Produces a combined `CODEBASE_ANALYSIS_REPORT.md` at repo root.

## What it does

Invokes the codelens 3-phase pipeline:
1. **Phase A — Scan:** `codelens-scanner` runs a single-pass extraction (rg + ast-grep + fallow) and writes `.codelens-review/extraction.json`.
2. **Phase B — Analyze:** Four domain reviewers (security, architecture, code-quality, a11y) read extraction.json and write `.codelens-review/findings/<domain>.json` in parallel.
3. **Phase C — Compile:** `codelens-reviewer` (orchestrator) merges findings, dedups across domains, applies `skills/_shared/report-template.md`, and writes `CODEBASE_ANALYSIS_REPORT.md` at repo root.

## Argument Parsing

| Input | Behavior |
|---|---|
| `/codelens:review` | Full review on current directory |
| `/codelens:review <path>` | Full review scoped to `<path>` |
| `/codelens:review <preset>` | Full review using a preset from `.claude/review-presets.json` |
| `/codelens:review help` | Show this skill's help |

## Setup

Before running, verify environment by invoking `/codelens:help` (runs the shared setup-check at `skills/_shared/setup-check.md`).

## Execution

1. Parse args (path or preset)
2. Dispatch to `codelens-reviewer` orchestrator agent with `mode=full`
3. Orchestrator runs scanner → Phase B agents → compile
4. On completion: report at `CODEBASE_ANALYSIS_REPORT.md`; raw findings in `.codelens-review/`

## See Also

- `/codelens:review-security`, `/codelens:review-architecture`, `/codelens:review-quality`, `/codelens:review-a11y` — single-domain reviews
- `/codelens:review-pr` — PR diff review
- `/codelens:help` — setup check and command list
