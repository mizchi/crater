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
  @sixel.render_paint_node_to_sixel(node, width, height)
}

///|
pub fn render_svg_to_sixel(scene : Scene, width : Int, height : Int) -> String {
  @sixel.render_svg_to_sixel(scene, width, height)
}

///|
pub fn render_svg_node_to_sixel(
  node : SVGNode,
  width : Int,
  height : Int,
) -> String {
  @sixel.render_svg_node_to_sixel(node, width, height)
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
  @kitty.encode_kitty_put_placement(
    image_id, placement_id, display_cols, display_rows,
  )
}

///|
pub fn encode_kitty_delete_placement(
  image_id : Int,
  placement_id : Int,
) -> String {
  @kitty.encode_kitty_delete_placement(image_id, placement_id)
}

///|
pub fn encode_png_base64_to_kitty_image(
  b64_data : String,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
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
  pixel_width : Int,
  pixel_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
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
  render_width : Int,
  render_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
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
