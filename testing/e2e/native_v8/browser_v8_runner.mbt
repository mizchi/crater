///|
/// Public connector for running a `@shell.Browser` on the native V8 runtime.
///
/// This is the supported entry point for "a browser that executes page JS":
/// it wires `V8JsRuntime` + the full mock DOM into a `Browser` via the
/// `set_js_runtime` trait seam, so callers don't repeat the construction dance.
/// With a runtime connected, `execute_scripts` / `execute_inline_js` run page
/// JS through V8, DOM mutations flow back into the `@dom.DomTree`, and the
/// dynamic-rendering layout bridge (`Browser::inject_layout_bridge`) exposes real
/// geometry to that JS.
///
/// Lives in this V8-isolated package on purpose: the `mizchi/v8` dependency must
/// not enter the main module graph (it would drag the native rusty_v8 build into
/// every workspace resolution — see #312), so the connector that needs both the
/// shell and the V8 host sits here rather than in the thin `browser/native`
/// facade or the `js+native` shell.

///|
/// Install the native V8 runtime (backed by the full mock DOM) into `browser`.
/// Enables JS execution as a side effect (`set_js_runtime` flips `enable_js`).
pub fn connect_v8(browser : @shell.Browser) -> Unit {
  let v8 = @js_v8.V8JsRuntime::new_with_mock_dom(@js_v8.full_mock_dom_js())
  browser.set_js_runtime(v8.as_js_runtime())
}

///|
/// Create a `Browser` of the given viewport already connected to the native V8
/// runtime — the one-call setup for V8-backed dynamic rendering.
pub fn new_v8_browser(width : Int, height : Int) -> @shell.Browser {
  let browser = @shell.Browser::new(width, height)
  connect_v8(browser)
  browser
}
