///|
/// Stable facade API for reusable pure layout primitives.
/// Full crater-compatible kernel lives in `mizchi/layout/kernel`.

///|
pub fn compute_justify(
  justify : @types.Alignment,
  free_space : Double,
  item_count : Int,
) -> (Double, Double) {
  @kernel.compute_justify(justify, free_space, item_count)
}

///|
pub fn compute_align_offset(
  align : @types.Alignment,
  free_space : Double,
) -> Double {
  @kernel.compute_align_offset(align, free_space)
}

///|
pub fn resolve_align_self(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
) -> @types.Alignment {
  @kernel.resolve_align_self(align_self, parent_align)
}

///|
pub fn compute_align_self_offset(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
  free_space : Double,
) -> Double {
  @kernel.compute_align_self_offset(align_self, parent_align, free_space)
}

///|
pub fn resolve_auto_margin_pair(
  start_is_auto : Bool,
  end_is_auto : Bool,
  fixed_start : Double,
  fixed_end : Double,
  remaining_space : Double,
) -> (Double, Double) {
  @kernel.resolve_auto_margin_pair(
    start_is_auto, end_is_auto, fixed_start, fixed_end, remaining_space,
  )
}

///|
pub fn clamp_value(
  value : Double,
  min_val : Double,
  max_val : Double,
) -> Double {
  @kernel.clamp_value(value, min_val, max_val)
}

///|
pub fn clamp_size(
  width : Double,
  height : Double,
  min_w : Double,
  max_w : Double,
  min_h : Double,
  max_h : Double,
) -> (Double, Double) {
  @kernel.clamp_size(width, height, min_w, max_w, min_h, max_h)
}

///|
pub fn clamp_size_with_box_min(
  width : Double,
  height : Double,
  style_min_w : Double,
  max_w : Double,
  style_min_h : Double,
  max_h : Double,
  box_min_w : Double,
  box_min_h : Double,
) -> (Double, Double) {
  @kernel.clamp_size_with_box_min(
    width, height, style_min_w, max_w, style_min_h, max_h, box_min_w, box_min_h,
  )
}

///|
pub fn apply_aspect_ratio_after_constraints(
  width : Double,
  height : Double,
  aspect_ratio : Double?,
  width_has_constraint : Bool,
  height_has_constraint : Bool,
) -> (Double, Double) {
  @kernel.apply_aspect_ratio_after_constraints(
    width, height, aspect_ratio, width_has_constraint, height_has_constraint,
  )
}

///|
pub fn resolve_relative_inset_axis_offset(
  start : @types.Dimension,
  end : @types.Dimension,
  percent_context : Double?,
) -> Double {
  @kernel.resolve_relative_inset_axis_offset(start, end, percent_context)
}

///|
pub fn resolve_relative_inset_offsets(
  inset : @types.Rect[@types.Dimension],
  width_context : Double,
  height_context : Double?,
) -> (Double, Double) {
  @kernel.resolve_relative_inset_offsets(inset, width_context, height_context)
}
