///|
/// Per-origin username/password pair for HTTP Basic / Digest authentication.
/// Written via WebDriver `crater.setOriginCredentials` and consumed by the
/// BiDi runtime fetch shim's 401 Digest retry path.
pub struct OriginCredentials {
  username : String
  password : String
}

///|
pub fn OriginCredentials::username(self : OriginCredentials) -> String {
  self.username
}

///|
pub fn OriginCredentials::password(self : OriginCredentials) -> String {
  self.password
}

///|
/// Per-origin Authorization header storage carried by a Profile.
///
/// Two related-but-separate storage maps live on this state:
///
/// - `origin_headers`: complete pre-formed `Authorization: ...` header
///   values, written via `crater.setOriginAuthorization` and attached
///   to outbound requests when the caller has not already supplied an
///   `Authorization` header. Used for Bearer-style tokens.
///
/// - `origin_credentials`: raw username/password pairs, written via
///   `crater.setOriginCredentials` and used by the fetch shim's 401
///   Digest auto-retry path to compute a Digest response from the
///   challenge the server returned. Never sent unless a 401 challenge
///   arrives.
pub struct AuthState {
  origin_headers : Map[String, String]
  origin_credentials : Map[String, OriginCredentials]
}

///|
/// Show impl deliberately redacts header values AND credentials; only
/// origins are rendered. Prevents secret leaks via panic stack traces or
/// structural debugging.
pub impl Show for AuthState with fn output(self, logger) {
  logger.write_string("AuthState{headers=[")
  let origins = self.list_origins()
  for i = 0; i < origins.length(); i = i + 1 {
    if i > 0 {
      logger.write_string(", ")
    }
    logger.write_string(origins[i])
    logger.write_string(": <redacted>")
  }
  logger.write_string("], credentials=[")
  let cred_origins = self.list_credential_origins()
  for i = 0; i < cred_origins.length(); i = i + 1 {
    if i > 0 {
      logger.write_string(", ")
    }
    logger.write_string(cred_origins[i])
    logger.write_string(": <redacted>")
  }
  logger.write_string("]}")
}

///|
pub fn AuthState::default() -> AuthState {
  AuthState::{
    origin_headers: Map([], capacity=0),
    origin_credentials: Map([], capacity=0),
  }
}

///|
pub fn AuthState::set_origin_header(
  self : AuthState,
  origin : String,
  header_value : String,
) -> Unit {
  self.origin_headers[origin] = header_value
}

///|
pub fn AuthState::clear_origin_header(
  self : AuthState,
  origin : String,
) -> Unit {
  self.origin_headers.remove(origin)
}

///|
pub fn AuthState::header_for_origin(
  self : AuthState,
  origin : String,
) -> String? {
  self.origin_headers.get(origin)
}

///|
pub fn AuthState::list_origins(self : AuthState) -> Array[String] {
  let result = []
  for origin, _ in self.origin_headers {
    result.push(origin)
  }
  result.sort()
  result
}

///|
pub fn AuthState::set_origin_credentials(
  self : AuthState,
  origin : String,
  username : String,
  password : String,
) -> Unit {
  self.origin_credentials[origin] = { username, password }
}

///|
pub fn AuthState::clear_origin_credentials(
  self : AuthState,
  origin : String,
) -> Unit {
  self.origin_credentials.remove(origin)
}

///|
pub fn AuthState::credentials_for_origin(
  self : AuthState,
  origin : String,
) -> OriginCredentials? {
  self.origin_credentials.get(origin)
}

///|
pub fn AuthState::list_credential_origins(self : AuthState) -> Array[String] {
  let result = []
  for origin, _ in self.origin_credentials {
    result.push(origin)
  }
  result.sort()
  result
}
