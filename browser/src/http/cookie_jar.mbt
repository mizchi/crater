///|
/// HTTP Cookie Jar — RFC 6265 compliant cookie storage
///
/// SECURITY: Cookie support is DISABLED by default.
/// Enable via CookieJar::new(enabled=true) only for testing or when explicitly needed.

///|
/// Parsed Set-Cookie attributes
pub(all) struct ParsedCookie {
  name : String
  value : String
  domain : String
  path : String
  secure : Bool
  http_only : Bool
  same_site : String // "strict" | "lax" | "none" | ""
  max_age : Int? // seconds
  expires : String? // raw date string
} derive(Show)

///|
/// Cookie Jar — stores cookies per-domain with security enforcement
pub struct CookieJar {
  cookies : Array[ParsedCookie]
  /// SECURITY: When false (default), all operations are no-ops
  enabled : Bool
}

///|
pub fn CookieJar::new(enabled? : Bool = false) -> CookieJar {
  { cookies: [], enabled }
}

///|
/// Parse a Set-Cookie header value into a ParsedCookie.
/// Returns None if the cookie is malformed.
pub fn parse_set_cookie(
  header : String,
  request_domain : String,
  request_path : String,
) -> ParsedCookie? {
  if header.is_empty() {
    return None
  }
  // Split name=value from attributes
  let parts = header.split(";")
  let mut first = true
  let mut name = ""
  let mut value = ""
  let mut domain = ""
  let mut path = ""
  let mut secure = false
  let mut http_only = false
  let mut same_site = ""
  let mut max_age : Int? = None
  let mut expires : String? = None
  let mut domain_set = false
  let mut path_set = false
  for part in parts {
    let trimmed = part.trim(chars=" ").to_string()
    if first {
      first = false
      // name=value pair
      match trimmed.find("=") {
        Some(eq_idx) => {
          name = trimmed.substring(end=eq_idx).trim().to_string()
          value = trimmed.substring(start=eq_idx + 1).trim().to_string()
        }
        None => {
          // Cookie with no value
          name = trimmed
        }
      }
      // Empty cookie name is invalid (RFC 6265 §5.2)
      if name.is_empty() {
        return None
      }
      continue
    }
    // Parse attributes
    let lower = trimmed.to_lower()
    if lower == "secure" {
      secure = true
    } else if lower == "httponly" {
      http_only = true
    } else if lower.has_prefix("domain=") {
      let d = trimmed.substring(start=7).trim().to_string().to_lower()
      // Strip leading dot (RFC 6265 §5.2.3)
      domain = if d.has_prefix(".") { d.substring(start=1) } else { d }
      domain_set = true
    } else if lower.has_prefix("path=") {
      path = trimmed.substring(start=5).trim().to_string()
      path_set = true
    } else if lower.has_prefix("max-age=") {
      let val = trimmed.substring(start=8).trim().to_string()
      max_age = parse_cookie_int(val)
    } else if lower.has_prefix("expires=") {
      expires = Some(trimmed.substring(start=8).trim().to_string())
    } else if lower.has_prefix("samesite=") {
      same_site = trimmed.substring(start=9).trim().to_string().to_lower()
    }
  }
  // Default domain to request domain if not set
  if !domain_set {
    domain = request_domain.to_lower()
  }
  // Default path per RFC 6265 §5.1.4
  if !path_set {
    path = cookie_default_path(request_path)
  }
  // Domain validation: cookie domain must be a suffix of request domain
  // or equal (RFC 6265 §5.3 step 6)
  if domain_set {
    let req_lower = request_domain.to_lower()
    if req_lower != domain && !req_lower.has_suffix("." + domain) {
      return None // Reject: domain does not match request
    }
  }
  Some({ name, value, domain, path, secure, http_only, same_site, max_age, expires })
}

///|
/// Get the default cookie path from a request path (RFC 6265 §5.1.4)
fn cookie_default_path(request_path : String) -> String {
  if request_path.is_empty() || !request_path.has_prefix("/") {
    return "/"
  }
  // Find last '/' (excluding trailing)
  let mut last_slash = 0
  for i = 1; i < request_path.length(); i = i + 1 {
    if request_path[i] == '/' {
      last_slash = i
    }
  }
  if last_slash == 0 {
    "/"
  } else {
    request_path.substring(end=last_slash)
  }
}

///|
/// Parse an integer for cookie max-age (allows negative values)
fn parse_cookie_int(s : String) -> Int? {
  if s.is_empty() {
    return None
  }
  let mut result = 0
  let mut negative = false
  let mut start = 0
  if s[0] == '-' {
    negative = true
    start = 1
  }
  if start >= s.length() {
    return None
  }
  for i = start; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  if negative {
    Some(-result)
  } else {
    Some(result)
  }
}

///|
/// Store a cookie from a Set-Cookie header.
/// Enforces: domain validation, secure flag, httpOnly flag.
pub fn CookieJar::store_from_header(
  self : CookieJar,
  set_cookie_header : String,
  request_url : String,
  is_secure_origin : Bool,
) -> Unit {
  if !self.enabled {
    return
  }
  let req_domain = cookie_extract_domain(request_url)
  let req_path = cookie_extract_path(request_url)
  let cookie = match parse_set_cookie(set_cookie_header, req_domain, req_path) {
    Some(c) => c
    None => return
  }
  // Security: Secure cookies only from secure origins
  if cookie.secure && !is_secure_origin {
    return
  }
  // Security: __Secure- prefix requires Secure flag (RFC 6265bis §4.1.3)
  if cookie.name.has_prefix("__Secure-") && !cookie.secure {
    return
  }
  // Security: __Host- prefix requires Secure, no explicit Domain, Path=/ (RFC 6265bis §4.1.3)
  if cookie.name.has_prefix("__Host-") {
    if !cookie.secure || cookie.path != "/" || cookie.domain != req_domain {
      // __Host- cookies must not have Domain attribute set (domain == request domain only)
      return
    }
  }
  // max-age=0 or negative: delete cookie
  match cookie.max_age {
    Some(age) if age <= 0 => {
      self.remove_cookie(cookie.name, cookie.domain, cookie.path)
      return
    }
    _ => ()
  }
  // Replace existing cookie with same name+domain+path
  self.remove_cookie(cookie.name, cookie.domain, cookie.path)
  self.cookies.push(cookie)
}

///|
/// Get cookies for a request URL as "Cookie: name=value; name2=value2" pairs.
/// Enforces: domain matching, path matching, secure flag, httpOnly.
pub fn CookieJar::get_cookie_header(
  self : CookieJar,
  request_url : String,
  is_secure : Bool,
  is_http_api : Bool,
) -> String? {
  if !self.enabled {
    return None
  }
  let req_domain = cookie_extract_domain(request_url)
  let req_path = cookie_extract_path(request_url)
  let buf = StringBuilder::new()
  let mut first = true
  for cookie in self.cookies {
    // Domain match (RFC 6265 §5.4)
    if !cookie_domain_matches(req_domain, cookie.domain) {
      continue
    }
    // Path match (RFC 6265 §5.4)
    if !cookie_path_matches(req_path, cookie.path) {
      continue
    }
    // Secure cookie only over secure channel
    if cookie.secure && !is_secure {
      continue
    }
    // httpOnly cookies only sent in HTTP APIs (not accessible to JS)
    if cookie.http_only && !is_http_api {
      continue
    }
    // SameSite enforcement (simplified)
    // For now we send all matching cookies in HTTP API context
    if !first {
      buf.write_string("; ")
    }
    first = false
    buf.write_string(cookie.name)
    buf.write_char('=')
    buf.write_string(cookie.value)
  }
  let result = buf.to_string()
  if result.is_empty() { None } else { Some(result) }
}

///|
/// Remove a cookie by name+domain+path
fn CookieJar::remove_cookie(
  self : CookieJar,
  name : String,
  domain : String,
  path : String,
) -> Unit {
  let mut i = 0
  while i < self.cookies.length() {
    let c = self.cookies[i]
    if c.name == name && c.domain == domain && c.path == path {
      self.cookies.remove(i) |> ignore
    } else {
      i = i + 1
    }
  }
}

///|
/// Clear all cookies
pub fn CookieJar::clear(self : CookieJar) -> Unit {
  self.cookies.clear()
}

///|
/// Get number of stored cookies
pub fn CookieJar::size(self : CookieJar) -> Int {
  self.cookies.length()
}

///|
/// Domain match per RFC 6265 §5.1.3
fn cookie_domain_matches(request_domain : String, cookie_domain : String) -> Bool {
  let req = request_domain.to_lower()
  let cd = cookie_domain.to_lower()
  if req == cd {
    return true
  }
  // request domain must end with ".cookiedomain"
  req.has_suffix("." + cd)
}

///|
/// Path match per RFC 6265 §5.1.4
fn cookie_path_matches(request_path : String, cookie_path : String) -> Bool {
  if request_path == cookie_path {
    return true
  }
  if request_path.has_prefix(cookie_path) {
    // Cookie path must end with / or request path must have / after cookie path
    if cookie_path.has_suffix("/") {
      return true
    }
    if request_path.length() > cookie_path.length() &&
      request_path[cookie_path.length()] == '/' {
      return true
    }
  }
  false
}

///|
/// Extract domain from URL
fn cookie_extract_domain(url : String) -> String {
  match url.find("://") {
    Some(i) => {
      let after = url.substring(start=i + 3)
      let end = match after.find("/") {
        Some(j) => j
        None => after.length()
      }
      let host_port = after.substring(end~)
      // Remove port
      match host_port.find(":") {
        Some(j) => host_port.substring(end=j).to_lower()
        None => host_port.to_lower()
      }
    }
    None => url.to_lower()
  }
}

///|
/// Extract path from URL
fn cookie_extract_path(url : String) -> String {
  match url.find("://") {
    Some(i) => {
      let after = url.substring(start=i + 3)
      match after.find("/") {
        Some(j) => after.substring(start=j)
        None => "/"
      }
    }
    None => "/"
  }
}
