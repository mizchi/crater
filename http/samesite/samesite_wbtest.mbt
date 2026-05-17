///|
test "classify_site_context: same eTLD+1 is SameSite" {
  inspect(
    classify_site_context("https://app.example.com", "example.com"),
    content="SameSite",
  )
}

///|
test "classify_site_context: different site is CrossSite" {
  inspect(
    classify_site_context("https://app.example.com", "evil.com"),
    content="CrossSite",
  )
}

///|
test "classify_site_context: localhost is SameSite to itself" {
  inspect(
    classify_site_context("http://localhost:3000", "localhost"),
    content="SameSite",
  )
}

///|
test "classify_site_context: IP literal matches itself" {
  inspect(
    classify_site_context("http://127.0.0.1", "127.0.0.1"),
    content="SameSite",
  )
}

///|
test "classify_site_context: malformed origin falls back to CrossSite" {
  inspect(
    classify_site_context("not-a-url", "example.com"),
    content="CrossSite",
  )
}

///|
test "classify_site_context: trailing-dot FQDN matches non-dotted form" {
  inspect(
    classify_site_context("https://app.example.com.", "example.com"),
    content="SameSite",
  )
  inspect(
    classify_site_context("https://app.example.com", "example.com."),
    content="SameSite",
  )
}

///|
/// Build a ParsedCookie via the real Set-Cookie parser so tests exercise
/// the public surface rather than a private constructor.
fn test_cookie(
  name : String,
  same_site_attr : String,
  secure : Bool,
) -> @cookie_jar.ParsedCookie {
  let secure_attr = if secure { "; Secure" } else { "" }
  let header = name + "=v; Path=/; SameSite=" + same_site_attr + secure_attr
  match @cookie_jar.parse_set_cookie(header, "example.com", "/") {
    Some(c) => c
    None => panic()
  }
}

///|
test "should_attach_cookie: Strict only attaches when same-site" {
  let cookie = test_cookie("s", "Strict", false)
  // same-site, top-level nav
  inspect(
    should_attach_cookie(cookie, "https://example.com/x", SameSite, true),
    content="true",
  )
  // same-site, subresource
  inspect(
    should_attach_cookie(cookie, "https://example.com/x", SameSite, false),
    content="true",
  )
  // cross-site, top-level nav
  inspect(
    should_attach_cookie(cookie, "https://evil.com/x", CrossSite, true),
    content="false",
  )
  // cross-site, subresource
  inspect(
    should_attach_cookie(cookie, "https://evil.com/x", CrossSite, false),
    content="false",
  )
}

///|
test "should_attach_cookie: Lax attaches on cross-site top-level nav" {
  let cookie = test_cookie("l", "Lax", false)
  // same-site, top-level nav
  inspect(
    should_attach_cookie(cookie, "https://example.com/x", SameSite, true),
    content="true",
  )
  // same-site, subresource
  inspect(
    should_attach_cookie(cookie, "https://example.com/x", SameSite, false),
    content="true",
  )
  // cross-site, top-level nav
  inspect(
    should_attach_cookie(cookie, "https://evil.com/x", CrossSite, true),
    content="true",
  )
  // cross-site, subresource
  inspect(
    should_attach_cookie(cookie, "https://evil.com/x", CrossSite, false),
    content="false",
  )
}

///|
test "should_attach_cookie: None always attaches" {
  let cookie = test_cookie("n", "None", true)
  // same-site, top-level nav
  inspect(
    should_attach_cookie(cookie, "https://example.com/x", SameSite, true),
    content="true",
  )
  // same-site, subresource
  inspect(
    should_attach_cookie(cookie, "https://example.com/x", SameSite, false),
    content="true",
  )
  // cross-site, top-level nav
  inspect(
    should_attach_cookie(cookie, "https://evil.com/x", CrossSite, true),
    content="true",
  )
  // cross-site, subresource
  inspect(
    should_attach_cookie(cookie, "https://evil.com/x", CrossSite, false),
    content="true",
  )
}
