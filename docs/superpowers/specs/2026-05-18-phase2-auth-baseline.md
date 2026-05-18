# Phase 2 auth — WPT baseline inventory (2026-05-18)

Tracking issue: [#147](https://github.com/mizchi/crater/issues/147) — `network.continueWithAuth`
and HTTP Basic 401 challenge handling. Phase 1 (origin-scoped `Authorization`
injection) shipped in PR #146.

## TL;DR

After enabling the new `auth` WPT profile, **all 56 auth-related WPT tests already
pass** (4 modules, 0 failures, 0 errors). The reason is not that
`network.continueWithAuth` is spec-compliant on the wire — it is not. The reason
is that the Python adapter (`scripts/crater_bidi_modules.py`) translates every
upstream BiDi command name into Crater's internal action name before it ever
hits the WebSocket.

This makes Phase 2 a **spec-conformance gap, not a functionality gap**. Crater
already has the synthetic fetch pause / `network.authRequired` event / resume
with credentials plumbing wired (it has to, for the adapter-shimmed flow to pass).
What is missing is the on-wire BiDi command surface that a real WebDriver BiDi
client (Playwright, Selenium, a stock `webdriver-bidi` library) would send.

## Run summary

| Module | Tests | Pass | Fail | Errors |
|---|---:|---:|---:|---:|
| `network/auth_required` | 5 | 5 | 0 | 0 |
| `network/continue_with_auth` (action.py + invalid.py) | 45 | 45 | 0 | 0 |
| `network/add_intercept/phase_auth_required.py` | 2 | 2 | 0 | 0 |
| `network/continue_response/credentials.py` | 4 | 4 | 0 | 0 |
| **Total** | **56** | **56** | 0 | 0 |

Run via `npx tsx scripts/wpt-webdriver-runner.ts --profile auth --json /tmp/wpt-auth-baseline.json`
after the new `auth` profile was added to `scripts/wpt-bidi-subset.json`.
Pass-rate: `1.0`. Generated baseline JSON at `/tmp/wpt-auth-baseline.json`.

## Where the spec gap lives

`webdriver/webdriver/bidi_protocol_dispatch_network.mbt` only recognizes
Crater-specific action names. Direct probe against the BiDi server (with
`session.new` then `network.continueWithAuth`) returns:

```
{"id":2,"type":"error","error":"unknown command","message":"Unknown network method: continueWithAuth","stacktrace":""}
```

The WPT tests still pass because `scripts/crater_bidi_modules.py::NetworkModule`
silently rewrites:

| Upstream BiDi method | Crater wire method | Site |
|---|---|---|
| `network.continueWithAuth` | `network.continueAuthRequest` | `crater_bidi_modules.py:405` |
| `network.continueRequest` | `network.continueBlockedRequest` | `crater_bidi_modules.py:379` |
| `network.continueResponse` | `network.continueBlockedResponse` (`mode: continueResponse`) | `crater_bidi_modules.py:390` |
| `network.provideResponse` | `network.continueBlockedResponse` (`mode: provideResponse`) | `crater_bidi_modules.py:417` |
| `network.failRequest` | `network.failBlockedRequest` | `crater_bidi_modules.py:397` |
| `network.addIntercept` | `network.addInterceptId` | `crater_bidi_modules.py:361` |
| `network.addDataCollector` | `network.addDataCollectorId` | `crater_bidi_modules.py:426` |

A Playwright / Selenium client speaking native BiDi would hit `unknown command`
on every one of these — i.e. Phase 2 is non-functional for any real client and
only "passes" through the WPT harness.

The Python adapter also implements `network.continue_with_auth` parameter
validation client-side (`_validate_request_id` etc.). The same checks need to
move into the MoonBit handler, otherwise spec-conformant clients won't get the
expected `invalid argument` / `no such request` errors.

## Missing pieces

Each section lists the tests it would unblock for a real BiDi client (i.e. tests
that currently only pass because of the adapter shim).

### 1. Wire-level `network.continueWithAuth` dispatch — **size L**

**What:** Add `"continueWithAuth"` action to
`webdriver/webdriver/bidi_protocol_dispatch_network.mbt` and a
`handle_network_continue_with_auth` handler. Per the BiDi spec the params
shape is `{request: str, action: "default" | "cancel" | "provideCredentials",
credentials?: {type: "password", username: str, password: str}}`.

The existing `handle_network_continue_auth_request` (in
`bidi_network_intercept_commands.mbt:186-300+`) already implements the
semantics — the new handler can delegate to it after spec-conformant param
validation, OR the existing handler can be re-pointed and the
`continueAuthRequest` action removed entirely once internal callers (wbtests,
adapter) are migrated.

Validation gaps relative to spec — currently caught in Python, must move to
MoonBit:

- `request` must be a non-empty string → `invalid argument` if not string,
  `no such request` if string but unknown.
- `action` must be one of `"default" | "cancel" | "provideCredentials"` →
  `invalid argument` on other strings or non-string. Existing handler already
  rejects non-`"default"`/`"cancel"` after `provideCredentials` branch — close
  enough but the order of checks matters for the test
  `test_params_action_invalid_value` (sends `action="foo"` with a freshly-blocked
  request).
- `credentials` shape: required when action is `provideCredentials`, must have
  `type: "password"`, non-empty `username` and `password` strings.
- Phase guard: request must be blocked at `authRequired` (existing handler
  enforces this).

**Tests unblocked for native clients:** all 45 in `network/continue_with_auth/`
plus the teardown path in `setup_blocked_request` (which is called from every
auth-blocked test in this profile).

### 2. Wire-level `network.continueResponse` with credentials — **size M**

**What:** Add `"continueResponse"` action and a `handle_network_continue_response`
handler to `bidi_protocol_dispatch_network.mbt`. Spec-faithful delegation to
the existing `handle_network_continue_blocked_response` (with `mode:
continueResponse` injected) is the minimum path. Same for `provideResponse`
and `failRequest`.

This is what `network/continue_response/credentials.py` needs to drive against
a real client. Both `test_wrong_credentials` and `test_correct_credentials`
call `bidi_session.network.continue_response(request=..., credentials=...)` —
the adapter currently rewrites to `continueBlockedResponse`.

**Tests unblocked for native clients:** 4 in `network/continue_response/credentials.py`
plus structural alignment for every other `continue_response` WPT path
(`status_code.py`, `cookies.py`, etc., which already pass under
`network-no-auth`).

### 3. Wire-level `network.addIntercept` and friends — **size M**

**What:** Add `"addIntercept"` action that returns the same shape as
`addInterceptId` (likely an alias; the `addInterceptId` name appears to be a
Crater test-only variant). Same applies to `addDataCollector` vs
`addDataCollectorId`.

This is not Phase-2-specific but it is a dependency: `add_intercept` is used
to set up every auth-blocked request, and the WPT auth tests can only run
against a native client once `network.addIntercept` is on the wire.

**Tests unblocked for native clients:** all 56 in this profile (every one of
them uses `add_intercept`), plus everything under `network/add_intercept/**`
in the broader `network-no-auth` profile.

### 4. Credential cache (origin/realm → credentials) — **size S, optional**

**What:** Extend `AuthState` (added in PR #146) with an optional
`{origin, realm} → (username, password)` cache so a second 401 on the same
realm can auto-resend without round-tripping the WebDriver client. Mirrors
the browser's built-in HTTP auth cache.

This is listed in #147 scope point 2 but **is not exercised by any WPT test
in the auth profile** — every test issues a fresh `setup_blocked_request` with
a unique username/password, defeating any cache. It is a UX-for-real-clients
piece, not a WPT-driven piece. Defer unless a Playwright fixture demands it.

**Tests unblocked:** none in WPT. Useful for the Playwright fixture in
`tests/`.

### 5. Digest auth — **size M, deferred**

**What:** Digest challenge parsing + nonce/cnonce/qop response computation in
the fetch shim. #147 scope point 3 explicitly marks this as optional /
deferred. WPT `auth_required.py` only exercises Basic
(`authentication.py?realm=...` returns `WWW-Authenticate: Basic realm=...`).

**Tests unblocked:** none in this profile. Skip until a downstream user reports
Digest as a blocker.

## Suggested implementation order

Driven by **most tests unblocked per piece** (for native clients) and
prerequisite dependencies:

1. **Piece 3** (`addIntercept` alias) — prerequisite for everything else.
   Smallest unit-test surface, smallest risk. (~30 min.)
2. **Piece 1** (`continueWithAuth`) — the core of issue #147. Unblocks 45
   tests on its own and is the spec-conformance headline. The semantics are
   already implemented; this is wire-name + validation work. (~2-3 h.)
3. **Piece 2** (`continueResponse` + `provideResponse` + `failRequest`
   aliases) — closes the broader credential / blocked-request path. (~1-2 h.)
4. **Piece 4** (credential cache) — defer to a real client demand.
5. **Piece 5** (Digest) — defer.

## Suggested Phase 2 sub-tasks (PRs)

- **PR A: `network.continueWithAuth` BiDi command** (issue #147 headline)
  - Pieces 1 + 3 above.
  - New `pkspec` scenario `protocol.bidi-network-continue-with-auth` flips to
    approved.
  - Add wbtests to `bidi_protocol_network_wbtest.mbt` covering each invalid
    branch (`invalid argument` for bad action / phase / credentials shape,
    `no such request` for unknown request id).
  - Update `crater_bidi_modules.py::NetworkModule.continue_with_auth` to send
    the spec name; keep a deprecation comment on the old `continueAuthRequest`
    mapping in case wbtests still reference it.
  - Audit: remove `continueAuthRequest` from
    `bidi_protocol_dispatch_network.mbt` if nothing else dispatches it.

- **PR B: `network.continueResponse` / `provideResponse` / `failRequest`
  aliases**
  - Piece 2 above.
  - Same pattern: add spec names as dispatch actions, delegate to existing
    handlers, port adapter param validation into MoonBit, update
    `crater_bidi_modules.py`.
  - This PR is not strictly part of #147 but is a sibling spec gap exposed by
    the same audit. File a follow-up issue or fold into #147 description.

Out of scope for both PRs: credential cache, Digest auth, multi-profile
partitioning per BiDi `userContext`.
