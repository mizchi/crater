///|
test "network header helpers build read and merge string entries" {
  let raw_headers = {
    "Accept": Json::string("text/html"),
    "X-Enabled": Json::boolean(true),
  }
  let headers = synthetic_network_header_entries_from_object(raw_headers)
  inspect(headers.length(), content="2")

  let first = synthetic_network_header_string_entry("Accept", "text/plain")
  match synthetic_network_header_entry_name(first) {
    Some(name) => inspect(name, content="Accept")
    None => fail("expected header name")
  }
  match synthetic_network_header_entry_string_value(first) {
    Some(value) => inspect(value, content="text/plain")
    None => fail("expected header value")
  }

  let merged = synthetic_network_merge_header_entries([
    first,
    synthetic_network_header_string_entry("accept", "application/json"),
  ])
  inspect(merged.length(), content="1")
  match synthetic_network_request_header_string_value(merged, "ACCEPT") {
    Some(value) => inspect(value, content="text/plain, application/json")
    None => fail("expected merged header value")
  }
}

///|
test "network query helpers decode values and parse ints" {
  let url = "https://example.test/path?a=1&a=two+words&empty&bad=x"
  match synthetic_network_first_query_value(url, "a") {
    Some(value) => inspect(value, content="1")
    None => fail("expected first query value")
  }
  let values = synthetic_network_query_values(url, "a")
  inspect(values.length(), content="2")
  inspect(values[0], content="1")
  inspect(values[1], content="two words")
  match synthetic_network_first_query_value(url, "empty") {
    Some(value) => inspect(value, content="")
    None => fail("expected empty query value")
  }
  inspect(synthetic_network_int_query_param(url, "a", 9), content="1")
  inspect(synthetic_network_int_query_param(url, "bad", 9), content="9")
}

///|
test "network URL and response metadata helpers" {
  assert_true(synthetic_network_is_valid_continue_url("data:text/plain,ok"))
  assert_true(
    synthetic_network_is_valid_continue_url("https://example.test/path"),
  )
  assert_false(synthetic_network_is_valid_continue_url("https:///path"))

  inspect(
    synthetic_network_cache_key("GET", "https://example.test/"),
    content="GET https://example.test/",
  )
  inspect(
    synthetic_network_request_path("https://example.test/docs/index.html?q=1"),
    content="/docs/index.html",
  )
  inspect(
    synthetic_network_infer_mime_type("https://example.test/app.js", "/app.js"),
    content="text/javascript",
  )
  inspect(synthetic_network_status_text_for_code(404), content="Not Found")
}
