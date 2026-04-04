///|
/// Build a CacheEntry from a URL and HttpResponse.
fn build_cache_entry(url : String, response : HttpResponse) -> CacheEntry {
  let cache_control_header = get_header(response.headers, "cache-control")
  let directives = match cache_control_header {
    Some(h) => parse_cache_control(h)
    None => CacheDirectives::default()
  }
  let etag = get_header(response.headers, "etag")
  let last_modified = get_header(response.headers, "last-modified")
  {
    url,
    status: response.status,
    headers: response.headers,
    body: response.body,
    etag,
    last_modified,
    directives,
    stored_at: now_seconds(),
  }
}

///|
/// Convert a CacheEntry back to an HttpResponse.
fn entry_to_response(entry : CacheEntry) -> HttpResponse {
  { status: entry.status, headers: entry.headers, body: entry.body }
}

///|
/// Fetch with transparent HTTP caching (async version).
/// Wraps an async fetcher (e.g. @http.fetch) with cache lookup/store.
/// Only GET requests are cached.
pub async fn cached_fetch_async(
  url~ : String,
  options~ : FetchOptions,
  cache~ : MemoryCacheBackend,
  fetcher~ : async (String, FetchOptions) -> HttpResponse raise HttpError,
) -> HttpResponse raise HttpError {
  if options.http_method != "GET" {
    return fetcher(url, options)
  }
  let now = now_seconds()
  match cache.lookup(url) {
    Some(entry) =>
      if is_fresh(entry, now) {
        println("[cache] HIT (fresh): " + url)
        return entry_to_response(entry)
      } else {
        println("[cache] STALE (revalidating): " + url)
        let modified_headers : Map[String, String] = {}
        for k, v in options.headers {
          modified_headers[k] = v
        }
        match entry.etag {
          Some(etag) => modified_headers["If-None-Match"] = etag
          None => ()
        }
        match entry.last_modified {
          Some(lm) => modified_headers["If-Modified-Since"] = lm
          None => ()
        }
        let modified_options : FetchOptions = {
          ..options,
          headers: modified_headers,
        }
        let response = fetcher(url, modified_options)
        if response.status == 304 {
          println("[cache] 304 Not Modified: " + url)
          let refreshed : CacheEntry = { ..entry, stored_at: now }
          cache.store(refreshed)
          return entry_to_response(entry)
        }
        let new_entry = build_cache_entry(url, response)
        if !new_entry.directives.no_store {
          cache.store(new_entry)
        }
        return response
      }
    None => {
      println("[cache] MISS: " + url)
      let response = fetcher(url, options)
      let entry = build_cache_entry(url, response)
      if !entry.directives.no_store {
        cache.store(entry)
      }
      return response
    }
  }
}

///|
/// Fetch with transparent HTTP caching (sync version for testing).
/// Only GET requests are cached. The fetcher parameter allows callers to
/// inject any transport function.
pub fn cached_fetch(
  url~ : String,
  options~ : FetchOptions,
  cache~ : MemoryCacheBackend,
  fetcher~ : (String, FetchOptions) -> HttpResponse raise HttpError,
) -> HttpResponse raise HttpError {
  // Only cache GET
  if options.http_method != "GET" {
    return fetcher(url, options)
  }
  let now = now_seconds()
  match cache.lookup(url) {
    Some(entry) =>
      if is_fresh(entry, now) {
        return entry_to_response(entry)
      } else {
        // Stale: conditional request
        let modified_headers : Map[String, String] = {}
        for k, v in options.headers {
          modified_headers[k] = v
        }
        match entry.etag {
          Some(etag) => modified_headers["If-None-Match"] = etag
          None => ()
        }
        match entry.last_modified {
          Some(lm) => modified_headers["If-Modified-Since"] = lm
          None => ()
        }
        let modified_options : FetchOptions = {
          ..options,
          headers: modified_headers,
        }
        let response = fetcher(url, modified_options)
        if response.status == 304 {
          let refreshed : CacheEntry = { ..entry, stored_at: now }
          cache.store(refreshed)
          return entry_to_response(entry)
        }
        let new_entry = build_cache_entry(url, response)
        if !new_entry.directives.no_store {
          cache.store(new_entry)
        }
        return response
      }
    None => {
      let response = fetcher(url, options)
      let entry = build_cache_entry(url, response)
      if !entry.directives.no_store {
        cache.store(entry)
      }
      return response
    }
  }
}
