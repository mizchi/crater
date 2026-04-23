///|
/// JavaScript Runtime - Native target
///
/// Default is stub (NotSupported). To enable V8, use JsContext::new_with_runtime()
/// with the V8JsRuntime from mizchi/crater-browser-native/js_v8.

///|
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
}

///|
impl JsRuntime for NativeStubRuntime with execute(
  self : NativeStubRuntime,
  context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : AsyncExecutionMode,
) -> JsResult raise JsError {
  let _ = (self, context_id, dom, code, async_mode)
  raise NotSupported
}

///|
impl JsRuntime for NativeStubRuntime with tick(
  self : NativeStubRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = (self, context_id, dom)
  JsResult::new("false", [], true)
}

///|
pub fn init_js_runtime() -> Unit {
  native_stub_runtime.init()
}
