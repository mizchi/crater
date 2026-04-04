///|
/// Cookie Jar tests — attack-first approach
/// Each test targets a specific attack vector from RFC 6265 and known exploits

// ============================================================
// BASIC FUNCTIONALITY
// ============================================================

///|
test "cookie: disabled jar ignores all operations" {
  let jar = CookieJar::new() // enabled=false by default
  jar.store_from_header(
    "session=abc123",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="0")
  inspect(jar.get_cookie_header("https://example.com/", true, true), content="None")
}

///|
test "cookie: enabled jar stores and retrieves" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc123",
    "https://example.com/app",
    true,
  )
  inspect(jar.size(), content="1")
  inspect(
    jar.get_cookie_header("https://example.com/app", true, true),
    content="Some(\"session=abc123\")",
  )
}

///|
test "cookie: multiple cookies in header" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header("a=1", "https://example.com/", true)
  jar.store_from_header("b=2", "https://example.com/", true)
  let header = jar.get_cookie_header("https://example.com/", true, true)
  match header {
    Some(h) => {
      inspect(h.contains("a=1"), content="true")
      inspect(h.contains("b=2"), content="true")
    }
    None => assert_true(false)
  }
}

///|
test "cookie: clear removes all" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header("a=1", "https://example.com/", true)
  jar.store_from_header("b=2", "https://example.com/", true)
  jar.clear()
  inspect(jar.size(), content="0")
}

///|
test "cookie: same name+domain+path replaces" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header("token=old", "https://example.com/", true)
  jar.store_from_header("token=new", "https://example.com/", true)
  inspect(jar.size(), content="1")
  inspect(
    jar.get_cookie_header("https://example.com/", true, true),
    content="Some(\"token=new\")",
  )
}

// ============================================================
// PARSE EDGE CASES
// ============================================================

///|
test "parse: empty header returns None" {
  inspect(parse_set_cookie("", "example.com", "/"), content="None")
}

///|
test "parse: name only (no value)" {
  let c = parse_set_cookie("flag", "example.com", "/")
  match c {
    Some(cookie) => {
      inspect(cookie.name, content="flag")
      inspect(cookie.value, content="")
    }
    None => assert_true(false)
  }
}

///|
test "parse: empty name is invalid" {
  inspect(parse_set_cookie("=value", "example.com", "/"), content="None")
}

///|
test "parse: value with equals sign" {
  let c = parse_set_cookie("data=a=b=c", "example.com", "/")
  match c {
    Some(cookie) => {
      inspect(cookie.name, content="data")
      // Only first = splits name/value
      inspect(cookie.value, content="a=b=c")
    }
    None => assert_true(false)
  }
}

///|
test "parse: all attributes" {
  let c = parse_set_cookie(
    "id=42; Domain=.example.com; Path=/app; Secure; HttpOnly; SameSite=Strict; Max-Age=3600",
    "sub.example.com",
    "/app/page",
  )
  match c {
    Some(cookie) => {
      inspect(cookie.name, content="id")
      inspect(cookie.value, content="42")
      inspect(cookie.domain, content="example.com") // leading dot stripped
      inspect(cookie.path, content="/app")
      inspect(cookie.secure, content="true")
      inspect(cookie.http_only, content="true")
      inspect(cookie.same_site, content="strict")
      inspect(cookie.max_age, content="Some(3600)")
    }
    None => assert_true(false)
  }
}

///|
test "parse: default path from request" {
  let c = parse_set_cookie("a=1", "example.com", "/app/sub/page")
  match c {
    Some(cookie) => inspect(cookie.path, content="/app/sub")
    None => assert_true(false)
  }
}

///|
test "parse: default path for root request" {
  let c = parse_set_cookie("a=1", "example.com", "/")
  match c {
    Some(cookie) => inspect(cookie.path, content="/")
    None => assert_true(false)
  }
}

// ============================================================
// ATTACK: Domain Scoping (Cookie Tossing / Scope Expansion)
// ============================================================

///|
/// Attack: Set cookie for parent domain from subdomain
test "attack: subdomain can set cookie for parent domain" {
  let c = parse_set_cookie(
    "token=evil; Domain=example.com",
    "sub.example.com",
    "/",
  )
  // RFC 6265 allows this — subdomain can set for parent
  match c {
    Some(cookie) => inspect(cookie.domain, content="example.com")
    None => assert_true(false)
  }
}

///|
/// Attack: Set cookie for unrelated domain (must be rejected)
test "attack: cannot set cookie for unrelated domain" {
  let c = parse_set_cookie(
    "stolen=data; Domain=evil.com",
    "example.com",
    "/",
  )
  // example.com cannot set cookie for evil.com
  inspect(c, content="None")
}

///|
/// Attack: Set cookie for TLD (e.g. ".com") — not rejected by our parser
/// but in practice, public suffix lists would block this
test "attack: cookie for TLD domain is accepted (no public suffix list)" {
  let c = parse_set_cookie("x=1; Domain=com", "sub.com", "/")
  // Our parser allows it (no public suffix list) — documented limitation
  match c {
    Some(cookie) => inspect(cookie.domain, content="com")
    None => assert_true(false)
  }
}

///|
/// Attack: Set cookie for sibling subdomain (must be rejected)
test "attack: cannot set cookie for sibling subdomain" {
  let c = parse_set_cookie(
    "x=1; Domain=other.example.com",
    "sub.example.com",
    "/",
  )
  // sub.example.com is not a suffix of other.example.com
  inspect(c, content="None")
}

///|
/// Attack: Domain with trailing dot
test "attack: domain with trailing dot" {
  let c = parse_set_cookie(
    "x=1; Domain=example.com.",
    "example.com",
    "/",
  )
  // "example.com." != "example.com" and "example.com" doesn't end with ".example.com."
  inspect(c, content="None")
}

// ============================================================
// ATTACK: Secure Flag Bypass
// ============================================================

///|
/// Attack: Set Secure cookie from non-secure origin
test "attack: secure cookie from http:// is rejected" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc; Secure",
    "http://example.com/",
    false, // not secure
  )
  inspect(jar.size(), content="0")
}

///|
/// Attack: Read secure cookie over non-secure channel
test "attack: secure cookie not sent over http" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc; Secure",
    "https://example.com/",
    true,
  )
  // Try to read over http
  inspect(
    jar.get_cookie_header("http://example.com/", false, true),
    content="None",
  )
  // Works over https
  inspect(
    jar.get_cookie_header("https://example.com/", true, true),
    content="Some(\"session=abc\")",
  )
}

// ============================================================
// ATTACK: Cookie Prefix Bypass (__Secure- and __Host-)
// ============================================================

///|
/// Attack: __Secure- prefix without Secure flag
test "attack: __Secure- without Secure flag is rejected" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "__Secure-token=abc",
    "https://example.com/",
    true,
  )
  // No Secure attribute → rejected
  inspect(jar.size(), content="0")
}

///|
/// Attack: __Secure- with Secure flag is accepted
test "attack: __Secure- with Secure flag is accepted" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "__Secure-token=abc; Secure",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="1")
}

///|
/// Attack: __Host- without Secure flag
test "attack: __Host- without Secure is rejected" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "__Host-token=abc; Path=/",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="0")
}

///|
/// Attack: __Host- with non-root path
test "attack: __Host- with Path=/app is rejected" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "__Host-token=abc; Secure; Path=/app",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="0")
}

///|
/// Attack: __Host- with correct attributes is accepted
test "attack: __Host- properly configured is accepted" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "__Host-token=abc; Secure; Path=/",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="1")
}

// ============================================================
// ATTACK: HttpOnly Bypass
// ============================================================

///|
/// Attack: httpOnly cookie not accessible via JS API
test "attack: httpOnly cookie hidden from JS" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=secret; HttpOnly",
    "https://example.com/",
    true,
  )
  // is_http_api=false simulates JS document.cookie access
  inspect(
    jar.get_cookie_header("https://example.com/", true, false),
    content="None",
  )
  // is_http_api=true simulates fetch/XHR
  inspect(
    jar.get_cookie_header("https://example.com/", true, true),
    content="Some(\"session=secret\")",
  )
}

// ============================================================
// ATTACK: Path Traversal
// ============================================================

///|
/// Attack: cookie set on /admin not sent to /public
test "attack: path scoping prevents cross-path access" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "admin_token=xyz; Path=/admin",
    "https://example.com/admin/dashboard",
    true,
  )
  // /admin → match
  inspect(
    jar.get_cookie_header("https://example.com/admin/page", true, true),
    content="Some(\"admin_token=xyz\")",
  )
  // /public → no match
  inspect(
    jar.get_cookie_header("https://example.com/public/page", true, true),
    content="None",
  )
  // /admin-evil → no match (not /admin/)
  inspect(
    jar.get_cookie_header("https://example.com/admin-evil", true, true),
    content="None",
  )
}

///|
/// Attack: path with trailing slash matches subpaths
test "cookie: path=/app/ matches /app/sub" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "x=1; Path=/app/",
    "https://example.com/app/",
    true,
  )
  inspect(
    jar.get_cookie_header("https://example.com/app/sub", true, true),
    content="Some(\"x=1\")",
  )
}

// ============================================================
// ATTACK: Cookie Deletion
// ============================================================

///|
/// max-age=0 deletes a cookie
test "cookie: max-age=0 deletes existing cookie" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header("token=abc", "https://example.com/", true)
  inspect(jar.size(), content="1")
  jar.store_from_header(
    "token=; Max-Age=0",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="0")
}

///|
/// max-age negative deletes a cookie
test "cookie: negative max-age deletes cookie" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header("token=abc", "https://example.com/", true)
  jar.store_from_header(
    "token=; Max-Age=-1",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="0")
}

// ============================================================
// ATTACK: Cross-domain cookie reading
// ============================================================

///|
/// Attack: cookie for example.com not sent to evil.com
test "attack: cookie not sent to different domain" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header("session=abc", "https://example.com/", true)
  inspect(
    jar.get_cookie_header("https://evil.com/", true, true),
    content="None",
  )
}

///|
/// Attack: cookie for example.com IS sent to sub.example.com
test "cookie: parent domain cookie sent to subdomain" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc; Domain=example.com",
    "https://example.com/",
    true,
  )
  inspect(
    jar.get_cookie_header("https://sub.example.com/", true, true),
    content="Some(\"session=abc\")",
  )
}

///|
/// Attack: cookie for sub.example.com NOT sent to example.com
test "attack: subdomain cookie not sent to parent domain" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc",
    "https://sub.example.com/",
    true,
  )
  // Cookie domain is sub.example.com (default), should NOT match example.com
  inspect(
    jar.get_cookie_header("https://example.com/", true, true),
    content="None",
  )
}

// ============================================================
// ATTACK: Cookie Injection via header values
// ============================================================

///|
/// Attack: CRLF in cookie value
test "attack: CRLF in cookie value stored as-is" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "x=value\r\nInjected: header",
    "https://example.com/",
    true,
  )
  // Parser stores the raw value — transport layer is responsible for rejecting
  inspect(jar.size(), content="1")
}

///|
/// Attack: semicolon in cookie value
test "parse: semicolon splits attributes, not value" {
  let c = parse_set_cookie("data=hello; Path=/", "example.com", "/")
  match c {
    Some(cookie) => {
      // "hello" is the value, "; Path=/" is parsed as attribute
      inspect(cookie.name, content="data")
      inspect(cookie.value, content="hello")
      inspect(cookie.path, content="/")
    }
    None => assert_true(false)
  }
}

// ============================================================
// BOUNDARY CONDITIONS
// ============================================================

///|
test "cookie_extract_domain: standard URL" {
  inspect(cookie_extract_domain("https://example.com/path"), content="example.com")
}

///|
test "cookie_extract_domain: URL with port" {
  inspect(cookie_extract_domain("https://example.com:8080/path"), content="example.com")
}

///|
test "cookie_extract_domain: no path" {
  inspect(cookie_extract_domain("https://example.com"), content="example.com")
}

///|
test "cookie_extract_path: standard URL" {
  inspect(cookie_extract_path("https://example.com/app/page"), content="/app/page")
}

///|
test "cookie_extract_path: root URL" {
  inspect(cookie_extract_path("https://example.com/"), content="/")
}

///|
test "cookie_extract_path: no path" {
  inspect(cookie_extract_path("https://example.com"), content="/")
}

///|
test "cookie_domain_matches: exact match" {
  inspect(cookie_domain_matches("example.com", "example.com"), content="true")
}

///|
test "cookie_domain_matches: subdomain matches parent" {
  inspect(
    cookie_domain_matches("sub.example.com", "example.com"),
    content="true",
  )
}

///|
test "cookie_domain_matches: parent does not match subdomain" {
  inspect(
    cookie_domain_matches("example.com", "sub.example.com"),
    content="false",
  )
}

///|
test "cookie_domain_matches: unrelated domains" {
  inspect(cookie_domain_matches("evil.com", "example.com"), content="false")
}

///|
test "cookie_path_matches: exact" {
  inspect(cookie_path_matches("/app", "/app"), content="true")
}

///|
test "cookie_path_matches: subpath" {
  inspect(cookie_path_matches("/app/sub", "/app"), content="true")
}

///|
test "cookie_path_matches: prefix but no slash boundary" {
  // /application should NOT match /app (no / after /app)
  inspect(cookie_path_matches("/application", "/app"), content="false")
}

///|
test "cookie_path_matches: root matches everything" {
  inspect(cookie_path_matches("/anything/here", "/"), content="true")
}

///|
test "cookie_default_path: from /a/b/c" {
  inspect(cookie_default_path("/a/b/c"), content="/a/b")
}

///|
test "cookie_default_path: from /" {
  inspect(cookie_default_path("/"), content="/")
}

///|
test "cookie_default_path: empty path" {
  inspect(cookie_default_path(""), content="/")
}
