///|
/// Placeholder for HTTP auth credentials carried by a Profile.
/// P1: empty. Future expansion: basic_credentials, bearer_tokens.
pub(all) struct AuthState {} derive(Debug)

///|
pub impl Show for AuthState with output(_self, logger) {
  logger.write_string("{}")
}

///|
pub fn AuthState::default() -> AuthState {
  AuthState::{  }
}
