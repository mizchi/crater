///|
/// Per-session bag of HTTP security state: cookie jar, HTTP cache,
/// authorization state, and CORS preflight cache. Browser emulation
/// state such as user-agent overrides intentionally lives outside this
/// package so HTTP credentials and identity spoofing controls do not
/// share the same mutation surface.
pub struct Profile {
  mut cookie_jar : @cookie_jar.CookieJar
  http_cache : @cache.MemoryCacheBackend
  auth_state : AuthState
  preflight_cache : @cors.PreflightCache
}

///|
/// Default Profile: jar enabled and fresh in-memory caches.
pub fn Profile::default() -> Profile {
  Profile::{
    cookie_jar: @cookie_jar.CookieJar::new(enabled=true),
    http_cache: @cache.MemoryCacheBackend::new(max_entries=1000),
    auth_state: AuthState::default(),
    preflight_cache: @cors.PreflightCache::new(),
  }
}

///|
/// Construct a Profile with explicit HTTP-state overrides. WebDriver
/// sessions use this with `jar_enabled=true` (the default) so login flows
/// work without the operator having to opt in.
pub fn Profile::new(jar_enabled? : Bool = true) -> Profile {
  Profile::{
    cookie_jar: @cookie_jar.CookieJar::new(enabled=jar_enabled),
    http_cache: @cache.MemoryCacheBackend::new(max_entries=1000),
    auth_state: AuthState::default(),
    preflight_cache: @cors.PreflightCache::new(),
  }
}

///|
pub fn Profile::cookie_jar(self : Profile) -> @cookie_jar.CookieJar {
  self.cookie_jar
}

///|
pub fn Profile::set_cookie_jar(
  self : Profile,
  cookie_jar : @cookie_jar.CookieJar,
) -> Unit {
  self.cookie_jar = cookie_jar
}

///|
pub fn Profile::http_cache(self : Profile) -> @cache.MemoryCacheBackend {
  self.http_cache
}

///|
pub fn Profile::auth_state(self : Profile) -> AuthState {
  self.auth_state
}

///|
pub fn Profile::preflight_cache(self : Profile) -> @cors.PreflightCache {
  self.preflight_cache
}
