#!/usr/bin/env node
/**
 * validate-entry.js — hand-written structural check for .codelens/reviews.log entries.
 *
 * Validates the flat short-key shape (9 fields, no nesting):
 *   { ts, scope, crit, high, med, low, info, report, v }
 *
 * Prints OK or FAIL: <reason>. Exits 0 / 1.
 *
 * Usage:
 *   node scripts/validate-entry.js <path-to-entry.json>
 *   cat entry.json | node scripts/validate-entry.js
 */

const REQUIRED_FIELDS = ['ts', 'scope', 'crit', 'high', 'med', 'low', 'info', 'report', 'v', 'tokIn', 'tokOut'];
const INT_FIELDS = ['crit', 'high', 'med', 'low', 'info', 'tokIn', 'tokOut'];
const SEMVER_RE = /^\d+\.\d+\.\d+$/;

function validateEntry(entry) {
  if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
    return 'FAIL: entry must be a JSON object';
  }

  for (const f of REQUIRED_FIELDS) {
    if (!(f in entry)) return `FAIL: missing required field ${f}`;
  }

  const extras = Object.keys(entry).filter(k => !REQUIRED_FIELDS.includes(k));
  if (extras.length) return `FAIL: unexpected field ${extras[0]}`;

  if (typeof entry.ts !== 'string' || !entry.ts) {
    return 'FAIL: ts must be a non-empty string';
  }

  if (typeof entry.scope !== 'string' || !entry.scope) {
    return 'FAIL: scope must be a non-empty string';
  }

  for (const k of INT_FIELDS) {
    if (!Number.isInteger(entry[k]) || entry[k] < 0) {
      return `FAIL: ${k} must be a non-negative integer`;
    }
  }

  if (typeof entry.report !== 'string' || !entry.report) {
    return 'FAIL: report must be a non-empty string';
  }

  if (typeof entry.v !== 'string' || !SEMVER_RE.test(entry.v)) {
    return `FAIL: v "${entry.v}" does not match X.Y.Z`;
  }

  return 'OK';
}

function main() {
  let raw;
  if (process.argv[2]) {
    raw = require('fs').readFileSync(process.argv[2], 'utf8');
  } else {
    raw = require('fs').readFileSync(0, 'utf8');
  }

  let entry;
  try {
    entry = JSON.parse(raw);
  } catch (e) {
    console.log('FAIL: invalid JSON');
    process.exit(1);
  }

  const result = validateEntry(entry);
  console.log(result);
  process.exit(result === 'OK' ? 0 : 1);
}

if (require.main === module) {
  main();
}

module.exports = { validateEntry };
