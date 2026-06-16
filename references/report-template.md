# Codebase Analysis Report: [project-name]

**Date:** [date]
**Stack:** [detected tech stack]
**Supported languages:** JavaScript/TypeScript (non-JS/TS code receives a partial rg-only review — see Language Support Note if present)
**Domains:** [comma-separated list from config.domains]
**Scope:** [config.scope: config.scopeTarget or "repo root"]

---

## Executive Summary

**Security:** [1-2 sentence posture with critical/high count, or "Not analyzed — not in requested domains"]
**Architecture:** [same]
**Code Quality:** [same]
**Accessibility:** [same]

---

## Critical ([count])

| # | Domain | Issue | Location |
|---|--------|-------|----------|

### Details
[For each Critical finding: title, OWASP/WCAG class, evidence (file:line + snippet), impact, fix]

---

## High ([count])
[Same format]

---

## Medium ([count])
[Same format]

---

## Low ([count])
[Same format]

---

## Informational ([count])
[Table only — no details subsection]

---

## What's Done Well
[Per-domain positive findings with file references, ONLY for domains in config.domains]

---

## Priority Actions
### Immediate (Week 1) — Critical
### Short-Term (Week 2-3) — High
### Medium-Term (Month 1)
### Backlog

---

## Methodology

| Domain | Files Scanned | Focus |
|--------|---------------|-------|

Each requested domain performed analysis using the available tooling (ripgrep for pattern scan; Biome for JS/TS lint+a11y when installed; fallow for dead-code, duplication, complexity, and architecture boundaries when installed; ctx_execute_file for single-pass per-file deep analysis). Findings are evidence-backed with file paths and code snippets, consolidated across requested domains, and ranked by severity.

---

## Language Support Note (include only if non-JS/TS code was the primary target)

The codelens agent's tool integrations (Biome, fallow) target JavaScript and TypeScript. This codebase is primarily **[detected language]**, so the review fell back to language-agnostic rg patterns for quality, architecture, and a11y. Dead-code, duplication, and complexity analysis (fallow) and structured lint+a11y (Biome) were skipped. For full coverage, run codelens on a JS/TS codebase, or wait for v0.0.5+ which adds multi-language tool support.
