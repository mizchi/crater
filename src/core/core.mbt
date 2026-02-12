///|
/// Shared alignment computation functions for Box/Flex/Grid layouts.
///
/// Public API is kept stable for crater packages; implementation delegates to
/// `mizchi/layout` so core logic can live in an external reusable module.

///|
fn to_layout_flex_direction(
  direction : @types.FlexDirection,
) -> @lt.FlexDirection {
  match direction {
    @types.Row => @lt.Row
    @types.RowReverse => @lt.RowReverse
    @types.Column => @lt.Column
    @types.ColumnReverse => @lt.ColumnReverse
  }
}

///|
fn to_layout_alignment(alignment : @types.Alignment) -> @lt.Alignment {
  match alignment {
    @types.Start => @lt.Start
    @types.End => @lt.End
    @types.FlexStart => @lt.FlexStart
    @types.FlexEnd => @lt.FlexEnd
    @types.Center => @lt.Center
    @types.SpaceBetween => @lt.SpaceBetween
    @types.SpaceAround => @lt.SpaceAround
    @types.SpaceEvenly => @lt.SpaceEvenly
    @types.Stretch => @lt.Stretch
    @types.Baseline => @lt.Baseline
  }
}

///|
fn from_layout_alignment(alignment : @lt.Alignment) -> @types.Alignment {
  match alignment {
    @lt.Start => @types.Start
    @lt.End => @types.End
    @lt.FlexStart => @types.FlexStart
    @lt.FlexEnd => @types.FlexEnd
    @lt.Center => @types.Center
    @lt.SpaceBetween => @types.SpaceBetween
    @lt.SpaceAround => @types.SpaceAround
    @lt.SpaceEvenly => @types.SpaceEvenly
    @lt.Stretch => @types.Stretch
    @lt.Baseline => @types.Baseline
  }
}

///|
fn to_layout_align_self(align_self : @types.AlignSelf) -> @lt.AlignSelf {
  match align_self {
    @types.AlignSelf::Auto => @lt.AlignSelf::Auto
    @types.AlignSelf::Start => @lt.AlignSelf::Start
    @types.AlignSelf::End => @lt.AlignSelf::End
    @types.AlignSelf::Center => @lt.AlignSelf::Center
    @types.AlignSelf::Stretch => @lt.AlignSelf::Stretch
    @types.AlignSelf::Baseline => @lt.AlignSelf::Baseline
  }
}

///|
fn to_layout_dimension(dimension : @types.Dimension) -> @lt.Dimension {
  match dimension {
    @types.Length(v) => @lt.Length(v)
    @types.Percent(v) => @lt.Percent(v)
    @types.Auto => @lt.Auto
    @types.MinContent => @lt.MinContent
    @types.MaxContent => @lt.MaxContent
    @types.FitContent(v) => @lt.FitContent(v)
  }
}

///|
fn to_layout_rect_double(rect : @types.Rect[Double]) -> @lt.Rect[Double] {
  { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom }
}

///|
fn to_layout_rect_dimension(
  rect : @types.Rect[@types.Dimension],
) -> @lt.Rect[@lt.Dimension] {
  {
    left: to_layout_dimension(rect.left),
    right: to_layout_dimension(rect.right),
    top: to_layout_dimension(rect.top),
    bottom: to_layout_dimension(rect.bottom),
  }
}

///|
fn to_layout_track(track : ContentTrack) -> @layout_kernel.ContentTrack {
  { position: track.position, size: track.size, stretchable: track.stretchable }
}

///|
fn from_layout_track(track : @layout_kernel.ContentTrack) -> ContentTrack {
  { position: track.position, size: track.size, stretchable: track.stretchable }
}

///|
/// Resolved flex axis information for a container.
pub(all) struct FlexAxis {
  direction_is_row : Bool
  is_row : Bool
  is_reverse : Bool
}

///|
/// Track descriptor for content alignment (justify-content / align-content).
pub(all) struct ContentTrack {
  position : Double
  size : Double
  stretchable : Bool
}

///|
pub fn compute_justify(
  justify : @types.Alignment,
  free_space : Double,
  item_count : Int,
) -> (Double, Double) {
  @layout_kernel.compute_justify(
    to_layout_alignment(justify),
    free_space,
    item_count,
  )
}

///|
pub fn compute_align_offset(
  align : @types.Alignment,
  free_space : Double,
) -> Double {
  @layout_kernel.compute_align_offset(to_layout_alignment(align), free_space)
}

///|
pub fn resolve_flex_axis(
  direction : @types.FlexDirection,
  vertical_writing : Bool,
  rtl : Bool,
) -> FlexAxis {
  let axis = @layout_kernel.resolve_flex_axis(
    to_layout_flex_direction(direction),
    vertical_writing,
    rtl,
  )
  {
    direction_is_row: axis.direction_is_row,
    is_row: axis.is_row,
    is_reverse: axis.is_reverse,
  }
}

///|
pub fn axis_main_start(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @layout_kernel.axis_main_start(is_row, to_layout_rect_double(rect))
}

///|
pub fn axis_main_end(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @layout_kernel.axis_main_end(is_row, to_layout_rect_double(rect))
}

///|
pub fn axis_cross_start(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @layout_kernel.axis_cross_start(is_row, to_layout_rect_double(rect))
}

///|
pub fn axis_cross_end(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @layout_kernel.axis_cross_end(is_row, to_layout_rect_double(rect))
}

///|
pub fn axis_main_sum(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @layout_kernel.axis_main_sum(is_row, to_layout_rect_double(rect))
}

///|
pub fn axis_cross_sum(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  @layout_kernel.axis_cross_sum(is_row, to_layout_rect_double(rect))
}

///|
pub fn clamp_value(
  value : Double,
  min_val : Double,
  max_val : Double,
) -> Double {
  @layout_kernel.clamp_value(value, min_val, max_val)
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
  @layout_kernel.clamp_size(width, height, min_w, max_w, min_h, max_h)
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
  @layout_kernel.clamp_size_with_box_min(
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
  @layout_kernel.apply_aspect_ratio_after_constraints(
    width, height, aspect_ratio, width_has_constraint, height_has_constraint,
  )
}

///|
pub fn resolve_align_self(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
) -> @types.Alignment {
  from_layout_alignment(
    @layout_kernel.resolve_align_self(
      to_layout_align_self(align_self),
      to_layout_alignment(parent_align),
    ),
  )
}

///|
pub fn resolve_auto_margin_pair(
  start_is_auto : Bool,
  end_is_auto : Bool,
  fixed_start : Double,
  fixed_end : Double,
  remaining_space : Double,
) -> (Double, Double) {
  @layout_kernel.resolve_auto_margin_pair(
    start_is_auto, end_is_auto, fixed_start, fixed_end, remaining_space,
  )
}

///|
pub fn resolve_relative_inset_axis_offset(
  start : @types.Dimension,
  end : @types.Dimension,
  percent_context : Double?,
) -> Double {
  @layout_kernel.resolve_relative_inset_axis_offset(
    to_layout_dimension(start),
    to_layout_dimension(end),
    percent_context,
  )
}

///|
pub fn resolve_relative_inset_offsets(
  inset : @types.Rect[@types.Dimension],
  width_context : Double,
  height_context : Double?,
) -> (Double, Double) {
  @layout_kernel.resolve_relative_inset_offsets(
    to_layout_rect_dimension(inset),
    width_context,
    height_context,
  )
}

///|
pub fn compute_grid_self_alignment_offset(
  alignment : @types.Alignment,
  available_size : Double,
  item_size : Double,
  start_auto_margin : Bool,
  end_auto_margin : Bool,
) -> Double {
  @layout_kernel.compute_grid_self_alignment_offset(
    to_layout_alignment(alignment),
    available_size,
    item_size,
    start_auto_margin,
    end_auto_margin,
  )
}

///|
pub fn compute_grid_absolute_self_position(
  align_self : @types.AlignSelf,
  base_position : Double,
  area_start : Double,
  area_size : Double,
  final_size : Double,
  margin_end : Double,
  start_inset_is_none : Bool,
  end_inset_is_none : Bool,
) -> Double {
  @layout_kernel.compute_grid_absolute_self_position(
    to_layout_align_self(align_self),
    base_position,
    area_start,
    area_size,
    final_size,
    margin_end,
    start_inset_is_none,
    end_inset_is_none,
  )
}

///|
pub fn compute_inset_axis_position_with_auto_margin(
  start_inset : Double?,
  end_inset : Double?,
  margin_start : Double,
  margin_end : Double,
  margin_start_is_auto : Bool,
  margin_end_is_auto : Bool,
  child_size : Double,
  area_start : Double,
  area_size : Double,
  fallback_offset : Double,
) -> Double {
  @layout_kernel.compute_inset_axis_position_with_auto_margin(
    start_inset, end_inset, margin_start, margin_end, margin_start_is_auto, margin_end_is_auto,
    child_size, area_start, area_size, fallback_offset,
  )
}

///|
pub fn compute_align_self_offset(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
  free_space : Double,
) -> Double {
  @layout_kernel.compute_align_self_offset(
    to_layout_align_self(align_self),
    to_layout_alignment(parent_align),
    free_space,
  )
}

///|
pub fn align_content_tracks(
  tracks : Array[ContentTrack],
  container_size : Double,
  alignment : @types.Alignment,
) -> Array[ContentTrack] {
  let layout_tracks : Array[@layout_kernel.ContentTrack] = []
  for i = 0; i < tracks.length(); i = i + 1 {
    layout_tracks.push(to_layout_track(tracks[i]))
  }
  let aligned = @layout_kernel.align_content_tracks(
    layout_tracks,
    container_size,
    to_layout_alignment(alignment),
  )
  let result : Array[ContentTrack] = []
  for i = 0; i < aligned.length(); i = i + 1 {
    result.push(from_layout_track(aligned[i]))
  }
  result
}
