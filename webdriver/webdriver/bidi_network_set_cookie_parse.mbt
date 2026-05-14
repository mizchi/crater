///|
fn synthetic_network_extract_set_cookie_entries(
  headers : Array[Json],
  base_url : String,
) -> Array[StoredCookie] {
  let cookies : Array[StoredCookie] = []
  for
    cookie in @crater_network.synthetic_network_extract_set_cookie_entries(
      headers,
      base_url,
      storage_now_seconds(),
    ) {
    cookies.push(synthetic_network_cookie_to_stored_cookie(cookie))
  }
  cookies
}

///|
fn synthetic_network_cookie_to_stored_cookie(
  cookie : @crater_network.SyntheticNetworkCookie,
) -> StoredCookie {
  {
    name: cookie.name,
    value_text: cookie.value_text,
    domain: cookie.domain,
    domain_explicit: cookie.domain_explicit,
    path: cookie.path,
    http_only: cookie.http_only,
    secure: cookie.secure,
    same_site: cookie.same_site,
    expiry: cookie.expiry,
    context_id: None,
    user_context: None,
    source_origin: None,
  }
}
