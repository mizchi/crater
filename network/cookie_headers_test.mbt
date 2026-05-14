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
