///|
test "network formats Set-Cookie header attributes" {
  let header = synthetic_network_format_set_cookie_header({
    "name": Json::string("sid"),
    "value": Json::string("abc"),
    "path": Json::string("/app"),
    "domain": Json::string("example.test"),
    "expiry": Json::string("Wed, 21 Oct 2030 07:28:00 GMT"),
    "maxAge": Json::number(60),
    "httpOnly": Json::boolean(true),
    "secure": Json::boolean(true),
    "sameSite": Json::string("lax"),
  })
  inspect(
    header,
    content="sid=abc;Path=/app;Domain=example.test;Expires=Wed, 21 Oct 2030 07:28:00 GMT;Max-Age=60;HttpOnly;Secure;SameSite=Lax",
  )
}

///|
test "network formats unknown SameSite casing without changing input" {
  inspect(
    synthetic_network_format_set_cookie_header({
      "name": Json::string("sid"),
      "value": Json::string("abc"),
      "sameSite": Json::string("Custom"),
    }),
    content="sid=abc;SameSite=Custom",
  )
}

///|
test "network parses Set-Cookie header value" {
  let cookie = match
    synthetic_network_parse_set_cookie_header_value(
      "sid=abc; Domain=.Example.test; Path=/app; SameSite=Lax; Max-Age=60; HttpOnly; Secure",
      "https://origin.test/page", 1000,
    ) {
    Some(cookie) => cookie
    None => fail("expected parsed cookie")
  }
  inspect(cookie.name, content="sid")
  inspect(cookie.value_text, content="abc")
  inspect(cookie.domain, content="example.test")
  inspect(cookie.domain_explicit, content="true")
  inspect(cookie.path, content="/app")
  inspect(cookie.same_site, content="lax")
  inspect(cookie.http_only, content="true")
  inspect(cookie.secure, content="true")
  match cookie.expiry {
    Some(expiry) => inspect(expiry, content="1060")
    None => fail("expected max-age expiry")
  }
}

///|
test "network extracts Set-Cookie entries from header array" {
  let headers = [
    synthetic_network_header_string_entry("Content-Type", "text/plain"),
    synthetic_network_header_string_entry(
      "Set-Cookie", "token=one; Path=/; SameSite=None",
    ),
  ]
  let cookies = synthetic_network_extract_set_cookie_entries(
    headers, "data:text/html,#domain=alt&subdomain=app", 2000,
  )
  inspect(cookies.length(), content="1")
  inspect(cookies[0].name, content="token")
  inspect(cookies[0].domain, content="app.alt.localhost")
  inspect(cookies[0].same_site, content="none")
}

///|
test "network parses document cookie assignment with webdriver defaults" {
  let cookie = match
    synthetic_network_parse_document_cookie_assignment(
      "token=xyz; Domain=.Example.test; Path=/app; SameSite=None; Max-Age=60; HttpOnly; Secure",
      "https://origin.test/page", "/default", 1000,
    ) {
    Some(cookie) => cookie
    None => fail("expected parsed document cookie")
  }
  inspect(cookie.name, content="token")
  inspect(cookie.value_text, content="xyz")
  inspect(cookie.domain, content="example.test")
  inspect(cookie.domain_explicit, content="true")
  inspect(cookie.path, content="/app")
  inspect(cookie.same_site, content="none")
  inspect(cookie.http_only, content="true")
  inspect(cookie.secure, content="true")
  match cookie.expiry {
    Some(expiry) => inspect(expiry, content="1060")
    None => fail("expected max-age expiry")
  }
}

///|
test "network parses document cookie assignment default domain path and samesite" {
  let cookie = match
    synthetic_network_parse_document_cookie_assignment(
      "token=xyz", "data:text/html,#domain=alt&subdomain=app", "/webdriver/tests/support",
      2000,
    ) {
    Some(cookie) => cookie
    None => fail("expected parsed document cookie")
  }
  inspect(cookie.domain, content="app.alt.localhost")
  inspect(cookie.domain_explicit, content="false")
  inspect(cookie.path, content="/webdriver/tests/support")
  inspect(cookie.same_site, content="default")
  match cookie.expiry {
    Some(_) => fail("expected session cookie")
    None => inspect("session", content="session")
  }
}

///|
test "network rejects document cookie assignment without name separator" {
  match
    synthetic_network_parse_document_cookie_assignment(
      "token", "https://origin.test/page", "/", 0,
    ) {
    Some(_) => fail("expected invalid document cookie assignment")
    None => inspect("invalid", content="invalid")
  }
}

///|
test "network normalizes set cookie override entry" {
  let normalized = match
    synthetic_network_normalize_set_cookie_override_entry(
      {
        "domain": Json::string(".Example.test"),
        "path": Json::string("/app"),
        "sameSite": Json::string("Lax"),
        "httpOnly": Json::boolean(true),
        "secure": Json::boolean(true),
        "maxAge": Json::number(60),
      },
      "token",
      "xyz",
      "https://origin.test/page",
      1000,
    ) {
    Ok(normalized) => normalized
    Err(message) => fail("unexpected normalize error: " + message)
  }
  inspect(
    normalized.set_cookie_header_value,
    content="token=xyz;Path=/app;Domain=.Example.test;Max-Age=60;HttpOnly;Secure;SameSite=Lax",
  )
  inspect(normalized.cookie.domain, content="example.test")
  inspect(normalized.cookie.domain_explicit, content="true")
  inspect(normalized.cookie.path, content="/app")
  inspect(normalized.cookie.same_site, content="lax")
  match normalized.cookie.expiry {
    Some(expiry) => inspect(expiry, content="1060")
    None => fail("expected max-age expiry")
  }
}

///|
test "network rejects invalid set cookie override sameSite" {
  match
    synthetic_network_normalize_set_cookie_override_entry(
      { "sameSite": Json::string("wide") },
      "token",
      "xyz",
      "https://origin.test/page",
      0,
    ) {
    Ok(_) => fail("expected invalid sameSite")
    Err(message) => inspect(message, content="cookie sameSite is invalid")
  }
}

///|
test "network rejects unsafe set cookie override maxAge" {
  match
    synthetic_network_normalize_set_cookie_override_entry(
      { "maxAge": Json::number(1.5) },
      "token",
      "xyz",
      "https://origin.test/page",
      0,
    ) {
    Ok(_) => fail("expected invalid maxAge")
    Err(message) => inspect(message, content="cookie maxAge must be an integer")
  }
}

///|
test "network normalizes request cookie entries" {
  let normalized = match
    synthetic_network_normalize_request_cookie_entries(
      Some(
        Json::array([
          Json::object({
            "name": Json::string("token"),
            "value": Json::object({
              "type": Json::string("string"),
              "value": Json::string("xyz"),
            }),
          }),
        ]),
      ),
    ) {
    Ok(normalized) => normalized
    Err(message) => fail("unexpected request cookie error: " + message)
  }
  inspect(normalized.enabled, content="true")
  inspect(normalized.cookies.length(), content="1")
  inspect(
    normalized.cookies[0].stringify(),
    content="{\"name\":\"token\",\"value\":{\"type\":\"string\",\"value\":\"xyz\"}}",
  )
}

///|
test "network treats missing request cookie entries as disabled" {
  let normalized = match
    synthetic_network_normalize_request_cookie_entries(None) {
    Ok(normalized) => normalized
    Err(message) => fail("unexpected request cookie error: " + message)
  }
  inspect(normalized.enabled, content="false")
  inspect(normalized.cookies.length(), content="0")
}

///|
test "network rejects invalid request cookie value type" {
  match
    synthetic_network_normalize_request_cookie_entries(
      Some(
        Json::array([
          Json::object({
            "name": Json::string("token"),
            "value": Json::object({
              "type": Json::string("base64"),
              "value": Json::string("eHl6"),
            }),
          }),
        ]),
      ),
    ) {
    Ok(_) => fail("expected invalid request cookie value type")
    Err(message) =>
      inspect(message, content="requestCookies.value.type is invalid")
  }
}
