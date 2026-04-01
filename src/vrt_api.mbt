///|
fn make_render_context(
  viewport : @types.Size[Double],
) -> @renderer.RenderContext {
  {
    ..@renderer.RenderContext::default(),
    viewport_width: viewport.width,
    viewport_height: viewport.height,
  }
}

///|
pub fn render_html_to_paint_tree(
  html : String,
  viewport : @types.Size[Double],
) -> @paint.PaintNode {
  render_html_to_paint_tree_with_external_css(html, viewport, [])
}

///|
pub fn render_html_to_paint_tree_with_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> @paint.PaintNode {
  let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
    html,
    make_render_context(viewport),
    external_css,
  )
  match
    @paint.from_node_and_layout_with_viewport(
      node,
      layout,
      0.0,
      viewport.height,
      0.0,
    ) {
    Some(paint_tree) => paint_tree
    None => @paint.from_node_and_layout(node, layout)
  }
}

///|
pub fn render_html_to_paint_tree_json(
  html : String,
  viewport : @types.Size[Double],
) -> String {
  render_html_to_paint_tree(html, viewport).to_json_string()
}

///|
pub fn diff_rendered_paint_trees(
  baseline_html : String,
  current_html : String,
  viewport : @types.Size[Double],
) -> @paint.PaintTreeDiff {
  let baseline = render_html_to_paint_tree(baseline_html, viewport)
  let current = render_html_to_paint_tree(current_html, viewport)
  @paint.diff_trees(baseline, current)
}
