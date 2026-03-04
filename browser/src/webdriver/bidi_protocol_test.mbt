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
