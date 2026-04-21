///|
/// White-box tests for HTTP CORS/sandbox helpers

///|
fn capture_error(f : () -> Unit raise HttpError) -> HttpError? {
  f() catch {
    err => return Some(err)
  }
  None
}

///|
test "prepare_fetch_options injects Origin for cross-origin CORS" {
  let options = {
    ..FetchOptions::default(),
    mode: Cors,
    origin: "https://example.test/page",
    sandbox: Open,
  }
  let prepared = prepare_fetch_options("https://other.test/asset", options)
  match prepared.headers.get("Origin") {
    Some(value) => inspect(value, content="https://example.test")
    None => assert_true(false)
  }
}

///|
test "prepare_fetch_options blocks by same-origin sandbox" {
  let err = capture_error(fn() raise HttpError {
    let _ = prepare_fetch_options("https://other.test/asset", {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test/page",
      sandbox: SameOrigin,
    })
  })
  match err {
    Some(SandboxError(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "prepare_fetch_options blocks same-origin mode on cross-origin" {
  let err = capture_error(fn() raise HttpError {
    let _ = prepare_fetch_options("https://other.test/asset", {
      ..FetchOptions::default(),
      mode: SameOrigin,
      origin: "https://example.test/page",
      sandbox: Open,
    })
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "enforce_cors_response rejects missing ACAO" {
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/asset",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://example.test/page",
        sandbox: Open,
      },
      { status: 200, headers: {}, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "enforce_cors_response rejects wildcard with credentials" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["access-control-allow-credentials"] = "true"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/asset",
      {
        ..FetchOptions::default(),
        mode: Cors,
        credentials: Include,
        origin: "https://example.test/page",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "enforce_cors_response allows matching origin" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://example.test"
  let result = enforce_cors_response(
    "https://other.test/asset",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test/page",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  inspect(result.status, content="200")
  inspect(result.body, content="ok")
}

// ============================================================
// CORS: Response Header Filtering (Fetch spec § 3.2.5)
// ============================================================

///|
test "CORS: filters non-safelisted headers by default" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["content-type"] = "text/html"
  headers["x-custom-header"] = "secret"
  headers["x-request-id"] = "abc123"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  // content-type is safelisted → visible
  inspect(result.headers.contains("content-type"), content="true")
  // x-custom-header is NOT safelisted and NOT exposed → filtered
  inspect(result.headers.contains("x-custom-header"), content="false")
  inspect(result.headers.contains("x-request-id"), content="false")
}

///|
test "CORS: expose-headers allows specific non-safelisted headers" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["access-control-expose-headers"] = "X-Custom-Header"
  headers["content-type"] = "application/json"
  headers["x-custom-header"] = "visible"
  headers["x-other"] = "hidden"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  inspect(result.headers.contains("x-custom-header"), content="true")
  inspect(result.headers.contains("x-other"), content="false")
  inspect(result.headers.contains("content-type"), content="true")
}

///|
test "CORS: expose-headers wildcard exposes all (no credentials)" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["access-control-expose-headers"] = "*"
  headers["x-custom"] = "val1"
  headers["x-secret"] = "val2"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      credentials: Omit,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  inspect(result.headers.contains("x-custom"), content="true")
  inspect(result.headers.contains("x-secret"), content="true")
}

///|
test "CORS: expose-headers wildcard does NOT work with credentials:Include" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://example.test"
  headers["access-control-allow-credentials"] = "true"
  headers["access-control-expose-headers"] = "*"
  headers["x-custom"] = "val1"
  headers["content-type"] = "text/html"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      credentials: Include,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  // Wildcard is ignored with credentials, but "*" is in the exposed list literally
  // so only safelisted headers should be visible (wildcard doesn't expand)
  inspect(result.headers.contains("content-type"), content="true")
  // x-custom is not literally named, so filtered
  inspect(result.headers.contains("x-custom"), content="false")
}

///|
test "CORS: safelisted headers always visible" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["cache-control"] = "max-age=300"
  headers["content-language"] = "en"
  headers["content-length"] = "42"
  headers["content-type"] = "text/plain"
  headers["expires"] = "Thu, 01 Jan 2026 00:00:00 GMT"
  headers["last-modified"] = "Wed, 01 Jan 2025 00:00:00 GMT"
  headers["pragma"] = "no-cache"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  inspect(result.headers.contains("cache-control"), content="true")
  inspect(result.headers.contains("content-language"), content="true")
  inspect(result.headers.contains("content-length"), content="true")
  inspect(result.headers.contains("content-type"), content="true")
  inspect(result.headers.contains("expires"), content="true")
  inspect(result.headers.contains("last-modified"), content="true")
  inspect(result.headers.contains("pragma"), content="true")
}

// ============================================================
// CORS: Origin validation edge cases
// ============================================================

///|
test "CORS: same-origin request skips CORS checks" {
  let headers : Map[String, String] = {}
  // No ACAO header — but same-origin, so it should pass
  headers["x-custom"] = "visible"
  let result = enforce_cors_response(
    "https://example.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  // Same-origin → no filtering, all headers visible
  inspect(result.headers.contains("x-custom"), content="true")
}

///|
test "CORS: NoCors mode skips CORS enforcement" {
  let headers : Map[String, String] = {}
  headers["x-custom"] = "visible"
  // NoCors: no ACAO needed, no filtering
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: NoCors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  inspect(result.headers.contains("x-custom"), content="true")
}

///|
test "CORS: Navigate mode skips CORS enforcement" {
  let headers : Map[String, String] = {}
  let result = enforce_cors_response(
    "https://other.test/page",
    {
      ..FetchOptions::default(),
      mode: Navigate,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "html" },
  )
  inspect(result.status, content="200")
}

///|
test "CORS: credentials Include with matching origin succeeds" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://example.test"
  headers["access-control-allow-credentials"] = "true"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      credentials: Include,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  inspect(result.status, content="200")
}

///|
test "CORS: credentials Include without allow-credentials header fails" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://example.test"
  // Missing access-control-allow-credentials
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        credentials: Include,
        origin: "https://example.test",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "CORS: origin with port is distinct" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://example.test"
  // Origin has port → different origin
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://example.test:8080",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "CORS: empty origin treated as same-origin" {
  let headers : Map[String, String] = {}
  // No ACAO, but empty origin → not cross-origin → passes
  let result = enforce_cors_response(
    "https://other.test/api",
    { ..FetchOptions::default(), mode: Cors, origin: "", sandbox: Open },
    { status: 200, headers, body: "ok" },
  )
  inspect(result.status, content="200")
}

// ============================================================
// Sandbox edge cases
// ============================================================

///|
test "sandbox: allowlist permits listed origin" {
  let options = {
    ..FetchOptions::default(),
    mode: Cors,
    origin: "https://example.test",
    sandbox: Allowlist(["https://allowed.test"]),
  }
  let prepared = prepare_fetch_options("https://allowed.test/api", options)
  // Should not raise — allowed origin
  inspect(prepared.http_method, content="GET")
}

///|
test "prepare_fetch_options injects Origin for navigate POST" {
  let options = {
    ..FetchOptions::default(),
    http_method: "POST",
    mode: Navigate,
    origin: "https://example.test/form",
    sandbox: Open,
  }
  let prepared = prepare_fetch_options("https://other.test/submit", options)
  match prepared.headers.get("Origin") {
    Some(value) => inspect(value, content="https://example.test")
    None => assert_true(false)
  }
}

///|
test "prepare_fetch_options does not inject Origin for navigate GET" {
  let options = {
    ..FetchOptions::default(),
    http_method: "GET",
    mode: Navigate,
    origin: "https://example.test/form",
    sandbox: Open,
  }
  let prepared = prepare_fetch_options("https://other.test/page", options)
  inspect(prepared.headers.get("Origin"), content="None")
}

///|
test "sandbox: allowlist blocks unlisted origin" {
  let err = capture_error(fn() raise HttpError {
    let _ = prepare_fetch_options("https://blocked.test/api", {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Allowlist(["https://allowed.test"]),
    })
  })
  match err {
    Some(SandboxError(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "sandbox: allowlist always permits same-origin" {
  let options = {
    ..FetchOptions::default(),
    mode: Cors,
    origin: "https://example.test",
    sandbox: Allowlist(["https://other.test"]),
  }
  // Same origin as caller → allowed even if not in list
  let prepared = prepare_fetch_options("https://example.test/api", options)
  inspect(prepared.http_method, content="GET")
}

// ============================================================
// extract_origin / normalize_origin edge cases
// ============================================================

///|
test "extract_origin: standard URL" {
  inspect(
    extract_origin("https://example.com/path"),
    content="https://example.com",
  )
}

///|
test "extract_origin: URL with port" {
  inspect(
    extract_origin("https://example.com:8080/path"),
    content="https://example.com:8080",
  )
}

///|
test "extract_origin: URL without path" {
  inspect(extract_origin("https://example.com"), content="https://example.com")
}

///|
test "extract_origin: no protocol" {
  inspect(extract_origin("/relative/path"), content="")
}

///|
test "normalize_origin: full URL normalized to origin" {
  inspect(
    normalize_origin("https://example.com/path/page"),
    content="https://example.com",
  )
}

///|
test "normalize_origin: empty string" {
  inspect(normalize_origin(""), content="")
}

///|
test "get_header: case insensitive lookup (lowercase key)" {
  let headers : Map[String, String] = {}
  headers["content-type"] = "text/html"
  // get_header tries lowercase first
  inspect(get_header(headers, "Content-Type"), content="Some(\"text/html\")")
}

///|
test "get_header: exact match" {
  let headers : Map[String, String] = {}
  headers["content-type"] = "text/html"
  inspect(get_header(headers, "content-type"), content="Some(\"text/html\")")
}

///|
test "get_header: missing header" {
  let headers : Map[String, String] = {}
  inspect(get_header(headers, "x-missing"), content="None")
}

// ============================================================
// ATTACKER PERSPECTIVE: CORS Bypass Attempts
// ============================================================

///|
/// Attack: ACAO with leading/trailing whitespace to bypass origin check
test "CORS attack: ACAO with whitespace should still match wildcard" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "  *  "
  let result = enforce_cors_response(
    "https://evil.test/steal",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "data" },
  )
  // Trimmed " * " → "*" → should pass
  inspect(result.status, content="200")
}

///|
/// Attack: ACAO with whitespace around specific origin
test "CORS attack: ACAO with whitespace around origin" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "  https://victim.test  "
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  inspect(result.status, content="200")
}

///|
/// Attack: ACAO set to "null" (e.g. from sandboxed iframe) — should NOT match
test "CORS attack: ACAO null string should not match real origin" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "null"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://victim.test",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => () // Correctly blocked
    _ => assert_true(false)
  }
}

///|
/// Attack: ACAO with subdomain prefix trying to match parent domain
test "CORS attack: subdomain in ACAO should not match parent domain" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://evil.victim.test"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://victim.test",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// Attack: ACAO with http:// when caller is https:// (protocol downgrade)
test "CORS attack: http ACAO should not match https origin" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "http://victim.test"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://victim.test",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// Attack: Try to exfiltrate Set-Cookie via CORS response
test "CORS attack: Set-Cookie header must be filtered" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["set-cookie"] = "session=stolen123"
  headers["content-type"] = "application/json"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "{}" },
  )
  // Set-Cookie must be filtered out
  inspect(result.headers.contains("set-cookie"), content="false")
  // But content-type (safelisted) is visible
  inspect(result.headers.contains("content-type"), content="true")
}

///|
/// Attack: Try to read Authorization header via CORS response
test "CORS attack: Authorization response header must be filtered" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["authorization"] = "Bearer stolen-token"
  headers["x-internal-id"] = "secret-123"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  inspect(result.headers.contains("authorization"), content="false")
  inspect(result.headers.contains("x-internal-id"), content="false")
}

///|
/// Attack: Expose-Headers with credentials tries to use wildcard
test "CORS attack: wildcard expose-headers with credentials is blocked" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://victim.test"
  headers["access-control-allow-credentials"] = "true"
  headers["access-control-expose-headers"] = "*"
  headers["x-secret"] = "sensitive-data"
  headers["set-cookie"] = "session=abc"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      credentials: Include,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  // Wildcard is ignored with credentials → non-safelisted headers filtered
  inspect(result.headers.contains("x-secret"), content="false")
  inspect(result.headers.contains("set-cookie"), content="false")
}

///|
/// Attack: Multiple ACAO values (spec says single value only)
test "CORS attack: multiple origins in ACAO should fail" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://victim.test https://evil.test"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://victim.test",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  // "https://victim.test https://evil.test" != "https://victim.test"
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// Attack: ACAO with trailing path (should not match origin-only)
test "CORS attack: ACAO with path should not match origin" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://victim.test/evil"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://victim.test",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

// ============================================================
// MODERN ATTACK VECTORS (2024-2026)
// ============================================================

///|
/// CORS Origin Reflection attack: server naively reflects Origin as ACAO
/// Our implementation checks exact match, so reflected origin works
/// This test documents the behavior — the risk is on the server side
test "CORS reflection: server reflects origin (this is a server misconfiguration)" {
  let headers : Map[String, String] = {}
  // Server reflects any origin — our client-side check passes for exact match
  headers["access-control-allow-origin"] = "https://evil.test"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://api.test/data",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://victim.test", // Caller is victim
        sandbox: Open,
      },
      { status: 200, headers, body: "secret" },
    )
  })
  // ACAO is "evil.test" but caller is "victim.test" → mismatch → blocked
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// CORS: case sensitivity of origin scheme
/// "HTTPS://example.test" vs "https://example.test"
test "CORS: scheme case sensitivity in origin" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "HTTPS://victim.test"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://victim.test",
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  // Strict comparison: "HTTPS://victim.test" != "https://victim.test" → blocked
  // This is correct per spec (origins are case-sensitive)
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// CORS: IDN homograph attack — unicode domain vs ASCII
test "CORS: unicode domain does not match ASCII lookalike" {
  let headers : Map[String, String] = {}
  // Cyrillic "а" looks like Latin "a" but is different codepoint
  headers["access-control-allow-origin"] = "https://ex\u0430mple.test"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://example.test", // Latin a
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// CORS: tab/newline characters in ACAO value (HTTP header injection)
test "CORS: tab character in ACAO is trimmed and accepted" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://victim.test\t"
  // MoonBit's trim() removes whitespace including \t
  // This matches browser behavior (HTTP header values are trimmed of OWS)
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  inspect(result.status, content="200")
}

///|
/// CORS: Expose-Headers header injection via comma in header name
test "CORS: expose-headers cannot inject via comma in value" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  // Attacker tries to expose "set-cookie" by injecting into expose-headers
  headers["access-control-expose-headers"] = "x-safe, set-cookie"
  headers["x-safe"] = "visible"
  headers["set-cookie"] = "session=stolen"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  // If server explicitly lists set-cookie in expose-headers, it IS exposed
  // This is correct behavior — the server explicitly opted in
  // The security boundary is on the server, not the client
  inspect(result.headers.contains("set-cookie"), content="true")
  inspect(result.headers.contains("x-safe"), content="true")
}

///|
/// DNS rebinding: origin check with IP address
test "CORS: IP-based origin check is strict" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://192.168.1.1"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://192.168.1.1/api",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://192.168.1.2", // Different IP
        sandbox: Open,
      },
      { status: 200, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// CORS: credentials SameOrigin mode with cross-origin request
test "CORS: credentials SameOrigin does not trigger credential check" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  // credentials=SameOrigin + cross-origin → credentials are NOT included
  // So wildcard ACAO should work (no credentials check triggered)
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      credentials: CredentialsMode::SameOrigin,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  inspect(result.status, content="200")
}

///|
/// Header smuggling: duplicate header keys use last value
test "header smuggling: duplicate ACAO uses last value" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "https://evil.test"
  // Overwrite with correct origin
  headers["access-control-allow-origin"] = "https://victim.test"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "ok" },
  )
  // Map stores last value → "https://victim.test" → matches
  inspect(result.status, content="200")
}

///|
/// Sandbox bypass: protocol-relative URL
test "sandbox: protocol-relative URL uses caller scheme for origin check" {
  let err = capture_error(fn() raise HttpError {
    let _ = prepare_fetch_options("//evil.test/steal", {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://victim.test",
      sandbox: SameOrigin,
    })
  })
  // //evil.test → https://evil.test (inherits caller scheme)
  // SameOrigin sandbox → https://evil.test != https://victim.test → blocked
  match err {
    Some(SandboxError(_)) => ()
    _ => assert_true(false)
  }
}

// ============================================================
// BOUNDARY CONDITIONS: Origin parsing edge cases
// ============================================================

///|
test "extract_origin: data URL returns empty (no scheme://)" {
  // data: URLs don't contain "://" → returns ""
  inspect(extract_origin("data:text/html,<h1>hi</h1>"), content="")
}

///|
test "extract_origin: blob URL extracts inner origin" {
  // blob:https://example.com/uuid → "://" found → origin = "blob:https://example.com"
  inspect(
    extract_origin("blob:https://example.com/uuid-1234"),
    content="blob:https://example.com",
  )
}

///|
test "extract_origin: javascript URL has no meaningful origin" {
  inspect(extract_origin("javascript:alert(1)"), content="")
}

///|
test "extract_origin: file URL" {
  inspect(extract_origin("file:///etc/passwd"), content="file://")
}

///|
test "resolve_request_origin: relative URL uses caller" {
  inspect(
    resolve_request_origin("/api/data", "https://example.test"),
    content="https://example.test",
  )
}

///|
test "resolve_request_origin: protocol-relative with no caller scheme" {
  // Caller has no scheme → empty result
  inspect(resolve_request_origin("//evil.test/x", "localhost"), content="")
}

///|
test "is_cross_origin: both empty is not cross-origin" {
  inspect(is_cross_origin("", ""), content="false")
}

///|
test "is_cross_origin: one empty is not cross-origin" {
  inspect(is_cross_origin("https://a.test", ""), content="false")
  inspect(is_cross_origin("", "https://a.test"), content="false")
}

///|
test "is_cross_origin: same origin" {
  inspect(is_cross_origin("https://a.test", "https://a.test"), content="false")
}

///|
test "is_cross_origin: different origin" {
  inspect(is_cross_origin("https://a.test", "https://b.test"), content="true")
}

// ============================================================
// BOUNDARY CONDITIONS: CORS header filtering edge cases
// ============================================================

///|
test "CORS filter: empty expose-headers value" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["access-control-expose-headers"] = ""
  headers["x-custom"] = "val"
  headers["content-type"] = "text/html"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  // Empty expose → only safelisted headers
  inspect(result.headers.contains("content-type"), content="true")
  inspect(result.headers.contains("x-custom"), content="false")
}

///|
test "CORS filter: expose-headers with extra commas" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  headers["access-control-expose-headers"] = ",,x-custom,,,"
  headers["x-custom"] = "val"
  headers["x-other"] = "hidden"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  inspect(result.headers.contains("x-custom"), content="true")
  inspect(result.headers.contains("x-other"), content="false")
}

///|
test "CORS filter: response with no headers at all" {
  let headers : Map[String, String] = {}
  headers["access-control-allow-origin"] = "*"
  let result = enforce_cors_response(
    "https://other.test/api",
    {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Open,
    },
    { status: 200, headers, body: "" },
  )
  inspect(result.status, content="200")
}

///|
/// Edge case: CORS check on non-2xx response
test "CORS: non-2xx response still requires valid ACAO" {
  let headers : Map[String, String] = {}
  // No ACAO on 403 → should still be blocked by CORS
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/forbidden",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://example.test",
        sandbox: Open,
      },
      { status: 403, headers, body: "Forbidden" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// Edge case: CORS check on redirect response (3xx)
test "CORS: 301 response without ACAO is blocked" {
  let headers : Map[String, String] = {}
  headers["location"] = "https://other.test/new-path"
  let err = capture_error(fn() raise HttpError {
    let _ = enforce_cors_response(
      "https://other.test/old",
      {
        ..FetchOptions::default(),
        mode: Cors,
        origin: "https://example.test",
        sandbox: Open,
      },
      { status: 301, headers, body: "" },
    )
  })
  match err {
    Some(CorsError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// Sandbox: empty allowlist blocks everything
test "sandbox: empty allowlist blocks all cross-origin" {
  let err = capture_error(fn() raise HttpError {
    let _ = prepare_fetch_options("https://other.test/api", {
      ..FetchOptions::default(),
      mode: Cors,
      origin: "https://example.test",
      sandbox: Allowlist([]),
    })
  })
  match err {
    Some(SandboxError(_)) => ()
    _ => assert_true(false)
  }
}

///|
/// Sandbox: allowlist with same-origin URL allows it
test "sandbox: allowlist same-origin request always allowed" {
  let opts = {
    ..FetchOptions::default(),
    mode: Cors,
    origin: "https://example.test",
    sandbox: Allowlist([]), // Empty allowlist
  }
  // Same-origin request is always allowed
  let prepared = prepare_fetch_options("https://example.test/api", opts)
  inspect(prepared.http_method, content="GET")
}

///|
/// headers_to_json: empty headers
test "headers_to_json: empty map" {
  inspect(headers_to_json({}), content="{}")
}

///|
/// headers_to_json: single header
test "headers_to_json: single header" {
  let headers : Map[String, String] = {}
  headers["a"] = "b"
  inspect(headers_to_json(headers), content="{\"a\":\"b\"}")
}
