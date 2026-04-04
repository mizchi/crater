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
