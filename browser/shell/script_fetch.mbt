///|
/// Async fetcher signature used by the CORS gate. The actual network
/// roundtrip is driven by the caller-supplied closure, which may
/// either dispatch a real fetch (in the live path) or return a canned
/// response (in wbtests).
type ResponseFetcher = async (String, @http.FetchOptions) -> @http.HttpResponse raise @http.HttpError

///|
/// Sync OPTIONS preflight fetcher. The PreflightCache invokes this on
/// cache miss / expiry, never on a fresh hit. The cache contract is
/// sync (see `@http_cors.PreflightCache::get_or_validate`), so the
/// live wiring captures a `now`-bounded sync surface: a real network
/// preflight runs as an `async` call that the closure awaits before
/// returning the synthetic response.
type PreflightFetcher = (@http_cors.PreflightRequest) -> @http.HttpResponse

///|
/// Run a subresource fetch through the CORS gate:
///
/// 1. `@http_cors.classify_request` → Allow / PreflightRequired / Blocked.
/// 2. If `Blocked`, raise `CorsBlocked` without touching the network.
/// 3. If `PreflightRequired`, ask `cache.get_or_validate` to either
///    reuse a fresh entry or invoke `preflight_fetcher` once. A
///    preflight validation failure raises `PreflightFailed`.
/// 4. Dispatch the actual request via `fetcher`.
/// 5. Run `@http_cors.validate_actual_response` on the response and
///    raise `CorsBlocked` on Err. Same-origin responses skip the check
///    (the validator returns Ok early in that case).
///
/// Tests drive this seam directly by passing closures that return
/// canned `HttpResponse` values — no real network I/O required.
async fn script_fetch_with_cors(
  url~ : String,
  options~ : @http.FetchOptions,
  preflight_cache~ : @http_cors.PreflightCache,
  now~ : () -> Double,
  preflight_fetcher~ : PreflightFetcher,
  fetcher~ : ResponseFetcher,
) -> @http.HttpResponse raise @http.HttpError {
  let decision = @http_cors.classify_request(
    url~,
    origin=options.origin,
    mode=options.mode,
    method=options.http_method,
    headers=options.headers,
  )
  match decision {
    Blocked(reason) => raise @http.HttpError::CorsBlocked(reason)
    PreflightRequired(preflight_req) =>
      match
        preflight_cache.get_or_validate(preflight_req, now, preflight_fetcher) {
        Err(msg) => raise @http.HttpError::PreflightFailed(msg)
        Ok(_) => ()
      }
    Allow => ()
  }
  let response = fetcher(url, options)
  // NoCors responses are opaque per Fetch spec: the script tag can
  // still execute the body, but the page can't read it. We skip
  // validate_actual_response in that mode — the validator assumes a
  // CORS-mode request and would otherwise block every cross-origin
  // <script src> that doesn't echo ACA-Origin (which is the majority).
  if options.mode == @http.RequestMode::NoCors {
    return response
  }
  match
    @http_cors.validate_actual_response(
      request_url=url,
      origin=options.origin,
      credentials=options.credentials,
      response~,
    ) {
    Err(msg) => raise @http.HttpError::CorsBlocked(msg)
    Ok(_) => response
  }
}

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
  let script_options = {
    ..@http.FetchOptions::default(),
    mode: @http.RequestMode::NoCors,
    origin: self.current_url,
    sandbox: self.request_sandbox,
  }
  // Stash the cache and preflight cache up front so the closures below
  // can reference them without re-resolving through `self`.
  let cache = self.profile.http_cache
  let preflight_cache = self.profile.preflight_cache
  // The actual fetcher wires the response path through the HTTP cache.
  // The async hop is inside this closure; the gate calls it exactly
  // once after the preflight step decides the request can proceed.
  let fetcher = async fn(
    u : String,
    o : @http.FetchOptions,
  ) -> @http.HttpResponse raise @http.HttpError {
    @http_cache.cached_fetch_async(
      url=u,
      options=o,
      cache~,
      fetcher=http_fetch_adapter,
    )
  }
  // PreflightCache::get_or_validate wants a sync fetcher, but the live
  // OPTIONS roundtrip is async. So we pre-fetch the preflight response
  // up front (only when classify_request asks for one — see below) and
  // hand the cache a closure that returns the captured response. The
  // mutable slot lets the closure see whatever the async hop produced.
  let captured_preflight : Ref[@http.HttpResponse?] = { val: None }
  let preflight_fetcher = fn(
    _req : @http_cors.PreflightRequest,
  ) -> @http.HttpResponse {
    match captured_preflight.val {
      Some(resp) => resp
      // Defensive: this path runs only when caller forgot to pre-fetch.
      // 0-status forces the validator to raise PreflightFailed with a
      // "missing ACA-Origin" message rather than silently allowing.
      None => { status: 0, headers: {}, body: "" }
    }
  }
  // Mirror classify_request's decision once to decide whether to
  // dispatch the OPTIONS preflight before script_fetch_with_cors
  // consults the cache. classify_request is pure / cheap, so doing it
  // twice (here and inside the gate) is fine; the alternative would be
  // pushing async into the cache contract, which lives in http/cors/.
  // We pre-fetch only when the cache lookup misses, so a cached entry
  // skips the redundant OPTIONS roundtrip.
  let pre_decision = @http_cors.classify_request(
    url=script_url,
    origin=script_options.origin,
    mode=script_options.mode,
    method=script_options.http_method,
    headers=script_options.headers,
  )
  match pre_decision {
    PreflightRequired(preflight_req) =>
      if !preflight_cache.contains_fresh(preflight_req, @http_cache.now_seconds) {
        let headers : Map[String, String] = {
          "Access-Control-Request-Method": preflight_req.method,
        }
        if !preflight_req.request_headers.is_empty() {
          headers["Access-Control-Request-Headers"] = preflight_req.request_headers.join(
            ",",
          )
        }
        let opts = {
          ..@http.FetchOptions::default(),
          http_method: "OPTIONS",
          headers,
          mode: @http.RequestMode::Cors,
          origin: preflight_req.origin,
        }
        try {
          captured_preflight.val = Some(
            @http.fetch(preflight_req.url, options=opts),
          )
        } catch {
          _ =>
            captured_preflight.val = Some({ status: 0, headers: {}, body: "" })
        }
      }
    _ => ()
  }
  try {
    let response = script_fetch_with_cors(
      url=script_url,
      options=script_options,
      preflight_cache~,
      now=@http_cache.now_seconds,
      preflight_fetcher~,
      fetcher~,
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
