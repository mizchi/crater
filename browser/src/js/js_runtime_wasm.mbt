///|
/// JavaScript Runtime - WASM stub (not supported)

///|
/// WASM stub runtime implementation
priv struct WasmStubRuntime {
  _unused : Int
}

///|
let wasm_stub_runtime : WasmStubRuntime = { _unused: 0 }

///|
fn default_js_runtime() -> &JsRuntime {
  wasm_stub_runtime as &JsRuntime
}

///|
impl JsRuntime for WasmStubRuntime with init(self : WasmStubRuntime) -> Unit {
  let _ = self
  // Not supported on WASM
}

///|
impl JsRuntime for WasmStubRuntime with execute(
  self : WasmStubRuntime,
  dom : @dom.DomTree,
  code : String,
) -> JsResult raise JsError {
  let _ = self
  let _ = dom
  let _ = code
  raise NotSupported
}

///|
/// Initialize JS runtime (no-op on WASM)
pub fn init_js_runtime() -> Unit {
  wasm_stub_runtime.init()
}
