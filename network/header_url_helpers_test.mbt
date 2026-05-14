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
test "network normalizes and validates header entries" {
  let raw_headers = Json::array([
    synthetic_network_header_string_entry("x-test", "ok"),
  ])
  match
    synthetic_network_normalize_header_entries(
      Some(raw_headers),
      "requestHeaders",
    ) {
    Ok(headers) => {
      inspect(headers.length(), content="1")
      match synthetic_network_header_entry_name(headers[0]) {
        Some(name) => inspect(name, content="x-test")
        None => fail("expected normalized header name")
      }
    }
    Err(message) => fail("unexpected header normalization error: " + message)
  }

  assert_true(synthetic_network_is_valid_header_name_token("content-type"))
  assert_false(synthetic_network_is_valid_header_name_token("bad name"))
  assert_false(synthetic_network_is_valid_header_string_value(" bad"))
  match
    synthetic_network_normalize_header_entries(
      Some(
        Json::array([
          Json::object({
            "name": Json::string("bad name"),
            "value": Json::object({
              "type": Json::string("string"),
              "value": Json::string("ok"),
            }),
          }),
        ]),
      ),
      "requestHeaders",
    ) {
    Ok(_) => fail("expected invalid header entry")
    Err(message) => inspect(message, content="requestHeaders entry is invalid")
  }
  match
    synthetic_network_normalize_header_entries(
      Some(Json::string("bad")),
      "requestHeaders",
    ) {
    Ok(_) => fail("expected invalid header list")
    Err(message) => inspect(message, content="requestHeaders must be an array")
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
  match
    synthetic_network_normalize_continue_url(
      Json::string("https://example.test/path"),
    ) {
    Ok(url) => inspect(url, content="https://example.test/path")
    Err(message) => fail("unexpected continue url error: " + message)
  }
  match synthetic_network_normalize_continue_url(Json::number(1)) {
    Ok(_) => fail("expected invalid continue url type")
    Err(message) => inspect(message, content="url must be a string")
  }
  match
    synthetic_network_normalize_continue_url(Json::string("https:///path")) {
    Ok(_) => fail("expected invalid continue url")
    Err(message) => inspect(message, content="url is invalid")
  }

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

///|
test "network normalizes synthetic response overrides" {
  match synthetic_network_normalize_response_overrides(None) {
    Ok(overrides) => {
      inspect(overrides.status, content="200")
      inspect(overrides.status_text, content="OK")
      inspect(overrides.headers.length(), content="0")
    }
    Err(message) => fail("unexpected default overrides error: " + message)
  }
  match
    synthetic_network_normalize_response_overrides(
      Some(
        Json::object({
          "fromCache": Json::boolean(true),
          "status": Json::number(407),
          "mimeType": Json::string("text/html"),
          "protocol": Json::string("http/2"),
          "headers": Json::array([
            synthetic_network_header_string_entry("content-type", "text/html"),
          ]),
        }),
      ),
    ) {
    Ok(overrides) => {
      inspect(overrides.from_cache, content="true")
      inspect(overrides.status, content="407")
      inspect(overrides.status_text, content="Proxy Authentication Required")
      inspect(overrides.mime_type, content="text/html")
      inspect(overrides.protocol, content="http/2")
      inspect(overrides.headers.length(), content="1")
      match overrides.auth_challenges {
        Some(auth_challenges) =>
          inspect(auth_challenges.stringify(), content="[]")
        None => fail("expected default auth challenges")
      }
    }
    Err(message) => fail("unexpected response overrides error: " + message)
  }
  match
    synthetic_network_normalize_response_overrides(
      Some(Json::object({ "status": Json::number(-1) })),
    ) {
    Ok(_) => fail("expected invalid status")
    Err(message) =>
      inspect(
        message,
        content="responseOverrides.status must be a non-negative integer",
      )
  }
}
