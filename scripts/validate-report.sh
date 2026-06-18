#!/usr/bin/env bash
# validate-report.sh — markdown structural lint for codelens reports.
#
# Checks the report file for required sections, title format, and template-fill
# completeness. Prints OK or FAIL: <reason> and exits 0/1.
#
# Usage: bash scripts/validate-report.sh <report.md>

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "FAIL: missing report path argument" >&2
  exit 64
fi

REPORT="$1"

if [ ! -f "$REPORT" ]; then
  echo "FAIL: report file not found: $REPORT"
  exit 1
fi

fail() {
  echo "FAIL: $1"
  exit 1
}

# 1. Title line
head -1 "$REPORT" | grep -qE '^# Codebase Analysis Report: ' || fail "title line must match '# Codebase Analysis Report: ...'"

# 2. Required sections (header-level match)
for section in 'Scorecard' 'What.s Done Well' 'Priority Actions' 'Methodology'; do
  grep -qE "^## ${section}" "$REPORT" || fail "missing section: ${section}"
done

# 3. At least one severity section header
if ! grep -qE '^## (Critical|High|Medium|Low|Informational) \([0-9]+\)' "$REPORT"; then
  fail "no severity section headers found (expected at least one of: Critical/High/Medium/Low/Informational with count)"
fi

# 4. No unfilled placeholders or TBD markers
if grep -qE '\{\{[A-Z_]+\}\}' "$REPORT"; then
  fail "unfilled {{PLACEHOLDER}} found in report"
fi
if grep -qiE '^[[:space:]]*-[[:space:]]*(TBD|TODO)\b' "$REPORT"; then
  fail "TBD/TODO marker found — report is incomplete"
fi

echo "OK"
exit 0
