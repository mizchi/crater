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
pub(all) struct SyntheticNetworkSetCookieOverrideEntry {
  set_cookie_header_value : String
  cookie : SyntheticNetworkCookie
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
pub fn synthetic_network_normalize_set_cookie_override_entry(
  entry : Map[String, Json],
  name : String,
  value_text : String,
  base_url : String,
  now_seconds : Int,
) -> Result[SyntheticNetworkSetCookieOverrideEntry, String] {
  if !synthetic_network_is_valid_header_name_token(name) {
    return Err("cookie name is invalid")
  }
  let mut domain = synthetic_network_cookie_domain_from_base_url(base_url)
  let mut domain_explicit = false
  let mut path = "/"
  let mut http_only = false
  let mut secure = false
  let mut same_site = "none"
  let mut expiry : Int? = None
  let header_entry : Map[String, Json] = {}
  header_entry["name"] = Json::string(name)
  header_entry["value"] = Json::string(value_text)

  match entry.get("domain") {
    Some(String(raw_domain)) => {
      let normalized_domain = synthetic_network_strip_leading_dot(
        raw_domain.trim().to_owned().to_lower(),
      )
      domain = normalized_domain
      domain_explicit = normalized_domain != ""
      header_entry["domain"] = Json::string(raw_domain)
    }
    Some(_) => return Err("cookie domain must be a string")
    None => ()
  }
  match entry.get("expiry") {
    Some(String(raw_expiry)) => {
      header_entry["expiry"] = Json::string(raw_expiry)
      let parsed_expiry = js_parse_cookie_expiry_seconds(raw_expiry)
      if parsed_expiry >= 0 {
        expiry = Some(parsed_expiry)
      }
    }
    Some(_) => return Err("cookie expiry must be a string")
    None => ()
  }
  match entry.get("path") {
    Some(String(raw_path)) => {
      path = raw_path
      header_entry["path"] = Json::string(raw_path)
    }
    Some(_) => return Err("cookie path must be a string")
    None => ()
  }
  match entry.get("sameSite") {
    Some(String(raw_same_site)) => {
      let lowered_same_site = raw_same_site.to_lower()
      if lowered_same_site != "none" &&
        lowered_same_site != "lax" &&
        lowered_same_site != "strict" {
        return Err("cookie sameSite is invalid")
      }
      same_site = lowered_same_site
      header_entry["sameSite"] = Json::string(lowered_same_site)
    }
    Some(_) => return Err("cookie sameSite must be a string")
    None => ()
  }
  match entry.get("httpOnly") {
    Some(True) => {
      http_only = true
      header_entry["httpOnly"] = Json::boolean(true)
    }
    Some(False) => header_entry["httpOnly"] = Json::boolean(false)
    Some(_) => return Err("cookie httpOnly must be a boolean")
    None => ()
  }
  match entry.get("secure") {
    Some(True) => {
      secure = true
      header_entry["secure"] = Json::boolean(true)
    }
    Some(False) => header_entry["secure"] = Json::boolean(false)
    Some(_) => return Err("cookie secure must be a boolean")
    None => ()
  }
  match entry.get("maxAge") {
    Some(raw_max_age) =>
      match
        synthetic_network_json_as_safe_int(
          raw_max_age, -9007199254740991.0, 9007199254740991.0,
        ) {
        Some(max_age) => {
          header_entry["maxAge"] = Json::number(max_age.to_double())
          expiry = Some(now_seconds + max_age)
        }
        None => return Err("cookie maxAge must be an integer")
      }
    None => ()
  }

  Ok({
    set_cookie_header_value: synthetic_network_format_set_cookie_header(
      header_entry,
    ),
    cookie: {
      name,
      value_text,
      domain,
      domain_explicit,
      path,
      http_only,
      secure,
      same_site,
      expiry,
    },
  })
}

///|
pub fn synthetic_network_normalize_request_cookie_entries(
  raw_cookies : Json?,
) -> Result[SyntheticNetworkCookieOverride, String] {
  match raw_cookies {
    None => Ok({ enabled: false, cookies: [] })
    Some(Null) => Ok({ enabled: true, cookies: [] })
    Some(Array(items)) => {
      let cookies : Array[Json] = []
      for item in items {
        let map = match item {
          Object(map) => map
          _ => return Err("requestCookies entry must be an object")
        }
        let name = match map.get("name") {
          Some(String(name)) => name
          _ => return Err("requestCookies.name must be a string")
        }
        let value = match map.get("value") {
          Some(Object(value_map)) => {
            let value_type = match value_map.get("type") {
              Some(String(value_type)) => value_type
              _ => return Err("requestCookies.value.type must be a string")
            }
            let payload = match value_map.get("value") {
              Some(String(payload)) => payload
              _ => return Err("requestCookies.value.value must be a string")
            }
            if value_type != "string" {
              return Err("requestCookies.value.type is invalid")
            }
            Json::object({
              "type": Json::string("string"),
              "value": Json::string(payload),
            })
          }
          _ => return Err("requestCookies.value must be an object")
        }
        cookies.push(
          Json::object({ "name": Json::string(name), "value": value }),
        )
      }
      Ok({ enabled: true, cookies })
    }
    Some(_) => Err("requestCookies must be an array")
  }
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
        (name == "" || !synthetic_network_is_valid_header_name_token(name)) {
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
fn synthetic_network_json_as_safe_int(
  value : Json,
  min : Double,
  max : Double,
) -> Int? {
  match value {
    Number(n, ..) =>
      if n == n.to_int64().to_double() && n >= min && n <= max {
        Some(n.to_int64().to_int())
      } else {
        None
      }
    _ => None
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
