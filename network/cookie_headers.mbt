///|
pub(all) struct SyntheticNetworkCookie {
  name : String
  value_text : String
  domain : String
  domain_explicit : Bool
  path : String
  http_only : Bool
  secure : Bool
  same_site : String
  expiry : Int?
}

///|
extern "js" fn js_parse_cookie_expiry_seconds(value : String) -> Int =
  #| (value) => {
  #|   const text = String(value ?? "").trim();
  #|   if (text.length === 0) return -1;
  #|   const hasZone = /(?:GMT|UTC|[+-]\d{2}:?\d{2})$/i.test(text);
  #|   const parsed = Date.parse(hasZone ? text : `${text} GMT`);
  #|   if (!Number.isFinite(parsed)) return -1;
  #|   return Math.floor(parsed / 1000);
  #| }

///|
pub fn synthetic_network_extract_set_cookie_entries(
  headers : Array[Json],
  base_url : String,
  now_seconds : Int,
) -> Array[SyntheticNetworkCookie] {
  let cookies : Array[SyntheticNetworkCookie] = []
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
      synthetic_network_parse_set_cookie_header_value(
        header_value, base_url, now_seconds,
      ) {
      Some(cookie) => cookies.push(cookie)
      None => ()
    }
  }
  cookies
}

///|
pub fn synthetic_network_parse_set_cookie_header_value(
  header_value : String,
  base_url : String,
  now_seconds : Int,
) -> SyntheticNetworkCookie? {
  synthetic_network_parse_cookie_text(
    header_value, base_url, "/", "none", now_seconds, true,
  )
}

///|
pub fn synthetic_network_parse_document_cookie_assignment(
  cookie_assignment : String,
  base_url : String,
  default_path : String,
  now_seconds : Int,
) -> SyntheticNetworkCookie? {
  synthetic_network_parse_cookie_text(
    cookie_assignment, base_url, default_path, "default", now_seconds, false,
  )
}

///|
pub fn synthetic_network_format_set_cookie_header(
  entry : Map[String, Json],
) -> String {
  let parts : Array[String] = []
  let name = match entry.get("name") {
    Some(String(name)) => name
    _ => ""
  }
  let value = match entry.get("value") {
    Some(String(value)) => value
    _ => ""
  }
  parts.push(name + "=" + value)
  match entry.get("path") {
    Some(String(path)) => parts.push("Path=" + path)
    _ => ()
  }
  match entry.get("domain") {
    Some(String(domain)) => parts.push("Domain=" + domain)
    _ => ()
  }
  match entry.get("expiry") {
    Some(String(expiry)) => parts.push("Expires=" + expiry)
    _ => ()
  }
  match entry.get("maxAge") {
    Some(Number(max_age, ..)) =>
      parts.push("Max-Age=" + max_age.to_int().to_string())
    _ => ()
  }
  match entry.get("httpOnly") {
    Some(True) => parts.push("HttpOnly")
    _ => ()
  }
  match entry.get("secure") {
    Some(True) => parts.push("Secure")
    _ => ()
  }
  match entry.get("sameSite") {
    Some(String(raw_same_site)) => {
      let same_site = raw_same_site.to_lower()
      let mapped = if same_site == "none" {
        "None"
      } else if same_site == "lax" {
        "Lax"
      } else if same_site == "strict" {
        "Strict"
      } else {
        raw_same_site
      }
      parts.push("SameSite=" + mapped)
    }
    _ => ()
  }
  parts.join(";")
}

///|
fn synthetic_network_cookie_domain_from_base_url(base_url : String) -> String {
  match canonicalize_network_http_url(base_url) {
    Some(parts) => parts.host
    None =>
      if base_url.has_prefix("data:") {
        synthetic_network_inline_cookie_host(base_url).to_lower()
      } else {
        "localhost"
      }
  }
}

///|
fn synthetic_network_inline_cookie_host(url : String) -> String {
  let domain_value = extract_url_fragment_param(url, "domain").unwrap_or("")
  let base_host = if domain_value == "" || domain_value == "default" {
    "localhost"
  } else if domain_value == "alt" {
    "alt.localhost"
  } else if domain_value.contains(".") || domain_value.contains(":") {
    domain_value
  } else {
    domain_value + ".localhost"
  }
  let subdomain = extract_url_fragment_param(url, "subdomain").unwrap_or("")
  if subdomain == "" {
    base_host
  } else {
    subdomain + "." + base_host
  }
}

///|
fn extract_url_fragment_param(url : String, key : String) -> String? {
  match find_substring(url, "#", 0) {
    Some(hash_idx) => {
      let start = hash_idx + 1
      if start >= url.length() {
        return None
      }
      let fragment = url.unsafe_substring(start~, end=url.length())
      for part in fragment.split("&") {
        let raw = part.to_owned()
        if raw.length() == 0 {
          continue
        }
        match find_substring(raw, "=", 0) {
          Some(eq_idx) => {
            let part_key = raw.unsafe_substring(start=0, end=eq_idx)
            if part_key == key {
              let value_start = eq_idx + 1
              if value_start <= raw.length() {
                return Some(
                  raw.unsafe_substring(start=value_start, end=raw.length()),
                )
              }
              return Some("")
            }
          }
          None => if raw == key { return Some("") }
        }
      }
      None
    }
    None => None
  }
}

///|
fn synthetic_network_strip_leading_dot(value : String) -> String {
  if value.has_prefix(".") {
    network_slice_from(value, 1)
  } else {
    value
  }
}

///|
fn synthetic_network_parse_cookie_text(
  cookie_text : String,
  base_url : String,
  default_path : String,
  default_same_site : String,
  now_seconds : Int,
  require_valid_name : Bool,
) -> SyntheticNetworkCookie? {
  let attributes : Array[String] = []
  let mut first : String? = None
  for raw_part in cookie_text.split(";") {
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
      let name = network_slice(first, 0, eq_idx).trim().to_owned()
      let value_start = eq_idx + 1
      let value = if value_start <= first.length() {
        network_slice_from(first, value_start).trim().to_owned()
      } else {
        ""
      }
      if require_valid_name &&
        (name == "" || !is_valid_network_header_name_token(name)) {
        return None
      }
      let mut domain = synthetic_network_cookie_domain_from_base_url(base_url)
      let mut domain_explicit = false
      let mut path = default_path
      let mut http_only = false
      let mut secure = false
      let mut same_site = default_same_site
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
              network_slice(attr, 0, attr_eq_idx).trim().to_owned().to_lower(),
              if attr_value_start <= attr.length() {
                network_slice_from(attr, attr_value_start).trim().to_owned()
              } else {
                ""
              },
            )
          }
          None => (attr.to_lower(), "")
        }
        if attr_name == "domain" {
          let normalized_domain = synthetic_network_strip_leading_dot(
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
            Some(parsed_max_age) => expiry = Some(now_seconds + parsed_max_age)
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
      })
    }
    None => None
  }
}

///|
fn network_slice(value : String, start : Int, end : Int) -> String {
  value.unsafe_substring(start~, end~)
}

///|
fn network_slice_from(value : String, start : Int) -> String {
  if start > value.length() {
    ""
  } else {
    value.unsafe_substring(start~, end=value.length())
  }
}

///|
fn is_ascii_case_insensitive_equal(lhs : String, rhs : String) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let lhs_chars = lhs.to_array()
  let rhs_chars = rhs.to_array()
  for i = 0; i < lhs_chars.length(); i = i + 1 {
    let l = lhs_chars[i]
    let r = rhs_chars[i]
    if l == r {
      continue
    }
    let l_is_upper = l >= 'A' && l <= 'Z'
    let r_is_upper = r >= 'A' && r <= 'Z'
    if l_is_upper && l.to_int() + 32 == r.to_int() {
      continue
    }
    if r_is_upper && r.to_int() + 32 == l.to_int() {
      continue
    }
    return false
  }
  true
}

///|
fn is_valid_network_header_name_token(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for c in name.iter() {
    if !is_valid_network_header_name_token_char(c) {
      return false
    }
  }
  true
}

///|
fn is_valid_network_header_name_token_char(c : Char) -> Bool {
  let code = c.to_int()
  if (code >= 48 && code <= 57) ||
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) {
    return true
  }
  match code {
    33 => true
    35 => true
    36 => true
    37 => true
    38 => true
    39 => true
    42 => true
    43 => true
    45 => true
    46 => true
    94 => true
    95 => true
    96 => true
    124 => true
    126 => true
    _ => false
  }
}
