///|
/// Valid network.addIntercept phase names.
fn is_valid_network_intercept_phase(name : String) -> Bool {
  name == "beforeRequestSent" ||
  name == "responseStarted" ||
  name == "authRequired"
}

///|
/// Validate one `network.Header` entry.
fn validate_network_extra_header_entry(entry : Json) -> Json? {
  @crater_network.synthetic_network_validate_header_entry(entry)
}

///|
/// Validate HTTP header name token (`field-name`).
fn is_valid_network_header_name_token(name : String) -> Bool {
  @crater_network.synthetic_network_is_valid_header_name_token(name)
}
