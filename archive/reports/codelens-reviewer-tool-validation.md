# Tool Validation Report: Benchmark Evidence & Industry Adoption

Every tool recommended across the v3 spec and its addendum is listed below.
For each: what the independent evidence says, what the honest caveats are,
and whether an alternative exists that benchmarks better for the same job.

All benchmark sources cited are independent (not vendor-funded) unless explicitly noted.

---

## 1. ripgrep (rg)

**Used for:** Pattern counting, architecture/quality signals, universal fallback

**Benchmark evidence:**
- Linux kernel source tree (75,000 files): rg in 0.082s vs GNU grep in 0.671s — 8x faster
  (Source: BurntSushi/ripgrep GitHub README, reproduced independently by multiple parties)
- On a single 13.5GB file: rg 1.664s vs grep 9.484s
  (Source: macOS M1 benchmark by adamprzblk, Feb 2026)
- Official 25-benchmark comparison (burntsushi.net/ripgrep): rg wins or ties every test

**Who uses it:** VS Code (built-in search), Cursor, Claude Code, Codex CLI, Aider
— every major AI coding agent has independently converged on rg as their search backend.
This is the strongest possible adoption signal: independent convergence, not vendor claims.

**Honest caveats:**
- rg is NOT faster on very small files or patterns with few matches (the advantage
  requires parallelism to kick in — roughly 50+ files before the gap becomes significant)
- Cannot search compressed files or non-UTF-8 encodings (rare in source code review)

**Alternatives benchmarked:** grep, ag (Silver Searcher — unmaintained since 2018),
ack (Perl, slowest of the set), git grep (fast within git repos but requires git context)
**Verdict: rg is the correct choice. No close competitor exists.**

---

## 2. Biome (replaces ESLint + Prettier for JS/TS/a11y)

**Used for:** JS/TS/JSX/CSS lint, a11y rules, quality signals — one pass

**Benchmark evidence (independent, reproducible):**
- Linting 10,000 files: Biome 0.8s vs ESLint 45.2s — 56x faster
  (Source: Dev.to benchmark, reproduced by AppSignal May 2025, multiple others)
- Formatting 10,000 files: Biome 0.3s vs Prettier 12.1s — 40x faster
- Medium project (500 TS files): Biome <2s vs ESLint 15-20s
- Energy use: 70% less than ESLint on macOS M3 (quick-lint-js benchmarks 2025)

**Who uses it in production:** AWS, Google, Microsoft, Cloudflare, Coinbase,
Discord, Slack, Vercel, Astro, Node.js project itself — all confirmed adopters as of 2026.

**Rule coverage:** 491 lint rules in v2.3 (Jan 2026), including type-aware linting
(previously required @typescript-eslint slow TypeScript compiler invocation).
v2.4 adds 15 HTML a11y rules covering Vue, Svelte, Astro.
97% Prettier compatibility for formatting.

**Honest caveats:**
- Covers ~80% of what most projects need. The remaining 20% is framework-specific
  ESLint plugins and custom rule authoring — ESLint's plugin ecosystem (79.3M weekly
  downloads vs Biome's 2M) is still vastly larger.
- For projects with heavy React Testing Library, Storybook, or niche ESLint plugins:
  those plugins don't exist in Biome. ESLint fallback is correct for those cases.
- Biome's a11y rule set is newer than eslint-plugin-jsx-a11y's. For projects that
  specifically require jsx-a11y's full rule set: keep eslint-plugin-jsx-a11y.

**Alternative considered:** Oxlint (OXC toolchain) — fastest raw linting speed,
but lint-only (no formatting, no a11y). Not a full ESLint replacement for our needs.
**Verdict: Biome is the correct default for JS/TS. ESLint fallback documented.**

---

## 3. OpenGrep / Semgrep (security SAST)

**Used for:** Security signal collection, 30+ language coverage

**Benchmark evidence (independent OWASP Benchmark Project v1.2, standardized):**
- Semgrep CE: 87.06% True Positive Rate, 42.09% False Positive Rate
  (Source: OWASP Benchmark, reported by Xygeni 2026 — independent of Semgrep Inc.)
- "Sifting the Noise" (arXiv:2601.22952, 2025, peer-reviewed): Semgrep FPR at 74.8%
  on some CWE categories, reaching 1.00 on CWE-327 and CWE-330
- For context: SonarQube FPR is even higher at 45.8% on the full benchmark.
  CodeQL achieves best F1 but flags 68.2% of non-vulnerable cases as positive.

**The honest truth about SAST false positive rates:** Every free SAST tool has a
high false positive rate on the OWASP benchmark. This is a known, documented, industry-wide
problem. The benchmark tests synthetic vulnerabilities; real-world FPR is typically lower
but still significant. The spec's Phase 3 confirmation step (ctx_search + human judgment)
exists precisely because of this — Semgrep/OpenGrep find CANDIDATES, not confirmed bugs.

**OpenGrep vs Semgrep distinction:**
- OpenGrep (Jan 2025 fork): Backed by Aikido, Endor Labs, Jit, Orca Security + 6 others.
  Restores cross-function taint analysis that Semgrep CE moved behind commercial paywall.
  Fully LGPL-2.1, backward-compatible rule format, dedicated OCaml dev team.
- Semgrep CE (after Dec 2024): Moved cross-function taint, fingerprinting, and other
  features to commercial platform. CE is now single-function taint only.
- For free CLI use, OpenGrep is strictly better than Semgrep CE.

**Who uses Semgrep/OpenGrep:** Trail of Bits (security firm), Shopify, Dropbox,
Figma — listed as Semgrep users before the fork. OpenGrep is backed by 10+ AppSec vendors.

**Alternatives benchmarked:**
- CodeQL: Best F1 score on OWASP benchmark BUT requires compilation, GitHub dependency,
  harder local CLI use. Not practical for a language-agnostic local code review agent.
- SonarQube: Highest FPR in independent benchmarks (SonarQube flags 94.6% of non-
  vulnerable cases as positive in some CWE categories per arXiv:2601.22952).
  Not recommended.
- Psalm (PHP taint only): Best for PHP specifically, not multi-language.

**Verdict: OpenGrep is the correct primary, Semgrep as named fallback. Neither
produces low FPR without Phase 3 confirmation — this is inherent to SAST, not
a tool choice problem. The spec accounts for this correctly.**

---

## 4. osv-scanner (CVE/dependency scanning)

**Used for:** Multi-ecosystem lockfile scanning — Node, Rust, Go, Python, PHP, Dart, Java

**Benchmark evidence:**
- OSV.dev database aggregates GHSA + NVD + ecosystem-specific advisories.
  Same data Dependabot uses (confirmed by GitHub/Google partnership documentation).
- npm audit false positive rate: ~80% on typical projects (Source: PkgPulse analysis,
  March 2026 — independent, reproduces the finding from multiple team reports).
  This is why npm audit was rejected in favor of osv-scanner.
- osv-scanner v2 adds guided remediation: calculates minimum upgrade set ranked by
  dependency depth, severity, and ROI. No equivalent in free tools.

**Who uses it:** Google (maintainer), CodeRabbit (AI code review platform integrates
osv-scanner as its default dependency scanner), multiple enterprise CI/CD pipelines.

**Honest caveats:**
- OSV.dev/GHSA coverage for npm ecosystem is strong. For Dart/Flutter (Pub), PHP
  (Packagist), and some smaller ecosystems, advisory coverage is thinner — not every
  CVE makes it into OSV.dev as fast as into Snyk's proprietary database.
- Snyk's proprietary database catches CVEs ~47 days before NVD on average (Snyk's
  own claim, not independently verified). If early-warning is critical: Snyk.
  For a free, local, multi-ecosystem scan: osv-scanner is the correct choice.
- osv-scanner does not detect malicious packages (typosquatting, supply chain attacks)
  — it only matches known CVEs. Socket.dev covers this gap but is a separate product.

**Alternatives evaluated:** npm audit (rejected — 80% FPR), Dependabot (GitHub-only,
not CLI-based), Snyk (commercial, per-scan limits), OWASP Dependency-Check (Java-only).
**Verdict: osv-scanner is the correct choice for free, local, multi-ecosystem CVE scanning.**

---

## 5. PHPStan / Larastan (PHP/Laravel type analysis)

**Used for:** PHP static analysis, bug detection, type correctness

**Benchmark evidence / adoption data:**
- PHPStan has 13,800+ GitHub stars vs Psalm's 5,800 (StackShare data, 2026)
- meh.dev survey (tracks static analysis adoption across 1K+ star PHP repos, 2026):
  PHPStan is the most commonly used PHP static analysis tool in the surveyed set,
  with Psalm used alongside by a significant subset for complementary coverage.
- PHPStan 2.1 (early 2026): 25-40% faster analysis from caching + raw performance
  improvements; 50-70% less memory consumption on large projects vs previous versions.

**Adoption by major PHP projects:** Laravel itself (via Larastan),
Symfony (official PHPStan extensions), Doctrine, PHPUnit — official extensions exist
for all major PHP frameworks, indicating framework team endorsement.

**PHPStan vs Psalm in practice:**
- PHPStan: More permissive type inference (fewer false positives, may miss edge cases).
  11 progressive levels (0-10) make incremental adoption practical.
  Best plugin ecosystem (200+ community packages).
- Psalm: More conservative (catches bugs PHPStan allows through, especially mixed types
  and complex generics). Built-in taint analysis (tracks $_GET/$_POST to SQL/XSS sinks)
  — PHPStan has NO equivalent without a separate tool.
- The spec recommends BOTH for complementary coverage. This is validated by the meh.dev
  survey which confirms "running both is still a valid strategy for maximum coverage."

**Honest caveats:**
- Psalm's taint analysis adds significant overhead on large codebases — runs slower than
  standard type checking because it builds a full data-flow graph.
- Larastan requires Laravel — it adds noise on non-Laravel PHP projects. The addendum
  correctly gates it on `laravel/framework` presence in composer.json.

**Alternatives:** Phan (only used by MediaWiki per meh.dev survey — effectively niche),
Qodana (JetBrains, commercial, early traction but limited adoption data).
**Verdict: PHPStan/Larastan + Psalm combination is the current industry standard for PHP.**

---

## 6. dart analyze / flutter analyze + DCM (Dart/Flutter)

**Used for:** Dart/Flutter static analysis, widget quality, dead code

**Benchmark evidence / adoption data:**
- dart analyze: Part of the official Dart SDK (Google). Used by every Dart/Flutter
  project by default. Not a third-party tool — it IS the platform standard.
  Equivalent status to `cargo check` for Rust or `go vet` for Go.
- DCM: Used by the Dart and Flutter DevTools team (Google's own tools team) per DCM's
  own documentation. This is the strongest possible endorsement — the framework's
  own tooling team uses it to maintain quality.
- DCM supports presets for Bloc, Riverpod, Provider, GetX, Flame, Equatable —
  the major Flutter state management and game libraries — indicating broad framework
  coverage validated by community use.

**What dart analyze / DCM cover that nothing else does:**
- Widget rebuild analysis (setState overuse detection) — no other tool does this
- Flutter-specific anti-patterns (calling setState in build(), unnecessary rebuilds)
- Null safety validation (Dart 3.x null safety is a primary quality signal)
- Unused l10n (localization strings) — unique to DCM for Flutter

**Honest caveats:**
- DCM's free tier has limitations; full rule set requires a license for commercial use.
  For open-source or individual use, the free tier covers the core quality checks.
  The spec should note this — if DCM is unavailable, dart analyze alone covers core errors.
- Flutter accessibility is not statically detectable. This is correctly flagged as
  "not applicable" in the spec, but worth emphasizing: NO tool in 2026 can statically
  verify correct Semantics widget usage in Flutter. This is an inherent gap in the
  state of Flutter tooling, not a gap in the spec.

**Alternatives:** flutter_statix (newer, less mature), dart_code_metrics (older name
for what is now DCM — same project, same maintainers, renamed in 2023).
**Verdict: dart analyze + DCM is the correct and only viable choice for Flutter/Dart.**

---

## 7. jscpd (duplication detection)

**Used for:** Code duplication across all languages (223+)

**Benchmark evidence:**
- jscpd v5: Rust core, 24-37x faster than v4 (Node.js)
  (Source: jscpd.dev own documentation — vendor claim, not independently reproduced)
- AI Reporter format: ~79% token reduction vs default reporter
  (Source: jscpd.dev — vendor claim, mechanism is verified: it produces summarized
  output vs per-clone full context output)

**Honest caveats:**
- The 24-37x speed claim is from jscpd's own benchmarks, not independently verified.
  The Rust core is real and verified (crates.io listing). The speed order of magnitude
  is plausible given Rust vs Node.js for this workload.
- jscpd's duplication detection is token-based, not AST-based — this means it can
  produce false positives on code that looks syntactically similar but is semantically
  different (e.g., boilerplate test setup across files). The `--min-lines 5` flag
  in the spec reduces but doesn't eliminate this.

**Alternatives:** CPD (PMD's copy-paste detector — Java-based, slower), SonarQube
(includes duplication but requires server infrastructure).
**Verdict: jscpd is the correct choice for a CLI-based, multi-language duplication scan.
Speed claim should be treated as approximate until independently reproduced.**

---

## 8. tokei (code counting / stack composition)

**Used for:** Language detection, file counts, LOC stats in Phase 0

**Benchmark evidence:**
- tokei: "millions of lines of code in seconds" (crates.io)
- Rust-based, parallel file processing, handles nested/multi-line comments correctly
- 150+ languages supported, respects .gitignore by default
- Independently confirmed faster and more accurate than cloc on multi-line comment
  handling (multiple developer blog posts, no formal benchmark paper)

**Who uses it:** Listed as a standard tool in multiple "Rust CLI tools" roundups;
Repotoire blog explicitly recommends it for codebase stats.

**Honest caveats:** No formal independent academic benchmark. Speed and accuracy
claims are from developer community consensus rather than controlled studies.
For Phase 0's purpose (language detection + file counts), tokei's correctness on
multi-line comments is the relevant property — confirmed by its design.

**Alternatives:** cloc (Perl, slower, less accurate on nested comments), scc (Go,
comparable speed). tokei is the Rust-native choice consistent with the spec's preferences.
**Verdict: Correct choice for the job. No accuracy concerns for Phase 0's usage.**

---

## 9. repotoire (architecture analysis)

**Used for:** Architecture graph, circular dependency detection, 9 languages

**Benchmark evidence:**
- ~400 files/second (crates.io documentation)
- 110 pure Rust detectors running in parallel via rayon
- Uses tree-sitter compiled to native Rust — no external runtime dependencies
- 9 languages: Rust, Python, TypeScript, JavaScript, Go, Java, C#, C++, Kotlin

**Honest caveats:**
- Repotoire is newer/less established than the other tools in this stack.
  It has no independently published benchmark study. The 400 files/second figure
  is from its own documentation.
- PHP, Dart, Ruby, Swift are NOT supported. The spec correctly falls back to rg
  counts for these languages. This is a real gap, not a workaround.
- The tool is actively developed (March 2026 blog post, recent crates.io updates)
  but has less community validation than tools like PHPStan or Semgrep.

**Alternatives:** The closest alternative is running multiple single-language
architecture tools (depend-cruiser for JS/TS, cargo-modules for Rust, etc.) — but
that multiplies tool calls rather than reducing them.

**Verdict: Repotoire is the best available single-binary multi-language architecture
tool, but treat its findings as indicative rather than authoritative until it has
more independent validation. The spec's Phase 3 confirmation step is the correct
hedge for this.**

---

## 10. composer-dependency-analyser (PHP dead dependencies)

**Used for:** Unused, shadow, and misplaced PHP Composer dependencies

**Benchmark evidence:**
- Scans 15,000 files in 2.297 seconds (own documentation, README benchmark)
- Zero own Composer dependencies (important: no dependency hell for a dev tool)
- Comparison table in README vs icanhazstring/composer-unused (72s) and
  maglnet/composer-require-checker (124s) — same codebase
  (Source: shipmonk-rnd/composer-dependency-analyser README — vendor comparison)

**Honest caveats:**
- The benchmark comparison is vendor-produced (the tool's own README). The speed
  gap is large enough to be plausibly real (Rust-equivalent compiled vs slower
  interpreters), but no independent reproduction exists.
- DI container usages (Laravel service providers, Symfony bundles that are registered
  but not explicitly `use`d in PHP files) can produce false "unused dependency"
  findings. The spec notes this: "exclude service providers from unused-dep checks
  or add them to force-used symbols." This is a real, documented limitation.

**Verdict: Best available free CLI for PHP dead dependency detection. Speed claim
plausible, DI container caveat is real and documented in the tool itself.**

---

## Summary: Where the evidence is strong vs where it needs caveats

| Tool | Evidence quality | Key independent source | Main honest caveat |
|---|---|---|---|
| ripgrep | **Strong** | BurntSushi benchmarks, reproduced widely, used by VS Code/Cursor/Claude Code | Slower on tiny files |
| Biome | **Strong** | AppSignal May 2025, multiple dev blogs, AWS/Google/Cloudflare production use | 80% ESLint rule coverage |
| OpenGrep/Semgrep | **Mixed** | OWASP Benchmark (independent), arXiv:2601.22952 (peer-reviewed) | 42-74% FPR is real — Phase 3 confirmation is mandatory, not optional |
| osv-scanner | **Strong** | Same database as Dependabot (Google/GitHub), CodeRabbit integration | Thinner Pub/Packagist advisory coverage vs npm/PyPI |
| PHPStan | **Strong** | meh.dev adoption survey (independent), Laravel/Symfony/Doctrine official extensions | PHPStan needs Psalm for taint analysis — neither alone is complete |
| Psalm | **Good** | Security research backing, meh.dev survey, complementary with PHPStan | Taint analysis adds CI overhead on large codebases |
| dart analyze | **Very Strong** | Official Dart SDK — IS the platform standard, not a third-party tool | Not everything is statically detectable (Flutter a11y) |
| DCM | **Good** | Used by Flutter DevTools team (Google) | Commercial license for full features; free tier may be sufficient |
| jscpd | **Adequate** | Rust v5 core verified, AI reporter design verified; speed claim is vendor's own | 24-37x speed claim unverified by independent party |
| tokei | **Good** | Community consensus, developer blog reproductions, Rust design verified | No formal benchmark paper |
| repotoire | **Adequate** | Newer tool, own documentation, no independent benchmark paper yet | Treat as indicative; Phase 3 confirmation required |
| composer-dependency-analyser | **Good** | Own README benchmark (vendor), zero-dependency design verified | DI container false positives are real and documented |

---

## What this means for the agent's Phase 3

The SAST tools (OpenGrep/Semgrep, PHPStan, Psalm, dart analyze) all produce candidate
findings, some with documented high false positive rates. Phase 3's confirmation step
is not optional hygiene — it is a **required correctness mechanism** given the evidence
above. An agent that skips Phase 3 and reports all SAST findings as confirmed bugs would
be wrong on a meaningful fraction of findings.

The non-SAST tools (osv-scanner, Biome, jscpd, knip, DCM, composer-dependency-analyser)
produce lower false positive output by design (database matching, AST-based rules, exact
symbol analysis). Phase 3 for these is a lighter check — confirm file:line exists,
not a deep correctness re-verification.

The spec correctly treats all tool outputs as candidates. This report validates that
the tool choices are the current best available options for each job, with the caveats
above documented so the agent's Phase 4 report can qualify findings appropriately.
