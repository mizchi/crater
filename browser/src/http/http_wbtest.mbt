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
