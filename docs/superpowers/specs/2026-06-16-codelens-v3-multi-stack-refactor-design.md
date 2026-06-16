# Codelens v3 Multi-Stack Refactor Design

**Date:** 2026-06-16
**Status:** Design Draft
**Approach:** Monolithic Agent Enhancement (Approach 1)

---

## Context

Codelens is a Claude Code plugin for multi-domain code review. The current architecture (v0.0.3) uses a single agent (`codelens-reviewer.md`) that analyzes codebases across four domains: security, architecture, code quality, and accessibility. 

This design implements the v3 refactor to support multiple language stacks (JS/TS, PHP/Laravel, Dart/Flutter, Rust, Go, Python) while preserving the existing 4-domain model and single-agent architecture.

**Problem Being Solved:**
The current agent only supports JS/TS-centric analysis patterns. PHP and Dart/Flutter projects need stack-specific tooling (PHPStan, Psalm, DCM, etc.) and appropriate fallback chains for comprehensive code review.

**Intended Outcome:**
A single, enhanced agent that automatically detects the project's tech stack and applies appropriate tooling for each requested domain, with proper fallback chains and stack-aware reporting.

---

## Architecture Overview

### High-Level Structure

```
/codelens:review (NL-driven dispatcher, unchanged)
  → Reads $ARGUMENTS, infers {domains, scope, scopeTarget, outputFile}
  → codelens-reviewer agent (enhanced single agent, ~800 lines):
      Phase 0:   Dependency preflight (rg + context-mode + Context7)
      Phase 0.5: Stack detection (NEW - fd + jq for lockfiles)
      Phase 1:   Inventory + stack-specific signal collection (ENHANCED)
      Phase 2:   Pattern analysis with domain filtering (unchanged)
      Phase 2.5: Doc/CVE verification (on-flag only, unchanged)
      Phase 3:   Hotspot deep-dive with stack-aware patterns (ENHANCED)
      Phase 4:   Report compilation with stack-specific domains (ENHANCED)
```

### Key Design Decisions

1. **Single Agent Architecture:** Preserve current design pattern - one continuous agent execution, no persisted state, no sub-dispatchers
2. **4-Domain Model:** Maintain security/architecture/quality/a11y domains - add stack-specific tooling underneath each
3. **Stack Detection:** Automatic detection via lockfile fingerprints in Phase 0.5
4. **Tool Selection:** Conditional tool activation based on detected stack
5. **Fallback Chains:** Graceful degradation when stack-specific tools unavailable
6. **Phase 0.5 Addition:** New lightweight phase for stack detection between preflight and inventory

---

## Components

### 1. Enhanced Phase 0: Dependency Preflight

**Current State:** 3 mandatory checks (rg, context-mode, Context7)

**Enhancement:** Add PHP and Dart tool probes to existing probe command:

```bash
# Existing probes (unchanged)
which semgrep opengrep osv-scanner biome repotoire jscpd knip

# NEW: PHP and Dart tool probes
which phpstan psalm composer dcm dart flutter

# Existing npx fallbacks (unchanged)
npx --yes --quiet biome --version
npx --yes --quiet knip --version

# NEW: Check for Larastan in Composer
composer show larastan/larastan --no-interaction 2>/dev/null | grep -c larastan || echo "0"
```

**Halt Conditions:** Unchanged - rg, context-mode, Context7 are mandatory. PHP/Dart tools are optional (use fallbacks if missing).

### 2. NEW Phase 0.5: Stack Detection

**Purpose:** Detect project stack by fingerprinting lockfiles and manifests

**Implementation:**

```bash
# Single fd call to find all potential stack fingerprints
fd --type f \
   -g "package.json" -g "Cargo.toml" -g "go.mod" \
   -g "requirements.txt" -g "pyproject.toml" -g "pom.xml" \
   -g "build.gradle" -g "*.csproj" -g "Gemfile" \
   -g "composer.json" \
   -g "pubspec.yaml" \
   --max-depth 2 . 2>/dev/null
```

**Laravel Detection Refinement:**
```bash
# Run jq check if composer.json detected
jq -e '.require["laravel/framework"] // .require["laravel/lumen-framework"]' \
   composer.json > /dev/null 2>&1 && echo "laravel=true" || echo "laravel=false"
```

**Output:** Stack object in working memory:
```javascript
const stack = {
  js: false,       // package.json detected
  php: false,      // composer.json detected
  laravel: false,  // laravel/framework in require
  dart: false,     // pubspec.yaml detected
  flutter: false,  // flutter in environment or sdk: flutter
  rust: false,     // Cargo.toml detected
  go: false,       // go.mod detected
  python: false,   // requirements.txt or pyproject.toml detected
};
```

### 3. Enhanced Phase 1: Inventory + Stack-Specific Signals

**Current State:** `rg --files` + `ctx_batch_execute` for file stats and tech stack

**Enhancement:** Add stack-specific signal collection blocks to ctx_batch_execute:

**PHP/Laravel Block (when composer.json detected):**
```bash
# PHPStan / Larastan
vendor/bin/phpstan analyse --error-format=json --no-progress \
    app/ bootstrap/ config/ database/ routes/ \
    --memory-limit=512M 2>/dev/null

# Psalm taint analysis
vendor/bin/psalm --taint-analysis --output-format=json --no-progress 2>/dev/null

# Dead dependencies
vendor/bin/composer-dependency-analyser 2>/dev/null \
    || composer require --dev shipmonk/composer-dependency-analyser -q

# Architecture fallback (repotoire doesn't support PHP)
rg --count-matches 'class [A-Z]' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "php_classes:"s}'
```

**Dart/Flutter Block (when pubspec.yaml detected):**
```bash
# Core analysis
flutter analyze --no-pub --format=machine <scopePath> 2>/dev/null \
    | awk -F'|' '{print "{\"file\":\""$3"\",\"line\":"$4",\"severity\":\""$1"\",\"msg\":\""$5"\"}"}'

# DCM quality checks
dcm analyze lib --reporter=json \
    --exclude="{**/*.g.dart,**/*.freezed.dart,**/*.pb.dart}" 2>/dev/null

# Widget quality (Flutter only)
dcm analyze-widgets lib --reporter=json 2>/dev/null
```

**Integration:** These blocks are added to the existing ctx_batch_execute call, running in parallel with JS/TS commands when multiple stacks detected.

### 4. Enhanced Phase 3: Hotspot Deep-Dive

**Current State:** ctx_execute_file per hotspot with domain-specific pattern matching

**Enhancement:** Add stack-aware pattern matching:

```javascript
// Existing JS/TS patterns (unchanged)
if (line.match(/eval\(|innerHTML|dangerouslySetInnerHTML/))
  result.findings.push({ domain: 'security', line: ln, text: t, signal: 'xss-or-eval' });

// NEW: PHP-specific patterns
if (stack.php && line.match(/DB::(table|raw)/))
  result.findings.push({ domain: 'architecture', line: ln, text: t, signal: 'raw-db-query' });
if (stack.php && line.match(/env\(/))
  result.findings.push({ domain: 'quality', line: ln, text: t, signal: 'env-outside-config' });

// NEW: Dart-specific patterns
if (stack.dart && line.match(/setState\(/))
  result.findings.push({ domain: 'quality', line: ln, text: t, signal: 'setstate-overuse' });
if (stack.flutter && line.match(/Widget build/) && line.match(/setState/))
  result.findings.push({ domain: 'architecture', line: ln, text: t, signal: 'business-logic-in-build' });
```

**Key:** Stack detection from Phase 0.5 gates pattern matching - PHP patterns only run on PHP files, etc.

### 5. Enhanced Phase 4: Report Compilation

**Current State:** Severity-ranked findings with domain tables

**Enhancement:** Add stack-specific domain sections to report template:

**PHP/Laravel Domain Section:**
```markdown
### PHP/Laravel Analysis

| Domain | Findings | Severity |
|--------|----------|----------|
| Security | PHPStan errors + Psalm taint findings | Critical/High/Medium |
| Dependencies | osv-scanner CVEs + unused composer deps | High/Medium |
| Quality | PHPStan warnings + TODO/FIXME counts | Medium/Low |
| Architecture | Class/function counts + Laravel-specific signals | Low/Informational |
```

**Dart/Flutter Domain Section:**
```markdown
### Dart/Flutter Analysis

| Domain | Findings | Severity |
|--------|----------|----------|
| Analysis | dart analyze errors and warnings | Critical/High |
| Widget Quality | DCM widget analysis findings | High/Medium |
| Dead Code | DCM unused code/files | Medium/Low |
| Dependencies | osv-scanner CVEs + unused pubspec deps | High/Medium |
```

**Cross-Stack Dedup:** Same file:line findings across domains merge into single row, regardless of stack.

### 6. Tool Registry and Fallback Chains

**Tool Registry (NEW):** Maps stacks to tools with availability fallbacks

```javascript
const toolRegistry = {
  php: {
    security: {
      primary: 'phpstan + psalm --taint-analysis',
      fallback: 'opengrep/semgrep',
      crude: 'rg --count patterns'
    },
    deadDeps: {
      primary: 'composer-dependency-analyser',
      fallback: 'rg --count "use "'
    },
    cve: {
      primary: 'osv-scanner -L composer.lock',
      fallback: 'WebSearch + version check'
    }
  },
  dart: {
    analysis: {
      primary: 'dart analyze / flutter analyze',
      fallback: 'dcm analyze',
      crude: 'rg patterns'
    },
    deadCode: {
      primary: 'dcm check-unused-code + check-unused-files',
      fallback: 'rg patterns'
    },
    cve: {
      primary: 'osv-scanner -L pubspec.lock',
      fallback: 'WebSearch + version check'
    }
  }
};
```

**Fallback Logic:**
1. Try primary tool
2. On failure, try fallback tool
3. On failure, use crude rg patterns
4. Report tool used in Methodology section

---

## Data Flow

### Request Flow

```
User: "/codelens:review src/auth for security"
  ↓
skills/review/SKILL.md parses NL
  → domains: ["security"]
  → scope: "path"
  → scopeTarget: "src/auth"
  → outputFile: "CODEBASE_ANALYSIS_REPORT.md"
  ↓
codelens-reviewer agent receives config
  ↓
Phase 0: Dependency preflight (rg + context-mode + Context7)
  ↓
Phase 0.5: Stack detection (fd for lockfiles)
  → stack.php = true (composer.json detected)
  ↓
Phase 1: Inventory + stack-specific signals
  → rg --files src/auth
  → ctx_batch_execute:
      - file stats (existing)
      - tech stack (existing)
      - PHPStan analysis (NEW, gated by stack.php)
      - Psalm taint (NEW, gated by stack.php)
      - composer-dependency-analyser (NEW, gated by stack.php)
  ↓
Phase 2: Pattern analysis (security only, per config.domains)
  → rg security patterns (existing, PHP-aware)
  ↓
Phase 3: Hotspot deep-dive (top 15 files)
  → ctx_execute_file per hotspot
  → PHP-specific security patterns (NEW, gated by stack.php)
  ↓
Phase 4: Report compilation
  → Build severity-ranked findings
  → Add PHP/Laravel domain section
  → Write to CODEBASE_ANALYSIS_REPORT.md
  → Append to .codelens/reviews.json
```

### Stack Detection State

```javascript
// Phase 0.5 output
const stack = {
  js: false,
  php: true,          // composer.json detected
  laravel: true,     // laravel/framework confirmed
  dart: false,
  flutter: false,
  rust: false,
  go: false,
  python: false
};

// Used throughout Phases 1-4 for conditional execution
if (stack.php) {
  // Run PHP-specific tooling
}
if (stack.laravel) {
  // Run Laravel-specific patterns
}
```

---

## File Structure

### Modified Files

```
codelens/
├── agents/
│   └── codelens-reviewer.md              # MAJOR: ~400 → ~800 lines
│       ├── Phase 0: Enhanced preflight (add PHP/Dart probes)
│       ├── Phase 0.5: NEW - Stack detection
│       ├── Phase 1: Enhanced inventory (add PHP/Dart blocks)
│       ├── Phase 2: Unchanged (domain filtering)
│       ├── Phase 2.5: Unchanged (doc/CVE verification)
│       ├── Phase 3: Enhanced hotspots (add stack-aware patterns)
│       └── Phase 4: Enhanced report (add stack sections)
├── .claude/
│   ├── codelens-exclusions.json          # OPTIONAL: Add PHP/Dart patterns
│   └── review-presets.json              # OPTIONAL: Add stack presets
└── docs/
    └── superpowers/specs/
        └── 2026-06-16-codelens-v3-multi-stack-refactor-design.md  # THIS FILE
```

### New Configuration Files

**.claude/codelens-exclusions.json (enhanced):**
```json
{
  "comment": "Exclusion patterns applied by every codelens agent",
  "defaults": ["node_modules", ".next", "dist", "vendor", "build"],
  "byDomain": {
    "security": [],
    "architecture": [],
    "quality": [],
    "a11y": ["*.svg", "*.png", "*.jpg"]
  },
  "keepInScope": {
    "comment": "Patterns explicitly KEPT for analysis",
    "envFiles": [".env", ".env.*"],
    "cicd": [".github", ".gitlab"],
    "projectConfig": [".editorconfig", ".gitignore"],
    "lockfiles": ["composer.lock", "pubspec.lock", "package-lock.json"]
  }
}
```

**.claude/review-presets.json (enhanced):**
```json
{
  "pr-check": {
    "domains": ["security", "quality"],
    "scope": "diff"
  },
  "a11y-audit": {
    "domains": ["a11y"],
    "scope": "full"
  },
  "full-audit": {
    "domains": ["all"],
    "scope": "full"
  },
  "php-security": {
    "domains": ["security"],
    "scope": "full",
    "stack": "php"
  },
  "flutter-quality": {
    "domains": ["quality"],
    "scope": "full",
    "stack": "dart"
  }
}
```

---

## Error Handling

### Tool Unavailability

**Scenario:** PHPStan not installed in a PHP project

**Handling:**
1. Phase 0 probe detects missing phpstan
2. Phase 1 attempts primary tool → fails
3. Fallback to opengrep/semgrep for security patterns
4. Fallback to rg --count for quality signals
5. Report notes in Methodology: "PHP analysis performed using fallback tools (opengrep, rg) due to PHPStan unavailability"

**Log:** Append to status field in reviews.json: `partial` (some tools unavailable) vs `success` (all primary tools)

### Stack Detection Failure

**Scenario:** No lockfiles detected (unusual project structure)

**Handling:**
1. Phase 0.5 detects no stack fingerprints
2. Default to JS/TS patterns (most common)
3. Report notes: "Stack detection failed - defaulting to generic analysis"
4. Phase 2 runs all domain patterns (no filtering)

### CVE Database Unavailability

**Scenario:** osv-scanner cannot reach OSV.dev database

**Handling:**
1. Phase 2.5 triggered for outdated deps
2. Context7/WebSearch fail to verify CVEs
3. Report notes: "CVE verification unavailable - manual review recommended"
4. Findings marked as "Unverified" in report

---

## Testing Strategy

### Test Scenarios

**1. PHP/Laravel Project (Laravel 9+)**
- Stack: Laravel confirmed via composer.json
- Domains: security + quality
- Expected: PHPStan + Psalm findings, Laravel-specific patterns
- Verification: Report includes PHP/Laravel domain section

**2. Flutter Project (pubspec.yaml)**
- Stack: Flutter confirmed via sdk: flutter
- Domains: quality + architecture
- Expected: DCM widget analysis, setState pattern detection
- Verification: Report includes Dart/Flutter domain section

**3. Multi-Stack Project (monorepo)**
- Stack: JS/TS + PHP detected
- Domains: all four
- Expected: Both JS/TS and PHP tooling run, findings merged
- Verification: Report includes both domain sections

**4. Tool Unavailability**
- Stack: PHP project without PHPStan installed
- Domains: security
- Expected: Fallback to opengrep/semgrep + rg patterns
- Verification: Report notes tool unavailability in Methodology

### Validation Commands

```bash
# Test PHP stack detection
cd /path/to/laravel/project
/codelens:review for security

# Test Flutter stack detection
cd /path/to/flutter/project
/codelens:review for quality

# Test multi-stack detection
cd /path/to/monorepo
/codelens:review full audit

# Verify tool fallback
cd /path/to/php/project/no-tools
/codelens:review for security
# Check report Methodology for fallback notes
```

---

## Migration Path

### Incremental Implementation

**Phase 1: PHP/Laravel Support (Sprint 1)**
1. Add Phase 0.5 stack detection (composer.json + Laravel check)
2. Add PHP tool probes to Phase 0
3. Add PHP signal collection to Phase 1
4. Add PHP patterns to Phase 3
5. Add PHP domain section to Phase 4
6. Test on Laravel 9+ projects

**Phase 2: Dart/Flutter Support (Sprint 2)**
1. Extend Phase 0.5 (pubspec.yaml + Flutter check)
2. Add Dart tool probes to Phase 0
3. Add Dart signal collection to Phase 1
4. Add Dart patterns to Phase 3
5. Add Dart domain section to Phase 4
6. Test on Flutter 3+ projects

**Phase 3: Additional Stacks (Sprint 3+)**
1. Add Rust support (Cargo.toml)
2. Add Go support (go.mod)
3. Add Python support (requirements.txt/pyproject.toml)
4. Follow same pattern as PHP/Dart

**Phase 4: Polish and Validation (Final Sprint)**
1. Comprehensive cross-stack testing
2. Documentation updates
3. Performance optimization
4. Edge case handling

### Backward Compatibility

- **Existing users:** No breaking changes - `/codelens:review` works unchanged
- **Existing projects:** JS/TS projects analyzed as before
- **Existing presets:** pr-check, a11y-audit, full-audit preserved
- **reviews.json:** Schema unchanged (6 fields)

---

## Performance Considerations

### Phase 0.5 Overhead

**Impact:** +1 fd call (~50ms for typical repo)

**Mitigation:** Single fd call with multiple glob patterns - runs once per session

### Phase 1 Signal Collection

**Impact:** +3-5 commands per detected stack

**Mitigation:** ctx_batch_execute runs commands in parallel (concurrency: 2)

**Estimated cost:**
- JS/TS only: ~2s (existing)
- + PHP: +2.5s (PHPStan + Psalm + composer-dependency-analyser)
- + Dart: +1.5s (flutter analyze + dcm)
- Multi-stack: ~4-5s total (parallel execution)

### Phase 3 Hotspot Analysis

**Impact:** Stack-aware pattern matching adds minimal overhead

**Mitigation:** Pattern checks are gated by stack detection - no cost if stack not detected

### Context Window

**Impact:** Agent grows from ~400 to ~800 lines

**Mitigation:** 
- Clear section headers for quick navigation
- Inline comments for phase boundaries
- Pattern blocks are code (not prose) - less token overhead

---

## Security Considerations

### Tool Execution

**Risk:** Running third-party tools (PHPStan, DCM, etc.) on user code

**Mitigation:**
- All tools read-only - no code modification
- Tools run in user's environment (no remote execution)
- Tool availability probed in Phase 0 before use

### CVE Scanning

**Risk:** False positives from osv-scanner or OSV.dev

**Mitigation:**
- Phase 2.5 verification via Context7 + WebSearch
- Report marks CVEs as "candidate findings"
- Clear severity classification (not all CVEs are exploitable)

### Stack Detection

**Risk:** Incorrect stack detection leading to wrong tool selection

**Mitigation:**
- Multiple fingerprint checks (lockfile + framework-specific markers)
- Fallback to generic analysis if detection fails
- Report notes detection method in Methodology

---

## Documentation Requirements

### User Documentation

**README.md Updates:**
- Add multi-stack support section
- Document supported stacks (JS/TS, PHP, Dart, Rust, Go, Python)
- Add stack-specific examples
- Document fallback behavior

**CHANGELOG.md:**
```
## [0.1.0] - 2026-06-XX
### Added
- Multi-stack support (PHP/Laravel, Dart/Flutter)
- Stack-aware tool selection and fallback chains
- Enhanced reporting with stack-specific domain sections

### Changed
- Agent enhanced from ~400 to ~800 lines
- Phase 0.5 added for stack detection
- Phase 1 enhanced with stack-specific signal collection
- Phase 3 enhanced with stack-aware pattern matching
- Phase 4 enhanced with stack domain sections
```

### Developer Documentation

**ARCHITECTURE.md:**
- Document Phase 0.5 stack detection logic
- Document tool registry and fallback chains
- Document stack-aware pattern matching

**CONTRIBUTING.md:**
- Add stack contribution guidelines
- Document pattern for adding new stack support
- Add testing requirements for new stacks

---

## Success Criteria

### Functional Requirements

- [ ] Stack detection correctly identifies PHP/Laravel projects
- [ ] Stack detection correctly identifies Dart/Flutter projects
- [ ] PHP-specific tooling runs when composer.json detected
- [ ] Dart-specific tooling runs when pubspec.yaml detected
- [ ] Fallback chains activate when primary tools unavailable
- [ ] Report includes stack-specific domain sections
- [ ] Cross-domain dedup works across stack-specific findings
- [ ] reviews.json append maintains 6-field schema

### Non-Functional Requirements

- [ ] Agent remains stateless (no persisted intermediate state)
- [ ] Agent completes in single turn (no phase gates)
- [ ] Phase 0.5 adds <100ms overhead
- [ ] Phase 1 signal collection completes in <5s for typical repo
- [ ] Agent file remains <10,000 characters
- [ ] Backward compatible with existing `/codelens:review` usage

### Quality Requirements

- [ ] All existing tests pass
- [ ] New test scenarios added for PHP/Laravel
- [ ] New test scenarios added for Dart/Flutter
- [ ] Documentation updated with multi-stack examples
- [ ] CHANGELOG.md reflects v0.1.0 changes

---

## Open Questions

1. **Tool installation guidance:** Should we provide auto-install commands for missing tools (e.g., `composer require --dev phpstan/phpstan`) or require manual installation?
   - **Decision:** Document manual installation in `/codelens:doctor` - auto-install risks surprising users

2. **Multi-stack projects:** How should we prioritize findings in monorepos with multiple stacks?
   - **Decision:** Severity-first regardless of stack - maintain current approach

3. **Stack-specific presets:** Should review-presets.json include stack-specific presets (e.g., "php-security-audit")?
   - **Decision:** Yes - add in Phase 4 documentation updates

4. **Performance monitoring:** Should we track per-stack execution times?
   - **Decision:** Add to Methodology section - "PHP analysis completed in 2.3s using PHPStan + Psalm"

---

## References

**Design Documents:**
- Tool Validation Report: `/reports/codelens-reviewer-tool-validation.md`
- Refactor Spec v3 Addendum: `/reports/codelens-reviewer-refactor-spec-v3-addendum.md`

**Current Implementation:**
- Agent: `/agents/codelens-reviewer.md`
- Skill: `/skills/review/SKILL.md`
- Exclusions: `/.claude/codelens-exclusions.json`
- Presets: `/.claude/review-presets.json`

**External Documentation:**
- ripgrep: https://github.com/BurntSushi/ripgrep
- Biome: https://biomejs.dev/
- OpenGrep: https://github.com/opengrep/opengrep
- osv-scanner: https://github.com/google/osv-scanner
- PHPStan: https://phpstan.org/
- Psalm: https://psalm.dev/
- DCM: https://dcm.dev/
