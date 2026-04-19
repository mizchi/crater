// User implementation for layout
// Edit this file to implement the interface

///|
fn to_layout_alignment(a : Alignment) -> @layout_types.Alignment {
  match a {
    Start => @layout_types.Start
    End => @layout_types.End
    FlexStart => @layout_types.FlexStart
    FlexEnd => @layout_types.FlexEnd
    Center => @layout_types.Center
    SpaceBetween => @layout_types.SpaceBetween
    SpaceAround => @layout_types.SpaceAround
    SpaceEvenly => @layout_types.SpaceEvenly
    Stretch => @layout_types.Stretch
    Baseline => @layout_types.Baseline
  }
}

///|
fn from_layout_alignment(a : @layout_types.Alignment) -> Alignment {
  match a {
    Start => Start
    End => End
    FlexStart => FlexStart
    FlexEnd => FlexEnd
    Center => Center
    SpaceBetween => SpaceBetween
    SpaceAround => SpaceAround
    SpaceEvenly => SpaceEvenly
    Stretch => Stretch
    Baseline => Baseline
  }
}

///|
fn to_layout_align_self(a : AlignSelf) -> @layout_types.AlignSelf {
  match a {
    Auto => @layout_types.Auto
    Start => @layout_types.Start
    End => @layout_types.End
    Center => @layout_types.Center
    Stretch => @layout_types.Stretch
    Baseline => @layout_types.Baseline
  }
}

///|
/// Export: apply-aspect-ratio
pub fn apply_aspect_ratio(
  width : Double,
  height : Double,
  has_ratio : Bool,
  ratio_value : Double,
  width_changed : Bool,
  height_changed : Bool,
) -> Pair {
  let ratio : Double? = if has_ratio { Some(ratio_value) } else { None }
  let (w, h) = @layout.apply_aspect_ratio_after_constraints(
    width, height, ratio, width_changed, height_changed,
  )
  { a: w, b: h }
}

///|
/// Export: clamp-size
pub fn clamp_size(
  width : Double,
  height : Double,
  min_width : Double,
  max_width : Double,
  min_height : Double,
  max_height : Double,
) -> Pair {
  let (w, h) = @layout.clamp_size(
    width, height, min_width, max_width, min_height, max_height,
  )
  { a: w, b: h }
}

///|
/// Export: clamp-size-with-box-min
pub fn clamp_size_with_box_min(
  width : Double,
  height : Double,
  min_width : Double,
  max_width : Double,
  min_height : Double,
  max_height : Double,
  box_min_width : Double,
  box_min_height : Double,
) -> Pair {
  let (w, h) = @layout.clamp_size_with_box_min(
    width, height, min_width, max_width, min_height, max_height, box_min_width,
    box_min_height,
  )
  { a: w, b: h }
}

///|
/// Export: clamp-value
pub fn clamp_value(value : Double, min_val : Double, max_val : Double) -> Double {
  @layout.clamp_value(value, min_val, max_val)
}

///|
/// Export: compute-align-offset
pub fn compute_align_offset(
  align : Alignment,
  remaining_space : Double,
) -> Double {
  @layout.compute_align_offset(to_layout_alignment(align), remaining_space)
}

///|
/// Export: compute-align-self-offset
pub fn compute_align_self_offset(
  self_align : AlignSelf,
  parent_align : Alignment,
  remaining_space : Double,
) -> Double {
  @layout.compute_align_self_offset(
    to_layout_align_self(self_align),
    to_layout_alignment(parent_align),
    remaining_space,
  )
}

///|
/// Export: compute-justify
pub fn compute_justify(
  align : Alignment,
  container_size : Double,
  item_count : Int,
) -> Pair {
  let (start, gap) = @layout.compute_justify(
    to_layout_alignment(align), container_size, item_count,
  )
  { a: start, b: gap }
}

///|
/// Export: resolve-align-self
pub fn resolve_align_self(
  self_align : AlignSelf,
  parent_align : Alignment,
) -> Alignment {
  from_layout_alignment(
    @layout.resolve_align_self(
      to_layout_align_self(self_align), to_layout_alignment(parent_align),
    ),
  )
}

///|
/// Export: resolve-auto-margin-pair
pub fn resolve_auto_margin_pair(
  start_auto : Bool,
  end_auto : Bool,
  margin_start : Double,
  margin_end : Double,
  remaining_space : Double,
) -> Pair {
  let (ms, me) = @layout.resolve_auto_margin_pair(
    start_auto, end_auto, margin_start, margin_end, remaining_space,
  )
  { a: ms, b: me }
}
