///|
test "wasm facade computes layout json" {
  let json = @crater-wasm.compute_layout(
    "<div style=\"width: 100px; height: 40px;\"></div>", 320, 200,
  )
  assert_true(json.contains("\"rootId\""))
}

///|
test "wasm facade exposes typed yoga controls" {
  ignore(@crater-wasm.create_tree("<div id=\"root\"></div>", 320, 200))
  ignore(@crater-wasm.set_width("div#root", 120.0))
  ignore(@crater-wasm.set_height("div#root", 40.0))
  let result = @crater-wasm.calculate_layout_structured(320.0, 200.0)
  assert_true(result.root_id.length() > 0)
  @crater-wasm.destroy_tree()
}

///|
test "wasm facade exposes accessibility helpers" {
  let snapshot = @crater-wasm.get_aria_snapshot_json(
    "<button>Click me</button>",
  )
  assert_true(snapshot.contains("button"))
}
