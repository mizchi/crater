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
