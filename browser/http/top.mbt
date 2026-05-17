///|
pub using @http_impl {
  type CredentialsMode,
  type FetchOptions,
  type HttpError,
  type HttpResponse,
  type RequestMode,
  type RequestSandbox,
}

///|
pub using @cache {
  trait HttpCacheBackend,
  type CacheDirectives,
  type CacheEntry,
  type MemoryCacheBackend,
}

///|
pub using @cookie_jar {type CookieJar, type ParsedCookie}

///|
pub using @profile {type Profile, type AuthState}

///|
pub using @samesite {type SiteContext}

///|
pub using @cors {
  type CorsDecision,
  type PreflightRequest,
  type PreflightEntry,
  type PreflightCache,
}

///|
pub fn classify_request(
  url~ : String,
  origin~ : String,
  mode~ : RequestMode,
  method~ : String,
  headers~ : Map[String, String],
) -> CorsDecision {
  @cors.classify_request(url~, origin~, mode~, method~, headers~)
}

///|
pub fn validate_preflight_response(
  request : PreflightRequest,
  response : HttpResponse,
) -> Result[Unit, String] {
  @cors.validate_preflight_response(request, response)
}

///|
pub fn validate_actual_response(
  request_url~ : String,
  origin~ : String,
  credentials~ : CredentialsMode,
  response~ : HttpResponse,
) -> Result[Unit, String] {
  @cors.validate_actual_response(request_url~, origin~, credentials~, response~)
}

///|
pub fn classify_site_context(
  request_origin : String,
  cookie_domain : String,
) -> SiteContext {
  @samesite.classify_site_context(request_origin, cookie_domain)
}

///|
pub fn should_attach_cookie(
  cookie : @cookie_jar.ParsedCookie,
  site_context : SiteContext,
  is_top_level_navigation : Bool,
) -> Bool {
  @samesite.should_attach_cookie(cookie, site_context, is_top_level_navigation)
}

///|
pub fn[CacheBackend : HttpCacheBackend] cached_fetch(
  url~ : String,
  options~ : FetchOptions,
  cache~ : CacheBackend,
  fetcher~ : (String, FetchOptions) -> HttpResponse raise HttpError,
) -> HttpResponse raise HttpError {
  @cache.cached_fetch(url~, options~, cache~, fetcher~)
}

///|
pub async fn[CacheBackend : HttpCacheBackend] cached_fetch_async(
  url~ : String,
  options~ : FetchOptions,
  cache~ : CacheBackend,
  fetcher~ : async (String, FetchOptions) -> HttpResponse raise HttpError,
) -> HttpResponse raise HttpError {
  @cache.cached_fetch_async(url~, options~, cache~, fetcher~)
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
  @cache.is_cacheable_status(status)
}

///|
pub fn is_fresh(entry : CacheEntry, now : Double) -> Bool {
  @cache.is_fresh(entry, now)
}

///|
pub fn now_seconds() -> Double {
  @cache.now_seconds()
}

///|
pub fn parse_cache_control(header : String) -> CacheDirectives {
  @cache.parse_cache_control(header)
}

///|
pub fn parse_set_cookie(
  header : String,
  request_host : String,
  request_path : String,
) -> ParsedCookie? {
  @cookie_jar.parse_set_cookie(header, request_host, request_path)
}
