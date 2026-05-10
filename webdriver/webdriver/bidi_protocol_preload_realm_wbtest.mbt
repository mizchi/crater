///|
/// WebDriver BiDi preload script and realm lifecycle regression tests.

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
  assert_true(json.contains("\"realm\":\"realm-"))
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
