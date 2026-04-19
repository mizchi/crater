///|
/// Parsed Cache-Control header directives
pub(all) struct CacheDirectives {
  max_age : Int?
  no_cache : Bool
  no_store : Bool
  must_revalidate : Bool
  public_ : Bool
  private_ : Bool
  immutable : Bool
} derive(Debug)

///|
pub fn CacheDirectives::default() -> CacheDirectives {
  {
    max_age: None,
    no_cache: false,
    no_store: false,
    must_revalidate: false,
    public_: false,
    private_: false,
    immutable: false,
  }
}

///|
pub impl Show for CacheDirectives with output(self, logger) {
  logger.write_string("{max_age: ")
  self.max_age.output(logger)
  logger.write_string(", no_cache: ")
  self.no_cache.output(logger)
  logger.write_string(", no_store: ")
  self.no_store.output(logger)
  logger.write_string(", must_revalidate: ")
  self.must_revalidate.output(logger)
  logger.write_string(", public_: ")
  self.public_.output(logger)
  logger.write_string(", private_: ")
  self.private_.output(logger)
  logger.write_string(", immutable: ")
  self.immutable.output(logger)
  logger.write_string("}")
}

///|
/// Parse a Cache-Control header value into CacheDirectives.
pub fn parse_cache_control(header : String) -> CacheDirectives {
  let mut max_age : Int? = None
  let mut no_cache = false
  let mut no_store = false
  let mut must_revalidate = false
  let mut public_ = false
  let mut private_ = false
  let mut immutable = false
  let parts = header.split(",")
  for part in parts {
    let trimmed = part.trim(chars=" ").to_string().to_lower()
    if trimmed == "no-cache" {
      no_cache = true
    } else if trimmed == "no-store" {
      no_store = true
    } else if trimmed == "must-revalidate" {
      must_revalidate = true
    } else if trimmed == "public" {
      public_ = true
    } else if trimmed == "private" {
      private_ = true
    } else if trimmed == "immutable" {
      immutable = true
    } else if trimmed.has_prefix("max-age=") {
      let value_str = trimmed[8:].to_string()
      max_age = parse_int_string(value_str)
    }
  }
  { max_age, no_cache, no_store, must_revalidate, public_, private_, immutable }
}

///|
/// Render CacheDirectives into a normalized Cache-Control header value.
#cfg(target="js")
fn render_cache_control(directives : CacheDirectives) -> String {
  let parts : Array[String] = []
  if directives.public_ {
    parts.push("public")
  }
  if directives.private_ {
    parts.push("private")
  }
  match directives.max_age {
    Some(max_age) => parts.push("max-age=" + max_age.to_string())
    None => ()
  }
  if directives.no_cache {
    parts.push("no-cache")
  }
  if directives.no_store {
    parts.push("no-store")
  }
  if directives.must_revalidate {
    parts.push("must-revalidate")
  }
  if directives.immutable {
    parts.push("immutable")
  }
  parts.join(", ")
}

///|
/// Parse an integer from a string, returning None on failure.
fn parse_int_string(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut result = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(result)
}

///|
/// Cached HTTP response entry
pub(all) struct CacheEntry {
  url : String
  status : Int
  headers : Map[String, String]
  body : String
  etag : String?
  last_modified : String?
  directives : CacheDirectives
  stored_at : Double
} derive(Debug)

///|
/// Shared cache backend contract used by cached_fetch.
pub(open) trait HttpCacheBackend {
  lookup(Self, String) -> CacheEntry?
  store(Self, CacheEntry) -> Unit
  remove(Self, String) -> Unit
  clear(Self) -> Unit
}

///|
/// Check whether a cache entry is still fresh at the given time.
pub fn is_fresh(entry : CacheEntry, now : Double) -> Bool {
  let d = entry.directives
  // no_store: never use cache
  if d.no_store {
    return false
  }
  // immutable: always fresh
  if d.immutable {
    return true
  }
  // no_cache: must revalidate every time
  if d.no_cache {
    return false
  }
  // max_age: explicit freshness lifetime
  match d.max_age {
    Some(max_age) => {
      let elapsed = now - entry.stored_at
      let fresh = elapsed < max_age.to_double()
      // must-revalidate: stale entries must NOT be served without revalidation
      // (When fresh, serve normally. When stale, force revalidation — which
      // is the default behavior, so must-revalidate is enforced by returning false.)
      return fresh
    }
    None => ()
  }
  // must-revalidate without max-age: always stale (must revalidate)
  if d.must_revalidate {
    return false
  }
  // Heuristic freshness based on last_modified
  match entry.last_modified {
    Some(lm_str) => {
      let lm_epoch = parse_epoch_string(lm_str)
      let resource_age = entry.stored_at - lm_epoch
      if resource_age > 0.0 {
        let heuristic_lifetime = resource_age * 0.1
        let elapsed = now - entry.stored_at
        return elapsed < heuristic_lifetime
      }
      false
    }
    None => false
  }
}

///|
/// Check if an HTTP status code is cacheable.
/// Only 200, 203, 204, 206, 300, 301, 308 are cacheable by default (RFC 9111 §4.2.2).
pub fn is_cacheable_status(status : Int) -> Bool {
  status == 200 ||
  status == 203 ||
  status == 204 ||
  status == 206 ||
  status == 300 ||
  status == 301 ||
  status == 308
}

///|
/// Parse a numeric string to Double. Returns 0.0 on failure.
fn parse_epoch_string(s : String) -> Double {
  if s.length() == 0 {
    return 0.0
  }
  let mut result = 0.0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10.0 + (c.to_int() - '0'.to_int()).to_double()
    } else {
      return 0.0
    }
  }
  result
}

///|
/// Get current time in seconds since epoch.
/// Delegates to platform-specific FFI.
pub fn now_seconds() -> Double {
  now_seconds_ffi() / 1000.0
}
