///|
pub using @http_impl {
  trait HttpCacheBackend,
  type CacheDirectives,
  type CacheEntry,
  type CookieJar,
  type CredentialsMode,
  type FetchOptions,
  type HttpError,
  type HttpResponse,
  type MemoryCacheBackend,
  type ParsedCookie,
  type RequestMode,
  type RequestSandbox,
}

///|
pub fn[CacheBackend : HttpCacheBackend] cached_fetch(
  url~ : String,
  options~ : FetchOptions,
  cache~ : CacheBackend,
  fetcher~ : (String, FetchOptions) -> HttpResponse raise HttpError,
) -> HttpResponse raise HttpError {
  @http_impl.cached_fetch(url~, options~, cache~, fetcher~)
}

///|
pub async fn[CacheBackend : HttpCacheBackend] cached_fetch_async(
  url~ : String,
  options~ : FetchOptions,
  cache~ : CacheBackend,
  fetcher~ : async (String, FetchOptions) -> HttpResponse raise HttpError,
) -> HttpResponse raise HttpError {
  @http_impl.cached_fetch_async(url~, options~, cache~, fetcher~)
}

///|
/// Preserve the async facade even when the selected target resolves the
/// implementation package to its synchronous WASM stub.
#warnings("-unused_async")
pub async fn fetch(
  url : String,
  options? : FetchOptions,
) -> HttpResponse raise HttpError {
  @http_impl.fetch(url, options?)
}

///|
pub fn headers_to_json(headers : Map[String, String]) -> String {
  @http_impl.headers_to_json(headers)
}

///|
pub fn is_cacheable_status(status : Int) -> Bool {
  @http_impl.is_cacheable_status(status)
}

///|
pub fn is_fresh(entry : CacheEntry, now : Double) -> Bool {
  @http_impl.is_fresh(entry, now)
}

///|
pub fn now_seconds() -> Double {
  @http_impl.now_seconds()
}

///|
pub fn parse_cache_control(header : String) -> CacheDirectives {
  @http_impl.parse_cache_control(header)
}

///|
pub fn parse_set_cookie(
  header : String,
  request_host : String,
  request_path : String,
) -> ParsedCookie? {
  @http_impl.parse_set_cookie(header, request_host, request_path)
}
