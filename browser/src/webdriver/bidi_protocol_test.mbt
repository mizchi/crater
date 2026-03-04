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
