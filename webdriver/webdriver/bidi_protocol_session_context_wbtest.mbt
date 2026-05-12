///|
/// WebDriver BiDi session, browser, and core browsingContext protocol regression tests.

///|
test "bidi session status" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.status\",\"params\":{}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"ready\":true"))
}

///|
test "bidi session new resets stale contexts for getRealms" {
  let proto = BidiProtocol::new()

  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.getRealms\",\"params\":{}}",
  )
  let before_msgs = proto.take_messages()
  assert_eq(before_msgs.length(), 1)
  let before_json = before_msgs[0].to_json()
  assert_true(before_json.contains("\"context\":\"session-1\""))
  assert_true(before_json.contains("\"context\":\"session-2\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.getRealms\",\"params\":{}}",
  )
  let after_msgs = proto.take_messages()
  assert_eq(after_msgs.length(), 1)
  let after_json = after_msgs[0].to_json()
  assert_false(after_json.contains("\"context\":\"session-1\""))
  assert_false(after_json.contains("\"context\":\"session-2\""))
  assert_true(after_json.contains("\"context\":\"session-3\""))
}

///|
test "bidi browsingContext create emits events before response" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext\",\"script\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 3)
  assert_true(msgs[0].to_json().contains("browsingContext.contextCreated"))
  assert_true(msgs[1].to_json().contains("script.realmCreated"))
  assert_true(msgs[2].to_json().contains("\"type\":\"success\""))
}

///|
test "bidi global contextCreated subscribe does not replay existing context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.contextCreated\"]}}",
  )
  let sub_msgs = proto.take_messages()
  assert_eq(sub_msgs.length(), 1)
  assert_true(sub_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let response_json = msgs[1].to_json()
  assert_true(event_json.contains("browsingContext.contextCreated"))
  assert_true(event_json.contains("\"context\":\"session-2\""))
  assert_true(response_json.contains("\"context\":\"session-2\""))
}

///|
test "bidi browsingContext close unknown context returns no such frame" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.close\",\"params\":{\"context\":\"foo\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"no such frame\""))
}

///|
test "bidi browsingContext close rejects child context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<iframe src='about:blank'></iframe>\",\"wait\":\"complete\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.close\",\"params\":{\"context\":\"session-2\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi browsingContext navigate normalizes WPT headers_echo URL in protocol" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.setExtraHeaders\",\"params\":{\"contexts\":[\"session-1\"],\"headers\":[{\"name\":\"x-test\",\"value\":{\"type\":\"string\",\"value\":\"ok\"}},{\"name\":\"x-unicode\",\"value\":{\"type\":\"string\",\"value\":\"你好世界\"}}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\",\"wait\":\"complete\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"url\":\"data:text/html;charset=utf-8;base64,"))
  assert_true(json.contains("#frag"))

  let current_url = match proto.manager.get_session("session-1") {
    Some(session) => session.get_url()
    None => ""
  }
  assert_true(current_url.has_prefix("data:text/html;charset=utf-8;base64,"))
  assert_true(current_url.has_suffix("#frag"))
  match parse_data_url(current_url) {
    Some((_content_type, content)) => {
      assert_true(content.contains("\"x-test\":[\"ok\"]"))
      assert_true(content.contains("\\u4f60\\u597d\\u4e16\\u754c"))
    }
    None => assert_true(false)
  }
}

///|
test "bidi browsingContext createSyntheticChildContext updates context tree" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"context\":\"session-2\""))
  assert_true(json.contains("\"parentContext\":\"session-1\""))
  assert_true(json.contains("\"userContext\":\"default\""))

  let child_parent = proto.context_parent.get("session-2").unwrap_or("")
  assert_eq(child_parent, "session-1")
  let child_user_context = proto.context_user_context
    .get("session-2")
    .unwrap_or("")
  assert_eq(child_user_context, "default")
  let parent_children = proto.context_children.get("session-1").unwrap_or([])
  assert_eq(parent_children.length(), 1)
  assert_eq(parent_children[0], "session-2")

  let child_url = match proto.manager.get_session("session-2") {
    Some(session) => session.get_url()
    None => ""
  }
  assert_eq(
    child_url, "http://localhost:8000/webdriver/tests/support/empty.html",
  )
}

///|
test "bidi browsingContext createAndGetInfo returns created context entry" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.createAndGetInfo\",\"params\":{\"type\":\"tab\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"context\":\"session-2\""))
  assert_true(json.contains("\"url\":\"about:blank\""))
  assert_true(
    json.contains("\"children\":null") || json.contains("\"children\":[]"),
  )
  assert_true(json.contains("\"userContext\":\"default\""))
}

///|
test "bidi browsingContext createAndGetInfoValue returns raw created context entry" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.createAndGetInfoValue\",\"params\":{\"type\":\"tab\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"context\":\"session-2\""))
  assert_true(json.contains("\"url\":\"about:blank\""))
  assert_true(
    json.contains("\"children\":null") || json.contains("\"children\":[]"),
  )
  assert_true(json.contains("\"userContext\":\"default\""))
}

///|
test "bidi browsingContext createContextId returns raw created context id" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.createContextId\",\"params\":{\"type\":\"tab\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":\"session-2\""))
  assert_false(json.contains("\"url\":\"about:blank\""))
}

///|
test "bidi browsingContext createAndGetInfo accepts snake_case aliases" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.createAndGetInfo\",\"params\":{\"type_hint\":\"tab\",\"user_context\":\"user-1\"}}",
  )
  let created_json = proto.take_messages()[0].to_json()
  assert_true(created_json.contains("\"type\":\"success\""))
  assert_true(created_json.contains("\"context\":\"session-2\""))
  assert_true(created_json.contains("\"userContext\":\"user-1\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.createAndGetInfo\",\"params\":{\"reference_context\":\"session-2\"}}",
  )
  let inherited_json = proto.take_messages()[0].to_json()
  assert_true(inherited_json.contains("\"type\":\"success\""))
  assert_true(inherited_json.contains("\"context\":\"session-3\""))
  assert_true(inherited_json.contains("\"userContext\":\"user-1\""))
}

///|
test "bidi browsingContext setViewport accepts user_contexts alias" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.setViewport\",\"params\":{\"user_contexts\":[\"user-1\"],\"viewport\":{\"width\":640,\"height\":480}}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(proto.user_context_viewport_width.get("user-1") == Some(640))
  assert_true(proto.user_context_viewport_height.get("user-1") == Some(480))
}

///|
test "bidi browsingContext setViewport accepts device_pixel_ratio alias" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.setViewport\",\"params\":{\"context\":\"session-1\",\"viewport\":{\"width\":640,\"height\":480},\"device_pixel_ratio\":2}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(proto.context_device_pixel_ratio.get("session-1") == Some(2.0))
}

///|
test "bidi browser createUserContext accepts snake_case aliases" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContext\",\"params\":{\"accept_insecure_certs\":false,\"unhandled_prompt_behavior\":{\"default\":\"ignore\"}}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"userContext\":\"user-1\""))
  let behavior = proto.user_context_prompt_behavior.get("user-1").unwrap()
  assert_eq(behavior.stringify(), "{\"default\":\"ignore\"}")
}

///|
test "bidi browser createUserContextId returns raw id string" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContextId\",\"params\":{}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":\"user-1\""))
}

///|
test "bidi browser getUserContextsList returns raw entries" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browser.getUserContextsList\",\"params\":{}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":["))
  assert_true(json.contains("\"userContext\":\"default\""))
  assert_true(json.contains("\"userContext\":\"user-1\""))
}

///|
test "bidi browser getClientWindowsList returns raw entries" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.getClientWindowsList\",\"params\":{}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":["))
  assert_true(json.contains("\"clientWindow\":\"client-window-session-1\""))
}

///|
test "bidi browsingContext getContextScopeInfo returns ancestry and user context" {
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
    "{\"id\":3,\"method\":\"browsingContext.getContextScopeInfo\",\"params\":{\"context\":\"session-2\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"known\":true"))
  assert_true(json.contains("\"context\":\"session-2\""))
  assert_true(json.contains("\"topLevelContext\":\"session-1\""))
  assert_true(json.contains("\"parent\":\"session-1\""))
  assert_true(json.contains("\"userContext\":\"default\""))
  assert_true(json.contains("\"isTopLevel\":false"))
  assert_true(json.contains("\"ancestry\":[\"session-1\",\"session-2\"]"))
}

///|
test "bidi browsingContext getContextScopeInfo reports unknown context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"browsingContext.getContextScopeInfo\",\"params\":{\"context\":\"missing\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"known\":false"))
  assert_true(json.contains("\"context\":\"missing\""))
}

///|
test "bidi browsingContext isKnownContext returns raw bool" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.isKnownContext\",\"params\":{\"context\":\"session-1\"}}",
  )
  let known_json = proto.take_messages()[0].to_json()
  assert_true(known_json.contains("\"type\":\"success\""))
  assert_true(known_json.contains("\"result\":true"))
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.isKnownContext\",\"params\":{\"context\":\"missing\"}}",
  )
  let missing_json = proto.take_messages()[0].to_json()
  assert_true(missing_json.contains("\"type\":\"success\""))
  assert_true(missing_json.contains("\"result\":false"))
}

///|
test "bidi browsingContext getRequestedNavigationUrl keeps original requested url" {
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
    "{\"id\":3,\"method\":\"browsingContext.getRequestedNavigationUrl\",\"params\":{\"context\":\"session-1\"}}",
  )
  let requested_json = proto.take_messages()[0].to_json()
  assert_true(requested_json.contains("\"type\":\"success\""))
  assert_true(
    requested_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\"",
    ),
  )

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.reload\",\"params\":{\"context\":\"session-1\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browsingContext.getRequestedNavigationUrl\",\"params\":{\"context\":\"session-1\"}}",
  )
  let reload_json = proto.take_messages()[0].to_json()
  assert_true(reload_json.contains("\"type\":\"success\""))
  assert_true(
    reload_json.contains(
      "\"url\":\"http://localhost:8000/webdriver/tests/support/http_handlers/headers_echo.py#frag\"",
    ),
  )
}

///|
test "bidi browsingContext getContextInfo returns a single context entry" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.getContextInfo\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"context\":\"session-1\""))
  assert_true(json.contains("\"url\":\"about:blank\""))
  assert_true(
    json.contains("\"children\":null") || json.contains("\"children\":[]"),
  )
  assert_true(json.contains("\"userContext\":\"default\""))
}

///|
test "bidi browsingContext getTreeContexts returns raw contexts array" {
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
    "{\"id\":3,\"method\":\"browsingContext.getTreeContexts\",\"params\":{\"root\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":[{"))
  assert_true(json.contains("\"context\":\"session-1\""))
  assert_true(json.contains("\"context\":\"session-2\""))
}

///|
test "bidi browsingContext getTreeContexts accepts max_depth alias" {
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
    "{\"id\":3,\"method\":\"browsingContext.getTreeContexts\",\"params\":{\"max_depth\":0}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":[{"))
  assert_true(json.contains("\"context\":\"session-1\""))
  assert_false(json.contains("\"context\":\"session-2\""))
}

///|
test "bidi session prepareBaselineContextForTest clears some variable and returns context info" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,baseline\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"globalThis.SOME_VARIABLE = 42; globalThis.SOME_VARIABLE\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.prepareBaselineContextForTest\",\"params\":{}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))
  assert_true(prepare_json.contains("\"contextInfo\""))
  assert_true(prepare_json.contains("\"url\":\"about:blank\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"typeof globalThis.SOME_VARIABLE\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"value\":\"undefined\""))
}

///|
test "bidi session prepareBaselineContextForTest clears custom user contexts" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.prepareBaselineContextForTest\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browser.getUserContextsList\",\"params\":{}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"userContext\":\"default\""))
  assert_false(json.contains("\"userContext\":\"user-1\""))
}

///|
test "bidi session getBaselineContextInfoForTest returns current baseline context info" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let url = "data:text/html,baseline-info"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    url +
    "\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.getBaselineContextInfoForTest\",\"params\":{}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"context\":\"session-1\""))
  assert_true(json.contains("\"contextInfo\""))
  assert_true(json.contains("\"url\":\"" + url + "\""))
}

///|
test "bidi session getBaselineContextInfoValueForTest returns raw baseline context info" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let url = "data:text/html,baseline-info-raw"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    url +
    "\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.getBaselineContextInfoValueForTest\",\"params\":{}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"context\":\"session-1\""))
  assert_true(json.contains("\"url\":\"" + url + "\""))
}

///|
test "bidi network prepareContextForTest navigates default context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let url = "data:text/html,prepared-context"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"network.prepareContextForTest\",\"params\":{\"url\":\"" +
    url +
    "\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))
  assert_true(prepare_json.contains("\"url\":\"" + url + "\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.getCurrentUrlValue\",\"params\":{\"context\":\"session-1\"}}",
  )
  let current_url_json = proto.take_messages()[0].to_json()
  assert_true(current_url_json.contains("\"type\":\"success\""))
  assert_true(current_url_json.contains("\"result\":\"" + url + "\""))
}

///|
test "bidi browsingContext getCurrentUrl returns current url" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let url = "data:text/html,current-url"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    url +
    "\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.getCurrentUrl\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"context\":\"session-1\""))
  assert_true(json.contains("\"url\":\"" + url + "\""))
}

///|
test "bidi browsingContext getCurrentUrlValue returns raw url string" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let url = "data:text/html,current-url-value"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    url +
    "\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.getCurrentUrlValue\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":\"" + url + "\""))
}

///|
test "bidi browsingContext getCurrentUrlValue rejects invalid context type" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"browsingContext.getCurrentUrlValue\",\"params\":{\"context\":42}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}
