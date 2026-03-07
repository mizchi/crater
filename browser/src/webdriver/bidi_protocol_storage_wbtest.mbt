///|
test "bidi storage setCookie with context partition is visible to document.cookie" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"storage.setCookie\",\"params\":{\"cookie\":{\"domain\":\"localhost\",\"name\":\"sid\",\"value\":{\"type\":\"string\",\"value\":\"abc\"},\"path\":\"/\",\"sameSite\":\"none\",\"secure\":true},\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}",
  )
  let set_msgs = proto.take_messages()
  assert_eq(set_msgs.length(), 1)
  let set_json = set_msgs[0].to_json()
  assert_true(set_json.contains("\"type\":\"success\""))
  assert_true(set_json.contains("\"partitionKey\""))
  assert_true(set_json.contains("\"userContext\":\"default\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.cookie\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_msgs = proto.take_messages()
  assert_eq(eval_msgs.length(), 1)
  let eval_json = eval_msgs[0].to_json()
  assert_true(eval_json.contains("\"type\":\"success\""))
  assert_true(eval_json.contains("\"value\":\"sid=abc\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"storage.getCookies\",\"params\":{\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}",
  )
  let get_msgs = proto.take_messages()
  assert_eq(get_msgs.length(), 1)
  let get_json = get_msgs[0].to_json()
  assert_true(get_json.contains("\"name\":\"sid\""))
  assert_true(get_json.contains("\"domain\":\"localhost\""))
  assert_true(get_json.contains("\"path\":\"/\""))
}

///|
test "bidi storage deleteCookies removes cookies created via document.cookie" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.cookie = 'token=xyz;path=/;SameSite=None;Secure'\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let set_msgs = proto.take_messages()
  assert_eq(set_msgs.length(), 1)
  assert_true(set_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"storage.getCookies\",\"params\":{\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}",
  )
  let before_msgs = proto.take_messages()
  assert_eq(before_msgs.length(), 1)
  assert_true(before_msgs[0].to_json().contains("\"name\":\"token\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"storage.deleteCookies\",\"params\":{\"filter\":{\"name\":\"token\"},\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}",
  )
  let delete_msgs = proto.take_messages()
  assert_eq(delete_msgs.length(), 1)
  let delete_json = delete_msgs[0].to_json()
  assert_true(delete_json.contains("\"type\":\"success\""))
  assert_true(delete_json.contains("\"partitionKey\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"storage.getCookies\",\"params\":{\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}",
  )
  let after_msgs = proto.take_messages()
  assert_eq(after_msgs.length(), 1)
  let after_json = after_msgs[0].to_json()
  assert_false(after_json.contains("\"name\":\"token\""))
}

///|
test "bidi storage rejects unknown user context partition" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"storage.getCookies\",\"params\":{\"partition\":{\"type\":\"storageKey\",\"userContext\":\"missing\"}}}",
  )
  let msgs = proto.take_messages()
  assert_eq(msgs.length(), 1)
  let json = msgs[0].to_json()
  assert_true(json.contains("\"type\":\"error\""))
  assert_true(json.contains("\"error\":\"no such user context\""))
}
