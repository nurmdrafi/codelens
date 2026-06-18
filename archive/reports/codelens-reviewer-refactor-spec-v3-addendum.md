# Refactor Spec v3 — Addendum: Laravel/PHP and Flutter/Dart Stack Support

Patches into v3 spec at every point where stack detection, tool selection, fallback
chains, and Phase 0/1 commands are defined. Apply this addendum ON TOP of v3 — do not
rewrite v3; patch the specific sections listed below.

---

## PATCH 1 — Phase 0 Slot 1: Add PHP and Dart manifest fingerprints

**Find in v3:** Phase 0 Slot 1 fd command.

**Change:** Add `composer.json` and `pubspec.yaml` to the fd glob list.

```bash
# Slot 1 — Stack fingerprint (updated)
fd --type f \
   -g "package.json" -g "Cargo.toml" -g "go.mod" \
   -g "requirements.txt" -g "pyproject.toml" -g "pom.xml" \
   -g "build.gradle" -g "*.csproj" -g "Gemfile" \
   -g "composer.json" \
   -g "pubspec.yaml" \
   --max-depth 2 . 2>/dev/null
```

**Laravel detection refinement:** `composer.json` alone means PHP. Laravel is confirmed
if `composer.json` contains `"laravel/framework"` in the `require` block. Run this
check as a single jq command in the aggregation script (Phase 1.5), not in Phase 0:

```bash
jq -e '.require["laravel/framework"] // .require["laravel/lumen-framework"]' \
   composer.json > /dev/null 2>&1 && echo "laravel=true" || echo "laravel=false"
```

Result feeds the Laravel-specific tool activation (Larastan vs plain PHPStan).

---

## PATCH 2 — Phase 0 Slot 4: Add PHP and Dart tool probes

**Find in v3:** Phase 0 Slot 4 `which` command.

**Change:** Append PHP and Dart/Flutter tool probes to the existing probe line.

```bash
# Slot 4 — Tool availability probes (updated)
which semgrep opengrep osv-scanner biome repotoire jscpd knip \
      phpstan psalm composer dcm dart flutter 2>/dev/null; \
npx --yes --quiet biome --version 2>/dev/null; \
npx --yes --quiet knip --version 2>/dev/null; \
composer show larastan/larastan --no-interaction 2>/dev/null | grep -c larastan || echo "0"
```

The `composer show larastan/larastan` check tells the agent whether Larastan is already
installed as a dev dependency (most Laravel projects have it). If it is, use it directly.
If not, fall back to plain PHPStan with `--level=5` as a reasonable default.

---

## PATCH 3 — Phase 0 Stack decision table: PHP/Laravel and Dart/Flutter entries

**Find in v3:** Stack decision table after Slot 3.

**Add these rows:**

```
PHP detected (composer.json present) →
    enable: phpstan (or larastan if detected), psalm, composer-dependency-analyser
    if Laravel confirmed → enable: larastan (wraps phpstan), use laravel-specific rules
    if plain PHP → enable: phpstan --level=5

Dart/Flutter detected (pubspec.yaml present) →
    enable: dart analyze, dcm
    if flutter confirmed (flutter in pubspec.yaml environment or sdk: flutter) →
        enable: flutter analyze (wraps dart analyze), dcm analyze-widgets
    if plain Dart (no flutter dependency) →
        enable: dart analyze only, dcm (non-widget rules only)

For both stacks:
    always: osv-scanner (PHP → composer.lock, Dart → pubspec.lock)
    always: opengrep/semgrep (covers PHP and Dart natively)
    always: jscpd (duplication, 223+ languages)
    skip: biome, knip (JS/TS only — not applicable)
    skip: repotoire (PHP and Dart not in its 9-language list — use rg fallback)
    skip: cargo clippy, ruff (wrong ecosystems)
```

---

## PATCH 4 — Phase 1 Signal Collection: PHP/Laravel domain commands

**Find in v3:** Phase 1 "Language-specific additions" section.

**Add a new block:**

```bash
# PHP / Laravel repos — run when composer.json detected
# ─────────────────────────────────────────────────────

# SECURITY + QUALITY: PHPStan / Larastan
# Larastan is PHPStan with full Laravel-aware type inference (Eloquent,
# facades, service container, route helpers). Use it when detected.
# --error-format=json produces machine-readable output directly.

# If Larastan installed:
vendor/bin/phpstan analyse --error-format=json --no-progress \
    app/ bootstrap/ config/ database/ routes/ \
    --memory-limit=512M 2>/dev/null

# If Larastan not installed, plain PHPStan at level 5:
vendor/bin/phpstan analyse --level=5 --error-format=json --no-progress \
    <scopePath> 2>/dev/null

# SECURITY (taint analysis): Psalm with taint tracking
# Psalm's built-in taint analysis tracks user input ($_GET, $_POST, $_REQUEST)
# through the application to dangerous sinks (SQL, shell, HTML output).
# PHPStan does NOT have this — Psalm is complementary, not redundant.
# Use --output-format=json for machine-readable output.
vendor/bin/psalm --taint-analysis --output-format=json --no-progress 2>/dev/null

# DEAD DEPENDENCIES: composer-dependency-analyser
# Detects unused, shadow, and misplaced composer dependencies.
# 15,000 files in 2 seconds. Zero composer dependencies itself.
# No JSON flag — output is structured text, parse with grep/awk in Phase 1.5.
vendor/bin/composer-dependency-analyser 2>/dev/null \
    || composer require --dev shipmonk/composer-dependency-analyser -q \
       && vendor/bin/composer-dependency-analyser 2>/dev/null

# ARCHITECTURE: rg --count fallback (repotoire does not support PHP)
rg --count-matches 'class [A-Z]' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "php_classes:"s}'
rg --count-matches 'function ' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "php_functions:"s}'
rg --count-matches 'TODO|FIXME|HACK|@deprecated' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "php_debt:"s}'

# Laravel-specific signals (only if laravel=true from Phase 1.5 detection)
rg --count-matches 'DB::' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "raw_db_calls:"s}'
rg --count-matches 'env(' <scopePath> --type php <EXCL> \
    | awk -F: '{s+=$2} END {print "env_outside_config:"s}'
# Note: env() calls outside config/ files is a Laravel anti-pattern (breaks config cache)
# Phase 3 confirmation should filter for calls in app/ routes/ vs config/ only
```

**Availability fallback for PHP tools:**
```
PHPStan/Larastan not in vendor/ → install via: composer require --dev larastan/larastan
Psalm not in vendor/ → skip Psalm (taint analysis is nice-to-have, not blocking)
composer-dependency-analyser not in vendor/ → auto-install as shown above
```

---

## PATCH 5 — Phase 1 Signal Collection: Dart/Flutter domain commands

**Add another new block in Phase 1 "Language-specific additions":**

```bash
# Dart / Flutter repos — run when pubspec.yaml detected
# ──────────────────────────────────────────────────────

# CORE ANALYSIS: dart analyze / flutter analyze
# Built-in, always available wherever Dart/Flutter SDK is installed.
# --format=machine produces structured line-delimited output (file|line|col|severity|msg)
# flutter analyze wraps dart analyze with Flutter-specific rules added.

# If Flutter project:
flutter analyze --no-pub --format=machine <scopePath> 2>/dev/null \
    | awk -F'|' '{print "{\"file\":\""$3"\",\"line\":"$4",\"severity\":\""$1"\",\"msg\":\""$5"\"}"}'

# If plain Dart (no Flutter):
dart analyze --format=machine <scopePath> 2>/dev/null \
    | awk -F'|' '{print "{\"file\":\""$3"\",\"line\":"$4",\"severity\":\""$1"\",\"msg\":\""$5"\"}"}'

# The awk converts --format=machine pipe-delimited output to one JSON object per line.
# Phase 1.5 aggregation script reads this as newline-delimited JSON.

# QUALITY + METRICS: DCM (Dart Code Metrics)
# Flutter-specific lint rules beyond the built-in analyzer:
# widget quality analysis, unused code/files/l10n, dependency checks,
# code duplication within Dart, cyclomatic complexity, nesting level.
# --reporter=json for machine-readable output.
# Exclude generated files (*.g.dart, *.freezed.dart) — always high noise.

# Lint rules:
dcm analyze lib --reporter=json \
    --exclude="{**/*.g.dart,**/*.freezed.dart,**/*.pb.dart}" 2>/dev/null

# Widget quality (Flutter only):
dcm analyze-widgets lib --reporter=json \
    --exclude="{**/*.g.dart,**/*.freezed.dart}" 2>/dev/null

# Unused code:
dcm check-unused-code lib --reporter=json \
    --exclude="{**/*.g.dart,**/*.freezed.dart}" 2>/dev/null

# Unused files:
dcm check-unused-files lib --reporter=json \
    --exclude="{**/*.g.dart,**/*.freezed.dart}" 2>/dev/null

# Unused dependencies (pubspec.yaml):
dcm check-dependencies --reporter=json 2>/dev/null

# ARCHITECTURE: rg --count fallback (repotoire does not support Dart)
rg --count-matches 'class [A-Z]' <scopePath> --type dart <EXCL> \
    | awk -F: '{s+=$2} END {print "dart_classes:"s}'
rg --count-matches 'Widget build' <scopePath> --type dart <EXCL> \
    | awk -F: '{s+=$2} END {print "flutter_widgets:"s}'
rg --count-matches 'TODO|FIXME|HACK' <scopePath> --type dart <EXCL> \
    | awk -F: '{s+=$2} END {print "dart_debt:"s}'

# Flutter-specific quality signals
rg --count-matches 'setState(' <scopePath> --type dart <EXCL> \
    | awk -F: '{s+=$2} END {print "setState_calls:"s}'
# High setState count is an architecture signal (business logic leaking into UI layer)
```

**Availability fallback for Dart/Flutter tools:**
```
dart analyze → always available if Dart SDK installed (any Dart project has it)
flutter analyze → always available if Flutter SDK installed
dcm → install: dart pub global activate dcm
     if not available: skip DCM, dart analyze covers core issues
```

---

## PATCH 6 — CVE/dependency domain: PHP and Dart lockfile paths

**Find in v3:** Part 3, Rule 4 — osv-scanner lockfile path stack-aware table.

**Add these rows:**

```
PHP/Laravel  → composer.lock  (osv-scanner scan --format json -L composer.lock)
Dart/Flutter → pubspec.lock   (osv-scanner scan --format json -L pubspec.lock)
```

Both are confirmed supported by osv-scanner v2 against OSV.dev's Packagist (PHP) and
Pub (Dart) ecosystems. One command, same JSON format as every other ecosystem.

---

## PATCH 7 — Phase 1.5 aggregation script: PHP and Dart parser additions

**Find in v3:** Phase 1.5 aggregation script comment block.

**Add to the signals dict and parsing logic:**

```python
signals = {
    # ... existing domains from v3 ...
    "php_security": [],     # PHPStan + Psalm taint findings
    "php_quality": [],      # PHPStan type/quality findings
    "php_dead_deps": [],    # composer-dependency-analyser unused/shadow
    "dart_analysis": [],    # dart analyze / flutter analyze findings
    "dart_quality": [],     # DCM lint findings
    "dart_widgets": [],     # DCM widget quality findings
    "dart_dead_code": [],   # DCM unused code/files findings
}

# PHPStan JSON output shape:
# {"totals":{"errors":N,"file_errors":N},
#  "files":{"path":{"errors":N,"messages":[{"message":"...","line":N,"ignorable":bool}]}}}
# Parse: flatten files.*.messages into (file, line, message) tuples

# dart analyze --format=machine output (after awk conversion):
# {"file":"lib/src/x.dart","line":42,"severity":"ERROR","msg":"..."}
# Parse: read newline-delimited JSON, group by severity

# DCM JSON output shape varies by command but consistently contains:
# {"issues":[{"ruleId":"...","severity":"...","location":{"path":"...","line":N},"message":"..."}]}
# Parse: flatten issues array

# Psalm --output-format=json output:
# {"results":{"...file...":{"errors":[{"severity":"...","line_from":N,"message":"...","taint_trace":[...]}]}}}
# Parse: flatten results.*.errors, flag taint_trace presence as security signal

# Deduplication across PHPStan + Psalm: same file:line may appear in both
# Keep the one with more detail (Psalm's taint_trace > PHPStan message only)
```

---

## PATCH 8 — Part 2 Tool Roster: PHP and Dart conditional tools

**Find in v3:** Part 2 "Conditional tools (language/stack gated)" table.

**Add these rows:**

| Tool | Language basis | Condition | Job |
|---|---|---|---|
| `phpstan` / `larastan` | PHP | `composer.json` detected | Type analysis, bug detection, 11 strictness levels. Larastan = PHPStan + Laravel-aware extensions (Eloquent, facades, service container) |
| `psalm` | PHP | `composer.json` detected | Taint analysis: tracks `$_GET`/`$_POST` to SQL/shell/HTML sinks. Complementary to PHPStan — covers what PHPStan cannot |
| `composer-dependency-analyser` | PHP | `composer.json` detected | Unused, shadow, and misplaced composer dependencies. 15,000 files in 2s, zero own dependencies |
| `dart analyze` / `flutter analyze` | Dart | `pubspec.yaml` detected | Core Dart/Flutter static analysis. Always available where SDK is installed |
| `dcm` | Dart | `pubspec.yaml` detected | Flutter-specific lint beyond the built-in analyzer: widget quality, unused code/files/l10n, dependency hygiene, cyclomatic complexity |

---

## PATCH 9 — Part 3 Multi-Language Safety Rules: PHP and Dart additions

**Find in v3:** Part 3, Rule 2 — Fallback chain.

**Add to the fallback chain table:**

```
PHP Security:    phpstan (JSON) + psalm --taint-analysis (JSON) → opengrep/semgrep fallback
PHP Dead deps:   composer-dependency-analyser → rg --count 'use ' (crude fallback)
PHP Quality:     phpstan → rg --count patterns (fallback)
PHP a11y:        SKIP (server-side PHP has no a11y domain; Blade templates not covered
                 by biome. If Blade a11y is needed: opengrep custom rules for aria/alt attrs)
PHP Duplication: jscpd (covers PHP)
PHP CVE:         osv-scanner -L composer.lock → WebSearch + version check (fallback)

Dart Security:   opengrep/semgrep (Dart supported) → dart analyze (errors only) → rg fallback
Dart Dead code:  dcm check-unused-code + check-unused-files → rg fallback
Dart Quality:    dcm analyze → dart analyze --fatal-warnings → rg fallback
Dart a11y:       SKIP (mobile UI accessibility in Flutter is Semantics widget usage —
                 not covered by current static tools. Flag as "not automatically detectable"
                 in the report's Tools Used section rather than producing false empty results)
Dart Duplication: jscpd (covers Dart)
Dart CVE:        osv-scanner -L pubspec.lock → WebSearch + version check (fallback)
```

**Rule 3 addition — explicit "not applicable" statements for PHP and Dart:**

These domains must appear in the Phase 4 report as "not applicable" rather than
empty findings sections:

- PHP: a11y domain → "Not automatically detectable for server-rendered PHP/Blade templates
  via current static tools. Manual review of HTML output recommended."
- PHP: architecture domain → repotoire not applicable; rg-based class/function counts
  provided as a structural proxy; LLM judgment in Phase 4 synthesizes the picture.
- Dart/Flutter: a11y domain → "Flutter accessibility requires Semantics widget usage
  analysis — not covered by current static analysis tools. Use Flutter's Accessibility
  Inspector for manual verification."
- Dart/Flutter: architecture domain → repotoire not applicable; rg-based widget/class
  counts provided as structural proxy.

---

## PATCH 10 — Phase 4 Report: PHP and Dart domain sections

**Find in v3:** Phase 4 "per-domain tables" list.

**The report template must include these new domain columns for PHP/Laravel repos:**

```
PHP/Laravel report domains:
├── Security:     PHPStan errors + Psalm taint findings (file:line, severity, message)
├── Dependencies: osv-scanner CVEs from composer.lock + composer-dependency-analyser
│                 unused/shadow deps
├── Quality:      PHPStan warnings + rg debt markers (TODO/FIXME/@deprecated counts)
├── Architecture: rg class/function counts + Laravel-specific signals
│                 (raw DB:: calls count, env() outside config/ count)
└── Duplication:  jscpd findings
```

```
Dart/Flutter report domains:
├── Analysis:     dart analyze / flutter analyze errors and warnings
├── Widget Quality: dcm analyze-widgets findings (Flutter only)
├── Dead Code:    dcm check-unused-code + check-unused-files
├── Dependencies: osv-scanner CVEs from pubspec.lock + dcm check-dependencies
├── Quality:      dcm lint findings (cyclomatic complexity, nesting, setState overuse)
└── Duplication:  jscpd findings
```

---

## Summary: what this addendum adds to v3

| Stack | Detection signal | New tools | CVE source | Dead code | Architecture fallback |
|---|---|---|---|---|---|
| **PHP (plain)** | `composer.json` | `phpstan`, `psalm` | `osv-scanner -L composer.lock` | `composer-dependency-analyser` | rg --count (class/function) |
| **Laravel** | `composer.json` + `laravel/framework` in require | `larastan` (PHPStan wrapper), `psalm` | `osv-scanner -L composer.lock` | `composer-dependency-analyser` | rg Laravel signals (DB::, env()) |
| **Dart (plain)** | `pubspec.yaml` (no flutter dep) | `dart analyze`, `dcm` (non-widget) | `osv-scanner -L pubspec.lock` | `dcm check-unused-code/files` | rg --count (class counts) |
| **Flutter** | `pubspec.yaml` + flutter in environment | `flutter analyze`, `dcm` (full, incl. widgets) | `osv-scanner -L pubspec.lock` | `dcm check-unused-code/files` | rg widget/class counts |

**Tools shared with existing stacks (no new additions needed):**
- `opengrep`/`semgrep` — already covers PHP and Dart natively
- `jscpd` — already covers PHP and Dart (223+ languages)
- `osv-scanner` — already multi-ecosystem, just needs lockfile path added per stack
- `rg`, `fd`, `tokei` — already universal

**Only genuinely new tool categories added by this addendum:**
- PHPStan/Larastan (PHP type analysis — no equivalent already in the stack)
- Psalm (PHP taint analysis — unique capability, no equivalent for PHP anywhere else)
- composer-dependency-analyser (PHP dead deps — equivalent to knip but for Composer)
- dart analyze / flutter analyze (Dart core SDK tool — no equivalent already in the stack)
- DCM (Flutter-specific quality + widget analysis — no equivalent in the stack)
