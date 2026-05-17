///|
/// Top-level navigation cookie attach is filtered by SameSite policy.
/// These tests pin the wiring contract: `fetch_navigation_document`
/// must classify the call as a top-level navigation and pass the
/// initiating page's origin so cross-site Strict cookies are dropped
/// while cross-site Lax cookies still ride along.

///|
test "navigation: Strict cookie attaches on same-site top-level nav" {
  let jar = @http_cookie_jar.CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc; SameSite=Strict; Secure", "https://example.com/", true,
  )
  // Same-site top-level nav: Strict cookie should attach.
  debug_inspect(
    navigation_cookie_header(
      jar, "https://example.com/login", "https://example.com/dashboard",
    ),
    content="Some(\"session=abc\")",
  )
}

///|
test "navigation: Strict cookie blocked on cross-site top-level nav" {
  let jar = @http_cookie_jar.CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc; SameSite=Strict; Secure", "https://example.com/", true,
  )
  // Cross-site top-level nav: Strict cookie must NOT attach.
  debug_inspect(
    navigation_cookie_header(
      jar, "https://other.com/landing", "https://example.com/dashboard",
    ),
    content="None",
  )
}

///|
test "navigation: Lax cookie attaches on cross-site top-level nav" {
  let jar = @http_cookie_jar.CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc; SameSite=Lax; Secure", "https://example.com/", true,
  )
  // Cross-site top-level nav: Lax cookie attaches (key Lax behavior).
  // If navigation_fetch ever stops passing is_top_level_navigation=true,
  // this assertion flips to None and the test fails — that is the wiring
  // we want to lock down.
  debug_inspect(
    navigation_cookie_header(
      jar, "https://other.com/landing", "https://example.com/dashboard",
    ),
    content="Some(\"session=abc\")",
  )
}

///|
test "navigation: empty source_url treated as same-site (no cross-site enforcement)" {
  let jar = @http_cookie_jar.CookieJar::new(enabled=true)
  jar.store_from_header(
    "session=abc; SameSite=Strict; Secure", "https://example.com/", true,
  )
  // No initiating page (typed URL / initial load): treat as same-site
  // so Strict cookies attach. Matches cookie_jar's site_origin="" semantics.
  debug_inspect(
    navigation_cookie_header(jar, "", "https://example.com/dashboard"),
    content="Some(\"session=abc\")",
  )
}
