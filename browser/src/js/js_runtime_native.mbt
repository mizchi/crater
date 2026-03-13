///|
/// JavaScript Runtime - Native stub (not supported)

///|
/// Native stub runtime implementation
priv struct NativeStubRuntime {
  _unused : Int
}

///|
let native_stub_runtime : NativeStubRuntime = { _unused: 0 }

///|
fn allocate_runtime_context_id() -> Int {
  0
}

///|
fn default_js_runtime() -> &JsRuntime {
  native_stub_runtime as &JsRuntime
}

///|
impl JsRuntime for NativeStubRuntime with init(self : NativeStubRuntime) -> Unit {
  let _ = self
  // Not supported on Native
}

///|
impl JsRuntime for NativeStubRuntime with execute(
  self : NativeStubRuntime,
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
impl JsRuntime for NativeStubRuntime with tick(
  self : NativeStubRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = self
  let _ = context_id
  let _ = dom
  JsResult::new("false", [], true)
}

///|
/// Initialize JS runtime (no-op on Native)
pub fn init_js_runtime() -> Unit {
  native_stub_runtime.init()
}
