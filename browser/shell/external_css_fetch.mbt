///|
/// Wrapper to adapt @http.fetch (which has optional params) to the
/// async fetcher signature expected by cached_fetch_async.
async fn http_fetch_adapter(
  url : String,
  options : @http.FetchOptions,
) -> @http.HttpResponse raise @http.HttpError {
  @http.fetch(url, options~)
}

///|
/// Fetch external stylesheets and return CSS array
async fn fetch_external_css(
  html : String,
  base_url : String,
  sandbox : @http.RequestSandbox,
  cache : @http_cache.MemoryCacheBackend,
) -> Array[String] {
  // Use lightweight extraction instead of full DOM parsing
  let stylesheet_links = @html.extract_stylesheet_links(html)
  let link_count = stylesheet_links.length()
  if link_count == 0 {
    return []
  }
  println("Found " + link_count.to_string() + " external stylesheets")
  // Fetch all external CSS
  let css_contents : Array[String] = []
  for link in stylesheet_links {
    let css_url = resolve_url(base_url, link)
    println("Fetching CSS: " + css_url)
    // Try to fetch CSS with cache, ignore errors
    try {
      let options = {
        ..@http.FetchOptions::default(),
        mode: @http.RequestMode::NoCors,
        origin: base_url,
        sandbox,
      }
      let response = @http_cache.cached_fetch_async(
        url=css_url,
        options~,
        cache~,
        fetcher=http_fetch_adapter,
      )
      css_contents.push(response.body)
      println("  -> OK (" + response.body.length().to_string() + " bytes)")
    } catch {
      err => println("  -> Error: " + err.to_string())
    }
  }
  println("Loaded " + css_contents.length().to_string() + " stylesheets")
  // Analyze CSS support
  @browser_helpers.report_css_support(css_contents)
  css_contents
}
