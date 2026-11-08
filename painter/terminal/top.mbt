///|
pub using @paint_model {type PaintNode}

///|
pub using @svg {type Scene, type SVGNode}

///|
pub using @raster {type DynamicPalette, type Framebuffer}

///|
pub using @glyph {type GlyphProvider}

///|
pub fn render_paint_node_to_sixel(
  node : PaintNode,
  width : Int32,
  height : Int32,
) -> String {
  @sixel.render_paint_node_to_sixel(node, width, height)
}

///|
pub fn render_svg_to_sixel(
  scene : Scene,
  width : Int32,
  height : Int32,
) -> String {
  @sixel.render_svg_to_sixel(scene, width, height)
}

///|
pub fn render_svg_node_to_sixel(
  node : SVGNode,
  width : Int32,
  height : Int32,
) -> String {
  @sixel.render_svg_node_to_sixel(node, width, height)
}

///|
pub fn render_svg_to_kitty(
  scene : Scene,
  width : Int32,
  height : Int32,
) -> String {
  @kitty.render_svg_to_kitty(scene, width, height)
}

///|
pub fn render_paint_node_to_kitty(
  node : PaintNode,
  width : Int32,
  height : Int32,
) -> String {
  @kitty.render_paint_node_to_kitty(node, width, height)
}

///|
pub fn render_paint_node_to_kitty_scrolled(
  node : PaintNode,
  width : Int32,
  height : Int32,
  scroll_y : Int32,
) -> String {
  @kitty.render_paint_node_to_kitty_scrolled(node, width, height, scroll_y)
}

///|
pub async fn[T : @io.Writer] write_paint_node_to_kitty_scrolled(
  writer : T,
  node : PaintNode,
  width : Int32,
  height : Int32,
  scroll_y : Int32,
) -> Unit {
  @kitty.write_paint_node_to_kitty_scrolled(
    writer, node, width, height, scroll_y,
  )
}

///|
pub fn encode_kitty_put_placement(
  image_id : Int32,
  placement_id : Int32,
  display_cols : Int32,
  display_rows : Int32,
) -> String {
  @kitty.encode_kitty_put_placement(
    image_id, placement_id, display_cols, display_rows,
  )
}

///|
pub fn encode_kitty_delete_placement(
  image_id : Int32,
  placement_id : Int32,
) -> String {
  @kitty.encode_kitty_delete_placement(image_id, placement_id)
}

///|
pub fn encode_png_base64_to_kitty_image(
  b64_data : String,
  display_cols : Int32,
  display_rows : Int32,
  image_id~ : Int32 = 0,
  placement_id~ : Int32 = 0,
) -> String {
  @kitty.encode_png_base64_to_kitty_image(
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
  pixel_width : Int32,
  pixel_height : Int32,
  display_cols : Int32,
  display_rows : Int32,
  image_id~ : Int32 = 0,
  placement_id~ : Int32 = 0,
) -> String {
  @kitty.encode_rgba_base64_to_kitty_image(
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
pub fn render_svg_text_to_kitty_cells(
  svg_text : String,
  render_width : Int32,
  render_height : Int32,
  display_cols : Int32,
  display_rows : Int32,
  image_id~ : Int32 = 0,
  placement_id~ : Int32 = 0,
) -> String {
  @kitty.render_svg_text_to_kitty_cells(
    svg_text,
    render_width,
    render_height,
    display_cols,
    display_rows,
    image_id~,
    placement_id~,
  )
}
