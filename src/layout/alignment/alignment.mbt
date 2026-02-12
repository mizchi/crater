///|
/// Shared alignment computation functions for Flex and Grid layouts

///|
/// Compute justify-content positioning for distributing items along an axis
/// Returns (start_offset, gap_between_items)
/// Note: FlexStart/FlexEnd should be resolved by caller before calling this function
///       (i.e., caller handles wrap-reverse by flipping FlexStart/FlexEnd)
pub fn compute_justify(
  justify : @types.Alignment,
  free_space : Double,
  item_count : Int,
) -> (Double, Double) {
  @core.compute_justify(justify, free_space, item_count)
}

///|
/// Compute alignment offset for a single item
/// Used for align-items, align-self, justify-self
pub fn compute_align_offset(
  align : @types.Alignment,
  free_space : Double,
) -> Double {
  @core.compute_align_offset(align, free_space)
}

///|
/// Resolve physical flex axis/reverse flags.
pub fn resolve_flex_axis(
  direction : @types.FlexDirection,
  vertical_writing : Bool,
  rtl : Bool,
) -> @core.FlexAxis {
  @core.resolve_flex_axis(direction, vertical_writing, rtl)
}

///|
/// Axis helpers for mapping physical rect edges to main/cross axes.
pub fn axis_main_start(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @core.axis_main_start(is_row, rect)
}

///|
pub fn axis_main_end(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @core.axis_main_end(is_row, rect)
}

///|
pub fn axis_cross_start(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @core.axis_cross_start(is_row, rect)
}

///|
pub fn axis_cross_end(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @core.axis_cross_end(is_row, rect)
}

///|
pub fn axis_main_sum(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @core.axis_main_sum(is_row, rect)
}

///|
pub fn axis_cross_sum(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @core.axis_cross_sum(is_row, rect)
}

///|
/// Resolve align-self/justify-self into effective alignment.
pub fn resolve_align_self(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
) -> @types.Alignment {
  @core.resolve_align_self(align_self, parent_align)
}

///|
/// Compute alignment offset for align-self (child's override of parent's align-items)
pub fn compute_align_self_offset(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
  free_space : Double,
) -> Double {
  @core.compute_align_self_offset(align_self, parent_align, free_space)
}
