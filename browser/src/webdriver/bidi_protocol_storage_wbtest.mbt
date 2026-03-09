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
test "bidi script rememberSyntheticLocationHref overrides window.location.href" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.rememberSyntheticLocationHref\",\"params\":{\"context\":\"session-1\",\"href\":\"http://localhost:8000/webdriver/tests/support/initial.html\"}}",
  )
  let remember_msgs = proto.take_messages()
  assert_eq(remember_msgs.length(), 1)
  assert_true(remember_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"window.location.href\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_msgs = proto.take_messages()
  assert_eq(eval_msgs.length(), 1)
  let eval_json = eval_msgs[0].to_json()
  assert_true(eval_json.contains("\"type\":\"success\""))
  assert_true(
    eval_json.contains(
      "\"value\":\"http://localhost:8000/webdriver/tests/support/initial.html\"",
    ),
  )
}

///|
test "bidi script evaluateResult unwraps synthetic window.location.href" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.rememberSyntheticLocationHref\",\"params\":{\"context\":\"session-1\",\"href\":\"http://localhost:8000/webdriver/tests/support/initial.html\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluateResult\",\"params\":{\"expression\":\"window.location.href\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let eval_json = proto.take_messages()[0].to_json()
  assert_true(eval_json.contains("\"type\":\"success\""))
  assert_true(eval_json.contains("\"result\"") == false)
  assert_true(
    eval_json.contains(
      "\"value\":\"http://localhost:8000/webdriver/tests/support/initial.html\"",
    ),
  )
}

///|
test "bidi synthetic location href is used for document.cookie base url" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.rememberSyntheticLocationHref\",\"params\":{\"context\":\"session-1\",\"href\":\"http://alt.localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"script.evaluate\",\"params\":{\"expression\":\"document.cookie = 'token=xyz;path=/;SameSite=None;Secure'\",\"target\":{\"context\":\"session-1\"},\"awaitPromise\":false}}",
  )
  let set_msgs = proto.take_messages()
  assert_eq(set_msgs.length(), 1)
  assert_true(set_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"storage.getCookies\",\"params\":{\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}",
  )
  let get_msgs = proto.take_messages()
  assert_eq(get_msgs.length(), 1)
  let get_json = get_msgs[0].to_json()
  assert_true(get_json.contains("\"name\":\"token\""))
  assert_true(get_json.contains("\"domain\":\"alt.localhost\""))
}

///|
test "bidi storage getContextCookieInfo reports default context scope" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"storage.getContextCookieInfo\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"baseUrl\":\"http://localhost:8000/webdriver/tests/support/empty.html\"",
    ),
  )
  assert_true(json.contains("\"origin\":\"http://localhost:8000\""))
  assert_true(json.contains("\"domain\":\"localhost\""))
  assert_true(json.contains("\"defaultPath\":\"/webdriver/tests/support\""))
  assert_true(json.contains("\"userContext\":\"default\""))
}

///|
test "bidi storage getContextCookieInfo uses synthetic location href" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"script.rememberSyntheticLocationHref\",\"params\":{\"context\":\"session-1\",\"href\":\"http://alt.localhost:8000/webdriver/tests/support/dir/page.html\"}}",
  )
  ignore(proto.take_messages())

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"storage.getContextCookieInfo\",\"params\":{\"context\":\"session-1\"}}",
  )
  let json = proto.take_messages()[0].to_json()
  assert_true(json.contains("\"type\":\"success\""))
  assert_true(
    json.contains(
      "\"baseUrl\":\"http://alt.localhost:8000/webdriver/tests/support/dir/page.html\"",
    ),
  )
  assert_true(json.contains("\"origin\":\"http://alt.localhost:8000\""))
  assert_true(json.contains("\"domain\":\"alt.localhost\""))
  assert_true(json.contains("\"defaultPath\":\"/webdriver/tests/support/dir\""))
  assert_true(json.contains("\"userContext\":\"default\""))
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

///|
test "bidi storage rememberDocumentCookie populates request cookies" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"storage.rememberDocumentCookie\",\"params\":{\"context\":\"session-1\",\"cookie\":\"token=xyz;path=/;SameSite=None;Secure\"}}",
  )
  let remember_msgs = proto.take_messages()
  assert_eq(remember_msgs.length(), 1)
  assert_true(remember_msgs[0].to_json().contains("\"type\":\"success\""))

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"storage.resolveRequestCookies\",\"params\":{\"context\":\"session-1\",\"requestUrl\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  let request_msgs = proto.take_messages()
  assert_eq(request_msgs.length(), 1)
  let request_json = request_msgs[0].to_json()
  assert_true(request_json.contains("\"type\":\"success\""))
  assert_true(request_json.contains("\"name\":\"token\""))
  assert_true(request_json.contains("\"value\":\"xyz\""))
}

///|
test "bidi storage resolveRequestCookies includes ancestor context cookies and filters by path" {
  let proto = BidiProtocol::new()
  let _ = proto.process_message(
    "{\"id\":1,\"method\":\"session.new\",\"params\":{}}",
  )
  let _ = proto.take_messages()
  let child_id = proto.create_child_context("session-1", "default")

  let _ = proto.process_message(
    "{\"id\":2,\"method\":\"storage.setCookie\",\"params\":{\"cookie\":{\"domain\":\"localhost\",\"name\":\"root\",\"value\":{\"type\":\"string\",\"value\":\"a\"},\"path\":\"/webdriver\",\"sameSite\":\"none\",\"secure\":false},\"partition\":{\"type\":\"context\",\"context\":\"session-1\"}}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":3,\"method\":\"storage.setCookie\",\"params\":{\"cookie\":{\"domain\":\"localhost\",\"name\":\"leaf\",\"value\":{\"type\":\"string\",\"value\":\"b\"},\"path\":\"/webdriver/tests/support\",\"sameSite\":\"none\",\"secure\":false},\"partition\":{\"type\":\"context\",\"context\":\"" +
    child_id +
    "\"}}}",
  )
  let _ = proto.take_messages()

  let _ = proto.process_message(
    "{\"id\":4,\"method\":\"storage.resolveRequestCookies\",\"params\":{\"context\":\"" +
    child_id +
    "\",\"requestUrl\":\"http://localhost:8000/webdriver/tests/support/empty.html\"}}",
  )
  let matching_msgs = proto.take_messages()
  assert_eq(matching_msgs.length(), 1)
  let matching_json = matching_msgs[0].to_json()
  assert_true(matching_json.contains("\"name\":\"root\""))
  assert_true(matching_json.contains("\"name\":\"leaf\""))

  let _ = proto.process_message(
    "{\"id\":5,\"method\":\"storage.resolveRequestCookies\",\"params\":{\"context\":\"" +
    child_id +
    "\",\"requestUrl\":\"http://localhost:8000/other\"}}",
  )
  let filtered_msgs = proto.take_messages()
  assert_eq(filtered_msgs.length(), 1)
  let filtered_json = filtered_msgs[0].to_json()
  assert_false(filtered_json.contains("\"name\":\"root\""))
  assert_false(filtered_json.contains("\"name\":\"leaf\""))
}
