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
