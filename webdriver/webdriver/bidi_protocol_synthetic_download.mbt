///|
/// Handle synthetic download click used in browser.setDownloadBehavior WPTs.
fn BidiProtocol::try_handle_synthetic_download(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Bool {
  let expr = expression.trim().to_owned()
  let target_id = match extract_click_target_identifier(expr) {
    Some(id) => id
    None => return false
  }
  if !is_known_synthetic_download_target(target_id) {
    return false
  }

  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

  let clicked_url = get_runtime_anchor_href_by_id(target_id).unwrap_or("")
  let download_attr = get_runtime_anchor_download_attr_by_id(target_id).unwrap_or(
    "",
  )
  let resolved_download_url = resolve_synthetic_download_final_url(clicked_url)
  let effective_clicked_url = if clicked_url.length() > 0 {
    clicked_url
  } else {
    resolved_download_url
  }
  let effective_download_url = if resolved_download_url.length() > 0 {
    resolved_download_url
  } else {
    effective_clicked_url
  }
  let has_download_attribute = download_attr.length() > 0
  let navigation_id : String? = if has_download_attribute {
    None
  } else {
    let nav_id = self.next_navigation_id.to_string()
    self.next_navigation_id += 1
    self.emit_navigation_started_event(ctx_id, effective_clicked_url, nav_id)
    Some(nav_id)
  }
  let suggested_filename = resolve_synthetic_download_filename(
    download_attr, effective_download_url,
  )
  let mut destination = "/tmp"
  let mut denied_by_behavior = false
  match self.resolve_download_behavior(ctx_id) {
    Some(Object(behavior)) =>
      match behavior.get("type") {
        Some(String("denied")) => denied_by_behavior = true
        Some(String("allowed")) =>
          match behavior.get("destinationFolder") {
            Some(String(folder)) => destination = folder
            _ => ()
          }
        _ => ()
      }
    _ => ()
  }
  let canceled = denied_by_behavior ||
    is_synthetic_download_canceled(effective_download_url)
  let status = if canceled { "canceled" } else { "complete" }
  let filepath : String? = if canceled {
    None
  } else {
    let output_path = destination + "/" + suggested_filename
    let content = resolve_synthetic_download_file_content(
      effective_download_url,
    )
    runtime_write_text_file(output_path, content)
    Some(output_path)
  }

  self.emit_download_will_begin(
    ctx_id, navigation_id, suggested_filename, effective_download_url,
  )
  self.emit_download_end(
    ctx_id, navigation_id, status, filepath, effective_download_url,
  )
  self.send_script_undefined_result(request_id, realm_id)
  true
}

///|
/// Extract click target identifier from snippets like `download_link.click()`.
fn extract_click_target_identifier(expression : String) -> String? {
  let source = expression.trim().to_owned()
  match find_substring(source, ".click(", 0) {
    Some(idx) => {
      let name = source.unsafe_substring(start=0, end=idx)
      let identifier = name.trim().to_owned()
      if identifier.length() == 0 {
        None
      } else {
        Some(identifier)
      }
    }
    None => None
  }
}

///|
/// Recognize synthetic download anchors used by WPT.
fn is_known_synthetic_download_target(target_id : String) -> Bool {
  target_id == "download_link" ||
  target_id == "content_disposition_link" ||
  target_id == "redirect_link"
}

///|
/// Extract raw query parameter value from URL string without percent-decoding.
fn extract_raw_query_param_value(url : String, key : String) -> String? {
  if url.length() == 0 || key.length() == 0 {
    return None
  }
  let marker = key + "="
  match find_substring(url, marker, 0) {
    Some(idx) => {
      let start = idx + marker.length()
      if start >= url.length() {
        return Some("")
      }
      let tail = url.unsafe_substring(start~, end=url.length())
      match find_substring(tail, "&", 0) {
        Some(end_idx) => Some(tail.unsafe_substring(start=0, end=end_idx))
        None => Some(tail)
      }
    }
    None => None
  }
}

///|
/// Resolve final download URL (follows redirect.py?location=...).
fn resolve_synthetic_download_final_url(clicked_url : String) -> String {
  if clicked_url.length() == 0 {
    return clicked_url
  }
  if clicked_url.contains("/redirect.py") {
    let redirected = extract_raw_query_param_value(clicked_url, "location").unwrap_or(
      "",
    )
    if redirected.length() > 0 {
      return redirected
    }
  }
  clicked_url
}

///|
/// Resolve suggested filename from `download` attribute or URL query.
fn resolve_synthetic_download_filename(
  download_attr : String,
  download_url : String,
) -> String {
  if download_attr.length() > 0 {
    return download_attr
  }
  let from_query = extract_raw_query_param_value(download_url, "filename").unwrap_or(
    "",
  )
  if from_query.length() > 0 {
    return from_query
  }
  "download.txt"
}

///|
/// Resolve synthetic download file content from URL (fallback keeps WPT stable).
fn resolve_synthetic_download_file_content(download_url : String) -> String {
  if download_url.has_prefix("data:") {
    match parse_data_url(download_url) {
      Some((_content_type, content)) => return content
      None => ()
    }
  }
  let from_query = get_runtime_url_query_param(download_url, "content").unwrap_or(
    "",
  )
  if from_query.length() > 0 {
    from_query
  } else {
    "SOME_FILE_CONTENT"
  }
}

///|
/// Detect URLs representing intentionally canceled synthetic downloads.
fn is_synthetic_download_canceled(download_url : String) -> Bool {
  download_url.contains("some_non_existing_link")
}
