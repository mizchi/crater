///|
/// Map an `@http.HttpError` into the BiDi `errorText` string that
/// `network.fetchError` / `network.responseCompleted` payloads expose to the
/// driver.
///
/// The two CORS variants get distinguishing prefixes so a Playwright /
/// WebDriver client can tell a preflight rejection apart from the actual
/// request being blocked:
///
/// - `CorsBlocked(reason)`     -> `"CORS: <reason>"`
/// - `PreflightFailed(reason)` -> `"CORS preflight: <reason>"`
///
/// Existing variants retain their `Show` form so legacy callers see the same
/// errorText as before.
pub fn error_text_of(e : @http.HttpError) -> String {
  match e {
    @http.HttpError::CorsBlocked(reason) => "CORS: " + reason
    @http.HttpError::PreflightFailed(reason) => "CORS preflight: " + reason
    @http.HttpError::NetworkError(msg) => "NetworkError: " + msg
    @http.HttpError::InvalidUrl(url) => "InvalidUrl: " + url
    @http.HttpError::TimeoutError => "TimeoutError"
    @http.HttpError::CorsError(msg) => "CorsError: " + msg
    @http.HttpError::SandboxError(msg) => "SandboxError: " + msg
  }
}
