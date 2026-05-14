///|
/// WebDriver BiDi prompt, download, and subscription protocol regression tests.

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
test "bidi session subscribeId returns raw subscription id" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.subscribeId\",\"params\":{\"events\":[\"log.entryAdded\"]}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"result\":\"00000000000000000000000000000001\""))
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
  debug_inspect(
    proto.subscription_state.user_context_subscriptions
    .get("user-1")
    .unwrap_or([]),
    content="[\"log.entryAdded\"]",
  )

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"session.unsubscribe\",\"params\":{\"events\":[\"log.entryAdded\"],\"user_contexts\":[\"user-1\"]}}",
  )
  let unsubscribe_json = proto.take_messages()[0].to_json()
  assert_true(unsubscribe_json.contains("\"type\":\"success\""))
  debug_inspect(
    proto.subscription_state.user_context_subscriptions
    .get("user-1")
    .unwrap_or([]),
    content="[]",
  )
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
