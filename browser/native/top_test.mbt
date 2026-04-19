///|
test "browser native facade exposes mock dom sources" {
  let full = full_mock_dom_js()
  let minimal = minimal_mock_dom_js()

  assert_true(full.contains("attachShadow"))
  assert_true(minimal.contains("document"))
}

///|
test "browser native facade exposes bundled runtimes" {
  assert_true(preact_bundle_js().contains("preact"))
  assert_true(react_bundle_js().contains("React"))
}
