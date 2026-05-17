///|
/// Outcome of CORS classification for an outgoing fetch.
///
/// - `Allow`: request can proceed; cross-origin responses still need
///   header validation via http enforce_cors_response.
/// - `PreflightRequired(req)`: an OPTIONS preflight must be sent and
///   succeed before the actual request runs. `req` carries the URL,
///   origin, method, and (lowercased, sorted) custom request headers
///   that go on the Access-Control-Request-* lines.
/// - `Blocked(reason)`: SOP itself refuses the request (currently
///   NoCors with a non-simple method or a custom header).
pub(all) enum CorsDecision {
  Allow
  PreflightRequired(PreflightRequest)
  Blocked(String)
}

///|
pub impl Show for CorsDecision with output(self, logger) {
  match self {
    Allow => logger.write_string("Allow")
    PreflightRequired(req) => {
      logger.write_string("PreflightRequired(")
      req.output(logger)
      logger.write_string(")")
    }
    Blocked(reason) => {
      logger.write_string("Blocked(")
      reason.output(logger)
      logger.write_string(")")
    }
  }
}

///|
/// Descriptor for the OPTIONS preflight that classify_request demands
/// when the actual request is not a simple CORS request.
///
/// `request_headers` is lowercased and sorted so a downstream cache
/// can use it as part of a stable key.
pub(all) struct PreflightRequest {
  url : String
  origin : String
  method : String
  request_headers : Array[String]
}

///|
pub impl Show for PreflightRequest with output(self, logger) {
  logger.write_string("{url: ")
  self.url.output(logger)
  logger.write_string(", origin: ")
  self.origin.output(logger)
  logger.write_string(", method: ")
  self.method.output(logger)
  logger.write_string(", request_headers: ")
  self.request_headers.output(logger)
  logger.write_string("}")
}

///|
/// Cached result of a successful preflight. `expires_at_seconds` is a
/// monotonic clock value (Unix seconds as Double for sub-second
/// granularity); when the cache asks "is this entry still valid?" it
/// compares against the current clock.
pub(all) struct PreflightEntry {
  allowed_methods : Array[String]
  allowed_headers : Array[String]
  allow_credentials : Bool
  expires_at_seconds : Double
}

///|
/// In-memory preflight cache. Key is built by the caller (typically
/// `origin + "|" + url + "|" + method + "|" + headers.join(",")`); the
/// CorsDecision module itself is intentionally key-agnostic for now.
pub struct PreflightCache {
  entries : Map[String, PreflightEntry]
}

///|
pub fn PreflightCache::new() -> PreflightCache {
  PreflightCache::{ entries: Map::new() }
}

///|
/// Classify a pending fetch into Allow / PreflightRequired / Blocked
/// per the Fetch spec's CORS protocol. Does not perform any I/O;
/// callers feed the result into the http fetch driver.
///
/// - Same-origin requests always pass (regardless of mode).
/// - `NoCors` cross-origin: rejects non-simple methods or custom
///   request headers up front (Blocked).
/// - `Cors` / `SameOrigin` cross-origin: simple GET/HEAD/POST with
///   only safelisted request headers → Allow. Anything else returns
///   PreflightRequired with a descriptor for the OPTIONS request.
pub fn classify_request(
  url~ : String,
  origin~ : String,
  mode~ : @http_impl.RequestMode,
  method~ : String,
  headers~ : Map[String, String],
) -> CorsDecision {
  let target_origin = origin_of(url)
  if target_origin == origin {
    return Allow
  }

  // Build the lowercased custom-header list once; both NoCors and
  // Cors branches consume it.
  let custom : Array[String] = []
  for k, _ in headers {
    let lower = k.to_lower()
    if !is_safelisted_header(lower) {
      custom.push(lower)
    }
  }
  custom.sort()

  // SOP guard for NoCors: must stay simple.
  if mode == @http_impl.RequestMode::NoCors {
    if !is_simple_method(method) {
      return Blocked("NoCors disallows non-simple method " + method)
    }
    if !custom.is_empty() {
      return Blocked("NoCors disallows custom header(s): " + custom.join(", "))
    }
    return Allow
  }

  // Cors / SameOrigin / Navigate: preflight if non-simple.
  if is_simple_method(method) && custom.is_empty() {
    return Allow
  }
  PreflightRequired(PreflightRequest::{
    url,
    origin,
    method,
    request_headers: custom,
  })
}

///|
/// CORS "simple" method set: GET / HEAD / POST. Anything else
/// (PUT/DELETE/PATCH/...) triggers a preflight in CORS mode and is
/// blocked outright in NoCors mode.
pub fn is_simple_method(method : String) -> Bool {
  method == "GET" || method == "HEAD" || method == "POST"
}

///|
/// CORS "safelisted" request-header set (lowercased name only —
/// content-type value restrictions are not enforced here; the
/// preflight will surface them at the OPTIONS roundtrip).
pub fn is_safelisted_header(name : String) -> Bool {
  let lower = name.to_lower()
  lower == "accept" ||
  lower == "accept-language" ||
  lower == "content-language" ||
  lower == "content-type"
}

///|
/// Extract `scheme://host[:port]` from a URL. Falls back to returning
/// the input unchanged when the input does not contain `://` — that
/// way a malformed URL never accidentally compares equal to a
/// well-formed origin.
pub fn origin_of(url : String) -> String {
  let scheme_end = match url.find("://") {
    Some(i) => i
    None => return url
  }
  let after_scheme = url.unsafe_substring(
    start=scheme_end + 3,
    end=url.length(),
  )
  let host_port = truncate_at_any(after_scheme, ['/', '?', '#'])
  url.unsafe_substring(start=0, end=scheme_end) + "://" + host_port
}

///|
/// Validate the OPTIONS response that answered an earlier
/// `PreflightRequest`. Returns `Ok(())` when every required
/// Access-Control-Allow-* header is present and accepts the original
/// request (origin / method / each custom header). Returns
/// `Err(message)` describing the first failing check so the caller can
/// surface a useful CORS error.
///
/// Rules (per Fetch spec, simplified):
/// - response.status must be 2xx (200–299).
/// - response.headers["access-control-allow-origin"] must equal
///   `request.origin` exactly, or be `"*"`.
/// - response.headers["access-control-allow-methods"] must contain
///   `request.method` (case-sensitive) or `"*"`.
/// - For each header name in `request.request_headers` (already
///   lowercased by classify_request), the value of
///   `access-control-allow-headers` parsed as a CSV must contain the
///   header (lowercased) or `"*"`.
pub fn validate_preflight_response(
  request : PreflightRequest,
  response : @http_impl.HttpResponse,
) -> Result[Unit, String] {
  if response.status < 200 || response.status >= 300 {
    return Err("preflight non-2xx status: " + response.status.to_string())
  }
  let aco = header_or_empty(response.headers, "access-control-allow-origin")
  if aco != request.origin && aco != "*" {
    return Err(
      "Access-Control-Allow-Origin missing or mismatched: \"" + aco + "\"",
    )
  }
  let allowed_methods = parse_csv(
    header_or_empty(response.headers, "access-control-allow-methods"),
  )
  if !allowed_methods.contains(request.method) && !allowed_methods.contains("*") {
    return Err(
      "Access-Control-Allow-Methods does not include " + request.method,
    )
  }
  let allowed_headers : Array[String] = parse_csv(
    header_or_empty(response.headers, "access-control-allow-headers"),
  ).map(fn(s) { s.to_lower() })
  for h in request.request_headers {
    if !allowed_headers.contains(h) && !allowed_headers.contains("*") {
      return Err("Access-Control-Allow-Headers does not include " + h)
    }
  }
  Ok(())
}

///|
/// Validate the actual (non-OPTIONS) response from a cross-origin
/// fetch against the CORS resource-sharing rules. Same-origin
/// responses are always Ok; cross-origin responses must satisfy:
///
/// - `Access-Control-Allow-Origin` echoes `origin` exactly, or is
///   `"*"` (only acceptable when credentials != Include).
/// - When `credentials == Include`:
///   - ACA-Origin must NOT be `"*"` (per Fetch spec: wildcard +
///     credentials is a developer error and the response is blocked
///     even if the browser already received it).
///   - ACA-Origin must equal `origin` exactly.
///   - `Access-Control-Allow-Credentials` must be the literal `"true"`
///     (case-sensitive per spec).
///
/// Returns `Err(message)` describing the first failing check so the
/// caller can surface a useful CORS error.
pub fn validate_actual_response(
  request_url~ : String,
  origin~ : String,
  credentials~ : @http_impl.CredentialsMode,
  response~ : @http_impl.HttpResponse,
) -> Result[Unit, String] {
  if origin_of(request_url) == origin {
    return Ok(())
  }
  let aco = header_or_empty(response.headers, "access-control-allow-origin")
  match credentials {
    Include => {
      if aco == "*" {
        return Err(
          "Access-Control-Allow-Origin \"*\" is not allowed with credentials=Include",
        )
      }
      if aco != origin {
        return Err(
          "Access-Control-Allow-Origin missing or mismatched: \"" + aco + "\"",
        )
      }
      let acc = header_or_empty(
        response.headers,
        "access-control-allow-credentials",
      )
      if acc != "true" {
        return Err(
          "Access-Control-Allow-Credentials must be \"true\" with credentials=Include, got \"" +
          acc +
          "\"",
        )
      }
      Ok(())
    }
    Omit | SameOrigin => {
      if aco != origin && aco != "*" {
        return Err(
          "Access-Control-Allow-Origin missing or mismatched: \"" + aco + "\"",
        )
      }
      Ok(())
    }
  }
}

///|
/// Look up `key` in `headers` (case-insensitive: the response from a
/// real fetch may use any casing). Returns the trimmed value, or `""`
/// when absent. Treating "header missing" and "header empty" the same
/// way is intentional — both leave validation with no positive
/// information to act on, which is the failure case anyway.
fn header_or_empty(headers : Map[String, String], key : String) -> String {
  let lower_key = key.to_lower()
  for k, v in headers {
    if k.to_lower() == lower_key {
      return v.trim().to_owned()
    }
  }
  ""
}

///|
/// Split a comma-separated header value into trimmed, non-empty tokens.
/// E.g. `"GET, POST , "` → `["GET", "POST"]`. Caller is responsible
/// for any case folding (preflight method names stay as-is; header
/// names are lowercased upstream).
pub fn parse_csv(value : String) -> Array[String] {
  let out : Array[String] = []
  for part in value.split(",") {
    let token = part.trim(chars=" ").to_owned()
    if token != "" {
      out.push(token)
    }
  }
  out
}

///|
/// Return the prefix of `s` up to (but not including) the first
/// character in `stops`. Returns `s` unchanged if no stop matches.
fn truncate_at_any(s : String, stops : Array[Char]) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  for i = 0; i < chars.length(); i = i + 1 {
    if stops.contains(chars[i]) {
      end = i
      break
    }
  }
  s.unsafe_substring(start=0, end~)
}
