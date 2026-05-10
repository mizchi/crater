///|
/// Kitty Graphics Protocol support
/// For terminals like Ghostty, Kitty, WezTerm that support this protocol

///|
fn to_kitty_protocol_colors(
  palette : @image.DynamicPalette,
) -> Array[@kitty_protocol.Color] {
  palette.colors.map(fn(color) {
    @kitty_protocol.Color::rgb(color.r, color.g, color.b)
  })
}

///|
/// Convert Framebuffer to Kitty Graphics Protocol string
pub fn to_kitty(
  fb : @image.Framebuffer,
  palette : @image.DynamicPalette,
) -> String {
  @kitty_protocol.encode_indexed_pixels_to_kitty(
    fb.width,
    fb.height,
    fb.pixels,
    to_kitty_protocol_colors(palette),
  )
}

///|
pub async fn[T : @io.Writer] write_kitty(
  writer : T,
  fb : @image.Framebuffer,
  palette : @image.DynamicPalette,
) -> Unit {
  @kitty_protocol.write_indexed_pixels_to_kitty(
    writer,
    fb.width,
    fb.height,
    fb.pixels,
    to_kitty_protocol_colors(palette),
  )
}

///|
/// Render SVG scene to Kitty Graphics Protocol string
pub fn render_svg_to_kitty(
  scene : @svg.Scene,
  width : Int,
  height : Int,
) -> String {
  let fb = @image.Framebuffer::new(width, height)
  let palette = @image.DynamicPalette::new()
  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)
  // Render SVG
  @image.render_svg_scene(scene, fb, palette)
  // Convert to Kitty
  to_kitty(fb, palette)
}

///|
pub async fn[T : @io.Writer] write_svg_to_kitty(
  writer : T,
  scene : @svg.Scene,
  width : Int,
  height : Int,
) -> Unit {
  let fb = @image.Framebuffer::new(width, height)
  let palette = @image.DynamicPalette::new()
  fb.fill_rect(0, 0, width, height, 0)
  @image.render_svg_scene(scene, fb, palette)
  write_kitty(writer, fb, palette)
}

///|
/// Render SVG node to Kitty Graphics Protocol string
pub fn render_svg_node_to_kitty(
  node : @svg.SVGNode,
  width : Int,
  height : Int,
) -> String {
  let scene = @svg.Scene::new(node)
  render_svg_to_kitty(scene, width, height)
}

///|
/// Render PaintNode to Kitty Graphics Protocol string
pub fn render_paint_node_to_kitty(
  node : @paint_model.PaintNode,
  width : Int,
  height : Int,
) -> String {
  render_paint_node_to_kitty_scrolled(node, width, height, 0)
}

///|
/// Render PaintNode to Kitty Graphics Protocol string with scroll offset
pub fn render_paint_node_to_kitty_scrolled(
  node : @paint_model.PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  let fb = @image.Framebuffer::new(width, height)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
  // Convert to Kitty
  to_kitty(fb, palette)
}

///|
pub async fn[T : @io.Writer] write_paint_node_to_kitty_scrolled(
  writer : T,
  node : @paint_model.PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> Unit {
  let fb = @image.Framebuffer::new(width, height)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
  write_kitty(writer, fb, palette)
}

///|
/// Render SVG scene with camera to Kitty Graphics Protocol string
pub fn render_svg_to_kitty_with_camera(
  scene : @svg.Scene,
  camera : @svg.Camera,
) -> String {
  let fb = @image.Framebuffer::new(
    camera.viewport_width,
    camera.viewport_height,
  )
  let palette = @image.DynamicPalette::new()
  // Fill with white background
  fb.fill_rect(0, 0, camera.viewport_width, camera.viewport_height, 0)
  // Render SVG with camera
  @image.render_svg_scene_with_camera(scene, fb, palette, camera)
  // Convert to Kitty
  to_kitty(fb, palette)
}
