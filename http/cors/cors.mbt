///|
/// Outcome of CORS classification for an outgoing fetch.
///
/// - `Allow`: request can proceed; cross-origin responses still need
///   header validation via http enforce_cors_response.
/// - `PreflightRequired(req)`: an OPTIONS preflight must be sent and
///   succeed before the actual request runs. `req` carries the URL,
///   origin, HTTP method, and (lowercased, sorted) custom request headers
///   that go on the Access-Control-Request-* lines.
/// - `Blocked(reason)`: SOP itself refuses the request (currently
///   NoCors with a non-simple method or a custom header).
pub(all) enum CorsDecision {
  Allow
  PreflightRequired(PreflightRequest)
  Blocked(String)
}

///|
pub impl Show for CorsDecision with fn output(self, logger) {
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
  http_method : String
  request_headers : Array[String]
}

///|
pub impl Show for PreflightRequest with fn output(self, logger) {
  logger.write_string("{url: ")
  self.url.output(logger)
  logger.write_string(", origin: ")
  self.origin.output(logger)
  logger.write_string(", http_method: ")
  self.http_method.output(logger)
  logger.write_string(", request_headers: ")
  logger.write_string("[")
  logger.write_string(self.request_headers.join(", "))
  logger.write_string("]")
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
///
/// `max_entries` caps the total number of distinct keys held; when the
/// cap is hit on insert the oldest entry (FIFO insertion order) is
/// evicted. This prevents unbounded growth per Profile lifetime — a
/// permissive remote could otherwise stuff the cache with a unique
/// preflight per request. `insertion_order` tracks keys in the order
/// they were first inserted so eviction is O(1) amortized at the front.
pub struct PreflightCache {
  entries : Map[String, PreflightEntry]
  insertion_order : Array[String]
  max_entries : Int
}

///|
/// Construct a preflight cache with an optional `max_entries` cap
/// (default 512). The cap is a self-DoS bound: same justification as
/// MemoryCacheBackend's max_entries=1000. Hitting the cap evicts the
/// oldest entry in FIFO insertion order.
pub fn PreflightCache::new(max_entries? : Int = 512) -> PreflightCache {
  PreflightCache::{ entries: {}, insertion_order: [], max_entries }
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
  http_method~ : String,
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
    if !is_simple_method(http_method) {
      return Blocked("NoCors disallows non-simple method " + http_method)
    }
    if !custom.is_empty() {
      return Blocked("NoCors disallows custom header(s): " + custom.join(", "))
    }
    return Allow
  }

  // Cors / SameOrigin / Navigate: preflight if non-simple.
  if is_simple_method(http_method) && custom.is_empty() {
    return Allow
  }
  PreflightRequired(PreflightRequest::{
    url,
    origin,
    http_method,
    request_headers: custom,
  })
}

///|
/// CORS "simple" method set: GET / HEAD / POST. Anything else
/// (PUT/DELETE/PATCH/...) triggers a preflight in CORS mode and is
/// blocked outright in NoCors mode.
pub fn is_simple_method(http_method : String) -> Bool {
  http_method == "GET" || http_method == "HEAD" || http_method == "POST"
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
///   `request.http_method` (case-sensitive) or `"*"`.
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
  if !allowed_methods.contains(request.http_method) &&
    !allowed_methods.contains("*") {
    return Err(
      "Access-Control-Allow-Methods does not include " + request.http_method,
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
/// Memoized preflight: look up an entry for `request` in `self`, and
/// either reuse it (when `expires_at_seconds` is still in the future
/// relative to `now()`) or perform an OPTIONS roundtrip via `fetcher`
/// and store a fresh entry.
///
/// On a cache hit we still re-check the cached entry against the
/// current `request` (method + each request header must be in the
/// allowed lists, accounting for `"*"`). A hit that fails this check
/// is evicted and treated as a miss — that way a misconfigured server
/// can recover after it updates its allow-lists without waiting for
/// Max-Age to expire.
///
/// On a miss we delegate to `fetcher`, run the response through
/// `validate_preflight_response`, and (on Ok) insert a new entry with
/// `expires_at_seconds = now() + Access-Control-Max-Age`. Validation
/// errors are propagated unchanged so the caller surfaces them.
pub fn PreflightCache::get_or_validate(
  self : PreflightCache,
  request : PreflightRequest,
  now : () -> Double,
  fetcher : (PreflightRequest) -> @http_impl.HttpResponse,
) -> Result[Unit, String] {
  let key = cache_key(request)
  let current = now()
  if self.entries.get(key) is Some(entry) {
    if entry.expires_at_seconds > current {
      match validate_cached_entry(entry, request) {
        Ok(_) => return Ok(())
        Err(_) => self.remove_entry(key)
      }
    } else {
      self.remove_entry(key)
    }
  }
  let response = fetcher(request)
  match validate_preflight_response(request, response) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let raw_max_age = parse_double_default(
    header_or_empty(response.headers, "access-control-max-age"),
    0.0,
  )
  // Clamp Access-Control-Max-Age to [0, 7200] seconds matching
  // Chromium's browser policy. Without this clamp a malicious origin
  // could serve Access-Control-Max-Age: 99999999999999 and pin a
  // permissive preflight policy for the Profile's entire lifetime.
  let max_age = if raw_max_age > 7200.0 {
    7200.0
  } else if raw_max_age < 0.0 {
    0.0
  } else {
    raw_max_age
  }
  let allowed_methods = parse_csv(
    header_or_empty(response.headers, "access-control-allow-methods"),
  )
  let allowed_headers = parse_csv(
    header_or_empty(response.headers, "access-control-allow-headers"),
  ).map(fn(s) { s.to_lower() })
  let allow_credentials = header_or_empty(
      response.headers,
      "access-control-allow-credentials",
    ) ==
    "true"
  // Evict oldest entry (FIFO) if we are at capacity. The cap is a
  // self-DoS bound — see PreflightCache::new for justification.
  if self.entries.length() >= self.max_entries {
    if self.insertion_order.length() > 0 {
      let oldest = self.insertion_order.remove(0)
      self.entries.remove(oldest)
    }
  }
  self.entries[key] = PreflightEntry::{
    allowed_methods,
    allowed_headers,
    allow_credentials,
    expires_at_seconds: current + max_age,
  }
  self.insertion_order.push(key)
  Ok(())
}

///|
/// Returns true when the cache holds an unexpired entry whose
/// allow-lists cover this request. Used by callers that want to
/// skip pre-dispatching the OPTIONS preflight on a cache hit.
///
/// This is the read-only peek companion to `get_or_validate` and shares
/// the same `cache_key` formula, so callers do not need to mirror the
/// key construction (which would silently drift if the formula ever
/// adds a new axis like credentials).
pub fn PreflightCache::contains_fresh(
  self : PreflightCache,
  request : PreflightRequest,
  now : () -> Double,
) -> Bool {
  let key = cache_key(request)
  match self.entries.get(key) {
    Some(entry) =>
      if entry.expires_at_seconds > now() {
        match validate_cached_entry(entry, request) {
          Ok(_) => true
          Err(_) => false
        }
      } else {
        false
      }
    None => false
  }
}

///|
/// Remove an entry from both the map and the insertion-order tracker.
/// Used internally when a cache entry is expired or fails the per-call
/// allow-list re-check.
fn PreflightCache::remove_entry(self : PreflightCache, key : String) -> Unit {
  self.entries.remove(key)
  for i = 0; i < self.insertion_order.length(); i = i + 1 {
    if self.insertion_order[i] == key {
      let _ = self.insertion_order.remove(i)
      break
    }
  }
}

///|
/// Build a stable cache key for a preflight request.
/// `request_headers` is already lowercased + sorted by
/// `classify_request`, so the join is deterministic.
fn cache_key(req : PreflightRequest) -> String {
  req.origin +
  "|" +
  req.url +
  "|" +
  req.http_method +
  "|" +
  req.request_headers.join(",")
}

///|
/// Re-check a cache hit against the current request. Mirrors the
/// method / header subset of `validate_preflight_response`, but reads
/// from the parsed `PreflightEntry` instead of HTTP headers.
fn validate_cached_entry(
  entry : PreflightEntry,
  req : PreflightRequest,
) -> Result[Unit, String] {
  if !entry.allowed_methods.contains(req.http_method) &&
    !entry.allowed_methods.contains("*") {
    return Err("cached entry does not allow method " + req.http_method)
  }
  for h in req.request_headers {
    if !entry.allowed_headers.contains(h) &&
      !entry.allowed_headers.contains("*") {
      return Err("cached entry does not allow header " + h)
    }
  }
  Ok(())
}

///|
/// Parse a numeric (integer or decimal) string to Double. Returns
/// `default` on any malformed input — the spec treats unparseable
/// Access-Control-Max-Age as if the header were absent, so callers
/// pass `0.0` to force a fresh roundtrip on the next request.
fn parse_double_default(s : String, default : Double) -> Double {
  if s.length() == 0 {
    return default
  }
  let mut int_part = 0.0
  let mut frac_part = 0.0
  let mut frac_div = 1.0
  let mut seen_dot = false
  let mut seen_digit = false
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c == '.' {
      if seen_dot {
        return default
      }
      seen_dot = true
    } else if c >= '0' && c <= '9' {
      let d = (c.to_int() - '0'.to_int()).to_double()
      if seen_dot {
        frac_div = frac_div * 10.0
        frac_part = frac_part + d / frac_div
      } else {
        int_part = int_part * 10.0 + d
      }
      seen_digit = true
    } else {
      return default
    }
  }
  if !seen_digit {
    return default
  }
  int_part + frac_part
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
