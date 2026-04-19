///|
pub using @paint_model {type PaintNode, type PaintProperties}

///|
pub using @paint_diff {
  type PaintLayoutShift,
  type PaintPropertyChange,
  type PaintTreeDiff,
}

///|
pub using @paint_scroll {type ScrollableElement, type ScrollableHitResult}

///|
pub using @svg {
  type BoundingBox,
  type Camera,
  type Color,
  type PathCommand,
  type RenderContext,
  type Scene,
  type SVGNode,
  type Transform,
}

///|
pub using @image {type DynamicPalette, type Framebuffer, type GlyphProvider}

///|
pub fn from_layout(layout : @types.Layout) -> PaintNode {
  @paint.from_layout(layout)
}

///|
pub fn from_node_and_layout(
  node : @node.Node,
  layout : @types.Layout,
) -> PaintNode {
  @paint.from_node_and_layout(node, layout)
}

///|
pub fn diff_trees(before : PaintNode, after : PaintNode) -> PaintTreeDiff {
  @paint.diff_trees(before, after)
}

///|
pub fn flatten_for_rendering(node : PaintNode) -> Array[PaintNode] {
  @paint.flatten_for_rendering(node)
}

///|
pub fn collect_scrollable_elements(
  node : PaintNode,
) -> Array[ScrollableElement] {
  @paint.collect_scrollable_elements(node)
}

///|
pub fn find_scrollable_at(
  node : PaintNode,
  x : Double,
  y : Double,
  viewport_width : Double,
  viewport_height : Double,
) -> ScrollableHitResult? {
  @paint.find_scrollable_at(node, x, y, viewport_width, viewport_height)
}

///|
pub fn create_svg_layout(
  tag : String,
  attributes : Array[(String, String)],
  width : Double,
  available_height? : Double,
) -> @types.Layout {
  @layout_svg.create_svg_layout(tag, attributes, width, available_height)
}

///|
pub fn attributes_to_svg_node(
  tag : String,
  attributes : Array[(String, String)],
) -> SVGNode {
  @layout_svg.attributes_to_svg_node(tag, attributes)
}

///|
pub fn parse_svg(svg_str : String) -> SVGNode? {
  @svg.parse_svg(svg_str)
}

///|
pub fn rect(
  id : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> SVGNode {
  @svg.rect(id, x, y, width, height)
}

///|
pub fn circle(id : String, cx : Double, cy : Double, r : Double) -> SVGNode {
  @svg.circle(id, cx, cy, r)
}

///|
pub fn line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> SVGNode {
  @svg.line(id, x1, y1, x2, y2)
}

///|
pub fn path(id : String, d : String) -> SVGNode {
  @svg.path(id, d)
}

///|
pub fn text(
  id : String,
  x : Double,
  y : Double,
  content : String,
  font_size : Double,
) -> SVGNode {
  @svg.text(id, x, y, content, font_size)
}

///|
pub fn group(id : String, children : Array[SVGNode]) -> SVGNode {
  @svg.group(id, children)
}

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
