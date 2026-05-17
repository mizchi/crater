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
