///|
/// Kitty Graphics Protocol support
/// For terminals like Ghostty, Kitty, WezTerm that support this protocol

///|
fn to_kitty_protocol_colors(
  palette : @raster.DynamicPalette,
) -> Array[@kitty_protocol.Color] {
  palette.colors.map(fn(color) {
    @kitty_protocol.Color::rgb(color.r, color.g, color.b)
  })
}

///|
/// Convert Framebuffer to Kitty Graphics Protocol string
pub fn to_kitty(
  fb : @raster.Framebuffer,
  palette : @raster.DynamicPalette,
) -> String {
  @kitty_protocol.encode_indexed_pixels_to_kitty(
    fb.width,
    fb.height,
    fb.pixels,
    to_kitty_protocol_colors(palette),
  )
}

///|
pub fn to_kitty_with_cells(
  fb : @raster.Framebuffer,
  palette : @raster.DynamicPalette,
  cols : Int,
  rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  @kitty_protocol.encode_indexed_pixels_to_kitty_cells(
    fb.width,
    fb.height,
    fb.pixels,
    to_kitty_protocol_colors(palette),
    cols,
    rows,
    image_id~,
    placement_id~,
  )
}

///|
pub fn encode_kitty_put_placement(
  image_id : Int,
  placement_id : Int,
  display_cols : Int,
  display_rows : Int,
) -> String {
  @kitty_protocol.encode_put_placement(
    image_id, placement_id, display_cols, display_rows,
  )
}

///|
pub fn encode_kitty_delete_placement(
  image_id : Int,
  placement_id : Int,
) -> String {
  @kitty_protocol.encode_delete_placement(image_id, placement_id)
}

///|
pub fn encode_png_base64_to_kitty_image(
  b64_data : String,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  @kitty_protocol.encode_png_base64_to_kitty_image(
    b64_data,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}

///|
pub fn encode_rgba_base64_to_kitty_image(
  b64_data : String,
  pixel_width : Int,
  pixel_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  @kitty_protocol.encode_rgba_base64_to_kitty_image(
    b64_data,
    pixel_width,
    pixel_height,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}

///|
pub async fn[T : @io.Writer] write_kitty(
  writer : T,
  fb : @raster.Framebuffer,
  palette : @raster.DynamicPalette,
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
  let fb = @raster.Framebuffer::new(width, height)
  let palette = @raster.DynamicPalette::new()
  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)
  // Render SVG
  @raster.render_svg_scene(scene, fb, palette)
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
  let fb = @raster.Framebuffer::new(width, height)
  let palette = @raster.DynamicPalette::new()
  fb.fill_rect(0, 0, width, height, 0)
  @raster.render_svg_scene(scene, fb, palette)
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
  let fb = @raster.Framebuffer::new(width, height)
  let palette = @raster.DynamicPalette::new()
  @raster.render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
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
  let fb = @raster.Framebuffer::new(width, height)
  let palette = @raster.DynamicPalette::new()
  @raster.render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
  write_kitty(writer, fb, palette)
}

///|
/// Render SVG scene with camera to Kitty Graphics Protocol string
pub fn render_svg_to_kitty_with_camera(
  scene : @svg.Scene,
  camera : @svg.Camera,
) -> String {
  let fb = @raster.Framebuffer::new(
    camera.viewport_width,
    camera.viewport_height,
  )
  let palette = @raster.DynamicPalette::new()
  // Fill with white background
  fb.fill_rect(0, 0, camera.viewport_width, camera.viewport_height, 0)
  // Render SVG with camera
  @raster.render_svg_scene_with_camera(scene, fb, palette, camera)
  // Convert to Kitty
  to_kitty(fb, palette)
}

///|
pub fn render_svg_text_to_kitty_cells(
  svg_text : String,
  render_width : Int,
  render_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  let svg_node = match @svg.parse_svg(svg_text) {
    Some(node) => node
    None => return ""
  }
  let scene = @svg.Scene::new(svg_node)
  let fb = @raster.Framebuffer::new(render_width, render_height)
  let palette = @raster.DynamicPalette::new()
  fb.fill_rect(0, 0, render_width, render_height, 0)
  let viewbox = @svg.extract_root_view_box(svg_text)
  let (vx, vy, vw, vh) = match viewbox {
    Some(v) => (v.min_x, v.min_y, v.width, v.height)
    None => {
      let bounds = scene.get_bounds()
      (0.0, 0.0, bounds.width(), bounds.height())
    }
  }
  if vw <= 0.0 || vh <= 0.0 {
    return ""
  }
  let camera = @svg.Camera::new(render_width, render_height)
  camera.set_position(vx + vw / 2.0, vy + vh / 2.0)
  let zoom = (render_width.to_double() / vw).min(render_height.to_double() / vh)
  camera.set_zoom(zoom)
  @raster.render_svg_scene_with_camera(scene, fb, palette, camera)
  to_kitty_with_cells(
    fb,
    palette,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}
