///|
/// Verifies that `crater.setOriginAuthorization` stores the supplied
/// header value on the per-session profile's AuthState under the
/// requested origin.
test "crater.setOriginAuthorization stores per-origin header" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer abc123\"}}",
  )
  ignore(proto.take_messages())
  let profile = proto.profile_for_session("session-1").unwrap()
  match profile.auth_state().header_for_origin("https://api.example.com") {
    Some(header) => inspect(header, content="Bearer abc123")
    None => fail("expected origin authorization header")
  }
}

///|
/// Origin is normalized before storage: uppercase host is lowercased and
/// the default port (443 for https, 80 for http) is stripped. The
/// original casing must NOT match the stored entry.
test "crater.setOriginAuthorization normalizes origin" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://Example.COM:443\",\"headerValue\":\"Bearer abc\"}}",
  )
  ignore(proto.take_messages())
  let profile = proto.profile_for_session("session-1").unwrap()
  match profile.auth_state().header_for_origin("https://example.com") {
    Some(header) => inspect(header, content="Bearer abc")
    None => fail("expected normalized origin authorization header")
  }
  inspect(
    profile.auth_state().header_for_origin("https://Example.COM:443") is None,
    content="true",
  )
}

///|
/// Missing headerValue must produce `invalid argument` with a message
/// that names the offending field.
test "crater.setOriginAuthorization rejects missing headerValue" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("headerValue"))
}

///|
/// CRLF / control characters in the header value must be rejected so the
/// stored value cannot be smuggled into a subsequent header line.
test "crater.setOriginAuthorization rejects CRLF in headerValue" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer abc\\r\\nX-Spoof: evil\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("control"))
}

///|
/// Non-http(s) schemes are rejected outright.
test "crater.setOriginAuthorization rejects non-http scheme" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"ftp://example.com\",\"headerValue\":\"Bearer abc\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
/// An origin with a path component is malformed; only scheme + host
/// [+ port] is allowed.
test "crater.setOriginAuthorization rejects path in origin" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://example.com/api\",\"headerValue\":\"Bearer abc\"}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
/// `crater.clearOriginAuthorization` removes a previously-registered
/// entry. A subsequent `header_for_origin` lookup must return None.
test "crater.clearOriginAuthorization removes the entry" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer abc\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"crater.clearOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\"}}",
  )
  ignore(proto.take_messages())
  let profile = proto.profile_for_session("session-1").unwrap()
  inspect(
    profile.auth_state().header_for_origin("https://api.example.com") is None,
    content="true",
  )
}

///|
/// `apply_effective_viewport_to_runtime_context` re-pushes the auth snapshot
/// at every `script.evaluate` boundary, so the JS-side `__bidiResolveAuth`
/// bridge sees the latest registered values even if the runtime state was
/// cleared between evaluations. The test deliberately wipes `__bidiContextAuth`
/// inside the first evaluate, then confirms the second evaluate re-installs
/// the snapshot via the lifecycle hook.
test "apply_effective_viewport_to_runtime_context pushes auth snapshot" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  // Register an Authorization header for a test origin.
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer lifecycle-test\"}}",
  )
  ignore(proto.take_messages())
  // First evaluate: deliberately wipe the auth map to simulate a fresh
  // runtime state (e.g. after a page navigation that resets globals).
  // This proves that the lifecycle hook — not the setOriginAuthorization
  // push — is what makes the value available in the second evaluate.
  let wipe_expr = "delete globalThis.__bidiContextAuth; delete globalThis.__bidiResolveAuth; 'wiped'"
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(wipe_expr).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  ignore(proto.take_messages())
  // Second evaluate: apply_effective_viewport_to_runtime_context runs and
  // re-pushes the auth snapshot before the expression body executes.
  let check_expr = "(function(){ var r = (typeof globalThis.__bidiResolveAuth === 'function') ? globalThis.__bidiResolveAuth('https://api.example.com/x') : '<no-fn>'; return r === null || r === undefined ? '<null>' : r; })()"
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":" +
    Json::string(check_expr).stringify() +
    ",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  let resp = msgs[0].to_json()
  // The lifecycle hook must have re-pushed the auth snapshot so the bridge
  // can return the exact header value registered above.
  assert_true(resp.contains("Bearer lifecycle-test"))
}

///|
/// `crater.listOriginAuthorizations` returns the registered origins
/// without leaking the header values into the BiDi response payload.
test "crater.listOriginAuthorizations returns origins without values" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://api.example.com\",\"headerValue\":\"Bearer secret-token\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"crater.setOriginAuthorization\",\"params\":{\"origin\":\"https://auth.example.com\",\"headerValue\":\"Bearer another-secret\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"crater.listOriginAuthorizations\",\"params\":{}}",
  )
  let msgs = proto.take_messages()
  let json = msgs[0].to_json()
  assert_true(json.contains("https://api.example.com"))
  assert_true(json.contains("https://auth.example.com"))
  // Header values MUST NOT appear in the response.
  assert_true(!json.contains("secret-token"))
  assert_true(!json.contains("another-secret"))
}
