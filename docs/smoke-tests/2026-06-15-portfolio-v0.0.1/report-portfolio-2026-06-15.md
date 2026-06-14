# Codebase Analysis Report — `my-portfolio`

| | |
|---|---|
| **Project** | `portfolio-next` v1.0.0 (Next.js personal portfolio) |
| **Scan date** | 2026-06-15 |
| **Tech stack** | Next.js 13.4.7 (Pages Router), React 18.2.0, TypeScript 5.1.3 (strict), Tailwind CSS v4, shadcn/ui (`@base-ui/react`), Framer Motion 11, AOS 2.3.4, react-hook-form 7.45, `@emailjs/browser` 3.11, react-hot-toast 2.4, lucide-react, react-icons |
| **Domains reviewed** | Security, Architecture, Code Quality, Accessibility |
| **Scope** | Path scope — `/home/nurmdrafi/Desktop/MyProject/my-portfolio` |
| **Files scanned** | 45 source files (`.tsx`/`.ts`/`.css`), ~2,983 LoC |
| **Hotspot files deep-read** | 15 (single pass, no re-reads) |

---

## Executive Summary

**Security** — One Critical finding: the project pins **Next.js 13.4.7**, which falls inside the affected range of three 2025 advisories (CVE-2025-29927 auth-bypass, CVE-2025-55182 / CVE-2025-66478 RCE). The EmailJS integration exposes three `NEXT_PUBLIC_*` identifiers in the client bundle (this is by design for EmailJS, but the variable named `..._API_KEY` reads as a secret and the SDK throws no useful error to the user on failure). No XSS, no hardcoded credentials, no `localStorage` secrets, no `eval`.

**Architecture** — Clean Pages-Router layout. Each section is one folder under `components/` with a colocated `data.ts(x)` and an `index.tsx`. Two deviations: `components/common/card-3d.tsx` exports a React Context (`MouseEnterContext`) from a generic `common/` folder rather than a dedicated provider module, and `pages/blog.tsx` duplicates the `<Meta>` + `<Navbar>` + `<Footer>` + `<ScrollToTop>` scaffolding that `pages/index.tsx` already pays the cost for (no shared layout).

**Code Quality** — Generally strong: typed props everywhere, react-hook-form used correctly, `ScrollToTop` correctly debounces with `requestAnimationFrame` and cleans up its listener. Three issues: `_handleSendEmail` declares `response: any` and `error: any` (defeats TS strict), the `catch` only logs to `console.log` and never shows the user a failure toast, and the `minLength` validator at `contact/index.tsx:74` uses the key `minLength` while react-hook-form emits `minLength` only for the registered rule — the rendering check at line 80 (`errors?.name?.type === "minLength"`) works but mixes stringly-typed comparisons with the rest of the file's pattern.

**Accessibility** — Better than typical for a personal portfolio: every icon-only social link has an `aria-label`, every image has `alt`, the navbar has `aria-label="Main navigation"`, the mobile Sheet has a `sr-only` `<SheetTitle>`, form inputs use `aria-invalid`. Gaps: the contact form's three `<Input>` / `<Textarea>` fields have **no `<label>` elements and no `aria-label`** (placeholder-only — WCAG 1.3.1 / 4.1.2 violation), error messages are not linked via `aria-describedby` (so screen readers won't announce them), the decorative SVG wave in `footer.tsx` is missing `aria-hidden="true"` (screen readers will try to parse it), and the `Card3D` tilt effect is mouse-only with no keyboard/`prefers-reduced-motion` fallback.

---

## Findings by Severity

### Critical

| # | Finding | File:Line | Domains | OWASP / Criteria |
|---|---|---|---|---|
| C1 | Next.js 13.4.7 is within the affected range of three 2025 critical CVEs | `package.json:18` | Security | A06 — Vulnerable Components |

#### C1 — Next.js 13.4.7 pinned, multiple critical CVEs apply

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/package.json:18`

**Evidence:**
```json
"next": "13.4.7"
```

**Impact:** Next.js 13.4.7 falls inside the vulnerable version range for:
- **CVE-2025-29927** — Authentication bypass via middleware header manipulation. Affects Next.js `>= 1.11.4` up to patched releases. Unauthenticated attackers can bypass authorization middleware. ([NVD CVE-2025-29927](https://nvd.nist.gov/vuln/detail/CVE-2025-29927))
- **CVE-2025-55182** — Critical RCE in React Server Components ("React2Shell"), disclosed 2025-12-03. ([Vercel changelog](https://vercel.com/changelog/cve-2025-55182))
- **CVE-2025-66478** — Critical RCE in RSC protocol. ([Next.js blog](https://nextjs.org/blog/CVE-2025-66478))

Although this portfolio is a static site (Pages Router, no middleware, no RSC), the CVEs are still in your dependency tree. A static site makes exploitation of the middleware-bypass CVE unlikely, but the RSC advisories also patched other code paths you do touch (SSR rendering of `_app.tsx`, image optimization).

**Fix:** Upgrade to the latest patched Next.js release in the 13.x or (preferred) 14.x / 15.x line. Run `npm audit` and `npm install next@latest`, then `npm run build` to confirm the Pages Router still compiles. Verify `next/image`, `next/font`, and `next/head` behavior on the upgraded version.

---

### High

| # | Finding | File:Line | Domains | OWASP / WCAG |
|---|---|---|---|---|
| H1 | Contact form fields use placeholder-only labels — no `<label>` or `aria-label` | `components/contact/index.tsx:63, 95, 125` | A11y | WCAG 1.3.1, 4.1.2 (Level A) |
| H2 | Form validation errors not linked via `aria-describedby` | `components/contact/index.tsx:80, 110, 140` | A11y | WCAG 4.1.2, 3.3.1 (Level A) |
| H3 | Contact form failure path silent — user gets no error feedback | `components/contact/index.tsx:42-44` | Quality | — |

#### H1 — Contact form inputs lack accessible labels

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/contact/index.tsx` lines 63 (Name `<Input>`), 95 (Email `<Input>`), 125 (Message `<Textarea>`)

**Evidence:** Each input relies solely on `placeholder="Name"`, `placeholder="Email"`, `placeholder="Your Message"`. Placeholders disappear on input and are not a substitute for a programmatic label.

**Impact:** Screen reader users navigating in forms-mode hear no field name. Voice-control users cannot say "click name" to focus the field. WCAG 1.3.1 (Info and Relationships) and 4.1.2 (Name, Role, Value) — both Level A.

**Fix:** Add visible `<Label>` components (the project already imports `@/components/ui/label`) above each field, or at minimum add `aria-label="Name"` / `aria-label="Email"` / `aria-label="Message"` to each input.

#### H2 — Validation errors not linked to inputs via `aria-describedby`

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/contact/index.tsx:80, 110, 140` (the `<p>` error text blocks)

**Evidence:** Error paragraphs render conditionally (e.g., `{errors?.name?.type === "required" && (<p className="pt-2 text-left text-destructive">...`)}`) but the corresponding `<Input>` has no `aria-describedby` pointing at the error's `id`. Also no `role="alert"` on the error paragraph.

**Impact:** When a validation error appears, screen readers do not announce it because the connection between input and message is purely visual. Users who rely on SR hear "invalid entry" (from `aria-invalid`) but not why. WCAG 4.1.2 and 3.3.1 (Level A).

**Fix:** Give each error paragraph a stable `id` (e.g., `name-error`), pass `aria-describedby="name-error"` to the input, and add `role="alert"` to the paragraph so it announces on insertion.

#### H3 — Contact form silently swallows send failures

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/contact/index.tsx:42-44`

**Evidence:**
```ts
} catch (error: any) {
  console.log(error.text);
} finally {
  reset();
}
```

**Impact:** When `emailjs.sendForm` rejects (network down, quota exceeded, invalid template, etc.), the user sees nothing — but the form still resets in the `finally` block, destroying their input. They walk away believing the message sent. This is the worst-case UX for a contact form: silent data loss.

**Fix:** In the `catch`, call `toast.error("Message failed to send. Please try again or email me directly.")`, and **do not** call `reset()` in `finally` — move `reset()` inside the success branch only, so the user can retry without retyping.

---

### Medium

| # | Finding | File:Line | Domains | OWASP / WCAG / Criteria |
|---|---|---|---|---|
| M1 | `response: any` / `error: any` defeat TypeScript strict mode in contact handler | `components/contact/index.tsx:26, 42` | Quality | — |
| M2 | Decorative footer SVG wave lacks `aria-hidden="true"` | `components/common/footer.tsx:15` | A11y | WCAG 1.3.1 |
| M3 | `Card3D` tilt effect is mouse-only — no keyboard / `prefers-reduced-motion` path | `components/common/card-3d.tsx:30-48` | A11y | WCAG 2.1.1, 2.3.3 |
| M4 | EmailJS identifiers exposed via `NEXT_PUBLIC_*` env vars (by design, but mislabeled) | `components/contact/index.tsx:27-30` | Security | A02 — Cryptographic Failures (low confidence; see note) |
| M5 | `pages/blog.tsx` duplicates page-scaffold from `pages/index.tsx` (no shared layout) | `pages/blog.tsx` vs `pages/index.tsx:13-25` | Architecture | — |
| M6 | `MouseEnterContext` exported from `components/common/` instead of a dedicated provider | `components/common/card-3d.tsx:10` | Architecture | — |
| M7 | Unused `Prospec` font family computed but never applied via class | `pages/_app.tsx:11-13` | Quality | — |

#### M1 — `any` types in contact handler defeat TypeScript strict

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/contact/index.tsx:26` (`const response: any`) and `:42` (`catch (error: any)`)

**Evidence:**
```ts
const response: any = await emailjs.sendForm(...)
...
} catch (error: any) {
  console.log(error.text);
}
```

**Impact:** The project declares `"strict": true` (per the run context) and `tsconfig` strict-mode is the only thing preventing `error.text` from compiling when `error` is `unknown`. Two `any` annotations in the hottest async path silently disable every typecheck the rest of the file buys. Also: `error.text` is not guaranteed — EmailJS errors can carry `.message` or `.status`, and accessing `.text` on `unknown` would throw at runtime inside the `catch`.

**Fix:** Type the response as `EmailJSResponseStatus` (exported from `@emailjs/browser`), and `catch (error: unknown)` with a narrowing helper or `error instanceof Error ? error.message : String(error)`.

#### M2 — Decorative footer SVG missing `aria-hidden="true"`

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/common/footer.tsx:15-72`

**Evidence:** The `<svg className="waves">` element with `<defs>`, `<path>`, and four `<use>` references is purely decorative ocean-wave animation. No `aria-hidden="true"` and no `role="img"` / `<title>`.

**Impact:** Screen readers may announce internal SVG element names or attempt to traverse the `<use>` references. WCAG 1.3.1.

**Fix:** Add `aria-hidden="true"` to the `<svg>` tag.

#### M3 — `Card3D` tilt effect has no keyboard or reduced-motion fallback

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/common/card-3d.tsx:30-48` (`handleMouseMove`, `handleMouseEnter`, `handleMouseLeave`)

**Evidence:** Tilt is bound exclusively to `onMouseMove` / `onMouseEnter` / `onMouseLeave`. There is no `onFocus` / `onBlur` equivalent, no `@media (prefers-reduced-motion: reduce)` override for the framer-motion springs.

**Impact:** Keyboard-only users never see the effect (acceptable) but also never get equivalent feedback that the card is interactive (not acceptable if the tilt conveys "this is hoverable"). Users with vestibular sensitivities get motion they cannot opt out of. WCAG 2.1.1 (Keyboard) and 2.3.3 (Animation from Interactions, Level AAA).

**Fix:** Wrap the spring setup in a `prefers-reduced-motion` check (`window.matchMedia('(prefers-reduced-motion: reduce)').matches` → return static values), and/or gate the tilt behind a `useReducedMotion()` from Framer Motion.

#### M4 — EmailJS public identifier named `..._API_KEY` (mislabeled, not a leak)

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/contact/index.tsx:30` — `${process.env.NEXT_PUBLIC_EMAILJS_API_KEY}`

**Evidence:** EmailJS's browser SDK is designed to be called with a **public key** that ships in the client bundle. This is documented behavior and not a leak. **However**, naming the variable `NEXT_PUBLIC_EMAILJS_API_KEY` misleads future maintainers and any security scanner into treating it as a secret. EmailJS's own docs call it a "public key".

**Impact:** Low direct risk; the real risk is a future contributor copying this pattern for an actual secret (e.g., a server-side API key) because "it worked for EmailJS". OWASP A02 (Cryptographic Failures) — defense-in-depth.

**Fix:** Rename to `NEXT_PUBLIC_EMAILJS_PUBLIC_KEY`. Optionally add a comment clarifying EmailJS public keys are safe to expose. Optionally enable EmailJS's "Allowed Origins" restriction in the dashboard so the key only works from `nurmdrafi.dev`.

#### M5 — `pages/blog.tsx` duplicates the page scaffold from `pages/index.tsx`

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/pages/blog.tsx` (per hotspot scan) vs `/home/nurmdrafi/Desktop/MyProject/my-portfolio/pages/index.tsx:13-25`

**Evidence:** `pages/index.tsx` composes `<Meta>` + `<Hero>` (which contains `<Navbar>`) + sections + `<Footer>` + `<ScrollToTop>`. `pages/blog.tsx` imports `Meta`, `Navbar`, `Footer`, `ScrollToTop` separately and re-composes them (confirmed via the Phase 2 architecture scan: `pages/blog.tsx:5: import Meta from '@/components/common/meta'`, `pages/blog.tsx:6: import Navbar from '@/components/navbar'`).

**Impact:** Adding a new page (e.g., `/uses`, `/talks`) means copying this 5-import scaffold a third time. Layout drift risk — if you add a cookie banner or analytics script, you have to touch every page.

**Fix:** Extract a `<Layout>` component in `components/common/layout.tsx` that takes `title` and `children`, renders Meta + Navbar + children + Footer + ScrollToTop, and have both pages use it. (Pages Router supports this pattern; for App Router this is automatic.)

#### M6 — `MouseEnterContext` exported from `components/common/card-3d.tsx`

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/common/card-3d.tsx:10`

**Evidence:** `const MouseEnterContext = createContext<...>(undefined);` lives in the same file as the `Card3D` component and the `useMouseEnter` hook.

**Impact:** A React Context is a piece of module-level infrastructure with its own lifecycle (Provider, Consumer, hook). Co-locating it with the visual component means anyone reading `common/` doesn't know this file exports infrastructure. Minor; readability hit only.

**Fix:** Either accept the colocation (the hook + context are tightly coupled to `Card3D` so it's defensible) or split into `components/common/card-3d/context.ts` + `card-3d/index.tsx`. Low priority.

#### M7 — Unused `Prospec` font computed but never applied

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/pages/_app.tsx:11-13`

**Evidence:**
```ts
const Prospec = localFont({ src: '../public/fonts/Prospec Light.otf' })
```
Then at line 31 it's only used to set a CSS custom property: `'--font-display': Prospec.style.fontFamily`. The class `${inter.className}` is applied to the wrapper div, so `Prospec.className` is never injected into the DOM as a class — only its `fontFamily` string flows through the CSS variable.

**Impact:** This actually works (the CSS var is consumed by `style={{ fontFamily: 'var(--font-display)' }}` in `banner/full-name.tsx:14` and `common/heading.tsx:13`). But it's subtle — a maintainer might "clean up" the seemingly-unused `Prospec` const and break the hero heading. Comment it.

**Fix:** Add a one-line comment: `// Prospec is consumed via --font-display CSS var, not as a className`. Low priority.

---

### Low

| # | Finding | File:Line | Domains |
|---|---|---|---|
| L1 | `_handleSendEmail` uses a leading underscore naming convention (non-idiomatic React) | `components/contact/index.tsx:24` | Quality |
| L2 | `_document.tsx` doesn't set `<html lang="en">` | `pages/_document.tsx:3` | A11y |
| L3 | `react-icons` and `lucide-react` both imported across the project (two icon systems) | multiple | Architecture |
| L4 | `data-aos="…"` attributes used without a `prefers-reduced-motion` gate on `AOS.init()` | `pages/_app.tsx:29-31` | A11y |
| L5 | `Inter` and `Space_Grotesk` both loaded from Google Fonts but only `Inter` is applied to the wrapper | `pages/_app.tsx:14` | Quality |

#### L1 — Leading-underscore method name

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/components/contact/index.tsx:24`

The `_handleSendEmail` naming suggests a private method, borrowed from older Angular / Backbone conventions. In React handler land, plain `handleSendEmail` is idiomatic. Cosmetic.

#### L2 — `<html lang>` not set

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/pages/_document.tsx:3`

`<Html>` from `next/document` defaults to `<html>` with no `lang` attribute. Screen readers need `lang="en"` to pronounce content correctly. Add `<Html lang="en">`. (Pages Router — in App Router this lives in `app/layout.tsx`.)

#### L3 — Two icon libraries

`lucide-react` (blog-card, sheet, button) and `react-icons/fa` + `react-icons/bi` (footer, social-links, scroll-to-top) are both in the bundle. They're tree-shakeable so the cost is small, but consolidating onto one (lucide has equivalents for all the `react-icons` used) would remove a dependency and a stylistic split.

#### L4 — AOS animations not gated behind `prefers-reduced-motion`

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/pages/_app.tsx:29-31`

```ts
useEffect(() => { AOS.init(); }, []);
```

AOS does ship with a `disableMutationObserver` option but not a built-in reduced-motion gate. Users who set "reduce motion" in their OS still get fade/slide animations. Wrap: `AOS.init({ disable: window.matchMedia('(prefers-reduced-motion: reduce)').matches })`. WCAG 2.3.3.

#### L5 — `Space_Grotesk` loaded but never applied to wrapper class

**Location:** `/home/nurmdrafi/Desktop/MyProject/my-portfolio/pages/_app.tsx:14`

Same pattern as M7 — flows through `--font-space-grotesk` CSS var. Verify it's actually consumed somewhere (grep `var(--font-space-grotesk)` across `components/` and `styles/`); if not, remove the font load to save ~30KB of woff2.

---

### Informational

| # | Observation | File:Line |
|---|---|---|
| I1 | No `localStorage` / `sessionStorage` use anywhere — good (no token storage surface) | project-wide |
| I2 | No `eval`, `new Function`, or string-set `setTimeout` — good | project-wide |
| I3 | `meta.tsx:64` uses `dangerouslySetInnerHTML` but with `JSON.stringify` of a static object literal — safe (no user input) | `components/common/meta.tsx:64` |
| I4 | All external links use `rel="noopener noreferrer"` — good | `blog-card.tsx`, `social-links.tsx`, `client-logo.tsx` |
| I5 | No credentials, API tokens, or PII in source — `.env` not committed | project-wide |
| I6 | `react-hook-form` correctly typed via `useForm<FormValues>()` — good TS hygiene | `components/contact/index.tsx:21` |
| I7 | `ScrollToTop` correctly cleans up its scroll listener and uses `requestAnimationFrame` throttling — exemplary | `components/common/scroll-to-top.tsx:15-28` |

---

## What's Done Well

**Security**
- Zero `localStorage` / `sessionStorage` use (`rg` returned no matches across `components/`, `pages/`, `lib/`) — no client-side secret storage surface.
- No `eval`, `new Function`, `document.write`, or string-argument `setTimeout`.
- The only `dangerouslySetInnerHTML` (`components/common/meta.tsx:64`) serializes a static JSON-LD object — no user input reaches it.
- Every external link carries `rel="noopener noreferrer"` (`components/blog/blog-card.tsx:11`, `components/banner/social-links.tsx:6,16,25,34,43,52`, `components/customers/client-logo.tsx:6`).
- `.env` files are not committed (no `.env` in the file inventory).

**Architecture**
- Clean per-section folder structure: each `components/<section>/` has a colocated `data.ts(x)` and `index.tsx` (`components/skills/`, `components/timeline/`, `components/blog/`, `components/customers/`, `components/contact/`).
- Path alias `@/` consistently used for non-relative imports (`@/components/ui/...`, `@/lib/utils`).
- shadcn/ui primitives correctly wrapped as thin adapters in `components/ui/` (`button.tsx`, `card.tsx`, `sheet.tsx`, `input.tsx`, `textarea.tsx`, `label.tsx`) — not edited in place.
- Single responsibility per section file — no god-components.

**Code Quality**
- `react-hook-form` correctly typed end-to-end via `useForm<FormValues>()` with `interface FormValues` (`components/contact/index.tsx:13, 21`).
- `ScrollToTop` is a model for listener hygiene: `useCallback`-stabilized handler, `requestAnimationFrame` throttle, correct `removeEventListener` cleanup (`components/common/scroll-to-top.tsx:11-28`).
- No empty `catch` blocks anywhere in the codebase.
- No `@ts-ignore`, `@ts-nocheck`, or `@ts-expect-error` directives (`rg` returned no matches).
- Single `// eslint-disable` (`react/no-unescaped-entities` at `components/about/index.tsx:1`) — narrowly scoped to one file, justified by apostrophe usage.

**Accessibility**
- Every icon-only social link has a descriptive `aria-label` (`components/banner/social-links.tsx:6,16,25,34,43,52`).
- Navbar wrapped in `<nav aria-label="Main navigation">` (`components/navbar/index.tsx:16`).
- Mobile Sheet has a visually-hidden `<SheetTitle className="sr-only">Navigation Menu</SheetTitle>` (`components/navbar/small-navbar.tsx:28`) — many shadcn Sheet users skip this and break the dialog's accessible name.
- Decorative logo image in `full-name.tsx:37` correctly uses `alt=""` (empty alt = decorative).
- All informative images use descriptive `alt`: `about/index.tsx:29` (`alt="Nur Mohamod Rafi"`), `blog-card.tsx:24` (`alt={post.title}`), `client-logo.tsx:16` (`alt={\`${name} logo\`}`), `navbar/index.tsx:19` (`alt="Nur Mohamod Rafi logo"`).
- All form inputs set `aria-invalid={!!errors.<field>}` (`contact/index.tsx:70, 101, 133`).
- Heading hierarchy is clean: single `<h1>` in `banner/full-name.tsx:9`, section `<h2>`s in `common/heading.tsx:17`, item `<h3>`s in `blog-card.tsx:43` and `timeline/index.tsx:108`.

---

## Priority Actions

### Immediate (this week)
1. **Upgrade Next.js** off 13.4.7 to the latest patched release. Address C1.
2. **Add accessible labels to the three contact-form fields** (visible `<Label>` or `aria-label`). Address H1.
3. **Wire `aria-describedby` + `role="alert"` to error paragraphs** in the contact form. Address H2.
4. **Show a failure toast in the contact `catch` block and stop resetting the form on error.** Address H3.

### Short-Term (next 2 weeks)
5. Replace `response: any` / `error: any` with proper types and `catch (error: unknown)` narrowing. Address M1.
6. Add `aria-hidden="true"` to the footer wave SVG. Address M2.
7. Gate the `Card3D` tilt and `AOS.init()` behind `prefers-reduced-motion`. Address M3 and L4.
8. Rename `NEXT_PUBLIC_EMAILJS_API_KEY` → `NEXT_PUBLIC_EMAILJS_PUBLIC_KEY` and add an "Allowed Origins" restriction in the EmailJS dashboard. Address M4.

### Medium-Term (next month)
9. Extract a shared `<Layout>` component and refactor `pages/index.tsx` + `pages/blog.tsx` to use it. Address M5.
10. Add `<Html lang="en">` to `_document.tsx`. Address L2.
11. Consolidate onto one icon library (recommend lucide-react). Address L3.
12. Audit whether `Space_Grotesk` is actually consumed via the CSS var; remove if not. Address L5.

### Backlog
13. Document the `Prospec` font flow (M7) and the `MouseEnterContext` colocation decision (M6) with inline comments so future maintainers don't "clean them up".

---

## Methodology

| Step | Tool | Scope |
|---|---|---|
| Inventory | `rg --files`, `find ... wc -l`, `cat package.json` via `ctx_batch_execute` | 45 source files, ~2,983 LoC |
| Pattern analysis (security) | `rg` (host shell) for `eval`, `innerHTML`, `localStorage`, secrets, `emailjs`, `NEXT_PUBLIC_*`, external-link attrs | `components/`, `pages/`, `lib/` |
| Pattern analysis (architecture) | `rg` for imports, exports, context, interfaces, `forwardRef`, `memo`, `lazy` | `components/`, `pages/`, `lib/` |
| Pattern analysis (quality) | `rg` for functions, `console.*`, `TODO/FIXME`, empty catch, `any`, `@ts-*`, async patterns, hooks, listeners | `components/`, `pages/`, `lib/` |
| Pattern analysis (a11y) | `rg` for `<button>`, `<input>`, `<img>`, `aria-*`, `role=`, `alt=`, `tabIndex`, focus, `outline-none` | `components/`, `pages/` |
| Doc/CVE verification | `WebSearch` for "Next.js 13.4.7 CVE 2024 2025" | Confirmed C1 |
| Hotspot deep-read | `ctx_batch_execute` (15-file `cat` batch, concurrency 8, auto-indexed + `ctx_search` retrieval) | 15 hotspot files, single pass |

**Scope:** Path scope — `/home/nurmdrafi/Desktop/MyProject/my-portfolio`.
**Domains:** Security, Architecture, Code Quality, Accessibility.
**Hotspot files deep-read (15):** `components/contact/index.tsx`, `components/timeline/index.tsx`, `components/common/card-3d.tsx`, `components/about/index.tsx`, `components/blog/blog-card.tsx`, `components/common/meta.tsx`, `components/common/footer.tsx`, `components/banner/social-links.tsx`, `components/common/scroll-to-top.tsx`, `pages/_app.tsx`, `pages/index.tsx`, `components/navbar/menu-items.tsx`, `components/banner/full-name.tsx`, `components/customers/client-logo.tsx`, `lib/utils.ts`.

---

## Sources

- [NVD — CVE-2025-29927 (Next.js middleware auth bypass)](https://nvd.nist.gov/vuln/detail/CVE-2025-29927)
- [Next.js Blog — CVE-2025-66478 (RSC RCE)](https://nextjs.org/blog/CVE-2025-66478)
- [Vercel Changelog — CVE-2025-55182 (React RSC RCE / "React2Shell")](https://vercel.com/changelog/cve-2025-55182)
- [Next.js Blog — Security Update 2025-12-11](https://nextjs.org/blog/security-2025-12-11)
- [Google Cloud Blog — Responding to CVE-2025-55182](https://cloud.google.com/blog/products/identity-security/responding-to-cve-2025-55182)
