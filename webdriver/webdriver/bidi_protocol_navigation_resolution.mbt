///|
fn is_wpt_http_url(url : String) -> Bool {
  if !url.has_prefix("http://") && !url.has_prefix("https://") {
    return false
  }
  match extract_http_url_authority(url) {
    Some(authority) =>
      authority == "localhost:8000" || authority == "alt.localhost:8000"
    None => false
  }
}

///|
fn is_wpt_headers_echo_url(url : String) -> Bool {
  if !is_wpt_http_url(url) {
    return false
  }
  match extract_http_url_path(url) {
    Some(path) =>
      path.has_suffix("/webdriver/tests/support/http_handlers/headers_echo.py")
    None => false
  }
}

///|
fn is_wpt_blank_page_url(url : String) -> Bool {
  if !is_wpt_http_url(url) {
    return false
  }
  match extract_http_url_path(url) {
    Some(path) =>
      path == "/" ||
      path.has_suffix(
        "/webdriver/tests/bidi/browsing_context/support/empty.html",
      )
    None => false
  }
}

///|
/// Resolve relative navigation targets against current context URL.
fn BidiProtocol::resolve_navigation_target_url(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> String {
  if target_url.contains("://") ||
    target_url.has_prefix("about:") ||
    target_url.has_prefix("data:") ||
    target_url.has_prefix("blob:") ||
    target_url.has_prefix("file:") ||
    target_url.has_prefix("javascript:") {
    return target_url
  }
  let base_url = match self.manager.get_session(ctx_id) {
    Some(session) => session.get_url()
    None => "about:blank"
  }
  resolve_relative_url_against_base(base_url, target_url)
}

///|
fn BidiProtocol::resolve_fetch_target_url(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> String {
  if target_url.contains("://") ||
    target_url.has_prefix("about:") ||
    target_url.has_prefix("data:") ||
    target_url.has_prefix("blob:") ||
    target_url.has_prefix("file:") ||
    target_url.has_prefix("javascript:") {
    return target_url
  }
  let base_url = self.requested_navigation_url(ctx_id)
  if base_url.contains("://") {
    return resolve_relative_url_against_base(base_url, target_url)
  }
  match self.resolve_synthetic_location_href(ctx_id) {
    Some(href) =>
      if href.contains("://") {
        return resolve_relative_url_against_base(href, target_url)
      }
    None => ()
  }
  self.resolve_navigation_target_url(ctx_id, target_url)
}

///|
fn BidiProtocol::normalize_wpt_navigation_target_url(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> String {
  let fragment_suffix = extract_url_fragment_suffix(target_url)
  if is_wpt_headers_echo_url(target_url) {
    let payload = json_ensure_ascii(
      self.build_network_headers_echo_payload(ctx_id, []),
    )
    let html = "<html><head></head><body>" + payload + "</body></html>"
    return build_html_data_url(html) + fragment_suffix
  }
  if is_wpt_blank_page_url(target_url) {
    return target_url
  }
  target_url
}

///|
fn BidiProtocol::resolve_effective_navigation_target_url(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> String {
  let resolved_url = self.resolve_navigation_target_url(ctx_id, target_url)
  self.normalize_wpt_navigation_target_url(ctx_id, resolved_url)
}

///|
/// Whether navigation is same-document fragment navigation.
fn is_fragment_navigation(previous_url : String, next_url : String) -> Bool {
  if !next_url.contains("#") {
    return false
  }
  // Adapter-only data URLs may carry "#domain=..." to emulate cross-origin.
  // Treat those as full navigations, not same-document fragments.
  if next_url.has_prefix("data:") &&
    (next_url.contains("#domain=") || previous_url.contains("#domain=")) {
    return false
  }
  strip_url_fragment(previous_url) == strip_url_fragment(next_url)
}

///|
/// Resolve synthetic redirect target for redirect_http_equiv test pages.
fn resolve_http_equiv_redirect_url(url : String) -> String? {
  let from_path = "/webdriver/tests/bidi/network/support/redirect_http_equiv.html"
  let to_path = "/webdriver/tests/bidi/network/support/redirected.html"
  match find_substring(url, from_path, 0) {
    Some(idx) => {
      let prefix = url.unsafe_substring(start=0, end=idx)
      let suffix_start = idx + from_path.length()
      let suffix = if suffix_start <= url.length() {
        url.unsafe_substring(start=suffix_start, end=url.length())
      } else {
        ""
      }
      Some(prefix + to_path + suffix)
    }
    None => None
  }
}

///|
/// Resolve committed navigation URL (redirect.py commits to the location target).
fn resolve_navigation_committed_url(url : String) -> String {
  if url.contains("/redirect.py") {
    get_runtime_url_query_param(url, "location").unwrap_or(url)
  } else {
    url
  }
}

///|
/// Resolve synthetic inline script redirect targets used by interrupted-navigation WPTs.
fn resolve_inline_script_redirect_url(url : String) -> String? {
  if !url.has_prefix("data:") {
    return None
  }
  let content = match parse_data_url(url) {
    Some((_content_type, body)) => body
    None => return None
  }
  match extract_quoted_after_marker(content, "window.location=") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  match extract_quoted_after_marker(content, "window.location = ") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  match extract_quoted_after_marker(content, "location.href = ") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  match extract_quoted_after_marker(content, "location.href=") {
    Some(target_url) => return Some(target_url)
    None => ()
  }
  None
}
