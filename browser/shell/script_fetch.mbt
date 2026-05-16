///|
async fn Browser::fetch_external_script_source(
  self : Browser,
  src : String,
) -> String? {
  let script_url = resolve_url(self.current_url, src)
  if script_url.length() == 0 {
    println("  [SKIP] Invalid script URL: " + src)
    return None
  }
  println("  [FETCH] External script: " + script_url)
  try {
    let script_options = {
      ..@http.FetchOptions::default(),
      mode: @http.RequestMode::NoCors,
      origin: self.current_url,
      sandbox: self.request_sandbox,
    }
    let response = @http_cache.cached_fetch_async(
      url=script_url,
      options=script_options,
      cache=self.http_cache,
      fetcher=http_fetch_adapter,
    )
    println("    -> OK (" + response.body.length().to_string() + " bytes)")
    Some(response.body)
  } catch {
    err => {
      println("    -> Error: " + err.to_string())
      None
    }
  }
}
