///|
test "paint capture timing serializes stable json keys" {
  let timing : PaintCaptureTiming = {
    node_layout_ms: 1,
    paint_tree_ms: 2,
    raster_ms: 3,
    png_encode_ms: 4,
    rgba_encode_ms: 5,
    total_ms: 15,
  }
  let json = capture_timing_to_json(timing).stringify()
  assert_true(json.contains("\"nodeLayoutMs\":1"))
  assert_true(json.contains("\"paintTreeMs\":2"))
  assert_true(json.contains("\"rasterMs\":3"))
  assert_true(json.contains("\"pngEncodeMs\":4"))
  assert_true(json.contains("\"rgbaEncodeMs\":5"))
  assert_true(json.contains("\"totalMs\":15"))
}
