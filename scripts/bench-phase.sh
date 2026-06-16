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

echo "[bench] running: (cd $TARGET && claude -p --plugin-dir $PLUGIN_DIR --settings $PLUGIN_DIR/scripts/bench-settings.json --permission-mode bypassPermissions --output-format stream-json --verbose) with prompt: $PROMPT"
START=$(date +%s%N)
set +e
( cd "$TARGET" && echo "$PROMPT" | claude -p \
    --plugin-dir "$PLUGIN_DIR" \
    --settings "$PLUGIN_DIR/scripts/bench-settings.json" \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --verbose ) > "$TRANSCRIPT" 2>&1
EXIT_CODE=$?
set -e
END=$(date +%s%N)
T_WALL=$(( (END - START) / 1000000 ))

# Metric 2: count tool invocations in stream-json transcript
# stream-json emits one JSON object per line; tool_use events have "type":"user" with tool_use,
# or "type":"assistant" containing tool_use blocks. Match broadly.
N_TOOLS=$(grep -cE '"type":"tool_use"|tool_use' "$TRANSCRIPT" 2>/dev/null || echo 0)

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
if [ ! -f "$LOG" ]; then
  echo -e "phase\tT_prompt\tN_tools\tt_wall_ms\tB_ctx\tfindings_total\tfindings_CH\tshape\texit_code\tscope" > "$LOG"
fi
echo -e "$PHASE\t$T_PROMPT\t$N_TOOLS\t$T_WALL\t$B_CTX\t$FINDINGS_TOTAL\t$FINDINGS_CH\t$SHAPE\t$EXIT_CODE\t$SCOPE_PATH" >> "$LOG"

# Summary
echo "[bench] phase=$PHASE shape=$SHAPE scope=$SCOPE_PATH exit=$EXIT_CODE"
echo "        T_prompt=$T_PROMPT  N_tools=$N_TOOLS  t_wall=${T_WALL}ms  B_ctx=$B_CTX"
echo "        findings_total=$FINDINGS_TOTAL  findings_CH=$FINDINGS_CH"
echo "        report:    $REPORT"
echo "        transcript: $TRANSCRIPT"
