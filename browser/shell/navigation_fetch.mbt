///|
/// Compute the `Cookie` header for a top-level navigation request,
/// filtering each candidate cookie through the SameSite policy
/// (`is_top_level_navigation=true`, matching
/// `@http.should_attach_cookie`'s top-level branch). `source_url` is the
/// origin of the page initiating the navigation; an empty string means
/// "same-site" and disables cross-site enforcement.
///
/// This is the single seam that the navigation path uses to decide
/// cookie attach. Subresource fetches (script_fetch / external_css_fetch)
/// have their own helper (TBD in later tasks) so the two contexts can
/// differ in `is_top_level_navigation` independently.
fn navigation_cookie_header(
  jar : @http_cookie_jar.CookieJar,
  source_url : String,
  target_url : String,
) -> String? {
  let is_secure = target_url.has_prefix("https://")
  jar.get_cookie_header(
    target_url,
    is_secure,
    true,
    site_origin=source_url,
    is_top_level_navigation=true,
  )
}

///|
async fn Browser::fetch_navigation_document(
  self : Browser,
  source_url : String,
  request : NavigationRequest,
) -> @http.HttpResponse raise @http.HttpError {
  let url = request.url
  let page_headers : Map[String, String] = {}
  let is_secure = url.has_prefix("https://")
  match navigation_cookie_header(self.profile.cookie_jar, source_url, url) {
    Some(cookie_header) => page_headers["Cookie"] = cookie_header
    None => ()
  }
  if request.content_type.length() > 0 {
    page_headers["Content-Type"] = request.content_type
  }
  let page_options = {
    ..@http.FetchOptions::default(),
    headers: page_headers,
    http_method: request.http_method,
    body: request.body,
    mode: @http.RequestMode::Navigate,
    origin: source_url,
    sandbox: self.request_sandbox,
  }
  let response = @http.fetch(url, options=page_options)
  match response.headers.get("set-cookie") {
    Some(sc) => self.profile.cookie_jar.store_from_header(sc, url, is_secure)
    None => ()
  }
  response
}

///|
async fn Browser::fetch_lightweight_navigation_document(
  self : Browser,
  source_url : String,
  url : String,
) -> @http.HttpResponse raise @http.HttpError {
  let page_options = {
    ..@http.FetchOptions::default(),
    mode: @http.RequestMode::Navigate,
    origin: source_url,
    sandbox: self.request_sandbox,
  }
  @http.fetch(url, options=page_options)
}
