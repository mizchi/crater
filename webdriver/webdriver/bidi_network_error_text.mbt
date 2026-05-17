///|
/// Strip CRLF, ANSI CSI escapes, and other control characters from
/// server-controlled strings before they reach WebDriver client logs.
/// Defends against log injection / log forging from malicious response
/// headers that propagate via HttpError reason strings.
fn sanitize_for_log(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let code = c.to_int()
    if code == 0x1b {
      // ESC — skip the entire CSI sequence (ESC [ ... terminating-letter)
      i = i + 1
      if i < chars.length() && chars[i] == '[' {
        i = i + 1
        while i < chars.length() {
          let cc = chars[i]
          let ccode = cc.to_int()
          i = i + 1
          // CSI terminator is any byte in 0x40-0x7e
          if ccode >= 0x40 && ccode <= 0x7e {
            break
          }
        }
      }
    } else if code == 0x09 {
      // Allow tab
      buf.write_char(c)
      i = i + 1
    } else if code < 0x20 {
      // Drop all other control characters (CR, LF, BEL, BS, …)
      i = i + 1
    } else {
      buf.write_char(c)
      i = i + 1
    }
  }
  buf.to_string()
}

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
///
/// Reason strings from `CorsBlocked`, `PreflightFailed`, and `CorsError` are
/// sanitized via `sanitize_for_log` before interpolation to prevent log
/// injection from malicious server-controlled values.
pub fn error_text_of(e : @http.HttpError) -> String {
  match e {
    @http.HttpError::CorsBlocked(reason) => "CORS: " + sanitize_for_log(reason)
    @http.HttpError::PreflightFailed(reason) =>
      "CORS preflight: " + sanitize_for_log(reason)
    @http.HttpError::NetworkError(msg) => "NetworkError: " + msg
    @http.HttpError::InvalidUrl(url) => "InvalidUrl: " + url
    @http.HttpError::TimeoutError => "TimeoutError"
    @http.HttpError::CorsError(msg) => "CorsError: " + sanitize_for_log(msg)
    @http.HttpError::SandboxError(msg) => "SandboxError: " + msg
  }
}
