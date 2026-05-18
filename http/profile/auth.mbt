///|
/// Per-origin Authorization header storage carried by a Profile.
/// Header values are written via WebDriver `crater.setOriginAuthorization`
/// and attached by the BiDi runtime fetch shim when the caller has not
/// already supplied an `Authorization` header.
pub(all) struct AuthState {
  mut origin_headers : Map[String, String]
}

///|
/// Show impl deliberately redacts header values; only origins are
/// rendered. Prevents secret leaks via panic stack traces or
/// structural debugging.
pub impl Show for AuthState with output(self, logger) {
  logger.write_string("AuthState{")
  let origins = self.list_origins()
  for i = 0; i < origins.length(); i = i + 1 {
    if i > 0 {
      logger.write_string(", ")
    }
    logger.write_string(origins[i])
    logger.write_string(": <redacted>")
  }
  logger.write_string("}")
}

///|
pub fn AuthState::default() -> AuthState {
  AuthState::{ origin_headers: Map([], capacity=0) }
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
