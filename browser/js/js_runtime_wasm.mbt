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
fn allocate_runtime_context_id() -> Int {
  0
}

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
  context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : AsyncExecutionMode,
) -> JsResult raise JsError {
  let _ = self
  let _ = context_id
  let _ = dom
  let _ = code
  let _ = async_mode
  raise NotSupported
}

///|
impl JsRuntime for WasmStubRuntime with tick(
  self : WasmStubRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = self
  let _ = context_id
  let _ = dom
  JsResult::new("false", [], true)
}

///|
/// Initialize JS runtime (no-op on WASM)
pub fn init_js_runtime() -> Unit {
  wasm_stub_runtime.init()
}
