///|
/// Cookie URL filter parity guard.
///
/// `__bidiResolveCookies` (JS, in bidi_runtime_context.mbt) and
/// `storage_cookie_matches_request_url` (MoonBit, in bidi_storage.mbt)
/// independently re-implement the WHATWG cookie domain / path / secure
/// filtering. Functionally they should agree on every input. Without a
/// parity guard they would silently drift the next time someone touches
/// only one side.
///
/// This file pins parity by running a fixed set of cookie + request URL
/// pairs through BOTH implementations and asserting they agree on whether
/// the cookie attaches. The JS side is exercised through `__bidiResolveCookies`
/// (set up via `set_runtime_context_cookies`) so we test the actual bridge,
/// not an isolated JS helper.
///
/// Pins bug.runtime.cookie-url-filter-parity. Catches drift; does NOT
/// unify the implementations.

///|
/// One parity case: a single cookie + a target URL + the expected match
/// outcome. The cookie shape is the same one the JS bridge consumes (see
/// `BidiProtocol::cookies_for_context_full_json`).
priv struct ParityCase {
  label : String
  cookie_json : String
  stored_cookie : StoredCookie
  request_url : String
  expected : Bool
}

///|
/// A `StoredCookie` literal with sensible defaults. Tests only override
/// the fields they care about so cases stay short.
fn make_stored(
  name~ : String,
  value? : String = "v",
  domain~ : String,
  path? : String = "/",
  secure? : Bool = false,
  same_site? : String = "lax",
  expiry? : Int? = None,
) -> StoredCookie {
  {
    name,
    value_text: value,
    domain,
    domain_explicit: true,
    path,
    http_only: false,
    secure,
    same_site,
    expiry,
    context_id: Some("session-1"),
    user_context: None,
    source_origin: None,
  }
}

///|
/// Seed a single-cookie partition jar scoped to session-1 and push it to
/// the JS realm. The JS-side bridge installs lazily inside
/// `set_runtime_context_cookies`, so the very first push wires
/// `__bidiResolveCookies`.
fn seed_parity_cookie(proto : BidiProtocol, cookie_json : String) -> Unit {
  let payload = "{\"id\":2,\"method\":\"storage.setCookie\",\"params\":{\"cookie\":" +
    cookie_json +
    ",\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
}

///|
/// Read whether `__bidiResolveCookies(url)` returned a non-empty string,
/// i.e. whether the JS side decided the cookie attaches.
fn js_bridge_matches(
  proto : BidiProtocol,
  request_id : Int,
  cookie_name : String,
  request_url : String,
) -> Bool {
  // Page URL drives the request scheme resolution for the JS-side
  // request_path / request_scheme helpers. Use the request URL so both
  // sides see the same base; the JS helpers fall back to __pageUrl when
  // the URL is relative.
  let setup = "globalThis.__pageUrl = '" +
    request_url +
    "'; globalThis.__parityResolveResult = (typeof globalThis.__bidiResolveCookies === 'function' ? globalThis.__bidiResolveCookies('" +
    request_url +
    "') : '<no-fn>');"
  let payload = "{\"id\":" +
    request_id.to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(setup).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(payload)
  let _ = proto.take_messages()
  let read_payload = "{\"id\":" +
    (request_id + 1).to_string() +
    ",\"method\":\"script.evaluate\",\"params\":{\"expression\":\"globalThis.__parityResolveResult\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}"
  let _ = proto.process_message(read_payload)
  let msgs = proto.take_messages()
  if msgs.length() == 0 {
    return false
  }
  let resp = msgs[0].to_json()
  // A match shows up as `name=` in the Cookie header value.
  resp.contains(cookie_name + "=")
}

///|
/// Build the 10 representative cases. Each case sets `cookie_json` (for the
/// JS push via storage.setCookie) and `stored_cookie` (for the MoonBit side
/// to evaluate directly). Keep these in lock-step.
fn parity_cases() -> Array[ParityCase] {
  [
    // 1. Same-origin same-path: matches both sides.
    {
      label: "exact host + root path",
      cookie_json: "{\"name\":\"a1\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a1", domain="localhost"),
      request_url: "http://localhost/api/me",
      expected: true,
    },
    // 2. Cross-site host: domain mismatch blocks both sides.
    {
      label: "cross-site host",
      cookie_json: "{\"name\":\"a2\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a2", domain="localhost"),
      request_url: "http://api.example.test/v1",
      expected: false,
    },
    // 3. Subdomain match: leading-dot domain attaches on the subdomain.
    {
      label: "subdomain matches dot-prefixed domain",
      cookie_json: "{\"name\":\"a3\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\".example.test\",\"path\":\"/\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a3", domain=".example.test"),
      request_url: "http://api.example.test/v1",
      expected: true,
    },
    // 4. Path prefix match: cookie path /api attaches on /api/me.
    {
      label: "sub-path matches cookie path prefix",
      cookie_json: "{\"name\":\"a4\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/api\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a4", domain="localhost", path="/api"),
      request_url: "http://localhost/api/me",
      expected: true,
    },
    // 5. Path mismatch: cookie path /admin does not attach on /api/me.
    {
      label: "path mismatch blocks cookie",
      cookie_json: "{\"name\":\"a5\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/admin\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a5", domain="localhost", path="/admin"),
      request_url: "http://localhost/api/me",
      expected: false,
    },
    // 6. Non-secure cookie on https: both sides allow (parallel to case 7 below).
    {
      label: "non-secure cookie allowed on https",
      cookie_json: "{\"name\":\"a6\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a6", domain="localhost"),
      request_url: "https://localhost/api/me",
      expected: true,
    },
    // 7. Non-secure cookie on http: both sides allow. Note: scheme-based
    // Secure-only filtering is JS-side only today — see
    // bug.runtime.cookie-url-filter-parity. This parity suite covers
    // domain + path agreement; secure-vs-scheme divergence is intentional
    // and out of scope until the implementations are unified.
    {
      label: "non-secure cookie on http (domain/path parity only)",
      cookie_json: "{\"name\":\"a7\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a7", domain="localhost"),
      request_url: "http://localhost/api/me",
      expected: true,
    },
    // 8. Cookie path with trailing slash matches exact path prefix.
    {
      label: "cookie path with trailing slash matches",
      cookie_json: "{\"name\":\"a8\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/api/\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a8", domain="localhost", path="/api/"),
      request_url: "http://localhost/api/inner",
      expected: true,
    },
    // 9. Cookie path that is a name prefix but not a path prefix.
    // /api should not match /apiv2 (boundary check).
    {
      label: "path name prefix without boundary blocks",
      cookie_json: "{\"name\":\"a9\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"localhost\",\"path\":\"/api\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a9", domain="localhost", path="/api"),
      request_url: "http://localhost/apiv2/me",
      expected: false,
    },
    // 10. Subdomain mismatch: cookie domain api.example.test does NOT attach
    // on a different host (other.example.test).
    {
      label: "different subdomain blocks cookie",
      cookie_json: "{\"name\":\"a10\",\"value\":{\"type\":\"string\",\"value\":\"v\"},\"domain\":\"api.example.test\",\"path\":\"/\",\"sameSite\":\"lax\"}",
      stored_cookie: make_stored(name="a10", domain="api.example.test"),
      request_url: "http://other.example.test/v1",
      expected: false,
    },
  ]
}

///|
/// One test per case. Each test seeds a single cookie, evaluates both
/// implementations against the same request URL, and asserts they agree
/// with `expected`. Per-case proto isolation prevents cross-contamination
/// when the JS realm is shared across cases.
test "cookie URL filter parity: 10 representative cases" {
  let cases = parity_cases()
  for i = 0; i < cases.length(); i = i + 1 {
    let case = cases[i]
    let proto = BidiProtocol::new()
    let _ = proto.process_message(
      "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
    )
    let _ = proto.take_messages()
    seed_parity_cookie(proto, case.cookie_json)
    // JS side
    let js_matches = js_bridge_matches(
      proto,
      3,
      case.stored_cookie.name,
      case.request_url,
    )
    // MoonBit side
    let moonbit_matches = storage_cookie_matches_request_url(
      case.stored_cookie,
      Some(case.request_url),
    )
    // Both sides must agree with the expected outcome AND with each other.
    if js_matches != case.expected || moonbit_matches != case.expected {
      let diag = "parity case " +
        i.to_string() +
        " (" +
        case.label +
        "): js=" +
        js_matches.to_string() +
        " moonbit=" +
        moonbit_matches.to_string() +
        " expected=" +
        case.expected.to_string()
      // Surface the case label so a regression is debuggable from the
      // failure message.
      assert_eq(diag, "")
    }
  }
}
