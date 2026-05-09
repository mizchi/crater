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
