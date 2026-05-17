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
