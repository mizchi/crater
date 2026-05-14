///|
/// Compatibility facade for WebDriver runtime helpers.
///
/// Runtime implementations own JS FFI and mutable runtime state. Keep the
/// published `webdriver/webdriver` API stable while callers migrate to the
/// narrower `mizchi/crater-webdriver-bidi/runtime` package.

///|
pub fn init_quickjs() -> @core.Any {
  @runtime.init_quickjs()
}

///|
pub fn mark_quickjs_initialized() -> Unit {
  @runtime.mark_quickjs_initialized()
}

///|
pub fn is_quickjs_initialized() -> Bool {
  @runtime.is_quickjs_initialized()
}

///|
pub fn quickjs_eval_sync(expression : String) -> String {
  @runtime.quickjs_eval_sync(expression)
}

///|
pub fn quickjs_eval_async(
  expression : String,
  await_promise : Bool,
) -> @core.Any {
  @runtime.quickjs_eval_async(expression, await_promise)
}

///|
pub fn quickjs_eval_ws(
  socket : @core.Any,
  request_id : Int,
  expression : String,
  ctx_id : String,
) -> Unit {
  @runtime.quickjs_eval_ws(socket, request_id, expression, ctx_id)
}

///|
pub fn quickjs_eval_module(code : String) -> @core.Any {
  @runtime.quickjs_eval_module(code)
}

///|
pub fn quickjs_load(html : String) -> @core.Any {
  @runtime.quickjs_load(html)
}

///|
pub fn quickjs_fetch(url : String) -> @core.Any {
  @runtime.quickjs_fetch(url)
}
