# Codebase Analysis Report — `portfolio-next`

**Project:** Nur Mohamod Rafi personal portfolio (`portfolio-next`, v1.0.0)
**Date:** 2026-06-13
**Scope:** Full repository (`.`), all source files excluding `node_modules`, `.next`, `out`, `dist`, `build`, `.git`, `*.min.{js,css}`, `public/images`
**Domains reviewed:** Security, Architecture, Code Quality, Accessibility
**Tech stack:** Next.js 13.4.7 (Pages Router), TypeScript 5.1.3 (strict), React 18.2.0, Tailwind CSS v4, shadcn/ui (@base-ui/react), Framer Motion 11, AOS, react-hook-form 7.45, @emailjs/browser 3.11, react-hot-toast 2.4, lucide-react, react-icons
**Files scanned:** 45 source files, ~2,472 lines of code
**Hotspot files deep-read (8):** `components/contact/index.tsx`, `components/common/meta.tsx`, `components/common/scroll-to-top.tsx`, `components/navbar/use-scroll-state.ts`, `components/about/index.tsx`, `components/banner/social-links.tsx`, `components/navbar/menu-items.tsx`, `components/customers/client-logo.tsx`
**Tools used:** ripgrep 14.1.1 (pattern search), context-mode FTS5 index (evidence store), Context7 (`/emailjs-com/emailjs-sdk` for EmailJS abuse-prevention docs)

---

## Executive Summary

- **Security:** The codebase is largely clean — no `localStorage`/`sessionStorage`/`eval`/hardcoded secrets. The one substantive issue is that the contact form exposes EmailJS's public API key (correctly, via `NEXT_PUBLIC_*`) but does **not** enable EmailJS's built-in abuse protections (`blockHeadless`, `blockList`, `limitRate`), leaving a publicly-bundled key vulnerable to scripted abuse. The `dangerouslySetInnerHTML` site in `meta.tsx` is verified to inject only static JSON-LD — no XSS path.
- **Architecture:** Well-structured Pages Router app with thin composition root (`pages/index.tsx`, 31 lines), per-section `index.tsx` entry points, consistent `export default`, and a correctly-cleaned custom scroll hook. Minor: two `any` type escapes in the contact form.
- **Quality:** Clean of `TODO`/`FIXME`/`HACK` markers. One stray `console.log(error.text)` in the contact form error handler ships to production. Listener cleanup is correct everywhere it appears. One file-scoped `eslint-disable`.
- **Accessibility:** Strong baseline — every social link, client logo, scroll-to-top button, and nav landmark has aria-label/alt text; the mobile sheet has an `sr-only` `SheetTitle`. Gaps: no `aria-live` region for the toast notifications (react-hot-toast default `Toaster` is not announced to screen readers), no `aria-describedby` on the three contact form inputs to programmatically associate the inline error messages, and the mobile menu trigger Button has no `aria-label`.

---

## Findings by Severity

### Critical

None.

---

### High

#### H1 — Contact form exposes a public EmailJS key with no abuse protection (Security — A04 Insecure Design / A05 Security Misconfiguration)

| Field | Value |
|---|---|
| File | `components/contact/index.tsx:26-31` |
| OWASP | A04 Insecure Design, A05 Security Misconfiguration |
| Evidence | `const response: any = await emailjs.sendForm(\n  \`${process.env.NEXT_PUBLIC_EMAILJS_SERVICE_ID}\`,\n  \`${process.env.NEXT_PUBLIC_EMAILJS_TEMPLATE_ID}\`,\n  form.current!,\n  \`${process.env.NEXT_PUBLIC_EMAILJS_API_KEY}\`\n);` |

**Impact.** `NEXT_PUBLIC_*` vars are inlined into the client bundle by design — every visitor receives the EmailJS public key, service ID, and template ID. EmailJS's public key is *intended* to be public, but without the SDK's abuse-protection options enabled, anyone who scrapes the key can script unlimited `sendForm` POSTs against the EmailJS service, exhausting the monthly quota (free tier: 200 emails/month) or flooding the owner's inbox within minutes. Verified against EmailJS SDK docs via Context7: the SDK exposes `blockHeadless` (rejects headless browsers, returns 451), `blockList` (rejects specified addresses, returns 403), and `limitRate: { throttle: <ms> }` (returns 429) — none are used here.

**Fix.** Configure these options either globally via `emailjs.init({...})` in `pages/_app.tsx` (after the existing `AOS.init()`) or per-call as the 4th argument object:
```ts
emailjs.sendForm(
  serviceId, templateId, form.current,
  {
    publicKey: process.env.NEXT_PUBLIC_EMAILJS_API_KEY!,
    blockHeadless: true,
    blockList: { watchVariable: 'email' }, // block submitter emails you want to refuse
    limitRate: { id: 'contact-form', throttle: 60_000 }, // 1 submission per minute
  }
);
```
Also enable EmailJS dashboard-side protections: allowed origins (your domain only), monthly quota cap with email alerts.

---

### Medium

#### M1 — Toast notifications have no live region (A11y — WCAG 2.1 AA, 4.1.3 Status Messages)

| Field | Value |
|---|---|
| File | `components/contact/index.tsx` (Toaster usage; `toast(...)` at line 34) |
| WCAG | 4.1.3 Status Messages (Level AA) |
| Evidence | `import toast, { Toaster } from "react-hot-toast";` — success toast fires after form submission. `<Toaster />` is rendered at the section root; default react-hot-toast container does **not** set `role="status"` / `aria-live="polite"` on its children by default. |

**Impact.** Screen-reader users get no audible confirmation that the form was submitted successfully — they only see the form reset. Same for any future error toasts.

**Fix.** Configure the Toaster with an explicit aria-live region. react-hot-toast supports this via `Toaster` props:
```tsx
<Toaster
  position="bottom-center"
  ariaProps={{ role: "status", "aria-live": "polite" }}
/>
```
(The `toast.success(...)`/`toast.error(...)` variants are preferred over the generic `toast(...)` so the role/announcement is semantically correct.)

---

#### M2 — Contact form error messages not programmatically associated with inputs (A11y — WCAG 2.1 AA, 3.3.1 Error Identification / 4.1.3 Status Messages)

| Field | Value |
|---|---|
| Files | `components/contact/index.tsx:67-72` (name), `98-103` (email), `130-135` (message) — inputs use `aria-invalid={!!errors.<field>}` but no `aria-describedby` |
| WCAG | 3.3.1 Error Identification (Level A), 3.3.3 Error Suggestion (Level AA) |
| Evidence | The inputs correctly set `aria-invalid` when validation fails, and there is a visible error paragraph (`<p>` with the error text) below each input, but the `<p>` has no `id` and the input has no `aria-describedby` pointing to it. |

**Impact.** Screen readers announce that the field is invalid but do not announce *what* the error is — the visible error text is read only if the user manually navigates to it.

**Fix.** Give each error `<p>` a stable `id` and link it:
```tsx
<input id="name" aria-invalid={!!errors.name} aria-describedby="name-error" {...} />
{errors.name && <p id="name-error" role="alert">{errors.name.message}</p>}
```

---

#### M3 — Mobile menu trigger has no accessible name (A11y — WCAG 2.1 AA, 4.1.2 Name, Role, Value)

| Field | Value |
|---|---|
| File | `components/navbar/small-navbar.tsx:20-26` |
| WCAG | 4.1.2 Name, Role, Value (Level A) |
| Evidence | `<SheetTrigger render={<Button variant="ghost" size="icon-sm" className="text-primary" />}><MenuIcon /></SheetTrigger>` — the trigger is an icon-only button with no `aria-label`. |

**Impact.** Screen-reader users encounter an unnamed button in the small-screen navbar. The `SheetTitle` inside (`sr-only` "Navigation Menu") is good for the dialog itself but does not name the trigger.

**Fix.** Add `aria-label` to the Button:
```tsx
<SheetTrigger render={
  <Button variant="ghost" size="icon-sm" className="text-primary" aria-label="Open navigation menu" />
}>
```

---

### Low

#### L1 — `console.log(error.text)` ships to production (Quality — Debug leftover)

| Field | Value |
|---|---|
| File | `components/contact/index.tsx:43` |
| Evidence | `} catch (error: any) {\n  console.log(error.text);\n} finally { reset(); }` |

**Impact.** EmailJS error text (potentially including service IDs, response codes, or internal EmailJS error strings) is logged to the browser console in production. Minor information leak and noise; bypasses the user-facing toast flow (the catch logs but never `toast.error`s, so the user gets no feedback that submission failed).

**Fix.** Remove the `console.log`, add a user-facing error toast, and narrow the `any` type:
```tsx
} catch (error) {
  toast.error("Sorry — something went wrong. Please try again or email me directly.");
  if (process.env.NODE_ENV !== 'production') console.error('EmailJS error:', error);
}
```

---

#### L2 — Two `any` type escapes in the contact form (Architecture / Quality — TypeScript strict bypass)

| Field | Value |
|---|---|
| File | `components/contact/index.tsx:26` (`const response: any`), `:42` (`catch (error: any)`) |
| Evidence | `const response: any = await emailjs.sendForm(...)` — the project is configured for TS strict mode but the EmailJS response and error are typed `any`, losing all type safety on the call. |

**Impact.** The `response` variable is checked only for truthiness (`if (response) { toast(...) }`) and then discarded — the `any` is essentially unused. The `error: any` forces `.text` access without compile-time guarantees.

**Fix.** `@emailjs/browser` v3.11 exports `EmailJSResponseStatus`. Type the response as `EmailJSResponseStatus` and the error as `unknown` with a runtime narrowing:
```tsx
import emailjs, { EmailJSResponseStatus } from "@emailjs/browser";
const response: EmailJSResponseStatus = await emailjs.sendForm(...);
// ...
} catch (error: unknown) {
  const text = error && typeof error === 'object' && 'text' in error ? String((error as { text: unknown }).text) : 'unknown';
  // ...
}
```

---

#### L3 — File-scoped `eslint-disable react/no-unescaped-entities` (Quality — Lint suppression)

| Field | Value |
|---|---|
| File | `components/about/index.tsx:1` |
| Evidence | `/* eslint-disable react/no-unescaped-entities */` at the top of the file. |

**Impact.** Disables the rule for the whole file rather than per-line. The rule exists to catch unescaped `'`/`"` in JSX text that React renders as a string but can confuse tooling.

**Fix.** Either (a) replace the file-scoped directive with per-line `// eslint-disable-next-line react/no-unescaped-entities` on the specific JSX lines that contain apostrophes, or (b) escape the literal apostrophes (`it's` → `it&apos;s` or `it&rsquo;s`). Option (b) is preferable because it removes the directive entirely.

---

#### L4 — Heavy skills list not memoized (Architecture / Quality — Unnecessary re-renders)

| Field | Value |
|---|---|
| File | `components/skills/data.tsx` (215 lines, 40+ skill icon entries), `components/skills/index.tsx` |
| Evidence | `data.tsx` exports 40+ inline JSX `<Icon>` elements. The `Skills` component at `components/skills/index.tsx` renders them directly. `React.memo` is used **nowhere** in the codebase (confirmed by rg). |

**Impact.** Since the parent `pages/index.tsx` re-renders on every scroll-driven `activeSection` state change from `useScrollState()` (the hook fires on every IntersectionObserver callback), the 40+ icon elements re-render on each section change unless React bails out by prop equality. Icons are stable but the cost compounds.

**Fix.** Wrap the `Skills` (and `Customers`, `Blog`) section components in `React.memo`, or move the `useScrollState` subscription to a context so only the navbar re-renders. Lowest-effort option:
```tsx
// components/skills/index.tsx
function SkillsImpl() { /* existing body */ }
export default React.memo(SkillsImpl);
```

---

#### L5 — `aria-current="page"` not used on in-page nav links (A11y — WCAG 2.1 AA, 1.3.1 Info and Relationships)

| Field | Value |
|---|---|
| File | `components/navbar/menu-items.tsx:47` (href rendering) — consumes `activeSection` but doesn't apply `aria-current` |
| WCAG | 1.3.1 Info and Relationships (Level A), 2.4.8 Location (Level AAA) |
| Evidence | The `MenuItems` component receives `activeSection` from the `useScrollState` hook and applies a visual active style (presumably via `cn(...)`), but the matching `<a>` / `<Link>` does not set `aria-current="location"` for screen readers. |

**Impact.** Sighted users see which section is active via styling; screen-reader users do not get an equivalent programmatic indicator.

**Fix.** On each in-page nav anchor:
```tsx
<a href={href} aria-current={activeSection === id ? 'location' : undefined} ...>
```

---

### Informational

#### I1 — `dangerouslySetInnerHTML` is used but is safe (Security — Verified no XSS)

| Field | Value |
|---|---|
| File | `components/common/meta.tsx:49-68` |
| Evidence | `<script type='application/ld+json' dangerouslySetInnerHTML={{ __html: JSON.stringify({ '@context': 'https://schema.org', '@type': 'Person', name: 'Nur Mohamod Rafi', url: siteUrl, ... }) }} />` |

**Verdict.** The `__html` value is the output of `JSON.stringify` on a literal schema.org `Person` object with hardcoded string URLs and the `description` prop. There is no user-derived input flowing into the serialized object, so there is no XSS injection vector. `JSON.stringify` also escapes `<`/`>` by default, which would neutralize a `</script>` breakout even if the data were partially dynamic. No action required — kept in the report as a documented audit of the flagged pattern.

---

#### I2 — Tailwind v4 CSS-first config is correctly set up (Architecture — Positive observation)

| Field | Value |
|---|---|
| File | `package.json` (`tailwindcss: 4.1.3`, `@tailwindcss/postcss: 4.1.3`), `styles/globals.css`, `postcss.config.js` |

The project follows the documented Tailwind v4 setup (PostCSS plugin, CSS-first `:root` theme tokens, no `tailwind.config.ts`). Matches the convention recorded in `CLAUDE.md`.

---

#### I3 — IntersectionObserver and scroll listeners are correctly cleaned up (Quality — Positive observation)

| Field | Value |
|---|---|
| Files | `components/navbar/use-scroll-state.ts:29` (`return () => observer.disconnect();`), `components/common/scroll-to-top.tsx:27-28` (`{ passive: true }` + `removeEventListener` cleanup) |

Both effects subscribe to browser events in `useEffect` and unsubscribe in the returned cleanup function. The scroll listener is registered with `{ passive: true }`, which is best practice for non-preventable scroll handlers. No memory leak.

---

## What's Done Well

**Security**
- No `localStorage`/`sessionStorage` usage anywhere in the source (rg-confirmed) — nothing sensitive is persisted client-side.
- No `eval()`, no `new Function()`, no `Function()` constructor usage.
- No hardcoded credentials in source. The EmailJS key is referenced via `process.env.NEXT_PUBLIC_*` rather than written as a string literal (correct for a key intended to be public).
- `pages/_document.tsx` and `pages/_app.tsx` do not expose any debug or admin surface.

**Architecture**
- `pages/index.tsx` (31 lines) is a textbook composition root: Meta → Hero → Banner → About → Skills → Timeline → Customers → Blog → Contact → Footer. No business logic leaks into the page component.
- Every section folder (`about/`, `banner/`, `contact/`, `hero/`, `navbar/`, `skills/`, `customers/`, `common/`, `ui/`, `timeline/`, `blog/`) has an `index.tsx` entry point with `export default`, matching the documented convention. No circular exports detected.
- `useScrollState` (`components/navbar/use-scroll-state.ts`) is a clean extracted custom hook — single responsibility (active-section tracking), reusable across `LargeNavbar` and `SmallNavbar`.
- Async code uses `async`/`await` consistently — no `.then()` pyramid chains.
- `@/*` path alias is used for cross-folder imports (`@/components/ui/card`, `@/lib/utils`); relative imports are reserved for sibling modules. Clean layering.

**Quality**
- Zero `TODO`/`FIXME`/`HACK`/`XXX` markers in source.
- TypeScript strict mode is enabled; only 2 `any` escapes in the entire codebase (both in the contact form).
- `react-hook-form` is used for the contact form, which provides proper controlled-input state, validation, and `reset()` semantics without manual state plumbing.
- AOS, Framer Motion, and react-hot-toast are integrated correctly and only where they add value.
- Semantic HTML throughout: `<section>`, `<nav aria-label>`, `<form>`, `<button type="submit">`, no `<div onClick>` anti-patterns.

**Accessibility**
- Every social link anchor in `components/banner/social-links.tsx:13-58` has a descriptive `aria-label` ("GitHub profile", "Medium blog", "LinkedIn profile", etc.) — icon-only buttons are named.
- `components/common/scroll-to-top.tsx:38` — icon-only button has `aria-label="Scroll to top"`.
- `components/banner/full-name.tsx:37` — decorative image correctly uses `alt=""` (hides from AT).
- All 40+ skill icons in `components/skills/data.tsx` get a meaningful `alt` via the `Icon` helper.
- `components/about/index.tsx:29` — profile photo has `alt="Nur Mohamod Rafi"`.
- `components/customers/client-logo.tsx:8,16` — both the anchor and image get dynamically-generated accessible names.
- `components/blog/blog-card.tsx:24` and `components/timeline/index.tsx:103` — meaningful `alt` text on imagery.
- `components/navbar/index.tsx:16` — `<nav aria-label="Main navigation">` correctly disambiguates the nav landmark.
- `components/navbar/small-navbar.tsx:28` — mobile Sheet has `<SheetTitle className="sr-only">Navigation Menu</SheetTitle>`, giving the dialog an accessible name (commonly missed).
- Contact form inputs use `aria-invalid={!!errors.<field>}` to flag invalid fields.

---

## Priority Actions

### Immediate (this sprint)
1. **H1** — Add EmailJS abuse protections (`blockHeadless`, `blockList`, `limitRate`) to the contact form's `sendForm` call and configure allowed origins in the EmailJS dashboard.
2. **M1** — Configure `<Toaster ariaProps={{ role: "status", "aria-live": "polite" }} />` so submission feedback is announced.
3. **M3** — Add `aria-label="Open navigation menu"` to the mobile menu trigger Button.

### Short-Term (next 2 weeks)
4. **M2** — Add `id`/`aria-describedby` linking between contact form inputs and their error `<p>` tags.
5. **L1** — Remove `console.log(error.text)`, replace with a user-facing error toast and gated dev-only logging.
6. **L5** — Apply `aria-current="location"` to the active in-page nav link in `menu-items.tsx`.

### Medium-Term (next month)
7. **L2** — Type the EmailJS response as `EmailJSResponseStatus` and the catch as `unknown`.
8. **L4** — Wrap `Skills`, `Customers`, and `Blog` section components in `React.memo` to prevent re-renders from `activeSection` state churn.

### Backlog
9. **L3** — Replace the file-scoped `eslint-disable` in `about/index.tsx` with escaped entities or per-line directives.

---

## Methodology

| Step | Description |
|---|---|
| Inventory | Listed 45 source files via `rg --files`; identified top hotspots by LoC via `find + wc -l`. |
| Pattern analysis | Ran 4 domain-specific `rg` commands verbatim (security, architecture, quality, a11y) covering the full repo with the fallback exclusion set. Each command's output was indexed for search. |
| Hotspot deep-dive | Single-pass read of 8 highest-signal files via sandboxed `ctx_execute_file` — only the requested domains' checks ran, only the derived signals entered context. |
| Doc verification | Queried Context7 `/emailjs-com/emailjs-sdk` to verify the EmailJS SDK exposes `blockHeadless`/`blockList`/`limitRate` options and confirmed the public key is intended to be public. |
| Scope | Full repository (`.`), all requested domains. No fallow / ast-grep runs (neither flag passed; both tools skipped). |
