///|
pub using @paint_model {type PaintNode}

///|
pub using @svg {type Scene, type SVGNode}

///|
pub using @image {type DynamicPalette, type Framebuffer, type GlyphProvider}

///|
pub fn render_paint_node_to_sixel(
  node : PaintNode,
  width : Int,
  height : Int,
) -> String {
  @image.render_paint_node_to_sixel(node, width, height)
}

///|
pub fn render_svg_to_sixel(scene : Scene, width : Int, height : Int) -> String {
  @image.render_svg_to_sixel(scene, width, height)
}

///|
pub fn render_svg_node_to_sixel(
  node : SVGNode,
  width : Int,
  height : Int,
) -> String {
  @image.render_svg_node_to_sixel(node, width, height)
}

///|
pub fn render_svg_to_kitty(scene : Scene, width : Int, height : Int) -> String {
  @kitty.render_svg_to_kitty(scene, width, height)
}

///|
pub fn render_paint_node_to_kitty(
  node : PaintNode,
  width : Int,
  height : Int,
) -> String {
  @kitty.render_paint_node_to_kitty(node, width, height)
}

///|
pub fn render_paint_node_to_kitty_scrolled(
  node : PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  @kitty.render_paint_node_to_kitty_scrolled(node, width, height, scroll_y)
}

///|
pub async fn[T : @io.Writer] write_paint_node_to_kitty_scrolled(
  writer : T,
  node : PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> Unit {
  @kitty.write_paint_node_to_kitty_scrolled(
    writer, node, width, height, scroll_y,
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
fn to_kitty_protocol_colors(
  palette : DynamicPalette,
) -> Array[@kitty_protocol.Color] {
  palette.colors.map(fn(color) {
    @kitty_protocol.Color::rgb(color.r, color.g, color.b)
  })
}

///|
fn to_kitty_with_cells(
  fb : Framebuffer,
  palette : DynamicPalette,
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
  let fb = @image.Framebuffer::new(render_width, render_height)
  let palette = @image.DynamicPalette::new()
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
  @image.render_svg_scene_with_camera(scene, fb, palette, camera)
  to_kitty_with_cells(
    fb,
    palette,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}
