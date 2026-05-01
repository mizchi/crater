///|
pub using @paint_plain {type PaintNode}

///|
pub using @image {type Framebuffer, type DynamicPalette}

///|
pub(all) struct VisualStats {
  pixel_count : Int
  non_white_pixels : Int
  distinct_colors : Int
  is_blank : Bool
}

///|
pub fn raster_to_framebuffer(
  paint_node : PaintNode,
  width : Int,
  height : Int,
) -> (Framebuffer, DynamicPalette) {
  let fb = @image.Framebuffer::new(width, height)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(paint_node, fb, palette)
  (fb, palette)
}

///|
pub fn framebuffer_to_rgba_base64(
  fb : Framebuffer,
  palette : DynamicPalette,
) -> String {
  @image.framebuffer_to_rgba_base64(fb, palette)
}

///|
fn color_rgb_key(c : @image.Color) -> Int {
  c.r * 65536 + c.g * 256 + c.b
}

///|
pub fn framebuffer_visual_stats(
  fb : Framebuffer,
  palette : DynamicPalette,
) -> VisualStats {
  let white_key = 255 * 65536 + 255 * 256 + 255
  let palette_keys : Array[Int] = []
  for color in palette.colors {
    palette_keys.push(color_rgb_key(color))
  }
  let seen_indexes = Array::make(palette_keys.length(), false)
  let mut non_white_pixels = 0
  for idx in fb.pixels {
    if idx >= 0 && idx < palette_keys.length() {
      seen_indexes[idx] = true
      if palette_keys[idx] != white_key {
        non_white_pixels += 1
      }
    } else if seen_indexes.length() > 0 {
      seen_indexes[0] = true
    }
  }
  let mut distinct_colors = 0
  for i in 0..<seen_indexes.length() {
    if seen_indexes[i] {
      distinct_colors += 1
    }
  }
  {
    pixel_count: fb.pixels.length(),
    non_white_pixels,
    distinct_colors,
    is_blank: non_white_pixels == 0,
  }
}

///|
pub fn raster_to_rgba_base64(
  paint_node : PaintNode,
  width : Int,
  height : Int,
) -> String {
  let (fb, palette) = raster_to_framebuffer(paint_node, width, height)
  framebuffer_to_rgba_base64(fb, palette)
}

///|
pub fn to_json_string(paint_node : PaintNode) -> String {
  paint_node.to_json_string()
}
