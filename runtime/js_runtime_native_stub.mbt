///|
/// JavaScript Runtime - Native target
///
/// Default stub raises NotSupported. Opt-in backends:
///
///   - js_engine (pure MoonBit): browser.set_js_runtime(jsengine_runtime_ref())
///     See runtime/js_runtime_jsengine.mbt
///
///   - V8 (native FFI):          browser.set_js_runtime(V8JsRuntime::new())
///     See browser/native/js_v8/js_runtime_v8.mbt

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
impl JsRuntime for NativeStubRuntime with fn init(self : NativeStubRuntime) -> Unit {
  let _ = self
}

///|
impl JsRuntime for NativeStubRuntime with fn execute(
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
impl JsRuntime for NativeStubRuntime with fn tick(
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
