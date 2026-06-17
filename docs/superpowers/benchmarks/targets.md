# Benchmark Targets (pinned)

Reproducibility: every benchmark run uses these exact target repos at these exact
commits. Re-clone or reset before each phase to avoid drift.

## Primary target — my-portfolio

- **Path:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio`
- **Pinned commit:** `ea032745cfa022795c75b078ca8195b9e5de4793` (branch `dev`)
- **Stack:** Next.js (top-level `components/`, `pages/`, no `src/`)
- **Cheap-scope path:** `./components` (36 files)
- **Why primary:** Real codebase, 36 component files exercise security/a11y/quality
  patterns cleanly, used in prior 2026-06-15 smoke tests.

### Run cheap shape

```bash
./scripts/bench-phase.sh <phase-label> /home/nurmdrafi/Desktop/MyProject/my-portfolio cheap ./components
```

### Run full shape

```bash
./scripts/bench-phase.sh <phase-label> /home/nurmdrafi/Desktop/MyProject/my-portfolio full
```

## Secondary target — dockerize-react-app

- **Path:** `/home/nurmdrafi/Desktop/MyProject/dockerize-react-app`
- **Pinned commit:** `a559db7d86d3b2b2c228dd1dc68d1f5fd711f9cb` (branch `with-env-serve`)
- **Stack:** Create-React-App (`src/` layout, 8 files)
- **Cheap-scope path:** `./src` (8 files)
- **Why secondary:** Small, fast iterations for cross-checking primary results.
  Different stack fingerprint (CRA vs Next.js) catches stack-specific regressions.

### Run cheap shape

```bash
./scripts/bench-phase.sh <phase-label> /home/nurmdrafi/Desktop/MyProject/dockerize-react-app cheap ./src
```

### Run full shape

```bash
./scripts/bench-phase.sh <phase-label> /home/nurmdrafi/Desktop/MyProject/dockerize-react-app full
```

## Refresh procedure (run before each phase)

```bash
cd /home/nurmdrafi/Desktop/MyProject/my-portfolio && git reset --hard ea032745cfa022795c75b078ca8195b9e5de4793
cd /home/nurmdrafi/Desktop/MyProject/dockerize-react-app && git reset --hard a559db7d86d3b2b2c228dd1dc68d1f5fd711f9cb
```

Also clean codelens side-effects from each target between runs:

```bash
rm -f /home/nurmdrafi/Desktop/MyProject/my-portfolio/CODEBASE_ANALYSIS_REPORT.md
rm -rf /home/nurmdrafi/Desktop/MyProject/my-portfolio/.codelens
rm -f /home/nurmdrafi/Desktop/MyProject/dockerize-react-app/CODEBASE_ANALYSIS_REPORT.md
rm -rf /home/nurmdrafi/Desktop/MyProject/dockerize-react-app/.codelens
```

## Why two targets

- **Single-target risk:** an optimization that wins on portfolio's Next.js layout
  could regress on dockerize-react-app's CRA layout. Two stacks catch this.
- **Speed:** dockerize-react-app's 8-file scope runs ~3-5× faster than portfolio's
  36-file scope, so most autoresearch iterations use the secondary for speed, then
  the primary validates the winner.
- **Findings diversity:** portfolio produces rich findings (auth, forms, SSR guards);
  dockerize-react-app produces a thin baseline. The guard threshold (20% findings
  drop) applies independently per target.

## Tertiary target — akg-frontend

- **Path:** `/Users/nur/Barikoi/akg-frontend`
- **Pinned commit:** `bc56e62616855076bfc2c317bd0c6f341ed1bf3b` (branch `main`)
- **Stack:** Next.js 15.5 + React 19 + TypeScript + Ant Design + shadcn
- **Cheap-scope path:** `./components` (React patterns, realistic complexity)
- **Why tertiary:** Production codebase, modern stack validates Biome on TSX, tests React 19 patterns

### Run cheap shape

```bash
./scripts/bench-phase.sh <phase-label> /Users/nur/Barikoi/akg-frontend cheap ./components
```

### Run full shape

```bash
./scripts/bench-phase.sh <phase-label> /Users/nur/Barikoi/akg-frontend full
```

### Refresh procedure (run before each phase)

```bash
cd /Users/nur/Barikoi/akg-frontend && git reset --hard bc56e62616855076bfc2c317bd0c6f341ed1bf3b
```

Clean codelens side-effects:

```bash
rm -f /Users/nur/Barikoi/akg-frontend/CODEBASE_ANALYSIS_REPORT.md
rm -rf /Users/nur/Barikoi/akg-frontend/.codelens
```

---

## Adding more targets later

If v0.0.5+ needs broader signal (e.g., a Python repo to validate non-JS rg patterns),
append a new section here following the same template. Pin the commit.
Do not benchmark against an unpinned target.
