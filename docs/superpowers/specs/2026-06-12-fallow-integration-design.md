# Fallow Integration Design

## Context

Codelens uses ripgrep-based pattern scanning for all domains. For TypeScript/JavaScript codebases, [fallow](https://github.com/fallow-rs/fallow) provides deterministic codebase intelligence — dead code detection, duplication analysis — that is faster and more accurate than rg patterns alone. Fallow runs in ~0.5s for large codebases and produces structured human-readable output.

The challenge: fallow's full JSON output is 45KB+ for large codebases, which is not token-efficient. By using targeted sub-commands with human-format output, each run produces 5-7KB that can be parsed by `ctx_execute_file` in a sandbox, with only summaries (~1-2KB each) entering context.

## Decision

Integrate fallow as an **optional** Phase A enhancement for TS/JS codebases only. Run two targeted sub-commands (`dead-code` and `dupes`), output to markdown files, parse via `ctx_execute_file`, fold summaries into `extraction.json`.

## What Runs

| Command | Output size | Domain mapping |
|---|---|---|
| `fallow dead-code --format human --quiet -o .claude-review/fallow-dead-code.md 2>/dev/null \|\| true` | ~7KB | code-quality (unused code, dead exports, circular deps), security (unlisted deps) |
| `fallow dupes --format human --quiet -o .claude-review/fallow-dupes.md 2>/dev/null \|\| true` | ~5KB | code-quality (duplication, clone families) |

**Why human format:** 7KB + 5KB vs 45KB+ for JSON. Human format truncates long lists ("...and X more"), includes file:line references, and is parseable by a JS script in `ctx_execute_file`.

**Why not health:** User decision — dead-code and dupes are the high-value analyses for code review.

## Files to Modify

### 1. `agents/codelens-scanner.md`

**Add after Step 2 (Combined Pattern Scan), before Step 3 (Hotspot Deep-Dive):**

New "Step 2.5: Fallback Extraction (TS/JS only)" that:

1. Checks for `package.json` in the project root
2. If found, runs the two fallow commands via `ctx_batch_execute`
3. For each output file, runs `ctx_execute_file` with a JS parser that extracts:
   - **dead-code:** category counts (unused files, exports, types, deps), top findings per category (file, line, symbol), circular dependencies, unlisted dependencies
   - **dupes:** total duplicated lines/percentage, top clone groups (files, line ranges, fingerprints), clone family summaries
4. Writes parsed summaries into `extraction.json` under a new `fallow` field

**JS parser for dead-code (`ctx_execute_file`):**
- Parse section headers (lines starting with `●`)
- Extract counts from headers like `● Unused exports (191)`
- Extract file references with line numbers (`:355 setFilterList`)
- Extract circular dependency chains
- Extract unlisted dependency names
- Output: structured JSON summary ~1-2KB

**JS parser for dupes (`ctx_execute_file`):**
- Parse clone group headers (lines with `lines`, `instances`, `dup:ID`)
- Extract file:line ranges per clone
- Parse clone family summaries with extraction suggestions
- Output: structured JSON summary ~1-2KB

**Update Step 4 extraction.json schema** to include:

```json
{
  "fallow": {
    "detected": true,
    "deadCode": {
      "summary": "58 unused files, 191 unused exports, 44 unused types, 1 circular dep",
      "unusedFiles": { "count": 58, "top": ["path/to/file.ts", ...] },
      "unusedExports": {
        "count": 191,
        "top": [
          { "file": "redux/features/category/categorySlice.ts", "line": 355, "symbol": "setFilterList" },
          ...
        ]
      },
      "unusedTypes": { "count": 44, "top": [...] },
      "unusedDeps": { "count": 3, "items": ["pkg1", "pkg2", "pkg3"] },
      "unlistedDeps": { "count": 1, "items": ["jose"] },
      "circularDeps": [
        { "chain": "index.ts → selectors.ts → store.ts → index.ts" }
      ]
    },
    "duplication": {
      "summary": "4604 lines (7.7%) duplicated across 91 files",
      "totalLines": 4604,
      "percentage": 7.7,
      "filesAffected": 91,
      "topClones": [
        {
          "lines": 234,
          "instances": 2,
          "fingerprint": "dup:bcdb5d2c",
          "files": ["app/.../page.tsx:1-234", "components/.../SupportTicketsPageClient.tsx:1-234"]
        },
        ...
      ],
      "cloneFamilies": [
        {
          "groups": 2,
          "lines": 384,
          "files": ["app/.../page.tsx", "components/.../SupportTicketsPageClient.tsx"],
          "suggestion": "Extract 2 shared clone groups (384 lines) into a shared directory"
        }
      ]
    }
  }
}
```

**Update Dependencies section** to list fallow as optional:
```
- **`fallow`** (optional) — TS/JS codebase intelligence. Auto-detected via package.json. Provides dead-code and duplication analysis. Skipped silently for non-TS/JS projects.
```

### 2. `agents/code-quality-reviewer.md`

**Update `## Input` section** — add `fallow.deadCode` and `fallow.duplication` to the focus list.

**Add to `## Code Quality Criteria`:**
- Dead code and unused exports — exported symbols with no consumers, files unreachable from entry points, unused dependencies
- Code duplication — clone families, duplicated logic across files

**Add step to `## Analysis Process`:**
- Step 6: Process fallow dead-code and duplication data from extraction.json
  - Cross-reference fallow dead-code findings with own pattern matches (e.g., unused exports in files that also have TODOs)
  - Use fallow clone data to identify the most impactful duplication (largest clone families, cross-module duplication)
  - Merge fallow findings into findings, tagged with `source: "fallow"` for traceability

### 3. `agents/architecture-reviewer.md`

**Update `## Input` section** — add `fallow.deadCode.circularDeps` to the focus list.

**Extend `## Analysis Process` Step 1 (Import analysis):**
- Check `fallow.deadCode.circularDeps` for import cycles
- Include circular dependency chains as architecture findings

**Add to `## Architecture Criteria`:**
- Circular dependencies — import cycles that prevent tree-shaking and risk initialization failures

### 4. `agents/security-reviewer.md`

**Update `## Input` section** — add `fallow.deadCode.unlistedDeps` to the focus list.

**Extend analysis process:**
- Check `fallow.deadCode.unlistedDeps` for packages imported in code but missing from package.json (potential supply chain risk)

### 5. `skills/review/SKILL.md`

**Update setup-check** — add soft check for fallow:
- If `package.json` exists → check `npx fallow --version 2>/dev/null`
- Show "fallow: available (TS/JS enhancement)" or "fallow: not installed (optional)"
- Do NOT fail the setup-check if fallow is missing

### 6. `CLAUDE.md`

**Update Hard Dependencies table** — add row:

| Dependency | Used By | Purpose |
|---|---|---|
| **`fallow`** (optional) | codelens-scanner | TS/JS dead-code and duplication analysis. Auto-detected, skipped for non-TS/JS projects. |

**Update File Map** — note that fallow output files go to `.claude-review/fallow-dead-code.md` and `.claude-review/fallow-dupes.md`.

**Update Common Workflows** — add note about fallow under "Test locally".

## Edge Cases

| Case | Behavior |
|---|---|
| No `package.json` | Skip fallow entirely, no message |
| `npx` not available | Graceful skip, log info in scanner output |
| `fallow` command fails (exit 1 = issues found, exit 2 = error) | Exit 1: parse output normally. Exit 2: log warning, skip fallow data |
| `fallow` not installed | `npx -y fallow` auto-installs via npx |
| Non-TS/JS project | Same as no package.json — skip |
| Very large TS/JS codebase | Human format truncates automatically ("...and X more"). Parser extracts top findings only |

## Token Budget

| Item | Size |
|---|---|
| `fallow-dead-code.md` raw file | ~7KB |
| `fallow-dupes.md` raw file | ~5KB |
| Parsed dead-code summary (in extraction.json) | ~1-2KB |
| Parsed duplication summary (in extraction.json) | ~1-2KB |
| **Total added to context** | **~2-4KB** |

Raw files stay in the `ctx_execute_file` sandbox and never enter context.

## Verification

1. Run `/review full` on a TS/JS project with fallow installed — scanner should produce fallow data in extraction.json
2. Run `/review full` on a non-TS/JS project (e.g., Python) — scanner should skip fallow silently
3. Run `/review full` on a TS/JS project without fallow — scanner should attempt npx, gracefully skip on failure
4. Verify code-quality findings include fallow-sourced findings with `source: "fallow"` tag
5. Verify architecture findings include circular dependencies from fallow
6. Verify security findings include unlisted dependencies from fallow
7. Check token budget: extraction.json should grow by ~2-4KB, not 45KB+
