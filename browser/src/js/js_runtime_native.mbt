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
  dom : @dom.DomTree,
  code : String,
) -> JsResult raise JsError {
  let _ = self
  let _ = dom
  let _ = code
  raise NotSupported
}

///|
/// Initialize JS runtime (no-op on Native)
pub fn init_js_runtime() -> Unit {
  native_stub_runtime.init()
}
