///|
/// Phase 2 PR A: ensure spec-conformant WebDriver BiDi method names are
/// routed by Crater's dispatcher. These tests probe the spec names
/// directly (without going through the `crater_bidi_modules.py` shim).
///
/// Tracking issue: #147

///|
test "bidi network.addIntercept (spec name) returns intercept object" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"authRequired\"]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  // Spec response shape: { "intercept": "<id>" }
  assert_true(json.contains("\"intercept\":\""))
  // No "unknown command" error
  assert_false(json.contains("unknown command"))
}

///|
test "bidi network.continueWithAuth (spec name) cancel resolves blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-spec-alias-1\",\"blockedRequest\":{\"phase\":\"authRequired\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/authentication.py?realm=secure&username=user&password=pass\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"response_headers\":[{\"name\":\"www-authenticate\",\"value\":{\"type\":\"string\",\"value\":\"Basic realm=\\\"secure\\\"\"}}],\"response_status\":401,\"response_status_text\":\"Unauthorized\"}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueWithAuth\",\"params\":{\"request\":\"request-spec-alias-1\",\"action\":\"cancel\"}}",
  )
  let continue_json = proto.take_messages()[0].to_json()
  assert_true(continue_json.contains("\"type\":\"success\""))
  assert_false(continue_json.contains("unknown command"))
  assert_true(continue_json.contains("\"consumed\":true"))
}

///|
test "bidi network.continueWithAuth (spec name) provideCredentials resolves blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-spec-alias-2\",\"blockedRequest\":{\"phase\":\"authRequired\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/authentication.py?realm=secure&username=u&password=p\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"response_headers\":[{\"name\":\"www-authenticate\",\"value\":{\"type\":\"string\",\"value\":\"Basic realm=\\\"secure\\\"\"}}],\"response_status\":401,\"response_status_text\":\"Unauthorized\"}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueWithAuth\",\"params\":{\"request\":\"request-spec-alias-2\",\"action\":\"provideCredentials\",\"credentials\":{\"type\":\"password\",\"username\":\"u\",\"password\":\"p\"}}}",
  )
  let continue_json = proto.take_messages()[0].to_json()
  assert_true(continue_json.contains("\"type\":\"success\""))
  assert_false(continue_json.contains("unknown command"))
  assert_true(continue_json.contains("\"consumed\":true"))
}

///|
/// Phase 2 PR B: probe the three remaining spec-conformant names so that
/// native BiDi clients can drive `continueResponse`, `provideResponse`,
/// and `failRequest` without going through the WPT shim's rename layer.

///|
test "bidi network.continueResponse (spec name) resolves blocked response" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-spec-alias-3\",\"blockedRequest\":{\"phase\":\"responseStarted\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/echo.py\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"response_headers\":[{\"name\":\"content-type\",\"value\":{\"type\":\"string\",\"value\":\"text/plain\"}}],\"response_status\":200,\"response_status_text\":\"OK\"}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueResponse\",\"params\":{\"request\":\"request-spec-alias-3\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_false(json.contains("unknown command"))
  // The shared continueBlockedResponse handler emits a synthetic
  // responseCompleted event and marks the request as consumed.
  assert_true(json.contains("\"responseCompletedEvent\""))
  assert_true(json.contains("\"consumed\":true"))
}

///|
test "bidi network.provideResponse (spec name) resolves blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-spec-alias-4\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/echo.py\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"}}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.provideResponse\",\"params\":{\"request\":\"request-spec-alias-4\",\"statusCode\":204,\"reasonPhrase\":\"No Content\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_false(json.contains("unknown command"))
  // provideResponse should emit a synthesised response event with the
  // overridden status / reason and mark the request as consumed.
  assert_true(json.contains("\"responseCompletedEvent\""))
  assert_true(json.contains("\"consumed\":true"))
  assert_true(json.contains("\"statusCode\":204"))
}

///|
test "bidi network.failRequest (spec name) fails blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-spec-alias-5\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/echo.py\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"}}}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.failRequest\",\"params\":{\"request\":\"request-spec-alias-5\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_false(json.contains("unknown command"))
  // failRequest emits a synthetic fetchError event.
  assert_true(json.contains("\"event\""))
}
