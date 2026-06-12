# Codebase Analysis Report: [project-name]

**Date:** 2026-01-15
**Stack:** Next.js App Router · TypeScript · Tailwind CSS · UI Component Library · Redux Toolkit + RTK Query · NextAuth.js · react-hook-form + zod
**Agents:** security-reviewer, architecture-reviewer, code-quality-reviewer, accessibility-reviewer

---

## Executive Summary

**Security:** Critical vulnerabilities in authentication secrets, client-side encryption, and missing server-side route protection. Solid fundamentals (no XSS vectors, proper JWT strategy, auth token refresh).

**Architecture:** Clean server/client boundary and RTK Query patterns, but carries technical debt in duplicated data-fetching paths, oversized config file, and category state duplication.

**Code Quality:** Good foundational patterns with strong type safety (only 3 `any` usages), but significant copy-paste duplication in coupon logic, ~20 debug `console.log` statements, and a broken price filter.

**Accessibility:** Significant WCAG 2.1 AA gaps — 92% of buttons missing accessible names, 100% of custom form inputs without labels, no skip links, no `<main>` landmark, no `aria-live` regions.

---

## Critical (7)


| # | Agent | Issue | Location |
|---|-------|-------|----------|
| 1 | Security | **Weak AUTH_SECRET** — Human-guessable string allows JWT forgery | `.env:2` |
| 2 | Security | **Encryption key exposed to browser** via `NEXT_PUBLIC_ENCRYPTED_KEY` — phone encryption is security theater | `config/app.config.ts:2` |
| 3 | Security | **No server-side route protection** — No `middleware.ts`, protected routes render without auth | Project root (missing) |
| 4 | Security | **Open redirect via `callbackUrl`** — Unvalidated query param passed to `router.push()` | `LoginForm.tsx:39,76,85,92` |
| 5 | A11y | **No skip link or `<main>` landmark** — Keyboard/screen reader users cannot bypass navigation | `app/(root)/layout.tsx` |
| 6 | A11y | **All auth form inputs lack labels** — 56 inputs across login, registration, OTP, forgot-password have no visible labels or `aria-label` | `components/auth/` |
| 7 | A11y | **97 buttons without accessible names (92%)** — Screen readers announce "button" with no context | `components/` globally |

### Details

**1. Weak AUTH_SECRET**
- **OWASP:** A02:2021 – Cryptographic Failures
- **Evidence:** `AUTH_SECRET=example-insecure-secret-value`
- **Impact:** An attacker who guesses this can forge session tokens, impersonate any user, bypass all auth.
- **Fix:** Generate with `openssl rand -base64 48`. Rotate immediately.

**2. Encryption Key Exposed to Browser**
- **OWASP:** A02:2021, A05:2021
- **Evidence:** `NEXT_PUBLIC_ENCRYPTED_KEY` is bundled into client-side JS. Used in `LoginForm.tsx`, `ForgotPasswordForm.tsx`, `PhoneUpdateModal.tsx`.
- **Impact:** Attacker can decrypt/forge encrypted phone numbers, trigger OTPs on arbitrary numbers.
- **Fix:** Move encryption to server-side API route. Remove `NEXT_PUBLIC_` prefix.

**3. No Server-Side Route Protection**
- **OWASP:** A01:2021 – Broken Access Control
- **Evidence:** `lib/routes.ts` defines `PROTECTED_ROUTE_PREFIXES` but only used client-side. No `middleware.ts` at project root.
- **Impact:** Protected pages (`/checkout`, `/orders`, `/profile`) render without auth — server renders before client redirect.
- **Fix:** Create `middleware.ts` with auth middleware enforcing auth at the edge.

**4. Open Redirect via `callbackUrl`**
- **OWASP:** A01:2021 – Broken Access Control
- **Evidence:** `const callbackUrl = searchParams.get("callbackUrl"); router.push(callbackUrl);` — No validation. Also passed to `signIn("google", { callbackUrl })`.
- **Fix:** Validate same-origin before redirect:
  ```typescript
  const safeCallbackUrl = (url: string | null): string => {
    if (!url) return "/";
    try {
      const parsed = new URL(url, window.location.origin);
      if (parsed.origin === window.location.origin) return parsed.pathname + parsed.search;
    } catch { /* invalid URL */ }
    return "/";
  };
  ```

**5. No Skip Link or Main Landmark**
- **WCAG:** 2.4.1 Bypass Blocks (A), 1.3.1 Info & Relationships (A)
- **Evidence:** `app/(root)/layout.tsx` wraps content in `<div>`, no skip link, no `<main>` element anywhere.
- **Impact:** Keyboard/screen reader users must tab through entire Header on every page.
- **Fix:**
  ```tsx
  <a href="#main-content" className="sr-only focus:not-sr-only focus:absolute focus:z-50 ...">
    Skip to main content
  </a>
  <Header />
  <main id="main-content">{children}</main>
  ```

**6. All Auth Form Inputs Lack Labels**
- **WCAG:** 1.3.1, 3.3.2 (A)
- **Evidence:** 56 of 56 custom `<Input>` components (100%) lack `aria-label` or `aria-labelledby`. Auth forms bypass form library `FormField` which handles this.
- **Impact:** Screen reader users cannot identify input purpose.
- **Fix:** Migrate auth forms to `FormField` + `FormItem` + `FormLabel`, or add `aria-label` to each input.

**7. 97 Buttons Without Accessible Names**
- **WCAG:** 4.1.2 Name, Role, Value (A)
- **Evidence:** ProductView.tsx alone has 13 unnamed buttons. Includes icon buttons, toggle buttons, close buttons.
- **Impact:** Screen reader users hear "button" with no context. Voice control users cannot target buttons.
- **Fix:** Add `aria-label` to all icon-only and ambiguous buttons.

---

## High (16)

| # | Agent | Issue | Location |
|---|-------|-------|----------|
| 8 | Security | **reCAPTCHA site key hardcoded as fallback** in config | `config/app.config.ts:3` |
| 9 | Security | **No CSRF protection** on mutation endpoints | `apiSlice.ts` |
| 10 | Security | **No CSP, HSTS, X-Frame-Options** or any security headers | `next.config.ts` |
| 11 | Security | **Payment gateway redirects not validated** — 15+ `window.location.href = <variable>` | `PaymentForm.tsx` |
| 12 | Arch | **Dual data-fetching paths** — `lib/api/` server fetch and RTK Query for same endpoints | `lib/api/category.ts`, `lib/api/product.ts` vs Redux slices |
| 13 | Arch | **Config file 386 lines** — monolithic config mixing routes, payments, constants | `config/app.config.ts` |
| 14 | Arch | **Category slice duplicates RTK Query cache** — same data in manual slice and RTK Query | `categorySlice.ts` |
| 15 | Code | **Coupon logic triplicated** across 3 summary card components | `CheckoutSummary.tsx`, `PaymentSummary.tsx`, `CartSummary.tsx` |
| 16 | Code | **~20 debug `console.log` statements** in production components | `PaymentForm.tsx`, `ProductDetails.tsx`, etc. |
| 17 | Code | **`useFilteredProducts` broken price filter** — commented out with active TODO | `useFilters.ts:71` |
| 18 | A11y | **Form errors not linked to inputs** via `aria-describedby` | Auth forms, checkout address |
| 19 | A11y | **OTP input has no label** and 2 buttons without aria-label | `OTPVerification.tsx` |
| 20 | A11y | **13 buttons in ProductView.tsx** have no accessible names | `ProductView.tsx` |
| 21 | A11y | **FAQ accordion missing `aria-controls`** | `FAQAccordion.tsx` |
| 22 | A11y | **Checkout progress not indicated** accessibly — no `aria-current="step"` | `PaymentForm.tsx` |
| 23 | A11y | **Hero carousel autoplay without pause control** | `HeroCarousel.tsx` |

### Details

**8. Hardcoded reCAPTCHA Site Key**
- **OWASP:** A05:2021 – Security Misconfiguration
- **Fix:** Remove hardcoded fallback. Fail at build time if env var is missing.

**9. No CSRF Protection**
- **OWASP:** A01:2021 – Broken Access Control
- Bearer token auth mitigates partially, but defense-in-depth is missing.
- **Fix:** Add `X-Requested-With` header to mutations at minimum.

**10. No Security Headers**
- **OWASP:** A05:2021 – Security Misconfiguration
- **Fix:** Add CSP, HSTS, X-Frame-Options, X-Content-Type-Options in `next.config.ts` `headers()`.

**11. Unvalidated Payment Redirects**
- **Fix:** Validate redirect URLs against allowlist of known payment gateway domains.

**12. Dual Data-Fetching Paths**
- `lib/api/category.ts` imports `fetchCategoryPageData` from Redux slice — awkward cross-layer dependency.
- **Fix:** Move server-side fetch helpers out of Redux files into `lib/api/` as self-contained functions.

**13. Monolithic Configuration File**
- Config contains every API route, payment config, search constants.
- **Fix:** Split into `config/routes.auth.ts`, `config/routes.product.ts`, `config/routes.payment.ts`, `config/app.ts`.

**14. Category Slice Duplicates RTK Query Cache**
- `categorySlice.ts` stores `currentCategory`, `banners`, `brands`, `categoryProducts`, etc. — all available via RTK Query.
- **Fix:** Keep slice only for UI state (`selectedFilters`, `selectedSort`, `pagination`). Remove data duplication.

**15. Coupon Logic Triplicated**
- Apply/remove coupon and reward points handlers nearly identical across 3 files.
- **Fix:** Extract `useCouponActions(cartId, onRefresh?)` hook.

**16. Debug console.log Statements**
- Key locations: `PaymentForm.tsx:307,459,517`, `ProductDetails.tsx:539,554`, `PaymentSelector.tsx:169`, `useFilters.ts:76`
- **Fix:** Remove all `console.log`. Keep `console.error` only for actual error monitoring.

**17. Broken Price Filter**
- Filter commented out with TODO. `console.log` fires every render.
- **Fix:** Investigate `product_price` field mismatch with API response. Fix or remove dead parameter.

---

## Medium (25)

| # | Agent | Issue | Location |
|---|-------|-------|----------|
| 24 | Security | **Access token in JWT accessible client-side** via `session.accessToken` | `lib/auth.ts` session callback |
| 25 | Security | **PBKDF2 with only 999 iterations** — OWASP recommends 210,000+ for SHA-512 | `lib/crypto.ts:39,61` |
| 26 | Security | **localStorage for referral_code** — XSS accessible | `LoginForm.tsx:116` |
| 27 | Arch | **Duplicate RTK Query endpoint** in category and product APIs | `categoryApi.ts:114`, `productApi.ts:168` |
| 28 | Arch | **Three identical route group layouts** — copy-pasted | Layout files |
| 29 | Arch | **Misleading export name** — file exports as different API name | `wishlistApi.ts` |
| 30 | Arch | **Minimal code splitting** — only 4 dynamic imports across entire codebase | Components globally |
| 31 | Arch | **No RTK Query cache policies** — all endpoints use default 60s | All API slices |
| 32 | Arch | **Wrong library in `optimizePackageImports`** | `next.config.ts` |
| 33 | Arch | **`services/` directory** unclear boundary vs `lib/` and `redux/` | `services/` |
| 34 | Arch | **Provider uses raw `useSelector`** instead of typed hook | `CartProvider.tsx` |
| 35 | Code | **Empty types file** (0 bytes) with commented-out barrel export | `types/checkout.ts` |
| 36 | Code | **`const res: any`** for coupon responses in 3 locations | Summary card components |
| 37 | Code | **SEO schema functions duplicated** between two utility files | Both files |
| 38 | Code | **Binary images in component directory** — should be in `/public/` | `components/category/*.png,*.jpg` |
| 39 | Code | **Hardcoded canonical URL** for all categories | `seo.ts:301` |
| 40 | Code | **Backend typos propagated** — `spacial_price`, `cconvenience_fee`, `payment_getway` | `types/`, hooks |
| 41 | Code | **`console.log` in filter hook** runs every render | `useFilters.ts:76` |
| 42 | A11y | **No `aria-live` regions** for dynamic updates (cart, prices, filters) | Cart, checkout, filters |
| 43 | A11y | **Heading hierarchy gaps** — `h1` jumps to `h4` in ProductView | `ProductView.tsx:330,393` |
| 44 | A11y | **Payment radio group lacks `role="radiogroup"`** | `PaymentSelector.tsx` |
| 45 | A11y | **Auth inputs missing `autoComplete` attributes** | `EmailLogin.tsx`, `PhoneLogin.tsx` |
| 46 | A11y | **Sidebar drawer** — 2 buttons without aria-label, focus management unclear | `SidebarDrawer.tsx` |
| 47 | A11y | **FAQ section** has no heading wrapping accordion items | `FAQAccordion.tsx` |
| 48 | A11y | **Checkout address form** lacks `aria-describedby`/`aria-invalid` on fields | `AddressForm.tsx` |

---

## Low (13)

| # | Agent | Issue | Location |
|---|-------|-------|----------|
| 49 | Security | **Console.error leaks auth error context** in dev | `lib/auth.ts:165` |
| 50 | Arch | **Unused legacy constants** | `categoryConstants.ts` |
| 51 | Arch | **API file contains hardcoded mock data** | `compare.ts` |
| 52 | Arch | **Animation library imported eagerly** despite `optimizePackageImports` | Various components |
| 53 | Code | **`eslint-disable-line react-hooks/exhaustive-deps`** on useEffect | `ProductDetails.tsx:87` |
| 54 | Code | **Commented-out code blocks** in multiple files | Multiple files |
| 55 | Code | **Hardcoded production URLs** in SEO utilities instead of env config | `seo.ts` (6 occurrences) |
| 56 | Code | **Placeholder TODOs** in form components | Multiple files |
| 57 | Code | **Large components** — ProductView 917 lines, PaymentForm 811 lines | Component files |
| 58 | Code | **Error pages near-identical copies** across route groups | `error.tsx` files |
| 59 | A11y | **Footer text contrast** — white on dark needs verification | `SiteFooter.tsx` |
| 60 | A11y | **Empty `alt=""` on 2 images** in ProductView — verify decorative intent | `ProductView.tsx` |
| 61 | A11y | **Custom buttons use `focus:outline-none`** without visible ring | `ProductView.tsx:898`, `ReviewModal.tsx:345` |

---

## Informational (1)

| # | Agent | Issue | Location |
|---|-------|-------|----------|
| 62 | Security | **No zod schemas found** — forms use inline regex despite zod in stack | Components directory |

---

## What's Done Well

### Security
- Zero `dangerouslySetInnerHTML`, zero `eval()` — primary XSS vectors eliminated
- `poweredByHeader: false`, production `removeConsole`, JWT strategy with token-derived max-age
- Image loading restricted to known domains via `remotePatterns`
- Bearer token auth (not cookie-based) partially mitigates CSRF
- Centralized route protection constants
- Proper 401 handling with retry and token refresh

### Architecture
- Clean server/client component boundary — server pages fetch data, `*Client` handles interactivity
- RTK Query endpoint injection pattern is correct with tag-based cache invalidation
- No circular dependencies detected (83 files analyzed)
- Well-organized TypeScript types with 17 domain-specific files
- Layered provider architecture
- Typed Redux hooks

### Code Quality
- Only 3 `any` usages across entire codebase
- Proper `react-hook-form` + `zod` integration in address form
- Custom hooks encapsulate complex flows well
- Zero `debugger` statements
- Error boundary coverage across all route groups

### Accessibility
- `ImageWithFallback` enforces `alt: string` at TypeScript type level (only 1 of 51 missing)
- UI primitives have solid built-in a11y (dialog, carousel, pagination, breadcrumb, spinner)
- Some key elements already have `aria-label` (cart link, filter buttons)
- `<html lang="en">` correctly set
- `focus-visible:` styling exists in base components

### SEO
- Comprehensive: JSON-LD structured data, OpenGraph, Twitter cards, breadcrumbs, sitemap, robots.txt
- Per-page `generateMetadata` on all dynamic routes
- ISR with proper revalidation

### DevOps
- Husky + commitlint + lint-staged for code quality enforcement
- `.env` properly gitignored with thorough `.env.example`
- `optimizePackageImports` for tree-shaking heavy libraries

---

## Priority Actions

### Immediate (Week 1) — Critical Security + Critical Accessibility

1. **Rotate AUTH_SECRET** to `openssl rand -base64 48`
2. **Move encryption server-side**, remove `NEXT_PUBLIC_ENCRYPTED_KEY`
3. **Create `middleware.ts`** for server-side auth route protection
4. **Validate `callbackUrl`** for same-origin before redirect
5. **Add skip link + `<main>` landmark** to root layout
6. **Add `aria-label` to all auth form inputs** (56 inputs)
7. **Add `aria-label` to unnamed buttons** (97 buttons, prioritize product-detail, auth, cart)

### Short-Term (Week 2-3) — High Severity

8. **Remove hardcoded reCAPTCHA key** fallback
9. **Add security headers** (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
10. **Validate payment redirect URLs** against gateway domain allowlist
11. **Wire error messages to inputs** via `aria-describedby` in auth forms
12. **Add `aria-live` regions** for cart updates, price changes, filter status
13. **Remove debug `console.log` statements** (~20 instances)
14. **Extract `useCouponActions` hook** to eliminate triplicated logic
15. **Fix broken price filter** in `useFilteredProducts`

### Medium-Term (Month 1) — Architecture + Quality

16. **Split config file** into domain-specific config files
17. **Refactor category slice** to remove data duplication
18. **Move server fetch helpers** out of Redux files into `lib/api/`
19. **Consolidate three identical layouts** into shared component
20. **Fix misleading export names**
21. **Add RTK Query cache policies** (`keepUnusedDataFor`, `refetchOnMountOrArgChange`)
22. **Consolidate SEO utilities**
23. **Fix heading hierarchy** in ProductView (h1 -> h2 -> h3 -> h4)
24. **Add `role="radiogroup"`** to payment method selector
25. **Populate or delete empty types file**
26. **Replace `any` types** with proper coupon response types

### Backlog

27. Add CSRF mitigation headers on mutations
28. Increase PBKDF2 iterations to 210,000+ (coordinate with backend)
29. Enable Next.js image optimization or add CDN-based optimizer
30. Add dynamic imports for route-level client components
31. Move binary images from component directory to `/public/`
32. Fix hardcoded canonical URL in category metadata
33. Normalize backend typos at API boundary via `transformResponse`
34. Add `autoComplete` attributes to auth form inputs
35. Add test infrastructure

---

## Methodology

This report was generated by 4 specialized agents running in parallel, each with focused scope:

| Agent | Files Scanned | Focus |
|-------|---------------|-------|
| **security-reviewer** | 30+ key files | OWASP Top 10, auth, encryption, API security, payment security |
| **architecture-reviewer** | 83 dependency-mapped files | Component architecture, state management, data flow, scalability |
| **code-quality-reviewer** | 30+ hooks/components/types | TypeScript quality, React patterns, duplication, debug code |
| **accessibility-reviewer** | 235 component files | WCAG 2.1 AA compliance, keyboard nav, screen readers, forms |

Each agent performed pattern searches, analyzed key files, and produced evidence-backed findings with file paths and code snippets. Findings were deduplicated and consolidated across agents by severity.
