///|
fn BidiProtocol::build_synthetic_fetch_request_plan(
  self : BidiProtocol,
  context_id : String,
  url : String,
  http_method : String,
  request_headers : Array[Json],
  request_value : Json?,
) -> Array[SyntheticFetchPlanEntry] {
  let requests : Array[SyntheticFetchPlanEntry] = []
  let actual_request_token = self.next_synthetic_network_request_id()
  if synthetic_fetch_requires_preflight(
      self.requested_navigation_url(context_id),
      url,
      http_method,
      request_headers,
    ) {
    requests.push({
      url,
      http_method: "OPTIONS",
      request_token: self.next_synthetic_network_request_id(),
      redirect_count: 0,
      request_value: None,
    })
  }
  requests.push({
    url,
    http_method,
    request_token: actual_request_token,
    redirect_count: 0,
    request_value,
  })

  let path = synthetic_network_request_path(url)
  let redirect_location = synthetic_network_first_query_value(url, "location")
  let redirect_status = synthetic_network_int_query_param(url, "status", 302)
  let should_follow_redirect = path.has_suffix("/redirect.py") ||
    (
      path.has_suffix("/cached.py") &&
      (
        redirect_status == 301 ||
        redirect_status == 302 ||
        redirect_status == 303 ||
        redirect_status == 307 ||
        redirect_status == 308
      )
    )
  if should_follow_redirect {
    match redirect_location {
      Some(redirect_url) if redirect_url != "" =>
        requests.push({
          url: redirect_url,
          http_method,
          request_token: actual_request_token,
          redirect_count: 1,
          request_value: None,
        })
      _ => ()
    }
  }
  requests
}

///|
fn synthetic_fetch_requires_preflight(
  source_url : String,
  target_url : String,
  http_method : String,
  request_headers : Array[Json],
) -> Bool {
  let source_origin = match canonicalize_network_http_url(source_url) {
    Some(source) => source
    None => return false
  }
  let target_origin = match canonicalize_network_http_url(target_url) {
    Some(target) => target
    None => return false
  }
  if source_origin.scheme == target_origin.scheme &&
    source_origin.host == target_origin.host &&
    source_origin.port == target_origin.port {
    return false
  }
  let method_upper = http_method.to_upper()
  if method_upper != "GET" && method_upper != "HEAD" && method_upper != "POST" {
    return true
  }
  for header in request_headers {
    let name = match synthetic_network_header_entry_name(header) {
      Some(name) => name.to_lower()
      None => continue
    }
    let value = match synthetic_network_header_entry_string_value(header) {
      Some(value) => value
      None => ""
    }
    if name == "accept" ||
      name == "accept-language" ||
      name == "content-language" {
      continue
    }
    if name == "content-type" &&
      synthetic_fetch_is_cors_safelisted_content_type(value) {
      continue
    }
    return true
  }
  false
}

///|
fn synthetic_fetch_is_cors_safelisted_content_type(value : String) -> Bool {
  let raw_media_type = match find_substring(value, ";", 0) {
    Some(idx) => value.unsafe_substring(start=0, end=idx).to_lower()
    None => value.to_lower()
  }
  let media_type = raw_media_type.trim()
  media_type == "application/x-www-form-urlencoded" ||
  media_type == "multipart/form-data" ||
  media_type == "text/plain"
}
