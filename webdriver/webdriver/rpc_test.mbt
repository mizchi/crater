///|
/// Tests for JSON-RPC protocol layer
test "rpc id num to json" {
  let id = RpcId::Num(42)
  inspect(id.to_json(), content="42")
}

///|
test "rpc id str to json" {
  let id = RpcId::Str("abc-123")
  inspect(id.to_json(), content="\"abc-123\"")
}

///|
test "rpc id null to json" {
  let id : RpcId = RpcId::Null
  inspect(id.to_json(), content="null")
}

///|
test "rpc success response to json" {
  let resp = rpc_success_string(RpcId::Num(1), "hello")
  let json = resp.to_json()
  assert_true(json.contains("\"jsonrpc\":\"2.0\""))
  assert_true(json.contains("\"id\":1"))
  assert_true(json.contains("\"result\":\"hello\""))
}

///|
test "rpc success null to json" {
  let resp = rpc_success_null(RpcId::Num(2))
  let json = resp.to_json()
  assert_true(json.contains("\"result\":null"))
}

///|
test "rpc success bool to json" {
  let resp = rpc_success_bool(RpcId::Num(3), true)
  let json = resp.to_json()
  assert_true(json.contains("\"result\":true"))
}

///|
test "rpc success number to json" {
  let resp = rpc_success_number(RpcId::Num(4), 42.5)
  let json = resp.to_json()
  assert_true(json.contains("\"result\":42.5"))
}

///|
test "rpc error response to json" {
  let resp = rpc_error(
    RpcId::Num(5),
    RpcErrorCode::MethodNotFound,
    "Unknown method",
  )
  let json = resp.to_json()
  assert_true(json.contains("\"jsonrpc\":\"2.0\""))
  assert_true(json.contains("\"id\":5"))
  assert_true(json.contains("\"error\":"))
  assert_true(json.contains("\"code\":-32601"))
  assert_true(json.contains("\"message\":\"Unknown method\""))
}

///|
test "rpc error with data to json" {
  let resp = rpc_error_with_data(
    RpcId::Num(6),
    RpcErrorCode::ElementNotFound,
    "Not found",
    "{\"selector\":\"#id\"}",
  )
  let json = resp.to_json()
  assert_true(json.contains("\"code\":-32000"))
  assert_true(json.contains("\"data\":{\"selector\":\"#id\"}"))
}

///|
test "error code values" {
  inspect(RpcErrorCode::ParseError.code(), content="-32700")
  inspect(RpcErrorCode::InvalidRequest.code(), content="-32600")
  inspect(RpcErrorCode::MethodNotFound.code(), content="-32601")
  inspect(RpcErrorCode::InvalidParams.code(), content="-32602")
  inspect(RpcErrorCode::InternalError.code(), content="-32603")
  inspect(RpcErrorCode::ElementNotFound.code(), content="-32000")
}

///|
test "api error to rpc error" {
  let id = RpcId::Num(7)
  let api_err : ApiError = ApiError::ElementNotFound(selector="#btn")
  let rpc_resp = api_error_to_rpc(id, api_err)
  let json = rpc_resp.to_json()
  assert_true(json.contains("Element not found"))
  assert_true(json.contains("-32000"))
}

///|
test "parse json object simple" {
  let json = "{\"name\":\"test\",\"value\":\"123\"}"
  let map = parse_json_object(json)
  let name_opt = map.get("name")
  let value_opt = map.get("value")
  match name_opt {
    Some(v) => inspect(v, content="test")
    None => fail("Expected name")
  }
  match value_opt {
    Some(v) => inspect(v, content="123")
    None => fail("Expected value")
  }
}

///|
test "parse json object empty" {
  let json = "{}"
  let map = parse_json_object(json)
  assert_true(map.length() == 0)
}

///|
test "parse method names" {
  inspect(parse_method("newContext"), content="Some(NewContext)")
  inspect(parse_method("goto"), content="Some(Goto(page_id=\"\", url=\"\"))")
  inspect(parse_method("click"), content="Some(Click(element_id=\"\"))")
  inspect(parse_method("unknown_method"), content="None")
}

///|
test "parse method with alias" {
  inspect(parse_method("Browser.createContext"), content="Some(NewContext)")
  inspect(
    parse_method("Page.navigate"),
    content="Some(Goto(page_id=\"\", url=\"\"))",
  )
  inspect(parse_method("Element.click"), content="Some(Click(element_id=\"\"))")
}
