///|
test "bidi network buildBeforeRequestSentEvent includes storage cookies" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"storage.rememberDocumentCookie\",\"params\":{\"context\":\"session-1\",\"cookie\":\"token=xyz;path=/;SameSite=None;Secure\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.buildBeforeRequestSentEvent\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"requestId\":\"request-1\",\"requestHeaders\":[{\"name\":\"x-test\",\"value\":{\"type\":\"string\",\"value\":\"ok\"}}],\"intercepts\":[\"intercept-1\"],\"redirectCount\":2,\"navigation\":\"navigation-1\",\"destination\":\"document\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"event\""))
  assert_true(json.contains("\"isBlocked\":true"))
  assert_true(json.contains("\"redirectCount\":2"))
  assert_true(json.contains("\"request\":\"request-1\""))
  assert_true(json.contains("\"name\":\"token\""))
  assert_true(json.contains("\"value\":\"xyz\""))
  assert_true(json.contains("\"destination\":\"document\""))
}

///|
test "bidi network buildBeforeRequestSentEvent resolves extra header scopes in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.setExtraHeaders\",\"params\":{\"headers\":[{\"name\":\"x-shared\",\"value\":{\"type\":\"string\",\"value\":\"global\"}},{\"name\":\"x-global-only\",\"value\":{\"type\":\"string\",\"value\":\"g\"}}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.setExtraHeaders\",\"params\":{\"user_contexts\":[\"default\"],\"headers\":[{\"name\":\"x-shared\",\"value\":{\"type\":\"string\",\"value\":\"user\"}},{\"name\":\"x-user-only\",\"value\":{\"type\":\"string\",\"value\":\"u\"}}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.setExtraHeaders\",\"params\":{\"contexts\":[\"session-1\"],\"headers\":[{\"name\":\"x-shared\",\"value\":{\"type\":\"string\",\"value\":\"context\"}},{\"name\":\"x-context-only\",\"value\":{\"type\":\"string\",\"value\":\"c\"}}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.buildBeforeRequestSentEvent\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"requestId\":\"request-extra-1\",\"requestHeaders\":[{\"name\":\"x-shared\",\"value\":{\"type\":\"string\",\"value\":\"request\"}},{\"name\":\"x-request-only\",\"value\":{\"type\":\"string\",\"value\":\"r\"}}],\"intercepts\":[\"intercept-1\"]}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"name\":\"x-shared\""))
  assert_true(json.contains("\"value\":\"request\""))
  assert_true(json.contains("\"name\":\"x-global-only\""))
  assert_true(json.contains("\"value\":\"g\""))
  assert_true(json.contains("\"name\":\"x-user-only\""))
  assert_true(json.contains("\"value\":\"u\""))
  assert_true(json.contains("\"name\":\"x-context-only\""))
  assert_true(json.contains("\"value\":\"c\""))
  assert_true(json.contains("\"name\":\"x-request-only\""))
  assert_true(json.contains("\"value\":\"r\""))
}

///|
test "bidi network buildHeadersEchoPayload uses extra header scopes" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.setExtraHeaders\",\"params\":{\"headers\":[{\"name\":\"x-global-only\",\"value\":{\"type\":\"string\",\"value\":\"g\"}}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.setExtraHeaders\",\"params\":{\"contexts\":[\"session-1\"],\"headers\":[{\"name\":\"x-context-only\",\"value\":{\"type\":\"string\",\"value\":\"c\"}}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.buildHeadersEchoPayload\",\"params\":{\"context\":\"session-1\",\"requestHeaders\":[{\"name\":\"x-request-only\",\"value\":{\"type\":\"string\",\"value\":\"r\"}}]}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"payload\":\"{"))
  assert_true(json.contains("\\\"x-global-only\\\":[\\\"g\\\"]"))
  assert_true(json.contains("\\\"x-context-only\\\":[\\\"c\\\"]"))
  assert_true(json.contains("\\\"x-request-only\\\":[\\\"r\\\"]"))
}

///|
test "bidi network buildResponseEvent applies response overrides" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.buildResponseEvent\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"requestId\":\"request-2\",\"requestHeaders\":[],\"responseOverrides\":{\"status\":401,\"statusText\":\"Unauthorized\",\"mimeType\":\"text/html\",\"protocol\":\"http/2\",\"fromCache\":true,\"headers\":[{\"name\":\"content-type\",\"value\":{\"type\":\"string\",\"value\":\"text/html\"}}],\"authChallenges\":[{\"scheme\":\"Basic\",\"realm\":\"testrealm\"}]}}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"status\":401"))
  assert_true(json.contains("\"statusText\":\"Unauthorized\""))
  assert_true(json.contains("\"mimeType\":\"text/html\""))
  assert_true(json.contains("\"protocol\":\"http/2\""))
  assert_true(json.contains("\"fromCache\":true"))
  assert_true(json.contains("\"authChallenges\""))
}

///|
test "bidi network buildResponseEvent fills auth defaults from status code" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.buildResponseEvent\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"requestId\":\"request-2b\",\"requestHeaders\":[],\"responseOverrides\":{\"status\":407}}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"status\":407"))
  assert_true(json.contains("\"statusText\":\"Proxy Authentication Required\""))
  assert_true(json.contains("\"authChallenges\":[]"))
}

///|
test "bidi network buildFetchErrorEvent includes errorText" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.buildFetchErrorEvent\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"POST\",\"requestId\":\"request-3\",\"requestHeaders\":[],\"requestValue\":{\"type\":\"string\",\"value\":\"hello\"},\"errorText\":\"Request failed\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"errorText\":\"Request failed\""))
  assert_true(json.contains("\"method\":\"POST\""))
  assert_true(json.contains("\"bodySize\":5"))
}

///|
test "bidi network resolveSyntheticResponseOverrides tracks cache and auth state" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.resolveSyntheticResponseOverrides\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/cached.py?status=204\",\"method\":\"GET\",\"requestHeaders\":[]}}",
  )
  let first = proto.take_messages()[0].to_json()
  assert_true(first.contains("\"status\":204"))
  assert_true(first.contains("\"fromCache\":false"))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.resolveSyntheticResponseOverrides\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/cached.py?status=204\",\"method\":\"GET\",\"requestHeaders\":[]}}",
  )
  let second = proto.take_messages()[0].to_json()
  assert_true(second.contains("\"fromCache\":true"))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.resolveSyntheticResponseOverrides\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/authentication.py?realm=secure\",\"method\":\"GET\",\"requestHeaders\":[]}}",
  )
  let third = proto.take_messages()[0].to_json()
  assert_true(third.contains("\"status\":401"))
  assert_true(third.contains("\"statusText\":\"Unauthorized\""))
  assert_true(third.contains("\"authChallenges\""))
  assert_true(third.contains("WWW-Authenticate"))
}

///|
test "bidi network blocked request state lives in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-9\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"navigation\":\"navigation-9\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-9\"}}",
  )
  let get_json = proto.take_messages()[0].to_json()
  assert_true(get_json.contains("\"request\":\"request-9\""))
  assert_true(get_json.contains("\"phase\":\"beforeRequestSent\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.hasBlockedNavigationRequest\",\"params\":{\"context\":\"session-1\",\"navigation\":\"navigation-9\"}}",
  )
  let has_json = proto.take_messages()[0].to_json()
  assert_true(has_json.contains("\"blocked\":true"))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.forgetBlockedRequest\",\"params\":{\"request\":\"request-9\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"network.hasBlockedNavigationRequest\",\"params\":{\"context\":\"session-1\",\"navigation\":\"navigation-9\"}}",
  )
  let forgotten_json = proto.take_messages()[0].to_json()
  assert_true(forgotten_json.contains("\"blocked\":false"))
}

///|
test "bidi network blocked request raw field queries return phase and navigation" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-raw\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"navigation\":\"navigation-raw\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.getBlockedRequestPhaseValue\",\"params\":{\"request\":\"request-raw\"}}",
  )
  let phase_json = proto.take_messages()[0].to_json()
  assert_true(phase_json.contains("\"type\":\"success\""))
  assert_true(phase_json.contains("\"result\":\"beforeRequestSent\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.getBlockedRequestNavigationValue\",\"params\":{\"request\":\"request-raw\"}}",
  )
  let navigation_json = proto.take_messages()[0].to_json()
  assert_true(navigation_json.contains("\"type\":\"success\""))
  assert_true(navigation_json.contains("\"result\":\"navigation-raw\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.forgetBlockedRequest\",\"params\":{\"request\":\"request-raw\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"network.getBlockedRequestPhaseValue\",\"params\":{\"request\":\"request-raw\"}}",
  )
  let missing_json = proto.take_messages()[0].to_json()
  assert_true(missing_json.contains("\"type\":\"success\""))
  assert_true(missing_json.contains("\"result\":null"))
}

///|
test "bidi network prepareNavigationRequest emits blocked beforeRequestSent event" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.prepareNavigationRequest\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let response_json = msgs[1].to_json()
  assert_true(event_json.contains("\"type\":\"event\""))
  assert_true(event_json.contains("\"method\":\"network.beforeRequestSent\""))
  assert_true(event_json.contains("\"isBlocked\":true"))
  assert_true(event_json.contains("\"request\":\"request-1\""))
  assert_true(event_json.contains("\"navigation\":\"1\""))
  assert_true(response_json.contains("\"type\":\"success\""))
  assert_true(response_json.contains("\"blocked\":true"))
  assert_true(response_json.contains("\"navigation\":\"1\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.hasBlockedNavigationRequest\",\"params\":{\"context\":\"session-1\",\"navigation\":\"1\"}}",
  )
  let blocked_json = proto.take_messages()[0].to_json()
  assert_true(blocked_json.contains("\"blocked\":true"))
}

///|
test "bidi network emitNavigationRequestSequence emits redirect follow-up events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.emitNavigationRequestSequence\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/redirect_http_equiv.html\",\"navigation\":\"navigation-1\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 3)
  let first_event_json = msgs[0].to_json()
  let second_event_json = msgs[1].to_json()
  let response_json = msgs[2].to_json()
  assert_true(
    first_event_json.contains("\"method\":\"network.beforeRequestSent\""),
  )
  assert_true(first_event_json.contains("\"request\":\"request-1\""))
  assert_true(
    first_event_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/redirect_http_equiv.html\"",
    ),
  )
  assert_true(
    second_event_json.contains("\"method\":\"network.beforeRequestSent\""),
  )
  assert_true(second_event_json.contains("\"request\":\"request-2\""))
  assert_true(
    second_event_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/redirected.html\"",
    ),
  )
  assert_true(
    second_event_json.contains("\"navigation\":\"navigation-1-redirect\""),
  )
  assert_true(response_json.contains("\"type\":\"success\""))
  assert_true(response_json.contains("\"emitted\":2"))
}

///|
test "bidi network emitNavigationRequestSequence blocks provide_response resource requests" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"beforeRequestSent\"],\"urlPatterns\":[{\"type\":\"string\",\"pattern\":\"http://localhost:8000/webdriver/tests/bidi/network/support/provide_response.js\"}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.emitNavigationRequestSequence\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/provide_response.html\",\"navigation\":\"navigation-1\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 4)
  let blocked_event_json = msgs[2].to_json()
  let response_json = msgs[3].to_json()
  assert_true(blocked_event_json.contains("\"isBlocked\":true"))
  assert_true(
    blocked_event_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/provide_response.js\"",
    ),
  )
  assert_true(response_json.contains("\"type\":\"success\""))
  assert_true(response_json.contains("\"emitted\":3"))
}

///|
test "bidi network allocateRequestId shares protocol request sequence" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.allocateRequestId\",\"params\":{}}",
  )
  let first_json = proto.take_messages()[0].to_json()
  assert_true(first_json.contains("\"request\":\"request-1\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.emitNavigationRequestSequence\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"navigation\":\"navigation-1\"}}",
  )
  let sequence_msgs = proto.take_messages()
  let sequence_json = sequence_msgs[0].to_json()
  assert_true(sequence_json.contains("\"request\":\"request-2\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.allocateRequestId\",\"params\":{}}",
  )
  let second_json = proto.take_messages()[0].to_json()
  assert_true(second_json.contains("\"request\":\"request-3\""))
}

///|
test "bidi network failBlockedRequest consumes blocked request and returns fetchError event" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-10\",\"blockedRequest\":{\"phase\":\"responseStarted\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"POST\",\"request_headers\":{\"x-test\":\"ok\"},\"request_value\":{\"type\":\"string\",\"value\":\"hello\"},\"redirect_count\":2,\"navigation\":\"navigation-10\",\"destination\":\"document\",\"initiator_type\":\"fetch\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.failBlockedRequest\",\"params\":{\"request\":\"request-10\"}}",
  )
  let fail_json = proto.take_messages()[0].to_json()
  assert_true(fail_json.contains("\"type\":\"success\""))
  assert_true(fail_json.contains("\"event\""))
  assert_true(fail_json.contains("\"errorText\":\"Request failed\""))
  assert_true(fail_json.contains("\"request\":\"request-10\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-10\"}}",
  )
  let forgotten_json = proto.take_messages()[0].to_json()
  assert_true(forgotten_json.contains("\"blockedRequest\":null"))
}

///|
test "bidi network failBlockedRequest rejects authRequired phase" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-11\",\"blockedRequest\":{\"phase\":\"authRequired\",\"context_id\":\"session-1\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.failBlockedRequest\",\"params\":{\"request\":\"request-11\"}}",
  )
  let error_json = proto.take_messages()[0].to_json()
  assert_true(error_json.contains("\"type\":\"error\""))
  assert_true(error_json.contains("\"error\":\"invalid argument\""))
  assert_true(error_json.contains("authRequired requests cannot be failed"))
}

///|
test "bidi network continueAuthRequest default preserves blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-12\",\"blockedRequest\":{\"phase\":\"authRequired\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/authentication.py\",\"method\":\"GET\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueAuthRequest\",\"params\":{\"request\":\"request-12\",\"action\":\"default\"}}",
  )
  let default_json = proto.take_messages()[0].to_json()
  assert_true(default_json.contains("\"type\":\"success\""))
  assert_true(default_json.contains("\"event\":null"))
  assert_true(default_json.contains("\"consumed\":false"))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-12\"}}",
  )
  let still_blocked_json = proto.take_messages()[0].to_json()
  assert_true(still_blocked_json.contains("\"phase\":\"authRequired\""))
}

///|
test "bidi network continueAuthRequest cancel consumes blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-13\",\"blockedRequest\":{\"phase\":\"authRequired\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/authentication.py?realm=secure\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"response_headers\":[{\"name\":\"www-authenticate\",\"value\":{\"type\":\"string\",\"value\":\"Basic realm=\\\"secure\\\"\"}}],\"response_status\":401,\"response_status_text\":\"Unauthorized\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueAuthRequest\",\"params\":{\"request\":\"request-13\",\"action\":\"cancel\"}}",
  )
  let cancel_json = proto.take_messages()[0].to_json()
  assert_true(cancel_json.contains("\"type\":\"success\""))
  assert_true(cancel_json.contains("\"event\""))
  assert_true(cancel_json.contains("\"status\":401"))
  assert_true(cancel_json.contains("\"statusText\":\"Unauthorized\""))
  assert_true(cancel_json.contains("\"authChallenges\":[]"))
  assert_true(cancel_json.contains("\"consumed\":true"))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-13\"}}",
  )
  let forgotten_json = proto.take_messages()[0].to_json()
  assert_true(forgotten_json.contains("\"blockedRequest\":null"))
}

///|
test "bidi network continueResponse on responseStarted consumes blocked request and stores cookies" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-14\",\"blockedRequest\":{\"phase\":\"responseStarted\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/provide-response.html\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"response_headers\":[{\"name\":\"content-type\",\"value\":{\"type\":\"string\",\"value\":\"text/html\"}}],\"response_status\":200,\"response_status_text\":\"OK\",\"navigation\":\"navigation-14\",\"destination\":\"document\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-14\",\"mode\":\"continueResponse\",\"cookies\":[{\"name\":\"token\",\"value\":{\"type\":\"string\",\"value\":\"xyz\"},\"path\":\"/\",\"sameSite\":\"none\",\"secure\":true}]}}",
  )
  let continue_json = proto.take_messages()[0].to_json()
  assert_true(continue_json.contains("\"type\":\"success\""))
  assert_true(continue_json.contains("\"responseCompletedEvent\""))
  assert_true(continue_json.contains("\"Set-Cookie\""))
  assert_true(continue_json.contains("\"browsingContextLoad\""))
  assert_true(continue_json.contains("\"consumed\":true"))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"storage.getCookies\",\"params\":{}}",
  )
  let cookies_json = proto.take_messages()[0].to_json()
  assert_true(cookies_json.contains("\"name\":\"token\""))
  assert_true(cookies_json.contains("\"value\":\"xyz\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-14\"}}",
  )
  let forgotten_json = proto.take_messages()[0].to_json()
  assert_true(forgotten_json.contains("\"blockedRequest\":null"))
}

///|
test "bidi network continueResponse with wrong credentials keeps authRequired blocked" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-15\",\"blockedRequest\":{\"phase\":\"authRequired\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/authentication.py?realm=secure&username=user&password=pass\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"response_headers\":[{\"name\":\"www-authenticate\",\"value\":{\"type\":\"string\",\"value\":\"Basic realm=\\\"secure\\\"\"}}],\"response_status\":401,\"response_status_text\":\"Unauthorized\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-15\",\"mode\":\"continueResponse\",\"credentials\":{\"type\":\"password\",\"username\":\"user\",\"password\":\"wrong\"}}}",
  )
  let continue_json = proto.take_messages()[0].to_json()
  assert_true(continue_json.contains("\"type\":\"success\""))
  assert_true(continue_json.contains("\"authRequiredEvent\""))
  assert_true(continue_json.contains("\"status\":401"))
  assert_true(continue_json.contains("\"consumed\":false"))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-15\"}}",
  )
  let still_blocked_json = proto.take_messages()[0].to_json()
  assert_true(still_blocked_json.contains("\"phase\":\"authRequired\""))
}

///|
test "bidi network provideResponse on beforeRequestSent returns started and completed events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-16\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/provide-response.html\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"navigation\":\"navigation-16\",\"destination\":\"document\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-16\",\"mode\":\"provideResponse\",\"body\":{\"type\":\"string\",\"value\":\"<div>ok</div>\"},\"statusCode\":201,\"reasonPhrase\":\"Created\",\"headers\":[{\"name\":\"content-type\",\"value\":{\"type\":\"string\",\"value\":\"text/html\"}}]}}",
  )
  let provide_json = proto.take_messages()[0].to_json()
  assert_true(provide_json.contains("\"type\":\"success\""))
  assert_true(provide_json.contains("\"responseStartedEvent\""))
  assert_true(provide_json.contains("\"responseCompletedEvent\""))
  assert_true(provide_json.contains("\"status\":201"))
  assert_true(provide_json.contains("\"reasonPhrase\":\"Created\""))
  assert_true(provide_json.contains("\"bodyText\":\"<div>ok</div>\""))
  assert_true(provide_json.contains("\"browsingContextLoad\""))
  assert_true(provide_json.contains("\"consumed\":true"))
}

///|
test "bidi network continueBlockedRequest emits response events and consumes blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-17\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"destination\":\"fetch\",\"initiator_type\":\"fetch\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueBlockedRequest\",\"params\":{\"request\":\"request-17\",\"method\":\"POST\",\"body\":{\"type\":\"string\",\"value\":\"hello\"},\"headers\":[{\"name\":\"x-test\",\"value\":{\"type\":\"string\",\"value\":\"value1\"}},{\"name\":\"x-test\",\"value\":{\"type\":\"string\",\"value\":\"value2\"}}],\"cookies\":[{\"name\":\"token\",\"value\":{\"type\":\"string\",\"value\":\"xyz\"}}],\"navigation\":\"navigation-17b\"}}",
  )
  let continue_json = proto.take_messages()[0].to_json()
  assert_true(continue_json.contains("\"type\":\"success\""))
  assert_true(continue_json.contains("\"responseStartedEvent\""))
  assert_true(continue_json.contains("\"responseCompletedEvent\""))
  assert_true(continue_json.contains("\"method\":\"POST\""))
  assert_true(continue_json.contains("\"bodySize\":5"))
  assert_true(continue_json.contains("value1, value2"))
  assert_true(continue_json.contains("\"name\":\"token\""))
  assert_true(continue_json.contains("\"value\":\"xyz\""))
  assert_true(continue_json.contains("\"navigation\":\"navigation-17b\""))
  assert_true(continue_json.contains("\"consumed\":true"))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-17\"}}",
  )
  let forgotten_json = proto.take_messages()[0].to_json()
  assert_true(forgotten_json.contains("\"blockedRequest\":null"))
}

///|
test "bidi network continueBlockedRequest clears storage cookies when headers override without cookies" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"storage.rememberDocumentCookie\",\"params\":{\"context\":\"session-1\",\"cookie\":\"token=xyz;path=/;SameSite=None;Secure\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-18\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"request_headers\":{},\"destination\":\"fetch\",\"initiator_type\":\"fetch\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.continueBlockedRequest\",\"params\":{\"request\":\"request-18\",\"headers\":[]}}",
  )
  let continue_json = proto.take_messages()[0].to_json()
  assert_true(continue_json.contains("\"type\":\"success\""))
  assert_true(continue_json.contains("\"cookies\":[]"))
  assert_true(not(continue_json.contains("\"name\":\"token\"")))
}

///|
test "bidi network continueBlockedRequest handles navigation in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.load\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let initial_url = "data:text/html,<div id='from-initial'>initial</div>"
  let redirect_url = "data:text/html,<div id='from-redirect'>redirect</div>"
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-19\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"" +
    initial_url +
    "\",\"method\":\"GET\",\"request_headers\":{},\"navigation\":\"navigation-19\",\"destination\":\"document\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.continueBlockedRequest\",\"params\":{\"request\":\"request-19\",\"url\":\"" +
    redirect_url +
    "\"}}",
  )
  let continue_msgs = proto.take_messages()
  assert_eq(continue_msgs.length(), 2)
  assert_true(
    continue_msgs[0].to_json().contains("\"method\":\"browsingContext.load\""),
  )
  assert_true(continue_msgs[1].to_json().contains("\"type\":\"success\""))

  let current_url = match proto.manager.get_session("session-1") {
    Some(session) => session.get_url()
    None => ""
  }
  assert_eq(current_url, redirect_url)

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.location.href\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let href_json = proto.take_messages()[0].to_json()
  assert_true(href_json.contains("\"value\":\"" + initial_url + "\""))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.body.textContent.trim()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let body_json = proto.take_messages()[0].to_json()
  assert_true(body_json.contains("\"value\":\"redirect\""))
}

///|
test "bidi network continueBlockedRequest completes deferred navigate response" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let url = "http://localhost:8000/webdriver/tests/support/empty.html"
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigateWithState\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    url +
    "\",\"wait\":\"complete\"}}",
  )
  let blocked_msgs = proto.take_messages()
  assert_eq(blocked_msgs.length(), 1)
  assert_true(
    blocked_msgs[0]
    .to_json()
    .contains("\"method\":\"network.beforeRequestSent\""),
  )

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.continueBlockedRequest\",\"params\":{\"request\":\"request-1\"}}",
  )
  let continue_msgs = proto.take_messages()
  assert_eq(continue_msgs.length(), 3)
  let combined = continue_msgs[0].to_json() +
    continue_msgs[1].to_json() +
    continue_msgs[2].to_json()
  assert_true(combined.contains("\"id\":5"))
  assert_true(combined.contains("\"id\":4"))
  assert_true(combined.contains("\"method\":\"browsingContext.load\""))
  assert_true(combined.contains("\"url\":\"" + url + "\""))
}

///|
test "bidi network failBlockedRequest fails deferred navigate response" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let url = "http://localhost:8000/webdriver/tests/support/empty.html"
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigateWithState\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    url +
    "\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.failBlockedRequest\",\"params\":{\"request\":\"request-1\"}}",
  )
  let fail_msgs = proto.take_messages()
  assert_eq(fail_msgs.length(), 2)
  let combined = fail_msgs[0].to_json() + fail_msgs[1].to_json()
  assert_true(combined.contains("\"id\":5"))
  assert_true(combined.contains("\"id\":4"))
  assert_true(combined.contains("\"type\":\"error\""))
  assert_true(combined.contains("Navigation failed: Request failed"))
}

///|
test "bidi network continueBlockedResponse completes responseStarted deferred navigate response" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\",\"network.responseStarted\",\"network.responseCompleted\",\"browsingContext.load\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"responseStarted\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let url = "http://localhost:8000/webdriver/tests/support/empty.txt"
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigateWithState\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    url +
    "\",\"wait\":\"complete\"}}",
  )
  let blocked_msgs = proto.take_messages()
  assert_eq(blocked_msgs.length(), 2)
  assert_true(
    blocked_msgs[1].to_json().contains("\"method\":\"network.responseStarted\""),
  )
  assert_eq(proto.pending_navigation_request.get("session-1"), Some(4))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-1\",\"mode\":\"continueResponse\"}}",
  )
  let continue_msgs = proto.take_messages()
  assert_eq(continue_msgs.length(), 4)
  let combined = continue_msgs[0].to_json() +
    continue_msgs[1].to_json() +
    continue_msgs[2].to_json() +
    continue_msgs[3].to_json()
  assert_true(combined.contains("\"id\":5"))
  assert_true(combined.contains("\"id\":4"))
  assert_true(combined.contains("\"method\":\"network.responseCompleted\""))
  assert_true(combined.contains("\"method\":\"browsingContext.load\""))
}

///|
test "bidi network resolveMatchingIntercepts matches data url string patterns" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"beforeRequestSent\"],\"urlPatterns\":[{\"type\":\"string\",\"pattern\":\"data:text/plain,hello\"}]}}",
  )
  let add_json = proto.take_messages()[0].to_json()
  assert_true(add_json.contains("\"type\":\"success\""))
  assert_true(
    add_json.contains("\"intercept\":\"00000000000000000000000000000001\""),
  )

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.resolveMatchingIntercepts\",\"params\":{\"context\":\"session-1\",\"phase\":\"beforeRequestSent\",\"url\":\"data:text/plain,hello\"}}",
  )
  let resolve_json = proto.take_messages()[0].to_json()
  assert_true(resolve_json.contains("\"type\":\"success\""))
  assert_true(
    resolve_json.contains(
      "\"intercepts\":[\"00000000000000000000000000000001\"]",
    ),
  )
}

///|
test "bidi network getData and disownData use protocol collector store" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.addDataCollector\",\"params\":{\"dataTypes\":[\"request\",\"response\"],\"maxEncodedDataSize\":1000}}",
  )
  let add_json = proto.take_messages()[0].to_json()
  assert_true(add_json.contains("\"collector\":\"collector-1\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.rememberCollectedData\",\"params\":{\"context\":\"session-1\",\"request\":\"request-1\",\"requestData\":{\"type\":\"string\",\"value\":\"hello\"},\"responseData\":{\"type\":\"string\",\"value\":\"world\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.getData\",\"params\":{\"request\":\"request-1\",\"dataType\":\"response\",\"collector\":\"collector-1\"}}",
  )
  let get_json = proto.take_messages()[0].to_json()
  assert_true(get_json.contains("\"type\":\"success\""))
  assert_true(get_json.contains("\"value\":\"world\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.disownData\",\"params\":{\"request\":\"request-1\",\"dataType\":\"response\",\"collector\":\"collector-1\"}}",
  )
  let disown_json = proto.take_messages()[0].to_json()
  assert_true(disown_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"network.getData\",\"params\":{\"request\":\"request-1\",\"dataType\":\"response\",\"collector\":\"collector-1\"}}",
  )
  let missing_json = proto.take_messages()[0].to_json()
  assert_true(missing_json.contains("\"type\":\"error\""))
  assert_true(missing_json.contains("\"error\":\"no such network data\""))
}

///|
test "bidi network addDataCollectorId returns raw collector id" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.addDataCollectorId\",\"params\":{\"dataTypes\":[\"request\"],\"maxEncodedDataSize\":1000}}",
  )
  let add_json = proto.take_messages()[0].to_json()
  assert_true(add_json.contains("\"type\":\"success\""))
  assert_true(add_json.contains("\"result\":\"collector-1\""))
}

///|
test "bidi network continueBlockedResponse emits subscribed events after success" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.responseStarted\",\"network.responseCompleted\",\"browsingContext.load\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-20\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/provide-response.html\",\"method\":\"GET\",\"request_headers\":{\"x-test\":\"ok\"},\"navigation\":\"navigation-20\",\"destination\":\"document\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-20\",\"mode\":\"provideResponse\",\"body\":{\"type\":\"string\",\"value\":\"<div>ok</div>\"},\"statusCode\":200,\"reasonPhrase\":\"OK\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 4)
  assert_true(msgs[0].to_json().contains("\"type\":\"success\""))
  assert_true(
    msgs[1].to_json().contains("\"method\":\"network.responseStarted\""),
  )
  assert_true(
    msgs[2].to_json().contains("\"method\":\"network.responseCompleted\""),
  )
  assert_true(msgs[3].to_json().contains("\"method\":\"browsingContext.load\""))
}

///|
test "bidi network provideResponse applies document body override in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-20a\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/provide_response.html\",\"method\":\"GET\",\"request_headers\":{},\"navigation\":\"navigation-20a\",\"destination\":\"document\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-20a\",\"mode\":\"provideResponse\",\"body\":{\"type\":\"string\",\"value\":\"<div id=\\\"from-provide-response\\\"></div>\"},\"statusCode\":200,\"reasonPhrase\":\"OK\"}}",
  )
  let provide_msgs = proto.take_messages()
  assert_true(provide_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"!!document.getElementById('from-provide-response')\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"value\":true"))
}

///|
test "bidi network provideResponse applies script body override in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-20b\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/provide_response.js\",\"method\":\"GET\",\"request_headers\":{},\"navigation\":\"navigation-20b\",\"destination\":\"script\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-20b\",\"mode\":\"provideResponse\",\"body\":{\"type\":\"string\",\"value\":\"window.isFromProvideResponse = true;\"},\"statusCode\":200,\"reasonPhrase\":\"OK\"}}",
  )
  let provide_msgs = proto.take_messages()
  assert_true(provide_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.isFromProvideResponse == true\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"value\":true"))
}

///|
test "bidi network provideResponse applies style body override in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-20c\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/bidi/network/support/provide_response.css\",\"method\":\"GET\",\"request_headers\":{},\"navigation\":\"navigation-20c\",\"destination\":\"style\",\"is_navigation\":true}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-20c\",\"mode\":\"provideResponse\",\"body\":{\"type\":\"string\",\"value\":\"div { color: rgb(255, 0, 0) }\"},\"statusCode\":200,\"reasonPhrase\":\"OK\"}}",
  )
  let provide_msgs = proto.take_messages()
  assert_true(provide_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"(() => { const div = document.createElement('div'); document.body.appendChild(div); return window.getComputedStyle(div).color === 'rgb(255, 0, 0)'; })()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"value\":true"))
}

///|
test "bidi network provideResponse emits followup preflight block in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"beforeRequestSent\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-21\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"OPTIONS\",\"request_headers\":{\"x-test\":\"ok\"},\"destination\":\"fetch\",\"initiator_type\":\"fetch\",\"is_navigation\":false}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.continueBlockedResponse\",\"params\":{\"request\":\"request-21\",\"mode\":\"provideResponse\",\"statusCode\":204,\"reasonPhrase\":\"No Content\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  assert_true(msgs[0].to_json().contains("\"type\":\"success\""))
  assert_true(
    msgs[1].to_json().contains("\"method\":\"network.beforeRequestSent\""),
  )
  assert_true(msgs[1].to_json().contains("\"request\":\"request-1\""))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-1\"}}",
  )
  let blocked_json = proto.take_messages()[0].to_json()
  assert_true(blocked_json.contains("\"phase\":\"beforeRequestSent\""))
  assert_true(blocked_json.contains("\"method\":\"GET\""))
}

///|
test "bidi network failBlockedRequest emits subscribed fetchError after success" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.fetchError\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.rememberBlockedRequest\",\"params\":{\"request\":\"request-22\",\"blockedRequest\":{\"phase\":\"beforeRequestSent\",\"context_id\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"request_headers\":{},\"destination\":\"fetch\",\"initiator_type\":\"fetch\"}}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.failBlockedRequest\",\"params\":{\"request\":\"request-22\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  assert_true(msgs[0].to_json().contains("\"type\":\"success\""))
  assert_true(msgs[1].to_json().contains("\"method\":\"network.fetchError\""))
}

///|
test "bidi network performSyntheticFetch blocks before request in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"beforeRequestSent\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.performSyntheticFetch\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"method\":\"GET\",\"requestHeaders\":[]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  assert_true(
    msgs[0].to_json().contains("\"method\":\"network.beforeRequestSent\""),
  )
  assert_true(msgs[1].to_json().contains("\"blocked\":true"))
  assert_true(
    msgs[1]
    .to_json()
    .contains("\"message\":\"Request blocked by network intercept\""),
  )

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"network.getBlockedRequest\",\"params\":{\"request\":\"request-1\"}}",
  )
  let blocked_json = proto.take_messages()[0].to_json()
  assert_true(blocked_json.contains("\"phase\":\"beforeRequestSent\""))
  assert_true(blocked_json.contains("\"method\":\"GET\""))
}

///|
test "bidi network performSyntheticFetch returns synthetic bytes payload" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.setExtraHeaders\",\"params\":{\"headers\":[{\"name\":\"x-global-only\",\"value\":{\"type\":\"string\",\"value\":\"g\"}}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.responseCompleted\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"network.performSyntheticFetch\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py\",\"method\":\"GET\",\"requestHeaders\":[{\"name\":\"x-request-only\",\"value\":{\"type\":\"string\",\"value\":\"r\"}}]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  assert_true(
    msgs[0].to_json().contains("\"method\":\"network.responseCompleted\""),
  )
  assert_true(msgs[1].to_json().contains("\"blocked\":false"))
  assert_true(msgs[1].to_json().contains("\\\"x-global-only\\\":[\\\"g\\\"]"))
  assert_true(msgs[1].to_json().contains("\\\"x-request-only\\\":[\\\"r\\\"]"))
}
