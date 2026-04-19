///|
pub using @renderer_api {
  type CssMutation,
  type CssMutationAction,
  type RenderVariant,
  type RenderVariantResult,
}

///|
pub using @core_subset_pkg {type CoreIssue, type CoreComputeResult}

///|
/// Compute layout through the dedicated layout package boundary.
pub fn compute_layout(
  node : @layout.Node,
  viewport : @types.Size[Double],
) -> @types.Layout {
  @layout.compute_layout(node, viewport)
}

///|
/// Compute layout with warnings through the layout package boundary.
pub fn compute_layout_with_warnings(
  node : @layout.Node,
  viewport : @types.Size[Double],
) -> @types.LayoutResult {
  @layout.compute_layout_with_warnings(node, viewport)
}

///|
/// Compute block layout directly
pub fn compute_block_layout(
  node : @layout.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  @layout.compute_block_layout(node, ctx)
}

///|
/// Compute flex layout directly
pub fn compute_flex_layout(
  node : @layout.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  @layout.compute_flex_layout(node, ctx)
}

///|
pub fn validate_core_subset(node : @layout.Node) -> Array[CoreIssue] {
  @core_subset_pkg.validate_core_subset(node)
}

///|
pub fn compute_core_layout(
  node : @layout.Node,
  viewport : @types.Size[Double],
) -> CoreComputeResult {
  @core_subset_pkg.compute_core_layout(node, viewport)
}

///|
/// Compute element shift (CLS)
pub fn compute_element_shift(
  before : @types.BoundingRect,
  after : @types.BoundingRect,
  viewport : @types.Size[Double],
) -> @webvitals.LayoutShift {
  @webvitals.compute_element_shift(before, after, viewport)
}

///|
/// Compute total CLS score
pub fn compute_total_cls(
  before : Array[@types.BoundingRect],
  after : Array[@types.BoundingRect],
  viewport : @types.Size[Double],
) -> Double {
  @webvitals.compute_total(before, after, viewport)
}

///|
pub fn render_html_to_paint_tree(
  html : String,
  viewport : @types.Size[Double],
) -> @paint.PaintNode {
  @renderer_api.render_html_to_paint_tree(html, viewport)
}

///|
pub fn render_html_to_paint_tree_with_external_css(
  html : String,
  viewport : @types.Size[Double],
  external_css : Array[String],
) -> @paint.PaintNode {
  @renderer_api.render_html_to_paint_tree_with_external_css(
    html, viewport, external_css,
  )
}

///|
pub fn render_html_to_paint_tree_json(
  html : String,
  viewport : @types.Size[Double],
) -> String {
  @renderer_api.render_html_to_paint_tree_json(html, viewport)
}

///|
pub fn diff_rendered_paint_trees(
  baseline_html : String,
  current_html : String,
  viewport : @types.Size[Double],
) -> @paint.PaintTreeDiff {
  @renderer_api.diff_rendered_paint_trees(baseline_html, current_html, viewport)
}

///|
pub fn render_html_batch_variants(
  html : String,
  viewport : @types.Size[Double],
  variants : Array[RenderVariant],
) -> Array[RenderVariantResult] {
  @renderer_api.render_html_batch_variants(html, viewport, variants)
}
