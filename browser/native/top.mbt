///|
pub using @js_v8 {type V8JsRuntime}

///|
pub fn full_mock_dom_js() -> String {
  @js_v8.full_mock_dom_js()
}

///|
pub fn minimal_mock_dom_js() -> String {
  @js_v8.minimal_mock_dom_js()
}

///|
pub fn preact_bundle_js() -> String {
  @assets.preact_bundle_js()
}

///|
pub fn react_bundle_js() -> String {
  @assets.react_bundle_js()
}

///|
pub fn read_file_to_string_via_eval(path : String) -> String? {
  @assets.read_file_to_string_via_eval(path)
}
