///|
test "classify_request: simple GET same-origin is Allow" {
  let d = classify_request(
    url="https://example.com/api/x",
    origin="https://example.com",
    mode=@http_impl.RequestMode::Cors,
    method="GET",
    headers={},
  )
  inspect(d, content="Allow")
}

///|
test "classify_request: simple GET cross-origin is Allow (validate at response)" {
  let d = classify_request(
    url="https://api.other.com/x",
    origin="https://example.com",
    mode=@http_impl.RequestMode::Cors,
    method="GET",
    headers={},
  )
  inspect(d, content="Allow")
}

///|
test "classify_request: POST cross-origin with custom header → PreflightRequired" {
  let d = classify_request(
    url="https://api.other.com/upload",
    origin="https://example.com",
    mode=@http_impl.RequestMode::Cors,
    method="POST",
    headers={ "X-Csrf": "tok", "Content-Type": "application/json" },
  )
  match d {
    PreflightRequired(req) => {
      inspect(req.url, content="https://api.other.com/upload")
      inspect(req.method, content="POST")
      inspect(req.request_headers, content="[x-csrf]")
    }
    _ => panic()
  }
}

///|
test "classify_request: NoCors + custom header → Blocked" {
  let d = classify_request(
    url="https://api.other.com/x",
    origin="https://example.com",
    mode=@http_impl.RequestMode::NoCors,
    method="POST",
    headers={ "X-Csrf": "tok" },
  )
  match d {
    Blocked(_) => inspect(true, content="true")
    _ => panic()
  }
}

///|
/// Build a synthetic preflight HttpResponse from optional ACA-* headers.
/// All header names are written lowercased so the validator's lookup
/// (which uses `get_header` semantics) finds them regardless of case.
fn test_preflight_response(
  status~ : Int,
  aca_origin? : String,
  aca_methods? : String,
  aca_headers? : String,
  aca_credentials? : String,
  aca_max_age? : String,
) -> @http_impl.HttpResponse {
  let h : Map[String, String] = {}
  if aca_origin is Some(v) {
    h["access-control-allow-origin"] = v
  }
  if aca_methods is Some(v) {
    h["access-control-allow-methods"] = v
  }
  if aca_headers is Some(v) {
    h["access-control-allow-headers"] = v
  }
  if aca_credentials is Some(v) {
    h["access-control-allow-credentials"] = v
  }
  if aca_max_age is Some(v) {
    h["access-control-max-age"] = v
  }
  { status, headers: h, body: "" }
}

///|
test "validate_preflight_response: all required headers present → Ok" {
  let req = PreflightRequest::{
    url: "https://api.other.com/x",
    origin: "https://example.com",
    method: "POST",
    request_headers: ["content-type", "x-csrf"],
  }
  let resp = test_preflight_response(
    status=204,
    aca_origin="https://example.com",
    aca_methods="POST",
    aca_headers="content-type, x-csrf",
    aca_credentials="true",
    aca_max_age="600",
  )
  match validate_preflight_response(req, resp) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("expected Ok, got Err: " + e)
  }
}

///|
test "validate_preflight_response: missing ACA-Origin → Err" {
  let req = PreflightRequest::{
    url: "https://api.other.com/x",
    origin: "https://example.com",
    method: "POST",
    request_headers: ["content-type"],
  }
  let resp = test_preflight_response(
    status=204,
    aca_methods="POST",
    aca_headers="content-type",
  )
  match validate_preflight_response(req, resp) {
    Err(_) => inspect(true, content="true")
    Ok(_) => fail("expected Err")
  }
}

///|
test "validate_preflight_response: required method not listed → Err" {
  let req = PreflightRequest::{
    url: "https://api.other.com/x",
    origin: "https://example.com",
    method: "DELETE",
    request_headers: [],
  }
  let resp = test_preflight_response(
    status=204,
    aca_origin="https://example.com",
    aca_methods="GET, POST",
  )
  match validate_preflight_response(req, resp) {
    Err(_) => inspect(true, content="true")
    Ok(_) => fail("expected Err")
  }
}

///|
test "validate_actual_response: same-origin always Ok regardless of headers" {
  let resp = test_preflight_response(status=200)
  match
    validate_actual_response(
      request_url="https://example.com/api/x",
      origin="https://example.com",
      credentials=@http_impl.CredentialsMode::Include,
      response=resp,
    ) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("expected Ok, got Err: " + e)
  }
}

///|
test "validate_actual_response: cross-origin + ACA-Origin echo → Ok" {
  let resp = test_preflight_response(
    status=200,
    aca_origin="https://example.com",
  )
  match
    validate_actual_response(
      request_url="https://api.other.com/x",
      origin="https://example.com",
      credentials=@http_impl.CredentialsMode::Omit,
      response=resp,
    ) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("expected Ok, got Err: " + e)
  }
}

///|
test "validate_actual_response: credentials=Include with wildcard → Err" {
  let resp = test_preflight_response(
    status=200,
    aca_origin="*",
    aca_credentials="true",
  )
  match
    validate_actual_response(
      request_url="https://api.other.com/x",
      origin="https://example.com",
      credentials=@http_impl.CredentialsMode::Include,
      response=resp,
    ) {
    Err(_) => inspect(true, content="true")
    Ok(_) => fail("expected Err")
  }
}

///|
test "validate_actual_response: credentials=Include needs ACA-Credentials=true" {
  let resp = test_preflight_response(
    status=200,
    aca_origin="https://example.com",
  )
  match
    validate_actual_response(
      request_url="https://api.other.com/x",
      origin="https://example.com",
      credentials=@http_impl.CredentialsMode::Include,
      response=resp,
    ) {
    Err(_) => inspect(true, content="true")
    Ok(_) => fail("expected Err")
  }
}

///|
test "PreflightCache::get_or_validate: cache hit within Max-Age (fetcher called once)" {
  let cache = PreflightCache::new()
  let req = PreflightRequest::{
    url: "https://api.other.com/x",
    origin: "https://example.com",
    method: "POST",
    request_headers: ["content-type", "x-csrf"],
  }
  // Mutable counter via 1-element array (Ref not assumed available).
  let calls : Array[Int] = [0]
  let fetcher = fn(_r : PreflightRequest) -> @http_impl.HttpResponse {
    calls[0] = calls[0] + 1
    test_preflight_response(
      status=204,
      aca_origin="https://example.com",
      aca_methods="POST",
      aca_headers="content-type, x-csrf",
      aca_max_age="600",
    )
  }
  // Frozen clock; both calls happen at t=1000.0, well under 600s Max-Age.
  let now = fn() -> Double { 1000.0 }
  match cache.get_or_validate(req, now, fetcher) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("first call expected Ok, got Err: " + e)
  }
  match cache.get_or_validate(req, now, fetcher) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("second call expected Ok, got Err: " + e)
  }
  inspect(calls[0], content="1")
}

///|
test "HttpError carries CorsBlocked variant" {
  let e : @http_impl.HttpError = @http_impl.HttpError::CorsBlocked("test")
  inspect(e, content="CorsBlocked(test)")
}

///|
test "HttpError carries PreflightFailed variant" {
  let e : @http_impl.HttpError = @http_impl.HttpError::PreflightFailed(
    "missing ACA-Origin",
  )
  inspect(e, content="PreflightFailed(missing ACA-Origin)")
}

///|
test "PreflightCache::get_or_validate: max_entries cap evicts oldest in FIFO order" {
  // max_entries=2 lets us add 3 distinct preflights and confirm the
  // first one was evicted (must re-fetch on lookup) while the second
  // and third remain cached (no re-fetch).
  let cache = PreflightCache::new(max_entries=2)
  let calls : Array[Int] = [0]
  let fetcher = fn(r : PreflightRequest) -> @http_impl.HttpResponse {
    calls[0] = calls[0] + 1
    test_preflight_response(
      status=204,
      aca_origin=r.origin,
      aca_methods=r.method,
      aca_headers=r.request_headers.join(", "),
      aca_max_age="600",
    )
  }
  let now = fn() -> Double { 1000.0 }
  let req_a = PreflightRequest::{
    url: "https://api.other.com/a",
    origin: "https://example.com",
    method: "PUT",
    request_headers: ["x-a"],
  }
  let req_b = PreflightRequest::{
    url: "https://api.other.com/b",
    origin: "https://example.com",
    method: "PUT",
    request_headers: ["x-b"],
  }
  let req_c = PreflightRequest::{
    url: "https://api.other.com/c",
    origin: "https://example.com",
    method: "PUT",
    request_headers: ["x-c"],
  }
  let _ = cache.get_or_validate(req_a, now, fetcher)
  let _ = cache.get_or_validate(req_b, now, fetcher)
  let _ = cache.get_or_validate(req_c, now, fetcher)
  // 3 distinct preflights → 3 fetches so far.
  inspect(calls[0], content="3")
  // Cache must hold exactly max_entries=2 entries.
  inspect(cache.entries.length(), content="2")
  // b and c are still cached → no extra fetch.
  let _ = cache.get_or_validate(req_b, now, fetcher)
  let _ = cache.get_or_validate(req_c, now, fetcher)
  inspect(calls[0], content="3")
  // a was evicted (oldest) → re-fetch on lookup.
  let _ = cache.get_or_validate(req_a, now, fetcher)
  inspect(calls[0], content="4")
}

///|
test "PreflightCache::get_or_validate: Access-Control-Max-Age is clamped to 7200s" {
  // Server claims Max-Age=86400 (Firefox cap, 24h). The clamp pulls
  // it back to 7200 (Chromium cap, 2h) so a malicious origin cannot
  // pin a permissive policy beyond 2 hours.
  let cache = PreflightCache::new()
  let req = PreflightRequest::{
    url: "https://api.other.com/clamp",
    origin: "https://example.com",
    method: "PUT",
    request_headers: ["x-token"],
  }
  let fetcher = fn(_r : PreflightRequest) -> @http_impl.HttpResponse {
    test_preflight_response(
      status=204,
      aca_origin="https://example.com",
      aca_methods="PUT",
      aca_headers="x-token",
      aca_max_age="86400",
    )
  }
  let now = fn() -> Double { 1000.0 }
  match cache.get_or_validate(req, now, fetcher) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("expected Ok, got Err: " + e)
  }
  // expires_at_seconds = now (1000) + clamped Max-Age (7200) = 8200,
  // not 1000 + 86400 = 87400.
  let key = req.origin +
    "|" +
    req.url +
    "|" +
    req.method +
    "|" +
    req.request_headers.join(",")
  match cache.entries.get(key) {
    Some(entry) => inspect(entry.expires_at_seconds, content="8200")
    None => fail("expected cache entry to exist")
  }
}

///|
test "PreflightCache::get_or_validate: cache miss past Max-Age (fetcher called twice)" {
  let cache = PreflightCache::new()
  let req = PreflightRequest::{
    url: "https://api.other.com/y",
    origin: "https://example.com",
    method: "PUT",
    request_headers: ["x-token"],
  }
  let calls : Array[Int] = [0]
  let fetcher = fn(_r : PreflightRequest) -> @http_impl.HttpResponse {
    calls[0] = calls[0] + 1
    test_preflight_response(
      status=204,
      aca_origin="https://example.com",
      aca_methods="PUT",
      aca_headers="x-token",
      aca_max_age="60",
    )
  }
  // Advance the clock past Max-Age between the two calls.
  let clock : Array[Double] = [1000.0]
  let now = fn() -> Double { clock[0] }
  match cache.get_or_validate(req, now, fetcher) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("first call expected Ok, got Err: " + e)
  }
  // 60s after first call → entry expires_at = 1060, now = 1100 ⇒ expired.
  clock[0] = 1100.0
  match cache.get_or_validate(req, now, fetcher) {
    Ok(_) => inspect(true, content="true")
    Err(e) => fail("second call expected Ok, got Err: " + e)
  }
  inspect(calls[0], content="2")
}
