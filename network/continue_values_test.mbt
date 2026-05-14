///|
test "network normalizes BytesValue variants" {
  match
    synthetic_network_normalize_bytes_value(
      Json::object({
        "type": Json::string("base64"),
        "value": Json::string("aGVsbG8="),
      }),
      "body",
    ) {
    Ok(value) =>
      inspect(
        value.stringify(),
        content="{\"type\":\"base64\",\"value\":\"aGVsbG8=\"}",
      )
    Err(message) => fail("unexpected bytes value error: " + message)
  }
  match
    synthetic_network_text_from_bytes_value(
      Json::object({
        "type": Json::string("base64"),
        "value": Json::string("aGVsbG8="),
      }),
      "body",
    ) {
    Ok(value) => inspect(value, content="hello")
    Err(message) => fail("unexpected decoded text error: " + message)
  }
  match
    synthetic_network_string_from_bytes_value(
      Json::object({
        "type": Json::string("base64"),
        "value": Json::string("aGVsbG8="),
      }),
      "cookie.value",
    ) {
    Ok(_) => fail("expected string-only BytesValue error")
    Err(message) => inspect(message, content="cookie.value.type is invalid")
  }
  match
    synthetic_network_request_body_size(
      Some(
        Json::object({
          "type": Json::string("string"),
          "value": Json::string("hello"),
        }),
      ),
      "requestValue",
    ) {
    Ok(size) => inspect(size, content="5")
    Err(message) => fail("unexpected body size error: " + message)
  }
  match
    synthetic_network_request_body_size(
      Some(
        Json::object({
          "type": Json::string("base64"),
          "value": Json::string("aGVsbG8="),
        }),
      ),
      "requestValue",
    ) {
    Ok(size) => inspect(size, content="5")
    Err(message) => fail("unexpected base64 body size error: " + message)
  }
  match
    synthetic_network_request_body_size(
      Some(
        Json::object({
          "type": Json::string("bytes"),
          "value": Json::string("hello"),
        }),
      ),
      "requestValue",
    ) {
    Ok(_) => fail("expected invalid request body type")
    Err(message) => inspect(message, content="requestValue.type is invalid")
  }
}

///|
test "network normalizes continue credentials and matches expected query credentials" {
  let credentials = match
    synthetic_network_normalize_continue_credentials(
      Json::object({
        "type": Json::string("password"),
        "username": Json::string("user"),
        "password": Json::string("secret"),
      }),
    ) {
    Ok(credentials) => credentials
    Err(message) => fail("unexpected credentials error: " + message)
  }
  assert_true(
    synthetic_network_credentials_match_expected(
      "https://example.test/auth?username=user&password=secret",
      Some(credentials),
    ),
  )
  assert_false(
    synthetic_network_credentials_match_expected(
      "https://example.test/auth?username=user&password=other",
      Some(credentials),
    ),
  )
  match
    synthetic_network_normalize_continue_credentials(
      Json::object({ "type": Json::string("token") }),
    ) {
    Ok(_) => fail("expected invalid credentials type")
    Err(message) => inspect(message, content="credentials.type is invalid")
  }
}
