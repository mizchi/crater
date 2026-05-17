///|
test "browser/http re-exports CORS surface" {
  let d = @http.classify_request(
    url="https://example.com/x",
    origin="https://example.com",
    mode=@http.RequestMode::Cors,
    method="GET",
    headers={},
  )
  inspect(d, content="Allow")
}
