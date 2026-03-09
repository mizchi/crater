///|
/// Tests for WebDriver BiDi protocol

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
  assert_true(json.contains("\"children\":[]"))
  assert_true(json.contains("\"userContext\":\"default\""))
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
  assert_eq(proto.user_context_viewport_width.get("user-1"), Some(640))
  assert_eq(proto.user_context_viewport_height.get("user-1"), Some(480))
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
  assert_eq(proto.context_device_pixel_ratio.get("session-1"), Some(2.0))
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
  assert_true(json.contains("\"children\":[]"))
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
  assert_true(prepare_json.contains("\"context\":\"session-1\""))
  assert_true(prepare_json.contains("\"contextInfo\""))
  assert_true(prepare_json.contains("\"url\":\"about:blank\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"typeof globalThis.SOME_VARIABLE\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"value\":\"undefined\""))
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

///|
test "bidi script getElementForTest returns first matching node" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='target'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.getElementForTest\",\"params\":{\"context\":\"session-1\",\"selector\":\"#target\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"node\""))
  assert_true(json.contains("\"sharedId\":\"node-"))
}

///|
test "bidi script getElementForTest creates textarea fallback when requested" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.getElementForTest\",\"params\":{\"context\":\"session-1\",\"selector\":\"textarea\",\"allowFrameFallback\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"node\""))
  assert_true(json.contains("\"sharedId\":\"node-"))
}

///|
test "bidi script prepareLoadedStaticTestPage dispatches DOMContentLoaded and resets allEvents" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<script>var allEvents={events:[{type:'stale'}]};document.addEventListener('DOMContentLoaded',function(){window.__domcontentloaded_ran=true;});</script><input id='keys'><div id='outer'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify({count: window.allEvents.events.length, dom: !!window.__domcontentloaded_ran, focused: globalThis.__bidiFocusedElement === null})\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"count\\\":0,\\\"dom\\\":true,\\\"focused\\\":true}\"",
    ),
  )
}

///|
test "bidi script prepareLoadedStaticTestPage inlineScripts runs scripts in order" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='root'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\",\"phase\":\"inlineScripts\",\"scripts\":[\"window.__inlineOrder = [1];\",\"window.__inlineOrder.push(2);\"]}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify(window.__inlineOrder)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[1,2]\""))
}

///|
test "bidi script setupBeforeunloadPageForTest marks input as interacted" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='target'>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.setupBeforeunloadPageForTest\",\"params\":{\"context\":\"session-1\"}}",
  )
  let setup_json = proto.take_messages()[0].to_json()
  assert_true(setup_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify((() => { const input = document.getElementById('target'); return { value: input && typeof input.value === 'string' ? input.value : '', focused: globalThis.__bidiFocusedElement === input }; })())\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"value\\\":\\\"foo\\\",\\\"focused\\\":true}\"",
    ),
  )
}

///|
test "bidi script prepareLoadedStaticTestPage pageSpecific styles actions fixture" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div class='area' id='area'></div><div class='block' id='block'></div><div id='trackPointer'></div><div id='resultContainer'></div><div id='dragArea'></div><div id='dragTarget'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions.html\",\"phase\":\"pageSpecific\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify((() => { const area = document.getElementById('area'); const dragTarget = document.getElementById('dragTarget'); return {areaWidth: area && area.style ? area.style.width : '', dragTop: dragTarget && dragTarget.style ? dragTarget.style.top : '', dragLeft: dragTarget && dragTarget.style ? dragTarget.style.left : ''}; })())\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"areaWidth\\\":\\\"100px\\\",\\\"dragTop\\\":\\\"22px\\\",\\\"dragLeft\\\":\\\"47px\\\"}\"",
    ),
  )
}

///|
test "bidi script prepareLoadedStaticTestPage pageSpecific sets wheel fixture" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='root'></div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.prepareLoadedStaticTestPage\",\"params\":{\"context\":\"session-1\",\"page\":\"test_actions_scroll.html\",\"phase\":\"pageSpecific\"}}",
  )
  let prepare_json = proto.take_messages()[0].to_json()
  assert_true(prepare_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify((() => { const scrollable = document.getElementById('scrollable'); const iframe = document.getElementById('iframe'); return {overflow: scrollable && scrollable.style ? scrollable.style.overflow : '', hasRecorder: typeof window.recordWheelEvent === 'function', iframeSetup: !!(iframe && iframe.__craterWheelIframeSetup)}; })())\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"value\":\"{\\\"overflow\\\":\\\"scroll\\\",\\\"hasRecorder\\\":true,\\\"iframeSetup\\\":true}\"",
    ),
  )
}

///|
test "bidi script createIframeContextForTest returns child context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.createIframeContextForTest\",\"params\":{\"context\":\"session-1\",\"url\":\"about:blank\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"context\":\"session-"))
  assert_true(json.contains("\"parentContext\":\"session-1\""))
}

///|
test "bidi browser hasUserContext reflects current user contexts" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browser.hasUserContext\",\"params\":{\"userContext\":\"default\"}}",
  )
  let default_json = proto.take_messages()[0].to_json()
  assert_true(default_json.contains("\"type\":\"success\""))
  assert_true(default_json.contains("\"known\":true"))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browser.createUserContext\",\"params\":{}}",
  )
  let create_json = proto.take_messages()[0].to_json()
  assert_true(create_json.contains("\"userContext\":\"user-1\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browser.hasUserContext\",\"params\":{\"userContext\":\"user-1\"}}",
  )
  let created_json = proto.take_messages()[0].to_json()
  assert_true(created_json.contains("\"type\":\"success\""))
  assert_true(created_json.contains("\"known\":true"))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browser.removeUserContext\",\"params\":{\"userContext\":\"user-1\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"browser.hasUserContext\",\"params\":{\"userContext\":\"user-1\"}}",
  )
  let removed_json = proto.take_messages()[0].to_json()
  assert_true(removed_json.contains("\"type\":\"success\""))
  assert_true(removed_json.contains("\"known\":false"))
}

///|
test "bidi session isSubscribedForContext follows parent context subscriptions" {
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
    "{\"id\":3,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"network.beforeRequestSent\"],\"contexts\":[\"session-1\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.isSubscribedForContext\",\"params\":{\"event\":\"network.beforeRequestSent\",\"context\":\"session-2\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"subscribed\":true"))
}

///|
test "bidi browsingContext close promptUnload waits for handleUserPrompt" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.userPromptOpened\",\"browsingContext.contextDestroyed\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\",\"wait\":\"complete\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.close\",\"params\":{\"context\":\"session-1\",\"promptUnload\":true}}",
  )
  let close_msgs = proto.take_messages()
  assert_eq(close_msgs.length(), 1)
  let close_json = close_msgs[0].to_json()
  assert_true(close_json.contains("browsingContext.userPromptOpened"))
  assert_false(close_json.contains("\"id\":4"))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browsingContext.handleUserPrompt\",\"params\":{\"context\":\"session-1\"}}",
  )
  let msgs = proto.take_messages()
  let mut has_close_success = false
  let mut has_handle_success = false
  let mut has_destroyed = false
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":4") && json.contains("\"type\":\"success\"") {
      has_close_success = true
    }
    if json.contains("\"id\":5") && json.contains("\"type\":\"success\"") {
      has_handle_success = true
    }
    if json.contains("browsingContext.contextDestroyed") {
      has_destroyed = true
    }
  }
  assert_true(has_close_success)
  assert_true(has_handle_success)
  assert_true(has_destroyed)
}

///|
test "bidi browsingContext closeWithState promptUnload keeps waitForDestroyed payload" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.userPromptOpened\",\"browsingContext.contextDestroyed\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\",\"wait\":\"complete\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browsingContext.closeWithState\",\"params\":{\"context\":\"session-1\",\"promptUnload\":true}}",
  )
  let close_msgs = proto.take_messages()
  assert_eq(close_msgs.length(), 1)
  let close_json = close_msgs[0].to_json()
  assert_true(close_json.contains("browsingContext.userPromptOpened"))
  assert_false(close_json.contains("\"id\":5"))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"browsingContext.handleUserPrompt\",\"params\":{\"context\":\"session-1\"}}",
  )
  let msgs = proto.take_messages()
  let mut has_close_success = false
  let mut has_wait_flag = false
  let mut has_handle_success = false
  let mut has_destroyed = false
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":5") && json.contains("\"type\":\"success\"") {
      has_close_success = true
      if json.contains("\"waitForDestroyed\":true") {
        has_wait_flag = true
      }
    }
    if json.contains("\"id\":6") && json.contains("\"type\":\"success\"") {
      has_handle_success = true
    }
    if json.contains("browsingContext.contextDestroyed") {
      has_destroyed = true
    }
  }
  assert_true(has_close_success)
  assert_true(has_wait_flag)
  assert_true(has_handle_success)
  assert_true(has_destroyed)
}

///|
test "bidi browsingContext closeResult returns empty payload after destroying contexts" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.contextDestroyed\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.closeResult\",\"params\":{\"context\":\"session-1\"}}",
  )
  let msgs = proto.take_messages()
  let mut has_close_success = false
  let mut has_destroyed = false
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":4") && json.contains("\"type\":\"success\"") {
      has_close_success = true
      assert_false(json.contains("\"waitForDestroyed\""))
      assert_true(json.contains("\"result\":{}"))
    }
    if json.contains("browsingContext.contextDestroyed") {
      has_destroyed = true
    }
  }
  assert_true(has_close_success)
  assert_true(has_destroyed)
}

///|
test "bidi browsingContext closeResult promptUnload returns empty payload" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.userPromptOpened\",\"browsingContext.contextDestroyed\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.createSyntheticChildContext\",\"params\":{\"parentContext\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browsingContext.closeResult\",\"params\":{\"context\":\"session-1\",\"promptUnload\":true}}",
  )
  let close_msgs = proto.take_messages()
  assert_eq(close_msgs.length(), 1)
  let close_json = close_msgs[0].to_json()
  assert_true(close_json.contains("browsingContext.userPromptOpened"))
  assert_false(close_json.contains("\"id\":5"))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"browsingContext.handleUserPrompt\",\"params\":{\"context\":\"session-1\"}}",
  )
  let msgs = proto.take_messages()
  let mut has_close_success = false
  let mut has_handle_success = false
  let mut has_destroyed = false
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":5") && json.contains("\"type\":\"success\"") {
      has_close_success = true
      assert_false(json.contains("\"waitForDestroyed\""))
      assert_true(json.contains("\"result\":{}"))
    }
    if json.contains("\"id\":6") && json.contains("\"type\":\"success\"") {
      has_handle_success = true
    }
    if json.contains("browsingContext.contextDestroyed") {
      has_destroyed = true
    }
  }
  assert_true(has_close_success)
  assert_true(has_handle_success)
  assert_true(has_destroyed)
}

///|
test "bidi browsingContext closeResult accepts prompt_unload alias" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.userPromptOpened\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"http://localhost:8000/webdriver/tests/support/html/beforeunload.html\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.closeResult\",\"params\":{\"context\":\"session-1\",\"prompt_unload\":true}}",
  )
  let close_json = proto.take_messages()[0].to_json()
  assert_true(close_json.contains("browsingContext.userPromptOpened"))
  assert_false(close_json.contains("\"id\":4"))
}

///|
test "bidi session subscribe returns subscription id" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"log.entryAdded\"]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(
    json.contains("\"subscription\":\"00000000000000000000000000000001\""),
  )
}

///|
test "bidi session subscribe and unsubscribe accept user_contexts alias" {
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
    "{\"id\":3,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"log.entryAdded\"],\"user_contexts\":[\"user-1\"]}}",
  )
  let subscribe_json = proto.take_messages()[0].to_json()
  assert_true(subscribe_json.contains("\"type\":\"success\""))
  assert_eq(proto.user_context_subscriptions.get("user-1").unwrap_or([]), [
    "log.entryAdded",
  ])

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.unsubscribe\",\"params\":{\"events\":[\"log.entryAdded\"],\"user_contexts\":[\"user-1\"]}}",
  )
  let unsubscribe_json = proto.take_messages()[0].to_json()
  assert_true(unsubscribe_json.contains("\"type\":\"success\""))
  assert_eq(proto.user_context_subscriptions.get("user-1").unwrap_or([]), [])
}

///|
test "bidi browser setDownloadBehavior accepts user_contexts alias" {
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
    "{\"id\":3,\"method\":\"browser.setDownloadBehavior\",\"params\":{\"downloadBehavior\":{\"type\":\"allowed\",\"destinationFolder\":\"/tmp/downloads\"},\"user_contexts\":[\"user-1\"]}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  let behavior = proto.user_context_download_behavior.get("user-1").unwrap()
  assert_eq(
    behavior.stringify(),
    "{\"type\":\"allowed\",\"destinationFolder\":\"/tmp/downloads\"}",
  )
}

///|
test "bidi event subscription does not subscribe sibling module events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.userPromptOpened\"]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  let msgs = proto.take_messages()
  let mut has_context_created = false
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("browsingContext.contextCreated") {
      has_context_created = true
    }
  }
  assert_false(has_context_created)
}

///|
test "bidi unsubscribe one browsingContext event from module subscription" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.unsubscribe\",\"params\":{\"events\":[\"browsingContext.domContentLoaded\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"about:blank\",\"wait\":\"complete\"}}",
  )
  let msgs = proto.take_messages()
  let mut has_load = false
  let mut has_dom_content_loaded = false
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("browsingContext.load") {
      has_load = true
    }
    if json.contains("browsingContext.domContentLoaded") {
      has_dom_content_loaded = true
    }
  }
  assert_true(has_load)
  assert_false(has_dom_content_loaded)
}

///|
test "bidi unsubscribe by subscription id keeps duplicate subscription" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.load\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"browsingContext.load\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"session.unsubscribe\",\"params\":{\"subscriptions\":[\"00000000000000000000000000000001\"]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"about:blank\",\"wait\":\"complete\"}}",
  )
  let msgs_after_first_unsub = proto.take_messages()
  let mut has_load_after_first_unsub = false
  for msg in msgs_after_first_unsub {
    if msg.to_json().contains("browsingContext.load") {
      has_load_after_first_unsub = true
    }
  }
  assert_true(has_load_after_first_unsub)

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"session.unsubscribe\",\"params\":{\"subscriptions\":[\"00000000000000000000000000000002\"]}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":7,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"about:blank\",\"wait\":\"complete\"}}",
  )
  let msgs_after_second_unsub = proto.take_messages()
  let mut has_load_after_second_unsub = false
  for msg in msgs_after_second_unsub {
    if msg.to_json().contains("browsingContext.load") {
      has_load_after_second_unsub = true
    }
  }
  assert_false(has_load_after_second_unsub)
}

///|
test "bidi input performActions validates context type" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.performActions\",\"params\":{\"context\":true,\"actions\":[]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
}

///|
test "bidi input performActions validates unknown context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.performActions\",\"params\":{\"context\":\"missing\",\"actions\":[]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"no such frame\""))
}

///|
test "bidi input key actions update focused input value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='keys'><script>document.getElementById('keys').focus()</script>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"a\"},{\"type\":\"keyUp\",\"value\":\"a\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.getElementById('keys').value\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"a\""))
}

///|
test "bidi input keyUp without keyDown does not dispatch keyboard events" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='keys'><script>document.getElementById('keys').focus()</script>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.events=[];const k=document.getElementById('keys');k.focus();['keydown','keypress','keyup'].forEach(t=>k.addEventListener(t,e=>window.events.push({type:e.type,key:e.key,code:e.code})));\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyUp\",\"value\":\"a\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":\"[]\""))
}

///|
test "bidi input special right key resolves code and key" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id='keys'><script>document.getElementById('keys').focus()</script>\"}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.events=[];const k=document.getElementById('keys');k.focus();['keydown','keypress','keyup'].forEach(t=>k.addEventListener(t,e=>window.events.push({type:e.type,key:e.key,code:e.code,location:e.location})));\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"key\",\"id\":\"key-0\",\"actions\":[{\"type\":\"keyDown\",\"value\":\"\\uE014\"}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.events[0])\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\\\"key\\\":\\\"ArrowRight\\\""))
  assert_true(json.contains("\\\"code\\\":\\\"ArrowRight\\\""))
}

///|
test "bidi input pointer actions record click event" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div id='outer' style='width:100px;height:100px'></div><script>window.allEvents={events:[]}</script>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events.map(e => e.type))\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(
    json.contains(
      "\"value\":\"[\\\"pointermove\\\",\\\"mousemove\\\",\\\"pointerdown\\\",\\\"mousedown\\\",\\\"pointerup\\\",\\\"mouseup\\\",\\\"click\\\"]\"",
    ),
  )
}

///|
test "bidi input pointerDown can close context without trailing action" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input style='position:absolute;left:0;top:0;width:120px;height:80px' onmousedown='window.close()'>close</input>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0}]}]}}",
  )
  let perform_msgs = proto.take_messages()
  assert_eq(perform_msgs.length(), 1)
  let perform_json = perform_msgs[0].to_json()
  assert_true(perform_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"1\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let evaluate_msgs = proto.take_messages()
  assert_eq(evaluate_msgs.length(), 1)
  let evaluate_json = evaluate_msgs[0].to_json()
  assert_true(evaluate_json.contains("\"type\":\"error\""))
  assert_true(evaluate_json.contains("\"error\":\"no such frame\""))
}

///|
test "bidi script evaluate input.click emits fileDialogOpened event" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"input.fileDialogOpened\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id=input type=file />\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"input.click()\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let result_json = msgs[1].to_json()
  assert_true(event_json.contains("input.fileDialogOpened"))
  assert_true(event_json.contains("\"context\":\"session-1\""))
  assert_true(event_json.contains("\"multiple\":false"))
  assert_true(event_json.contains("\"element\":{\"sharedId\":\"node-"))
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"result\":{\"type\":\"undefined\"}"))
}

///|
test "bidi script evaluate input.click return preserves node result" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"input.fileDialogOpened\"]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input id=input type=file multiple />\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"input.click(); input\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let result_json = msgs[1].to_json()
  assert_true(event_json.contains("input.fileDialogOpened"))
  assert_true(event_json.contains("\"multiple\":true"))
  assert_true(event_json.contains("\"element\":{\"sharedId\":\"node-"))
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"result\":{\"type\":\"node\""))
  assert_true(result_json.contains("\"sharedId\":\"node-"))
}

///|
test "bidi script evaluate showOpenFilePicker emits event without element" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"session.subscribe\",\"params\":{\"events\":[\"input.fileDialogOpened\"]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.showOpenFilePicker({'multiple': true})\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"userActivation\":true}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 2)
  let event_json = msgs[0].to_json()
  let result_json = msgs[1].to_json()
  assert_true(event_json.contains("input.fileDialogOpened"))
  assert_true(event_json.contains("\"context\":\"session-1\""))
  assert_true(event_json.contains("\"multiple\":true"))
  assert_false(event_json.contains("\"element\""))
  assert_true(result_json.contains("\"type\":\"success\""))
  assert_true(result_json.contains("\"result\":{\"type\":\"undefined\"}"))
}

///|
test "bidi script evaluate allEvents returns synthetic setFiles events per context" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.recordSyntheticEvents\",\"params\":{\"context\":\"session-1\",\"events\":[{\"type\":\"input\",\"files\":[\"noop.txt\"]},{\"type\":\"change\",\"files\":[\"noop.txt\"]}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"string\""))
  assert_true(json.contains("\\\"type\\\":\\\"input\\\""))
  assert_true(json.contains("\\\"type\\\":\\\"change\\\""))
  assert_true(json.contains("\\\"files\\\":[\\\"noop.txt\\\"]"))
}

///|
test "bidi script evaluate allEvents isolates contexts for synthetic setFiles events" {
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
    "{\"id\":3,\"method\":\"input.recordSyntheticEvents\",\"params\":{\"context\":\"session-1\",\"events\":[{\"type\":\"input\",\"files\":[\"noop.txt\"]}]}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-2\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains("\"result\":{\"type\":\"string\",\"value\":\"[]\"}"),
  )
}

///|
test "bidi script evaluateResult allEvents unwraps to string remote value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"input.recordSyntheticEvents\",\"params\":{\"context\":\"session-1\",\"events\":[{\"type\":\"input\",\"files\":[\"noop.txt\"]}]}}",
  )
  ignore(proto.take_messages())
  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"string\""))
  assert_true(json.contains("\\\"type\\\":\\\"input\\\""))
}

///|
test "bidi script evaluate allEvents normalizes modifier codes and dedupes consecutive entries" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let html = "data:text/html,<script>window.allEvents={events:[{type:'keydown',key:'Shift',code:'',location:1},{type:'keydown',key:'Shift',code:'',location:1},{type:'keydown',key:'Meta',code:'Unidentified',location:2}]}</script>"
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"" +
    html +
    "\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"JSON.stringify(window.allEvents.events)\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("ShiftLeft"))
  assert_true(json.contains("MetaRight"))
  assert_false(json.contains("\"code\":\"\""))
  assert_false(
    json.contains(
      "\\\"key\\\":\\\"Shift\\\",\\\"code\\\":\\\"ShiftLeft\\\",\\\"location\\\":1},{\\\"type\\\":\\\"keydown\\\",\\\"key\\\":\\\"Shift\\\",\\\"code\\\":\\\"ShiftLeft\\\",\\\"location\\\":1",
    ),
  )
}

///|
test "bidi input pointerDown close reports error when actions continue" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<input style='position:absolute;left:0;top:0;width:120px;height:80px' onmousedown='window.close()'>close</input>\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"input.performActions\",\"params\":{\"context\":\"session-1\",\"actions\":[{\"type\":\"pointer\",\"id\":\"pointer-0\",\"parameters\":{\"pointerType\":\"mouse\"},\"actions\":[{\"type\":\"pointerMove\",\"x\":10,\"y\":10},{\"type\":\"pointerDown\",\"button\":0},{\"type\":\"pointerUp\",\"button\":0}]}]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"no such frame\""))
}

///|
test "bidi script removeAllPreloadScripts clears future contexts" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.addPreloadScript\",\"params\":{\"functionDeclaration\":\"() => { window.foo = 'bar'; }\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.foo\",\"target\":{\"context\":\"session-2\"},\"awaitPromise\":true}}",
  )
  let before_remove_json = proto.take_messages()[0].to_json()
  assert_true(before_remove_json.contains("\"value\":\"bar\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.removeAllPreloadScripts\",\"params\":{}}",
  )
  let remove_json = proto.take_messages()[0].to_json()
  assert_true(remove_json.contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":7,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.foo\",\"target\":{\"context\":\"session-3\"},\"awaitPromise\":true}}",
  )
  let after_remove_json = proto.take_messages()[0].to_json()
  assert_true(after_remove_json.contains("\"type\":\"undefined\""))
}

///|
test "bidi script addPreloadScript accepts snake_case aliases" {
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
    "{\"id\":3,\"method\":\"script.addPreloadScript\",\"params\":{\"function_declaration\":\"() => { window.foo = 'bar'; }\",\"user_contexts\":[\"user-1\"]}}",
  )
  let add_json = proto.take_messages()[0].to_json()
  assert_true(add_json.contains("\"type\":\"success\""))
  assert_true(add_json.contains("\"script\":\"preload-1\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.createAndGetInfo\",\"params\":{\"user_context\":\"user-1\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.foo\",\"target\":{\"context\":\"session-2\"},\"awaitPromise\":true}}",
  )
  let scoped_json = proto.take_messages()[0].to_json()
  assert_true(scoped_json.contains("\"value\":\"bar\""))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.foo\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":true}}",
  )
  let default_json = proto.take_messages()[0].to_json()
  assert_true(default_json.contains("\"type\":\"undefined\""))
}

///|
test "bidi script addPreloadScriptId returns raw script id" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.addPreloadScriptId\",\"params\":{\"functionDeclaration\":\"() => { window.foo = 'bar'; }\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":\"preload-1\""))
}

///|
test "bidi script removePreloadScript accepts nested script object" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.addPreloadScript\",\"params\":{\"functionDeclaration\":\"() => { window.foo = 'bar'; }\"}}",
  )
  let add_json = proto.take_messages()[0].to_json()
  assert_true(add_json.contains("\"script\":\"preload-1\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.removePreloadScript\",\"params\":{\"script\":{\"script\":\"preload-1\"}}}",
  )
  let remove_json = proto.take_messages()[0].to_json()
  assert_true(remove_json.contains("\"type\":\"success\""))
  assert_eq(proto.preload_scripts.length(), 0)
}

///|
test "bidi script getRealmsList returns raw realms array" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.getRealmsList\",\"params\":{}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":[{"))
  assert_true(json.contains("\"context\":\"session-1\""))
  assert_true(json.contains("\"realm\":\"realm-session-1\""))
}

///|
test "bidi session resetForTest clears stale realms and preloads" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.addPreloadScript\",\"params\":{\"functionDeclaration\":\"() => { window.foo = 'bar'; }\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.resetForTest\",\"params\":{}}",
  )
  let reset_json = proto.take_messages()[0].to_json()
  assert_true(reset_json.contains("\"type\":\"success\""))
  assert_true(reset_json.contains("\"context\":\"session-3\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"script.getRealms\",\"params\":{}}",
  )
  let realms_json = proto.take_messages()[0].to_json()
  assert_true(realms_json.contains("\"context\":\"session-3\""))
  assert_false(realms_json.contains("\"context\":\"session-1\""))
  assert_false(realms_json.contains("\"context\":\"session-2\""))

  let _ = proto.process_message(
    "{\"id\":6,\"method\":\"browsingContext.create\",\"params\":{\"type\":\"tab\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":7,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.foo\",\"target\":{\"context\":\"session-4\"},\"awaitPromise\":true}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"type\":\"undefined\""))
}

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

///|
test "bidi script evaluate validates snake_case serializationOptions aliases" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"({foo:{bar:1}})\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"serializationOptions\":{\"max_object_depth\":-1}}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("maxObjectDepth must be a non-negative integer"))
}

///|
test "bidi script callFunction validates snake_case channel serializationOptions aliases" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunction\",\"params\":{\"functionDeclaration\":\"(...args) => args.length\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false,\"arguments\":[{\"type\":\"channel\",\"value\":{\"channel\":\"ch\",\"serializationOptions\":{\"max_object_depth\":-1}}}]}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"invalid argument\""))
  assert_true(json.contains("maxObjectDepth must be a non-negative integer"))
}

///|
test "bidi script evaluate accepts await_promise alias" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"Promise.resolve(42)\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"value\":42"))
}

///|
test "bidi script callFunction accepts snake_case aliases" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunction\",\"params\":{\"function_declaration\":\"async () => ({answer: 42})\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true,\"result_ownership\":\"root\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"handle\":"))
}

///|
test "bidi script evaluateResult unwraps async remote value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"Promise.resolve(42)\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"number\",\"value\":42}"))
  assert_false(json.contains("\"realm\""))
}

///|
test "bidi script evaluateResult keeps exceptionDetails payload" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"(() => { throw new Error('boom'); })()\",\"target\":{\"context\":\"session-1\"}}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"exceptionDetails\""))
  assert_true(json.contains("\"text\":\"Error: boom\""))
}

///|
test "bidi script callFunctionResult unwraps async remote value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"async () => ({answer: 42})\",\"target\":{\"context\":\"session-1\"},\"await_promise\":true}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"object\""))
  assert_false(json.contains("\"realm\""))
}

///|
test "bidi script callFunctionResult unwraps synthetic scroll fallback result" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"browsingContext.navigate\",\"params\":{\"context\":\"session-1\",\"url\":\"data:text/html,<div style='margin-top:768px'>foo</div>\",\"wait\":\"complete\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"() => { const element = document.querySelector('div'); const rect = element.getBoundingClientRect(); window.scrollTo(0, rect.y); return element; }\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"node\""))
  assert_false(json.contains("\"realm\""))
}
