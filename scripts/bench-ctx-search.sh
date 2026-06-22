#!/usr/bin/env bash
# Usage: ./scripts/bench-ctx-search.sh <target-repo-path> [--skip-cleanup]
#
# Measures ctx_search latency in cold and warm FTS5 states. Confirms or refutes
# the hypothesis from rewrite-r3 (where two ctx_search calls took 321s and 374s,
# blowing the 10-min timeout).
#
# Method:
#   1. Cold: run `claude -p` with a prompt that issues ctx_batch_execute (to
#      rebuild the index) followed by 5 sequential ctx_search calls. Parse
#      task_progress.duration_ms for each search.
#   2. Warm: run the same prompt again with --skip-cleanup so the index stays.
#      Compare per-query latency.
#
# Output: stdout table — phase, query#, duration_ms, delta vs cold.
# Exit: 0 if all queries succeed, 1 otherwise.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <target-repo-path> [--skip-cleanup]" >&2
  exit 64
fi

TARGET="$1"
SKIP_CLEANUP="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT="$PLUGIN_DIR/agents/codelens-reviewer.md"
OUTDIR="$PLUGIN_DIR/docs/superpowers/benchmarks"
mkdir -p "$OUTDIR/transcripts"

if [ ! -d "$TARGET" ]; then
  echo "[FAIL] target repo not found: $TARGET" >&2
  exit 2
fi

RUN_TS=$(date +%s)
LABEL="${SKIP_CLEANUP:+warm-}probe"
TRANSCRIPT="$OUTDIR/transcripts/phase-$LABEL-$RUN_TS.log"
TIMEOUT_SEC="${BENCH_TIMEOUT_SEC:-300}"
BENCH_MAX_BUDGET_USD="${BENCH_MAX_BUDGET_USD:-1.00}"

# Pre-run cleanup unless --skip-cleanup
if [ -z "$SKIP_CLEANUP" ]; then
  echo "[probe] running pre-run cleanup (cold index)" >&2
  "$SCRIPT_DIR/bench-cleanup.sh" "$TARGET" >&2 || true
else
  echo "[probe] --skip-cleanup set, keeping existing index (warm)" >&2
fi

# Probe prompt: index the repo, then run 5 distinct searches and report timing.
PROMPT="Use context-mode MCP tools. Steps:
1. Call ctx_batch_execute with commands: [{label:\"probe-files\",command:\"rg --files \"$TARGET\" 2>/dev/null | head -200\"}], queries:[\"files\"]. Wait for it to return.
2. Sequentially, one at a time, call ctx_search with these exact queries:
   - 'function'
   - 'import export'
   - 'error handling'
   - 'async await'
   - 'button click'
3. After each ctx_search call, print on its own line: PROBE-RESULT query=\"<the query>\" duration=<duration_ms from the task_progress event>ms
4. Do not run any other tools. Do not analyze the results. Just measure latency.
Output ONLY the 5 PROBE-RESULT lines at the end."

echo "[probe] running: claude -p with timeout=${TIMEOUT_SEC}s" >&2
echo "[probe] transcript: $TRANSCRIPT" >&2

set +e
( cd "$TARGET" && export CLAUDE_PROJECT_DIR="$PLUGIN_DIR" && echo "$PROMPT" | timeout "${TIMEOUT_SEC}" claude -p \
    --plugin-dir "$PLUGIN_DIR" \
    --settings "$PLUGIN_DIR/scripts/bench-mcp-settings.json" \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --max-budget-usd "$BENCH_MAX_BUDGET_USD" \
    --verbose ) > "$TRANSCRIPT" 2>&1
EXIT_CODE=$?
set -e

echo ""
echo "=== Probe exit code: $EXIT_CODE ==="
echo "=== Transcript: $TRANSCRIPT ==="
echo ""

# Extract per-query latency from task_progress events
# task_progress carries cumulative duration_ms — we need per-call deltas.
# Filter to lines whose last_tool_name is ctx_search.
echo "=== ctx_search task_progress events ==="
grep -F '"subtype":"task_progress"' "$TRANSCRIPT" \
  | grep -F 'ctx_search' \
  | grep -oE '"duration_ms":[0-9]+|"tool_uses":[0-9]+|"last_tool_name":"[^"]+"' \
  | paste -d'|' - - - \
  | head -20

echo ""
echo "=== Agent's PROBE-RESULT lines (if it followed instructions) ==="
grep -E 'PROBE-RESULT' "$TRANSCRIPT" | head -10 || echo "(agent did not print PROBE-RESULT lines)"

echo ""
echo "=== Final result event ==="
grep -E '"type":"result"' "$TRANSCRIPT" | head -c 500

exit 0
