# Browser Auth + CORS (Profile-backed) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable form-based login flows over WebDriver BiDi by turning Crater's cookie jar on by default, adding spec-compliant SameSite attach + CORS preflight enforcement on the fetch path, and bundling per-session UA / jar / cache / auth state into a single `Profile` value.

**Architecture:** Three new sub-packages under the existing `mizchi/crater-browser-http` module (`profile`, `samesite`, `cors`). `browser/shell/state.mbt` collapses its `cookie_jar` + `http_cache` fields into `state.profile : @http_profile.Profile`. Fetch paths (`navigation_fetch`, `script_fetch`, `external_css_fetch`) route through the new SameSite and CORS gates. The WebDriver `emulation_state` global UA delegates to `profile.user_agent`. End-to-end validation runs against a local Node fixture server in `scripts/fixtures/auth-server.ts`.

**Tech Stack:** MoonBit (browser + webdriver), TypeScript (fixture server + Playwright BiDi e2e), pkfire (task graph), pkspec (scenarios).

---

## File Structure

**New sub-packages (under existing `mizchi/crater-browser-http` module at `./http/`):**

- `http/profile/`
  - `moon.pkg` — imports `cookie_jar`, `cache`
  - `profile.mbt` — `Profile` struct, `Profile::default()`, `Profile::new()`, `effective_user_agent()`
  - `auth.mbt` — `AuthState` placeholder
  - `profile_wbtest.mbt` — unit tests
- `http/samesite/`
  - `moon.pkg` — imports `cookie_jar`
  - `samesite.mbt` — `SiteContext`, `classify_site_context()`, `should_attach_cookie()`
  - `samesite_wbtest.mbt` — unit tests
- `http/cors/`
  - `moon.pkg` — imports `core/string`, `core/double`
  - `cors.mbt` — `CorsDecision`, `PreflightRequest`, `PreflightEntry`, `PreflightCache`, `classify_request()`, `validate_preflight_response()`, `validate_actual_response()`
  - `cors_wbtest.mbt` — unit tests

**Modified MoonBit files:**

- `browser/http/moon.pkg` — add imports for new sub-packages
- `browser/http/top.mbt` — re-export Profile / SameSite / CORS types
- `browser/shell/moon.pkg` — add `@http_profile`, `@samesite`, `@cors` aliases
- `browser/shell/state.mbt` — replace `cookie_jar` / `http_cache` fields with `profile : Profile`; add backward-compat accessors
- `browser/shell/navigation_fetch.mbt` — route cookie attach through `should_attach_cookie` with `is_top_level_navigation=true`
- `browser/shell/script_fetch.mbt` — add CORS classify + preflight + validate around `@http.fetch`
- `browser/shell/external_css_fetch.mbt` — same CORS wiring (NoCors path still bypasses preflight)
- `webdriver/webdriver/bidi_emulation_state.mbt` — global UA delegates to `profile.user_agent`
- `webdriver/webdriver/bidi_emulation_synthetic.mbt` — fallback chain ends at `profile.user_agent` instead of inline default

**New integration test files:**

- `browser/shell/auth_flow_test.mbt` — login → set-cookie → dashboard with stub fetcher
- `browser/shell/cors_enforcement_test.mbt` — cross-origin GET + preflight with stub fetcher
- `webdriver/webdriver/bidi_protocol_auth_wbtest.mbt` — BiDi session jar enabled + UA delegated

**New e2e fixture + test:**

- `scripts/fixtures/auth-server.ts` — Node `node:http` fixture server (login + dashboard + API on two ports)
- `tests/auth-flow-via-bidi.test.ts` — Playwright BiDi end-to-end suite

**Modified workflow / contract files:**

- `flaker.star` — add `auth-flow-via-bidi` task
- `scripts/flaker-batch-plan-core.test.ts` — snapshot update
- `specs/crater.pkl` — three new approved scenarios
- `specs/tasks.Test.pkl` — three new pkspec smoke tests

---

## Phase 1 — Profile type (no behavior change)

### Task 1: Create `http/profile/` package skeleton with AuthState

**Files:**
- Create: `http/profile/moon.pkg`
- Create: `http/profile/auth.mbt`
- Create: `http/profile/profile_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Create `http/profile/profile_wbtest.mbt`:

```moonbit
///|
test "AuthState::default is empty" {
  let state = AuthState::default()
  inspect(state, content="AuthState::{  }")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/profile`
Expected: FAIL — package does not exist.

- [ ] **Step 3: Write moon.pkg and auth.mbt**

Create `http/profile/moon.pkg`:

```
import {
  "mizchi/crater-browser-http/cookie_jar" @cookie_jar,
  "mizchi/crater-browser-http/cache" @cache,
}

warnings = "-unused_package"

supported_targets = "js+native+wasm+wasm-gc"
```

Create `http/profile/auth.mbt`:

```moonbit
///|
/// Placeholder for HTTP auth credentials carried by a Profile.
/// P1: empty. Future expansion: basic_credentials, bearer_tokens.
pub(all) struct AuthState {}

///|
pub fn AuthState::default() -> AuthState {
  AuthState::{  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/profile --update`
Then re-run without `--update` to confirm the snapshot is stable.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add http/profile/
git commit -m "Add http/profile sub-package with AuthState placeholder

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Profile struct with defaults

**Files:**
- Create: `http/profile/profile.mbt`
- Modify: `http/profile/profile_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Append to `http/profile/profile_wbtest.mbt`:

```moonbit
///|
test "Profile::default has jar enabled and no UA override" {
  let p = Profile::default()
  inspect(p.user_agent, content="None")
  inspect(p.cookie_jar.is_enabled(), content="true")
}

///|
test "Profile::new(jar_enabled=false) yields disabled jar" {
  let p = Profile::new(jar_enabled=false)
  inspect(p.cookie_jar.is_enabled(), content="false")
}

///|
test "Profile::new(user_agent=Some(...)) is reflected" {
  let p = Profile::new(user_agent="UA/1.0")
  inspect(p.user_agent, content="Some(\"UA/1.0\")")
}

///|
test "effective_user_agent returns set UA, else None-passthrough" {
  let with = Profile::new(user_agent="UA/2.0")
  inspect(with.effective_user_agent(), content="Some(\"UA/2.0\")")
  let without = Profile::default()
  inspect(without.effective_user_agent(), content="None")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/profile`
Expected: FAIL — `Profile` does not exist.

- [ ] **Step 3: Write profile.mbt**

Create `http/profile/profile.mbt`:

```moonbit
///|
/// Per-session bag of user-agent override, cookie jar, HTTP cache, and
/// auth state. Bundled so layers above can pass a single Profile value
/// instead of threading each field separately. P1 keeps the Profile
/// single per BrowserState; per-userContext partitioning is a P2
/// scenario.
pub(all) struct Profile {
  mut user_agent : String?
  cookie_jar : @cookie_jar.CookieJar
  http_cache : @cache.MemoryCacheBackend
  auth_state : AuthState
}

///|
/// Default Profile: jar enabled, no UA override, fresh in-memory cache.
pub fn Profile::default() -> Profile {
  Profile::{
    user_agent: None,
    cookie_jar: @cookie_jar.CookieJar::new(enabled=true),
    http_cache: @cache.MemoryCacheBackend::new(max_entries=1000),
    auth_state: AuthState::default(),
  }
}

///|
/// Construct a Profile with explicit overrides. WebDriver sessions
/// use this with `jar_enabled=true` (the default) so login flows
/// work without the operator having to opt in.
pub fn Profile::new(
  user_agent? : String,
  jar_enabled~ : Bool = true,
) -> Profile {
  Profile::{
    user_agent,
    cookie_jar: @cookie_jar.CookieJar::new(enabled=jar_enabled),
    http_cache: @cache.MemoryCacheBackend::new(max_entries=1000),
    auth_state: AuthState::default(),
  }
}

///|
/// Returns the override string when set, else None — the caller
/// (typically the WebDriver emulation layer) decides what to fall back
/// to so this sub-package stays free of webdriver-side dependencies.
pub fn Profile::effective_user_agent(self : Profile) -> String? {
  self.user_agent
}
```

Note: this assumes `@cookie_jar.CookieJar::new(enabled~)` exists. If the existing constructor signature differs, audit it first and adapt. If only `CookieJar::new()` exists (returning a disabled jar today), add a one-line follow-up step:

```moonbit
// In http/cookie_jar/<existing file>.mbt: extend new() to accept enabled~ : Bool = false
pub fn CookieJar::new(enabled~ : Bool = false) -> CookieJar { ... }
```

Pick the new default carefully — keeping the existing zero-arg `CookieJar::new()` disabled-by-default preserves callers that haven't been migrated yet. Profile passes `enabled=true` explicitly.

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/profile`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add http/profile/profile.mbt http/profile/profile_wbtest.mbt
git commit -m "Add Profile struct bundling UA / cookie jar / cache / auth state

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Re-export Profile through `browser/http/` facade

**Files:**
- Modify: `browser/http/moon.pkg`
- Modify: `browser/http/top.mbt`

- [ ] **Step 1: Write the failing test**

Add to `browser/top_test.mbt` (or create `browser/http/profile_reexport_test.mbt`):

```moonbit
///|
test "browser/http re-exports Profile" {
  let p = @http.Profile::default()
  inspect(p.cookie_jar.is_enabled(), content="true")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser`
Expected: FAIL — `Profile` not found in `@http`.

- [ ] **Step 3: Wire the facade**

Edit `browser/http/moon.pkg`:

```
import {
  "mizchi/crater-browser-http" @http_impl,
  "mizchi/crater-browser-http/cache" @cache,
  "mizchi/crater-browser-http/cookie_jar" @cookie_jar,
  "mizchi/crater-browser-http/profile" @profile,
}

supported_targets = "js+native+wasm+wasm-gc"
```

Append to `browser/http/top.mbt`:

```moonbit
///|
pub using @profile {type Profile, type AuthState}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon info && moon test -p mizchi/crater-browser`
Expected: PASS. Inspect the diff in `browser/http/pkg.generated.mbti` — should add `pub using ... {type Profile}` and `{type AuthState}` lines and nothing else.

- [ ] **Step 5: Commit**

```bash
git add browser/http/moon.pkg browser/http/top.mbt browser/http/pkg.generated.mbti browser/top_test.mbt
git commit -m "Re-export Profile / AuthState through browser/http facade

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Migrate `BrowserState` to own a `Profile`

**Files:**
- Modify: `browser/shell/state.mbt`
- Modify: `browser/shell/moon.pkg` (if Profile alias not already imported through `@http`)

- [ ] **Step 1: Write the failing test**

Create `browser/shell/profile_state_wbtest.mbt`:

```moonbit
///|
test "BrowserState.profile owns cookie_jar and http_cache" {
  let state = BrowserState::default()
  // existing accessors must still work
  inspect(state.cookie_jar().is_enabled(), content="true")
  // and reach the same jar instance the profile owns
  let same = state.profile.cookie_jar
  state.cookie_jar().set_test_marker("via-accessor")
  inspect(same.test_marker(), content="\"via-accessor\"")
}
```

(`set_test_marker` / `test_marker` are helpers — if they don't exist, replace with `inspect(state.profile.cookie_jar == state.cookie_jar())` once `CookieJar` has structural equality, or with any existing observable side-effect on the jar.)

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: FAIL — `BrowserState.profile` does not exist, and `cookie_jar()` accessor returns the old direct field.

- [ ] **Step 3: Replace fields with `profile`**

Edit `browser/shell/state.mbt`. Find the existing field block (around line 195–200):

```moonbit
// before
mut cookie_jar : @http_cookie_jar.CookieJar
http_cache : @http_cache.MemoryCacheBackend
```

Replace with:

```moonbit
mut profile : @http.Profile
```

Find the constructor (`BrowserState::default()` or `BrowserState::new(...)`, around line 260–270):

```moonbit
// before
cookie_jar: @http_cookie_jar.CookieJar::new(), // disabled by default
image_cache: @terminal_image_cache.ImageCache::new(),
http_cache: @http_cache.MemoryCacheBackend::new(max_entries=1000),
```

Replace with:

```moonbit
profile: @http.Profile::default(),    // jar enabled by default
image_cache: @terminal_image_cache.ImageCache::new(),
```

Append accessors at the end of `state.mbt`:

```moonbit
///|
/// Backward-compat accessor; new code should reach state.profile.cookie_jar directly.
pub fn BrowserState::cookie_jar(self : BrowserState) -> @http_cookie_jar.CookieJar {
  self.profile.cookie_jar
}

///|
/// Backward-compat accessor; new code should reach state.profile.http_cache directly.
pub fn BrowserState::http_cache(self : BrowserState) -> @http_cache.MemoryCacheBackend {
  self.profile.http_cache
}
```

If `browser/shell/moon.pkg` does not already import `@http` (it does — verify), no change is needed; otherwise add the alias.

- [ ] **Step 4: Run test to verify it passes**

Run: `moon check -p src/browser/shell && moon test -p mizchi/crater-browser/shell`
Expected: PASS. Any call site that read `state.cookie_jar` directly as a field (not via the new accessor) must be updated — sweep with `grep -rn 'state\.cookie_jar\b' browser/ webdriver/` and convert to `state.cookie_jar()` or `state.profile.cookie_jar`. Repeat the same for `state.http_cache`.

- [ ] **Step 5: Commit**

```bash
git add browser/shell/state.mbt browser/shell/profile_state_wbtest.mbt
# plus any sweep edits
git commit -m "Collapse BrowserState.{cookie_jar,http_cache} into state.profile

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Delegate `emulation_state` global UA to `profile.user_agent`

**Files:**
- Modify: `webdriver/webdriver/bidi_emulation_state.mbt`
- Modify: `webdriver/webdriver/bidi_emulation_synthetic.mbt`

- [ ] **Step 1: Write the failing test**

Create `webdriver/webdriver/bidi_emulation_profile_wbtest.mbt`:

```moonbit
///|
test "emulation_user_agent_global is mirrored on BrowserState.profile.user_agent" {
  let proto = make_test_bidi_protocol()
  proto.dispatch_request(
    "{\"id\":1,\"method\":\"emulation.setUserAgentOverride\",\"params\":{\"userAgent\":\"UA/test\"}}",
  )
  let state = proto.state_for_session("session-1")
  inspect(state.profile.user_agent, content="Some(\"UA/test\")")
}
```

(`make_test_bidi_protocol` / `state_for_session` are existing helpers; reuse whatever pattern the surrounding `_wbtest.mbt` files use to spin up a stub session.)

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-webdriver/webdriver`
Expected: FAIL — global UA write does not flow into `profile.user_agent`.

- [ ] **Step 3: Reroute the write + fallback**

Edit `webdriver/webdriver/bidi_emulation_state.mbt`:

Locate the `emulation_user_agent_global : String?` field and the function that mutates it (e.g. `set_emulation_user_agent_global(...)`). Replace direct mutation with delegation to `state.profile.user_agent`. The map fields (`emulation_user_agent_by_context`, `emulation_user_agent_by_user_context`) stay unchanged.

```moonbit
// before
self.emulation_user_agent_global = Some(ua)

// after
state.profile.user_agent = Some(ua)
// drop the emulation_user_agent_global field entirely — profile.user_agent is the source of truth
```

Edit `webdriver/webdriver/bidi_emulation_synthetic.mbt` around line 155–170:

```moonbit
// before
fn BidiProtocol::resolve_effective_user_agent(...) -> String {
  ...
  match resolve_chain {
    Some(user_agent) => user_agent
    None => @browser_domain.default_runtime_user_agent()
  }
}

// after
fn BidiProtocol::resolve_effective_user_agent(...) -> String {
  ...
  match resolve_chain_with_profile(state.profile.user_agent) {
    Some(user_agent) => user_agent
    None => @browser_domain.default_runtime_user_agent()
  }
}
```

Where `resolve_chain_with_profile` is the existing function adjusted to read from `state.profile.user_agent` as the lowest-priority fallback (per-context map → per-userContext map → profile.user_agent → None).

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-webdriver/webdriver`
Expected: PASS. Also re-run the existing emulation tests to confirm no regression.

- [ ] **Step 5: Commit**

```bash
git add webdriver/webdriver/bidi_emulation_state.mbt webdriver/webdriver/bidi_emulation_synthetic.mbt webdriver/webdriver/bidi_emulation_profile_wbtest.mbt
git commit -m "Delegate emulation_state global UA to BrowserState.profile.user_agent

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2 — SameSite attach policy + jar default-on

### Task 6: `http/samesite/` — `classify_site_context`

**Files:**
- Create: `http/samesite/moon.pkg`
- Create: `http/samesite/samesite.mbt`
- Create: `http/samesite/samesite_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Create `http/samesite/samesite_wbtest.mbt`:

```moonbit
///|
test "classify_site_context: same eTLD+1 is SameSite" {
  inspect(
    classify_site_context("https://app.example.com", "example.com"),
    content="SameSite",
  )
}

///|
test "classify_site_context: different site is CrossSite" {
  inspect(
    classify_site_context("https://app.example.com", "evil.com"),
    content="CrossSite",
  )
}

///|
test "classify_site_context: localhost is SameSite to itself" {
  inspect(
    classify_site_context("http://localhost:3000", "localhost"),
    content="SameSite",
  )
}

///|
test "classify_site_context: IP literal matches itself" {
  inspect(
    classify_site_context("http://127.0.0.1", "127.0.0.1"),
    content="SameSite",
  )
}

///|
test "classify_site_context: malformed origin falls back to CrossSite" {
  inspect(classify_site_context("not-a-url", "example.com"), content="CrossSite")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/samesite`
Expected: FAIL — package does not exist.

- [ ] **Step 3: Implement classify_site_context**

Create `http/samesite/moon.pkg`:

```
import {
  "mizchi/crater-browser-http/cookie_jar" @cookie_jar,
  "moonbitlang/core/string",
}

warnings = "-unused_package"
supported_targets = "js+native+wasm+wasm-gc"
```

Create `http/samesite/samesite.mbt`:

```moonbit
///|
/// Whether a request origin and a cookie domain live on the same site
/// (same registrable domain, a.k.a. eTLD+1). Used to decide SameSite
/// cookie attach.
pub(all) enum SiteContext {
  SameSite
  CrossSite
} derive(Show, Eq)

///|
/// Conservative eTLD+1 extractor. P1 uses a hard-coded "second-to-last
/// label" heuristic: it correctly handles example.com / *.example.com
/// vs unrelated.com, treats localhost / IP literals as their own site,
/// and falls back to CrossSite on parse failure so we never over-attach.
pub fn classify_site_context(
  request_origin : String,
  cookie_domain : String,
) -> SiteContext {
  match parse_host(request_origin) {
    None => CrossSite
    Some(req_host) => {
      let req_site = registrable_domain(req_host)
      let cookie_site = registrable_domain(cookie_domain)
      if req_site == cookie_site {
        SameSite
      } else {
        CrossSite
      }
    }
  }
}

fn parse_host(origin : String) -> String? {
  // strip scheme
  let after_scheme = match origin.index_of("://") {
    Some(i) => origin.substring(start=i + 3)
    None => return None
  }
  // strip path / query / fragment
  let host_port = after_scheme
    .split("/").next().unwrap_or("")
    .split("?").next().unwrap_or("")
    .split("#").next().unwrap_or("")
  if host_port == "" { return None }
  // strip port
  let host = host_port.split(":").next().unwrap_or(host_port)
  Some(host)
}

fn registrable_domain(host : String) -> String {
  // localhost / IP literals → themselves
  if host == "localhost" || is_ip_literal(host) {
    return host
  }
  let labels = host.split(".").collect()
  let n = labels.length()
  if n <= 2 { return host }
  // last two labels: works for .com / .net / etc.; not PSL-aware but
  // sufficient for fixture testing — PSL upgrade is a separate scenario.
  labels[n - 2] + "." + labels[n - 1]
}

fn is_ip_literal(host : String) -> Bool {
  // IPv4 dotted-quad heuristic; IPv6 bracketed form parsed conservatively.
  if host.has_prefix("[") && host.has_suffix("]") { return true }
  let parts = host.split(".").collect()
  if parts.length() != 4 { return false }
  parts.iter().all(fn(part) {
    if part == "" || part.length() > 3 { return false }
    part.iter().all(fn(c) { c >= '0' && c <= '9' })
  })
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/samesite`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add http/samesite/
git commit -m "Add http/samesite with classify_site_context

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `http/samesite/` — `should_attach_cookie`

**Files:**
- Modify: `http/samesite/samesite.mbt`
- Modify: `http/samesite/samesite_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Append to `http/samesite/samesite_wbtest.mbt`:

```moonbit
///|
test "should_attach_cookie: SameSite=Strict only attaches when same-site" {
  let cookie = test_cookie(name="s", same_site=Strict)
  inspect(should_attach_cookie(cookie, "https://example.com/x", SameSite, true), content="true")
  inspect(should_attach_cookie(cookie, "https://example.com/x", SameSite, false), content="true")
  inspect(should_attach_cookie(cookie, "https://other.com/x", CrossSite, true), content="false")
  inspect(should_attach_cookie(cookie, "https://other.com/x", CrossSite, false), content="false")
}

///|
test "should_attach_cookie: SameSite=Lax attaches on cross-site top-level nav" {
  let cookie = test_cookie(name="l", same_site=Lax)
  inspect(should_attach_cookie(cookie, "https://other.com/x", CrossSite, true), content="true")
  inspect(should_attach_cookie(cookie, "https://other.com/x", CrossSite, false), content="false")
  inspect(should_attach_cookie(cookie, "https://example.com/x", SameSite, true), content="true")
  inspect(should_attach_cookie(cookie, "https://example.com/x", SameSite, false), content="true")
}

///|
test "should_attach_cookie: SameSite=None always attaches" {
  let cookie = test_cookie(name="n", same_site=None_, secure=true)
  inspect(should_attach_cookie(cookie, "https://other.com/x", CrossSite, false), content="true")
  inspect(should_attach_cookie(cookie, "https://other.com/x", CrossSite, true), content="true")
  inspect(should_attach_cookie(cookie, "https://example.com/x", SameSite, true), content="true")
  inspect(should_attach_cookie(cookie, "https://example.com/x", SameSite, false), content="true")
}

// Test helper. `test_cookie` builds a ParsedCookie with sane defaults.
// Adjust call to whatever existing factory exists in @cookie_jar; if
// none exists, add one to the cookie_jar package as part of this task.
fn test_cookie(
  name~ : String,
  same_site~ : @cookie_jar.SameSiteAttr,
  secure~ : Bool = false,
) -> @cookie_jar.ParsedCookie {
  @cookie_jar.ParsedCookie::test_default(name~, same_site~, secure~)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/samesite`
Expected: FAIL — `should_attach_cookie` undefined.

- [ ] **Step 3: Implement should_attach_cookie**

Append to `http/samesite/samesite.mbt`:

```moonbit
///|
/// Decide whether a cookie may be attached to an outgoing request.
/// Follows the WHATWG cookies-bis SameSite table:
///
///   - Strict: only same-site, regardless of navigation kind
///   - Lax: same-site always; cross-site only for top-level navigation
///   - None: always (the cookie itself must be Secure)
pub fn should_attach_cookie(
  cookie : @cookie_jar.ParsedCookie,
  _request_url : String,
  site_context : SiteContext,
  is_top_level_navigation : Bool,
) -> Bool {
  match cookie.same_site() {
    @cookie_jar.SameSiteAttr::Strict =>
      match site_context {
        SameSite => true
        CrossSite => false
      }
    @cookie_jar.SameSiteAttr::Lax =>
      match site_context {
        SameSite => true
        CrossSite => is_top_level_navigation
      }
    @cookie_jar.SameSiteAttr::None_ => true
  }
}
```

If `ParsedCookie::same_site()` is not a public accessor today, add one (one-line getter). If `ParsedCookie::test_default` does not exist, add a `pub fn test_default(...)` helper to `http/cookie_jar/` guarded by a `// @internal: tests only` comment.

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/samesite`
Expected: PASS (12 SameSite × kind × nav cases across 3 tests + the 5 from Task 6 = 8 tests).

- [ ] **Step 5: Commit**

```bash
git add http/samesite/ http/cookie_jar/
git commit -m "Add should_attach_cookie matching WHATWG SameSite table

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Re-export SameSite types through `browser/http/` facade

**Files:**
- Modify: `browser/http/moon.pkg`
- Modify: `browser/http/top.mbt`

- [ ] **Step 1: Write the failing test**

Append to the same re-export test created in Task 3:

```moonbit
///|
test "browser/http re-exports SameSite types" {
  let s : @http.SiteContext = @http.SiteContext::SameSite
  inspect(s, content="SameSite")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser`
Expected: FAIL.

- [ ] **Step 3: Add to facade**

Edit `browser/http/moon.pkg` — append to imports:

```
  "mizchi/crater-browser-http/samesite" @samesite,
```

Edit `browser/http/top.mbt` — append:

```moonbit
///|
pub using @samesite {type SiteContext}

///|
pub fn classify_site_context(
  request_origin : String,
  cookie_domain : String,
) -> SiteContext {
  @samesite.classify_site_context(request_origin, cookie_domain)
}

///|
pub fn should_attach_cookie(
  cookie : @cookie_jar.ParsedCookie,
  request_url : String,
  site_context : SiteContext,
  is_top_level_navigation : Bool,
) -> Bool {
  @samesite.should_attach_cookie(cookie, request_url, site_context, is_top_level_navigation)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon info && moon test -p mizchi/crater-browser`
Expected: PASS. Inspect `browser/http/pkg.generated.mbti` diff: should add only the new re-exports.

- [ ] **Step 5: Commit**

```bash
git add browser/http/moon.pkg browser/http/top.mbt browser/http/pkg.generated.mbti
git commit -m "Re-export SameSite types through browser/http facade

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Wire `navigation_fetch` to use `should_attach_cookie`

**Files:**
- Modify: `browser/shell/navigation_fetch.mbt`
- Create: `browser/shell/navigation_samesite_test.mbt`

- [ ] **Step 1: Write the failing test**

Create `browser/shell/navigation_samesite_test.mbt`:

```moonbit
///|
test "navigation_fetch attaches SameSite=Lax cookie on cross-site top-level nav" {
  let state = BrowserState::default()
  state.profile.cookie_jar.store_from_header(
    "session=abc; Path=/; SameSite=Lax",
    "https://login.example.com",
    true,
  )
  let captured = Ref::new(("", ""))
  let stub_fetcher = fn(url, opts) {
    captured.val = (url, opts.headers.get("Cookie").or_default(""))
    test_ok_response()
  }
  state.with_fetcher(stub_fetcher).navigate("https://app.other.com/dashboard")
  let (url, cookie_header) = captured.val
  inspect(url, content="\"https://app.other.com/dashboard\"")
  inspect(cookie_header, content="\"\"")  // Lax + cross-site + top-level: spec attaches; but cookie was set for login.example.com, not app.other.com, so domain mismatch → not attached anyway
}

///|
test "navigation_fetch does NOT attach SameSite=Strict cookie cross-site" {
  let state = BrowserState::default()
  state.profile.cookie_jar.store_from_header(
    "session=abc; Domain=example.com; Path=/; SameSite=Strict",
    "https://login.example.com",
    true,
  )
  let captured = Ref::new("")
  let stub_fetcher = fn(_url, opts) {
    captured.val = opts.headers.get("Cookie").or_default("")
    test_ok_response()
  }
  state.with_fetcher(stub_fetcher).navigate("https://other.com/x")
  inspect(captured.val, content="\"\"")
}
```

(`test_ok_response`, `with_fetcher` are test helpers; if absent, add them in this task.)

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: FAIL — current path attaches by domain match only, ignoring SameSite.

- [ ] **Step 3: Filter cookies through `should_attach_cookie`**

Edit `browser/shell/navigation_fetch.mbt`. Find the existing cookie attach (around line 11):

```moonbit
// before
self.cookie_jar.get_cookie_header(host, path, is_secure)
```

Replace with a filtered helper that walks `cookie_jar.cookies_for(host, path, is_secure)`, runs each through `should_attach_cookie` with the current request origin and `is_top_level_navigation=true`, and joins the survivors:

```moonbit
fn cookie_header_for_navigation(
  jar : @http.CookieJar,
  request_url : String,
) -> String? {
  let origin = origin_of(request_url)
  let candidates = jar.cookies_for_url(request_url)
  let allowed = candidates.filter(fn(c) {
    let ctx = @http.classify_site_context(origin, c.domain())
    @http.should_attach_cookie(c, request_url, ctx, true)
  })
  if allowed.is_empty() { None }
  else { Some(format_cookie_header(allowed)) }
}
```

Call this from the existing navigation path; `script_fetch` / `external_css_fetch` will get a sibling `cookie_header_for_subresource` (Task 11).

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add browser/shell/navigation_fetch.mbt browser/shell/navigation_samesite_test.mbt
git commit -m "Filter navigation cookie attach through SameSite policy

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Integration test — full login → dashboard flow with stub fetcher

**Files:**
- Create: `browser/shell/auth_flow_test.mbt`

- [ ] **Step 1: Write the failing test**

Create `browser/shell/auth_flow_test.mbt`:

```moonbit
///|
test "login POST sets cookie, dashboard GET attaches it" {
  let state = BrowserState::default()
  let log = Ref::new([] : Array[(String, String)])
  let stub = fn(url, opts) {
    let cookie_in = opts.headers.get("Cookie").or_default("")
    log.val.push((url, cookie_in))
    if url == "https://example.com/login" {
      test_response(
        status=302,
        headers={
          "set-cookie": "session=xyz; Path=/; HttpOnly; SameSite=Lax",
          "location": "https://example.com/dashboard",
        },
      )
    } else {
      test_response(status=200, body="welcome alice")
    }
  }
  state.with_fetcher(stub).navigate("https://example.com/login")
  state.with_fetcher(stub).navigate("https://example.com/dashboard")

  // Login request had no cookie; dashboard request had session=xyz.
  inspect(log.val.length(), content="2")
  inspect(log.val[0], content="(\"https://example.com/login\", \"\")")
  inspect(log.val[1], content="(\"https://example.com/dashboard\", \"session=xyz\")")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: PASS already (Tasks 9 + Profile default jar enabled flipped). If it fails, the gap is real — fix in Task 9.

- [ ] **Step 3: (skip — implementation already complete)**

This task is a checkpoint, not new code. If the test passes, commit. If it fails, return to Task 9 and adjust until this flow goes through end-to-end with a stub fetcher.

- [ ] **Step 4: Run full shell test suite**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add browser/shell/auth_flow_test.mbt
git commit -m "Add integration test: login then dashboard via stub fetcher

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3 — CORS classification + preflight + validation

### Task 11: `http/cors/` package — types + `classify_request`

**Files:**
- Create: `http/cors/moon.pkg`
- Create: `http/cors/cors.mbt`
- Create: `http/cors/cors_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Create `http/cors/cors_wbtest.mbt`:

```moonbit
///|
test "classify_request: simple GET same-origin is Allow" {
  let d = classify_request(
    url="https://example.com/api/x",
    origin="https://example.com",
    mode=Cors,
    method="GET",
    headers={},
  )
  inspect(d, content="Allow")
}

///|
test "classify_request: simple GET cross-origin is Allow (validate at response)" {
  let d = classify_request(
    url="https://api.other.com/x",
    origin="https://example.com",
    mode=Cors,
    method="GET",
    headers={},
  )
  inspect(d, content="Allow")
}

///|
test "classify_request: POST cross-origin with custom header → PreflightRequired" {
  let d = classify_request(
    url="https://api.other.com/upload",
    origin="https://example.com",
    mode=Cors,
    method="POST",
    headers={"X-Csrf": "tok", "Content-Type": "application/json"},
  )
  match d {
    PreflightRequired(req) => {
      inspect(req.url, content="\"https://api.other.com/upload\"")
      inspect(req.method, content="\"POST\"")
      inspect(req.request_headers, content="[\"content-type\", \"x-csrf\"]")
    }
    _ => raise "expected PreflightRequired"
  }
}

///|
test "classify_request: NoCors + custom header → Blocked" {
  let d = classify_request(
    url="https://api.other.com/x",
    origin="https://example.com",
    mode=NoCors,
    method="POST",
    headers={"X-Csrf": "tok"},
  )
  match d {
    Blocked(_) => inspect(true, content="true")
    _ => raise "expected Blocked"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: FAIL — package does not exist.

- [ ] **Step 3: Implement types + classify_request**

Create `http/cors/moon.pkg`:

```
import {
  "mizchi/crater-browser-http" @http_impl,
  "moonbitlang/core/string",
  "moonbitlang/core/double",
}

warnings = "-unused_package"
supported_targets = "js+native+wasm+wasm-gc"
```

Create `http/cors/cors.mbt`:

```moonbit
///|
pub(all) enum CorsDecision {
  Allow
  PreflightRequired(PreflightRequest)
  Blocked(String)
} derive(Show)

///|
pub(all) struct PreflightRequest {
  url : String
  origin : String
  method : String
  request_headers : Array[String]  // lowercase, sorted
}

///|
pub(all) struct PreflightEntry {
  allowed_methods : Array[String]
  allowed_headers : Array[String]
  allow_credentials : Bool
  expires_at_seconds : Double
}

///|
pub struct PreflightCache {
  entries : Map[String, PreflightEntry]
}

///|
pub fn PreflightCache::new() -> PreflightCache {
  PreflightCache::{ entries: {} }
}

///|
/// Returns Allow when no preflight is needed, PreflightRequired with
/// the OPTIONS request descriptor when one is, and Blocked when SOP
/// itself refuses the request (NoCors with non-safe methods or custom
/// headers).
pub fn classify_request(
  url~ : String,
  origin~ : String,
  mode~ : @http_impl.RequestMode,
  method~ : String,
  headers~ : Map[String, String],
) -> CorsDecision {
  let target_origin = origin_of(url)
  let same_origin = target_origin == origin
  if same_origin { return Allow }

  // SOP guard for NoCors
  if mode == @http_impl.RequestMode::NoCors {
    if !is_simple_method(method) {
      return Blocked("NoCors disallows non-simple method " + method)
    }
    let bad = headers.keys().filter(fn(h) { !is_safelisted_header(h) }).collect()
    if !bad.is_empty() {
      return Blocked("NoCors disallows custom header(s): " + bad.join(", "))
    }
    return Allow
  }

  // Cors / SameOrigin: preflight if non-simple
  if is_simple_method(method) && headers.keys().all(is_safelisted_header) {
    return Allow
  }
  let req_headers = headers.keys()
    .map(fn(h) { h.to_lower() })
    .filter(fn(h) { !is_safelisted_header(h) })
    .collect()
  req_headers.sort()
  PreflightRequired(PreflightRequest::{
    url, origin, method, request_headers: req_headers,
  })
}

fn is_simple_method(method : String) -> Bool {
  method == "GET" || method == "HEAD" || method == "POST"
}

fn is_safelisted_header(name : String) -> Bool {
  match name.to_lower() {
    "accept" | "accept-language" | "content-language" | "content-type" => true
    _ => false
  }
}

fn origin_of(url : String) -> String {
  let after_scheme = match url.index_of("://") {
    Some(i) => url.substring(start=i + 3)
    None => return url
  }
  let host_port = after_scheme.split("/").next().unwrap_or("")
  let scheme = url.substring(end=url.index_of("://").unwrap())
  scheme + "://" + host_port
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add http/cors/
git commit -m "Add http/cors with CorsDecision + classify_request

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: `validate_preflight_response`

**Files:**
- Modify: `http/cors/cors.mbt`
- Modify: `http/cors/cors_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Append to `http/cors/cors_wbtest.mbt`:

```moonbit
///|
test "validate_preflight_response: all required headers present → Ok" {
  let req = PreflightRequest::{
    url: "https://api.other.com/x",
    origin: "https://example.com",
    method: "POST",
    request_headers: ["content-type", "x-csrf"],
  }
  let resp = test_preflight_response(
    status=204,
    aca_origin="https://example.com",
    aca_methods="POST",
    aca_headers="content-type, x-csrf",
    aca_credentials="true",
    aca_max_age="600",
  )
  match validate_preflight_response(req, resp) {
    Ok(_) => inspect(true, content="true")
    Err(e) => raise "expected Ok, got Err: " + e
  }
}

///|
test "validate_preflight_response: missing ACA-Origin → Err" {
  let req = PreflightRequest::{
    url: "https://api.other.com/x", origin: "https://example.com",
    method: "POST", request_headers: ["content-type"],
  }
  let resp = test_preflight_response(status=204, aca_methods="POST", aca_headers="content-type")
  match validate_preflight_response(req, resp) {
    Err(_) => inspect(true, content="true")
    _ => raise "expected Err"
  }
}

///|
test "validate_preflight_response: required method not listed → Err" {
  let req = PreflightRequest::{
    url: "https://api.other.com/x", origin: "https://example.com",
    method: "DELETE", request_headers: [],
  }
  let resp = test_preflight_response(
    status=204, aca_origin="https://example.com", aca_methods="GET, POST",
  )
  match validate_preflight_response(req, resp) {
    Err(_) => inspect(true, content="true")
    _ => raise "expected Err"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: FAIL.

- [ ] **Step 3: Implement validate_preflight_response**

Append to `http/cors/cors.mbt`:

```moonbit
///|
pub fn validate_preflight_response(
  request : PreflightRequest,
  response : @http_impl.HttpResponse,
) -> Result[Unit, String] {
  if response.status < 200 || response.status >= 300 {
    return Err("preflight non-2xx status: " + response.status.to_string())
  }
  let aco = response.headers.get("access-control-allow-origin").or_default("")
  if aco != request.origin && aco != "*" {
    return Err("Access-Control-Allow-Origin missing or mismatched: \"" + aco + "\"")
  }
  let allowed_methods = parse_csv(response.headers.get("access-control-allow-methods").or_default(""))
  if !allowed_methods.contains(request.method) && !allowed_methods.contains("*") {
    return Err("Access-Control-Allow-Methods does not include " + request.method)
  }
  let allowed_headers = parse_csv(response.headers.get("access-control-allow-headers").or_default(""))
    .map(fn(s) { s.to_lower() })
  for h in request.request_headers {
    if !allowed_headers.contains(h) && !allowed_headers.contains("*") {
      return Err("Access-Control-Allow-Headers does not include " + h)
    }
  }
  Ok(())
}

fn parse_csv(value : String) -> Array[String] {
  value.split(",").map(fn(s) { s.trim().to_string() })
    .filter(fn(s) { s != "" })
    .collect()
}
```

Also add a test helper `test_preflight_response` to `http/cors/cors_wbtest.mbt`:

```moonbit
fn test_preflight_response(
  status~ : Int,
  aca_origin? : String,
  aca_methods? : String,
  aca_headers? : String,
  aca_credentials? : String,
  aca_max_age? : String,
) -> @http_impl.HttpResponse {
  let h : Map[String, String] = {}
  if aca_origin is Some(v) { h["access-control-allow-origin"] = v }
  if aca_methods is Some(v) { h["access-control-allow-methods"] = v }
  if aca_headers is Some(v) { h["access-control-allow-headers"] = v }
  if aca_credentials is Some(v) { h["access-control-allow-credentials"] = v }
  if aca_max_age is Some(v) { h["access-control-max-age"] = v }
  @http_impl.HttpResponse::{ status, headers: h, body: Bytes::from_array([]) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add http/cors/
git commit -m "Add validate_preflight_response with ACA-Origin / Methods / Headers checks

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: `validate_actual_response` + credential-with-wildcard rule

**Files:**
- Modify: `http/cors/cors.mbt`
- Modify: `http/cors/cors_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Append to `http/cors/cors_wbtest.mbt`:

```moonbit
///|
test "validate_actual_response: same-origin always Ok" {
  let r = test_preflight_response(status=200)
  match validate_actual_response(
    request_url="https://example.com/x",
    origin="https://example.com",
    credentials=Omit,
    response=r,
  ) {
    Ok(_) => inspect(true, content="true")
    Err(e) => raise "expected Ok, got " + e
  }
}

///|
test "validate_actual_response: cross-origin with ACA-Origin echo → Ok" {
  let r = test_preflight_response(status=200, aca_origin="https://example.com")
  match validate_actual_response(
    request_url="https://api.other.com/x",
    origin="https://example.com",
    credentials=Omit,
    response=r,
  ) {
    Ok(_) => inspect(true, content="true")
    Err(_) => raise "expected Ok"
  }
}

///|
test "validate_actual_response: credentials=Include with wildcard → Err" {
  let r = test_preflight_response(status=200, aca_origin="*", aca_credentials="true")
  match validate_actual_response(
    request_url="https://api.other.com/x",
    origin="https://example.com",
    credentials=Include,
    response=r,
  ) {
    Err(_) => inspect(true, content="true")
    _ => raise "expected Err"
  }
}

///|
test "validate_actual_response: credentials=Include needs ACA-Credentials=true" {
  let r = test_preflight_response(status=200, aca_origin="https://example.com")
  match validate_actual_response(
    request_url="https://api.other.com/x",
    origin="https://example.com",
    credentials=Include,
    response=r,
  ) {
    Err(_) => inspect(true, content="true")
    _ => raise "expected Err"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: FAIL.

- [ ] **Step 3: Implement validate_actual_response**

Append to `http/cors/cors.mbt`:

```moonbit
///|
pub fn validate_actual_response(
  request_url~ : String,
  origin~ : String,
  credentials~ : @http_impl.CredentialsMode,
  response~ : @http_impl.HttpResponse,
) -> Result[Unit, String] {
  let target = origin_of(request_url)
  if target == origin { return Ok(()) }     // same-origin: SOP transparent

  let aco = response.headers.get("access-control-allow-origin").or_default("")
  match credentials {
    @http_impl.CredentialsMode::Include => {
      if aco == "*" {
        return Err("credentials=Include but Access-Control-Allow-Origin is wildcard")
      }
      if aco != origin {
        return Err("Access-Control-Allow-Origin mismatch: \"" + aco + "\"")
      }
      let acc = response.headers.get("access-control-allow-credentials").or_default("")
      if acc != "true" {
        return Err("credentials=Include but Access-Control-Allow-Credentials is not true")
      }
    }
    _ => {
      if aco != origin && aco != "*" {
        return Err("Access-Control-Allow-Origin mismatch: \"" + aco + "\"")
      }
    }
  }
  Ok(())
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add http/cors/
git commit -m "Add validate_actual_response including credentials-wildcard rule

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: `PreflightCache::get_or_fetch` with Max-Age expiry

**Files:**
- Modify: `http/cors/cors.mbt`
- Modify: `http/cors/cors_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Append to `http/cors/cors_wbtest.mbt`:

```moonbit
///|
test "PreflightCache hits within Max-Age" {
  let cache = PreflightCache::new()
  let req = PreflightRequest::{
    url: "https://api.other.com/x", origin: "https://example.com",
    method: "POST", request_headers: ["content-type"],
  }
  let calls = Ref::new(0)
  let fetch = fn(_pr) {
    calls.val = calls.val + 1
    test_preflight_response(
      status=204,
      aca_origin="https://example.com",
      aca_methods="POST",
      aca_headers="content-type",
      aca_max_age="600",
    )
  }
  let now = fn() -> Double { 1000.0 }
  cache.get_or_validate(req, now, fetch).unwrap()
  cache.get_or_validate(req, now, fetch).unwrap()
  inspect(calls.val, content="1")
}

///|
test "PreflightCache misses past Max-Age" {
  let cache = PreflightCache::new()
  let req = PreflightRequest::{
    url: "https://api.other.com/x", origin: "https://example.com",
    method: "POST", request_headers: ["content-type"],
  }
  let calls = Ref::new(0)
  let now = Ref::new(1000.0)
  let now_fn = fn() -> Double { now.val }
  let fetch = fn(_pr) {
    calls.val = calls.val + 1
    test_preflight_response(
      status=204, aca_origin="https://example.com",
      aca_methods="POST", aca_headers="content-type", aca_max_age="10",
    )
  }
  cache.get_or_validate(req, now_fn, fetch).unwrap()
  now.val = 1100.0
  cache.get_or_validate(req, now_fn, fetch).unwrap()
  inspect(calls.val, content="2")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: FAIL.

- [ ] **Step 3: Implement get_or_validate**

Append to `http/cors/cors.mbt`:

```moonbit
///|
/// Look up a cached preflight match for `request`. On miss, invokes
/// `fetcher`, validates, and caches. The cache key is origin × url ×
/// method × sorted request_headers; Max-Age is honored.
pub fn PreflightCache::get_or_validate(
  self : PreflightCache,
  request : PreflightRequest,
  now : () -> Double,
  fetcher : (PreflightRequest) -> @http_impl.HttpResponse,
) -> Result[Unit, String] {
  let key = cache_key(request)
  let current = now()
  if self.entries.get(key) is Some(entry) {
    if entry.expires_at_seconds > current {
      if validate_cached_entry(entry, request) is Ok(_) { return Ok(()) }
    }
    self.entries.remove(key)
  }
  let resp = fetcher(request)
  validate_preflight_response(request, resp)?
  let max_age = parse_double_default(
    resp.headers.get("access-control-max-age").or_default(""), 0.0,
  )
  let entry = PreflightEntry::{
    allowed_methods: parse_csv(resp.headers.get("access-control-allow-methods").or_default("")),
    allowed_headers: parse_csv(resp.headers.get("access-control-allow-headers").or_default(""))
      .map(fn(s) { s.to_lower() }),
    allow_credentials:
      resp.headers.get("access-control-allow-credentials").or_default("") == "true",
    expires_at_seconds: current + max_age,
  }
  self.entries[key] = entry
  Ok(())
}

fn cache_key(req : PreflightRequest) -> String {
  req.origin + "|" + req.url + "|" + req.method + "|" + req.request_headers.join(",")
}

fn validate_cached_entry(entry : PreflightEntry, req : PreflightRequest) -> Result[Unit, String] {
  if !entry.allowed_methods.contains(req.method) && !entry.allowed_methods.contains("*") {
    return Err("cached preflight: method " + req.method + " not allowed")
  }
  for h in req.request_headers {
    if !entry.allowed_headers.contains(h) && !entry.allowed_headers.contains("*") {
      return Err("cached preflight: header " + h + " not allowed")
    }
  }
  Ok(())
}

fn parse_double_default(s : String, default : Double) -> Double {
  match @double.from_string(s) {
    Some(d) => d
    None => default
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add http/cors/
git commit -m "Add PreflightCache::get_or_validate with Max-Age expiry

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Re-export CORS types through `browser/http/` facade

**Files:**
- Modify: `browser/http/moon.pkg`
- Modify: `browser/http/top.mbt`

- [ ] **Step 1: Write the failing test**

Append to the shared re-export test file:

```moonbit
///|
test "browser/http re-exports CORS surface" {
  let d = @http.classify_request(
    url="https://example.com/x",
    origin="https://example.com",
    mode=@http.RequestMode::Cors,
    method="GET",
    headers={},
  )
  inspect(d, content="Allow")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser`
Expected: FAIL.

- [ ] **Step 3: Extend facade**

Edit `browser/http/moon.pkg` — append:

```
  "mizchi/crater-browser-http/cors" @cors,
```

Edit `browser/http/top.mbt` — append:

```moonbit
///|
pub using @cors {
  type CorsDecision,
  type PreflightRequest,
  type PreflightEntry,
  type PreflightCache,
}

///|
pub fn classify_request(
  url~ : String,
  origin~ : String,
  mode~ : RequestMode,
  method~ : String,
  headers~ : Map[String, String],
) -> CorsDecision {
  @cors.classify_request(url~, origin~, mode~, method~, headers~)
}

///|
pub fn validate_preflight_response(
  request : PreflightRequest,
  response : HttpResponse,
) -> Result[Unit, String] {
  @cors.validate_preflight_response(request, response)
}

///|
pub fn validate_actual_response(
  request_url~ : String,
  origin~ : String,
  credentials~ : CredentialsMode,
  response~ : HttpResponse,
) -> Result[Unit, String] {
  @cors.validate_actual_response(request_url~, origin~, credentials~, response~)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `moon info && moon test -p mizchi/crater-browser`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add browser/http/moon.pkg browser/http/top.mbt browser/http/pkg.generated.mbti
git commit -m "Re-export CORS types and helpers through browser/http facade

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 16: Add new `HttpError` variants

**Files:**
- Modify: the existing `HttpError` definition (locate with `grep -n "enum HttpError" http/*.mbt browser/http/*.mbt`)
- Modify: callers that exhaustively match on `HttpError` (likely a `bidi_network_*` file)

- [ ] **Step 1: Write the failing test**

Add a one-line check at the end of `http/cors/cors_wbtest.mbt`:

```moonbit
///|
test "HttpError carries CorsBlocked variant" {
  let e : @http_impl.HttpError = @http_impl.HttpError::CorsBlocked("test")
  inspect(e, content="CorsBlocked(\"test\")")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser-http/cors`
Expected: FAIL — variant does not exist.

- [ ] **Step 3: Add variants**

Edit the file holding the `HttpError` enum (likely `http/http.mbt`). Add:

```moonbit
pub(all) enum HttpError {
  ...existing variants...
  CorsBlocked(String)
  PreflightFailed(String)
} derive(Show)
```

Run `moon check` and fix any `unused match arm` / `non-exhaustive` warnings in callers by adding straight-line passthrough mappings — `CorsBlocked` and `PreflightFailed` both surface as a network-layer error similar to existing variants.

- [ ] **Step 4: Run tests**

Run: `moon test -p mizchi/crater-browser-http`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add http/
git commit -m "Add CorsBlocked + PreflightFailed variants to HttpError

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 17: Wire `script_fetch` to the CORS gate

**Files:**
- Modify: `browser/shell/script_fetch.mbt`
- Create: `browser/shell/cors_enforcement_test.mbt`

- [ ] **Step 1: Write the failing test**

Create `browser/shell/cors_enforcement_test.mbt`:

```moonbit
///|
test "cross-origin GET with ACA-Origin echo succeeds" {
  let state = BrowserState::default()
  let stub = fn(_url, _opts) {
    test_response(
      status=200,
      headers={ "access-control-allow-origin": "https://app.example.com" },
      body="ok",
    )
  }
  let r = state.with_fetcher(stub).script_fetch(
    "https://api.other.com/me",
    origin="https://app.example.com",
    mode=@http.RequestMode::Cors,
    method="GET",
    credentials=@http.CredentialsMode::SameOrigin,
    headers={},
  )
  inspect(r.unwrap().status, content="200")
}

///|
test "cross-origin GET without ACA-Origin → CorsBlocked" {
  let state = BrowserState::default()
  let stub = fn(_url, _opts) { test_response(status=200, body="ok") }
  let r = state.with_fetcher(stub).script_fetch(
    "https://api.other.com/me",
    origin="https://app.example.com",
    mode=@http.RequestMode::Cors,
    method="GET",
    credentials=@http.CredentialsMode::SameOrigin,
    headers={},
  )
  match r {
    Err(@http.HttpError::CorsBlocked(_)) => inspect(true, content="true")
    _ => raise "expected CorsBlocked"
  }
}

///|
test "cross-origin POST custom header triggers preflight, cached on repeat" {
  let state = BrowserState::default()
  let calls = Ref::new([] : Array[String])
  let stub = fn(_url, opts) {
    calls.val.push(opts.method)
    if opts.method == "OPTIONS" {
      test_response(
        status=204,
        headers={
          "access-control-allow-origin": "https://app.example.com",
          "access-control-allow-methods": "POST",
          "access-control-allow-headers": "x-csrf, content-type",
          "access-control-max-age": "600",
        },
      )
    } else {
      test_response(
        status=200,
        headers={ "access-control-allow-origin": "https://app.example.com" },
        body="ok",
      )
    }
  }
  let scoped = state.with_fetcher(stub)
  scoped.script_fetch(
    "https://api.other.com/upload",
    origin="https://app.example.com",
    mode=@http.RequestMode::Cors,
    method="POST",
    credentials=@http.CredentialsMode::SameOrigin,
    headers={ "X-Csrf": "tok", "Content-Type": "application/json" },
  ).unwrap()
  scoped.script_fetch(
    "https://api.other.com/upload",
    origin="https://app.example.com",
    mode=@http.RequestMode::Cors,
    method="POST",
    credentials=@http.CredentialsMode::SameOrigin,
    headers={ "X-Csrf": "tok", "Content-Type": "application/json" },
  ).unwrap()
  inspect(calls.val, content="[\"OPTIONS\", \"POST\", \"POST\"]")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: FAIL — script_fetch does not yet gate through CORS.

- [ ] **Step 3: Add CORS gate to script_fetch**

Edit `browser/shell/script_fetch.mbt`. The existing function shape is roughly `fn script_fetch(url, options) -> HttpResponse`. Wrap it:

```moonbit
pub fn BrowserState::script_fetch(
  self : BrowserState,
  url : String,
  origin~ : String,
  mode~ : @http.RequestMode,
  method~ : String,
  credentials~ : @http.CredentialsMode,
  headers~ : Map[String, String],
  body? : Bytes,
) -> Result[@http.HttpResponse, @http.HttpError] {
  match @http.classify_request(url~, origin~, mode~, method~, headers~) {
    Blocked(reason) => return Err(@http.HttpError::CorsBlocked(reason))
    PreflightRequired(req) => {
      let pr = self.profile_preflight_cache()
      pr.get_or_validate(req, @http.now_seconds, fn(p) {
        self.raw_fetch(p.url, options=preflight_options(p))
      }) match {
        Err(reason) => return Err(@http.HttpError::PreflightFailed(reason))
        Ok(_) => ()
      }
    }
    Allow => ()
  }
  let resp = self.raw_fetch(url, options=actual_options(method, headers, body))?
  match @http.validate_actual_response(
    request_url=url, origin=origin, credentials=credentials, response=resp,
  ) {
    Err(reason) => Err(@http.HttpError::CorsBlocked(reason))
    Ok(_) => Ok(resp)
  }
}
```

Add `profile_preflight_cache()` to `BrowserState` (lazy field; create on first access and stash on `state.profile` or a sibling state field). If `state.profile` should not own UI-specific fields, put `preflight_cache : PreflightCache` directly on `BrowserState` (same lifetime as profile). Update Task 4's state change to include `preflight_cache: @http.PreflightCache::new()` in the constructor.

- [ ] **Step 4: Run test to verify it passes**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add browser/shell/script_fetch.mbt browser/shell/state.mbt browser/shell/cors_enforcement_test.mbt
git commit -m "Gate script_fetch through CORS classify + preflight + validate

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 18: Wire `external_css_fetch` to the CORS gate

**Files:**
- Modify: `browser/shell/external_css_fetch.mbt`

- [ ] **Step 1: Write the failing test**

Append to `browser/shell/cors_enforcement_test.mbt`:

```moonbit
///|
test "external_css_fetch NoCors path bypasses preflight" {
  let state = BrowserState::default()
  let calls = Ref::new(0)
  let stub = fn(_url, opts) {
    calls.val = calls.val + 1
    inspect(opts.method, content="\"GET\"")  // never OPTIONS
    test_response(status=200, body="body { }")
  }
  state.with_fetcher(stub).external_css_fetch(
    "https://cdn.other.com/site.css",
    origin="https://example.com",
  ).unwrap()
  inspect(calls.val, content="1")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: PASS already (NoCors mode is the existing default for external CSS). If a regression has crept in (e.g. external_css_fetch flipped to Cors mode after Task 17), this test catches it.

- [ ] **Step 3: Ensure mode=NoCors on external CSS path**

Confirm `browser/shell/external_css_fetch.mbt` still constructs `FetchOptions::{ ..default(), mode: @http.RequestMode::NoCors }`. If yes, no change. If no, restore it.

- [ ] **Step 4: Run tests**

Run: `moon test -p mizchi/crater-browser/shell`
Expected: PASS.

- [ ] **Step 5: Commit (skip if no diff)**

```bash
git add browser/shell/cors_enforcement_test.mbt
git commit -m "Lock external_css_fetch NoCors regression

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4 — BiDi errorText propagation

### Task 19: Map `HttpError::{CorsBlocked, PreflightFailed}` to BiDi `errorText`

**Files:**
- Modify: `webdriver/webdriver/bidi_network_event_payloads.mbt` (or wherever `errorText` is composed; locate via grep)
- Create: `webdriver/webdriver/bidi_network_cors_wbtest.mbt`

- [ ] **Step 1: Write the failing test**

Create `webdriver/webdriver/bidi_network_cors_wbtest.mbt`:

```moonbit
///|
test "CorsBlocked surfaces as BiDi errorText with reason" {
  let proto = make_test_bidi_protocol_with_synthetic_fetch(
    fetch_outcome=FetchOutcome::Err(@http.HttpError::CorsBlocked("missing ACA-Origin")),
  )
  let event = proto.last_emitted_event_for(method="network.responseCompleted")
  let json = event.payload.stringify()
  inspect(json.contains("\"errorText\":\"CORS: missing ACA-Origin\""), content="true")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `moon test -p mizchi/crater-webdriver/webdriver`
Expected: FAIL — payload does not include `errorText` for the new variant.

- [ ] **Step 3: Wire mapping**

In the BiDi network error composer, add:

```moonbit
fn error_text_of(e : @http.HttpError) -> String {
  match e {
    @http.HttpError::CorsBlocked(reason) => "CORS: " + reason
    @http.HttpError::PreflightFailed(reason) => "CORS preflight: " + reason
    ...existing variants...
  }
}
```

Update the call site that builds `responseCompleted` / `fetchError` payloads to populate `errorText` from `error_text_of`.

- [ ] **Step 4: Run tests**

Run: `moon test -p mizchi/crater-webdriver/webdriver`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add webdriver/webdriver/
git commit -m "Propagate CorsBlocked / PreflightFailed reason into BiDi errorText

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5 — Node fixture + Playwright BiDi e2e

### Task 20: `scripts/fixtures/auth-server.ts`

**Files:**
- Create: `scripts/fixtures/auth-server.ts`
- Create: `scripts/fixtures/auth-server.test.ts`

- [ ] **Step 1: Write the failing test**

Create `scripts/fixtures/auth-server.test.ts`:

```typescript
import { test, expect } from "vitest";
import { startAuthServer } from "./auth-server.ts";

test("login + dashboard round-trip", async () => {
  const { url, stop } = await startAuthServer({ port: 0 });
  try {
    const login = await fetch(`${url}/login`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ user: "alice", pass: "wonderland" }),
      redirect: "manual",
    });
    expect(login.status).toBe(302);
    const cookie = login.headers.get("set-cookie")!;
    expect(cookie).toContain("session=");

    const dashboard = await fetch(`${url}/dashboard`, {
      headers: { cookie },
    });
    expect(dashboard.status).toBe(200);
    expect(await dashboard.text()).toContain("welcome alice");

    const noCookie = await fetch(`${url}/dashboard`);
    expect(noCookie.status).toBe(401);
  } finally {
    await stop();
  }
});

test("cross-origin /api/me requires ACA-Origin and ACA-Credentials", async () => {
  const { url, stop, apiUrl, apiStop } = await startAuthServer({ port: 0, apiPort: 0 });
  try {
    const preflight = await fetch(`${apiUrl}/me`, {
      method: "OPTIONS",
      headers: {
        origin: url,
        "access-control-request-method": "GET",
        "access-control-request-headers": "x-csrf",
      },
    });
    expect(preflight.headers.get("access-control-allow-origin")).toBe(url);
    expect(preflight.headers.get("access-control-allow-credentials")).toBe("true");
  } finally {
    await stop();
    await apiStop();
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm exec vitest run scripts/fixtures/auth-server.test.ts`
Expected: FAIL — module does not exist.

- [ ] **Step 3: Implement the fixture server**

Create `scripts/fixtures/auth-server.ts`:

```typescript
import http, { IncomingMessage, ServerResponse } from "node:http";
import { AddressInfo } from "node:net";

type StartOptions = { port?: number; apiPort?: number };
type StartResult = {
  url: string;
  stop: () => Promise<void>;
  apiUrl: string;
  apiStop: () => Promise<void>;
};

const SESSIONS = new Map<string, string>();   // session-id → username

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", c => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function parseCookies(header: string | undefined): Map<string, string> {
  const out = new Map<string, string>();
  if (!header) return out;
  for (const piece of header.split(";")) {
    const [k, v] = piece.trim().split("=");
    if (k && v) out.set(k, v);
  }
  return out;
}

function loginPageHtml(): string {
  return `<!DOCTYPE html><html><body>
<form id="loginForm" method="POST" action="/login">
  <input id="user" name="user" />
  <input id="pass" name="pass" type="password" />
  <button id="submit" type="submit">Login</button>
</form></body></html>`;
}

function handleApp(req: IncomingMessage, res: ServerResponse): Promise<void> {
  return (async () => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
    if (url.pathname === "/login" && req.method === "GET") {
      res.writeHead(200, { "content-type": "text/html" });
      res.end(loginPageHtml());
      return;
    }
    if (url.pathname === "/login" && req.method === "POST") {
      const body = await readBody(req);
      const params = new URLSearchParams(body);
      if (params.get("user") === "alice" && params.get("pass") === "wonderland") {
        const id = `s_${Math.random().toString(36).slice(2)}`;
        SESSIONS.set(id, "alice");
        res.writeHead(302, {
          "set-cookie": `session=${id}; Path=/; HttpOnly; SameSite=Lax`,
          location: "/dashboard",
        });
        res.end();
      } else {
        res.writeHead(401);
        res.end("bad credentials");
      }
      return;
    }
    if (url.pathname === "/dashboard") {
      const cookies = parseCookies(req.headers.cookie);
      const sid = cookies.get("session");
      const who = sid ? SESSIONS.get(sid) : undefined;
      if (who) {
        res.writeHead(200, { "content-type": "text/html" });
        res.end(`<html><body>welcome ${who}</body></html>`);
      } else {
        res.writeHead(401);
        res.end("unauthenticated");
      }
      return;
    }
    res.writeHead(404);
    res.end();
  })();
}

function handleApi(req: IncomingMessage, res: ServerResponse, appOrigin: string): void {
  const origin = req.headers.origin ?? "";
  const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
  if (url.pathname === "/me") {
    if (req.method === "OPTIONS") {
      res.writeHead(204, {
        "access-control-allow-origin": appOrigin,
        "access-control-allow-methods": "GET, POST",
        "access-control-allow-headers": "x-csrf, content-type",
        "access-control-allow-credentials": "true",
        "access-control-max-age": "600",
      });
      res.end();
      return;
    }
    if (origin === appOrigin) {
      res.writeHead(200, {
        "content-type": "application/json",
        "access-control-allow-origin": appOrigin,
        "access-control-allow-credentials": "true",
      });
      res.end(JSON.stringify({ user: "alice" }));
    } else {
      // Deliberately omit ACA headers so Crater's CORS gate blocks.
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ user: "alice" }));
    }
    return;
  }
  res.writeHead(404);
  res.end();
}

export async function startAuthServer(opts: StartOptions = {}): Promise<StartResult> {
  const appServer = http.createServer((req, res) => { handleApp(req, res).catch(() => res.end()); });
  await new Promise<void>(r => appServer.listen(opts.port ?? 0, "127.0.0.1", r));
  const appPort = (appServer.address() as AddressInfo).port;
  const appUrl = `http://127.0.0.1:${appPort}`;

  const apiServer = http.createServer((req, res) => handleApi(req, res, appUrl));
  await new Promise<void>(r => apiServer.listen(opts.apiPort ?? 0, "127.0.0.1", r));
  const apiPort = (apiServer.address() as AddressInfo).port;
  const apiUrl = `http://127.0.0.1:${apiPort}`;

  return {
    url: appUrl,
    apiUrl,
    stop: () => new Promise(r => appServer.close(() => r())),
    apiStop: () => new Promise(r => apiServer.close(() => r())),
  };
}
```

The hard-coded `alice / wonderland` credentials live in a test fixture; add an inline secretlint suppression comment if the pre-push hook flags it:

```typescript
// secretlint-disable-next-line no-credentials
const VALID = { user: "alice", pass: "wonderland" };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm exec vitest run scripts/fixtures/auth-server.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/fixtures/auth-server.ts scripts/fixtures/auth-server.test.ts
git commit -m "Add Node fixture server for auth + CORS e2e tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 21: `tests/auth-flow-via-bidi.test.ts` — login flow

**Files:**
- Create: `tests/auth-flow-via-bidi.test.ts`

- [ ] **Step 1: Write the failing test**

Create `tests/auth-flow-via-bidi.test.ts`:

```typescript
import { test, expect } from "@playwright/test";
import { startAuthServer } from "../scripts/fixtures/auth-server.ts";
import { connectCraterBidi } from "./helpers/crater-bidi.ts";

test.describe("auth flow via BiDi", () => {
  test("login then dashboard", async () => {
    const fixture = await startAuthServer();
    const session = await connectCraterBidi();
    try {
      await session.browsingContext.navigate({ url: `${fixture.url}/login` });
      await session.script.evaluate({
        expression: `
          document.querySelector('#user').value = 'alice';
          document.querySelector('#pass').value = 'wonderland';
          document.forms[0].submit();
        `,
      });
      // wait for post-submit navigation
      await session.events.waitFor("browsingContext.load");
      const body = await session.script.evaluate({
        expression: `document.body.innerText`,
      });
      expect(body).toContain("welcome alice");

      const cookies = await session.storage.getCookies({
        partition: { type: "context", context: session.contextId },
      });
      expect(cookies.find(c => c.name === "session")).toBeTruthy();
    } finally {
      await session.end();
      await fixture.stop();
      await fixture.apiStop();
    }
  });
});
```

(`connectCraterBidi` is a helper that follows the same pattern as existing `tests/helpers/crater-vrt.ts`; reuse the closest existing helper or add a sibling.)

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm exec playwright test tests/auth-flow-via-bidi.test.ts`
Expected: FAIL — helper does not exist or session does not preserve cookies.

- [ ] **Step 3: Add the BiDi helper**

If `tests/helpers/crater-bidi.ts` does not already exist, create it as a thin wrapper around the existing BiDi connection code used by `tests/bidi-e2e.test.ts`. Mirror that file's connection / teardown shape; expose a typed `session` object with `browsingContext.navigate`, `script.evaluate`, `events.waitFor`, `storage.getCookies`, `contextId`, `end`.

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm exec playwright test tests/auth-flow-via-bidi.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/auth-flow-via-bidi.test.ts tests/helpers/crater-bidi.ts
git commit -m "Add Playwright BiDi e2e: form login persists cookie across navigation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 22: e2e — cross-origin XHR preflight

**Files:**
- Modify: `tests/auth-flow-via-bidi.test.ts`

- [ ] **Step 1: Write the failing test**

Append to `tests/auth-flow-via-bidi.test.ts`:

```typescript
test("cross-origin XHR preflight succeeds with ACA-Origin echo", async () => {
  const fixture = await startAuthServer();
  const session = await connectCraterBidi();
  try {
    await session.browsingContext.navigate({ url: `${fixture.url}/login` });
    // Skip form, inject session cookie directly via storage.setCookie
    await session.storage.setCookie({
      cookie: {
        domain: "127.0.0.1", name: "session",
        value: { type: "string", value: "s_test" },
        path: "/", sameSite: "lax",
      },
      partition: { type: "context", context: session.contextId },
    });

    const result = await session.script.evaluate({
      expression: `
        fetch('${fixture.apiUrl}/me', {
          credentials: 'include',
          headers: { 'X-Csrf': 'tok', 'Content-Type': 'application/json' },
        }).then(r => r.status)
      `,
      awaitPromise: true,
    });
    expect(result).toBe(200);
  } finally {
    await session.end();
    await fixture.stop();
    await fixture.apiStop();
  }
});

test("cross-origin XHR without ACA-Origin is blocked with errorText", async () => {
  const fixture = await startAuthServer();
  const session = await connectCraterBidi();
  try {
    await session.browsingContext.navigate({ url: `https://example.com/blank` });
    const errors: string[] = [];
    session.events.on("network.fetchError", e => errors.push(e.errorText));

    await session.script.evaluate({
      expression: `
        fetch('${fixture.apiUrl}/me').catch(() => null)
      `,
      awaitPromise: true,
    });
    expect(errors.some(t => /CORS/.test(t))).toBe(true);
  } finally {
    await session.end();
    await fixture.stop();
    await fixture.apiStop();
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm exec playwright test tests/auth-flow-via-bidi.test.ts -g "cross-origin XHR"`
Expected: FAIL if Tasks 17–19 missed any wiring; PASS if everything is in place. Treat this task as the integration checkpoint.

- [ ] **Step 3: (no new code)**

If failing, trace the error message back to its source (`CorsBlocked` reason vs. `PreflightFailed` reason vs. missing event emission) and patch the failing layer. If passing, proceed.

- [ ] **Step 4: Run full e2e**

Run: `pnpm exec playwright test tests/auth-flow-via-bidi.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/auth-flow-via-bidi.test.ts
git commit -m "Add e2e: cross-origin XHR preflight + blocked-without-ACAO

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 23: e2e — SameSite=Lax cookie is not attached cross-site

**Files:**
- Modify: `tests/auth-flow-via-bidi.test.ts`

- [ ] **Step 1: Write the failing test**

Append:

```typescript
test("SameSite=Lax cookie is not attached to cross-site subresource", async () => {
  const fixture = await startAuthServer();
  const session = await connectCraterBidi();
  try {
    await session.browsingContext.navigate({ url: `${fixture.url}/login` });
    await session.storage.setCookie({
      cookie: {
        domain: "127.0.0.1", name: "session",
        value: { type: "string", value: "s_test" },
        path: "/", sameSite: "lax",
      },
      partition: { type: "context", context: session.contextId },
    });

    // From the app origin, fetch the API origin (cross-site).
    const sentCookie = await session.script.evaluate({
      expression: `
        fetch('${fixture.apiUrl}/me', { credentials: 'include' })
          .then(r => r.headers.get('x-echo-cookie') ?? '')
      `,
      awaitPromise: true,
    });
    expect(sentCookie).toBe("");
  } finally {
    await session.end();
    await fixture.stop();
    await fixture.apiStop();
  }
});
```

Update the fixture server's `/me` handler to echo the cookie header it sees:

```typescript
res.writeHead(200, {
  "content-type": "application/json",
  "access-control-allow-origin": appOrigin,
  "access-control-allow-credentials": "true",
  "x-echo-cookie": req.headers.cookie ?? "",
});
```

(That extra header must be added to `access-control-expose-headers` for the JS read to succeed: `access-control-expose-headers: x-echo-cookie`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm exec playwright test tests/auth-flow-via-bidi.test.ts -g "SameSite=Lax"`
Expected: FAIL if SameSite filter is not wired into `script_fetch` cookie attach path. (Task 9 wired navigation_fetch; this task may surface a gap in subresource attach. If so, mirror the navigation_fetch change into the subresource fetch helper used by script_fetch.)

- [ ] **Step 3: Mirror SameSite filter into subresource cookie attach**

Patch wherever `script_fetch` resolves the outgoing `Cookie:` header. Reuse `cookie_header_for_subresource` (the sibling of `cookie_header_for_navigation` from Task 9):

```moonbit
fn cookie_header_for_subresource(
  jar : @http.CookieJar,
  request_url : String,
) -> String? {
  let origin = origin_of(request_url)
  let allowed = jar.cookies_for_url(request_url).filter(fn(c) {
    let ctx = @http.classify_site_context(origin, c.domain())
    @http.should_attach_cookie(c, request_url, ctx, false /* not top-level */)
  })
  if allowed.is_empty() { None }
  else { Some(format_cookie_header(allowed)) }
}
```

Call from `script_fetch` before invoking `raw_fetch`.

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm exec playwright test tests/auth-flow-via-bidi.test.ts`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add browser/shell/script_fetch.mbt scripts/fixtures/auth-server.ts tests/auth-flow-via-bidi.test.ts
git commit -m "Honor SameSite=Lax on subresource fetch: cross-site cookie not attached

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 24: Register `auth-flow-via-bidi` in flaker

**Files:**
- Modify: `flaker.star`
- Modify: `scripts/flaker-batch-plan-core.test.ts`

- [ ] **Step 1: Write the failing test**

Edit `scripts/flaker-batch-plan-core.test.ts`. Locate the array of expected task IDs (the one updated in PRs #126 and #127); insert `"auth-flow-via-bidi"` alphabetically:

```typescript
expect(tasks).toEqual([
  "auth-flow-via-bidi",
  "bidi-e2e",
  // ...
]);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm exec vitest run scripts/flaker-batch-plan-core.test.ts`
Expected: FAIL — task ID not in flaker.

- [ ] **Step 3: Add task to flaker.star**

Append to `flaker.star`:

```python
task(
  id="auth-flow-via-bidi",
  node="browser",
  cmd=["pnpm", "exec", "playwright", "test", "tests/auth-flow-via-bidi.test.ts"],
  srcs=[
    "browser/shell/**",
    "browser/http/**",
    "http/**",
    "webdriver/webdriver/**",
    "scripts/fixtures/**",
    "tests/auth-flow-via-bidi.test.ts",
    "tests/helpers/crater-bidi.ts",
  ],
  needs=["playwright-adapter"],
  trigger="auto",
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm exec vitest run scripts/flaker-batch-plan-core.test.ts`
Expected: PASS. Also run `pkf run flaker-check` to confirm metadata validity.

- [ ] **Step 5: Commit**

```bash
git add flaker.star scripts/flaker-batch-plan-core.test.ts
git commit -m "Register auth-flow-via-bidi task in flaker

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 6 — pkspec scenarios

### Task 25: Add three approved scenarios + pkspec smoke tests

**Files:**
- Modify: `specs/crater.pkl`
- Modify: `specs/tasks.Test.pkl`

- [ ] **Step 1: Write the failing test**

Append to `specs/tasks.Test.pkl`:

```pkl
  new {
    name = "cookie_jar_default_on_webdriver_session"
    description =
      "WebDriver-driven sessions start with the cookie jar enabled by default so login flows persist Set-Cookie across navigations."
    tags { "auth"; "cookies"; "browser" }
    specRef { "compat.cookie-jar-default-on-webdriver" }
    workdir = ".."
    cmd =
      "bash -lc 'set -e; grep -Fq -- \"jar_enabled~ : Bool = true\" http/profile/profile.mbt; grep -Fq -- \"@http.Profile::default()\" browser/shell/state.mbt'"
  }
  new {
    name = "cors_preflight_enforcement_wired"
    description =
      "script_fetch routes through classify_request + PreflightCache + validate_actual_response, surfacing failures as HttpError::CorsBlocked / PreflightFailed and BiDi errorText."
    tags { "cors"; "fetch"; "browser" }
    specRef { "compat.cors-preflight-enforcement" }
    workdir = ".."
    cmd =
      "bash -lc 'set -e; test -f http/cors/cors.mbt; grep -Fq -- \"classify_request\" browser/shell/script_fetch.mbt; grep -Fq -- \"validate_actual_response\" browser/shell/script_fetch.mbt; grep -Fq -- \"CorsBlocked\" webdriver/webdriver/bidi_network_event_payloads.mbt || grep -rFlq -- \"CorsBlocked\" webdriver/webdriver/'"
  }
  new {
    name = "samesite_attach_policy_enforced"
    description =
      "navigation_fetch and script_fetch filter outgoing cookies through should_attach_cookie with top-level vs subresource discrimination."
    tags { "cookies"; "samesite"; "browser" }
    specRef { "compat.samesite-attach-policy" }
    workdir = ".."
    cmd =
      "bash -lc 'set -e; test -f http/samesite/samesite.mbt; grep -Fq -- \"should_attach_cookie\" browser/shell/navigation_fetch.mbt; grep -Fq -- \"should_attach_cookie\" browser/shell/script_fetch.mbt'"
  }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pkf run spec-check`
Expected: FAIL — scenarios `compat.cookie-jar-default-on-webdriver`, `compat.cors-preflight-enforcement`, `compat.samesite-attach-policy` are not declared in `specs/crater.pkl`.

- [ ] **Step 3: Add scenarios**

Append to the `scenarios { ... }` block of `specs/crater.pkl` (alongside the other `compat.*-baseline` scenarios, around line 380):

```pkl
  new {
    id = "compat.cookie-jar-default-on-webdriver"
    name = "WebDriver sessions enable the cookie jar by default"
    description =
      "BrowserState.profile is constructed via Profile::default() which enables the cookie jar; WebDriver-driven login flows persist Set-Cookie across navigations without operator opt-in. Implemented by http/profile/profile.mbt and browser/shell/state.mbt; covered by browser/shell/auth_flow_test.mbt and tests/auth-flow-via-bidi.test.ts."
    tags { "auth"; "cookies"; "browser"; "webdriver" }
    severity = "major"
    reviewStatus = "approved"
    contributes { "goal.protocol-compat"; "goal.dom-compat" }
  }
  new {
    id = "compat.cors-preflight-enforcement"
    name = "script_fetch enforces CORS classification, preflight, and response validation"
    description =
      "script_fetch routes through http/cors/classify_request, runs OPTIONS preflight via PreflightCache when required, and validates Access-Control-Allow-* on the actual response. Violations surface as HttpError::CorsBlocked / PreflightFailed and as BiDi network errorText. Covered by browser/shell/cors_enforcement_test.mbt and tests/auth-flow-via-bidi.test.ts."
    tags { "cors"; "fetch"; "browser" }
    severity = "major"
    reviewStatus = "approved"
    contributes { "goal.dom-compat" }
  }
  new {
    id = "compat.samesite-attach-policy"
    name = "Outgoing cookie attach matches the WHATWG SameSite table"
    description =
      "navigation_fetch and script_fetch filter outgoing cookies through http/samesite/should_attach_cookie with top-level vs subresource discrimination. SameSite=Strict only attaches same-site; SameSite=Lax attaches cross-site only on top-level navigations; SameSite=None always attaches. Covered by http/samesite/samesite_wbtest.mbt and tests/auth-flow-via-bidi.test.ts."
    tags { "cookies"; "samesite"; "browser" }
    severity = "major"
    reviewStatus = "approved"
    contributes { "goal.dom-compat" }
  }
```

- [ ] **Step 4: Run tests to verify**

Run in order:
- `pkf run spec-check` — all 30 declared specs implemented.
- `pkf run spec-lint` — clean.
- `pkf run spec-test` — 30 passed.

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add specs/crater.pkl specs/tasks.Test.pkl
git commit -m "Approve auth/CORS scenarios with pkspec smoke tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (planner)

**1. Spec coverage:**

- `Profile` type + `BrowserState.profile`: Tasks 1, 2, 4.
- Profile re-export through facade: Task 3.
- `emulation_state` global UA → `profile.user_agent`: Task 5.
- `samesite` package: Tasks 6, 7. Re-export: Task 8.
- `navigation_fetch` SameSite filter: Task 9. Subresource filter: Task 23.
- Integration login test (stub fetcher): Task 10.
- `cors` package types + classify: Task 11. validate_preflight: 12. validate_actual: 13. PreflightCache: 14. Facade re-export: 15.
- HttpError variants: Task 16. BiDi errorText mapping: Task 19.
- `script_fetch` CORS gate: Task 17. `external_css_fetch` regression lock: Task 18.
- Node fixture server: Task 20.
- e2e tests (login / preflight / SameSite): Tasks 21, 22, 23.
- flaker task: Task 24.
- pkspec scenarios: Task 25.

Every section of the spec maps to at least one task.

**2. Placeholder scan:** No TBD / TODO / "handle edge cases" / "similar to Task N" patterns. Code blocks present in every implementation step. Test helpers (`test_response`, `test_preflight_response`, `connectCraterBidi`, `make_test_bidi_protocol_with_synthetic_fetch`, `test_cookie`) are named explicitly with a note in the task to reuse the closest existing pattern or add a sibling helper.

**3. Type consistency:**

- `Profile { user_agent : String?, cookie_jar, http_cache, auth_state }` — same shape in Tasks 2, 3, 4, 17.
- `CorsDecision::{Allow, PreflightRequired, Blocked}` — same in Tasks 11, 17, 19.
- `PreflightRequest { url, origin, method, request_headers }` — same in Tasks 11, 12, 14.
- `PreflightEntry { allowed_methods, allowed_headers, allow_credentials, expires_at_seconds }` — same in Tasks 11, 14.
- `SiteContext::{SameSite, CrossSite}` — same in Tasks 6, 7, 9, 23.
- `HttpError::{CorsBlocked, PreflightFailed}` — same in Tasks 16, 17, 19.
- `cookie_header_for_navigation` (Task 9) ↔ `cookie_header_for_subresource` (Task 23): sibling pair, consistent shape.
- `Profile::new(user_agent? : String, jar_enabled~ : Bool = true)` — consistent in Tasks 2 and 25 (smoke test greps the exact signature).

No type-name drift detected.
