///|
pub(all) struct PaintCaptureTiming {
  node_layout_ms : Int
  paint_tree_ms : Int
  raster_ms : Int
  png_encode_ms : Int
  rgba_encode_ms : Int
  total_ms : Int
}

///|
pub fn capture_timing_to_json(timing : PaintCaptureTiming) -> Json {
  @protocol.make_object({
    "nodeLayoutMs": Json::number(timing.node_layout_ms.to_double()),
    "paintTreeMs": Json::number(timing.paint_tree_ms.to_double()),
    "rasterMs": Json::number(timing.raster_ms.to_double()),
    "pngEncodeMs": Json::number(timing.png_encode_ms.to_double()),
    "rgbaEncodeMs": Json::number(timing.rgba_encode_ms.to_double()),
    "totalMs": Json::number(timing.total_ms.to_double()),
  })
}

///|
pub fn capture_visual_to_json(visual : @tui_paint_export.VisualStats) -> Json {
  @protocol.make_object({
    "pixelCount": Json::number(visual.pixel_count.to_double()),
    "nonWhitePixels": Json::number(visual.non_white_pixels.to_double()),
    "distinctColors": Json::number(visual.distinct_colors.to_double()),
    "isBlank": Json::boolean(visual.is_blank),
  })
}

///|
pub fn capture_paint_data_to_json(
  width : Int,
  height : Int,
  data : String,
  timing : PaintCaptureTiming,
  visual : @tui_paint_export.VisualStats,
) -> Json {
  @protocol.make_object({
    "width": Json::number(width.to_double()),
    "height": Json::number(height.to_double()),
    "data": Json::string(data),
    "timing": capture_timing_to_json(timing),
    "visual": capture_visual_to_json(visual),
  })
}
