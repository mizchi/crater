///|
/// WebDriver BiDi script evaluate and callFunction result regression tests.

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
test "bidi script evaluateResult window.open unwraps window remote value" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"window.open('about:blank', '_blank', '')\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"result\":{\"type\":\"window\",\"value\":{\"context\":\"session-2\"}}",
    ),
  )
  assert_false(json.contains("\"realm\""))
}

///|
test "bidi handleUserPrompt unwraps evaluateResult confirm remote value" {
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
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"window.confirm('test')\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"browsingContext.handleUserPrompt\",\"params\":{\"context\":\"session-1\",\"accept\":true}}",
  )
  let msgs = proto.take_messages()
  let mut saw_eval_result = false
  for msg in msgs {
    let json = msg.to_json()
    if json.contains("\"id\":3") {
      saw_eval_result = true
      assert_true(json.contains("\"type\":\"success\""))
      assert_true(
        json.contains("\"result\":{\"type\":\"boolean\",\"value\":true}"),
      )
      assert_false(json.contains("\"realm\""))
    }
  }
  assert_true(saw_eval_result)
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
test "bidi script evaluateResult async path keeps sloppy mode unless expression opts into strict mode" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"'use strict';SOME_VARIABLE=1\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":true}}",
  )
  let strict_json = proto.take_messages()[0].to_json()
  assert_true(strict_json.contains("\"type\":\"success\""))
  assert_true(strict_json.contains("\"exceptionDetails\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"SOME_VARIABLE=1\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":true}}",
  )
  let sloppy_json = proto.take_messages()[0].to_json()
  assert_true(sloppy_json.contains("\"type\":\"success\""))
  assert_true(
    sloppy_json.contains("\"result\":{\"type\":\"number\",\"value\":1}"),
  )
  assert_false(sloppy_json.contains("\"exceptionDetails\""))
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

///|
test "bidi script callFunctionResult unwraps synthetic document visibilityState" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"() => document.visibilityState\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains("\"result\":{\"type\":\"string\",\"value\":\"visible\"}"),
  )
  assert_false(json.contains("\"realm\""))
}

///|
test "bidi script callFunctionResult unwraps synthetic document focus state" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.callFunctionResult\",\"params\":{\"function_declaration\":\"() => document.hasFocus()\",\"target\":{\"context\":\"session-1\"},\"await_promise\":false}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(json.contains("\"result\":{\"type\":\"boolean\",\"value\":true}"))
  assert_false(json.contains("\"realm\""))
}
