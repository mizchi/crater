///|
test "headers_to_json - empty" {
  let headers : Map[String, String] = {}
  let json = headers_to_json(headers)
  assert_eq(json, "{}")
}

///|
test "headers_to_json - single header" {
  let headers : Map[String, String] = { "Content-Type": "application/json" }
  let json = headers_to_json(headers)
  inspect(json, content="{\"Content-Type\":\"application/json\"}")
}

///|
test "headers_to_json - multiple headers" {
  let headers : Map[String, String] = {}
  headers["Accept"] = "text/html"
  headers["Host"] = "example.com"
  let json = headers_to_json(headers)
  // Verify it parses as valid JSON with correct values
  let parsed = @json.parse(json) catch { _ => fail("invalid JSON") }
  guard parsed is Object(map) else { fail("expected Object") }
  guard map.get("Accept") is Some(String(accept)) else {
    fail("missing Accept")
  }
  assert_eq(accept, "text/html")
  guard map.get("Host") is Some(String(host)) else { fail("missing Host") }
  assert_eq(host, "example.com")
}

///|
test "headers_to_json - escapes special characters" {
  let headers : Map[String, String] = {
    "X-Quote": "a\"b",
    "X-Backslash": "x\\y",
    "X-Newline": "line1\nline2",
  }
  let json = headers_to_json(headers)
  let parsed = @json.parse(json) catch { _ => fail("invalid JSON") }
  guard parsed is Object(map) else { fail("expected Object") }
  guard map.get("X-Quote") is Some(String(v1)) else { fail("missing X-Quote") }
  assert_eq(v1, "a\"b")
  guard map.get("X-Backslash") is Some(String(v2)) else {
    fail("missing X-Backslash")
  }
  assert_eq(v2, "x\\y")
  guard map.get("X-Newline") is Some(String(v3)) else {
    fail("missing X-Newline")
  }
  assert_eq(v3, "line1\nline2")
}

///|
test "Response construction" {
  let resp = Response::{ code: 200, reason: "OK", headers: {} }
  assert_eq(resp.code, 200)
  assert_eq(resp.reason, "OK")
  assert_eq(resp.headers.length(), 0)
}

///|
test "HttpError show" {
  let err1 : HttpError = HttpError::NetworkError("connection refused")
  inspect(err1, content="NetworkError(\"connection refused\")")
  let err2 : HttpError = HttpError::InvalidUrl("bad://url")
  inspect(err2, content="InvalidUrl(\"bad://url\")")
  let err3 : HttpError = HttpError::TimeoutError
  inspect(err3, content="TimeoutError")
  let err4 : HttpError = HttpError::NotSupported
  inspect(err4, content="NotSupported")
}
