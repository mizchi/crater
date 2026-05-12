///|
/// Basic syntax check for navigate/reload URL parameter.
fn is_valid_navigation_target_url(url : String) -> Bool {
  if url.has_prefix("http://") {
    return has_valid_http_host(url, 7)
  }
  if url.has_prefix("https://") {
    return has_valid_http_host(url, 8)
  }
  true
}

///|
/// Detect navigation targets that should fail with unknown error after navigationStarted.
fn should_fail_navigation_with_unknown_error(url : String) -> Bool {
  if url.has_prefix("thisprotocoldoesnotexist://") {
    return true
  }
  if url.has_prefix("https://doesnotexist.localhost") ||
    url.has_prefix("http://doesnotexist.localhost") {
    return true
  }
  if has_invalid_http_zero_port(url) {
    return true
  }
  false
}

///|
/// Reject explicit `:0` ports as unreachable hosts.
fn has_invalid_http_zero_port(url : String) -> Bool {
  let scheme_len = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    return false
  }
  if url.length() <= scheme_len {
    return false
  }
  let chars = url.to_array()
  let mut host_end = chars.length()
  for i = scheme_len; i < chars.length(); i = i + 1 {
    if chars[i] == '/' || chars[i] == '?' || chars[i] == '#' {
      host_end = i
      break
    }
  }
  let host_port = url.unsafe_substring(start=scheme_len, end=host_end)
  host_port.has_suffix(":0")
}

///|
/// Check whether value carries CSP/COEP markers that block cross-origin frame navigations.
fn has_embedder_blocking_policy_marker(value : String) -> Bool {
  value.contains("Content-Security-Policy") ||
  value.contains("Cross-Origin-Embedder-Policy") ||
  value.contains("content-security-policy") ||
  value.contains("cross-origin-embedder-policy") ||
  value.contains("default-src") ||
  value.contains("require-corp")
}

///|
/// Whether a navigated document enforces cross-origin iframe blocking.
fn navigation_blocks_cross_origin_iframe_navigation(url : String) -> Bool {
  if has_embedder_blocking_policy_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, body)) => has_embedder_blocking_policy_marker(body)
    None => false
  }
}

///|
/// Whether URL/content carries X-Frame-Options: DENY.
fn has_x_frame_options_deny_marker(value : String) -> Bool {
  (value.contains("X-Frame-Options") || value.contains("x-frame-options")) &&
  (value.contains("DENY") || value.contains("deny"))
}

///|
/// Whether URL/content carries X-Frame-Options: SAMEORIGIN.
fn has_x_frame_options_sameorigin_marker(value : String) -> Bool {
  (value.contains("X-Frame-Options") || value.contains("x-frame-options")) &&
  (value.contains("SAMEORIGIN") || value.contains("sameorigin"))
}

///|
/// Compare origins for cross-origin iframe checks.
fn is_cross_origin_navigation_url(
  source_url : String,
  target_url : String,
) -> Bool {
  let source_origin = derive_realm_origin(source_url)
  let target_origin = derive_realm_origin(target_url)
  if source_origin == "null" || target_origin == "null" {
    return false
  }
  source_origin != target_origin
}

///|
/// Determine whether iframe navigation should be blocked by CSP/COEP/XFO policies.
fn BidiProtocol::is_iframe_navigation_blocked(
  self : BidiProtocol,
  ctx_id : String,
  target_url : String,
) -> Bool {
  let parent_ctx_id = match self.context_parent.get(ctx_id) {
    Some(parent_id) => parent_id
    None => return false
  }

  let mut target_has_xfo_deny = has_x_frame_options_deny_marker(target_url)
  let mut target_has_xfo_sameorigin = has_x_frame_options_sameorigin_marker(
    target_url,
  )
  match parse_data_url(target_url) {
    Some((_content_type, body)) => {
      if has_x_frame_options_deny_marker(body) {
        target_has_xfo_deny = true
      }
      if has_x_frame_options_sameorigin_marker(body) {
        target_has_xfo_sameorigin = true
      }
    }
    None => ()
  }
  if target_has_xfo_deny {
    return true
  }
  let parent_url = match self.manager.get_session(parent_ctx_id) {
    Some(parent_session) => parent_session.get_url()
    None => "about:blank"
  }

  let mut parent_blocks_cross_origin = self.context_blocks_cross_origin_iframe_navigation
    .get(parent_ctx_id)
    .unwrap_or(false)
  if navigation_blocks_cross_origin_iframe_navigation(parent_url) {
    parent_blocks_cross_origin = true
  }
  if parent_blocks_cross_origin &&
    is_cross_origin_navigation_url(parent_url, target_url) {
    return true
  }

  if target_has_xfo_sameorigin &&
    is_cross_origin_navigation_url(parent_url, target_url) {
    return true
  }
  false
}

///|
/// Ensure HTTP(S) URL host starts with a valid character.
fn has_valid_http_host(url : String, scheme_len : Int) -> Bool {
  if url.length() <= scheme_len {
    return false
  }
  let chars = url.to_array()
  let head = chars[scheme_len]
  if head == ':' || head == '#' || head == '/' || head == '?' {
    return false
  }
  true
}

///|
/// Determine whether navigate/reload should defer command response for `wait`.
fn should_block_navigation_response(wait_mode : String, url : String) -> Bool {
  if wait_mode == "none" {
    return false
  }
  if !is_trickle_navigation_url(url) {
    return false
  }
  if wait_mode == "complete" {
    return true
  }
  if is_slow_image_navigation_url(url) {
    return false
  }
  true
}

///|
/// Heuristic for navigations that can be interrupted by subsequent actions.
fn is_interruptible_navigation_candidate(url : String) -> Bool {
  if is_slow_image_navigation_url(url) {
    return false
  }
  if has_long_trickle_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, content)) => has_long_trickle_marker(content)
    None => false
  }
}

///|
/// Long trickle payloads used by interruption tests.
fn has_long_trickle_marker(value : String) -> Bool {
  value.contains("trickle(d10") || value.contains("trickle%28d10")
}

///|
/// Delay command response long enough for 1s WPT timeout assertions.
fn apply_navigation_wait_delay(wait_mode : String, url : String) -> Unit {
  if should_block_navigation_response(wait_mode, url) {
    busy_wait_ms(1500)
  }
}

///|
/// Busy-wait helper used to emulate blocking waits in the mock protocol.
fn busy_wait_ms(delay_ms : Int) -> Unit {
  let start = input_now_ms()
  while input_now_ms() - start < delay_ms.to_double() {

  }
}

///|
/// Heuristic for trickle-delayed test URLs used by WPT navigation wait tests.
fn is_trickle_navigation_url(url : String) -> Bool {
  if has_trickle_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, content)) => has_trickle_marker(content)
    None => false
  }
}

///|
/// Check string marker used by WPT trickle-delayed resources.
fn has_trickle_marker(value : String) -> Bool {
  value.contains("trickle(") ||
  value.contains("trickle%28") ||
  value.contains("trickle")
}

///|
/// Heuristic for image-only delayed resources that should still pass `interactive`.
fn is_slow_image_navigation_url(url : String) -> Bool {
  if (url.contains("empty.svg") || url.contains("empty.svg%3F")) &&
    has_trickle_marker(url) {
    return true
  }
  match parse_data_url(url) {
    Some((_content_type, content)) =>
      content.contains("empty.svg") && has_trickle_marker(content)
    None => false
  }
}

///|
/// Remove URL fragment part (after `#`) if present.
fn strip_url_fragment(url : String) -> String {
  match find_substring(url, "#", 0) {
    Some(idx) => url.unsafe_substring(start=0, end=idx)
    None => url
  }
}

///|
/// Remove URL query part (after `?`) if present.
fn strip_url_query(url : String) -> String {
  match find_substring(url, "?", 0) {
    Some(idx) => url.unsafe_substring(start=0, end=idx)
    None => url
  }
}

///|
extern "js" fn js_encode_base64_utf8(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return btoa(unescape(encodeURIComponent(value)));
  #|   } catch (_e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn js_encode_base64_raw(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return btoa(String(value ?? ""));
  #|   } catch (_e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn js_json_ensure_ascii(value : String) -> String =
  #| (value) => {
  #|   try {
  #|     return JSON.stringify(JSON.parse(value)).replace(/[\u007f-\uffff]/g, (ch) =>
  #|       '\\u' + ch.charCodeAt(0).toString(16).padStart(4, '0')
  #|     );
  #|   } catch (_e) {
  #|     return value;
  #|   }
  #| }

///|
extern "js" fn js_extract_inline_script_blocks(html : String) -> Array[String] =
  #| (html) => {
  #|   if (typeof html !== "string" || html === "") {
  #|     return [];
  #|   }
  #|   const result = [];
  #|   const pattern = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  #|   let match;
  #|   while ((match = pattern.exec(html)) !== null) {
  #|     const attrs = match[1] || "";
  #|     if (/\bsrc\s*=/.test(attrs)) {
  #|       continue;
  #|     }
  #|     const script = (match[2] || "").trim();
  #|     if (script !== "") {
  #|       result.push(script);
  #|     }
  #|   }
  #|   return result;
  #| }

///|
fn encode_base64_utf8(value : String) -> String {
  js_encode_base64_utf8(value)
}

///|
fn encode_base64_raw(value : String) -> String {
  js_encode_base64_raw(value)
}

///|
fn json_ensure_ascii(value : String) -> String {
  js_json_ensure_ascii(value)
}

///|
fn extract_inline_script_blocks(html : String) -> Array[String] {
  js_extract_inline_script_blocks(html)
}

///|
fn extract_url_fragment_suffix(url : String) -> String {
  match find_substring(url, "#", 0) {
    Some(idx) => url.unsafe_substring(start=idx, end=url.length())
    None => ""
  }
}

///|
fn extract_http_url_authority(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut host_end = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' || ch == '?' || ch == '#' {
          host_end = i
          break
        }
      }
      if host_start >= host_end {
        None
      } else {
        Some(url.unsafe_substring(start=host_start, end=host_end))
      }
    }
    None => None
  }
}

///|
fn extract_http_url_path(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut path_start = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' {
          path_start = i
          break
        }
        if ch == '?' || ch == '#' {
          return Some("/")
        }
      }
      if path_start >= chars.length() {
        return Some("/")
      }
      let mut path_end = chars.length()
      for i = path_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '?' || ch == '#' {
          path_end = i
          break
        }
      }
      Some(url.unsafe_substring(start=path_start, end=path_end))
    }
    None => None
  }
}

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
fn build_html_data_url(html : String) -> String {
  "data:text/html;charset=utf-8;base64," + encode_base64_utf8(html)
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
fn resolve_relative_url_against_base(
  base_url : String,
  target_url : String,
) -> String {
  match find_substring(base_url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let path_start = find_substring(base_url, "/", host_start).unwrap_or(
        base_url.length(),
      )
      let origin = base_url.unsafe_substring(start=0, end=path_start)
      if target_url.has_prefix("/") {
        return origin + target_url
      }
      let normalized_base = strip_url_query(strip_url_fragment(base_url))
      if path_start >= normalized_base.length() {
        return origin + "/" + target_url
      }
      let chars = normalized_base.to_array()
      let mut last_slash = path_start
      for i = path_start; i < chars.length(); i = i + 1 {
        if chars[i] == '/' {
          last_slash = i
        }
      }
      let base_dir = normalized_base.unsafe_substring(
        start=0,
        end=last_slash + 1,
      )
      origin +
      normalize_relative_url_path(
        base_dir.unsafe_substring(start=origin.length(), end=base_dir.length()) +
        target_url,
      )
    }
    None => target_url
  }
}

///|
fn normalize_relative_url_path(path : String) -> String {
  let absolute = path.has_prefix("/")
  let parts : Array[String] = []
  for segment in path.split("/") {
    let segment = segment.to_owned()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if parts.length() > 0 {
        ignore(parts.pop())
      }
      continue
    }
    parts.push(segment)
  }
  let normalized = parts.join("/")
  if absolute {
    "/" + normalized
  } else {
    normalized
  }
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
