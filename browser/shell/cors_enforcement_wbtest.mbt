///|
/// Tests for the CORS gate seam (`script_fetch_with_cors`).
///
/// These exercise the gate directly via captured fetcher closures so
/// the path stays unit-testable without a stub HTTP layer:
///   - classify_request → Allow / PreflightRequired / Blocked decision
///   - PreflightCache::get_or_validate invocation count
///   - validate_actual_response wiring (CorsBlocked on missing ACA-Origin)
///   - NoCors short-circuit (skips validate_actual_response per spec)
///
/// The actual `Browser::fetch_external_script_source` wiring is
/// covered indirectly: every call site uses the same gate, and the
/// gate's behaviour is locked down by these seam tests.

///|
/// Build a synthetic HttpResponse with the given status and headers.
/// Header names are written lowercased so the gate's lookup (which
/// uses `get_header` semantics) matches regardless of case.
fn cors_test_response(
  status~ : Int,
  aca_origin? : String,
  body? : String = "/*js*/",
) -> @http.HttpResponse {
  let h : Map[String, String] = {}
  if aca_origin is Some(v) {
    h["access-control-allow-origin"] = v
  }
  { status, headers: h, body }
}

///|
/// Build a Cors-mode FetchOptions for a cross-origin GET. `origin` is
/// the initiating page; the target URL goes to a different origin so
/// classify_request takes the cross-origin branch.
fn cors_test_options(
  method? : String = "GET",
  origin~ : String,
  mode? : @http.RequestMode = Cors,
  credentials? : @http.CredentialsMode = Omit,
  headers? : Map[String, String] = {},
) -> @http.FetchOptions {
  {
    ..@http.FetchOptions::default(),
    http_method: method,
    headers,
    mode,
    credentials,
    origin,
  }
}

///|
async test "script_fetch_with_cors: cross-origin GET Allow + ACA-Origin echo → Ok" {
  let preflight_cache = @http_cors.PreflightCache::new()
  let preflight_calls : Array[Int] = [0]
  let fetcher_calls : Array[Int] = [0]
  let preflight_fetcher = fn(
    _req : @http_cors.PreflightRequest,
  ) -> @http.HttpResponse {
    preflight_calls[0] = preflight_calls[0] + 1
    cors_test_response(status=0)
  }
  let fetcher = async fn(
    _u : String,
    _o : @http.FetchOptions,
  ) -> @http.HttpResponse raise @http.HttpError {
    fetcher_calls[0] = fetcher_calls[0] + 1
    cors_test_response(status=200, aca_origin="https://example.com")
  }
  let response = script_fetch_with_cors(
    url="https://api.other.com/x.js",
    options=cors_test_options(origin="https://example.com"),
    preflight_cache~,
    now=fn() { 1000.0 },
    preflight_fetcher~,
    fetcher~,
  )
  inspect(response.status, content="200")
  // Allow path: no preflight, one actual fetch.
  inspect(preflight_calls[0], content="0")
  inspect(fetcher_calls[0], content="1")
}

///|
async test "script_fetch_with_cors: cross-origin GET Allow but missing ACA-Origin → CorsBlocked" {
  let preflight_cache = @http_cors.PreflightCache::new()
  let preflight_fetcher = fn(
    _req : @http_cors.PreflightRequest,
  ) -> @http.HttpResponse {
    cors_test_response(status=0)
  }
  let fetcher = async fn(
    _u : String,
    _o : @http.FetchOptions,
  ) -> @http.HttpResponse raise @http.HttpError {
    // No ACA-Origin header → validate_actual_response should refuse.
    cors_test_response(status=200)
  }
  let outcome : Result[Int, String] = try {
    let r = script_fetch_with_cors(
      url="https://api.other.com/x.js",
      options=cors_test_options(origin="https://example.com"),
      preflight_cache~,
      now=fn() { 1000.0 },
      preflight_fetcher~,
      fetcher~,
    )
    Ok(r.status)
  } catch {
    @http.HttpError::CorsBlocked(_) => Err("CorsBlocked")
    e => Err("other:" + e.to_string())
  }
  inspect(
    outcome,
    content=(
      #|Err(CorsBlocked)
    ),
  )
}

///|
async test "script_fetch_with_cors: PreflightRequired path invokes preflight fetcher once on first call" {
  let preflight_cache = @http_cors.PreflightCache::new()
  let preflight_calls : Array[Int] = [0]
  let fetcher_calls : Array[Int] = [0]
  let preflight_fetcher = fn(
    _req : @http_cors.PreflightRequest,
  ) -> @http.HttpResponse {
    preflight_calls[0] = preflight_calls[0] + 1
    // Successful preflight that grants the custom method + header for
    // the cache's documented Max-Age (parsed as Double seconds).
    let h : Map[String, String] = {
      "access-control-allow-origin": "https://example.com",
      "access-control-allow-methods": "POST",
      "access-control-allow-headers": "x-csrf",
      "access-control-max-age": "600",
    }
    { status: 204, headers: h, body: "" }
  }
  let fetcher = async fn(
    _u : String,
    _o : @http.FetchOptions,
  ) -> @http.HttpResponse raise @http.HttpError {
    fetcher_calls[0] = fetcher_calls[0] + 1
    cors_test_response(status=200, aca_origin="https://example.com")
  }
  // POST with a custom header → classify_request returns PreflightRequired.
  let opts = cors_test_options(method="POST", origin="https://example.com", headers={
    "X-Csrf": "tok",
  })
  let response = script_fetch_with_cors(
    url="https://api.other.com/upload",
    options=opts,
    preflight_cache~,
    now=fn() { 1000.0 },
    preflight_fetcher~,
    fetcher~,
  )
  inspect(response.status, content="200")
  inspect(preflight_calls[0], content="1")
  inspect(fetcher_calls[0], content="1")
}

///|
async test "script_fetch_with_cors: cached preflight skips preflight fetcher on second request" {
  let preflight_cache = @http_cors.PreflightCache::new()
  let preflight_calls : Array[Int] = [0]
  let fetcher_calls : Array[Int] = [0]
  let preflight_fetcher = fn(
    _req : @http_cors.PreflightRequest,
  ) -> @http.HttpResponse {
    preflight_calls[0] = preflight_calls[0] + 1
    let h : Map[String, String] = {
      "access-control-allow-origin": "https://example.com",
      "access-control-allow-methods": "POST",
      "access-control-allow-headers": "x-csrf",
      "access-control-max-age": "600",
    }
    { status: 204, headers: h, body: "" }
  }
  let fetcher = async fn(
    _u : String,
    _o : @http.FetchOptions,
  ) -> @http.HttpResponse raise @http.HttpError {
    fetcher_calls[0] = fetcher_calls[0] + 1
    cors_test_response(status=200, aca_origin="https://example.com")
  }
  let opts = cors_test_options(method="POST", origin="https://example.com", headers={
    "X-Csrf": "tok",
  })
  // Frozen clock under Max-Age: second call must hit the cache.
  let now = fn() -> Double { 1000.0 }
  // First request → cache miss, preflight fetcher called once.
  let _ = script_fetch_with_cors(
    url="https://api.other.com/upload",
    options=opts,
    preflight_cache~,
    now~,
    preflight_fetcher~,
    fetcher~,
  )
  // Second request with the same descriptor → cache hit.
  let _ = script_fetch_with_cors(
    url="https://api.other.com/upload",
    options=opts,
    preflight_cache~,
    now~,
    preflight_fetcher~,
    fetcher~,
  )
  inspect(preflight_calls[0], content="1")
  inspect(fetcher_calls[0], content="2")
}

///|
async test "script_fetch_with_cors: NoCors cross-origin skips validate_actual_response" {
  let preflight_cache = @http_cors.PreflightCache::new()
  let preflight_fetcher = fn(
    _req : @http_cors.PreflightRequest,
  ) -> @http.HttpResponse {
    cors_test_response(status=0)
  }
  let fetcher = async fn(
    _u : String,
    _o : @http.FetchOptions,
  ) -> @http.HttpResponse raise @http.HttpError {
    // No ACA-Origin header. With NoCors mode the gate must NOT call
    // validate_actual_response — the script tag treats the response
    // as opaque-but-loadable per spec.
    cors_test_response(status=200)
  }
  let response = script_fetch_with_cors(
    url="https://cdn.other.com/lib.js",
    options=cors_test_options(origin="https://example.com", mode=NoCors),
    preflight_cache~,
    now=fn() { 1000.0 },
    preflight_fetcher~,
    fetcher~,
  )
  inspect(response.status, content="200")
}

///|
async test "script_fetch_with_cors: NoCors + non-simple method → Blocked classification surfaces as CorsBlocked" {
  let preflight_cache = @http_cors.PreflightCache::new()
  let preflight_fetcher = fn(
    _req : @http_cors.PreflightRequest,
  ) -> @http.HttpResponse {
    cors_test_response(status=0)
  }
  let fetcher = async fn(
    _u : String,
    _o : @http.FetchOptions,
  ) -> @http.HttpResponse raise @http.HttpError {
    cors_test_response(status=200, aca_origin="https://example.com")
  }
  let outcome : Result[Int, String] = try {
    let r = script_fetch_with_cors(
      url="https://api.other.com/x.js",
      options=cors_test_options(
        method="PUT",
        origin="https://example.com",
        mode=NoCors,
      ),
      preflight_cache~,
      now=fn() { 1000.0 },
      preflight_fetcher~,
      fetcher~,
    )
    Ok(r.status)
  } catch {
    @http.HttpError::CorsBlocked(_) => Err("CorsBlocked")
    e => Err("other:" + e.to_string())
  }
  inspect(
    outcome,
    content=(
      #|Err(CorsBlocked)
    ),
  )
}
