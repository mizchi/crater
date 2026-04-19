///|
pub fn render_html_to_json_for_wpt(
  html : String,
  width : Int,
  height : Int,
) -> String {
  @wpt_runtime.renderHtmlToJsonForWpt(html, width, height)
}

///|
pub fn default_dispatch() -> @node.DispatchFn {
  @taffy_compat.default_dispatch()
}

///|
pub fn assert_approx(actual : Double, expected : Double) -> Unit raise {
  @taffy_compat.assert_approx(actual, expected)
}
