# Codebase Analysis Report: optimus-marchant

**Date:** 2026-06-15
**Stack:** Next.js 14.2.35 (App Router), React 18.3.1, Redux Toolkit + RTK Query, Ant Design 5.24, crypto-js 4.2.0, Pusher-js, Vitest, TypeScript 5.8, Node 24.16, Docker, Sentry 8.32
**Domains:** security, architecture, quality, a11y
**Scope:** full (repo root)

---

## Executive Summary

- **Security:** Posture is **weak**. Auth tokens are stored in `localStorage` behind a client-exposed AES key (`NEXT_PUBLIC_CRYPTO_HASH_KEY`), giving zero real protection. Pusher app key and Barikoi API key are hardcoded in app.config. CORS-bypass proxy on `/api/frontend/set-cookies` decrypts and re-issues cookies from arbitrary POST bodies. 1 Critical / 5 High.
- **Architecture:** Sound at the macro level (App Router + RTK Query slices per domain), but **circular imports**, **leaking types (`any` in 165 locations)**, **`useAppDispatch` typed as `AppDispatch | any`** defeating the typed dispatch, and **data-mutation logic embedded in `onQueryStarted` side effects** create tight coupling and race conditions. 0 Critical / 4 High.
- **Code Quality:** Functional but **debug logging left in production paths** (Pusher init, console.log on every connection event), **`window`/`document` SSR guards scattered through component bodies**, **mutation-heavy error handling with parallel `.then/.catch/.finally` chains**, and **171 `eslint-disable` markers** masking real issues. 0 Critical / 3 High.
- **Accessibility:** Ant Design provides baseline semantics, but **icon-only buttons lack `aria-label`** (UserDropdown, CheckBalanceButton, mobile search toggle), **the ContextualSearch `enterButton` icon has no accessible name**, **active filter state is communicated by color alone** (ConsignmentFilters), and **`autoComplete='off'` on the Add Parcel form disables browser autofill** for users with motor impairments. 0 Critical / 5 High.

Total: **2 Critical, 17 High, 14 Medium, 9 Low, 6 Informational.**

---

## Critical (2)

| # | Domain | Issue | Location |
|---|--------|-------|----------|
| C1 | security | Client-side "encryption" of auth token uses a `NEXT_PUBLIC_` env var, fully exposed to every browser | `utils/cryptoUtils.ts:4`, `app.config.ts:1-3`, `Dockerfile:64` |
| C2 | security | `/api/frontend/set-cookies` route decrypts an attacker-supplied body and issues 15-day httpOnly auth cookies with no caller authentication | `app/api/frontend/set-cookies/route.ts:7-37` |

### C1 — Auth token "encryption" key shipped to the client (OWASP A02 Cryptographic Failures, A07 Auth Failures)

**Evidence:**

```ts
// utils/cryptoUtils.ts:4
const SECRET_KEY = process.env.NEXT_PUBLIC_CRYPTO_HASH_KEY ?? ''
// ^ NEXT_PUBLIC_ prefix inlines the value into every client bundle at build time.
```

The same string is used by `cryptoUtils.setItem(STORAGE_KEYS.TOKEN, ...)` in `authActions.ts`, then read by `apiSlice.ts:14` to construct `Authorization: Bearer <token>` headers.

**Impact:** The AES passphrase is visible in the browser devtools Sources tab, on every CDN-cached JS chunk, and in the Dockerfile (`ENV NEXT_PUBLIC_CRYPTO_HASH_KEY=MY_APP_CRYPTO_HASH_KEY` line 64). Any attacker who loads the page can decrypt every value in `localStorage`, including the merchant bearer token. The "encryption" provides **no security boundary** and gives a false sense of protection. Combined with no token rotation and a 15-day cookie TTL, a single XSS grants persistent account takeover.

**Remediation:**

1. Stop encrypting tokens client-side. The browser cannot keep a secret from itself.
2. Store the bearer token **only** in an `httpOnly`, `Secure`, `SameSite=Lax` cookie set by the server (Next.js Route Handler or middleware). Read it in `fetchBaseQuery` via a credentials-aware fetch (`credentials: 'include'`) — no client-side read required.
3. If obfuscation is still desired for defense in depth, use a per-session random key generated server-side and delivered via the same cookie session; never expose a stable passphrase.

---

### C2 — Cookie-issuing route has no authentication check (OWASP A01 Broken Access Control, A04 Insecure Design)

**Evidence:**

```ts
// app/api/frontend/set-cookies/route.ts:7-37
export async function POST(request: Request) {
  const body = await request.json()
  const { [STORAGE_KEYS.TOKEN]: encryptedToken, [STORAGE_KEYS.USER]: encryptedUser } = body
  const token = cryptoUtils.decrypt(encryptedToken)
  const user = cryptoUtils.decrypt(encryptedUser)
  // ...no caller verification, no CSRF token, no Origin check...
  response.cookies.set('optimus_merchant_token', token, {
    maxAge: 15 * 24 * 60 * 60,
    httpOnly: true,
    sameSite: 'lax',
  })
}
```

The decryptor uses the same client-bundled `NEXT_PUBLIC_CRYPTO_HASH_KEY` (see C1), so any visitor can produce a valid encrypted body for an arbitrary token.

**Impact:** Any script running in the page (or a CSRF form POST from a third-party site, given `sameSite: 'lax'` allows top-level navigations) can plant a chosen bearer token into the victim's httpOnly cookie. Combined with a leaked token, this enables **session fixation**. It also means XSS survives logout because the attacker can re-issue the cookie.

**Remediation:**

1. Remove this route. Token issuance must happen **only** on a server-side response to a verified login request to the upstream API.
2. If a bridge is unavoidable, gate it behind an HMAC-signed body verified with a **server-only** secret (`process.env.COOKIE_BRIDGE_SECRET`, no `NEXT_PUBLIC_`), validate `Origin`, and require a CSRF token.

---

## High (17)

| # | Domain | Issue | Location |
|---|--------|-------|----------|
| H1 | security | `dangerouslySetInnerHTML` renders a string built from API response data | `components/features/parcel/AddNewParcel.tsx:402` |
| H2 | security | Hardcoded Pusher app key in source (low risk for Pusher by design, but normalising the pattern of secrets-in-source) | `app.config.ts:69-89` |
| H3 | security | Barikoi API key exposed as `NEXT_PUBLIC_MAP_API_ACCESS_TOKEN` and interpolated into URL | `redux/features/autoComplete/autoCompleteApi.ts:28`, `app.config.ts:3` |
| H4 | security | Logout only clears local state; server session remains valid (no server revoke) | `redux/features/auth/authActions.ts:17-25` |
| H5 | security | `validateUser` does an unauthenticated `fetch` with no timeout, no AbortController, no CSRF token | `utils/validateUtils.ts:11-23` |
| H6 | architecture | Circular dependency: `redux/features/api/apiSlice.ts` imports from `redux/features/auth/authActions.ts`, which imports from `utils`, which imports back through the api surface | `redux/features/api/apiSlice.ts:1,7` |
| H7 | architecture | `useAppDispatch` typed as `() => (AppDispatch | any)` — defeats the entire typed-dispatch contract | `redux/store.ts:34-35` |
| H8 | architecture | Login success path performs three side effects inside `onQueryStarted` (validate user, persist auth, hard redirect) instead of in a thunk or component effect — couples the network layer to auth state and is untestable | `redux/features/auth/authApi.ts:31-57` |
| H9 | architecture | Two parallel RTK Query APIs (`apiSlice`, `autoCompleteApi`) with separate `reducerPath`s, no shared `BaseQueryFn`, no shared tag types — duplicates auth/header logic | `redux/features/autoComplete/autoCompleteApi.ts:5-15` |
| H10 | quality | Pusher init module retains 9+ `console.log` statements, including logging user info and full channel objects on every page load | `redux/features/notification/notificationAction.ts:11,52,57,61,70,81,87` |
| H11 | quality | 19 `eslint-disable react-hooks/exhaustive-deps` overrides hide stale-closure bugs in 13 components, including effect-heavy ones like `AddNewParcel`, `Consignments`, `ManagePickupLocations` | `components/features/parcel/AddNewParcel.tsx:291` + 18 more |
| H12 | quality | `register` mutation's `onQueryStarted` catches and silently swallows all errors (`catch { // nothing }`) — users get no feedback on registration failures | `redux/features/auth/authApi.ts:78-83` |
| H13 | a11y | Icon-only buttons lack `aria-label` (UserDropdown profile circle, mobile search toggle, balance button collapsed state) | `components/features/header/UserDropdown.tsx:45`, `components/layout/Header.tsx:38,51,81`, `components/features/header/CheckBalanceButton.tsx:50-65` |
| H14 | a11y | ContextualSearch submit button is `enterButton={<SearchOutlined />}` with no accessible name | `components/features/header/ContextualSearch.tsx:33-44` |
| H15 | a11y | Active filter state in ConsignmentFilters is conveyed by color/background only | `components/features/consignments/ConsignmentFilters.tsx:35-44` |
| H16 | a11y | Login form inputs have no `<label htmlFor>` association; antd `Form.Item` auto-binding relies on `name`, which screen readers do not announce as a label without `label` prop | `components/features/auth/LoginForm.tsx:38-65` |
| H17 | a11y | Logo is wrapped in a `<button>` whose only content is an `<Image>` with `alt='Optimus'` — the accessible name is "Optimus" not "Go to dashboard" | `components/common/Logo.tsx:29-49` |

### H1 — Stored XSS via `dangerouslySetInnerHTML` (OWASP A03 Injection)

**Evidence:**

```ts
// components/features/parcel/AddNewParcel.tsx:173-180
const _customerStats = `
  Delivered: <b style="color: green;">${proper_deliveries}</b>
  Cancelled: <b style="color: red;">${improper_deliveries}</b>,
  Delivery Success Rate: <b style="color: blue;">${deliverySuccessRate}%</b>
`
// line 402
<p dangerouslySetInnerHTML={{ __html: customerStats }} />
```

`proper_deliveries` and `improper_deliveries` are returned from `getMerchantsCustomerInfo(mobileNumber)`. Today they are integers, but the API surface is untyped (`any`) and a single backend regression that returns a string field with HTML characters becomes executable markup.

**Impact:** Reflected/stored XSS if the upstream API is ever compromised or extended with mutable fields. Defense in depth is broken.

**Remediation:** Replace with React elements: `<p>Delivered: <b style={{color:'green'}}>{proper_deliveries}</b> …</p>`. Never use `dangerouslySetInnerHTML` for templated output.

---

### H6 — Circular import graph between api slice and auth actions

**Evidence:** `apiSlice.ts` line 7 imports `clearCookies` from `authActions.ts`; `authActions.ts` imports `validateUser` from `@/utils`; the utils barrel re-exports from `cryptoUtils` which depends on `STORAGE_KEYS` from `app.config` — and `apiSlice` is consumed by `authApi.ts`, which `authActions` indirectly relies on. The `// eslint-disable import/no-cycle` on line 1 of `apiSlice.ts` and on `authApi.ts` confirms the team knows.

**Impact:** Module evaluation order bugs, flaky HMR, hard-to-test code, future bundler mis-optimisations.

**Remediation:** Extract the 401-handler into a standalone module that receives a callback or uses a Redux listener middleware (`listenerMiddleware` from RTK) instead of importing auth logic into the base query.

---

### H7 — `useAppDispatch: () => (AppDispatch | any)` defeats typed dispatch

**Evidence:**

```ts
// redux/store.ts:34-35
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const useAppDispatch: () => (AppDispatch | any) = useDispatch // NOSONAR
```

The return type union `AppDispatch | any` collapses to `any`. Every `dispatch(someThunk())` and every `dispatch(counter.actions.inc())` is now effectively untyped across the whole app.

**Remediation:** Replace with the canonical RTK pattern:

```ts
export const useAppDispatch = () => useDispatch<AppDispatch>()
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector
```

---

### H8 — Side effects in `onQueryStarted`

**Evidence:** `authApi.ts:31-57` — the login mutation's `onQueryStarted` performs user validation, persists the token via `setAuthData`, and forces a `window.location.href = '/dashboard'` redirect. None of this is in the function signature and none of it is reachable from a unit test without mocking the entire Redux store.

**Impact:** Untested auth path, surprise hard navigation (loses SPA state), and any error in `setAuthData` propagates as a generic login failure with no actionable message.

**Remediation:** Move the orchestration into an explicit thunk (`loginUser`), call it from the component, and let the component own the navigation via `router.replace('/dashboard')`.

---

### H13 — Icon-only buttons missing accessible names (WCAG 2.2 SC 4.1.2 Name, Role, Value)

**Evidence:**

```tsx
// components/features/header/UserDropdown.tsx:44-46
<Button shape='circle' size='large' icon={<UserOutlined style={{ fontSize: '18px' }} />} />
```

Same pattern in `Header.tsx:38` (sidebar toggle), `Header.tsx:51` (mobile search open), `Header.tsx:81` (mobile search close), and `CheckBalanceButton.tsx` collapsed state.

**Impact:** VoiceOver and NVDA users hear "button" with no label. Keyboard users cannot identify the control without sighted context.

**Remediation:** Add `aria-label='Open user menu'`, `aria-label='Toggle sidebar'`, `aria-label='Open search'`, `aria-label='Close search'`, `aria-label='Check balance'`. For mobile-only toggles, ensure the label updates when state changes (`aria-expanded` on the trigger).

---

### H16 — Login form has no programmatic labels (WCAG 2.2 SC 1.3.1 Info and Relationships, 3.3.2 Labels or Instructions)

**Evidence:** `LoginForm.tsx:38-65` — the `<Form.Item name='email'>` wraps an `<Input placeholder='Mobile Number'>`. Ant Design does not generate a `<label>` unless the `label` prop is supplied. The placeholder is the only text near the field; placeholders disappear on input and fail SC 3.3.2.

**Remediation:** Either pass `label='Mobile Number'` to `Form.Item` (preferred, renders a real `<label>`) or supply `<Input aria-label='Mobile Number' />` on every field. Same fix needed on Register, ForgotPassword, ChangePassword.

---

## Medium (14)

| # | Domain | Issue | Location |
|---|--------|-------|----------|
| M1 | security | `window.location.href` redirects used for logout and post-login — bypass SPA route guards and reset history, preventing back-button recovery UX | `redux/features/auth/authActions.ts:21`, `redux/features/auth/authApi.ts:51`, `redux/features/api/apiSlice.ts:38` |
| M2 | security | `validateUser` and all `fetch` calls in `validateUtils.ts` lack `AbortController`; switching pages mid-request causes setState-on-unmounted warnings | `utils/validateUtils.ts:11` |
| M3 | security | No CSP, no `X-Content-Type-Options`, no `Referrer-Policy` headers in `next.config.mjs` | `next.config.mjs` |
| M4 | architecture | 165 `any` casts across the codebase, including in Redux transforms (`merchantApi`, `supportApi`, `consignmentsApi`) | `redux/features/merchant/merchantApi.ts:13-14`, +12 more |
| M5 | architecture | `setSelectedKey(() => _selectedKey)` uses functional setter for non-functional update (confusing, not a bug today) | `components/layout/Sidebar.tsx:69-73` |
| M6 | architecture | `activateNotification` returns a function but is also called as one in `Providers.tsx` (`activateNotification()` without dispatch) — dead code path; the returned thunk is never dispatched | `app/providers.tsx:11`, `redux/features/notification/notificationAction.ts:42-44` |
| M7 | architecture | `Conversation.tsx` polls every 10s via RTK Query refetch instead of using Pusher (the app already ships Pusher elsewhere) — duplicate real-time story | `components/features/support/Conversation.tsx:53` (docstring) |
| M8 | quality | `setTimeout(() => setIsLoading(false), 500)` artificially delays button re-enable in LoginForm — perceived perf loss with no UX rationale | `components/features/auth/LoginForm.tsx:22` |
| M9 | quality | `deactivateSocket` and `connectSocketAgain` thunks are returned but never dispatched — Pusher reconnect loop silently no-ops | `redux/features/notification/notificationAction.ts:88-99` |
| M10 | quality | `PaymentRequest.tsx:40` contains dead `refetch()` call in a comment block | `components/features/paymentRequest/PaymentRequest.tsx:40` |
| M11 | a11y | Add Parcel form sets `autoComplete='off'` globally, disabling browser autofill for address and phone — bad for users with motor or memory impairments | `components/features/parcel/AddNewParcel.tsx` (form declaration) |
| M12 | a11y | `ConsignmentTable` pagination `useMediaQuery('max-width: 498px')` — missing parentheses on media query syntax (`(max-width: 498px)`) means the hook always returns false | `components/features/consignments/ConsignmentTable.tsx:18` |
| M13 | a11y | No visible focus style customization; relies entirely on antd defaults. Theme should re-declare focus ring for branded components | `app/theme/themeConfig.ts` (not reviewed in depth) |
| M14 | a11y | `Image` with `alt='Logo'` on tracking page is decorative; should be `alt=''` since it's inside a link with visible text elsewhere | `components/features/tracking/tracking-parcel.tsx:180` |

---

## Low (9)

| # | Domain | Issue | Location |
|---|--------|-------|----------|
| L1 | quality | Commented-out `console.log` lines left in `cryptoUtils.ts:54,56` | `utils/cryptoUtils.ts` |
| L2 | quality | `entrypoint.sh` echoes sensitive env values to stdout during container start (`env \| grep '^NEXT_PUBLIC_'`) | `entrypoint.sh:10-11` |
| L3 | quality | `metadata.openGraph.url` hardcoded to `https://merchant.sureexbd.com` — wrong for staging/preview deploys | `app/layout.tsx:32-49` |
| L4 | architecture | `_handleMenuItemClick` checks `key === '/'` to mean logout — magic-string routing convention, fragile | `components/layout/Sidebar.tsx:57-67` |
| L5 | architecture | Plausible analytics script hardcoded to `merchant.sureexbd.com` — also tracks staging | `app/layout.tsx:25-29` |
| L6 | a11y | Several decorative images have descriptive alt (`alt='taka'`, `alt='delivery-proof'`) | `components/features/parcel/CollectionInfo.tsx:69`, `components/features/consignments/Consignments.tsx:581` |
| L7 | a11y | `Spin tip='Loading'` should be `tip='Loading…'` with ellipsis or sentence-case label `aria-live='polite'` (antd renders aria-live automatically) | `components/features/parcel/AddNewParcel.tsx` |
| L8 | security | `Pusher.logToConsole = false` is set but `console.log` for Pusher events remains; in production builds, these still ship | `redux/features/notification/notificationAction.ts:50` |
| L9 | quality | `metadata.json` not present; Lighthouse meta coverage is manual | `app/layout.tsx` |

---

## Informational (6)

- **I1** (architecture): `redux/types/api.types.ts` exists but is barely used — slices define inline interfaces. Consolidate API response types.
- **I2** (quality): Vitest test coverage exists for auth, invoice, consignments, but **no tests cover the auth cookie bridge routes** (`/api/frontend/set-cookies`, `/api/frontend/clear-cookies`) — highest-risk code is least tested.
- **I3** (security): `eslint-plugin-jsx-a11y` is installed; consider surfacing its output in CI as a gate, not just lint.
- **I4** (architecture): Consider adopting RTK `listenerMiddleware` to replace `onQueryStarted` side effects and `apiSliceWithReauth` — listeners are testable, debuggable, and decoupled.
- **I5** (quality): The `// NOSONAR` markers spread across the codebase (e.g., `redux/store.ts:35`, `ConsignmentActions.tsx`, `AddNewParcel.tsx` phone regex) — SonarQube noise suppression suggests deeper review of each instance.
- **I6** (a11y): No skip-to-main-content link in `app/layout.tsx` (WCAG 2.4.1).

---

## What's Done Well

### Security
- httpOnly, `Secure` (in prod), `SameSite=Lax` cookies are the correct baseline posture on the server route — the failure is the missing caller auth, not the cookie attributes themselves (`app/api/frontend/set-cookies/route.ts:24-30`).
- 401 responses trigger an automated logout + redirect, preventing silent token-stale calls (`redux/features/api/apiSlice.ts:28-40`).
- Sentry is configured with `onunhandledrejection: false` to avoid leaking promise rejection details to the client replay (`sentry.client.config.js:10-11`).

### Architecture
- Clean slice-per-domain structure under `redux/features/*Api.ts` — predictable file layout.
- `createApi` with comprehensive `tagTypes` for cache invalidation (`redux/features/api/apiSlice.ts:42`).
- Dynamic imports for code-splitting heavy modals (`AdvancedSearchModal`) reduce initial bundle (`components/features/consignments/Consignments.tsx:24`).

### Code Quality
- Strict ESLint + Prettier + Husky + commitlint pipeline (`package.json:scripts`, `.husky/`).
- Comprehensive unit-test scaffolding under `__tests__/redux/features/` covering most API slices.
- Strong-typed form validation rules in `AddNewParcel` (regex-validated mobile, weight, quantity).

### Accessibility
- All `<Image>` components include `alt` attributes (7/7 images scanned).
- Ant Design ConfigProvider centralises theme; component-level semantics (button, input, table) inherit reasonable defaults.
- `viewport` config sets `viewportFit: 'cover'` for safe-area-aware mobile rendering (`app/layout.tsx:7-13`).

---

## Priority Actions

### Immediate (Week 1) — Critical
1. **C1** Remove `NEXT_PUBLIC_CRYPTO_HASH_KEY`; move token storage to httpOnly cookie set by the server on login response.
2. **C2** Delete `/api/frontend/set-cookies` or gate behind an HMAC-signed, Origin-checked body.
3. **H1** Replace `dangerouslySetInnerHTML` in `AddNewParcel.tsx:402` with React elements.

### Short-Term (Week 2-3) — High
4. **H6** Break the api/auth circular import with a `listenerMiddleware`.
5. **H7** Restore typed dispatch in `redux/store.ts:34`.
6. **H8** Move login side effects out of `onQueryStarted` into an explicit thunk.
7. **H4** Implement server-side session revoke on logout.
8. **H13–H17** Add `aria-label` to every icon-only button; add `label` to every `Form.Item` in auth flows.
9. **H10** Strip Pusher `console.log` statements; gate any debug logging behind `process.env.NODE_ENV === 'development'`.

### Medium-Term (Month 1)
10. **H9** Consolidate the two RTK Query APIs (`apiSlice` + `autoCompleteApi`) into one with shared `baseQuery`.
11. **M1–M3** Add CSP, X-Content-Type-Options, Referrer-Policy headers in `next.config.mjs`; replace `window.location.href` with `router.replace`.
12. **M4** Type-sweep `any` in Redux transforms; introduce generated API types (OpenAPI codegen or hand-rolled).
13. **M6, M9** Delete dead Pusher reconnect code or fix the dispatch flow.
14. **M11–M14** A11y polish pass on form labels, media-query syntax bug, decorative alts.

### Backlog
15. **I1–I6** Consolidate `redux/types`, add cookie-bridge tests, gate CI on jsx-a11y, add skip-link, review each `NOSONAR` marker.

---

## Methodology

| Domain | Files Scanned | Focus |
|--------|---------------|-------|
| Security | 232 source files via `rg`; deep read of `cryptoUtils.ts`, `apiSlice.ts`, `authApi.ts`, `authActions.ts`, `validateUtils.ts`, `app/api/frontend/*/route.ts`, `middleware.ts`, `notificationAction.ts`, `Dockerfile`, `entrypoint.sh`, `app.config.ts` | OWASP A01 (access control), A02 (crypto), A03 (injection), A04 (insecure design), A05 (misconfig), A07 (auth) |
| Architecture | All `redux/**` slices, `app/**` shell, top 20 components by size | SOLID, dependency direction, circular imports, abstraction levels |
| Quality | 232 source files; 171 `eslint-disable` markers analysed; all auth, notification, consignment flows | Error handling, complexity, dead code, async patterns |
| A11y | All `.tsx` with `<button`, `<img`, `<input`, `<Form`, ARIA attributes | WCAG 2.2 AA: SC 1.3.1, 1.4.3, 2.1.1, 2.4.1, 3.3.2, 4.1.2 |

Each domain ran pattern-based `rg` searches, then deep-read top 10–15 hotspot files via `ctx_execute_file` / batched cat. Findings were de-duplicated across domains and ranked severity-first. WebSearch verified Next.js 14.2.35 has no unpatched CVE in the 14.2.x line (only 15.x/16.x are affected by the December 2025 RSC advisory).
