///|
/// Tests for the BiDi runtime authorization bridge installed by
/// `set_runtime_context_authorization`. The bridge is the mirror of the
/// outbound cookie bridge (`__bidiResolveCookies`): it pushes the
/// per-context Authorization header snapshot into
/// `globalThis.__bidiContextAuth[ctxId]` and lazily installs
/// `globalThis.__bidiResolveAuth(url)` which the fetch shim calls to
/// attach an `Authorization` header on outbound requests that target a
/// registered origin.
///
/// These pin the JS-side semantics:
/// 1. With an empty snapshot the resolver returns null for any URL.
/// 2. A registered origin returns the exact header value for a request
///    whose URL parses to that origin.
/// 3. Default ports (`:443` https / `:80` http) are stripped during
///    origin extraction so they match a snapshot keyed without a port.
/// 4. A non-registered origin returns null.
///
/// We drive the bridge directly via `evaluate_js` rather than going
/// through a `script.evaluate` round-trip because the bridge is a pure
/// JS function; the BiDi handlers that feed it are exercised in
/// `bidi_authorization_wbtest.mbt`.

///|
/// Helper: install the auth snapshot for the default context and
/// evaluate `__bidiResolveAuth(url)`, returning the raw JS-stringified
/// result. The current context is left at its default
/// ("default-context"), matching what `reset_runtime_js_state` seeds.
fn install_and_resolve_auth(
  snapshot_json : String,
  request_url : String,
) -> String {
  reset_runtime_js_state()
  set_runtime_context_authorization("default-context", snapshot_json)
  // The resolver returns null or a string; coerce to a sentinel so the
  // test inspection is unambiguous regardless of how the JS bridge
  // surface stringifies a bare `null`.
  let expr = "(function(){ const r = globalThis.__bidiResolveAuth(" +
    Json::string(request_url).stringify() +
    "); return r === null || r === undefined ? \"<null>\" : r; })()"
  evaluate_js(expr)
}

///|
test "__bidiResolveAuth returns null when nothing registered" {
  let result = install_and_resolve_auth("{}", "https://api.example.com/x")
  assert_true(result.contains("<null>"))
}

///|
test "__bidiResolveAuth returns header for matching origin" {
  let result = install_and_resolve_auth(
    "{\"https://api.example.com\":\"Bearer abc123\"}", "https://api.example.com/x",
  )
  assert_true(result.contains("Bearer abc123"))
}

///|
test "__bidiResolveAuth strips default https port when matching" {
  let result = install_and_resolve_auth(
    "{\"https://api.example.com\":\"Bearer abc123\"}", "https://api.example.com:443/x",
  )
  assert_true(result.contains("Bearer abc123"))
}

///|
test "__bidiResolveAuth returns null for mismatched origin" {
  let result = install_and_resolve_auth(
    "{\"https://api.example.com\":\"Bearer abc123\"}", "https://other.com/x",
  )
  assert_true(result.contains("<null>"))
}
