#!/usr/bin/env bash
# Usage: ./scripts/bench-phase.sh <phase-label> <target-repo-path> [benchmark-shape] [scope-path]
#   phase-label:    any string (e.g., "baseline", "0", "4", "0-iter3", "final")
#   target-repo:    absolute path to the repo under review
#   benchmark-shape: "cheap" (default) or "full"
#   scope-path:     for cheap shape, the subpath inside the target to scope to
#                   (e.g., "./components", "./src", "./pages"). Default: "./src"
#                   Ignored when shape=full.
#
# Runs /codelens:review on a fixed target, extracts 4 metrics + guard, appends
# TSV row to docs/superpowers/benchmarks/bench-log.tsv:
#   phase  T_prompt  N_tools  t_wall_ms  B_ctx  findings_total  findings_crit_high
#                   shape  exit_code  scope  rss_peak_kb
#
# Env vars:
#   BENCH_TIMEOUT_SEC     (default 600)    hard cap on review runtime (wall clock)
#   BENCH_MAX_BUDGET_USD  (default 2.00)   hard cap on claude -p API spend
#   BENCH_SKIP_CLEANUP    (default 0)      set to 1 to skip pre-run state purge
#
# Returns summary line on stdout. Transcript + report paths preserved for inspection.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <phase-label> <target-repo-path> [cheap|full] [scope-path]" >&2
  exit 64
fi

PHASE="$1"
TARGET="$2"
SHAPE="${3:-cheap}"
SCOPE_PATH="${4:-./src}"

BENCH_TIMEOUT_SEC="${BENCH_TIMEOUT_SEC:-600}"
BENCH_MAX_BUDGET_USD="${BENCH_MAX_BUDGET_USD:-2.00}"
BENCH_SKIP_CLEANUP="${BENCH_SKIP_CLEANUP:-0}"

# Portable timeout: prefer GNU timeout/gtimeout, fall back to perl shim
TIMEOUT_BIN=""
for candidate in timeout gtimeout; do
  if command -v "$candidate" >/dev/null 2>&1; then
    TIMEOUT_BIN="$candidate"
    break
  fi
done
if [ -z "$TIMEOUT_BIN" ]; then
  # macOS lacks timeout by default — use perl alarm() shim
  TIMEOUT_BIN="__perl_timeout_shim"
fi
run_with_timeout() {
  local secs="$1"; shift
  if [ "$TIMEOUT_BIN" = "__perl_timeout_shim" ]; then
    perl -e '
      my $secs = shift;
      $SIG{ALRM} = sub { kill("TERM", $$) };
      alarm($secs);
      exec(@ARGV);
    ' -- "$secs" "$@"
  else
    "$TIMEOUT_BIN" "$secs" "$@"
  fi
}

# Resolve paths relative to the codelens repo (the script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT="$PLUGIN_DIR/agents/codelens-reviewer.md"
OUTDIR="$PLUGIN_DIR/docs/superpowers/benchmarks"

mkdir -p "$OUTDIR"

# Sanity: target must exist
if [ ! -d "$TARGET" ]; then
  echo "[FAIL] target repo not found: $TARGET" >&2
  exit 2
fi

# Pre-run cleanup: purge stale context-mode state + target's .codelens/
if [ "$BENCH_SKIP_CLEANUP" != "1" ]; then
  "$SCRIPT_DIR/bench-cleanup.sh" "$TARGET" >&2 || true
fi

# Metric 1: prompt tokens (chars / 4 approximation)
T_PROMPT=$(( $(wc -c < "$AGENT") / 4 ))

# Metrics 2-4: run review headlessly, capture transcript
TRANSCRIPT_DIR="$OUTDIR/transcripts"
mkdir -p "$TRANSCRIPT_DIR"
RUN_TS=$(date +%s)
TRANSCRIPT="$TRANSCRIPT_DIR/phase-$PHASE-$RUN_TS.log"
REPORT="$OUTDIR/reports/phase-$PHASE-$RUN_TS.md"
mkdir -p "$OUTDIR/reports"

if [ "$SHAPE" = "cheap" ]; then
  PROMPT="Use the codelens:review skill to run a code-quality and accessibility review scoped to $SCOPE_PATH. Output the report to $REPORT. Do not ask any clarifying questions — proceed with these arguments directly."
elif [ "$SHAPE" = "full" ]; then
  PROMPT="Use the codelens:review skill to run a full multi-domain review (security + architecture + code quality + accessibility) scoped to the whole repo. Output the report to $REPORT. Do not ask any clarifying questions — proceed with these arguments directly."
else
  echo "[FAIL] shape must be 'cheap' or 'full', got: $SHAPE" >&2
  exit 64
fi

echo "[bench] running: (cd $TARGET && claude -p --plugin-dir $PLUGIN_DIR --settings $PLUGIN_DIR/scripts/bench-mcp-settings.json --permission-mode bypassPermissions --output-format stream-json --max-budget-usd $BENCH_MAX_BUDGET_USD --verbose) with timeout=${BENCH_TIMEOUT_SEC}s, prompt: $PROMPT"

# Memory sampler: poll peak RSS of any claude/node process every 2s
RSS_PEAK_KB=0
MEMLOG="$TRANSCRIPT.memlog"
cleanup_memlog() {
  if [ -f "$MEMLOG" ]; then
    RSS_PEAK_KB=$(sort -n "$MEMLOG" 2>/dev/null | tail -1 || echo 0)
    rm -f "$MEMLOG"
  fi
}

sample_mem() {
  while true; do
    # Sum RSS of all claude + node processes (KB)
    ps -eo rss,comm 2>/dev/null \
      | awk '/claude|node/ {sum += $1} END {print sum+0}' \
      >> "$MEMLOG" 2>/dev/null || true
    sleep 2
  done
}

START=$(date +%s%N)
sample_mem &
MEM_PID=$!
# Ensure mem sampler is killed on any exit (normal, error, signal)
trap "kill $MEM_PID 2>/dev/null || true; cleanup_memlog" EXIT

# === Fail-fast watcher ===
# Tail the transcript in background; abort the run if we detect:
#   (a) tool_result with is_error:true — single hard failure
#   (b) terminal {"type":"result","subtype":"error"} event — run-level error
#   (c) single tool call exceeding BENCH_TOOL_TIMEOUT_SEC (default 180s) — pathological slowness
#   (d) any line containing 'STATUS: partial' — gate failure (agent should already halt, but enforce)
# On match: kill the claude -p process tree, write FAIL_REASON to a marker file,
# and let the outer EXIT_CODE capture the kill.
BENCH_TOOL_TIMEOUT_SEC="${BENCH_TOOL_TIMEOUT_SEC:-180}"
FAIL_MARKER="$TRANSCRIPT.failreason"
rm -f "$FAIL_MARKER"

watch_fail_fast() {
  local trans="$1"
  local pid="$2"
  local tool_timeout="$3"
  local last_progress_ms=0
  local last_progress_line=0
  # Wait for the transcript file to exist before tailing
  for _ in $(seq 1 50); do [ -f "$trans" ] && break; sleep 0.1; done
  tail -Fn +1 "$trans" 2>/dev/null | while IFS= read -r line; do
    # (a) is_error:true on a tool_result
    if printf '%s' "$line" | grep -qF '"is_error":true'; then
      echo "tool-result-is-error" > "$FAIL_MARKER"
      kill -TERM "$pid" 2>/dev/null || true
      return
    fi
    # (b) terminal result event with subtype:error
    if printf '%s' "$line" | grep -qE '"type":"result"[^}]*"subtype":"error"'; then
      echo "result-subtype-error" > "$FAIL_MARKER"
      kill -TERM "$pid" 2>/dev/null || true
      return
    fi
    # (d) STATUS: partial — gate failure
    if printf '%s' "$line" | grep -qF 'STATUS: partial'; then
      echo "gate-partial" > "$FAIL_MARKER"
      kill -TERM "$pid" 2>/dev/null || true
      return
    fi
    # (c) pathological single-tool duration
    if printf '%s' "$line" | grep -qF '"subtype":"task_progress"'; then
      local dur
      dur=$(printf '%s' "$line" | grep -oE '"duration_ms":[0-9]+' | grep -oE '[0-9]+' | head -1 || echo 0)
      if [ "$dur" -gt "$((tool_timeout * 1000))" ]; then
        echo "tool-duration-${dur}ms>-${tool_timeout}s" > "$FAIL_MARKER"
        kill -TERM "$pid" 2>/dev/null || true
        return
      fi
    fi
  done
}

set +e
( cd "$TARGET" && export CLAUDE_PROJECT_DIR="$PLUGIN_DIR" && echo "$PROMPT" | run_with_timeout "${BENCH_TIMEOUT_SEC}" claude -p \
    --plugin-dir "$PLUGIN_DIR" \
    --settings "$PLUGIN_DIR/scripts/bench-mcp-settings.json" \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --max-budget-usd "$BENCH_MAX_BUDGET_USD" \
    --verbose ) > "$TRANSCRIPT" 2>&1 &
CLAUDE_PID=$!
watch_fail_fast "$TRANSCRIPT" "$CLAUDE_PID" "$BENCH_TOOL_TIMEOUT_SEC" &
WATCHER_PID=$!
trap "kill $MEM_PID 2>/dev/null || true; kill $WATCHER_PID 2>/dev/null || true; cleanup_memlog" EXIT

wait "$CLAUDE_PID" 2>/dev/null
EXIT_CODE=$?
set -e

# Stop the watcher now that claude is done
kill "$WATCHER_PID" 2>/dev/null || true

# If fail-fast fired, override exit code and surface the reason
if [ -f "$FAIL_MARKER" ]; then
  FAIL_REASON=$(cat "$FAIL_MARKER")
  echo "[bench] FAIL-FAST triggered: $FAIL_REASON" >&2
  EXIT_CODE=130  # 130 = terminated by fail-fast (distinguish from 124 timeout, 0 success)
fi

END=$(date +%s%N)
T_WALL=$(( (END - START) / 1000000 ))

# Stop memory sampler before we read its peak
kill "$MEM_PID" 2>/dev/null || true
wait "$MEM_PID" 2>/dev/null || true
cleanup_memlog

# Metric 2: count tool invocations in stream-json transcript
# Only count actual tool_use events in assistant messages: "type":"tool_use"
# (avoid matching the word "tool_use" in text content or tool_result messages)
N_TOOLS=$(grep -oE '"type":"tool_use"' "$TRANSCRIPT" 2>/dev/null | wc -l | tr -d ' ')

# Metric 4: runtime context bytes (full stream-json transcript size)
B_CTX=$(wc -c < "$TRANSCRIPT")

# Guard: findings count + Critical/High split from the produced report
# Report format: "## Critical (N)", "## High (N)", "## Medium (N)", "## Low (N)", "## Informational (N)"
# Parse the (N) from each severity header and sum. Portable awk (no gawk extensions).
FINDINGS_TOTAL=0
FINDINGS_CH=0
if [ -f "$REPORT" ]; then
  read -r CRIT HIGH MED LOW INFO <<< "$(awk '
    /^## Critical \(/         { gsub(/[^0-9]/, "", $3); crit = $3 }
    /^## High \(/             { gsub(/[^0-9]/, "", $3); high = $3 }
    /^## Medium \(/           { gsub(/[^0-9]/, "", $3); med = $3 }
    /^## Low \(/              { gsub(/[^0-9]/, "", $3); low = $3 }
    /^## Informational \(/    { gsub(/[^0-9]/, "", $3); info = $3 }
    END { print crit+0, high+0, med+0, low+0, info+0 }
  ' "$REPORT")"
  FINDINGS_CH=$(( CRIT + HIGH ))
  FINDINGS_TOTAL=$(( CRIT + HIGH + MED + LOW + INFO ))
fi

# Append TSV row (file is created on first run with header)
LOG="$OUTDIR/bench-log.tsv"
# Detect header schema; if missing rss_peak_kb column, recreate header with new schema
if [ ! -f "$LOG" ] || ! head -1 "$LOG" | grep -q "rss_peak_kb"; then
  if [ -f "$LOG" ]; then
    # Migrate: rename old log, start fresh
    mv "$LOG" "$LOG.archived-$(date +%s)"
    echo "[bench] archived old TSV (pre-rss_peak_kb schema) → $LOG.archived-*" >&2
  fi
  echo -e "phase\tT_prompt\tN_tools\tt_wall_ms\tB_ctx\tfindings_total\tfindings_CH\tshape\texit_code\tscope\trss_peak_kb" > "$LOG"
fi
echo -e "$PHASE\t$T_PROMPT\t$N_TOOLS\t$T_WALL\t$B_CTX\t$FINDINGS_TOTAL\t$FINDINGS_CH\t$SHAPE\t$EXIT_CODE\t$SCOPE_PATH\t$RSS_PEAK_KB" >> "$LOG"

# Summary
echo "[bench] phase=$PHASE shape=$SHAPE scope=$SCOPE_PATH exit=$EXIT_CODE"
echo "        T_prompt=$T_PROMPT  N_tools=$N_TOOLS  t_wall=${T_WALL}ms  B_ctx=$B_CTX"
echo "        findings_total=$FINDINGS_TOTAL  findings_CH=$FINDINGS_CH"
echo "        rss_peak=${RSS_PEAK_KB}KB  timeout=${BENCH_TIMEOUT_SEC}s  max_budget=\$${BENCH_MAX_BUDGET_USD}"
echo "        report:    $REPORT"
echo "        transcript: $TRANSCRIPT"
