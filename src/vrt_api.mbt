///|
pub fn render_html_to_paint_tree(
  html : String,
  viewport : @types.Size[Double],
) -> @paint.PaintNode {
  @vrt.render_html_to_paint_tree(html, viewport)
}

///|
pub fn render_html_to_paint_tree_with_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> @paint.PaintNode {
  @vrt.render_html_to_paint_tree_with_external_css(html, viewport, external_css)
}

///|
pub fn render_html_to_paint_tree_json(
  html : String,
  viewport : @types.Size[Double],
) -> String {
  @vrt.render_html_to_paint_tree_json(html, viewport)
}

///|
pub fn diff_rendered_paint_trees(
  baseline_html : String,
  current_html : String,
  viewport : @types.Size[Double],
) -> @paint.PaintTreeDiff {
  @vrt.diff_rendered_paint_trees(baseline_html, current_html, viewport)
}
