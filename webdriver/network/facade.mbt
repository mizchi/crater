///|
/// Compatibility facade for protocol-neutral network state and helper types.
///
/// Keep reusable network primitives in `mizchi/crater-network`. This adapter
/// preserves the existing `mizchi/crater-webdriver-bidi/network` import path
/// while WebDriver-specific command handling remains in `webdriver/webdriver`.
pub using @crater_network {
  type BidiNetworkState,
  type SyntheticFetchCommandResult,
  type SyntheticFetchPlanEntry,
  type SyntheticFetchStepResult,
  type SyntheticNetworkContinueCredentials,
  type SyntheticNetworkCookieOverride,
  type SyntheticNetworkEventInput,
  type SyntheticNetworkResponseOverrides,
}

///|
pub fn utf8_byte_length(value : String) -> Int {
  @crater_network.utf8_byte_length(value)
}

///|
pub fn base64_byte_length(value : String) -> Int {
  @crater_network.base64_byte_length(value)
}

///|
pub fn decode_query_component(value : String) -> String {
  @crater_network.decode_query_component(value)
}
