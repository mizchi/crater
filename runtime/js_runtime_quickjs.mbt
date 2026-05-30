///|
/// JavaScript Runtime - QuickJS implementation
///
/// Uses quickjs-emscripten for sandboxed JavaScript execution.
/// DOM operations are queued and executed after JS completes.

///|
/// Global state for context management
priv struct RuntimeState {
  mut counter : Int
  contexts : Map[Int, @dom.DomTree]
  mut initialized : Bool
}

///|
/// Global runtime state
let runtime_state : RuntimeState = {
  counter: 0,
  contexts: {},
  initialized: false,
}

///|
/// Allocate a stable runtime context id
fn allocate_runtime_context_id() -> Int {
  let id = runtime_state.counter
  runtime_state.counter = runtime_state.counter + 1
  id
}

///|
/// Update DomTree mapping for an existing context id
fn update_context(id : Int, dom : @dom.DomTree) -> Unit {
  runtime_state.contexts.set(id, dom)
}

///|
/// QuickJS runtime implementation
priv struct QuickJsRuntime {
  _unused : Int
}

///|
let quickjs_runtime : QuickJsRuntime = { _unused: 0 }

///|
fn default_js_runtime() -> &JsRuntime {
  quickjs_runtime as &JsRuntime
}

///|
impl JsRuntime for QuickJsRuntime with fn init(self : QuickJsRuntime) -> Unit {
  let _ = self
  if !runtime_state.initialized {
    let success = quickjs_init()
    if success {
      runtime_state.initialized = true
    }
  }
}

///|
impl JsRuntime for QuickJsRuntime with fn execute(
  self : QuickJsRuntime,
  context_id : Int,
  dom : @dom.DomTree,
  code : String,
  async_mode : AsyncExecutionMode,
) -> JsResult raise JsError {
  let _ = self
  update_context(context_id, dom)

  // Generate DOM initialization code from DomTree
  // This populates the mock DOM with actual HTML content
  let dom_init_code = create_dom_init_code(dom)

  // Execute against a stable runtime context so top-level JS state survives.
  let flush_async = match async_mode {
    ImmediateFlush => true
    DeferredFlush => false
  }
  let result_json = quickjs_execute_with_mock_dom(
    context_id, dom_init_code, code, flush_async,
  )

  // Parse result
  let (result, dom_ops) = parse_js_result_with_ops(result_json)

  // Apply DOM operations to actual DomTree
  apply_dom_ops(dom, dom_ops)

  result
}

///|
impl JsRuntime for QuickJsRuntime with fn tick(
  self : QuickJsRuntime,
  context_id : Int,
  dom : @dom.DomTree,
) -> JsResult raise JsError {
  let _ = self
  update_context(context_id, dom)
  let result_json = quickjs_tick_with_mock_dom(context_id)
  let (result, dom_ops) = parse_js_result_with_ops(result_json)
  apply_dom_ops(dom, dom_ops)
  result
}

///|
/// Initialize JS runtime with QuickJS
pub fn init_js_runtime() -> Unit {
  quickjs_runtime.init()
}
