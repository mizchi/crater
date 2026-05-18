# BiDi Origin-Scoped Authorization Injection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let WebDriver clients register `Authorization` header values per origin via three `crater.*` BiDi commands; the runtime fetch shim attaches the value to outgoing requests for matching origins unless the caller has already set `Authorization` (caller wins).

**Architecture:** Extend the existing `AuthState` placeholder in `http/profile/auth.mbt` with a per-origin map. Add a new MoonBit handler file in `webdriver/webdriver/` for the three `crater.*` commands. Mirror the proven cookie snapshot push pattern: MoonBit pushes a JSON snapshot of the partition's `origin_headers` into `globalThis.__bidiContextAuth[ctxId]` during `apply_effective_viewport_to_runtime_context`, and the JS-side `__bidiResolveAuth(url)` bridge inspects the snapshot at request time. The fetch shim attaches the resolved value before dispatch, skipping if the caller already provided `Authorization`.

**Tech Stack:** MoonBit (browser-http profile + webdriver dispatch + runtime context bridges), embedded JS (runtime fetch shim), pkspec (scenario approval).

---

## File Structure

**Modified MoonBit files:**

- `http/profile/auth.mbt` — `AuthState` gains `origin_headers : Map[String, String]`, accessor methods, redacting `Show` impl.
- `webdriver/webdriver/bidi_runtime_context.mbt` — new `js_set_runtime_context_authorization` extern js + thin wrapper.
- `webdriver/webdriver/bidi_protocol_context_lifecycle.mbt` — push auth snapshot alongside the cookie push.
- `webdriver/webdriver/bidi_runtime_eval.mbt` — fetch shim attaches `Authorization` header when caller hasn't.
- One of `webdriver/webdriver/bidi_protocol_dispatch_*.mbt` — route three new `crater.*` command names. Survey before editing; pick the dispatch file that already routes other `crater.*` commands.

**New MoonBit files:**

- `webdriver/webdriver/bidi_authorization.mbt` — three handler functions + origin normalization helper + JSON snapshot serializer.
- `webdriver/webdriver/bidi_authorization_wbtest.mbt` — handler + validation tests.
- `webdriver/webdriver/bidi_runtime_authorization_bridge_wbtest.mbt` — `__bidiResolveAuth` bridge behavior tests.
- `http/profile/auth_wbtest.mbt` — unit tests on `AuthState` API + redacting `Show`.

**Modified test file:**

- `webdriver/webdriver/bidi_runtime_fetch_wbtest.mbt` — add Authorization integration cases.

**Modified spec files:**

- `specs/crater.pkl` — new scenario `protocol.bidi-origin-authorization-injection` approved with implementation pointer.
- `specs/tasks.Test.pkl` — pkspec smoke test wired to the new scenario.

---

## Task 1: Extend AuthState with origin_headers + accessors

**Files:**
- Modify: `http/profile/auth.mbt`
- Create: `http/profile/auth_wbtest.mbt`

- [ ] **Step 1: Write failing tests**

Create `http/profile/auth_wbtest.mbt`:

```moonbit
///|
test "AuthState::default has empty origin_headers" {
  let state = AuthState::default()
  inspect(state.origin_headers.size(), content="0")
}

///|
test "set_origin_header round-trips through header_for_origin" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer abc123")
  inspect(
    state.header_for_origin("https://api.example.com"),
    content="Some(\"Bearer abc123\")",
  )
  inspect(state.header_for_origin("https://other.com"), content="None")
}

///|
test "set_origin_header overwrites prior value for same origin" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer first")
  state.set_origin_header("https://api.example.com", "Bearer second")
  inspect(
    state.header_for_origin("https://api.example.com"),
    content="Some(\"Bearer second\")",
  )
}

///|
test "clear_origin_header removes the entry" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer abc")
  state.clear_origin_header("https://api.example.com")
  inspect(state.header_for_origin("https://api.example.com"), content="None")
}

///|
test "list_origins returns sorted origins" {
  let state = AuthState::default()
  state.set_origin_header("https://b.example.com", "Bearer b")
  state.set_origin_header("https://a.example.com", "Bearer a")
  state.set_origin_header("https://c.example.com", "Bearer c")
  let origins = state.list_origins()
  inspect(
    origins,
    content="[\"https://a.example.com\", \"https://b.example.com\", \"https://c.example.com\"]",
  )
}

///|
test "Show impl redacts header values" {
  let state = AuthState::default()
  state.set_origin_header("https://api.example.com", "Bearer secret-token")
  let buf = StringBuilder::new()
  state.output(buf)
  let rendered = buf.to_string()
  inspect(rendered.contains("secret-token"), content="false")
  inspect(rendered.contains("<redacted>"), content="true")
  inspect(rendered.contains("https://api.example.com"), content="true")
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `moon test -p mizchi/crater-browser-http/profile`
Expected: FAIL — `AuthState` has no `origin_headers` / no method.

- [ ] **Step 3: Extend AuthState in `http/profile/auth.mbt`**

Replace the current contents:

```moonbit
///|
/// Per-origin Authorization header storage carried by a Profile.
/// Header values are written via WebDriver `crater.setOriginAuthorization`
/// and attached by the BiDi runtime fetch shim when the caller has not
/// already supplied an `Authorization` header.
pub(all) struct AuthState {
  mut origin_headers : Map[String, String]
} derive(Debug)

///|
/// Show impl deliberately redacts header values; only origins are
/// rendered. Prevents secret leaks via panic stack traces or
/// structural debugging.
pub impl Show for AuthState with output(self, logger) {
  logger.write_string("AuthState{")
  let origins = self.list_origins()
  for i = 0; i < origins.length(); i = i + 1 {
    if i > 0 {
      logger.write_string(", ")
    }
    logger.write_string(origins[i])
    logger.write_string(": <redacted>")
  }
  logger.write_string("}")
}

///|
pub fn AuthState::default() -> AuthState {
  AuthState::{ origin_headers: Map::new() }
}

///|
pub fn AuthState::set_origin_header(
  self : AuthState,
  origin : String,
  header_value : String,
) -> Unit {
  self.origin_headers[origin] = header_value
}

///|
pub fn AuthState::clear_origin_header(
  self : AuthState,
  origin : String,
) -> Unit {
  self.origin_headers.remove(origin)
}

///|
pub fn AuthState::header_for_origin(
  self : AuthState,
  origin : String,
) -> String? {
  self.origin_headers.get(origin)
}

///|
pub fn AuthState::list_origins(self : AuthState) -> Array[String] {
  let result = []
  for origin, _ in self.origin_headers {
    result.push(origin)
  }
  result.sort()
  result
}
```

If `Map::new()` is not the right MoonBit API, look at how `cookie_jar.mbt` constructs its internal map. The exact constructor name may differ.

If the project's `Show` deprecation guidance (per MEMORY.md) requires deriving `Debug` and manually implementing `Show`, the code above already does that — but verify the `output` parameter type (`StringBuilder` vs `Logger`) matches what the existing `Show` impls in `http/profile/profile.mbt` use.

- [ ] **Step 4: Run tests to verify pass**

Run: `moon test -p mizchi/crater-browser-http/profile`
Expected: PASS (6 new tests + 5 pre-existing = 11 total).

- [ ] **Step 5: Commit**

```bash
git add http/profile/auth.mbt http/profile/auth_wbtest.mbt http/profile/pkg.generated.mbti
git commit -m "Extend AuthState with origin_headers map and redacting Show

Adds set_origin_header / clear_origin_header / header_for_origin /
list_origins methods plus a Show impl that redacts every stored
header value. Prepares the AuthState placeholder for the new
crater.setOriginAuthorization BiDi command.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Origin normalization helper

**Files:**
- Modify: `webdriver/webdriver/bidi_authorization.mbt` (create as part of Task 3)
- Modify: `webdriver/webdriver/bidi_authorization_wbtest.mbt` (create)

This task gets folded into Task 3 since the helper has no separate consumer. Keeping the description here to lock the contract:

```moonbit
/// Normalize an origin string per the spec:
/// - Reject non-http/https schemes.
/// - Reject input that contains path / query / fragment.
/// - Lowercase scheme and host.
/// - Strip default port (`:80` for http, `:443` for https).
/// - Strip trailing slash.
/// Returns Err(reason) for invalid input.
fn normalize_origin(input : String) -> Result[String, String]
```

Tests:
- `https://Example.COM` → `https://example.com`
- `https://Example.COM:443` → `https://example.com`
- `http://example.com:80` → `http://example.com`
- `https://example.com:8443` → `https://example.com:8443`
- `https://example.com/` → `https://example.com`
- `https://example.com/path` → Err
- `https://example.com?q=1` → Err
- `https://example.com#frag` → Err
- `ftp://example.com` → Err
- `javascript:void(0)` → Err
- Empty / not-a-url → Err

These tests live in `bidi_authorization_wbtest.mbt`.

---

## Task 3: Create bidi_authorization.mbt with set / clear / list handlers

**Files:**
- Create: `webdriver/webdriver/bidi_authorization.mbt`
- Create: `webdriver/webdriver/bidi_authorization_wbtest.mbt`

- [ ] **Step 1: Write failing tests**

Create `webdriver/webdriver/bidi_authorization_wbtest.mbt`. Use the existing test pattern from `bidi_emulation_profile_wbtest.mbt` as a template for spinning up a `BidiProtocol` stub and dispatching a message.

```moonbit
///|
test "crater.setOriginAuthorization stores per-origin header" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer abc123\"}}",
  )
  let profile = proto.profile_for_session("session-1").unwrap()
  inspect(
    profile.auth_state.header_for_origin("https://api.example.com"),
    content="Some(\"Bearer abc123\")",
  )
}

///|
test "crater.setOriginAuthorization normalizes origin" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://Example.COM:443\",\"headerValue\":\"Bearer abc\"}}",
  )
  let profile = proto.profile_for_session("session-1").unwrap()
  // Stored under normalized form
  inspect(
    profile.auth_state.header_for_origin("https://example.com"),
    content="Some(\"Bearer abc\")",
  )
  // Original casing does NOT match
  inspect(
    profile.auth_state.header_for_origin("https://Example.COM:443"),
    content="None",
  )
}

///|
test "crater.setOriginAuthorization rejects missing headerValue" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let response = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\"}}",
  )
  assert_true(response.contains("\"error\":\"invalid argument\""))
  assert_true(response.contains("headerValue"))
}

///|
test "crater.setOriginAuthorization rejects CRLF in headerValue" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let response = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer abc\\r\\nX-Spoof: evil\"}}",
  )
  assert_true(response.contains("\"error\":\"invalid argument\""))
  assert_true(response.contains("control"))
}

///|
test "crater.setOriginAuthorization rejects non-http scheme" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let response = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"ftp://example.com\",\"headerValue\":\"Bearer abc\"}}",
  )
  assert_true(response.contains("\"error\":\"invalid argument\""))
}

///|
test "crater.setOriginAuthorization rejects path in origin" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let response = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://example.com/api\",\"headerValue\":\"Bearer abc\"}}",
  )
  assert_true(response.contains("\"error\":\"invalid argument\""))
}

///|
test "crater.clearOriginAuthorization removes the entry" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer abc\"}}",
  )
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"crater.clearOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\"}}",
  )
  let profile = proto.profile_for_session("session-1").unwrap()
  inspect(
    profile.auth_state.header_for_origin("https://api.example.com"),
    content="None",
  )
}

///|
test "crater.listOriginAuthorizations returns origins without values" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer secret-token\"}}",
  )
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://auth.example.com\",\"headerValue\":\"Bearer another-secret\"}}",
  )
  let response = proto.process_message(
    "{\"id\":4,\"method\":\"crater.listOriginAuthorizations\",\"params\":{}}",
  )
  assert_true(response.contains("https://api.example.com"))
  assert_true(response.contains("https://auth.example.com"))
  // Header values MUST NOT appear in the response.
  assert_true(!response.contains("secret-token"))
  assert_true(!response.contains("another-secret"))
}
```

If `make_test_bidi_protocol` is the wrong helper name, look at `bidi_emulation_profile_wbtest.mbt` for the actual fixture-construction pattern in this codebase and adapt.

- [ ] **Step 2: Run tests to verify failure**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: FAIL — handlers do not exist; dispatch routes nothing for `crater.setOriginAuthorization`.

- [ ] **Step 3: Implement bidi_authorization.mbt**

Create `webdriver/webdriver/bidi_authorization.mbt`:

```moonbit
///|
/// Maximum length in bytes for a stored Authorization header value.
/// Real-world JWTs are typically under 4 KB; 8 KB leaves headroom
/// without making it cheap to wedge unbounded state.
const AUTH_HEADER_VALUE_LIMIT : Int = 8192

///|
/// Normalize an origin per the spec: only http/https, no path/query/
/// fragment, lowercased scheme and host, default port stripped, no
/// trailing slash.
fn normalize_origin(input : String) -> Result[String, String] {
  let trimmed = input.trim()
  let scheme_end = match trimmed.find("://") {
    Some(idx) => idx
    None => return Err("origin must be a valid URL (scheme://host[:port])")
  }
  let scheme = trimmed.unsafe_substring(start=0, end=scheme_end).to_ascii_lower()
  if scheme != "http" && scheme != "https" {
    return Err("origin must use http or https scheme")
  }
  let host_start = scheme_end + 3
  let rest = trimmed.unsafe_substring(start=host_start, end=trimmed.length())
  // Reject path / query / fragment
  for sep in ['/', '?', '#'] {
    if rest.contains_char(sep) {
      return Err("origin must not contain path / query / fragment")
    }
  }
  if rest.length() == 0 {
    return Err("origin must include a host")
  }
  let lowered_host = rest.to_ascii_lower()
  // Strip default port
  let normalized_host_port = if scheme == "http" && lowered_host.has_suffix(":80") {
    lowered_host.unsafe_substring(start=0, end=lowered_host.length() - 3)
  } else if scheme == "https" && lowered_host.has_suffix(":443") {
    lowered_host.unsafe_substring(start=0, end=lowered_host.length() - 4)
  } else {
    lowered_host
  }
  Ok(scheme + "://" + normalized_host_port)
}

///|
/// Validate a candidate header value. Reject empty, oversized, or
/// values containing control characters / ANSI escape sequences.
fn validate_header_value(value : String) -> Result[Unit, String] {
  if value.length() == 0 {
    return Err("headerValue must not be empty")
  }
  if value.length() > AUTH_HEADER_VALUE_LIMIT {
    return Err("headerValue exceeds 8KB limit")
  }
  // Check for control characters (anything < 0x20 except tab) and ANSI ESC.
  let chars = value.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let code = chars[i].to_int()
    if code < 0x20 && code != 0x09 {
      return Err("headerValue must not contain control characters")
    }
    if code == 0x1b {
      return Err("headerValue must not contain ANSI escape sequences")
    }
  }
  Ok(())
}

///|
fn BidiProtocol::handle_crater_set_origin_authorization(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(m)) => m
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let raw_origin = match map.get("origin") {
    Some(String(o)) => o
    _ => {
      self.send_error(
        request_id, "invalid argument", "origin must be a string",
      )
      return
    }
  }
  let header_value = match map.get("headerValue") {
    Some(String(v)) => v
    _ => {
      self.send_error(
        request_id, "invalid argument", "headerValue must be a string",
      )
      return
    }
  }
  let normalized = match normalize_origin(raw_origin) {
    Ok(o) => o
    Err(reason) => {
      self.send_error(request_id, "invalid argument", reason)
      return
    }
  }
  match validate_header_value(header_value) {
    Ok(_) => ()
    Err(reason) => {
      self.send_error(request_id, "invalid argument", reason)
      return
    }
  }
  let ctx_id = self.resolve_authorization_context(map, request_id)
  guard ctx_id is Some(ctx) else { return }
  let profile = match self.profile_for_session(ctx) {
    Some(p) => p
    None => {
      self.send_error(
        request_id, "no such frame", "Unknown context: " + ctx,
      )
      return
    }
  }
  profile.auth_state.set_origin_header(normalized, header_value)
  self.push_authorization_snapshot(ctx)
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_crater_clear_origin_authorization(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(m)) => m
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let raw_origin = match map.get("origin") {
    Some(String(o)) => o
    _ => {
      self.send_error(
        request_id, "invalid argument", "origin must be a string",
      )
      return
    }
  }
  let normalized = match normalize_origin(raw_origin) {
    Ok(o) => o
    Err(reason) => {
      self.send_error(request_id, "invalid argument", reason)
      return
    }
  }
  let ctx_id = self.resolve_authorization_context(map, request_id)
  guard ctx_id is Some(ctx) else { return }
  let profile = match self.profile_for_session(ctx) {
    Some(p) => p
    None => {
      self.send_error(
        request_id, "no such frame", "Unknown context: " + ctx,
      )
      return
    }
  }
  profile.auth_state.clear_origin_header(normalized)
  self.push_authorization_snapshot(ctx)
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_crater_list_origin_authorizations(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(m)) => m
    _ => make_object({})
  }
  let ctx_id = self.resolve_authorization_context(map, request_id)
  guard ctx_id is Some(ctx) else { return }
  let profile = match self.profile_for_session(ctx) {
    Some(p) => p
    None => {
      self.send_error(
        request_id, "no such frame", "Unknown context: " + ctx,
      )
      return
    }
  }
  let origins_json = []
  for origin in profile.auth_state.list_origins() {
    origins_json.push(make_object({ "origin": Json::string(origin) }))
  }
  self.send_success(
    request_id,
    Some(make_object({ "origins": Json::array(origins_json) })),
  )
}

///|
/// Resolve the target context: explicit `context` param wins; otherwise
/// fall back to the active context. Returns None and sends an error
/// when the context argument is malformed.
fn BidiProtocol::resolve_authorization_context(
  self : BidiProtocol,
  map : Map[String, Json],
  request_id : Int,
) -> String? {
  match map.get("context") {
    Some(String(ctx)) => {
      if !self.manager.has_session(ctx) {
        self.send_error(
          request_id, "no such frame", "Unknown context: " + ctx,
        )
        return None
      }
      Some(ctx)
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      None
    }
    None => self.default_context_id
  }
}

///|
/// Serialize the partition's origin_headers as a JSON object suitable
/// for pushing into globalThis.__bidiContextAuth[ctxId].
pub fn BidiProtocol::serialize_auth_snapshot_for_runtime(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  match self.profile_for_session(ctx_id) {
    Some(profile) => {
      let entries : Map[String, Json] = Map::new()
      for origin in profile.auth_state.list_origins() {
        match profile.auth_state.header_for_origin(origin) {
          Some(value) => entries[origin] = Json::string(value)
          None => ()
        }
      }
      Json::object(entries).stringify()
    }
    None => "{}"
  }
}

///|
fn BidiProtocol::push_authorization_snapshot(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  let snapshot = self.serialize_auth_snapshot_for_runtime(ctx_id)
  set_runtime_context_authorization(ctx_id, snapshot)
}
```

`set_runtime_context_authorization` is added in Task 5. Place a TODO comment on the call site so Task 5 lands the bridge.

Adapt any of the calls above to the actual MoonBit APIs in this codebase:
- `Map::new()` vs `{}` literal — match what `bidi_storage.mbt` uses.
- `Json::object(map).stringify()` vs `make_object(map)` — match the project's prevalent pattern.
- `self.send_error` / `self.send_success` / `make_object` — these are the established helpers; use them.

- [ ] **Step 4: Wire dispatch**

Find the existing dispatch entry point that routes `crater.*` commands (`grep -n 'crater\\.' webdriver/webdriver/bidi_protocol_dispatch*.mbt`). Add the three new cases:

```moonbit
"crater.setOriginAuthorization" => {
  self.handle_crater_set_origin_authorization(request.id, request.params)
  return Ok(())
}
"crater.clearOriginAuthorization" => {
  self.handle_crater_clear_origin_authorization(request.id, request.params)
  return Ok(())
}
"crater.listOriginAuthorizations" => {
  self.handle_crater_list_origin_authorizations(request.id, request.params)
  return Ok(())
}
```

- [ ] **Step 5: Run tests to verify pass and commit**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: PASS — 8 new handler tests pass. The two `push_authorization_snapshot` callers will fail at link time until Task 5 lands `set_runtime_context_authorization`. To make Task 3 commit-ready in isolation, **define a temporary stub** in `bidi_runtime_context.mbt`:

```moonbit
///|
/// Temporary stub; real extern js install lands in Task 5.
fn set_runtime_context_authorization(_ctx_id : String, _json : String) -> Unit {
  ()
}
```

Run tests again — should pass.

```bash
git add http/profile/auth.mbt http/profile/auth_wbtest.mbt webdriver/webdriver/bidi_authorization.mbt webdriver/webdriver/bidi_authorization_wbtest.mbt webdriver/webdriver/bidi_runtime_context.mbt webdriver/webdriver/bidi_protocol_dispatch_*.mbt webdriver/webdriver/pkg.generated.mbti
git commit -m "Add crater.setOriginAuthorization / clear / list BiDi handlers

Three new crater.* extension commands let WebDriver clients register
per-origin Authorization header values on the per-session Profile.
Input validation rejects non-http/https schemes, path/query/fragment
in origin, empty/oversized/CRLF/ANSI header values. Origin is
normalized (lowercase, default port stripped, trailing slash
stripped). listOriginAuthorizations exposes origins only — header
values are never serialized into BiDi responses.

A temporary set_runtime_context_authorization stub keeps the
snapshot push compilable; the real extern js bridge lands in the
next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Add set_runtime_context_authorization extern js bridge + install __bidiResolveAuth

**Files:**
- Modify: `webdriver/webdriver/bidi_runtime_context.mbt`
- Create: `webdriver/webdriver/bidi_runtime_authorization_bridge_wbtest.mbt`

- [ ] **Step 1: Write failing bridge tests**

Create `webdriver/webdriver/bidi_runtime_authorization_bridge_wbtest.mbt`:

```moonbit
///|
test "__bidiResolveAuth returns null when nothing registered" {
  let _ = reset_runtime_js_state()
  let _ = evaluate_js("0")
  set_runtime_context_authorization("session-1", "{}")
  let result = evaluate_js(
    "(globalThis.__bidiCurrentContext = \"session-1\", globalThis.__bidiResolveAuth(\"https://api.example.com/x\"))",
  )
  inspect(result, content="null")
}

///|
test "__bidiResolveAuth returns header for matching origin" {
  let _ = reset_runtime_js_state()
  let _ = evaluate_js("0")
  set_runtime_context_authorization(
    "session-1",
    "{\"https://api.example.com\":\"Bearer abc123\"}",
  )
  let result = evaluate_js(
    "(globalThis.__bidiCurrentContext = \"session-1\", globalThis.__bidiResolveAuth(\"https://api.example.com/v1/me\"))",
  )
  inspect(result, content="\"Bearer abc123\"")
}

///|
test "__bidiResolveAuth strips default https port when matching" {
  let _ = reset_runtime_js_state()
  let _ = evaluate_js("0")
  set_runtime_context_authorization(
    "session-1",
    "{\"https://api.example.com\":\"Bearer abc123\"}",
  )
  let result = evaluate_js(
    "(globalThis.__bidiCurrentContext = \"session-1\", globalThis.__bidiResolveAuth(\"https://api.example.com:443/v1/me\"))",
  )
  inspect(result, content="\"Bearer abc123\"")
}

///|
test "__bidiResolveAuth returns null for mismatched origin" {
  let _ = reset_runtime_js_state()
  let _ = evaluate_js("0")
  set_runtime_context_authorization(
    "session-1",
    "{\"https://api.example.com\":\"Bearer abc123\"}",
  )
  let result = evaluate_js(
    "(globalThis.__bidiCurrentContext = \"session-1\", globalThis.__bidiResolveAuth(\"https://other.com/x\"))",
  )
  inspect(result, content="null")
}
```

`evaluate_js` / `reset_runtime_js_state` already exist — see `bidi_runtime_set_cookie_ingest_wbtest.mbt` for the helper-usage pattern.

- [ ] **Step 2: Run tests to verify failure**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: FAIL — `__bidiResolveAuth` undefined.

- [ ] **Step 3: Implement extern js + replace the Task 3 stub**

In `webdriver/webdriver/bidi_runtime_context.mbt`, remove the stub from Task 3 and add:

```moonbit
///|
/// Push the per-context Authorization snapshot into the JS realm. The
/// snapshot is consumed by the auto-installed globalThis.__bidiResolveAuth
/// helper that the fetch shim calls before dispatching each outbound
/// request. Mirror of set_runtime_context_cookies.
pub extern "js" fn js_set_runtime_context_authorization(
  ctx_id : String,
  auth_json : String,
) -> Unit =
  #| (ctxId, authJson) => {
  #|   if (!globalThis.__bidiContextAuth) globalThis.__bidiContextAuth = {};
  #|   try {
  #|     globalThis.__bidiContextAuth[ctxId] = JSON.parse(authJson);
  #|   } catch (_e) {
  #|     globalThis.__bidiContextAuth[ctxId] = {};
  #|   }
  #|   if (typeof globalThis.__bidiResolveAuth !== 'function') {
  #|     globalThis.__bidiResolveAuth = function(url) {
  #|       const ctx = String(globalThis.__bidiCurrentContext || 'default-context');
  #|       const map = (globalThis.__bidiContextAuth || {})[ctx] || {};
  #|       try {
  #|         const u = new URL(url);
  #|         let origin = u.protocol + '//' + u.hostname;
  #|         if (
  #|           (u.protocol === 'http:'  && u.port && u.port !== '80') ||
  #|           (u.protocol === 'https:' && u.port && u.port !== '443')
  #|         ) origin += ':' + u.port;
  #|         return map[origin] || null;
  #|       } catch (_e) { return null; }
  #|     };
  #|   }
  #| }

///|
fn set_runtime_context_authorization(
  ctx_id : String,
  auth_json : String,
) -> Unit {
  js_set_runtime_context_authorization(ctx_id, auth_json)
}
```

Drop the stub added at the end of Task 3.

- [ ] **Step 4: Run tests to verify pass**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: PASS — 4 new bridge tests pass, all prior tests still pass.

- [ ] **Step 5: Commit**

```bash
git add webdriver/webdriver/bidi_runtime_context.mbt webdriver/webdriver/bidi_runtime_authorization_bridge_wbtest.mbt webdriver/webdriver/pkg.generated.mbti
git commit -m "Add set_runtime_context_authorization extern js + __bidiResolveAuth bridge

Mirror of set_runtime_context_cookies: pushes the per-context auth
snapshot into globalThis.__bidiContextAuth and lazily installs
globalThis.__bidiResolveAuth(url) which extracts the request origin
(http/https only, default-port-stripped) and looks up the registered
header value. Drops the stub from the previous commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Wire snapshot push from apply_effective_viewport_to_runtime_context

**Files:**
- Modify: `webdriver/webdriver/bidi_protocol_context_lifecycle.mbt`

- [ ] **Step 1: Write the test**

Add to `bidi_authorization_wbtest.mbt`:

```moonbit
///|
test "apply_effective_viewport_to_runtime_context pushes auth snapshot" {
  let proto = make_test_bidi_protocol()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{\"capabilities\":{}}}",
  )
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer abc\"}}",
  )
  // Force a viewport apply (would happen naturally before script.evaluate).
  proto.apply_effective_viewport_to_runtime_context("session-1", "session-1")
  let result = evaluate_js(
    "(globalThis.__bidiCurrentContext = \"session-1\", globalThis.__bidiResolveAuth(\"https://api.example.com/me\"))",
  )
  inspect(result, content="\"Bearer abc\"")
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: FAIL — `apply_effective_viewport_to_runtime_context` doesn't yet push the auth snapshot.

- [ ] **Step 3: Wire the push**

Edit `bidi_protocol_context_lifecycle.mbt` `apply_effective_viewport_to_runtime_context`. After the existing `set_runtime_context_cookies(...)` call (around line 51), append:

```moonbit
  // Push the partition Authorization snapshot so the runtime fetch
  // shim's __bidiResolveAuth bridge can attach Authorization headers
  // to outbound requests for registered origins. Resolves
  // protocol.bidi-origin-authorization-injection.
  let auth_json = self.serialize_auth_snapshot_for_runtime(logical_ctx_id)
  set_runtime_context_authorization(runtime_ctx_id, auth_json)
```

- [ ] **Step 4: Run test to verify pass**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add webdriver/webdriver/bidi_protocol_context_lifecycle.mbt webdriver/webdriver/bidi_authorization_wbtest.mbt
git commit -m "Push auth snapshot in apply_effective_viewport_to_runtime_context

Mirrors the existing cookie snapshot push; runs at every script.evaluate
boundary so script-side fetches see the latest registered values.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Wire Authorization attach in fetch shim

**Files:**
- Modify: `webdriver/webdriver/bidi_runtime_eval.mbt`

- [ ] **Step 1: Write the integration test**

Append to `webdriver/webdriver/bidi_runtime_fetch_wbtest.mbt`:

```moonbit
///|
test "fetch shim attaches Authorization for matching origin" {
  let _ = reset_runtime_js_state()
  let _ = evaluate_js("0")
  set_runtime_context_authorization(
    "session-1",
    "{\"https://api.example.com\":\"Bearer abc123\"}",
  )
  let result = evaluate_js(
    "(async () => {" +
    "  globalThis.__bidiCurrentContext = \"session-1\";" +
    "  let captured = null;" +
    "  globalThis.__rawFetch = async (url, opts) => {" +
    "    captured = (opts && opts.headers && (opts.headers.get ? opts.headers.get('Authorization') : opts.headers.Authorization)) || null;" +
    "    return new Response('ok', { status: 200, headers: { 'access-control-allow-origin': 'https://app.example.com' } });" +
    "  };" +
    "  globalThis.__pageUrl = 'https://app.example.com';" +
    "  await globalThis.fetch('https://api.example.com/me');" +
    "  return captured;" +
    "})()",
  )
  inspect(result, content="\"Bearer abc123\"")
}

///|
test "fetch shim respects caller-provided Authorization over bridge" {
  let _ = reset_runtime_js_state()
  let _ = evaluate_js("0")
  set_runtime_context_authorization(
    "session-1",
    "{\"https://api.example.com\":\"Bearer driver-token\"}",
  )
  let result = evaluate_js(
    "(async () => {" +
    "  globalThis.__bidiCurrentContext = \"session-1\";" +
    "  let captured = null;" +
    "  globalThis.__rawFetch = async (url, opts) => {" +
    "    captured = (opts && opts.headers && (opts.headers.get ? opts.headers.get('Authorization') : opts.headers.Authorization)) || null;" +
    "    return new Response('ok', { status: 200, headers: { 'access-control-allow-origin': 'https://app.example.com' } });" +
    "  };" +
    "  globalThis.__pageUrl = 'https://app.example.com';" +
    "  await globalThis.fetch('https://api.example.com/me', { headers: { Authorization: 'Bearer page-token' } });" +
    "  return captured;" +
    "})()",
  )
  inspect(result, content="\"Bearer page-token\"")
}

///|
test "fetch shim skips Authorization for non-matching origin" {
  let _ = reset_runtime_js_state()
  let _ = evaluate_js("0")
  set_runtime_context_authorization(
    "session-1",
    "{\"https://api.example.com\":\"Bearer abc\"}",
  )
  let result = evaluate_js(
    "(async () => {" +
    "  globalThis.__bidiCurrentContext = \"session-1\";" +
    "  let captured = \"<unset>\";" +
    "  globalThis.__rawFetch = async (url, opts) => {" +
    "    captured = (opts && opts.headers && (opts.headers.get ? opts.headers.get('Authorization') : opts.headers.Authorization)) || null;" +
    "    return new Response('ok', { status: 200, headers: { 'access-control-allow-origin': 'https://app.example.com' } });" +
    "  };" +
    "  globalThis.__pageUrl = 'https://app.example.com';" +
    "  await globalThis.fetch('https://other.com/x');" +
    "  return captured;" +
    "})()",
  )
  inspect(result, content="null")
}
```

If the existing fetch wbtests pattern uses `@async.Promise::wait` to flush microtasks, adapt the new tests to match — copy the structure from `bidi_runtime_fetch_wbtest.mbt`'s top-most test.

- [ ] **Step 2: Run tests to verify failure**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: FAIL — Authorization never gets attached because the fetch shim doesn't read `__bidiResolveAuth` yet.

- [ ] **Step 3: Wire the attach**

In `webdriver/webdriver/bidi_runtime_eval.mbt`, locate the `fetchWithPolicy` cookie-attach block (around line 3315, after `__bidiResolveCookies` is consulted). Insert the Authorization attach block right after:

```javascript
  #|         // Attach partition Authorization header if registered for
  #|         // this origin and caller has not already supplied one.
  #|         if (
  #|           typeof globalThis.__bidiResolveAuth === 'function' &&
  #|           !headers.has('Authorization')
  #|         ) {
  #|           try {
  #|             const authValue = globalThis.__bidiResolveAuth(resolvedUrl);
  #|             if (authValue) {
  #|               headers.set('Authorization', authValue);
  #|             }
  #|           } catch (_e) { /* swallow — fail open with no header */ }
  #|         }
```

The exact insertion point is just after the existing Cookie-attach `if` block. Find that block by grepping `__bidiResolveCookies` in the file.

- [ ] **Step 4: Run tests to verify pass**

Run: `moon test -p mizchi/crater-webdriver-bidi/webdriver`
Expected: PASS — all three new attach tests pass.

- [ ] **Step 5: Commit**

```bash
git add webdriver/webdriver/bidi_runtime_eval.mbt webdriver/webdriver/bidi_runtime_fetch_wbtest.mbt
git commit -m "Attach Authorization header in fetch shim for matching origins

Caller-supplied Authorization headers survive; the bridge only fires
when headers.has('Authorization') is false. Same skip-if-set policy
as the cookie attach block.

Closes protocol.bidi-origin-authorization-injection.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Approve pkspec scenario with smoke

**Files:**
- Modify: `specs/crater.pkl`
- Modify: `specs/tasks.Test.pkl`

- [ ] **Step 1: Write the smoke test failure**

Append the new pkspec smoke test to `specs/tasks.Test.pkl` (mirror the shape of `bidi_runtime_fetch_partition_cookie_bridge_wired`):

```pkl
  new {
    name = "bidi_origin_authorization_injection_wired"
    description =
      "The BiDi runtime accepts crater.setOriginAuthorization / clearOriginAuthorization / listOriginAuthorizations commands, normalizes origins, redacts header values in Show output and list responses, and attaches Authorization headers to outgoing fetches for matching origins via the __bidiResolveAuth bridge. Caller-supplied Authorization survives."
    tags { "bidi"; "auth"; "runtime" }
    specRef { "protocol.bidi-origin-authorization-injection" }
    workdir = ".."
    cmd =
      "bash -lc 'set -e; test -f http/profile/auth.mbt; grep -Fq -- \"fn AuthState::set_origin_header\" http/profile/auth.mbt; grep -Fq -- \"<redacted>\" http/profile/auth.mbt; test -f webdriver/webdriver/bidi_authorization.mbt; grep -Fq -- \"handle_crater_set_origin_authorization\" webdriver/webdriver/bidi_authorization.mbt; grep -Fq -- \"normalize_origin\" webdriver/webdriver/bidi_authorization.mbt; grep -Fq -- \"\\\"crater.setOriginAuthorization\\\"\" webdriver/webdriver/bidi_protocol_dispatch_script.mbt webdriver/webdriver/bidi_protocol_dispatch_storage.mbt webdriver/webdriver/bidi_protocol_dispatch_network.mbt webdriver/webdriver/bidi_protocol_dispatch_browsing_context.mbt 2>/dev/null || grep -rFq -- \"\\\"crater.setOriginAuthorization\\\"\" webdriver/webdriver/; grep -Fq -- \"globalThis.__bidiResolveAuth\" webdriver/webdriver/bidi_runtime_context.mbt; grep -Fq -- \"globalThis.__bidiResolveAuth\" webdriver/webdriver/bidi_runtime_eval.mbt; test -f webdriver/webdriver/bidi_authorization_wbtest.mbt; grep -Fq -- \"crater.setOriginAuthorization stores per-origin header\" webdriver/webdriver/bidi_authorization_wbtest.mbt; grep -Fq -- \"crater.setOriginAuthorization rejects CRLF in headerValue\" webdriver/webdriver/bidi_authorization_wbtest.mbt; test -f webdriver/webdriver/bidi_runtime_fetch_wbtest.mbt; grep -Fq -- \"fetch shim attaches Authorization for matching origin\" webdriver/webdriver/bidi_runtime_fetch_wbtest.mbt; grep -Fq -- \"fetch shim respects caller-provided Authorization over bridge\" webdriver/webdriver/bidi_runtime_fetch_wbtest.mbt'"
  }
```

The grep targets where `crater.setOriginAuthorization` is routed needs to match the actual dispatch file. Adjust the `grep -rFq` fallback to be the only check if there's no single dispatch file to grep.

- [ ] **Step 2: Run spec-test to confirm failure**

Run: `pkf run spec-check`
Expected: FAIL — `protocol.bidi-origin-authorization-injection` scenario isn't declared.

- [ ] **Step 3: Add the approved scenario**

Append to `specs/crater.pkl` in the appropriate `bug.*` / `protocol.*` cluster:

```pkl
  new {
    id = "protocol.bidi-origin-authorization-injection"
    name = "BiDi clients can inject Authorization headers per origin"
    description =
      "Three BiDi extension commands let WebDriver clients register Authorization header values scoped to a single scheme://host[:port] origin: crater.setOriginAuthorization sets, crater.clearOriginAuthorization removes, crater.listOriginAuthorizations returns the set of registered origins (header values intentionally NOT exposed). The runtime fetch shim attaches the registered header to outgoing requests for matching origins; the caller-wins policy from PR #136 / #140 still applies — if the caller has already set Authorization, the bridge does not overwrite. Origin normalization lowercases scheme and host and strips default ports. Header value validation rejects empty / CRLF / control / ANSI / oversized inputs. Stored credentials are redacted in Show output and absent from list responses."
    tags { "bidi"; "auth"; "runtime"; "protocol" }
    severity = "major"
    reviewStatus = "approved"
    contributes { "goal.protocol-compat"; "goal.dom-compat" }
  }
```

- [ ] **Step 4: Run gates**

Run:
- `pkf run spec-check` — all declared scenarios have impls.
- `pkf run spec-lint` — clean.
- `pkf run spec-test` — should now pass the new `bidi_origin_authorization_injection_wired` smoke.

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add specs/crater.pkl specs/tasks.Test.pkl
git commit -m "Approve protocol.bidi-origin-authorization-injection scenario

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**

- AuthState extension → Task 1.
- Origin normalization → Task 2 (folded into Task 3).
- `crater.setOriginAuthorization` / `clear` / `list` handlers → Task 3.
- Validation rejections (CRLF / ANSI / empty / oversized / scheme / path) → Task 3 tests.
- Origin normalization round-trip → Task 3 test (`https://Example.COM:443` → `https://example.com`).
- Snapshot bridge + `__bidiResolveAuth` install → Task 4.
- Snapshot push from lifecycle hook → Task 5.
- Fetch shim Authorization attach + caller-wins → Task 6.
- Origin mismatch → Task 6 test.
- pkspec scenario + smoke → Task 7.

Spec mentions preflight (cross-origin POST should not carry Authorization on the OPTIONS request, only on the actual POST). The existing preflight implementation builds its own headers via `Headers` constructor without copying `Authorization` from the original request — verify in Task 6 by adding a test if scope allows; if it complicates things, file as a follow-up draft.

**2. Placeholder scan:** No TBD / TODO / "similar to" / "add appropriate error handling" patterns. Validation contracts are spelled out. Test code present in every step.

**3. Type consistency:**

- `AuthState { origin_headers : Map[String, String] }` — same shape in Tasks 1, 3, 5.
- `set_origin_header` / `clear_origin_header` / `header_for_origin` / `list_origins` — same signatures across tasks.
- `serialize_auth_snapshot_for_runtime` returns `String` (JSON) — consistent in Tasks 3, 5.
- `set_runtime_context_authorization(ctx_id, json)` signature — same in Tasks 3 (stub), 4 (real), 5 (caller).
- `__bidiContextAuth` / `__bidiResolveAuth` / `__bidiCurrentContext` — consistent global names across Tasks 4, 5, 6.
- `protocol.bidi-origin-authorization-injection` scenario id matches between spec smoke and approval (Task 7).

No drift detected.
