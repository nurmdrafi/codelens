#!/usr/bin/env node
/**
 * validate-custom-checks.js — schema validator for config/custom-checks.json.
 *
 * Validates that each check has:
 *   - id: non-empty, kebab-case, unique within the file
 *   - domain: one of security | architecture | quality | a11y
 *   - severity: one of Critical | High | Medium | Low | Informational
 *   - detect: non-empty string (shell command)
 *   - passSignal (optional): non-empty string (default "OK" handled by agent)
 *   - title, description (optional but recommended): non-empty strings
 *
 * Prints OK or FAIL: <reason>. Exits 0 / 1.
 *
 * Usage:
 *   node scripts/validate-custom-checks.js [path]
 *   (defaults to $CLAUDE_PROJECT_DIR/config/custom-checks.json or ./config/custom-checks.json)
 */

const fs = require('fs');
const path = require('path');

const ALLOWED_DOMAINS = ['security', 'architecture', 'quality', 'a11y'];
const ALLOWED_SEVERITIES = ['Critical', 'High', 'Medium', 'Low', 'Informational'];
const KEBAB_RE = /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;

function validateCustomChecks(config) {
  if (typeof config !== 'object' || config === null || Array.isArray(config)) {
    return 'FAIL: top-level value must be an object with a "checks" array';
  }
  if (!Array.isArray(config.checks)) {
    return 'FAIL: "checks" must be an array';
  }
  if (config.checks.length === 0) {
    return 'OK'; // empty checks array is valid (file is optional, no-op if empty)
  }

  const seenIds = new Set();

  for (let i = 0; i < config.checks.length; i++) {
    const c = config.checks[i];
    const where = `checks[${i}]`;

    if (typeof c !== 'object' || c === null || Array.isArray(c)) {
      return `FAIL: ${where} must be an object`;
    }

    // id
    if (typeof c.id !== 'string' || !c.id) {
      return `FAIL: ${where}.id must be a non-empty string`;
    }
    if (!KEBAB_RE.test(c.id)) {
      return `FAIL: ${where}.id "${c.id}" must be kebab-case (lowercase letters/digits, hyphen-separated)`;
    }
    if (seenIds.has(c.id)) {
      return `FAIL: ${where}.id "${c.id}" duplicates an earlier check id`;
    }
    seenIds.add(c.id);

    // domain
    if (typeof c.domain !== 'string' || !c.domain) {
      return `FAIL: ${where}.domain must be a non-empty string`;
    }
    if (!ALLOWED_DOMAINS.includes(c.domain)) {
      return `FAIL: ${where}.domain "${c.domain}" not in {${ALLOWED_DOMAINS.join(', ')}}`;
    }

    // severity
    if (typeof c.severity !== 'string' || !c.severity) {
      return `FAIL: ${where}.severity must be a non-empty string`;
    }
    if (!ALLOWED_SEVERITIES.includes(c.severity)) {
      return `FAIL: ${where}.severity "${c.severity}" not in {${ALLOWED_SEVERITIES.join(', ')}}`;
    }

    // detect
    if (typeof c.detect !== 'string' || !c.detect) {
      return `FAIL: ${where}.detect must be a non-empty string (shell command)`;
    }

    // passSignal (optional)
    if ('passSignal' in c) {
      if (typeof c.passSignal !== 'string' || !c.passSignal) {
        return `FAIL: ${where}.passSignal (if present) must be a non-empty string`;
      }
    }

    // title (optional but recommended)
    if ('title' in c) {
      if (typeof c.title !== 'string' || !c.title) {
        return `FAIL: ${where}.title (if present) must be a non-empty string`;
      }
    }

    // description (optional but recommended)
    if ('description' in c) {
      if (typeof c.description !== 'string' || !c.description) {
        return `FAIL: ${where}.description (if present) must be a non-empty string`;
      }
    }
  }

  return 'OK';
}

function main() {
  const argPath = process.argv[2];
  const defaultPath = path.join(
    process.env.CLAUDE_PROJECT_DIR || process.cwd(),
    'config',
    'custom-checks.json'
  );
  const target = argPath || defaultPath;

  if (!fs.existsSync(target)) {
    console.log('OK no custom-checks.json');
    process.exit(0);
  }

  let raw;
  try {
    raw = fs.readFileSync(target, 'utf8');
  } catch (e) {
    console.log(`FAIL: cannot read ${target}: ${e.message}`);
    process.exit(1);
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    console.log(`FAIL: invalid JSON in ${target}: ${e.message}`);
    process.exit(1);
  }

  const result = validateCustomChecks(parsed);
  console.log(result);
  process.exit(result === 'OK' ? 0 : 1);
}

if (require.main === module) {
  main();
}

module.exports = { validateCustomChecks };
