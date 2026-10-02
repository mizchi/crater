///|
/// JavaScript Runtime - js_engine implementation
///
/// Pure MoonBit JS interpreter. Compiles on all targets:
///   native: moon check -p runtime --target native
///   js:     moon check -p runtime --target js
///   wasm:   moon check -p runtime --target wasm
///
/// Opt-in via: browser.set_js_runtime(jsengine_runtime_ref())
///
/// Alternatives:
///   Default: NativeStubRuntime (NotSupported)
///   V8:      browser/native/js_v8/js_runtime_v8.mbt

///|
priv struct JsEngineRuntime {
  _unused : Int
}

///|
let jsengine_runtime : JsEngineRuntime = { _unused: 0 }

///|
/// Get a reference to the js_engine runtime for opt-in use.
pub fn jsengine_runtime_ref() -> &JsRuntime {
  jsengine_runtime as &JsRuntime
}

///|
impl JsRuntime for JsEngineRuntime with fn init(self : JsEngineRuntime) -> Unit {
  let _ = self
}

///|
impl JsRuntime for JsEngineRuntime with fn execute(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : AsyncExecutionMode,
) -> JsResult raise JsError {
  let _ = (self, context_id, dom, async_mode)
  try {
    let interp = @interpreter.new_interpreter()
    let prog = @parser.parse(code)
    let result = interp.run(prog.stmts)
    interp.run_microtasks()
    interp.run_timers()
    JsResult::new(result.to_string(), interp.host.output, true)
  } catch {
    e => raise JsError::ExecutionError(describe_js_engine_error(e))
  }
}

///|
impl JsRuntime for JsEngineRuntime with fn tick(
  self : JsEngineRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = (self, context_id, dom)
  JsResult::new("false", [], true)
}

///|
fn describe_js_engine_error(err : Error) -> String {
  @js_errors.name_message_if_js_error(err)
  .map_or(err.to_string(), fn(pair) {
    let (name, msg) = pair
    name + ": " + msg
  })
}
