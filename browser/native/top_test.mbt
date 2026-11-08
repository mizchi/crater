///|
test "browser native facade exposes mock dom sources" {
  let full = @crater-browser-native.full_mock_dom_js()
  let minimal = @crater-browser-native.minimal_mock_dom_js()

  assert_true(full.contains("attachShadow"))
  assert_true(minimal.contains("document"))
}

///|
test "browser native facade exposes bundled runtimes" {
  assert_true(@crater-browser-native.preact_bundle_js().contains("preact"))
  assert_true(@crater-browser-native.react_bundle_js().contains("React"))
}
