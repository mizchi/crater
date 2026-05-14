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
