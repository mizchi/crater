///|
test "wire parse request forwards id method and params" {
  let json =
    #| {"id":7,"method":"session.new","params":{"capabilities":{}}}
  match parse_request(json) {
    Ok(request) => {
      inspect(request.id, content="7")
      inspect(request.method_name, content="session.new")
      match request.params {
        Some(Object(params)) => assert_true(params.contains("capabilities"))
        _ => fail("expected params object")
      }
    }
    Err(err) => fail("unexpected parse error: " + err)
  }
}

///|
test "wire serializes success error and event messages" {
  let success = success_response_to_json(
    1,
    Some(Json::object({ "ok": Json::boolean(true) })),
  )
  assert_true(success.contains("\"id\":1"))
  assert_true(success.contains("\"result\":{\"ok\":true}"))

  let error = error_response_to_json(
    2, "invalid argument", "bad params", "stack",
  )
  assert_true(error.contains("\"id\":2"))
  assert_true(error.contains("\"error\":\"invalid argument\""))
  assert_true(error.contains("\"message\":\"bad params\""))
  assert_true(error.contains("\"stacktrace\":\"stack\""))

  let event = event_to_json(
    "log.entryAdded",
    Json::object({ "text": Json::string("hello") }),
  )
  assert_true(event.contains("\"method\":\"log.entryAdded\""))
  assert_true(event.contains("\"params\":{\"text\":\"hello\"}"))
}
