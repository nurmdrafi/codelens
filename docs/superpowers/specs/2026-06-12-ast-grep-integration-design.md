# ast-grep Integration Design

## Context

Codelens uses ripgrep for all pattern scanning. While rg is extremely fast (~5-15ms), it cannot understand code structure — it matches raw text. Three patterns have high false-positive rates (`import.*from`, `class.*extends.*Component`, empty catch blocks) and rg can't express structural checks like "eval() in real code only."

ast-grep (`sg`) is a Rust-based structural code search tool using tree-sitter. It supports 20+ languages and produces JSON output. It complements rg (structural vs text) and doesn't conflict with fallow or context-mode MCP.

## Decision

Add ast-grep as an optional Phase A scanner step. Keep rg for simple text patterns. ast-grep handles AST-worthy patterns plus new structural checks. Supports 20+ languages, not just TS/JS.

## Layered Approach

| Layer | Tool | What it covers | Speed |
|---|---|---|---|
| 1 | `rg` (ripgrep) | Simple text: secrets, console.log, TODO, aria attrs, await/then | ~5-15ms |
| 2 | `sg` (ast-grep) | Structural: imports, classes, empty catch, eval, var usage, duplicate conditions | ~25-60ms |
| 3 | `fallow` | TS/JS dead-code, duplication, circular deps | ~500ms |

## Patterns Moved from rg to ast-grep

| rg pattern | Problem | ast-grep replacement |
|---|---|---|
| `import.*from` | Matches strings, comments | `import $$$ from $MOD` |
| `class.*extends.*Component` | Can't span lines | `class $NAME extends $BASE` |
| `catch\s*\([^)]*\)\s*\{\s*\}` | Misses multi-line | `catch($ERR) { }` |
| `eval\(` | False positives from strings | `eval($$$)` |

## New Patterns (rg can't express)

| Pattern | Domain |
|---|---|
| `var $NAME = $VALUE` | Code Quality — should be let/const |
| `$A && $A` | Code Quality — duplicate boolean operand (bug) |

## Token Budget

ast-grep JSON output: ~5-15KB raw. Parsed summaries in extraction.json: ~2-4KB. Raw JSON stays in sandbox.

## Files Modified

1. `agents/codelens-scanner.md` — Step 2.6, updated rg command, extraction.json schema
2. `agents/code-quality-reviewer.md` — astGrep data in Input, criteria, analysis
3. `agents/architecture-reviewer.md` — astGrep imports, classComponents in Input
4. `agents/security-reviewer.md` — astGrep evalCalls in Input
5. `skills/review/SKILL.md` — ast-grep in setup-check
6. `CLAUDE.md` — Optional Dependencies, architecture diagram
7. `CHANGELOG.md` — v1.3.0 entry
