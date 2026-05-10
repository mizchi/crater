///|
/// WebDriver BiDi deferred navigation, reload, and close state regression tests.

///|
test "bidi browsingContext prepareNavigate reuses blocked navigation preparation" {
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
    "{\"id\":4,\"method\":\"browsingContext.prepareNavigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  assert_true(
    msgs[0].to_json().contains("\"method\":\"network.beforeRequestSent\""),
  )
  let response_json = msgs[1].to_json()
  assert_true(response_json.contains("\"type\":\"success\""))
  assert_true(response_json.contains("\"blocked\":true"))
  assert_true(response_json.contains("\"navigation\":\"1\""))
}

///|
test "bidi browsingContext finalizeNavigate reports blocked synthetic request" {
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
    "{\"id\":4,\"method\":\"browsingContext.finalizeNavigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"navigation\":\"navigation-1\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let response_json = msgs[1].to_json()
  assert_true(event_json.contains("\"method\":\"network.beforeRequestSent\""))
  assert_true(event_json.contains("\"isBlocked\":true"))
  assert_true(response_json.contains("\"type\":\"success\""))
  assert_true(response_json.contains("\"blocked\":true"))
  assert_true(response_json.contains("\"emitted\":1"))
}

///|
test "bidi browsingContext finalizeReload uses remembered requested url" {
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
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.finalizeReload\",\"params\":{\"context\":\"session-1\",\"navigation\":\"navigation-2\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let response_json = msgs[1].to_json()
  assert_true(event_json.contains("\"method\":\"network.beforeRequestSent\""))
  assert_true(
    event_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\"",
    ),
  )
  assert_true(response_json.contains("\"type\":\"success\""))
  assert_true(response_json.contains("\"emitted\":1"))
  assert_true(
    response_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\"",
    ),
  )
}

///|
test "bidi browsingContext reloadWithState uses remembered requested url" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.reloadWithState\",\"params\":{\"context\":\"session-1\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let response_json = msgs[1].to_json()
  assert_true(event_json.contains("\"method\":\"network.beforeRequestSent\""))
  assert_true(
    event_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\"",
    ),
  )
  assert_true(response_json.contains("\"type\":\"success\""))
  assert_true(
    response_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\"",
    ),
  )
}

///|
test "bidi browsingContext reloadWithState prompt defers until handleUserPrompt" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.userPromptOpened\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.reloadWithState\",\"params\":{\"context\":\"session-1\"}}",
  )
  let opened_msgs = proto.take_messages()
  assert_eq(opened_msgs.length(), 1)
  assert_true(
    opened_msgs[0]
    .to_json()
    .contains("\"method\":\"browsingContext.userPromptOpened\""),
  )

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browsingContext.handleUserPrompt\",\"params\":{\"context\":\"session-1\",\"accept\":true}}",
  )
  let handled_msgs = proto.take_messages()
  assert_eq(handled_msgs.length(), 2)
  let reload_json = handled_msgs[0].to_json()
  let prompt_json = handled_msgs[1].to_json()
  assert_true(reload_json.contains("\"id\":4"))
  assert_true(reload_json.contains("\"type\":\"success\""))
  assert_true(
    reload_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\"",
    ),
  )
  assert_true(prompt_json.contains("\"id\":5"))
}

///|
test "bidi browsingContext navigateWithState defers blocked synthetic request" {
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
    "{\"id\":4,\"method\":\"browsingContext.navigateWithState\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"wait\":\"complete\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let event_json = msgs[0].to_json()
  assert_true(event_json.contains("\"method\":\"network.beforeRequestSent\""))
  assert_true(event_json.contains("\"isBlocked\":true"))
  assert_eq(proto.pending_navigation_request.get("session-1"), Some(4))
  assert_true(proto.in_flight_navigation_id.contains("session-1"))
}

///|
test "bidi browsingContext navigateWithState defers responseStarted blocked request" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\",\"network.responseStarted\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"network.addIntercept\",\"params\":{\"phases\":[\"responseStarted\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigateWithState\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.txt\",\"wait\":\"complete\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  assert_true(
    msgs[0].to_json().contains("\"method\":\"network.beforeRequestSent\""),
  )
  assert_true(
    msgs[1].to_json().contains("\"method\":\"network.responseStarted\""),
  )
  assert_true(msgs[1].to_json().contains("\"isBlocked\":true"))
  assert_eq(proto.pending_navigation_request.get("session-1"), Some(4))
  assert_true(proto.in_flight_navigation_id.contains("session-1"))
}

///|
test "bidi browsingContext navigateWithState prompt defers until handleUserPrompt" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.userPromptOpened\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigateWithState\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\",\"wait\":\"complete\"}}",
  )
  let opened_msgs = proto.take_messages()
  assert_eq(opened_msgs.length(), 1)
  assert_true(
    opened_msgs[0]
    .to_json()
    .contains("\"method\":\"browsingContext.userPromptOpened\""),
  )

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browsingContext.handleUserPrompt\",\"params\":{\"context\":\"session-1\",\"accept\":true}}",
  )
  let handled_msgs = proto.take_messages()
  assert_eq(handled_msgs.length(), 2)
  let navigate_json = handled_msgs[0].to_json()
  let prompt_json = handled_msgs[1].to_json()
  assert_true(navigate_json.contains("\"id\":4"))
  assert_true(navigate_json.contains("\"type\":\"success\""))
  assert_true(
    navigate_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"",
    ),
  )
  assert_true(prompt_json.contains("\"id\":5"))
}

///|
test "bidi browsingContext getCloseMetadata reports child contexts" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.getCloseMetadata\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"waitForDestroyed\":true"))
}

///|
test "bidi browsingContext closeWithState reports waitForDestroyed before closing" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.closeWithState\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"waitForDestroyed\":true"))
  assert_false(proto.manager.has_session("session-1"))
}
