///|
/// Compatibility facade re-exporting the HTTP/REST session manager from
/// `mizchi/crater-webdriver-bidi/server`. Keeps `@webdriver.SessionManager`
/// usages compiling while the real implementation lives in the smaller
/// `server` package.
pub using @server {type SessionManager, type SessionState}
