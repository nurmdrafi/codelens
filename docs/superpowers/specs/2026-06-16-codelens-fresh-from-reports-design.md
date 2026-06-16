# Codelens Multi-Stack Architecture (Fresh Design from Reports)

**Date:** 2026-06-16
**Status:** Fresh Architecture Design
**Source:** Derived solely from `reports/codelens-reviewer-tool-validation.md` and `reports/codelens-reviewer-refactor-spec-v3-addendum.md`

---

## Context

This design implements a multi-domain, multi-stack code review system based on validated tool evidence and the v3 refactor specification. The system supports PHP/Laravel, Dart/Flutter, and JS/TS stacks with automatic detection, tool selection, and fallback chains.

**Problem Statement:**
Code review requires domain-specific tooling for different language stacks. PHP projects need PHPStan/Psalm; Dart projects need DCM; JS/TS projects need Biome. A unified system must detect stacks, select appropriate tools, and produce comprehensive reports across security, architecture, quality, and accessibility domains.

**Intended Outcome:**
A code review system that:
1. Automatically detects project stacks (PHP/Laravel, Dart/Flutter, JS/TS)
2. Selects appropriate tools per stack with fallback chains
3. Runs analysis across requested domains
4. Produces severity-ranked, evidence-backed reports

---

## Architecture Overview

### System Phases

The refactor spec defines a **6-phase execution model**:

```
Phase 0:   Dependency preflight (tool availability checks)
Phase 0.5: Stack detection (lockfile/manifest fingerprinting)
Phase 1:   Signal collection (stack-specific tool execution)
Phase 2:   Pattern analysis (rg-based domain pattern matching)
Phase 3:   Hotspot deep-dive (file-level analysis)
Phase 4:   Report compilation (severity-ranked findings)
```

**Key Insight:** Phase 0.5 is **NEW** - introduced specifically for stack detection before running any stack-specific tools.

### Component Structure

```
codelens-reviewer system:
├── Stack Detection Module (Phase 0.5)
│   ├── Fingerprint scanner (fd for lockfiles)
│   ├── Framework detection (jq for composer.json, pubspec.yaml)
│   └── Stack registry (detected stacks → tool mappings)
├── Tool Selection Engine
│   ├── Primary tools (best-in-class per stack)
│   ├── Fallback tools (when primary unavailable)
│   └── Crude fallbacks (rg patterns when tools missing)
├── Signal Collection Pipeline (Phase 1)
│   ├── PHP/Laravel block (PHPStan, Psalm, composer-dependency-analyser)
│   ├── Dart/Flutter block (dart analyze, DCM)
│   ├── JS/TS block (Biome, knip)
│   └── Universal block (osv-scanner, jscpd, tokei, repotoire)
├── Pattern Analysis Engine (Phase 2)
│   ├── Domain-specific rg commands (security, architecture, quality, a11y)
│   ├── Stack-aware pattern filters
│   └── Cross-domain deduplication
├── Hotspot Analyzer (Phase 3)
│   ├── File selection (top 10-15 by complexity)
│   ├── Stack-aware pattern matching
│   └── Domain signal extraction
└── Report Generator (Phase 4)
    ├── Severity ranking (Critical > High > Medium > Low > Informational)
    ├── Stack-specific domain sections
    ├── Cross-stack deduplication
    └── Methodology documentation
```

---

## Tool Stack (Validated per Reports)

### Universal Tools (All Stacks)

| Tool | Purpose | Evidence Quality | Fallback |
|------|---------|------------------|----------|
| **ripgrep (rg)** | Pattern searching, architecture signals | Strong (8x faster than grep) | None (primary) |
| **osv-scanner** | CVE/dependency scanning | Strong (same DB as Dependabot) | WebSearch + version check |
| **jscpd** | Duplication detection (223+ languages) | Adequate (Rust v5 core) | None (primary) |
| **tokei** | Code counting, stack composition | Good (community consensus) | cloc (fallback) |
| **repotoire** | Architecture graphs (9 languages) | Adequate (400 files/sec) | rg --count fallback |

### JS/TS Stack Tools

| Tool | Purpose | Evidence Quality | Fallback |
|------|---------|------------------|----------|
| **Biome** | Lint + formatting (replaces ESLint/Prettier) | Strong (56x faster than ESLint) | ESLint (if needed) |
| **knip** | Dead code detection | Not in reports | rg patterns |

### PHP/Laravel Stack Tools

| Tool | Purpose | Evidence Quality | Fallback |
|------|---------|------------------|----------|
| **PHPStan / Larastan** | Type analysis, bug detection | Strong (13.8k GitHub stars) | opengrep/semgrep |
| **Psalm** | Taint analysis ($_GET/$_POST to sinks) | Good (security research backing) | rg patterns |
| **composer-dependency-analyser** | Unused/shadow/misplaced deps | Good (15k files in 2s) | rg --count "use " |

### Dart/Flutter Stack Tools

| Tool | Purpose | Evidence Quality | Fallback |
|------|---------|------------------|----------|
| **dart analyze / flutter analyze** | Core static analysis | Very Strong (official Dart SDK) | dcm analyze |
| **DCM** | Widget quality, dead code, complexity | Good (used by Flutter DevTools team) | dart analyze only |

### Security Tools (Multi-Language)

| Tool | Purpose | Evidence Quality | Caveats |
|------|---------|------------------|---------|
| **OpenGrep / Semgrep** | SAST (30+ languages) | Mixed (87% TPR, 42-74% FPR) | Phase 3 confirmation mandatory |

---

## Phase-by-Phase Implementation

### Phase 0: Dependency Preflight

**Purpose:** Verify mandatory and optional tools are available.

**Implementation:**

```bash
# Slot 1: ripgrep (MANDATORY - halts on failure)
rg --version

# Slot 2: Universal tools (optional - use fallbacks)
which semgrep opengrep osv-scanner jscpd tokei repotoire

# Slot 3: Stack-specific tools (optional - use fallbacks)
which phpstan psalm composer dcm dart flutter

# Slot 4: JS/TS tools (optional)
npx --yes --quiet biome --version
npx --yes --quiet knip --version

# Slot 5: Laravel detection (if composer.json exists)
composer show larastan/larastan --no-interaction 2>/dev/null | grep -c larastan || echo "0"
```

**Halt Conditions:**
- **Halt:** ripgrep not found
- **Continue:** Missing stack-specific tools (use fallbacks)

---

### Phase 0.5: Stack Detection (NEW)

**Purpose:** Detect project stacks by fingerprinting lockfiles and manifests.

**Implementation:**

```bash
# Step 1: Fingerprint all potential lockfiles
fd --type f \
   -g "package.json" -g "Cargo.toml" -g "go.mod" \
   -g "requirements.txt" -g "pyproject.toml" -g "pom.xml" \
   -g "build.gradle" -g "*.csproj" -g "Gemfile" \
   -g "composer.json" \
   -g "pubspec.yaml" \
   --max-depth 2 . 2>/dev/null
```

**Stack Decision Table:**

```
IF composer.json detected:
    enable: phpstan (or larastan if laravel/framework), psalm, composer-dependency-analyser
    IF laravel/framework in require → enable larastan, use Laravel-specific rules
    ELSE → enable phpstan --level=5

IF pubspec.yaml detected:
    IF flutter in environment OR sdk: flutter →
        enable: flutter analyze, dcm analyze-widgets
    ELSE (plain Dart) →
        enable: dart analyze, dcm (non-widget rules)

IF package.json detected:
    enable: biome, knip
    skip: phpstan, psalm, composer tools, dcm, dart tools

ALWAYS (for any detected stack):
    enable: osv-scanner (composer.lock, pubspec.lock, package-lock.json)
    enable: opengrep/semgrep (covers PHP, Dart, JS/TS)
    enable: jscpd (duplication, 223+ languages)
    skip: biome, knip for PHP/Dart stacks
    skip: repotoire for PHP/Dart (use rg --count fallback)
```

**Laravel Detection Refinement:**

```bash
# Run if composer.json detected
jq -e '.require["laravel/framework"] // .require["laravel/lumen-framework"]' \
   composer.json > /dev/null 2>&1 && echo "laravel=true" || echo "laravel=false"
```

**Output Structure:**

```javascript
const detectedStack = {
  php: false,          // composer.json present
  laravel: false,      // laravel/framework in require
  dart: false,         // pubspec.yaml present
  flutter: false,      // flutter in environment
  js: false,           // package.json present
  rust: false,         // Cargo.toml present
  go: false,           // go.mod present
  python: false        // requirements.txt or pyproject.toml present
};
```

---

### Phase 1: Signal Collection (Stack-Specific Commands)

**Purpose:** Run stack-specific tooling in parallel, collect structured outputs.

**PHP/Laravel Block (run only if composer.json detected):**

```bash
# SECURITY + QUALITY: PHPStan / Larastan
# If Larastan installed:
vendor/bin/phpstan analyse --error-format=json --no-progress \
    app/ bootstrap/ config/ database/ routes/ \
    --memory-limit=512M 2>/dev/null

# If Larastan not installed, plain PHPStan at level 5:
vendor/bin/phpstan analyse --level=5 --error-format=json --no-progress \
    <scopePath> 2>/dev/null

# SECURITY (taint analysis): Psalm
vendor/bin/psalm --taint-analysis --output-format=json --no-progress 2>/dev/null

# DEAD DEPENDENCIES: composer-dependency-analyser
vendor/bin/composer-dependency-analyser 2>/dev/null \
    || composer require --dev shipmonk/composer-dependency-analyser -q \
       && vendor/bin/composer-dependency-analyser 2>/dev/null

# ARCHITECTURE: rg fallback (repotoire doesn't support PHP)
rg --count-matches 'class [A-Z]' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "php_classes:"s}'
rg --count-matches 'function ' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "php_functions:"s}'

# Laravel-specific signals (only if laravel=true)
rg --count-matches 'DB::' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "raw_db_calls:"s}'
rg --count-matches 'env(' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "env_outside_config:"s}'
```

**Dart/Flutter Block (run only if pubspec.yaml detected):**

```bash
# CORE ANALYSIS: dart analyze / flutter analyze
# If Flutter project:
flutter analyze --no-pub --format=machine <scopePath> 2>/dev/null \
    | awk -F'|' '{print "{\"file\":\""$3"\",\"line\":"$4",\"severity\":\""$1"\",\"msg\":\""$5"\"}"}'

# If plain Dart (no Flutter):
dart analyze --format=machine <scopePath> 2>/dev/null \
    | awk -F'|' '{print "{\"file\":\""$3"\",\"line\":"$4",\"severity\":\""$1"\",\"msg\":\""$5"\"}"}'

# QUALITY + METRICS: DCM
dcm analyze lib --reporter=json \
    --exclude="{**/*.g.dart,**/*.freezed.dart,**/*.pb.dart}" 2>/dev/null

# Widget quality (Flutter only):
dcm analyze-widgets lib --reporter=json 2>/dev/null

# Unused code:
dcm check-unused-code lib --reporter=json 2>/dev/null

# Unused files:
dcm check-unused-files lib --reporter=json 2>/dev/null

# Unused dependencies:
dcm check-dependencies --reporter=json 2>/dev/null

# ARCHITECTURE: rg fallback (repotoire doesn't support Dart)
rg --count-matches 'class [A-Z]' <scopePath> --type dart <EXCL> \
    | awk -F: '{s+=$2} END {print "dart_classes:"s}'
rg --count-matches 'Widget build' <scopePath> --type dart <EXCL> \
    | awk -F: '{s+=$2} END {print "flutter_widgets:"s}'

# Flutter-specific quality signals
rg --count-matches 'setState(' <scopePath> --type dart <EXCL> \
    | awk -F: '{s+=$2} END {print "setState_calls:"s}'
```

**CVE/Dependency Scanning (run for all stacks):**

```bash
# PHP/Laravel
osv-scanner scan --format json -L composer.lock 2>/dev/null

# Dart/Flutter
osv-scanner scan --format json -L pubspec.lock 2>/dev/null

# JS/TS
osv-scanner scan --format json -L package-lock.json 2>/dev/null
```

**Execution Strategy:** Run all applicable blocks in parallel per detected stack.

---

### Phase 2: Pattern Analysis (Domain-Specific rg Commands)

**Purpose:** Search for domain-specific patterns across all files.

**Security Patterns (run only if security domain requested):**

```bash
rg --no-heading -n 'localStorage\.(getItem|setItem)' <scopePath> <EXCL>
rg --no-heading -n 'dangerouslySetInnerHTML' <scopePath> <EXCL>
rg --no-heading -n 'eval\(' <scopePath> <EXCL>
rg --no-heading -n 'innerHTML|outerHTML' <scopePath> <EXCL>
rg -i --no-heading -n 'SECRET|PASSWORD|API_KEY|TOKEN' <scopePath> <EXCL> | rg -v 'process\.env|\.env|config'
rg --no-heading -n 'Authorization.*Bearer' <scopePath> <EXCL>
```

**Architecture Patterns (run only if architecture domain requested):**

```bash
rg --count 'import.*from' <scopePath> <EXCL>
rg --no-heading -n 'class.*extends.*Component' <scopePath> <EXCL>
rg --count 'React\.memo|useMemo|useCallback' <scopePath> <EXCL>
rg --count 'await ' <scopePath> <EXCL>
rg --no-heading -n 'export default' <scopePath> <EXCL>
```

**Quality Patterns (run only if quality domain requested):**

```bash
rg --count 'console\.log' <scopePath> <EXCL>
rg --count 'TODO|FIXME|HACK|XXX' <scopePath> <EXCL>
rg --count 'eslint-disable' <scopePath> <EXCL>
rg --no-heading -n 'catch\s*\([^)]*\)\s*\{\s*\}' <scopePath> <EXCL>
```

**A11y Patterns (run only if a11y domain requested):**

```bash
rg --count 'alt=' <scopePath> <EXCL>
rg --count 'aria-label' <scopePath> <EXCL>
rg --count 'aria-describedby' <scopePath> <EXCL>
rg --count 'aria-live' <scopePath> <EXCL>
rg --count 'role=' <scopePath> <EXCL>
rg --no-heading -n '<img' <scopePath> <EXCL> | rg -v 'alt='
rg --no-heading -n '<button' <scopePath> <EXCL> | rg -v 'aria-label|>.*</button>'
```

**Stack-Aware Filtering:** Apply stack-specific file type filters (e.g., `--type php` for PHP patterns, `--type dart` for Dart patterns).

---

### Phase 3: Hotspot Deep-Dive

**Purpose:** Analyze top 10-15 most complex files for deep-dive findings.

**File Selection Criteria:**
- Largest files by line count (from Phase 1 signal collection)
- Most complex files (cyclomatic complexity if available)
- Files with highest pattern match counts (from Phase 2)

**Stack-Aware Pattern Matching:**

```javascript
// JS/TS patterns
if (line.match(/eval\(|innerHTML|dangerouslySetInnerHTML/))
  findings.push({ domain: 'security', signal: 'xss-or-eval', line, text });

// PHP-specific patterns
if (stack.php && line.match(/DB::(table|raw)/))
  findings.push({ domain: 'architecture', signal: 'raw-db-query', line, text });
if (stack.php && line.match(/env\(/))
  findings.push({ domain: 'quality', signal: 'env-outside-config', line, text });

// Laravel-specific patterns
if (stack.laravel && line.match(/DB::(table|raw)/))
  findings.push({ domain: 'quality', signal: 'raw-eloquent-query', line, text });

// Dart-specific patterns
if (stack.dart && line.match(/setState\(/))
  findings.push({ domain: 'quality', signal: 'setstate-overuse', line, text });

// Flutter-specific patterns
if (stack.flutter && line.match(/Widget build/) && line.match(/setState/))
  findings.push({ domain: 'architecture', signal: 'business-logic-in-build', line, text });
```

**Single-Pass Constraint:** Each file analyzed exactly once - track hotspots to avoid re-reading.

---

### Phase 4: Report Compilation

**Purpose:** Generate severity-ranked, evidence-backed report with stack-specific sections.

**Report Structure:**

```markdown
# Codebase Analysis Report: [project-name]

**Date:** [ISO 8601 date]
**Stack:** [detected stack(s)]
**Domains:** [requested domains]
**Scope:** [scope type and target]

---

## Executive Summary

**Security:** [posture with critical/high count, or "Not analyzed"]
**Architecture:** [posture or "Not analyzed"]
**Code Quality:** [posture or "Not analyzed"]
**Accessibility:** [posture or "Not analyzed"]

---

## Critical ([count])

| # | Domain | Issue | Location |
|---|--------|-------|----------|
| 1 | security | SQL injection risk | app/Models/User.php:145 |
| 2 | quality | Unused dependency | composer.json:23 |

### Details

[For each Critical finding: title, OWASP/WCAG class, evidence (file:line + snippet), impact, remediation]

---

## High ([count])
[Same format as Critical]

---

## Medium ([count])
[Same format as Critical]

---

## Low ([count])
[Same format as Critical]

---

## Informational ([count])
[Table only — no details subsection]

---

## Stack-Specific Analysis

### PHP/Laravel Analysis

| Domain | Findings | Severity |
|--------|----------|----------|
| Security | PHPStan errors + Psalm taint findings | [counts] |
| Dependencies | osv-scanner CVEs + unused composer deps | [counts] |
| Quality | PHPStan warnings + TODO/FIXME counts | [counts] |
| Architecture | Class/function counts + Laravel signals | [counts] |

### Dart/Flutter Analysis

| Domain | Findings | Severity |
|--------|----------|----------|
| Analysis | dart analyze errors and warnings | [counts] |
| Widget Quality | DCM widget analysis findings | [counts] |
| Dead Code | DCM unused code/files | [counts] |
| Dependencies | osv-scanner CVEs + unused pubspec deps | [counts] |

---

## What's Done Well

[Per-domain positive findings with file references]

---

## Priority Actions

### Immediate (Week 1) — Critical
[Actionable items for Critical findings]

### Short-Term (Week 2-3) — High
[Actionable items for High findings]

### Medium-Term (Month 1)
[Actionable items for Medium findings]

### Backlog
[Actionable items for Low/Informational findings]

---

## Methodology

| Domain | Files Scanned | Tools Used | Notes |
|--------|---------------|------------|-------|
| Security | [count] | [tools] | [fallback notes if applicable] |
| Architecture | [count] | [tools] | [fallback notes] |
| Quality | [count] | [tools] | [fallback notes] |
| Accessibility | [count] | [tools] | [fallback notes] |

**Stack Detection:** [stacks detected and method]
**Tool Availability:** [primary tools used, fallbacks noted]
**Analysis Duration:** [time per phase]
```

**Cross-Domain Deduplication:** Merge findings at same `file:line` (±2 lines) across domains into single row with multiple domain labels.

---

## Fallback Chains

### PHP Security

```
Primary:   phpstan (JSON) + psalm --taint-analysis (JSON)
Fallback:  opengrep/semgrep (PHP supported)
Crude:     rg --count patterns
```

### PHP Dead Dependencies

```
Primary:   composer-dependency-analyser
Fallback:  rg --count 'use '
```

### PHP Quality

```
Primary:   phpstan
Fallback:  rg --count patterns
```

### PHP CVE

```
Primary:   osv-scanner -L composer.lock
Fallback:  WebSearch + version check
```

### Dart Security

```
Primary:   opengrep/semgrep (Dart supported)
Fallback:  dart analyze (errors only)
Crude:     rg patterns
```

### Dart Dead Code

```
Primary:   dcm check-unused-code + check-unused-files
Fallback:  rg patterns
```

### Dart Quality

```
Primary:   dcm analyze
Fallback:  dart analyze --fatal-warnings
Crude:     rg patterns
```

### Dart CVE

```
Primary:   osv-scanner -L pubspec.lock
Fallback:  WebSearch + version check
```

---

## Not Applicable Domains

Certain domains are not automatically detectable for specific stacks:

**PHP:**
- **A11y:** Server-rendered PHP/Blade templates not covered by static tools. Manual review of HTML output recommended.
- **Architecture:** repotoire doesn't support PHP. rg-based class/function counts provided as structural proxy.

**Dart/Flutter:**
- **A11y:** Flutter accessibility requires Semantics widget usage analysis — not covered by static analysis tools. Use Flutter's Accessibility Inspector for manual verification.
- **Architecture:** repotoire doesn't support Dart. rg-based widget/class counts provided as structural proxy.

**Report Requirement:** These domains appear as "Not applicable" rather than empty findings sections.

---

## Data Structures

### Stack Detection Result

```javascript
{
  php: boolean,
  laravel: boolean,
  dart: boolean,
  flutter: boolean,
  js: boolean,
  rust: boolean,
  go: boolean,
  python: boolean
}
```

### Tool Availability Result

```javascript
{
  ripgrep: 'present' | 'absent',
  phpstan: 'present' | 'absent',
  psalm: 'present' | 'absent',
  larastan: 'present' | 'absent',
  composer: 'present' | 'absent',
  dcm: 'present' | 'absent',
  dart: 'present' | 'absent',
  flutter: 'present' | 'absent',
  biome: 'present' | 'absent',
  knip: 'present' | 'absent',
  // ... other tools
}
```

### Finding Structure

```javascript
{
  id: string,                    // Unique identifier
  severity: 'Critical' | 'High' | 'Medium' | 'Low' | 'Informational',
  domain: string,                // 'security' | 'architecture' | 'quality' | 'a11y'
  stack: string,                 // 'php' | 'dart' | 'js' | 'universal'
  file: string,                  // File path
  line: number,                  // Line number
  snippet: string,               // Code snippet
  signal: string,                // Pattern name
  message: string,               // Human-readable description
  remediation: string,           // Fix recommendation
  tool: string,                  // Tool that found this
  owasp?: string,                // OWASP category (if security)
  wcag?: string                  // WCAG criterion (if a11y)
}
```

### Review Log Entry

```javascript
{
  timestamp: string,             // ISO 8601 UTC
  command: string,               // Exact invocation
  scope: string,                 // 'full' | 'path:<target>' | 'diff:<target>'
  summary: string,               // One-sentence executive summary
  status: 'success' | 'partial' | 'failed',
  reportPath: string             // Output file path
}
```

---

## Error Handling

### Tool Unavailability

**Detection:** Phase 0 probe fails
**Action:** Use fallback chain (primary → fallback → crude)
**Report Note:** "X analysis performed using fallback tools (Y) due to Z unavailability"
**Status:** `partial` (not `failed`)

### Stack Detection Failure

**Detection:** Phase 0.5 finds no lockfiles
**Action:** Default to generic analysis (all domains, no stack-specific tools)
**Report Note:** "Stack detection failed - defaulting to generic analysis"
**Status:** `success` (with caveat)

### CVE Database Unavailability

**Detection:** osv-scanner or OSV.dev unreachable
**Action:** Skip CVE verification, proceed with other analysis
**Report Note:** "CVE verification unavailable - manual review recommended"
**Finding Mark:** "Unverified" in findings table
**Status:** `partial`

### Lockfile Not Found

**Detection:** Stack detected but lockfile missing (e.g., composer.json without composer.lock)
**Action:** Skip CVE scanning for that stack
**Report Note:** "No composer.lock found - skipping CVE scanning"
**Status:** `partial`

---

## Performance Estimates

### Phase Execution Times

| Phase | Operation | JS/TS Only | + PHP | + Dart | Multi-Stack |
|-------|-----------|------------|------|-------|-------------|
| 0 | Preflight | ~100ms | ~150ms | ~150ms | ~200ms |
| 0.5 | Stack detection | ~50ms | ~50ms | ~50ms | ~50ms |
| 1 | Signal collection | ~2s | +2.5s | +1.5s | ~4-5s |
| 2 | Pattern analysis | ~1s | ~1s | ~1s | ~1.5s |
| 3 | Hotspot deep-dive | ~1.5s | ~2s | ~2s | ~3s |
| 4 | Report compilation | ~200ms | ~300ms | ~300ms | ~400ms |
| **Total** | | **~5s** | **~8s** | **~7s** | **~10s** |

**Assumptions:**
- Medium-sized repo (500-1000 files)
- Commands run in parallel where possible
- Stack-specific tools available (no fallback delays)
- Hotspot analysis on 15 files

**Context Window Impact:**
- Phase 1 tool outputs: ~1-3k tokens (structured only)
- Phase 2 rg matches: ~500-1k tokens
- Phase 3 hotspot analysis: ~2-4k tokens (single-pass)
- Report generation: ~500-1k tokens

---

## Testing Scenarios

### Scenario 1: Laravel 9+ Project

**Input:**
```bash
cd /path/to/laravel/project
codelens-review --domains security,quality --scope full
```

**Expected Behavior:**
1. Phase 0.5 detects composer.json + laravel/framework
2. Phase 1 runs PHPStan + Psalm + composer-dependency-analyser
3. Phase 2 runs security + quality patterns (PHP-aware)
4. Phase 3 analyzes top 15 PHP files with Laravel patterns
5. Phase 4 generates report with PHP/Laravel domain section

**Verification:**
- Report includes "PHP/Laravel Analysis" section
- Findings include PHPStan errors + Psalm taint findings
- Laravel-specific patterns detected (DB::, env())
- Methodology notes tools used (PHPStan, Psalm, composer-dependency-analyser)

### Scenario 2: Flutter 3+ Project

**Input:**
```bash
cd /path/to/flutter/project
codelens-review --domains quality,architecture --scope full
```

**Expected Behavior:**
1. Phase 0.5 detects pubspec.yaml + flutter in environment
2. Phase 1 runs flutter analyze + DCM (analyze + analyze-widgets + check-unused-code)
3. Phase 2 runs quality + architecture patterns (Dart-aware)
4. Phase 3 analyzes top 15 Dart files with Flutter patterns
5. Phase 4 generates report with Dart/Flutter domain section

**Verification:**
- Report includes "Dart/Flutter Analysis" section
- Findings include flutter analyze errors + DCM widget findings
- Flutter-specific patterns detected (setState, Widget build)
- Methodology notes tools used (flutter analyze, DCM)

### Scenario 3: Multi-Stack Monorepo

**Input:**
```bash
cd /path/to/monorepo
codelens-review --domains all --scope full
```

**Expected Behavior:**
1. Phase 0.5 detects package.json + composer.json + pubspec.yaml
2. Phase 1 runs JS/TS + PHP + Dart blocks in parallel
3. Phase 2 runs all domain patterns (stack-aware filters)
4. Phase 3 analyzes top 15 files per stack
5. Phase 4 generates report with all stack sections

**Verification:**
- Report includes JS/TS, PHP/Laravel, and Dart/Flutter sections
- Findings correctly attributed to stack
- Cross-stack dedup works (same file:line merged)
- Methodology notes all tools used per stack

### Scenario 4: Tool Unavailability

**Input:**
```bash
cd /path/to/php/project/no-tools
codelens-review --domains security --scope full
```

**Expected Behavior:**
1. Phase 0 detects missing phpstan, psalm
2. Phase 1 falls back to opengrep/semgrep + rg patterns
3. Phase 2 runs security patterns (PHP-aware)
4. Phase 3 analyzes top 15 files with PHP patterns
5. Phase 4 generates report with fallback notes

**Verification:**
- Report includes PHP domain section
- Methodology notes "PHP analysis performed using fallback tools (opengrep, rg)"
- Status is `partial` (not `failed`)
- Findings still generated (via fallback)

---

## Migration Path

### Phase 1: PHP/Laravel Support

**Deliverables:**
1. Phase 0.5 stack detection (composer.json + Laravel check)
2. Phase 0 PHP tool probes (phpstan, psalm, composer)
3. Phase 1 PHP signal collection block
4. Phase 2 PHP-aware pattern filters
5. Phase 3 PHP-specific patterns
6. Phase 4 PHP/Laravel domain section

**Testing:**
- Laravel 9+ project
- Plain PHP project (no Laravel)
- PHP project without PHPStan (fallback test)

### Phase 2: Dart/Flutter Support

**Deliverables:**
1. Extend Phase 0.5 (pubspec.yaml + Flutter check)
2. Phase 0 Dart tool probes (dart, flutter, dcm)
3. Phase 1 Dart signal collection block
4. Phase 2 Dart-aware pattern filters
5. Phase 3 Dart-specific patterns
6. Phase 4 Dart/Flutter domain section

**Testing:**
- Flutter 3+ project
- Plain Dart project (no Flutter)
- Dart project without DCM (fallback test)

### Phase 3: Additional Stacks

**Future Stacks:**
- Rust (Cargo.toml)
- Go (go.mod)
- Python (requirements.txt/pyproject.toml)
- Java (pom.xml, build.gradle)

**Pattern:** Follow same approach as PHP/Dart
- Add lockfile to Phase 0.5 fd command
- Add tool probes to Phase 0
- Add signal collection block to Phase 1
- Add patterns to Phase 2/3
- Add domain section to Phase 4

### Phase 4: Polish and Validation

**Deliverables:**
1. Comprehensive cross-stack testing
2. Performance optimization
3. Documentation updates
4. Edge case handling

---

## Success Criteria

### Functional Requirements

- [ ] Stack detection correctly identifies PHP/Laravel projects
- [ ] Stack detection correctly identifies Dart/Flutter projects
- [ ] Stack-specific tooling runs when lockfiles detected
- [ ] Fallback chains activate when primary tools unavailable
- [ ] Report includes stack-specific domain sections
- [ ] Cross-domain dedup works across stack-specific findings
- [ ] Not applicable domains marked correctly (PHP/Dart a11y)
- [ ] CVE scanning works per stack (composer.lock, pubspec.lock, package-lock.json)

### Non-Functional Requirements

- [ ] Phases execute in order (0 → 0.5 → 1 → 2 → 3 → 4)
- [ ] Single-pass file analysis in Phase 3 (no re-reads)
- [ ] Phase 0.5 adds <100ms overhead
- [ ] Total execution time <10s for medium repo
- [ ] Report generation <500ms
- [ ] Backward compatible with existing invocation patterns

### Quality Requirements

- [ ] All tool outputs validated for JSON structure
- [ ] Fallback chains tested with missing tools
- [ ] Cross-stack dedup verified on monorepo
- [ ] Not applicable domains correctly marked
- [ ] Performance benchmarks met

---

## Open Questions

1. **Phase 1.5 aggregation script:** The spec mentions "Phase 1.5 aggregation script" but doesn't specify its implementation. Should this be:
   - A separate script file?
   - Inline aggregation in Phase 1?
   - Part of the agent's working memory processing?

2. **Tool installation guidance:** Should we provide auto-install commands (e.g., `composer require --dev phpstan/phpstan`) or require manual installation?
   - **Recommendation:** Document in setup/doctor command - auto-install risks surprising users

3. **Multi-stack project priority:** How to prioritize findings in monorepos with multiple stacks?
   - **Recommendation:** Severity-first regardless of stack

4. **repotoire limitations:** repotoire doesn't support PHP/Dart. Should we:
   - Use rg --count as crude fallback indefinitely?
   - Invest in PHP/Dart architecture tools?
   - **Recommendation:** rg fallback acceptable for v1, revisit if demand high

---

## References

**Source Documents:**
- Tool Validation Report: `/reports/codelens-reviewer-tool-validation.md`
- Refactor Spec v3 Addendum: `/reports/codelens-reviewer-refactor-spec-v3-addendum.md`

**External Documentation:**
- ripgrep: https://github.com/BurntSushi/ripgrep
- Biome: https://biomejs.dev/
- OpenGrep: https://github.com/opengrep/opengrep
- osv-scanner: https://github.com/google/osv-scanner
- PHPStan: https://phpstan.org/
- Psalm: https://psalm.dev/
- DCM: https://dcm.dev/
