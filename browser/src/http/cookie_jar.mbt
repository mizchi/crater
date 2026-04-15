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
} derive(Debug)

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
pub impl Show for ParsedCookie with output(self, logger) {
  logger.write_string("{name: ")
  self.name.output(logger)
  logger.write_string(", value: ")
  self.value.output(logger)
  logger.write_string(", domain: ")
  self.domain.output(logger)
  logger.write_string(", path: ")
  self.path.output(logger)
  logger.write_string(", secure: ")
  self.secure.output(logger)
  logger.write_string(", http_only: ")
  self.http_only.output(logger)
  logger.write_string(", same_site: ")
  self.same_site.output(logger)
  logger.write_string(", max_age: ")
  self.max_age.output(logger)
  logger.write_string(", expires: ")
  self.expires.output(logger)
  logger.write_string("}")
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
          name = trimmed[:eq_idx].trim().to_string()
          value = trimmed[eq_idx + 1:].trim().to_string()
        }
        None =>
          // Cookie with no value
          name = trimmed
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
      let d = trimmed[7:].trim().to_string().to_lower()
      // Strip leading dot (RFC 6265 §5.2.3)
      domain = if d.has_prefix(".") { d[1:].to_string() } else { d }
      domain_set = true
    } else if lower.has_prefix("path=") {
      path = trimmed[5:].trim().to_string()
      path_set = true
    } else if lower.has_prefix("max-age=") {
      let val = trimmed[8:].trim().to_string()
      max_age = parse_cookie_int(val)
    } else if lower.has_prefix("expires=") {
      expires = Some(trimmed[8:].trim().to_string())
    } else if lower.has_prefix("samesite=") {
      same_site = trimmed[9:].trim().to_string().to_lower()
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
  Some({
    name,
    value,
    domain,
    path,
    secure,
    http_only,
    same_site,
    max_age,
    expires,
  })
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
    request_path[:last_slash].to_string()
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
  // Security: SameSite=None requires Secure flag (RFC 6265bis)
  if cookie.same_site == "none" && !cookie.secure {
    return
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
/// Enforces: domain matching, path matching, secure flag, httpOnly, SameSite.
///
/// `site_origin`: the origin of the page making the request (for SameSite checks).
///   Empty string means "same-site" (no cross-site enforcement).
/// `is_top_level_navigation`: true for top-level navigations (SameSite=Lax allows these).
pub fn CookieJar::get_cookie_header(
  self : CookieJar,
  request_url : String,
  is_secure : Bool,
  is_http_api : Bool,
  site_origin? : String = "",
  is_top_level_navigation? : Bool = false,
) -> String? {
  if !self.enabled {
    return None
  }
  let req_domain = cookie_extract_domain(request_url)
  let req_path = cookie_extract_path(request_url)
  let cross_site = if site_origin.is_empty() {
    false
  } else {
    let site_domain = cookie_extract_domain(site_origin)
    !cookie_same_site(site_domain, req_domain)
  }
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
    // SameSite enforcement (RFC 6265bis)
    if cross_site {
      let effective_same_site = if cookie.same_site.is_empty() {
        "lax" // Default is Lax per modern browsers
      } else {
        cookie.same_site
      }
      match effective_same_site {
        "strict" => continue // Never sent cross-site
        "lax" =>
          // Lax: only sent on top-level navigation (GET)
          if !is_top_level_navigation {
            continue
          }
        "none" =>
          // SameSite=None requires Secure flag
          if !cookie.secure {
            continue
          }
        _ => continue // Unknown value → treat as Strict (safe default)
      }
    }
    if !first {
      buf.write_string("; ")
    }
    first = false
    buf.write_string(cookie.name)
    buf.write_char('=')
    buf.write_string(cookie.value)
  }
  let result = buf.to_string()
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
/// Check if two domains are "same-site" (share the same registrable domain).
/// Simplified: compares the last two domain labels (no public suffix list).
fn cookie_same_site(domain_a : String, domain_b : String) -> Bool {
  let a = domain_a.to_lower()
  let b = domain_b.to_lower()
  if a == b {
    return true
  }
  // Extract registrable domain (last 2 labels) — simplified, no PSL
  let reg_a = cookie_registrable_domain(a)
  let reg_b = cookie_registrable_domain(b)
  reg_a == reg_b && reg_a.length() > 0
}

///|
/// Extract registrable domain (last 2 labels). Simplified, no PSL.
/// "sub.example.com" → "example.com", "example.com" → "example.com"
fn cookie_registrable_domain(domain : String) -> String {
  let mut last_dot = -1
  let mut second_last_dot = -1
  for i = 0; i < domain.length(); i = i + 1 {
    if domain[i] == '.' {
      second_last_dot = last_dot
      last_dot = i
    }
  }
  if last_dot < 0 {
    // No dots (e.g. "localhost") → domain itself
    return domain
  }
  if second_last_dot < 0 {
    // One dot (e.g. "example.com") → whole domain
    return domain
  }
  // Two+ dots → take from second_last_dot+1
  domain[second_last_dot + 1:].to_string()
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
fn cookie_domain_matches(
  request_domain : String,
  cookie_domain : String,
) -> Bool {
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
      let after = url[i + 3:].to_string()
      let end = match after.find("/") {
        Some(j) => j
        None => after.length()
      }
      let host_port = after[:end].to_string()
      // Remove port
      match host_port.find(":") {
        Some(j) => host_port[:j].to_string().to_lower()
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
      let after = url[i + 3:].to_string()
      match after.find("/") {
        Some(j) => after[j:].to_string()
        None => "/"
      }
    }
    None => "/"
  }
}
