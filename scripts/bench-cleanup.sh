#!/usr/bin/env bash
# Usage: ./scripts/bench-cleanup.sh [target-repo-path]
#
# Purges stale state before each bench run:
#   1. context-mode FTS5 content DBs (~/.claude/context-mode/content/)
#   2. context-mode session DBs (~/.claude/context-mode/sessions/)
#   3. target repo's .codelens/ directory (prior review artifacts)
#   4. stale transcripts older than 7 days
#
# Context-mode accumulates indexed content across runs; without purge, memory
# and disk usage grows unbounded, eventually freezing the host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:-}"

CTX_MODE_DIR="$HOME/.claude/context-mode"
CONTENT_DIR="$CTX_MODE_DIR/content"
SESSIONS_DIR="$CTX_MODE_DIR/sessions"
TRANSCRIPTS_DIR="$PLUGIN_DIR/docs/superpowers/benchmarks/transcripts"

purged=0

# 1. Purge context-mode content DBs
if [ -d "$CONTENT_DIR" ]; then
  size=$(du -sh "$CONTENT_DIR" 2>/dev/null | awk '{print $1}')
  rm -rf "$CONTENT_DIR"
  mkdir -p "$CONTENT_DIR"
  echo "[cleanup] purged content DBs ($size) from $CONTENT_DIR"
  purged=$((purged + 1))
fi

# 2. Purge context-mode session DBs
if [ -d "$SESSIONS_DIR" ]; then
  count=$(ls -1 "$SESSIONS_DIR" 2>/dev/null | wc -l | tr -d ' ')
  rm -rf "$SESSIONS_DIR"
  mkdir -p "$SESSIONS_DIR"
  echo "[cleanup] purged $count session DBs from $SESSIONS_DIR"
  purged=$((purged + 1))
fi

# 3. Purge target's .codelens/ directory
if [ -n "$TARGET" ] && [ -d "$TARGET/.codelens" ]; then
  rm -rf "$TARGET/.codelens"
  echo "[cleanup] purged $TARGET/.codelens"
  purged=$((purged + 1))
fi

# 4. Purge stale transcripts older than 7 days
if [ -d "$TRANSCRIPTS_DIR" ]; then
  find "$TRANSCRIPTS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
fi

if [ "$purged" -eq 0 ]; then
  echo "[cleanup] nothing to purge"
else
  echo "[cleanup] done ($purged locations)"
fi
