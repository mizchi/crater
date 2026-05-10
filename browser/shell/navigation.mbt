///|
/// Resolve relative URL to absolute
fn resolve_url(base_url : String, href : String) -> String {
  // Skip empty, fragment-only, or javascript URLs
  if href.length() == 0 ||
    href.has_prefix("#") ||
    href.has_prefix("javascript:") ||
    href.has_prefix("mailto:") ||
    href.has_prefix("tel:") {
    return ""
  }
  // Already absolute
  if href.has_prefix("http://") || href.has_prefix("https://") {
    return href
  }
  if href.has_prefix("data:") ||
    href.has_prefix("about:") ||
    href.has_prefix("blob:") ||
    href.has_prefix("file:") {
    return href
  }
  // Protocol-relative
  if href.has_prefix("//") {
    let protocol = if base_url.has_prefix("https://") {
      "https:"
    } else {
      "http:"
    }
    return protocol + href
  }
  // Extract base from URL
  let protocol_end = match base_url.find("://") {
    Some(i) => i
    None => return href
  }
  let after_protocol = base_url.unsafe_substring(
    start=protocol_end + 3,
    end=base_url.length(),
  )
  let path_start = after_protocol.find("/")
  let origin = match path_start {
    Some(i) => base_url.unsafe_substring(start=0, end=protocol_end + 3 + i)
    None => base_url
  }
  // Root-relative
  if href.has_prefix("/") {
    return origin + href
  }
  // Relative - append to current path
  let last_slash = base_url.rev_find("/")
  match last_slash {
    Some(i) if i > protocol_end + 2 =>
      base_url.unsafe_substring(start=0, end=i + 1) + href
    _ => origin + "/" + href
  }
}

///|
fn make_substr(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn hex_digit_to_int(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn percent_decode_data_url_payload(payload : String) -> String {
  let chars = payload.to_array()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '%' && i + 2 < chars.length() {
      match (hex_digit_to_int(chars[i + 1]), hex_digit_to_int(chars[i + 2])) {
        (Some(high), Some(low)) => {
          buf.write_char((high * 16 + low).unsafe_to_char())
          i = i + 3
        }
        _ => {
          buf.write_char(chars[i])
          i = i + 1
        }
      }
    } else {
      buf.write_char(chars[i])
      i = i + 1
    }
  }
  buf.to_string()
}

///|
fn decode_sync_navigable_html_url(url : String) -> String? {
  if url == "about:blank" {
    return Some("")
  }
  if !url.has_prefix("data:") {
    return None
  }
  let chars = url.to_array()
  let mut comma_idx = -1
  for i = 5; i < chars.length(); i = i + 1 {
    if chars[i] == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  let header = make_substr(chars, 5, comma_idx)
  if header.contains(";base64") {
    return None
  }
  let mut payload_end = chars.length()
  for i = comma_idx + 1; i < chars.length(); i = i + 1 {
    if chars[i] == '?' || chars[i] == '#' {
      payload_end = i
      break
    }
  }
  let payload = make_substr(chars, comma_idx + 1, payload_end)
  Some(percent_decode_data_url_payload(payload))
}

///|
fn default_navigation_request(url : String) -> NavigationRequest {
  { url, http_method: "GET", content_type: "", body: "" }
}

///|
fn Browser::load_sync_navigable_html_request(
  self : Browser,
  request : NavigationRequest,
) -> Bool {
  match decode_sync_navigable_html_url(request.url) {
    Some(html) => {
      self.current_url = request.url
      self.last_navigation_request = Some(request)
      self.set_html_content(html)
      self.set_external_css([])
      let script_count = self.execute_scripts()
      if script_count > 0 {
        println(
          "Executed " +
          script_count.to_string() +
          " script(s) during sync page load",
        )
      }
      true
    }
    None => false
  }
}

///|
fn Browser::navigate_sync_if_supported(
  self : Browser,
  request : NavigationRequest,
) -> Bool {
  let previous_url = self.current_url
  let navigated = self.load_sync_navigable_html_request(request)
  if navigated {
    if previous_url.length() > 0 {
      self.back_history.push(previous_url)
    }
    self.forward_history.clear()
  }
  navigated
}

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
  cache : @http.MemoryCacheBackend,
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
      let response = @http.cached_fetch_async(
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
  @browser_contract.report_css_support(css_contents)
  css_contents
}

///|
/// Navigate to a URL and render (adds to back history, clears forward history)
pub async fn Browser::navigate(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  self.navigate_request(default_navigation_request(url))
}

///|
/// Navigate to URL in lightweight mode (for --json, --aom modes)
/// Skips CSS cascade and layout calculation to reduce memory usage
pub async fn Browser::navigate_lightweight(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  self.load_url_lightweight(url)
}

///|
/// Load a URL without adding to history (internal use)
async fn Browser::load_url(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  self.load_url_request(default_navigation_request(url))
}

///|
async fn Browser::navigate_request(
  self : Browser,
  request : NavigationRequest,
) -> String raise @http.HttpError {
  if self.current_url.length() > 0 {
    self.back_history.push(self.current_url)
  }
  self.forward_history.clear()
  self.load_url_request(request)
}

///|
async fn Browser::load_url_request(
  self : Browser,
  request : NavigationRequest,
) -> String raise @http.HttpError {
  let source_url = self.current_url
  let request_record = {
    url: request.url,
    http_method: request.http_method,
    content_type: request.content_type,
    body: request.body,
  }
  let url = request_record.url
  self.current_url = url
  self.last_navigation_request = Some(request_record)
  if url == "about:blank" || url.has_prefix("data:") {
    let _ = self.load_sync_navigable_html_request(request_record)
    return ""
  }
  let t0 = perf_now()
  // Fetch the page
  let page_headers : Map[String, String] = {}
  let is_secure = url.has_prefix("https://")
  match
    self.cookie_jar.get_cookie_header(
      url,
      is_secure,
      true,
      site_origin=source_url,
      is_top_level_navigation=true,
    ) {
    Some(cookie_header) => page_headers["Cookie"] = cookie_header
    None => ()
  }
  if request_record.content_type.length() > 0 {
    page_headers["Content-Type"] = request_record.content_type
  }
  let page_options = {
    ..@http.FetchOptions::default(),
    headers: page_headers,
    http_method: request_record.http_method,
    body: request_record.body,
    mode: @http.RequestMode::Navigate,
    origin: source_url,
    sandbox: self.request_sandbox,
  }
  let response = @http.fetch(url, options=page_options)
  // Process Set-Cookie from response
  match response.headers.get("set-cookie") {
    Some(sc) => self.cookie_jar.store_from_header(sc, url, is_secure)
    None => ()
  }
  self.source_html = response.body
  let has_declarative_shadow_dom = html_source_has_declarative_shadow_dom(
    response.body,
  )
  match
    normalize_declarative_shadow_source_html_with_hint(
      response.body,
      has_declarative_shadow_dom,
    ) {
    Some(normalized) => {
      self.html_content = normalized.render_html
      self.dom_snapshot_html = normalized.snapshot_html
      self.parsed_doc = Some(normalized.parsed_doc)
      self.html_has_declarative_shadow_dom = false
    }
    None => {
      self.html_content = response.body
      self.dom_snapshot_html = response.body
      self.parsed_doc = None
      self.html_has_declarative_shadow_dom = has_declarative_shadow_dom
    }
  }
  let t1 = perf_now()
  // Fetch external CSS using lightweight extraction (no full parsing)
  self.set_external_css(
    fetch_external_css(
      self.html_content,
      url,
      self.request_sandbox,
      self.http_cache,
    ) catch {
      _ => [] // Fallback to no external CSS on error
    },
  )
  let t2 = perf_now()
  self.focused_link = 0
  self.scroll_y = 0
  // Clear element scroll states on navigation
  self.clear_element_scroll_states()
  // Parse HTML using regular parser (streaming parser under investigation)
  match self.parsed_doc {
    Some(_) => ()
    None => {
      let doc = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(doc)
    }
  }
  self.refresh_links_from_render_source()
  self.clear_render_cache()
  let t3 = perf_now()
  // Execute scripts including external (JS execution)
  let script_count = self.execute_scripts_async() catch { _ => 0 }
  if script_count > 0 {
    println(
      "Executed " + script_count.to_string() + " script(s) during page load",
    )
  }
  let t4 = perf_now()
  // Content height is computed lazily from the layout tree in render_text()
  // to avoid a duplicate full layout pass here.
  self.content_height = 0
  // Accessibility tree is built lazily on first focus navigation
  // to avoid a duplicate full layout pass here.
  self.a11y_tree = None
  self.focus_manager = None
  // Prefetch images for kitty graphics rendering
  self.prefetch_images() catch {
    _ => ()
  }
  let t5 = perf_now()
  perf_log(
    "[perf] fetch=\{(t1 - t0).to_int()}ms css=\{(t2 - t1).to_int()}ms parse=\{(t3 - t2).to_int()}ms scripts=\{(t4 - t3).to_int()}ms images=\{(t5 - t4).to_int()}ms total=\{(t5 - t0).to_int()}ms",
  )
  // Render to Sixel
  self.render()
}

///|
/// Load a URL in lightweight mode (for --json, --aom modes)
/// Skips CSS cascade and layout calculation to reduce memory usage
async fn Browser::load_url_lightweight(
  self : Browser,
  url : String,
) -> String raise @http.HttpError {
  let source_url = self.current_url
  self.current_url = url
  // Fetch the page
  let page_options = {
    ..@http.FetchOptions::default(),
    mode: @http.RequestMode::Navigate,
    origin: source_url,
    sandbox: self.request_sandbox,
  }
  let response = @http.fetch(url, options=page_options)
  self.source_html = response.body
  let has_declarative_shadow_dom = html_source_has_declarative_shadow_dom(
    response.body,
  )
  match
    normalize_declarative_shadow_source_html_with_hint(
      response.body,
      has_declarative_shadow_dom,
    ) {
    Some(normalized) => {
      self.html_content = normalized.render_html
      self.dom_snapshot_html = normalized.snapshot_html
      self.parsed_doc = Some(normalized.parsed_doc)
      self.html_has_declarative_shadow_dom = false
    }
    None => {
      self.html_content = response.body
      self.dom_snapshot_html = response.body
      self.parsed_doc = None
      self.html_has_declarative_shadow_dom = has_declarative_shadow_dom
    }
  }
  // Skip external CSS fetching in lightweight mode
  self.set_external_css([])
  // Skip link extraction (not needed for JSON/AOM output)
  self.links = []
  self.focused_link = 0
  self.scroll_y = 0
  // Clear element scroll states on navigation
  self.clear_element_scroll_states()
  // Parse HTML using regular parser (streaming parser under investigation)
  match self.parsed_doc {
    Some(_) => ()
    None => {
      let doc = @html.assign_synthetic_ids(
        @html.parse_document(self.html_content),
      )
      self.parsed_doc = Some(doc)
    }
  }
  self.clear_render_cache()
  // Skip content height calculation in lightweight mode
  self.content_height = 0
  // Build lightweight accessibility tree (no CSS cascade, no layout)
  self.build_accessibility_tree_lightweight()
  // Return empty string (no rendering in lightweight mode)
  ""
}

///|
/// Go back to previous page in history and load it
pub async fn Browser::go_back(self : Browser) -> String? raise @http.HttpError {
  if self.back_history.length() == 0 {
    return None
  }
  // Save current URL to forward history
  if self.current_url.length() > 0 {
    self.forward_history.push(self.current_url)
  }
  let url = self.back_history.pop().unwrap()
  let _ = self.load_url(url)
  Some(url)
}

///|
/// Go forward to next page in history and load it
pub async fn Browser::go_forward(
  self : Browser,
) -> String? raise @http.HttpError {
  if self.forward_history.length() == 0 {
    return None
  }
  // Save current URL to back history
  if self.current_url.length() > 0 {
    self.back_history.push(self.current_url)
  }
  let url = self.forward_history.pop().unwrap()
  let _ = self.load_url(url)
  Some(url)
}
