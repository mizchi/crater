///|
/// JavaScript Runtime - WASM stub (not supported)

///|
/// Initialize JS runtime (no-op on WASM)
pub fn init_js_runtime() -> Unit {
  // Not supported on WASM
}

///|
/// Execute JavaScript code (not supported on WASM)
pub fn JsContext::execute(
  self : JsContext,
  code : String,
) -> JsResult raise JsError {
  let _ = self
  let _ = code
  raise NotSupported
}
