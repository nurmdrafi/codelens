# Codelens Output Templates

Output contracts the agent fills in at Phase 4. Both shapes live in this folder:

- **[`report.md`](./report.md)** — Markdown report template (placeholder skeleton with a fully-worked example embedded). The agent consults this at Phase 4 via `ctx_execute_file`.
- **[`reviews-entry.json`](./reviews-entry.json)** — Minimal 6-field shape appended to `.codelens/reviews.json` per review. One object per completed review.

The rules and translation maps below apply to **both** outputs.

## Abstraction rules (apply to ALL output)

These rules are mandatory; deviations are bugs.

1. **No tool names.** Never mention `biome`, `tsc`, `rg`, `ripgrep`, `fallow`, `ast-grep`, `sg`, or any third-party CLI by name.
2. **No plugin names.** Never mention `codelens`, `context-mode`, `context7`, or any Claude Code plugin / marketplace identifier.
3. **No money/cost figures.** Bytes and time only. `$X saved`, `USD`, `cost`, `price` are forbidden.
4. **Semantic rule names only.** Drop tool-specific prefixes:
   - `lint/a11y/useButtonType` → `a11y/buttonType`
   - `lint/style/useImportType` → `style/importType`
   - `lint/security/noDangerouslySetInnerHtml` → `security/unsafeHtml`
   - `lint/suspicious/noArrayIndexKey` → `suspicious/arrayIndexKey`
   - `TS2322`, `TS6133`, etc. → `typeError/typeMismatch`, `typeError/unusedLocal` (preserve semantic)
5. **Generic command form.** Use `/review ...` not `/codelens:review ...`. Use `/doctor` not `/codelens:doctor`.
6. **Self-version only.** `reviewerVersion` is the agent's own semver (e.g. `0.0.8`). Never emit third-party tool versions.

## Agent integration

```
Phase 4 → "Compile Report"
  ├── Read templates/reviews-entry.json (6-field entry shape)
  ├── Read templates/report.md (template + fully-worked example)
  ├── Build markdown report following the template
  ├── Build reviews.json entry conforming to the 6-field shape
  └── Append entry to .codelens/reviews.json
```

All 6 entry fields (`timestamp`, `scope`, `summary`, `findings`, `reportPath`, `reviewerVersion`) are always populatable from the review's runtime state. No fallback-to-zero / unknown handling needed.

## Pattern name translation map (Phase 3 → report)

> These names appear in the **markdown report**'s Standard column and finding titles. The minimal reviews.json log no longer carries them as structured fields — they live in the report only.

| Phase 3 internal label | Report pattern name |
|---|---|
| `ag-xss-innerhtml` | `unsafe-html-injection` |
| `ag-xss-eval` | `dynamic-code-exec` |
| `ag-empty-catch` | `empty-catch` |
| `ag-btn-no-aria` | `button-without-aria` |
| `ag-img-no-alt` | `image-without-alt` |
| `ag-input-no-label` | `input-without-label` |

## Static analyzer category translation map

> These names appear in the **markdown report**'s Standard column. The minimal reviews.json log no longer carries them as structured fields — they live in the report only.

| Source rule (tool) | Report category name |
|---|---|
| `lint/a11y/useButtonType` | `a11y/buttonType` |
| `lint/a11y/noSvgWithoutTitle` | `a11y/svgTitle` |
| `lint/a11y/useAltText` | `a11y/imageAlt` |
| `lint/a11y/useAriaPropsForRole` | `a11y/ariaRole` |
| `lint/a11y/noLabelWithoutControl` | `a11y/labelControl` |
| `lint/security/noDangerouslySetInnerHtml` | `security/unsafeHtml` |
| `lint/security/noGlobalEval` | `security/eval` |
| `lint/suspicious/noArrayIndexKey` | `suspicious/arrayIndexKey` |
| `lint/suspicious/noExplicitAny` | `suspicious/explicitAny` |
| `lint/suspicious/noShadowRestrictedNames` | `suspicious/shadowReserved` |
| `lint/style/useImportType` | `style/importType` |
| `lint/style/noNonNullAssertion` | `style/nonNullAssertion` |
| `lint/style/useTemplate` | `style/template` |
| `lint/correctness/useExhaustiveDependencies` | `correctness/hookDeps` |
| `lint/correctness/noUnusedImports` | `correctness/unusedImports` |
| `lint/correctness/noUnusedVariables` | `correctness/unusedVars` |
| `lint/correctness/noUnusedFunctionParameters` | `correctness/unusedParams` |
| `lint/complexity/useOptionalChain` | `complexity/optionalChain` |
| `lint/complexity/useLiteralKeys` | `complexity/literalKeys` |
| `lint/complexity/noUselessFragments` | `complexity/uselessFragments` |
| `lint/performance/noImgElement` | `performance/imgElement` |

For TS error codes:
| Source code | Report name |
|---|---|
| `TS2322` (type mismatch) | `typeError/typeMismatch` |
| `TS6133` (unused) | `typeError/unusedLocal` |
| `TS2304` (cannot find name) | `typeError/missingName` |
| `TS2307` (cannot find module) | `typeError/missingModule` |
| `TS2531` (null deref) | `typeError/nullDeref` |
| `TS2532` (possibly undefined) | `typeError/possiblyUndefined` |
| `TS7xxx`+ (syntax/JSX) | `typeError/syntax` |
