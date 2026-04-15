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
