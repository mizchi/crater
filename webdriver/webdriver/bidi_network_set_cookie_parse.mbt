///|
fn synthetic_network_extract_set_cookie_entries(
  headers : Array[Json],
  base_url : String,
) -> Array[StoredCookie] {
  let cookies : Array[StoredCookie] = []
  for header in headers {
    let map = match header {
      Object(map) => map
      _ => continue
    }
    let name = match map.get("name") {
      Some(String(name)) => name
      _ => continue
    }
    if !is_ascii_case_insensitive_equal(name, "set-cookie") {
      continue
    }
    let value_map = match map.get("value") {
      Some(Object(value_map)) => value_map
      _ => continue
    }
    let value_type = match value_map.get("type") {
      Some(String(value_type)) => value_type
      _ => continue
    }
    if value_type != "string" {
      continue
    }
    let header_value = match value_map.get("value") {
      Some(String(header_value)) => header_value
      _ => continue
    }
    match
      synthetic_network_parse_set_cookie_header_value(header_value, base_url) {
      Some(cookie) => cookies.push(cookie)
      None => ()
    }
  }
  cookies
}

///|
fn synthetic_network_parse_set_cookie_header_value(
  header_value : String,
  base_url : String,
) -> StoredCookie? {
  let attributes : Array[String] = []
  let mut first : String? = None
  for raw_part in header_value.split(";") {
    let part = raw_part.trim().to_owned()
    match first {
      Some(_) => attributes.push(part)
      None => first = Some(part)
    }
  }
  let first = match first {
    Some(first) => first
    None => return None
  }
  match find_substring(first, "=", 0) {
    Some(eq_idx) => {
      let name = storage_slice(first, 0, eq_idx).trim().to_owned()
      let value_start = eq_idx + 1
      let value = if value_start <= first.length() {
        storage_slice_from(first, value_start).trim().to_owned()
      } else {
        ""
      }
      if name == "" || !is_valid_network_header_name_token(name) {
        return None
      }
      let mut domain = storage_cookie_domain_from_base_url(base_url)
      let mut domain_explicit = false
      let mut path = "/"
      let mut http_only = false
      let mut secure = false
      let mut same_site = "none"
      let mut expiry : Int? = None

      for raw_attr in attributes {
        let attr = raw_attr.trim().to_owned()
        if attr == "" {
          continue
        }
        let (attr_name, attr_value) = match find_substring(attr, "=", 0) {
          Some(attr_eq_idx) => {
            let attr_value_start = attr_eq_idx + 1
            (
              storage_slice(attr, 0, attr_eq_idx).trim().to_owned().to_lower(),
              if attr_value_start <= attr.length() {
                storage_slice_from(attr, attr_value_start).trim().to_owned()
              } else {
                ""
              },
            )
          }
          None => (attr.to_lower(), "")
        }
        if attr_name == "domain" {
          let normalized_domain = storage_strip_leading_dot(
            attr_value.trim().to_owned().to_lower(),
          )
          if normalized_domain != "" {
            domain = normalized_domain
            domain_explicit = true
          }
        } else if attr_name == "path" {
          if attr_value != "" {
            path = attr_value
          }
        } else if attr_name == "samesite" {
          let lowered = attr_value.to_lower()
          if lowered == "none" || lowered == "lax" || lowered == "strict" {
            same_site = lowered
          }
        } else if attr_name == "max-age" {
          let parsed_max_age : Int? = Some(@string.parse_int(attr_value)) catch {
            _ => None
          }
          match parsed_max_age {
            Some(parsed_max_age) =>
              expiry = Some(storage_now_seconds() + parsed_max_age)
            None => ()
          }
        } else if attr_name == "expires" {
          let parsed_expiry = js_parse_cookie_expiry_seconds(attr_value)
          if parsed_expiry >= 0 {
            expiry = Some(parsed_expiry)
          }
        } else if attr_name == "httponly" {
          http_only = true
        } else if attr_name == "secure" {
          secure = true
        }
      }

      Some({
        name,
        value_text: value,
        domain,
        domain_explicit,
        path,
        http_only,
        secure,
        same_site,
        expiry,
        context_id: None,
        user_context: None,
        source_origin: None,
      })
    }
    None => None
  }
}
