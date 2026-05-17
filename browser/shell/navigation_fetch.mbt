///|
async fn Browser::fetch_navigation_document(
  self : Browser,
  source_url : String,
  request : NavigationRequest,
) -> @http.HttpResponse raise @http.HttpError {
  let url = request.url
  let page_headers : Map[String, String] = {}
  let is_secure = url.has_prefix("https://")
  match
    self.profile.cookie_jar.get_cookie_header(
      url,
      is_secure,
      true,
      site_origin=source_url,
      is_top_level_navigation=true,
    ) {
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
