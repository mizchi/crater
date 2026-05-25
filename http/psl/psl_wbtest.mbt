///|
test "psl registrable_domain handles co.uk multi-level public suffix" {
  inspect(registrable_domain("example.co.uk"), content="example.co.uk")
  inspect(registrable_domain("other.co.uk"), content="other.co.uk")
  // Sibling sites under co.uk must not collapse to "co.uk".
  let a = registrable_domain("example.co.uk")
  let b = registrable_domain("other.co.uk")
  inspect(a == b, content="false")
}

///|
test "psl registrable_domain handles co.jp" {
  inspect(registrable_domain("example.co.jp"), content="example.co.jp")
  inspect(
    registrable_domain("alpha.beta.example.co.jp"),
    content="example.co.jp",
  )
}

///|
test "psl registrable_domain handles github.io private suffix" {
  inspect(registrable_domain("alice.github.io"), content="alice.github.io")
  inspect(registrable_domain("bob.github.io"), content="bob.github.io")
  let a = registrable_domain("alice.github.io")
  let b = registrable_domain("bob.github.io")
  inspect(a == b, content="false")
}

///|
test "psl registrable_domain falls back to last-two-labels for unknown TLDs" {
  // 'xyz' is not in the curated subset, so the heuristic applies.
  inspect(registrable_domain("foo.example.xyz"), content="example.xyz")
  inspect(registrable_domain("example.xyz"), content="example.xyz")
}

///|
test "psl registrable_domain returns localhost as-is" {
  inspect(registrable_domain("localhost"), content="localhost")
}

///|
test "psl registrable_domain returns IPv4 literal as-is" {
  inspect(registrable_domain("127.0.0.1"), content="127.0.0.1")
  inspect(registrable_domain("192.168.1.10"), content="192.168.1.10")
}

///|
test "psl registrable_domain handles trailing dot FQDN" {
  inspect(registrable_domain("example.co.uk."), content="example.co.uk")
  inspect(registrable_domain("example.com."), content="example.com")
}

///|
test "psl registrable_domain is case-insensitive" {
  inspect(registrable_domain("Example.CO.UK"), content="example.co.uk")
  inspect(registrable_domain("ALICE.GITHUB.IO"), content="alice.github.io")
}

///|
test "psl normalize_host lowercases and strips trailing dot" {
  inspect(normalize_host("EXAMPLE.com."), content="example.com")
  inspect(normalize_host("a.b.c"), content="a.b.c")
  inspect(normalize_host(""), content="")
}

///|
test "psl is_ip_literal accepts IPv4 and bracketed IPv6, rejects others" {
  inspect(is_ip_literal("127.0.0.1"), content="true")
  inspect(is_ip_literal("[::1]"), content="true")
  inspect(is_ip_literal("[2001:db8::1]"), content="true")
  inspect(is_ip_literal("256.0.0.1"), content="false")
  inspect(is_ip_literal("example.com"), content="false")
  inspect(is_ip_literal("1.2.3"), content="false")
}
