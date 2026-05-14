///|
test "serialization options canonicalize snake case aliases" {
  let params = Json::object({
    "serialization_options": Json::object({
      "max_dom_depth": Json::number(2.0),
      "max_object_depth": Json::number(3.0),
      "include_shadow_tree": Json::string("all"),
      "ownership": Json::string("root"),
    }),
  })
  let json = get_serialization_options_json(Some(params))
  assert_true(json.contains("\"maxDomDepth\":2"))
  assert_true(json.contains("\"maxObjectDepth\":3"))
  assert_true(json.contains("\"includeShadowTree\":\"all\""))
  assert_true(json.contains("\"ownership\":\"root\""))
  assert_false(json.contains("max_dom_depth"))
}

///|
test "locate nodes serialization options adjust defaults" {
  let params = Json::object({
    "serializationOptions": Json::object({ "maxDomDepth": Json::number(1.0) }),
  })
  let json = get_locate_nodes_serialization_options_json(Some(params))
  assert_true(json.contains("\"maxDomDepth\":3"))
  assert_true(json.contains("\"includeShadowTree\":\"all\""))
}

///|
test "runtime context id resolves sandbox realm" {
  let params = Json::object({
    "target": Json::object({ "sandbox": Json::string("isolated") }),
  })
  inspect(
    resolve_runtime_context_id(Some(params), "context-1", "realm-1", false),
    content="realm-1",
  )
  inspect(
    resolve_runtime_context_id(None, "context-1", "realm-1", true),
    content="realm-1",
  )
  inspect(
    resolve_runtime_context_id(None, "context-1", "realm-1", false),
    content="context-1",
  )
}

///|
test "decimal and ascii helpers" {
  match parse_decimal_string("123") {
    Some(value) => inspect(value, content="123")
    None => fail("expected decimal value")
  }
  match parse_decimal_string("12a") {
    None => ()
    Some(_) => fail("expected invalid decimal")
  }
  assert_true(is_ascii_alpha('a'))
  assert_true(is_ascii_alpha('Z'))
  assert_false(is_ascii_alpha('1'))
  assert_true(is_ascii_alnum('7'))
  assert_true(is_ascii_case_insensitive_equal("Content-Type", "content-type"))
  assert_false(is_ascii_case_insensitive_equal("Content-Type", "content-type2"))
}

///|
test "safe json number validation keeps non-numeric and out-of-range values out" {
  debug_inspect(
    json_as_safe_number(Json::number(1.5), 0.0, 2.0),
    content="Some(1.5)",
  )
  debug_inspect(
    json_as_safe_number(Json::number(-1.0), 0.0, 2.0),
    content="None",
  )
  debug_inspect(
    json_as_safe_number(Json::string("1"), 0.0, 2.0),
    content="None",
  )
}

///|
test "safe json int validation requires integer numbers inside range" {
  debug_inspect(
    json_as_safe_int(Json::number(2.0), 0.0, 3.0),
    content="Some(2)",
  )
  debug_inspect(json_as_safe_int(Json::number(2.5), 0.0, 3.0), content="None")
  debug_inspect(json_as_safe_int(Json::number(4.0), 0.0, 3.0), content="None")
}

///|
test "evaluate result string helper extracts remote string value" {
  let payload =
    #|{"result":{"type":"success","value":"<main></main>"}}
  inspect(
    extract_string_value_from_evaluate_result(payload),
    content="<main></main>",
  )
}

///|
test "evaluate result string helper defaults malformed or non string values" {
  inspect(extract_string_value_from_evaluate_result("{"), content="")
  let non_string_payload =
    #|{"result":{"type":"success","value":42}}
  inspect(
    extract_string_value_from_evaluate_result(non_string_payload),
    content="",
  )
}
