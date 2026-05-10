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
