///|
/// Tests for WebDriver JSON serialization
test "success null response" {
  let resp = success_null()
  inspect(resp.to_json(), content="{\"value\":null}")
}

///|
test "success string response" {
  let resp = success_string("https://example.com")
  inspect(resp.to_json(), content="{\"value\":\"https://example.com\"}")
}

///|
test "success bool response" {
  let resp = success_bool(true)
  inspect(resp.to_json(), content="{\"value\":true}")
}

///|
test "success element response" {
  let resp = success_element("elem-123")
  inspect(
    resp.to_json(),
    content="{\"value\":{\"element-6066-11e4-a52e-4f735466cecf\":\"elem-123\"}}",
  )
}

///|
test "error response" {
  let resp = error_response(NoSuchElement, "Element not found")
  inspect(
    resp.to_json(),
    content="{\"value\":{\"error\":\"no such element\",\"message\":\"Element not found\",\"stacktrace\":\"\"}}",
  )
}

///|
test "timeouts to json" {
  let timeouts : Timeouts = { script: 30000, page_load: 300000, implicit: 0 }
  inspect(
    timeouts.to_json(),
    content="{\"script\":30000,\"pageLoad\":300000,\"implicit\":0}",
  )
}

///|
test "window rect to json" {
  let rect : WindowRect = { x: 0, y: 0, width: 800, height: 600 }
  inspect(
    rect.to_json(),
    content="{\"x\":0,\"y\":0,\"width\":800,\"height\":600}",
  )
}

///|
test "element rect to json" {
  let rect : ElementRect = { x: 10.5, y: 20.5, width: 100.0, height: 50.0 }
  inspect(
    rect.to_json(),
    content="{\"x\":10.5,\"y\":20.5,\"width\":100,\"height\":50}",
  )
}

///|
test "escape json string" {
  let value : WebDriverValue = String("hello\nworld\"test")
  inspect(value.to_json(), content="\"hello\\nworld\\\"test\"")
}

///|
test "array value to json" {
  let value : WebDriverValue = Array([String("a"), String("b"), Number(42.0)])
  inspect(value.to_json(), content="[\"a\",\"b\",42]")
}

///|
test "object value to json" {
  let map : Map[String, WebDriverValue] = {}
  map["name"] = String("test")
  map["value"] = Number(123.0)
  let value : WebDriverValue = Object(map)
  // Note: Map iteration order may vary
  let json = value.to_json()
  assert_true(json.contains("\"name\":\"test\""))
  assert_true(json.contains("\"value\":123"))
}
