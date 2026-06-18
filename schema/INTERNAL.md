# Codelens Output Schemas — Internal Spec

> **Internal.** Not user-facing. The agent consults this + the JSON Schema files when emitting any structured output.

## Files

- **[`reviews-entry.schema.json`](./reviews-entry.schema.json)** — JSON Schema for entries appended to `.codelens/reviews.json`. Every review appends exactly one object that conforms.
- **[`report-template.md`](./report-template.md)** — Markdown template for the human-readable report. Currently lives at `examples/sample-report.md`; will be consolidated here.

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
6. **Self-version only.** `reviewerVersion` is the agent's own semver (e.g. `0.0.7`). Never emit third-party tool versions.

## Agent integration

```
Phase 4 → "Compile Report"
  ├── Read schema/reviews-entry.schema.json
  ├── Read schema/report-template.md (or examples/sample-report.md until consolidated)
  ├── Build markdown report following the template
  ├── Build reviews.json entry conforming to the schema
  └── Append entry to .codelens/reviews.json
```

**Validation:** the agent MUST NOT append an entry that fails schema validation. If a field can't be populated (e.g., tool missing), set its value to `0` / `"unknown"` / empty array per the schema's allowance — never invent data.

## Pattern name translation map (Phase 3 → schema keys)

| Phase 3 internal label | Schema `deepDive.byPattern` key |
|---|---|
| `ag-xss-innerhtml` | `unsafe-html-injection` |
| `ag-xss-eval` | `dynamic-code-exec` |
| `ag-empty-catch` | `empty-catch` |
| `ag-btn-no-aria` | `button-without-aria` |
| `ag-img-no-alt` | `image-without-alt` |
| `ag-input-no-label` | `input-without-label` |

## Static analyzer category translation map

| Source rule (tool) | Schema `staticAnalyzer.topCategories[].rule` |
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
| Source code | Schema rule |
|---|---|
| `TS2322` (type mismatch) | `typeError/typeMismatch` |
| `TS6133` (unused) | `typeError/unusedLocal` |
| `TS2304` (cannot find name) | `typeError/missingName` |
| `TS2307` (cannot find module) | `typeError/missingModule` |
| `TS2531` (null deref) | `typeError/nullDeref` |
| `TS2532` (possibly undefined) | `typeError/possiblyUndefined` |
| `TS7xxx`+ (syntax/JSX) | `typeError/syntax` |
