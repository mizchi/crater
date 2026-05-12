///|
fn synthetic_fetch_is_headers_echo_url(url : String) -> Bool {
  match canonicalize_network_http_url(url) {
    Some(parts) =>
      parts.port == 8000 &&
      (parts.host == "localhost" || parts.host == "alt.localhost") &&
      parts.path.has_suffix(
        "/webdriver/tests/support/http_handlers/headers_echo.py",
      )
    None => false
  }
}

///|
fn synthetic_fetch_synthesize_response_value(
  url : String,
  headers_echo_payload : String?,
) -> Json {
  match headers_echo_payload {
    Some(payload) =>
      make_object({
        "type": Json::string("string"),
        "value": Json::string(payload),
      })
    None => synthetic_navigation_synthesize_response_value(url)
  }
}
