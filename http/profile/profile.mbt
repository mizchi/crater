///|
/// Per-session bag of user-agent override, cookie jar, HTTP cache, and
/// auth state. Bundled so layers above can pass a single Profile value
/// instead of threading each field separately. P1 keeps the Profile
/// single per BrowserState; per-userContext partitioning is a P2
/// scenario.
pub(all) struct Profile {
  mut user_agent : String?
  mut cookie_jar : @cookie_jar.CookieJar
  http_cache : @cache.MemoryCacheBackend
  auth_state : AuthState
  preflight_cache : @cors.PreflightCache
}

///|
/// Default Profile: jar enabled, no UA override, fresh in-memory cache.
pub fn Profile::default() -> Profile {
  Profile::{
    user_agent: None,
    cookie_jar: @cookie_jar.CookieJar::new(enabled=true),
    http_cache: @cache.MemoryCacheBackend::new(max_entries=1000),
    auth_state: AuthState::default(),
    preflight_cache: @cors.PreflightCache::new(),
  }
}

///|
/// Construct a Profile with explicit overrides. WebDriver sessions
/// use this with `jar_enabled=true` (the default) so login flows
/// work without the operator having to opt in.
pub fn Profile::new(
  user_agent? : String,
  jar_enabled? : Bool = true,
) -> Profile {
  Profile::{
    user_agent,
    cookie_jar: @cookie_jar.CookieJar::new(enabled=jar_enabled),
    http_cache: @cache.MemoryCacheBackend::new(max_entries=1000),
    auth_state: AuthState::default(),
    preflight_cache: @cors.PreflightCache::new(),
  }
}

///|
/// Returns the override string when set, else None — the caller
/// (typically the WebDriver emulation layer) decides what to fall back
/// to so this sub-package stays free of webdriver-side dependencies.
pub fn Profile::effective_user_agent(self : Profile) -> String? {
  self.user_agent
}
