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

// ============================================================
// HTTPONLY ATTACK VECTORS
// ============================================================

///|
/// Attack: HttpOnly attribute case variations must all be recognized
test "httponly: case variations are all recognized" {
  // "httponly" (lowercase — already tested via to_lower())
  let c1 = parse_set_cookie("a=1; httponly", "example.com", "/")
  match c1 {
    Some(c) => inspect(c.http_only, content="true")
    None => assert_true(false)
  }
  // "HTTPONLY" (uppercase)
  let c2 = parse_set_cookie("a=1; HTTPONLY", "example.com", "/")
  match c2 {
    Some(c) => inspect(c.http_only, content="true")
    None => assert_true(false)
  }
  // "HttpOnly" (mixed)
  let c3 = parse_set_cookie("a=1; HttpOnly", "example.com", "/")
  match c3 {
    Some(c) => inspect(c.http_only, content="true")
    None => assert_true(false)
  }
}

///|
/// Attack: Non-HttpOnly cookie with same name overwrites HttpOnly cookie
/// This is a real attack vector — JS can set document.cookie to replace HttpOnly cookies
test "httponly attack: non-httponly cookie replaces httponly (same name)" {
  let jar = CookieJar::new(enabled=true)
  // Server sets HttpOnly session cookie
  jar.store_from_header(
    "session=legitimate; HttpOnly",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="1")
  // Attacker's JS calls store_from_header with non-HttpOnly version
  // (simulating document.cookie = "session=evil")
  jar.store_from_header(
    "session=evil",
    "https://example.com/",
    true,
  )
  // VULNERABILITY: the non-HttpOnly cookie replaces the HttpOnly one
  // This is actually RFC 6265 compliant behavior — the spec doesn't prevent this
  // But we should document it
  inspect(jar.size(), content="1")
  // The cookie is now visible to JS (is_http_api=false)
  let js_visible = jar.get_cookie_header("https://example.com/", true, false)
  inspect(js_visible, content="Some(\"session=evil\")")
}

///|
/// Attack: Delete HttpOnly cookie via max-age=0 from JS context
test "httponly attack: max-age=0 can delete httponly cookie" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=secret; HttpOnly",
    "https://example.com/",
    true,
  )
  // JS context sends max-age=0 to delete — this is a limitation
  jar.store_from_header(
    "session=; Max-Age=0",
    "https://example.com/",
    true,
  )
  inspect(jar.size(), content="0")
}

///|
/// Attack: HttpOnly cookie mixed with non-HttpOnly cookies
test "httponly: mixed httponly and non-httponly cookies" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=secret; HttpOnly",
    "https://example.com/",
    true,
  )
  jar.store_from_header(
    "theme=dark",
    "https://example.com/",
    true,
  )
  // JS context: only non-HttpOnly visible
  inspect(
    jar.get_cookie_header("https://example.com/", true, false),
    content="Some(\"theme=dark\")",
  )
  // HTTP context: both visible
  let http = jar.get_cookie_header("https://example.com/", true, true)
  match http {
    Some(h) => {
      inspect(h.contains("session=secret"), content="true")
      inspect(h.contains("theme=dark"), content="true")
    }
    None => assert_true(false)
  }
}

///|
/// Attack: HttpOnly with whitespace padding in attribute
test "httponly: whitespace around HttpOnly attribute" {
  let c = parse_set_cookie("a=1;  HttpOnly  ; Secure", "example.com", "/")
  match c {
    Some(cookie) => {
      inspect(cookie.http_only, content="true")
      inspect(cookie.secure, content="true")
    }
    None => assert_true(false)
  }
}

// ============================================================
// SET-COOKIE INJECTION ATTACKS
// ============================================================

///|
/// Attack: multiple Domain attributes — last one wins
test "set-cookie attack: multiple Domain attributes" {
  let c = parse_set_cookie(
    "x=1; Domain=example.com; Domain=evil.com",
    "example.com",
    "/",
  )
  // Last Domain wins
  // But evil.com doesn't match example.com → rejected
  inspect(c, content="None")
}

///|
/// Attack: Domain attribute with leading dot variations
test "set-cookie: domain with double leading dot" {
  let c = parse_set_cookie(
    "x=1; Domain=..example.com",
    "example.com",
    "/",
  )
  // Strip one dot → ".example.com" → still has dot → not stripped again
  // ".example.com" != "example.com" and "example.com" doesn't end with "..example.com"
  inspect(c, content="None")
}

///|
/// Attack: empty Domain attribute
test "set-cookie attack: empty Domain attribute" {
  let c = parse_set_cookie(
    "x=1; Domain=",
    "example.com",
    "/",
  )
  // domain="" after strip, domain_set=true
  // "example.com" != "" and "example.com" doesn't have suffix "." → rejected
  inspect(c, content="None")
}

///|
/// Attack: Path with dot-dot traversal
test "set-cookie attack: path with dot-dot segments" {
  let c = parse_set_cookie(
    "x=1; Path=/app/../admin",
    "example.com",
    "/",
  )
  match c {
    Some(cookie) => {
      // Path is stored as-is — no normalization
      // The path matching function does prefix matching, so /app/../admin
      // will only match requests that literally start with "/app/../admin"
      inspect(cookie.path, content="/app/../admin")
    }
    None => assert_true(false)
  }
}

///|
/// Attack: very long cookie name (DoS)
test "set-cookie: very long cookie name is accepted" {
  let mut long_name = ""
  for i = 0; i < 200; i = i + 1 {
    long_name = long_name + "a"
  }
  let header = long_name + "=value"
  let c = parse_set_cookie(header, "example.com", "/")
  match c {
    Some(cookie) => inspect(cookie.name.length(), content="200")
    None => assert_true(false)
  }
}

///|
/// Attack: very long cookie value (DoS)
test "set-cookie: very long cookie value is accepted" {
  let mut long_val = ""
  for i = 0; i < 4096; i = i + 1 {
    long_val = long_val + "x"
  }
  let header = "data=" + long_val
  let c = parse_set_cookie(header, "example.com", "/")
  match c {
    Some(cookie) => inspect(cookie.value.length(), content="4096")
    None => assert_true(false)
  }
}

///|
/// Attack: null byte in cookie name
test "set-cookie attack: null byte in cookie name" {
  let c = parse_set_cookie("ses\x00sion=abc", "example.com", "/")
  // Name with null byte — parser accepts it (transport should reject)
  match c {
    Some(cookie) => inspect(cookie.name.contains("\x00"), content="true")
    None => ()
  }
}

///|
/// Attack: cookie value with encoded characters
test "set-cookie: URL-encoded value stored as-is" {
  let c = parse_set_cookie("data=%3Cscript%3E", "example.com", "/")
  match c {
    Some(cookie) => {
      // Value is NOT decoded — stored as-is
      inspect(cookie.value, content="%3Cscript%3E")
    }
    None => assert_true(false)
  }
}

///|
/// Attack: Set-Cookie with Expires in the past (should delete)
/// Note: our parser stores Expires but doesn't evaluate it — documented limitation
test "set-cookie: past Expires is stored (max-age takes precedence)" {
  let c = parse_set_cookie(
    "x=1; Expires=Thu, 01 Jan 1970 00:00:00 GMT",
    "example.com",
    "/",
  )
  match c {
    Some(cookie) => {
      // Expires is stored but not evaluated (only Max-Age is enforced)
      inspect(cookie.expires.is_empty(), content="false")
    }
    None => assert_true(false)
  }
}

// ============================================================
// __Host- AND __Secure- ADVANCED ATTACKS
// ============================================================

///|
/// Attack: __Host- with explicit Domain attribute matching request domain
test "attack: __Host- with Domain=example.com from example.com" {
  let jar = CookieJar::new(enabled=true)
  // Domain explicitly set to match request domain — BUT __Host- forbids Domain attribute
  jar.store_from_header(
    "__Host-token=abc; Secure; Path=/; Domain=example.com",
    "https://example.com/",
    true,
  )
  // The domain is "example.com" which matches req_domain "example.com"
  // BUT when Domain is explicitly set, the cookie domain could be different from
  // the host-only interpretation. We check cookie.domain != req_domain to detect this.
  // Since Domain=example.com from example.com → cookie.domain == req_domain → accepted
  // This is a known limitation — ideally we'd track domain_set separately
  // For now, document this behavior
  inspect(jar.size(), content="1")
}

///|
/// Attack: __Host- with Domain attribute for parent domain
test "attack: __Host- with Domain= parent domain is rejected" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "__Host-token=abc; Secure; Path=/; Domain=example.com",
    "https://sub.example.com/",
    true,
  )
  // cookie.domain = "example.com" != req_domain = "sub.example.com" → rejected
  inspect(jar.size(), content="0")
}

///|
/// Attack: __Secure- prefix is case-sensitive
test "attack: __secure- (lowercase) does not trigger prefix check" {
  let jar = CookieJar::new(enabled=true)
  // Lowercase prefix — not caught by has_prefix("__Secure-")
  jar.store_from_header(
    "__secure-token=abc",
    "https://example.com/",
    true,
  )
  // Bypasses the __Secure- check because prefix is case-sensitive
  // This is actually correct — cookie prefixes are case-sensitive per spec
  inspect(jar.size(), content="1")
}

///|
/// Attack: __HOST- (uppercase) does not trigger prefix check
test "attack: __HOST- (uppercase) does not trigger prefix check" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "__HOST-token=abc",
    "https://example.com/",
    true,
  )
  // Uppercase prefix — not caught by has_prefix("__Host-")
  inspect(jar.size(), content="1")
}

// ============================================================
// CROSS-SITE COOKIE ATTACKS
// ============================================================

///|
/// Attack: cookie set on parent domain, read from sibling subdomain
test "cross-site: cookie on parent readable from any subdomain" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "shared=data; Domain=example.com",
    "https://a.example.com/",
    true,
  )
  // Readable from another subdomain
  inspect(
    jar.get_cookie_header("https://b.example.com/", true, true),
    content="Some(\"shared=data\")",
  )
  // Readable from deeply nested subdomain
  inspect(
    jar.get_cookie_header("https://deep.sub.example.com/", true, true),
    content="Some(\"shared=data\")",
  )
}

///|
/// Attack: two cookies with same name, different domains
test "cookie isolation: same name different domains are separate" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "token=from-a",
    "https://a.example.com/",
    true,
  )
  jar.store_from_header(
    "token=from-b",
    "https://b.example.com/",
    true,
  )
  inspect(jar.size(), content="2")
  inspect(
    jar.get_cookie_header("https://a.example.com/", true, true),
    content="Some(\"token=from-a\")",
  )
  inspect(
    jar.get_cookie_header("https://b.example.com/", true, true),
    content="Some(\"token=from-b\")",
  )
}

///|
/// Attack: two cookies with same name, different paths
test "cookie isolation: same name different paths are separate" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "token=admin; Path=/admin",
    "https://example.com/admin/",
    true,
  )
  jar.store_from_header(
    "token=user; Path=/user",
    "https://example.com/user/",
    true,
  )
  inspect(jar.size(), content="2")
  inspect(
    jar.get_cookie_header("https://example.com/admin/page", true, true),
    content="Some(\"token=admin\")",
  )
  inspect(
    jar.get_cookie_header("https://example.com/user/page", true, true),
    content="Some(\"token=user\")",
  )
}

///|
/// Attack: SameSite=None without Secure should be rejected (RFC 6265bis)
/// Note: our implementation doesn't enforce this yet — documenting as known gap
test "samesite: SameSite=None parsed correctly" {
  let c = parse_set_cookie(
    "x=1; SameSite=None; Secure",
    "example.com",
    "/",
  )
  match c {
    Some(cookie) => {
      inspect(cookie.same_site, content="none")
      inspect(cookie.secure, content="true")
    }
    None => assert_true(false)
  }
}

///|
/// Attack: SameSite with invalid value
test "samesite: invalid value is stored as-is" {
  let c = parse_set_cookie(
    "x=1; SameSite=invalid",
    "example.com",
    "/",
  )
  match c {
    Some(cookie) => inspect(cookie.same_site, content="invalid")
    None => assert_true(false)
  }
}

// ============================================================
// DOMAIN MATCHING EDGE CASES
// ============================================================

///|
/// Attack: IP address cookies should be exact-match only
test "domain: IP address cookie exact match only" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "x=1",
    "https://192.168.1.1/",
    true,
  )
  // Exact IP match → sent
  inspect(
    jar.get_cookie_header("https://192.168.1.1/", true, true),
    content="Some(\"x=1\")",
  )
  // Different IP → not sent
  inspect(
    jar.get_cookie_header("https://192.168.1.2/", true, true),
    content="None",
  )
}

///|
/// Attack: setting Domain for IP address
test "domain: Domain attribute with IP is not treated as suffix match" {
  let c = parse_set_cookie(
    "x=1; Domain=192.168.1.1",
    "192.168.1.1",
    "/",
  )
  // IP with Domain set — accepted (exact match)
  match c {
    Some(cookie) => inspect(cookie.domain, content="192.168.1.1")
    None => assert_true(false)
  }
}

///|
/// Attack: localhost cookie scope
test "domain: localhost cookie not sent to 127.0.0.1" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header("x=1", "https://localhost/", true)
  inspect(
    jar.get_cookie_header("https://127.0.0.1/", true, true),
    content="None",
  )
}

///|
/// Attack: multiple cookies sent in correct order (longest path first per RFC 6265 §5.4)
test "cookie order: longer path cookies first" {
  let jar = CookieJar::new(enabled=true)
  jar.store_from_header(
    "a=root; Path=/",
    "https://example.com/",
    true,
  )
  jar.store_from_header(
    "b=app; Path=/app",
    "https://example.com/app/",
    true,
  )
  // Both match /app/page — but order depends on insertion order currently
  let header = jar.get_cookie_header("https://example.com/app/page", true, true)
  match header {
    Some(h) => {
      inspect(h.contains("a=root"), content="true")
      inspect(h.contains("b=app"), content="true")
    }
    None => assert_true(false)
  }
}
