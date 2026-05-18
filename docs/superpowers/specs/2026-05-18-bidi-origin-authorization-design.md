# BiDi Origin-Scoped Authorization Injection

## Overview

Extend Crater's BiDi runtime so WebDriver clients can register an
`Authorization` header value per origin, and have the BiDi runtime
fetch shim attach that header automatically to matching outgoing
requests. Cover the common Bearer / JWT case and the broader
"WebDriver supplies the credential, page-script forgets to send it"
ergonomic.

This is Phase 1 of the auth-extension follow-up to the
[browser auth + CORS plan](./2026-05-17-browser-auth-cors-design.md).
Phase 2 (HTTP Basic 401 challenge handling, `network.continueWithAuth`)
is a separate spec.

## Goals

- WebDriver clients can call a new `crater.setOriginAuthorization
  ({origin, headerValue})` BiDi command to register an Authorization
  value scoped to a single `scheme://host[:port]` origin.
- The BiDi runtime fetch shim automatically attaches the registered
  header to outgoing requests whose URL matches the origin, unless the
  caller has already set `Authorization` on the request (caller wins,
  same policy as PR #136 cookies).
- `crater.clearOriginAuthorization({origin})` removes a registered
  entry; `crater.listOriginAuthorizations()` returns the registered
  origins (without exposing the header values).
- Header values are sanitized at the input boundary so CRLF / control
  characters cannot inject downstream log lines or extra HTTP headers.
- Stored credentials never leak to logs or list responses — the
  `AuthState` `Show` impl renders `<redacted>` for each entry, and the
  list response surfaces origins only.

## Non-Goals

- HTTP Basic / Digest 401 challenge handling
  (`network.continueWithAuth`). Phase 2, separate scenario.
- BiDi standard `network.continueRequest` header-override flow. Phase 2.
- OAuth / SSO redirect chains, JWT signing / verification, refresh
  token plumbing. Out of scope — caller supplies a pre-baked header
  value.
- Persistent storage of credentials across sessions. The registered
  state lives on the per-session `Profile.auth_state` and is dropped on
  `browsingContext.close` along with the profile.
- Per-URL-prefix or wildcard matching. Origin-only scope keeps the
  surface minimal; URL-prefix matching is filed as a follow-up draft if
  the need arises.

---

## Architecture

```
            WebDriver client
                │
   crater.setOriginAuthorization({origin, headerValue})
   crater.clearOriginAuthorization({origin})
   crater.listOriginAuthorizations()
                │
        ┌───────▼───────────────────┐
        │  webdriver/webdriver       │
        │  bidi_authorization.mbt    │  ← new: handler + serializer
        │  (dispatch routes to it)   │
        └───────┬───────────────────┘
                │ mutates per-session profile
        ┌───────▼───────────────────┐
        │  http/profile/auth.mbt    │  ← AuthState extended
        │  origin_headers : Map     │
        └───────┬───────────────────┘
                │ snapshot push (mirrors cookies)
        ┌───────▼───────────────────┐
        │  bidi_runtime_context.mbt │
        │  set_runtime_context_     │
        │    authorization          │
        │  → globalThis.__bidi      │
        │      ContextAuth          │
        │  → globalThis.__bidi      │
        │      ResolveAuth(url)     │
        └───────┬───────────────────┘
                │
        ┌───────▼───────────────────┐
        │  bidi_runtime_eval.mbt    │
        │  fetchWithPolicy:         │
        │  attach Authorization     │
        │  if !caller-supplied      │
        └───────────────────────────┘
```

### Boundaries

- One new MoonBit file: `webdriver/webdriver/bidi_authorization.mbt`.
- `http/profile/auth.mbt` upgrades from an empty placeholder to a real
  struct with `origin_headers : Map[String, String]`.
- `webdriver/webdriver/bidi_runtime_context.mbt` gains a parallel
  `set_runtime_context_authorization` extern js mirroring the existing
  cookie snapshot push.
- `webdriver/webdriver/bidi_runtime_eval.mbt` adds Authorization attach
  inside the existing `fetchWithPolicy` header-construction block.
- `bidi_protocol_context_lifecycle.mbt` calls the new snapshot pusher
  alongside the cookie push.
- `bidi_protocol_dispatch.mbt` (or the appropriate `dispatch_*.mbt`)
  routes the three `crater.*` command names to the new handler.

---

## Components

### `http/profile/auth.mbt` (extended)

```moonbit
pub(all) struct AuthState {
  mut origin_headers : Map[String, String]
} derive(Debug)

pub impl Show for AuthState with output(self, logger) {
  logger.write_string("{")
  let mut first = true
  for origin, _ in self.origin_headers {
    if !first { logger.write_string(", ") }
    first = false
    logger.write_string(origin + ": <redacted>")
  }
  logger.write_string("}")
}

pub fn AuthState::default() -> AuthState {
  AuthState::{ origin_headers: {} }
}

pub fn AuthState::set_origin_header(
  self : AuthState,
  origin : String,
  header_value : String,
) -> Unit

pub fn AuthState::clear_origin_header(
  self : AuthState,
  origin : String,
) -> Unit

pub fn AuthState::header_for_origin(
  self : AuthState,
  origin : String,
) -> String?

pub fn AuthState::list_origins(self : AuthState) -> Array[String]
```

`Show` redacts every header value. Stored credentials cannot leak via
`println` / panic stack traces / structural debugging.

### `webdriver/webdriver/bidi_authorization.mbt` (new)

Handler functions for the three `crater.*` commands plus a
`serialize_auth_snapshot_for_runtime(ctx_id) -> String` helper that
emits a JSON object `{origin: header_value, ...}` for the runtime
bridge.

Input validation rejects:

- Missing or non-string `origin` / `headerValue`.
- `origin` whose scheme is not `http://` or `https://`.
- `origin` containing path / query / fragment.
- `origin` parse failure.
- Empty `headerValue`.
- `headerValue` containing CR, LF, NUL, or ANSI CSI escape (`\x1b[`).
- `headerValue` exceeding 8 KB.
- Unknown `context` argument.

Origin normalization:

- Scheme and host lowercased.
- Default port (`:80` for http, `:443` for https) stripped.
- Trailing slash on the origin URL stripped.

`listOriginAuthorizations` returns `{origins: [{origin: "..."}]}` —
header values are deliberately not exposed.

### `webdriver/webdriver/bidi_runtime_context.mbt` (modified)

New extern js `js_set_runtime_context_authorization(ctx_id, auth_json)`
and a thin MoonBit wrapper. The JS body:

```javascript
(ctxId, authJson) => {
  if (!globalThis.__bidiContextAuth) globalThis.__bidiContextAuth = {};
  try {
    globalThis.__bidiContextAuth[ctxId] = JSON.parse(authJson);
  } catch (_e) {
    globalThis.__bidiContextAuth[ctxId] = {};  // fail-safe
  }
  if (typeof globalThis.__bidiResolveAuth !== 'function') {
    globalThis.__bidiResolveAuth = function(url) {
      const ctx = String(globalThis.__bidiCurrentContext || 'default-context');
      const map = (globalThis.__bidiContextAuth || {})[ctx] || {};
      try {
        const u = new URL(url);
        let origin = u.protocol + '//' + u.hostname;
        if (
          (u.protocol === 'http:'  && u.port && u.port !== '80') ||
          (u.protocol === 'https:' && u.port && u.port !== '443')
        ) origin += ':' + u.port;
        return map[origin] || null;
      } catch (_e) { return null; }
    };
  }
}
```

The install-once pattern follows PR #136's `__bidiResolveCookies`.

### `webdriver/webdriver/bidi_protocol_context_lifecycle.mbt` (modified)

`apply_effective_viewport_to_runtime_context` already pushes the cookie
snapshot. The auth snapshot push happens right after:

```moonbit
flush_pending_cookie_ingest()
set_runtime_context_cookies(ctx_id, cookie_snapshot)
let auth_snapshot = self.serialize_auth_snapshot_for_runtime(ctx_id)
set_runtime_context_authorization(ctx_id, auth_snapshot)
```

### `webdriver/webdriver/bidi_runtime_eval.mbt` (modified, fetch shim)

In `fetchWithPolicy`, immediately after the cookie attach block:

```javascript
if (
  typeof globalThis.__bidiResolveAuth === 'function' &&
  !headers.has('Authorization')
) {
  try {
    const authValue = globalThis.__bidiResolveAuth(resolvedUrl);
    if (authValue) headers.set('Authorization', authValue);
  } catch (_e) { /* swallow — fail open with no header attached */ }
}
```

`headers.has('Authorization')` is the caller-wins guard. The block
mirrors the cookie-attach skip-if-set pattern from PR #136.

### Dispatch routing

Three new entries in the existing BiDi dispatch switch:

- `"crater.setOriginAuthorization"` → `handle_crater_set_origin_authorization`
- `"crater.clearOriginAuthorization"` → `handle_crater_clear_origin_authorization`
- `"crater.listOriginAuthorizations"` → `handle_crater_list_origin_authorizations`

### Lifecycle

`session_profiles.remove(ctx_id)` in
`close_context_and_cleanup` already drops the `Profile` (which owns
`auth_state`). No separate auth cleanup needed.

---

## Data Flow

### 1. Bearer / JWT injection (the happy path)

```
WebDriver client
  │
  │ crater.setOriginAuthorization({
  │   origin: "https://api.example.com",
  │   headerValue: "Bearer eyJhbGc..."
  │ })
  ▼
handle_crater_set_origin_authorization
  │  validate + normalize origin → "https://api.example.com"
  │  validate headerValue (no CRLF / ANSI / oversized)
  │  profile.auth_state.set_origin_header(origin, value)
  │  set_runtime_context_authorization(ctx_id, snapshot_json)
  │    → globalThis.__bidiContextAuth["ctx-1"] =
  │       {"https://api.example.com": "Bearer eyJhbGc..."}
  │  send_success({})
  │
  │ script.evaluate("fetch('https://api.example.com/me')")
  ▼
fetchWithPolicy
  │  __bidiResolveAuth(url) → "Bearer eyJhbGc..."
  │  headers.has('Authorization') → false
  │  headers.set('Authorization', 'Bearer eyJhbGc...')
  │  classify_request → Allow (simple GET cross-origin)
  │  fetch → 200 JSON
  │  validate_actual_response → Ok
  │  return to page
```

### 2. Caller wins

```
script.evaluate("fetch('https://api.example.com/me', {
  headers: { Authorization: 'Bearer page-token' }
})")

fetchWithPolicy
  │  headers seeded with caller's 'Bearer page-token'
  │  __bidiResolveAuth(url) → 'Bearer driver-token'
  │  headers.has('Authorization') → true
  │  → skip; driver token discarded for this request
  │  fetch with caller value
```

### 3. List / clear

```
crater.clearOriginAuthorization({
  origin: "https://api.example.com"
})
  → auth_state.clear_origin_header(origin)
  → __bidiContextAuth["ctx-1"] no longer has that origin
  → next fetch to that origin: __bidiResolveAuth returns null
  → no Authorization attached

crater.listOriginAuthorizations({})
  → response: {origins: [{origin: "https://api.example.com"}]}
  → header values are NOT in the response
```

---

## Error Handling

### Input-side rejection (`crater.setOriginAuthorization`)

| Input | BiDi error |
|---|---|
| `params` not an object | `invalid argument` "params must be an object" |
| Missing `origin` | `invalid argument` "origin must be a string" |
| Non-http/https scheme | `invalid argument` "origin must use http or https scheme" |
| Path / query / fragment present | `invalid argument` "origin must not contain path / query / fragment" |
| Missing `headerValue` | `invalid argument` "headerValue must be a string" |
| Empty `headerValue` | `invalid argument` "headerValue must not be empty" |
| CRLF / NUL / control char in `headerValue` | `invalid argument` "headerValue must not contain control characters" |
| ANSI CSI escape in `headerValue` | `invalid argument` "headerValue must not contain ANSI escape sequences" |
| `headerValue` > 8192 bytes | `invalid argument` "headerValue exceeds 8KB limit" |
| Unknown `context` | `no such frame` "Unknown context: ..." |

### Runtime-side fail-open

`__bidiResolveAuth` swallows URL parse failures, snapshot key
mismatches, and missing-context cases by returning `null`. The fetch
proceeds without an Authorization header.

Snapshot JSON parse failure resets `__bidiContextAuth[ctx_id]` to `{}`
instead of leaving a stale value (fail-safe).

### Secret leak prevention

- `Show` impl on `AuthState` writes `<redacted>` for each entry.
- `listOriginAuthorizations` returns origins only — header values are
  never serialized into BiDi responses.
- `headerValue` rejection of CR/LF prevents Set-Cookie-style or extra-
  header injection that could exfiltrate via log shippers.

### Race / concurrency

MoonBit BiDi handlers run on a single-task async runtime. Set / clear
/ list / fetch attach all execute serially. No locking needed.

---

## Testing Strategy

### Unit tests

`http/profile/auth_wbtest.mbt` (new):

- `AuthState::default()` has empty `origin_headers`.
- `set_origin_header` then `header_for_origin` round-trips.
- Set overwrites prior value for the same origin.
- `clear_origin_header` removes the entry.
- `list_origins` returns sorted origins.
- `Show` impl prints `origin: <redacted>` for each entry; never the
  header value.

### BiDi handler tests

`webdriver/webdriver/bidi_authorization_wbtest.mbt` (new):

- `crater.setOriginAuthorization` happy path — `profile_for_session
  ("ctx-1").auth_state.header_for_origin(origin)` reads the value.
- Re-set on the same origin overwrites.
- `crater.clearOriginAuthorization` removes the entry.
- `crater.listOriginAuthorizations` returns origins only; no header
  values appear anywhere in the response.
- Validation errors for each rejection in the table above.
- Origin normalization: setting
  `https://Example.COM:443` and `https://example.com` are observed as
  the same key.

### Snapshot bridge tests

`webdriver/webdriver/bidi_runtime_authorization_bridge_wbtest.mbt` (new):

- After set, `evaluate_js("globalThis.__bidiResolveAuth(...)")` returns
  the header value.
- After clear, `__bidiResolveAuth` returns `null`.
- URL with path / query resolves against the origin part only.
- Default-port URLs (`:443` / `:80`) match origins set without the
  port.

### Fetch shim integration tests

`bidi_runtime_fetch_wbtest.mbt` (extended):

- Authorization auto-attach on cross-origin GET to the registered
  origin — captured fetch sees `Authorization: Bearer ...`.
- Caller-wins: page-provided `Authorization` survives; driver value is
  discarded for that request.
- Origin mismatch: registered for origin A, fetch to origin B → no
  Authorization on the outgoing request.
- Coexistence with PR #140 Set-Cookie ingest: a single fetch can both
  send Authorization outbound and ingest Set-Cookie inbound.
- Preflight: cross-origin POST with custom header → OPTIONS preflight
  does NOT carry Authorization (per spec, preflight is credentialless);
  the actual POST does.

### pkspec scenario

One new scenario, approved with smoke:

- `protocol.bidi-origin-authorization-injection` (`goal.protocol-compat`)
  - WebDriver can set, list, and clear per-origin Authorization values
    via three `crater.*` commands.
  - The BiDi runtime fetch shim attaches the value to outgoing
    requests for matching origins.
  - Caller-supplied `Authorization` headers survive.
  - Header values are redacted from `Show` output and absent from
    `listOriginAuthorizations` responses.
  - Implementing tests: the four wbtest files above.

Smoke `cmd` (grep-based) verifies:
- `fn AuthState::set_origin_header` in `http/profile/auth.mbt`
- `"crater.setOriginAuthorization"` literal in the dispatch routing
- `__bidiResolveAuth` literal in both `bidi_runtime_context.mbt` and
  `bidi_runtime_eval.mbt`
- `<redacted>` literal in `auth.mbt`

### Optional end-to-end (deferred)

`scripts/fixtures/auth-server.ts` gains a `GET /api/protected`
endpoint that requires `Authorization: Bearer test-jwt-token`. A new
test case in `tests/auth-flow-via-bidi.test.ts` drives the full BiDi
flow: set → fetch protected → expect 200 with welcome data. The e2e
case ships only after all wbtests pass — Phase 5 e2e has known
form-shape gaps documented in PR #138 drafts, so the integration test
must work around them with the cookie-injection-style pattern.

---

## Sequencing

1. `AuthState` struct expansion + unit tests.
2. BiDi handler + dispatch routing + handler-side wbtests.
3. Snapshot bridge + `__bidiResolveAuth` install + bridge wbtest.
4. Fetch shim Authorization attach + integration wbtests.
5. pkspec scenario `protocol.bidi-origin-authorization-injection`
   flipped from draft to approved with smoke.
6. (Optional) e2e fixture endpoint and test case.

Each step is a separate commit. Steps 2-4 can each be their own PR if
review load is heavy; otherwise one PR covering 1-5 with separate
commits is fine.
