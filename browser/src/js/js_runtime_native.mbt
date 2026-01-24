///|
/// JavaScript Runtime - Native stub (not supported)

///|
/// Initialize JS runtime (no-op on Native)
pub fn init_js_runtime() -> Unit {
  // Not supported on Native
}

///|
/// Execute JavaScript code (not supported on Native)
pub fn JsContext::execute(
  self : JsContext,
  code : String,
) -> JsResult raise JsError {
  let _ = self
  let _ = code
  raise NotSupported
}
