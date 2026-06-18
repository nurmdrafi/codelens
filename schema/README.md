# Codelens Output Schemas

Structured output contracts used by codelens reviews.

## Files

- **[`reviews-entry.schema.json`](./reviews-entry.schema.json)** — JSON Schema for one entry in `.codelens/reviews.json`.
- **[`report-template.md`](./report-template.md)** — Markdown template for the review report.

## Conventions

Output is **abstracted** — no third-party tool names, no plugin identifiers, no cost figures. Rule names use a semantic `category/name` form (e.g. `a11y/buttonType`, `security/unsafeHtml`). The agent is responsible for translating raw tool output into these conventions before writing any structured record.
