///|
pub using @paint_plain {type PaintNode}

///|
pub using @image {type Framebuffer, type DynamicPalette}

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
