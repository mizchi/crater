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

///|
test "paint capture data result serializes payload timing and visual" {
  let timing : PaintCaptureTiming = {
    node_layout_ms: 1,
    paint_tree_ms: 2,
    raster_ms: 3,
    png_encode_ms: 0,
    rgba_encode_ms: 4,
    total_ms: 10,
  }
  let visual : @tui_paint_export.VisualStats = {
    pixel_count: 100,
    non_white_pixels: 25,
    distinct_colors: 3,
    is_blank: false,
  }
  let json = capture_paint_data_to_json(10, 20, "rgba", timing, visual).stringify()
  assert_true(json.contains("\"width\":10"))
  assert_true(json.contains("\"height\":20"))
  assert_true(json.contains("\"data\":\"rgba\""))
  assert_true(json.contains("\"rgbaEncodeMs\":4"))
  assert_true(json.contains("\"nonWhitePixels\":25"))
}

///|
test "paint capture tree result serializes tree string" {
  let tree =
    #|{"node":"root"}
  let json = capture_paint_tree_to_json(30, 40, tree).stringify()
  assert_true(json.contains("\"width\":30"))
  assert_true(json.contains("\"height\":40"))
  assert_true(json.contains("\"paintTree\":\"{\\\"node\\\":\\\"root\\\"}\""))
}

///|
test "paint capture log messages keep stable timing fields" {
  let timing : PaintCaptureTiming = {
    node_layout_ms: 1,
    paint_tree_ms: 2,
    raster_ms: 3,
    png_encode_ms: 4,
    rgba_encode_ms: 5,
    total_ms: 15,
  }
  let visual : @tui_paint_export.VisualStats = {
    pixel_count: 100,
    non_white_pixels: 25,
    distinct_colors: 3,
    is_blank: false,
  }
  let paint_log = capture_paint_data_log_message(timing, visual)
  assert_true(paint_log.contains("capturePaintData: node_layout=1ms"))
  assert_true(paint_log.contains("rgba_encode=5ms"))
  assert_true(paint_log.contains("non_white=25 distinct=3"))
  let screenshot_log = capture_screenshot_data_log_message(timing)
  assert_true(screenshot_log.contains("captureScreenshotData: node_layout=1ms"))
  assert_true(screenshot_log.contains("png_encode=4ms"))
}
