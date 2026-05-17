# Browser Auth Layer + CORS Enforcement (Profile-backed)

## Overview

Enable form-based login flows driven over WebDriver BiDi by turning Crater's
existing cookie jar on by default, adding spec-faithful CORS preflight
enforcement and SameSite cookie attach policy on the fetch path, and
collecting the per-session user agent, cookie jar, and HTTP cache into a
single `Profile` value.

The user goal is: "log in via WebDriver, then keep operating on the
authenticated state." Today the pieces are present but disabled
(`BrowserState.cookie_jar` is constructed but `disabled by default for
security`) and the SameSite / CORS surfaces are not enforced. This design
flips them on, gates them through a single `Profile` value that bundles
user agent + jar + cache + a placeholder auth state, and validates the
end-to-end flow against a local Node fixture server.

## Goals

- WebDriver-initiated form login persists `Set-Cookie` across navigations
  and attaches the cookie to subsequent same-site requests.
- Cross-origin XHR / `fetch()` is gated by CORS: preflight (`OPTIONS`)
  fires when required, `Access-Control-Allow-*` headers are validated,
  and violations surface as `TypeError` in JS and `errorText` in BiDi.
- SameSite (Strict / Lax / None) attach policy matches the WHATWG cookie
  spec for top-level navigations and subresource fetches.
- A `Profile` value collects user agent, cookie jar, HTTP cache, and a
  placeholder `AuthState` slot. `BrowserState` exposes a single
  `state.profile` field; the existing `emulation_state` global UA is
  resolved through it.
- The full flow is exercised by a Node fixture server + Playwright BiDi
  test in `tests/`.

## Non-Goals

- Per-userContext profile isolation. P1 ships a single Profile shared
  across the session; multi-profile partitioning per BiDi `userContext`
  is deferred to a separate scenario.
- HTTP Basic / Digest 401 challenge handling
  (`network.continueWithAuth`). Deferred.
- A high-level BiDi macro command (`crater.loginWithFormCredential`).
  Deferred — clients compose the flow from `browsingContext.navigate` +
  `script.evaluate` + `storage.getCookies` for now.
- OAuth / SSO redirect chains. Out of scope.
- `Authorization` header injection from WebDriver. Deferred.

---

## Architecture

```
                    BiDi WebDriver client
                          │
       browsingContext.navigate / script.evaluate / storage.* / emulation.*
                          │
        ┌─────────────────▼──────────────────┐
        │     webdriver/webdriver (BiDi)     │
        │  emulation_state:                  │
        │    UA global is resolved through   │
        │    Profile.user_agent (per-context │
        │    / per-userContext maps stay).   │
        │  storage.*: unchanged surface,     │
        │    flows through Profile.jar.      │
        └─────────────────┬──────────────────┘
                          │
        ┌─────────────────▼──────────────────┐
        │           browser/shell            │
        │  BrowserState.profile : Profile    │
        │  navigation_fetch / script_fetch / │
        │  external_css_fetch:               │
        │    - Profile.cookie_jar attach     │
        │    - SameSite attach policy        │
        │    - CORS preflight + validation   │
        └─────────────────┬──────────────────┘
                          │
        ┌─────────────────▼──────────────────┐
        │   browser/http (existing pkg)      │
        │  + cors.mbt       (~120 LOC)       │
        │  + samesite.mbt   (~ 60 LOC)       │
        │                                    │
        │   browser/http_profile (new pkg)   │
        │  Profile { user_agent, cookie_jar, │
        │            http_cache, auth_state }│
        └────────────────────────────────────┘
```

### Boundaries

- One new package: `browser/http_profile/`.
- Two new files in `browser/http/`: `cors.mbt`, `samesite.mbt`.
- `BrowserState.{cookie_jar, http_cache}` fields fold into
  `BrowserState.profile : Profile`. The old field names stay available
  as short accessors (`state.cookie_jar()` etc.) so existing call sites
  compile during the migration; the accessors are marked for removal in
  a P2 follow-up.
- WebDriver `emulation_state` keeps its per-context and per-userContext
  UA maps; only the *global* default is rerouted through
  `Profile.user_agent`. Per-userContext profile partitioning is a P2
  scenario.

---

## Components

### `browser/http_profile/profile.mbt`

```moonbit
pub struct Profile {
  mut user_agent : String?            // None = runtime default
  cookie_jar : @http_cookie_jar.CookieJar
  http_cache : @http_cache.MemoryCacheBackend
  auth_state : AuthState              // empty in P1, future expansion
}

pub fn Profile::default() -> Profile
pub fn Profile::new(
  user_agent? : String,
  jar_enabled~ : Bool = true,   // default true (WebDriver sessions)
) -> Profile

pub fn Profile::effective_user_agent(self) -> String
//   self.user_agent ?? @browser_domain.default_runtime_user_agent()
```

### `browser/http_profile/auth.mbt`

```moonbit
pub struct AuthState {
  // P1: intentionally empty. Future: basic_credentials, bearer_tokens.
}
pub fn AuthState::default() -> AuthState
```

### `browser/http/samesite.mbt`

```moonbit
pub enum SiteContext { SameSite; CrossSite }

pub fn classify_site_context(
  request_origin : String,
  cookie_domain : String,
) -> SiteContext

pub fn should_attach_cookie(
  cookie : @http_cookie_jar.ParsedCookie,
  request_url : String,
  site_context : SiteContext,
  is_top_level_navigation : Bool,
) -> Bool
```

Pure functions. `cookie_jar.get_cookie_header()` filters through
`should_attach_cookie` before composing the header.

### `browser/http/cors.mbt`

```moonbit
pub enum CorsDecision {
  Allow
  PreflightRequired(PreflightRequest)
  Blocked(reason : String)
}

pub struct PreflightRequest {
  url : String
  origin : String
  method : String
  request_headers : Array[String]
}

pub struct PreflightEntry {
  allowed_methods : Array[String]
  allowed_headers : Array[String]
  allow_credentials : Bool
  expires_at_seconds : Double               // now + Access-Control-Max-Age
}

pub struct PreflightCache {
  entries : Map[String, PreflightEntry]     // keyed by origin × url
}

pub fn classify_request(
  url : String,
  origin : String,
  mode : @http.RequestMode,
  method : String,
  headers : Map[String, String],
) -> CorsDecision

pub fn validate_preflight_response(
  request : PreflightRequest,
  response : @http.HttpResponse,
) -> Result[Unit, String]

pub fn validate_actual_response(
  request_url : String,
  origin : String,
  credentials : @http.CredentialsMode,
  response : @http.HttpResponse,
) -> Result[Unit, String]
```

Pure functions plus one `PreflightCache` value owned by `BrowserState`.

### `browser/shell/navigation_fetch.mbt` (modified)

`get_cookie_header` is called with `is_top_level_navigation=true`. The
new `should_attach_cookie` filter permits SameSite=Lax cookies onto
top-level cross-site navigations as the spec allows, and rejects
SameSite=Strict cookies in that case.

### `browser/shell/script_fetch.mbt`, `external_css_fetch.mbt` (modified)

XHR / `fetch()` / `<script src>` / `<link rel="stylesheet">` paths run
`classify_request` first:

```
match cors::classify_request(url, origin, mode, method, headers) {
  Allow => fetch_with_cookies(false /* not top-level */)
  PreflightRequired(req) =>
    preflight_cache.get_or_fetch(req)
    validate_preflight_response → fetch_with_cookies
  Blocked(reason) => raise HttpError::CorsBlocked(reason)
}
```

After receiving the actual response, `validate_actual_response` checks
`Access-Control-Allow-Origin` / `Access-Control-Allow-Credentials`.

### `browser/shell/state.mbt` (modified)

```moonbit
// before
mut cookie_jar : @http_cookie_jar.CookieJar
http_cache : @http_cache.MemoryCacheBackend

// after
mut profile : @http_profile.Profile

pub fn BrowserState::cookie_jar(self) -> @http_cookie_jar.CookieJar { self.profile.cookie_jar }
pub fn BrowserState::http_cache(self) -> @http_cache.MemoryCacheBackend { self.profile.http_cache }
```

### `webdriver/webdriver/bidi_emulation_state.mbt` (modified)

```
emulation_user_agent_global         → delegated to profile.user_agent
emulation_user_agent_by_context     → unchanged (P1)
emulation_user_agent_by_user_context → unchanged (P1)
```

`resolve_effective_user_agent` fallback chain becomes:
per-context → per-userContext → `profile.user_agent` → runtime default.

---

## Data Flow

### 1. Form-based login (the happy path)

```
WebDriver client
  │
  │ 1. session.new
  ▼
BidiProtocol.create_session
  │  Profile::new(jar_enabled=true) bound to BrowserState.profile
  │
  │ 2. browsingContext.navigate({url: "/login"})
  ▼
navigation_fetch.fetch(/login, mode=Navigate, top_level=true)
  │  jar.get_cookie_header() → empty
  │  GET /login → 200 (form HTML)
  │
  │ 3. script.evaluate(fill form + submit)
  ▼
form_bridge → navigation_fetch.fetch(/login, POST, top_level=true)
  │  POST /login → 302, Set-Cookie: session=xyz; HttpOnly; SameSite=Lax
  │  jar.store_from_header(...)
  │  follow 302 → GET /dashboard
  │  jar.get_cookie_header(): SameSite=Lax + top-level nav → attach
  │  Cookie: session=xyz
  │  200 (authenticated dashboard)
  │
  │ 4. storage.getCookies({partition: {context: ctx}})
  ▼
BidiProtocol → profile.cookie_jar.list() → JSON
```

### 2. Cross-origin XHR with simple GET + credentials

```
fetch("https://api.example.com/me", {credentials: "include"})

script_fetch.fetch
  │ classify_request → Allow (simple GET)
  │ jar.get_cookie_header():
  │   SameSite=Lax → cross-site subresource → reject
  │   SameSite=None;Secure → attach
  │ GET api.example.com/me, Cookie: <SameSite=None only>
  │ response 200, ACA-Origin: app.example.com, ACA-Credentials: true
  │ validate_actual_response → Ok
  │ return body to JS
```

### 3. Cross-origin POST + custom header (preflight)

```
fetch("https://api.example.com/upload", {
  method: "POST", credentials: "include",
  headers: {"X-Csrf": "tok", "Content-Type": "application/json"}, body
})

script_fetch.fetch
  │ classify_request → PreflightRequired(req)
  │ preflight_cache.get_or_fetch(req):
  │   miss → OPTIONS .../upload
  │     ACR-Method: POST, ACR-Headers: x-csrf, content-type
  │   200/204, ACA-Methods: POST, ACA-Headers: x-csrf, content-type,
  │            ACA-Origin: app.example.com, ACA-Credentials: true,
  │            ACA-Max-Age: 600
  │   validate_preflight_response → Ok
  │   cache entry stored with max_age=600
  │ actual POST → 200
  │ validate_actual_response → Ok → return body
```

---

## Error Handling

### New `HttpError` variants

```moonbit
+ CorsBlocked(reason : String)
+ PreflightFailed(reason : String)
+ CookieAttachRejected(reason : String)   // internal, usually silent
```

`CookieAttachRejected` is normally a quiet `false` from
`should_attach_cookie` — the request still goes out without the
cookie. A warning is logged only when a Strict cookie would have been
required for a cross-site context.

### Surfacing to JS

```
HttpError::CorsBlocked    → JS TypeError ("Failed to fetch")
HttpError::PreflightFailed → JS TypeError ("Failed to fetch")
others                     → existing mappings
```

The opaque `TypeError` matches Chrome's behavior. The detailed reason
goes to the JS console for debugging and to the BiDi event stream for
WebDriver clients.

### Surfacing to WebDriver

BiDi `network.responseCompleted` (or `network.fetchError`) `errorText`
carries the reason verbatim:

```
errorText: "CORS preflight: Access-Control-Allow-Origin missing"
errorText: "CORS: credentials=include but Access-Control-Allow-Origin is wildcard"
```

This lets a Playwright test assert
`expect(req.failure().errorText).toMatch(/preflight/)` at the network
layer.

### Internal safety

- `Profile::default()` is infallible.
- `cookie_jar.store_from_header()` silently skips parse failures
  (current behavior preserved).
- Preflight `Map[]` lookups go through `.get()` to avoid the
  missing-key panic.
- `classify_site_context()` falls back to `CrossSite` when eTLD+1
  extraction fails (conservative: blocks attach rather than over-
  attach).

### Fixture-server-side validation

- Set-Cookie with `Secure` over non-HTTPS → rejected at parse, logged.
- Multiple `Access-Control-Allow-Origin` values → blocked, reason
  `"multiple ACAO values"`.
- Expired cookies → `cookie_jar.purge_expired(now)` runs before each
  navigation.

---

## Testing Strategy

### Unit tests (whitebox `_wbtest.mbt`)

`browser/http/samesite_wbtest.mbt`
- `classify_site_context`: same eTLD+1, different site, IP literal,
  `localhost`.
- `should_attach_cookie`: SameSite × {Strict, Lax, None} × {top-level
  nav, subresource} × {GET, POST} — 12 cases.

`browser/http/cors_wbtest.mbt`
- `classify_request`: simple GET (same/cross), POST + custom header
  → PreflightRequired, NoCors + non-safe method → Blocked.
- `validate_preflight_response`: all headers present → Ok; ACA-Methods
  missing → Err; ACA-Origin not echoed → Err; Max-Age parsing.
- `validate_actual_response`: `credentials=Include` with ACA-Origin=`*`
  → Err; same-origin always Ok.

`browser/http_profile/profile_wbtest.mbt`
- `Profile::new(jar_enabled=true/false)` reflected in
  `cookie_jar.is_enabled()`.
- `effective_user_agent` None / Some fallback.
- `AuthState` equality against `AuthState::default()`.

### Integration tests (blackbox `_test.mbt`)

`browser/shell/auth_flow_test.mbt`
- Stub fetcher driving `POST /login` → `Set-Cookie` → `GET /dashboard`
  with `Cookie:` attached. Asserts on the request log.
- 302 chain (login → dashboard) preserves cookie attach order.

`browser/shell/cors_enforcement_test.mbt`
- Stub fetcher driving:
  - cross-origin GET, ACA-Origin echoed → success.
  - cross-origin GET, ACA-Origin missing → `HttpError::CorsBlocked`.
  - cross-origin POST + custom header → preflight `OPTIONS` first, cache.
  - second identical request → preflight cache hit, no second OPTIONS.

### WebDriver / BiDi tests

`webdriver/webdriver/bidi_protocol_auth_wbtest.mbt` (new)
- Session start: `profile.cookie_jar.is_enabled() == true`.
- `storage.getCookies` returns profile jar contents through the
  partition surface.
- `emulation.setUserAgentOverride` global value reflects in
  `profile.user_agent`.

### End-to-end (Node fixture + Playwright BiDi)

`scripts/fixtures/auth-server.ts` (new)
- `node:http` server with:
  - `GET /login` → form HTML.
  - `POST /login` → on valid credentials, `Set-Cookie: session=...;
    HttpOnly; SameSite=Lax`, 302 to `/dashboard`.
  - `GET /dashboard` → 200 if cookie valid, 401 otherwise.
  - `GET /api/me` → JSON, served from a separate port for CORS tests.
- Hard-coded fixture credentials are flagged for `secretlint` review
  (test fixture only, separate `.secretlintrc` carveout if needed).

`tests/auth-flow-via-bidi.test.ts` (new)
- `login then dashboard via BiDi`: navigate, fill, submit, expect
  dashboard URL + welcome body, confirm session cookie via
  `storage.getCookies`.
- `cross-origin XHR preflight succeeds when API echoes ACA-Origin`.
- `cross-origin XHR is blocked when ACA-Origin missing` — asserts on
  BiDi `errorText`.
- `SameSite=Lax cookie is not attached to cross-site subresource`.

`flaker.star` gets a new `auth-flow-via-bidi` task with inputs
`browser/shell/**`, `browser/http/**`, `browser/http_profile/**`,
`webdriver/webdriver/**`, `scripts/fixtures/**`,
`tests/auth-flow-via-bidi.test.ts`.

### pkspec scenarios

Three new draft → approved scenarios under `goal.protocol-compat` and
`goal.dom-compat`:

- `compat.cookie-jar-default-on-webdriver` — WebDriver sessions start
  with the jar enabled and persist cookies across navigations.
- `compat.cors-preflight-enforcement` — `script_fetch` / `fetch()`
  routes through `classify_request`, OPTIONS preflight is issued and
  validated, violations surface as `TypeError` / BiDi `errorText`.
- `compat.samesite-attach-policy` — cookie attach matches the WHATWG
  spec table for Strict / Lax / None across navigations and
  subresource fetches.

Each scenario's implementing test is the matching `_wbtest.mbt` plus
the end-to-end fixture test above.

Future P2 scenarios (not in this design):
`protocol.bidi-login-macro`,
`protocol.bidi-network-continue-with-auth`,
`compat.per-user-context-profile-isolation`.

---

## Sequencing

1. Profile type + accessor migration (no behavior change).
2. SameSite attach policy + cookie jar default-on (form login works
   end-to-end without CORS enforcement yet).
3. CORS classification + preflight cache + actual-response validation.
4. BiDi `errorText` propagation.
5. Node fixture server + Playwright BiDi tests.
6. pkspec scenarios flipped to approved.

Each step is a separate PR with its own pkspec smoke test where
applicable.
