///|
/// Shared alignment computation functions for Box/Flex/Grid layouts.
/// This package is intentionally pure and stateless so it can be reused
/// independently from full layout implementations.

///|
/// Compute justify-content positioning for distributing items along an axis.
/// Returns (start_offset, gap_between_items).
/// Note: FlexStart/FlexEnd should be resolved by caller when wrap-reverse
/// behavior needs physical flipping.
pub fn compute_justify(
  justify : @types.Alignment,
  free_space : Double,
  item_count : Int,
) -> (Double, Double) {
  if item_count == 0 {
    return (0.0, 0.0)
  }

  // CSS spec: when free_space is negative, space-* alignments fall back to start.
  if free_space < 0.0 {
    match justify {
      @types.SpaceBetween | @types.SpaceAround | @types.SpaceEvenly =>
        return (0.0, 0.0)
      _ => ()
    }
  }

  match justify {
    @types.Start | @types.FlexStart => (0.0, 0.0)
    @types.End | @types.FlexEnd => (free_space, 0.0)
    @types.Center => (free_space / 2.0, 0.0)
    @types.SpaceBetween =>
      if item_count == 1 {
        (0.0, 0.0)
      } else {
        (0.0, free_space / (item_count - 1).to_double())
      }
    @types.SpaceAround => {
      let gap = free_space / item_count.to_double()
      (gap / 2.0, gap)
    }
    @types.SpaceEvenly => {
      let gap = free_space / (item_count + 1).to_double()
      (gap, gap)
    }
    @types.Stretch => (0.0, 0.0)
    @types.Baseline => (0.0, 0.0)
  }
}

///|
/// Compute alignment offset for a single item.
/// Used for align-items, align-self, justify-self.
pub fn compute_align_offset(
  align : @types.Alignment,
  free_space : Double,
) -> Double {
  if free_space <= 0.0 {
    return 0.0
  }
  match align {
    @types.Start | @types.FlexStart => 0.0
    @types.End | @types.FlexEnd => free_space
    @types.Center => free_space / 2.0
    @types.SpaceBetween => 0.0
    @types.SpaceAround => free_space / 2.0
    @types.SpaceEvenly => free_space / 2.0
    @types.Stretch => 0.0
    @types.Baseline => 0.0
  }
}

///|
/// Resolved flex axis information for a container.
pub(all) struct FlexAxis {
  direction_is_row : Bool
  is_row : Bool
  is_reverse : Bool
}

///|
/// Resolve physical axis/reverse flags from flex-direction and writing/direction.
pub fn resolve_flex_axis(
  direction : @types.FlexDirection,
  vertical_writing : Bool,
  rtl : Bool,
) -> FlexAxis {
  let direction_is_row = match direction {
    @types.Row | @types.RowReverse => true
    @types.Column | @types.ColumnReverse => false
  }
  let is_row = if vertical_writing {
    not(direction_is_row)
  } else {
    direction_is_row
  }
  let direction_reverse = match direction {
    @types.RowReverse | @types.ColumnReverse => true
    _ => false
  }
  let is_reverse = if direction_is_row && rtl {
    not(direction_reverse)
  } else {
    direction_reverse
  }
  { direction_is_row, is_row, is_reverse }
}

///|
/// Main-axis start edge from a physical rect (left/right/top/bottom).
pub fn axis_main_start(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  if is_row {
    rect.left
  } else {
    rect.top
  }
}

///|
/// Main-axis end edge from a physical rect (left/right/top/bottom).
pub fn axis_main_end(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  if is_row {
    rect.right
  } else {
    rect.bottom
  }
}

///|
/// Cross-axis start edge from a physical rect (left/right/top/bottom).
pub fn axis_cross_start(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  if is_row {
    rect.top
  } else {
    rect.left
  }
}

///|
/// Cross-axis end edge from a physical rect (left/right/top/bottom).
pub fn axis_cross_end(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  if is_row {
    rect.bottom
  } else {
    rect.right
  }
}

///|
pub fn axis_main_sum(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  axis_main_start(is_row, rect) + axis_main_end(is_row, rect)
}

///|
pub fn axis_cross_sum(is_row : Bool, rect : @types.Rect[Double]) -> Double {
  axis_cross_start(is_row, rect) + axis_cross_end(is_row, rect)
}

///|
/// Clamp a value to [min_val, max_val], with CSS rule that min wins on conflict.
pub fn clamp_value(
  value : Double,
  min_val : Double,
  max_val : Double,
) -> Double {
  let clamped = if value > max_val { max_val } else { value }
  if clamped < min_val {
    min_val
  } else {
    clamped
  }
}

///|
/// Clamp width/height independently with CSS min/max precedence.
pub fn clamp_size(
  width : Double,
  height : Double,
  min_w : Double,
  max_w : Double,
  min_h : Double,
  max_h : Double,
) -> (Double, Double) {
  (clamp_value(width, min_w, max_w), clamp_value(height, min_h, max_h))
}

///|
/// Clamp width/height with box minimum (padding+border) as absolute lower bound.
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
  let min_w = if style_min_w > box_min_w { style_min_w } else { box_min_w }
  let min_h = if style_min_h > box_min_h { style_min_h } else { box_min_h }
  clamp_size(width, height, min_w, max_w, min_h, max_h)
}

///|
/// Re-apply aspect-ratio after constraints, matching current absolute/grid behavior.
pub fn apply_aspect_ratio_after_constraints(
  width : Double,
  height : Double,
  aspect_ratio : Double?,
  width_has_constraint : Bool,
  height_has_constraint : Bool,
) -> (Double, Double) {
  match aspect_ratio {
    Some(ar) if ar > 0.0 =>
      if height_has_constraint && not(width_has_constraint) {
        (height * ar, height)
      } else if not(height_has_constraint) && width_has_constraint {
        (width, width / ar)
      } else if not(height_has_constraint) && not(width_has_constraint) {
        (width, width / ar)
      } else {
        (width, height)
      }
    _ => (width, height)
  }
}

///|
/// Resolve align-self/justify-self against parent alignment.
pub fn resolve_align_self(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
) -> @types.Alignment {
  match align_self {
    @types.AlignSelf::Auto => parent_align
    @types.AlignSelf::Start => @types.Start
    @types.AlignSelf::End => @types.End
    @types.AlignSelf::Center => @types.Center
    @types.AlignSelf::Stretch => @types.Stretch
    @types.AlignSelf::Baseline => @types.Baseline
  }
}

///|
/// Resolve a pair of margins where either side can be `auto`.
///
/// `remaining_space` is clamped at 0 for auto margin distribution.
pub fn resolve_auto_margin_pair(
  start_is_auto : Bool,
  end_is_auto : Bool,
  fixed_start : Double,
  fixed_end : Double,
  remaining_space : Double,
) -> (Double, Double) {
  let auto_space = if remaining_space > 0.0 { remaining_space } else { 0.0 }
  if start_is_auto && end_is_auto {
    let half = auto_space / 2.0
    (half, half)
  } else if start_is_auto {
    (auto_space, fixed_end)
  } else if end_is_auto {
    (fixed_start, auto_space)
  } else {
    (fixed_start, fixed_end)
  }
}

///|
/// Resolve relative/static inset offset for one axis.
///
/// Behavior:
/// - start (left/top) takes precedence when definite.
/// - if start is auto, end (right/bottom) is applied as negative offset.
/// - percentage without context resolves to 0.
pub fn resolve_relative_inset_axis_offset(
  start : @types.Dimension,
  end : @types.Dimension,
  percent_context : Double?,
) -> Double {
  let resolve_percent = fn(p) {
    match percent_context {
      Some(ctx) => ctx * p
      None => 0.0
    }
  }
  match start {
    @types.Length(v) => v
    @types.Percent(p) => resolve_percent(p)
    @types.Auto =>
      match end {
        @types.Length(v) => -v
        @types.Percent(p) => -resolve_percent(p)
        @types.Auto
        | @types.MinContent
        | @types.MaxContent
        | @types.FitContent(_) => 0.0
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
  }
}

///|
/// Resolve x/y offsets from inset for relative/static positioning.
pub fn resolve_relative_inset_offsets(
  inset : @types.Rect[@types.Dimension],
  width_context : Double,
  height_context : Double?,
) -> (Double, Double) {
  let x = resolve_relative_inset_axis_offset(
    inset.left,
    inset.right,
    Some(width_context),
  )
  let y = resolve_relative_inset_axis_offset(
    inset.top,
    inset.bottom,
    height_context,
  )
  (x, y)
}

///|
/// Compute grid item alignment offset inside the available area.
/// Mirrors current grid behavior: auto margins disable alignment offset.
pub fn compute_grid_self_alignment_offset(
  alignment : @types.Alignment,
  available_size : Double,
  item_size : Double,
  start_auto_margin : Bool,
  end_auto_margin : Bool,
) -> Double {
  if start_auto_margin || end_auto_margin {
    return 0.0
  }
  let free_space = available_size - item_size
  match alignment {
    @types.End => free_space
    @types.Center => free_space / 2.0
    @types.Start | @types.Stretch => 0.0
    _ => 0.0
  }
}

///|
/// Compute align-self/justify-self position for grid absolutely positioned children
/// when both corresponding insets are auto.
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
  if not(start_inset_is_none && end_inset_is_none) {
    return base_position
  }
  match align_self {
    @types.AlignSelf::End => area_start + area_size - final_size - margin_end
    @types.AlignSelf::Center => area_start + (area_size - final_size) / 2.0
    @types.AlignSelf::Auto
    | @types.AlignSelf::Start
    | @types.AlignSelf::Stretch
    | @types.AlignSelf::Baseline => base_position
  }
}

///|
/// Compute 1-axis inset-based position with CSS margin:auto behavior.
///
/// `fallback_offset` is used when both insets are auto.
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
  let area_end = area_start + area_size
  match start_inset {
    Some(s) =>
      match end_inset {
        Some(e) => {
          let available = area_size - s - e - child_size
          if margin_start_is_auto && margin_end_is_auto && available > 0.0 {
            area_start + s + available / 2.0
          } else if margin_end_is_auto && available > 0.0 {
            area_start + s + margin_start
          } else if margin_start_is_auto && available > 0.0 {
            area_end - e - child_size - margin_end
          } else {
            area_start + s + margin_start
          }
        }
        None => area_start + s + margin_start
      }
    None =>
      match end_inset {
        Some(e) => area_end - e - margin_end - child_size
        None => area_start + fallback_offset + margin_start
      }
  }
}

///|
/// Compute alignment offset for align-self (child override of parent align-items).
pub fn compute_align_self_offset(
  align_self : @types.AlignSelf,
  parent_align : @types.Alignment,
  free_space : Double,
) -> Double {
  if free_space <= 0.0 {
    return 0.0
  }
  compute_align_offset(resolve_align_self(align_self, parent_align), free_space)
}

///|
/// Track descriptor for content alignment (justify-content / align-content).
pub(all) struct ContentTrack {
  position : Double
  size : Double
  stretchable : Bool
}

///|
/// Align tracks inside a container.
///
/// Behavior matches Grid/Flex content alignment semantics used in crater:
/// - `Stretch`: distributes positive free space to stretchable tracks.
/// - `Space*`: only non-zero tracks participate in distribution.
/// - others: tracks are shifted uniformly by start offset.
pub fn align_content_tracks(
  tracks : Array[ContentTrack],
  container_size : Double,
  alignment : @types.Alignment,
) -> Array[ContentTrack] {
  if tracks.length() == 0 {
    return []
  }

  let aligned = tracks.copy()
  let last_track = aligned[aligned.length() - 1]
  let total_track_size = last_track.position + last_track.size
  let free_space = container_size - total_track_size
  let track_count = aligned.length()
  let effective_indices : Array[Int] = []
  for i = 0; i < track_count; i = i + 1 {
    if aligned[i].size > 0.0 {
      effective_indices.push(i)
    }
  }
  let effective_count = effective_indices.length()

  if alignment == @types.Stretch {
    if free_space <= 0.0 {
      return aligned
    }
    let mut stretchable_count = 0
    for i = 0; i < track_count; i = i + 1 {
      if aligned[i].stretchable {
        stretchable_count = stretchable_count + 1
      }
    }
    if stretchable_count == 0 {
      return aligned
    }

    let extra_per_track = free_space / stretchable_count.to_double()
    let mut accumulated_offset = 0.0
    for i = 0; i < track_count; i = i + 1 {
      let track = aligned[i]
      if track.stretchable {
        aligned[i] = {
          position: track.position + accumulated_offset,
          size: track.size + extra_per_track,
          stretchable: track.stretchable,
        }
        accumulated_offset = accumulated_offset + extra_per_track
      } else {
        aligned[i] = {
          position: track.position + accumulated_offset,
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    }
    return aligned
  }

  let distribution_item_count = match alignment {
    @types.SpaceBetween | @types.SpaceAround | @types.SpaceEvenly =>
      effective_count
    _ => track_count
  }
  let (start_offset, gap_between_tracks) = compute_justify(
    alignment, free_space, distribution_item_count,
  )
  match alignment {
    @types.SpaceBetween | @types.SpaceAround | @types.SpaceEvenly =>
      for j = 0; j < effective_count; j = j + 1 {
        let i = effective_indices[j]
        let track = aligned[i]
        aligned[i] = {
          position: track.position +
          start_offset +
          gap_between_tracks * j.to_double(),
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    _ => {
      if start_offset == 0.0 {
        return aligned
      }
      for i = 0; i < track_count; i = i + 1 {
        let track = aligned[i]
        aligned[i] = {
          position: track.position + start_offset,
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    }
  }
  aligned
}
