// =============================================================================
// CSS Grid Layout Implementation
// =============================================================================

///|
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Resolve minimum track sizing to a concrete size
fn resolve_min_track_size(
  min_track : @style.MinTrackSizing,
  available_size : Double,
  min_content_size : Double,
  max_content_size : Double,
) -> Double {
  match min_track {
    @style.MinTrackSizing::Length(v) => v
    @style.MinTrackSizing::Percent(p) => available_size * p
    @style.MinTrackSizing::Auto => 0.0 // Auto in minmax uses 0 as minimum
    @style.MinTrackSizing::MinContent => min_content_size
    @style.MinTrackSizing::MaxContent => max_content_size
  }
}

///|
/// Resolve maximum track sizing to a concrete size
fn resolve_max_track_size(
  max_track : @style.MaxTrackSizing,
  available_size : Double,
  min_content_size : Double,
  max_content_size : Double,
) -> Double {
  match max_track {
    @style.MaxTrackSizing::Length(v) => v
    @style.MaxTrackSizing::Percent(p) => available_size * p
    @style.MaxTrackSizing::Fr(_) => 1.0e10 // Fr in max position means flexible
    @style.MaxTrackSizing::Auto => 1.0e10
    @style.MaxTrackSizing::MinContent => min_content_size
    @style.MaxTrackSizing::MaxContent => max_content_size
  }
}

///|
/// Grid track - represents a row or column with its position and size
priv struct GridTrack {
  position : Double // Start position of the track
  size : Double // Size of the track
  stretchable : Bool // Whether this track can be stretched by align-content: stretch
}

///|
/// Grid item placement - resolved position of an item in the grid
priv struct GridItemPlacement {
  row_start : Int
  row_end : Int
  column_start : Int
  column_end : Int
}

///|
/// Create default layout rect for margins, padding, border
fn default_rect() -> @types.Rect[Double] {
  { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 }
}

///|
/// Get the minimum and maximum track indices from placements
fn get_placement_range(
  placements : Array[GridItemPlacement],
  is_column : Bool,
) -> (Int, Int) {
  let mut min_idx = 0
  let mut max_idx = 0
  for i = 0; i < placements.length(); i = i + 1 {
    let placement = placements[i]
    let (start, end) = if is_column {
      (placement.column_start, placement.column_end)
    } else {
      (placement.row_start, placement.row_end)
    }
    if start < min_idx {
      min_idx = start
    }
    if end > max_idx {
      max_idx = end
    }
  }
  (min_idx, max_idx)
}

///|
/// Adjust all placements by offset to handle negative indices
fn adjust_placements(
  placements : Array[GridItemPlacement],
  col_offset : Int,
  row_offset : Int,
) -> Array[GridItemPlacement] {
  let result : Array[GridItemPlacement] = []
  for i = 0; i < placements.length(); i = i + 1 {
    let p = placements[i]
    result.push({
      row_start: p.row_start + row_offset,
      row_end: p.row_end + row_offset,
      column_start: p.column_start + col_offset,
      column_end: p.column_end + col_offset,
    })
  }
  result
}

///|
/// Calculate total track size (sum of track sizes, not including gaps at the end)
fn calculate_total_track_size(
  tracks : Array[GridTrack],
  _gap : Double,
) -> Double {
  if tracks.length() == 0 {
    return 0.0
  }
  let last_track = tracks[tracks.length() - 1]
  last_track.position + last_track.size
}

///|
/// Compute grid layout for a node
pub fn compute_grid_layout(
  node : @node.Node,
  available_width : Double,
  available_height : Double,
) -> @node.Layout {
  let style = node.style
  let children = node.children

  // Resolve container size first (needed for auto-fill expansion)
  let container_width_for_expansion = resolve_dimension(
    style.width,
    available_width,
    available_width,
  )
  let container_height_for_expansion = resolve_dimension(
    style.height,
    available_height,
    available_height,
  )

  // Expand repeat() in templates early (needed for correct column/row counts)
  let expanded_columns = expand_track_templates(
    style.grid_template_columns,
    container_width_for_expansion,
  )
  let expanded_rows = expand_track_templates(
    style.grid_template_rows,
    container_height_for_expansion,
  )
  let explicit_column_count = expanded_columns.length()
  let explicit_row_count = expanded_rows.length()

  // Parse grid-template-areas for named area placement
  let grid_areas = parse_grid_template_areas(style.grid_template_areas)

  // Place items first (needed for auto track sizing and implicit track calculation)
  let placements = place_grid_items(
    children,
    explicit_column_count,
    explicit_row_count,
    style.grid_auto_flow,
    grid_areas,
  )

  // Calculate implicit track range needed
  let (col_min_idx, col_max_idx) = get_placement_range(placements, true)
  let (row_min_idx, row_max_idx) = get_placement_range(placements, false)

  // Calculate offset for negative implicit tracks
  let col_offset = if col_min_idx < 0 { -col_min_idx } else { 0 }
  let row_offset = if row_min_idx < 0 { -row_min_idx } else { 0 }

  // Adjust placements by offset
  let adjusted_placements = adjust_placements(
    placements, col_offset, row_offset,
  )

  // Calculate total column/row count including implicit tracks
  let total_column_count = max_int(
    explicit_column_count,
    col_max_idx + col_offset,
  )
  let total_row_count = max_int(explicit_row_count, row_max_idx + row_offset)

  // Calculate intrinsic content sizes for tracks (min-content and max-content)
  let (column_min_content, column_max_content) = calculate_track_intrinsic_sizes(
    children, adjusted_placements, total_column_count, true, // is_column
    container_width_for_expansion,
  )
  let (row_min_content, row_max_content) = calculate_track_intrinsic_sizes(
    children, adjusted_placements, total_row_count, false, // is_column
    container_width_for_expansion, // CSS: percent padding resolves against width
  )

  // Determine if container has auto sizing
  let width_is_auto = match style.width {
    @types.Auto => true
    _ => false
  }
  let height_is_auto = match style.height {
    @types.Auto => true
    _ => false
  }

  // Resolve container size (preliminary for percentage calculations)
  let preliminary_width = resolve_dimension(
    style.width,
    available_width,
    available_width,
  )
  let preliminary_height = resolve_dimension(
    style.height,
    available_height,
    available_height,
  )

  // Get padding and border
  let padding_left = resolve_dimension(
    style.padding.left,
    preliminary_width,
    0.0,
  )
  let padding_right = resolve_dimension(
    style.padding.right,
    preliminary_width,
    0.0,
  )
  let padding_top = resolve_dimension(
    style.padding.top,
    preliminary_height,
    0.0,
  )
  let padding_bottom = resolve_dimension(
    style.padding.bottom,
    preliminary_height,
    0.0,
  )
  let border_left = resolve_dimension(style.border.left, preliminary_width, 0.0)
  let border_right = resolve_dimension(
    style.border.right,
    preliminary_width,
    0.0,
  )
  let border_top = resolve_dimension(style.border.top, preliminary_height, 0.0)
  let border_bottom = resolve_dimension(
    style.border.bottom,
    preliminary_height,
    0.0,
  )
  let column_gap = resolve_dimension(style.column_gap, preliminary_width, 0.0)
  let row_gap = resolve_dimension(style.row_gap, preliminary_height, 0.0)

  // Calculate content box for track sizing
  let preliminary_content_width = preliminary_width -
    padding_left -
    padding_right -
    border_left -
    border_right
  let preliminary_content_height = preliminary_height -
    padding_top -
    padding_bottom -
    border_top -
    border_bottom

  // Resolve track sizes with implicit track handling
  // Note: Templates are already expanded at the start of compute_grid_layout
  let column_tracks = resolve_tracks_with_implicit(
    expanded_columns,
    style.grid_auto_columns,
    preliminary_content_width,
    column_gap,
    column_min_content,
    column_max_content,
    col_offset,
    total_column_count,
    not(width_is_auto), // Only distribute remaining space if width is definite
  )
  let row_tracks = resolve_tracks_with_implicit(
    expanded_rows,
    style.grid_auto_rows,
    preliminary_content_height,
    row_gap,
    row_min_content,
    row_max_content,
    row_offset,
    total_row_count,
    not(height_is_auto), // Only distribute remaining space if height is definite
  )

  // Check if we need baseline alignment
  let needs_baseline = style.align_items == @style.Baseline

  // For baseline alignment, we need to adjust row track sizes
  // based on max_ascent + max_descent for each row
  if needs_baseline {
    // Calculate baseline info for each item (preliminary pass)
    let row_baseline_heights : @hashmap.HashMap[Int, (Double, Double)] = @hashmap.new()

    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let placement = adjusted_placements[i]

      if child.style.display == @style.None {
        continue
      }

      let row_start = placement.row_start

      // Get preliminary item size for baseline calculation
      let (_, item_width) = get_span_bounds(column_tracks, placement.column_start, placement.column_end)
      let (_, item_height) = get_span_bounds(row_tracks, row_start, placement.row_end)

      // Compute child layout for baseline info
      let child_inner = compute_child_layout(child, item_width, item_height)
      let baseline = calculate_baseline(child, child_inner)
      let descent = child_inner.height - baseline

      // Update max ascent/descent for this row
      let (current_ascent, current_descent) = row_baseline_heights.get(row_start).unwrap_or((0.0, 0.0))
      let new_ascent = max(current_ascent, baseline)
      let new_descent = max(current_descent, descent)
      row_baseline_heights.set(row_start, (new_ascent, new_descent))
    }

    // Adjust row track sizes to accommodate baseline alignment
    for row = 0; row < row_tracks.length(); row = row + 1 {
      match row_baseline_heights.get(row) {
        Some((max_ascent, max_descent)) => {
          let required_height = max_ascent + max_descent
          let track = row_tracks[row]
          if required_height > track.size {
            // Need to expand this row track
            let extra = required_height - track.size
            row_tracks[row] = {
              position: track.position,
              size: required_height,
              stretchable: track.stretchable,
            }
            // Shift all subsequent tracks down
            for j = row + 1; j < row_tracks.length(); j = j + 1 {
              let t = row_tracks[j]
              row_tracks[j] = {
                position: t.position + extra,
                size: t.size,
                stretchable: t.stretchable,
              }
            }
          }
        }
        None => ()
      }
    }
  }

  // Calculate final container size
  // Padding and border create a minimum size even when content is smaller
  let min_width = padding_left + padding_right + border_left + border_right
  let min_height = padding_top + padding_bottom + border_top + border_bottom
  let container_width = if width_is_auto {
    // Sum of track sizes + gaps + padding + border
    let total_track_width = calculate_total_track_size(
      column_tracks, column_gap,
    )
    total_track_width +
    padding_left +
    padding_right +
    border_left +
    border_right
  } else {
    // Enforce minimum size from padding + border
    if preliminary_width > min_width { preliminary_width } else { min_width }
  }
  let container_height = if height_is_auto {
    let total_track_height = calculate_total_track_size(row_tracks, row_gap)
    total_track_height +
    padding_top +
    padding_bottom +
    border_top +
    border_bottom
  } else {
    // Enforce minimum size from padding + border
    if preliminary_height > min_height { preliminary_height } else { min_height }
  }
  let content_box_left = padding_left + border_left
  let content_box_top = padding_top + border_top
  let content_box_width = container_width -
    padding_left -
    padding_right -
    border_left -
    border_right
  let content_box_height = container_height -
    padding_top -
    padding_bottom -
    border_top -
    border_bottom

  // Apply justify-content (horizontal) and align-content (vertical)
  apply_content_alignment(
    column_tracks,
    content_box_width,
    style.justify_content,
  )
  apply_content_alignment(row_tracks, content_box_height, style.align_content)

  // First pass: compute all children's layouts and collect baseline info
  let preliminary_layouts : Array[@node.Layout] = []
  let baseline_infos : Array[BaselineInfo] = []

  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let placement = adjusted_placements[i]

    // Skip hidden children
    if child.style.display == @style.None {
      preliminary_layouts.push({
        id: child.id,
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        margin: default_rect(),
        padding: default_rect(),
        border: default_rect(),
        children: [],
      })
      baseline_infos.push({ index: i, row: -1, ascent: 0.0, descent: 0.0, height: 0.0 })
      continue
    }

    // Get item position and size from tracks
    let col_start = placement.column_start
    let col_end = placement.column_end
    let row_start = placement.row_start
    let row_end = placement.row_end

    // Calculate item bounds from track positions
    let (item_x, item_width) = get_span_bounds(
      column_tracks, col_start, col_end,
    )
    let (item_y, item_height) = get_span_bounds(row_tracks, row_start, row_end)

    // Compute child's inner layout
    let child_inner = compute_child_layout(child, item_width, item_height)

    // Apply alignment (without baseline adjustment yet)
    let (final_x, final_y, final_width, final_height) = apply_alignment(
      child,
      style,
      content_box_left + item_x,
      content_box_top + item_y,
      item_width,
      item_height,
      child_inner,
    )

    preliminary_layouts.push({
      id: child.id,
      x: final_x,
      y: final_y,
      width: final_width,
      height: final_height,
      margin: default_rect(),
      padding: default_rect(),
      border: default_rect(),
      children: child_inner.children,
    })

    // Collect baseline info for baseline alignment
    if needs_baseline {
      baseline_infos.push(
        get_baseline_info(i, row_start, child, preliminary_layouts[i]),
      )
    } else {
      baseline_infos.push({ index: i, row: -1, ascent: 0.0, descent: 0.0, height: 0.0 })
    }
  }

  // Second pass: apply baseline alignment if needed
  let child_layouts : Array[@node.Layout] = []
  if needs_baseline {
    // Group items by row and calculate max ascent per row
    let row_max_ascent : @hashmap.HashMap[Int, Double] = @hashmap.new()
    for i = 0; i < baseline_infos.length(); i = i + 1 {
      let info = baseline_infos[i]
      if info.row >= 0 {
        let current = row_max_ascent.get(info.row).unwrap_or(0.0)
        if info.ascent > current {
          row_max_ascent.set(info.row, info.ascent)
        }
      }
    }

    // Apply baseline offset to each item
    for i = 0; i < preliminary_layouts.length(); i = i + 1 {
      let layout = preliminary_layouts[i]
      let info = baseline_infos[i]
      if info.row >= 0 {
        let max_ascent = row_max_ascent.get(info.row).unwrap_or(0.0)
        let baseline_offset = max_ascent - info.ascent
        child_layouts.push({
          ..layout,
          y: layout.y + baseline_offset,
        })
      } else {
        child_layouts.push(layout)
      }
    }
  } else {
    // No baseline alignment, use preliminary layouts as-is
    for i = 0; i < preliminary_layouts.length(); i = i + 1 {
      child_layouts.push(preliminary_layouts[i])
    }
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: container_width,
    height: container_height,
    margin: default_rect(),
    padding: {
      left: padding_left,
      right: padding_right,
      top: padding_top,
      bottom: padding_bottom,
    },
    border: {
      left: border_left,
      right: border_right,
      top: border_top,
      bottom: border_bottom,
    },
    children: child_layouts,
  }
}

///|
/// Resolve a dimension value to a concrete size
fn resolve_dimension(
  dim : @types.Dimension,
  available : Double,
  default : Double,
) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) => available * p
    @types.Auto => default
  }
}

///|
/// Apply content alignment (justify-content/align-content) to tracks
fn apply_content_alignment(
  tracks : Array[GridTrack],
  container_size : Double,
  alignment : @style.Alignment,
) -> Unit {
  if tracks.length() == 0 {
    return
  }

  // Calculate total track size (including gaps already baked in)
  let last_track = tracks[tracks.length() - 1]
  let total_track_size = last_track.position + last_track.size
  let free_space = container_size - total_track_size
  if free_space <= 0.0 {
    return
  }
  let track_count = tracks.length()
  match alignment {
    @style.Start | @style.Baseline =>
      // Start: tracks at start, no adjustment
      // Baseline: treated as start for content alignment
      ()
    @style.Stretch => {
      // Distribute free_space to stretchable tracks (expand their size)
      let mut stretchable_count = 0
      for i = 0; i < track_count; i = i + 1 {
        if tracks[i].stretchable {
          stretchable_count = stretchable_count + 1
        }
      }
      if stretchable_count > 0 {
        let extra_per_track = free_space / stretchable_count.to_double()
        let mut accumulated_offset = 0.0
        for i = 0; i < track_count; i = i + 1 {
          let track = tracks[i]
          if track.stretchable {
            tracks[i] = {
              position: track.position + accumulated_offset,
              size: track.size + extra_per_track,
              stretchable: track.stretchable,
            }
            accumulated_offset = accumulated_offset + extra_per_track
          } else {
            tracks[i] = {
              position: track.position + accumulated_offset,
              size: track.size,
              stretchable: track.stretchable,
            }
          }
        }
      }
    }
    @style.End =>
      // Shift all tracks by free_space
      for i = 0; i < track_count; i = i + 1 {
        let track = tracks[i]
        tracks[i] = {
          position: track.position + free_space,
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    @style.Center => {
      // Shift all tracks by half of free_space
      let offset = free_space / 2.0
      for i = 0; i < track_count; i = i + 1 {
        let track = tracks[i]
        tracks[i] = {
          position: track.position + offset,
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    }
    @style.SpaceBetween => {
      if track_count <= 1 {
        return
      }
      // Distribute free_space between tracks
      let gap_addition = free_space / (track_count - 1).to_double()
      for i = 1; i < track_count; i = i + 1 {
        let track = tracks[i]
        tracks[i] = {
          position: track.position + gap_addition * i.to_double(),
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    }
    @style.SpaceAround => {
      // Each track gets equal space on both sides
      let space_per_track = free_space / track_count.to_double()
      for i = 0; i < track_count; i = i + 1 {
        let track = tracks[i]
        let offset = space_per_track * (i.to_double() + 0.5)
        tracks[i] = {
          position: track.position + offset,
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    }
    @style.SpaceEvenly => {
      // Equal space between and around all tracks
      let gap_count = track_count + 1
      let space_per_gap = free_space / gap_count.to_double()
      for i = 0; i < track_count; i = i + 1 {
        let track = tracks[i]
        let offset = space_per_gap * (i + 1).to_double()
        tracks[i] = {
          position: track.position + offset,
          size: track.size,
          stretchable: track.stretchable,
        }
      }
    }
  }
}


///|
/// Calculate both min-content and max-content sizes for each track
fn calculate_track_intrinsic_sizes(
  children : Array[@node.Node],
  placements : Array[GridItemPlacement],
  track_count : Int,
  is_column : Bool,
  container_width : Double, // For resolving percent padding
) -> (Array[Double], Array[Double]) {
  // (min_content_sizes, max_content_sizes)
  let min_sizes : Array[Double] = []
  let max_sizes : Array[Double] = []
  for i = 0; i < track_count; i = i + 1 {
    min_sizes.push(0.0)
    max_sizes.push(0.0)
  }
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let placement = placements[i]

    // Skip hidden children
    if child.style.display == @style.None {
      continue
    }
    let (track_start, track_end) = if is_column {
      (placement.column_start, placement.column_end)
    } else {
      (placement.row_start, placement.row_end)
    }

    // Only consider items that span exactly one track for intrinsic sizing
    if track_end - track_start == 1 && track_start < track_count {
      let (min_content, max_content, margin_start, margin_end) = calculate_item_intrinsic_sizes(
        child, is_column, container_width,
      )
      let min_contribution = min_content + margin_start + margin_end
      let max_contribution = max_content + margin_start + margin_end
      if min_contribution > min_sizes[track_start] {
        min_sizes[track_start] = min_contribution
      }
      if max_contribution > max_sizes[track_start] {
        max_sizes[track_start] = max_contribution
      }
    }
  }
  (min_sizes, max_sizes)
}

///|
/// Get intrinsic sizes from measure function or defaults
fn get_intrinsic_from_measure(
  child : @node.Node,
  available_width : Double,
  available_height : Double,
) -> @node.IntrinsicSize {
  match child.measure {
    Some(measure) => (measure.func)(available_width, available_height)
    None => @node.IntrinsicSize::default()
  }
}

///|
/// Calculate intrinsic sizes (min-content, max-content) for a single item
fn calculate_item_intrinsic_sizes(
  child : @node.Node,
  is_column : Bool,
  container_width : Double,
) -> (Double, Double, Double, Double) {
  // Returns (min_content, max_content, margin_start, margin_end)
  if is_column {
    // Width intrinsic sizes
    let (min_content, max_content) = match child.style.width {
      @types.Length(v) => (v, v)
      @types.Percent(p) => {
        let resolved = p * container_width
        (resolved, resolved)
      }
      @types.Auto => {
        // For leaf nodes, use measure function or defaults
        if child.children.length() == 0 {
          let intrinsic = get_intrinsic_from_measure(child, container_width, 1.0e10)
          (intrinsic.min_width, intrinsic.max_width)
        } else {
          // For containers, recursively compute layout to get intrinsic size
          match child.style.display {
            @style.Grid => {
              // Compute grid layout with available width (for max-content sizing)
              let child_layout = compute_grid_layout(child, container_width, 1.0e10)
              (child_layout.width, child_layout.width)
            }
            @style.Flex => {
              // Compute flex layout
              let ctx : @node.LayoutContext = { available_width: container_width, available_height: Some(1.0e10) }
              let child_layout = @flex.compute(child, ctx)
              (child_layout.width, child_layout.width)
            }
            _ => {
              // For block/other display, use measure or defaults
              let intrinsic = get_intrinsic_from_measure(child, container_width, 1.0e10)
              (intrinsic.min_width, intrinsic.max_width)
            }
          }
        }
      }
    }
    // Add padding and border to intrinsic sizes
    let pl = resolve_dimension(child.style.padding.left, container_width, 0.0)
    let pr = resolve_dimension(child.style.padding.right, container_width, 0.0)
    let bl = resolve_dimension(child.style.border.left, container_width, 0.0)
    let br = resolve_dimension(child.style.border.right, container_width, 0.0)
    let box_size = pl + pr + bl + br
    let final_min = if min_content + box_size > box_size { min_content + box_size } else { box_size }
    let final_max = if max_content + box_size > box_size { max_content + box_size } else { box_size }
    let ml = match child.style.margin.left { @types.Length(v) => v; _ => 0.0 }
    let mr = match child.style.margin.right { @types.Length(v) => v; _ => 0.0 }
    (final_min, final_max, ml, mr)
  } else {
    // Height intrinsic sizes
    let (min_content, max_content) = match child.style.height {
      @types.Length(v) => (v, v)
      @types.Percent(_) => {
        // Percent height resolves against container height, but we don't have it here
        // Return 0 for percent heights in intrinsic sizing
        (0.0, 0.0)
      }
      @types.Auto => {
        if child.children.length() == 0 {
          let intrinsic = get_intrinsic_from_measure(child, 1.0e10, container_width)
          (intrinsic.min_height, intrinsic.max_height)
        } else {
          // For containers, recursively compute layout to get intrinsic size
          match child.style.display {
            @style.Grid => {
              let child_layout = compute_grid_layout(child, 1.0e10, container_width)
              (child_layout.height, child_layout.height)
            }
            @style.Flex => {
              let ctx : @node.LayoutContext = { available_width: 1.0e10, available_height: Some(container_width) }
              let child_layout = @flex.compute(child, ctx)
              (child_layout.height, child_layout.height)
            }
            _ => {
              let intrinsic = get_intrinsic_from_measure(child, 1.0e10, container_width)
              (intrinsic.min_height, intrinsic.max_height)
            }
          }
        }
      }
    }
    // Add padding and border (resolved against WIDTH per CSS spec)
    let pt = resolve_dimension(child.style.padding.top, container_width, 0.0)
    let pb = resolve_dimension(child.style.padding.bottom, container_width, 0.0)
    let bt = resolve_dimension(child.style.border.top, container_width, 0.0)
    let bb = resolve_dimension(child.style.border.bottom, container_width, 0.0)
    let box_size = pt + pb + bt + bb
    let final_min = if min_content + box_size > box_size { min_content + box_size } else { box_size }
    let final_max = if max_content + box_size > box_size { max_content + box_size } else { box_size }
    let mt = match child.style.margin.top { @types.Length(v) => v; _ => 0.0 }
    let mb = match child.style.margin.bottom { @types.Length(v) => v; _ => 0.0 }
    (final_min, final_max, mt, mb)
  }
}

///|
/// Convert SingleTrackSizing to TrackSizingFunction
fn single_to_track(
  single : @style.SingleTrackSizing,
) -> @style.TrackSizingFunction {
  match single {
    @style.SingleTrackSizing::Length(v) => @style.Length(v)
    @style.SingleTrackSizing::Percent(p) => @style.Percent(p)
    @style.SingleTrackSizing::Fr(f) => @style.Fr(f)
    @style.SingleTrackSizing::Auto => @style.Auto
    @style.SingleTrackSizing::MinContent => @style.MinContent
    @style.SingleTrackSizing::MaxContent => @style.MaxContent
    @style.SingleTrackSizing::MinMax(min, max) => @style.MinMax(min, max)
  }
}

///|
/// Expand repeat() in track templates
fn expand_track_templates(
  templates : Array[@style.TrackSizingFunction],
  available_size : Double,
) -> Array[@style.TrackSizingFunction] {
  // First, calculate fixed track sizes (non-repeat tracks)
  let mut fixed_size = 0.0
  for i = 0; i < templates.length(); i = i + 1 {
    match templates[i] {
      @style.Length(v) => fixed_size = fixed_size + v
      @style.Percent(p) => fixed_size = fixed_size + available_size * p
      @style.Repeat(_, _) => () // Skip repeats
      _ => () // Fr, Auto, etc. don't contribute to fixed size
    }
  }
  let remaining_size = available_size - fixed_size
  let result : Array[@style.TrackSizingFunction] = []
  for i = 0; i < templates.length(); i = i + 1 {
    match templates[i] {
      @style.Repeat(repeat_count, tracks) => {
        let repetitions = match repeat_count {
          @style.Count(n) => n
          @style.AutoFill => {
            // Calculate how many repetitions fit in remaining space
            let track_size = calculate_repeat_track_size(tracks, available_size)
            if track_size > 0.0 {
              let c = (remaining_size / track_size).to_int()
              if c < 1 {
                1
              } else {
                c
              }
            } else {
              1
            }
          }
          @style.AutoFit => {
            // Same as auto-fill for now (auto-fit collapses empty tracks later)
            let track_size = calculate_repeat_track_size(tracks, available_size)
            if track_size > 0.0 {
              let c = (remaining_size / track_size).to_int()
              if c < 1 {
                1
              } else {
                c
              }
            } else {
              1
            }
          }
        }
        // Expand the tracks
        for r = 0; r < repetitions; r = r + 1 {
          for t = 0; t < tracks.length(); t = t + 1 {
            result.push(single_to_track(tracks[t]))
          }
        }
      }
      other => result.push(other)
    }
  }
  result
}

///|
/// Calculate the total size of tracks in a repeat pattern
fn calculate_repeat_track_size(
  tracks : Array[@style.SingleTrackSizing],
  available_size : Double,
) -> Double {
  let mut total = 0.0
  for i = 0; i < tracks.length(); i = i + 1 {
    match tracks[i] {
      @style.SingleTrackSizing::Length(v) => total = total + v
      @style.SingleTrackSizing::Percent(p) => total = total + available_size * p
      @style.SingleTrackSizing::Fr(_) => total = total + 0.0 // Fr tracks are flexible
      @style.SingleTrackSizing::Auto => total = total + 0.0
      @style.SingleTrackSizing::MinContent => total = total + 0.0
      @style.SingleTrackSizing::MaxContent => total = total + 0.0
      @style.SingleTrackSizing::MinMax(min, _) =>
        match min {
          @style.MinTrackSizing::Length(v) => total = total + v
          @style.MinTrackSizing::Percent(p) =>
            total = total + available_size * p
          _ => ()
        }
    }
  }
  total
}

///|
/// Resolve track sizing functions with implicit track handling
fn resolve_tracks_with_implicit(
  explicit_templates : Array[@style.TrackSizingFunction],
  auto_templates : Array[@style.TrackSizingFunction],
  available_size : Double,
  gap : Double,
  min_content_sizes : Array[Double],
  max_content_sizes : Array[Double],
  offset : Int, // Number of implicit tracks before explicit grid
  total_count : Int, // Total number of tracks needed
  size_is_definite : Bool, // If false, auto tracks should not expand beyond content
) -> Array[GridTrack] {
  let tracks : Array[GridTrack] = []
  let mut position = 0.0
  let explicit_count = explicit_templates.length()

  // Build complete template array: [implicit before] + [explicit] + [implicit after]
  let all_templates : Array[@style.TrackSizingFunction] = []

  // Implicit tracks before explicit grid
  // These use auto_templates in reverse order: closest to explicit uses last template
  // Position -1 uses template[last], position -2 uses template[last-1], etc.
  for i = 0; i < offset; i = i + 1 {
    // i=0 is furthest from explicit (position -offset)
    // i=offset-1 is closest to explicit (position -1)
    // k = distance from explicit (1-indexed): offset-i for i going 0 to offset-1
    let k = offset - i
    let template = get_auto_template_reverse(auto_templates, k)
    all_templates.push(template)
  }

  // Explicit tracks
  for i = 0; i < explicit_count; i = i + 1 {
    all_templates.push(explicit_templates[i])
  }

  // Implicit tracks after explicit grid
  let implicit_after = total_count - offset - explicit_count
  for i = 0; i < implicit_after; i = i + 1 {
    let template = get_auto_template(auto_templates, i)
    all_templates.push(template)
  }
  let track_count = all_templates.length()
  let total_gaps = if track_count > 1 {
    gap * (track_count - 1).to_double()
  } else {
    0.0
  }

  // Phase 1: Calculate base sizes (minimum for minmax, fixed for others)
  let base_sizes : Array[Double] = []
  let min_sizes : Array[Double] = []
  let max_sizes : Array[Double] = []
  let mut total_fr = 0.0
  let mut fixed_size = 0.0
  for i = 0; i < track_count; i = i + 1 {
    let template = all_templates[i]
    let min_content = if i < min_content_sizes.length() {
      min_content_sizes[i]
    } else {
      0.0
    }
    let max_content = if i < max_content_sizes.length() {
      max_content_sizes[i]
    } else {
      0.0
    }
    match template {
      @style.Length(v) => {
        base_sizes.push(v)
        min_sizes.push(v)
        max_sizes.push(v)
        fixed_size = fixed_size + v
      }
      @style.Percent(p) => {
        // Percent tracks resolve to 0 when container size is indefinite
        let size = if size_is_definite { available_size * p } else { 0.0 }
        base_sizes.push(size)
        min_sizes.push(size)
        max_sizes.push(size)
        fixed_size = fixed_size + size
      }
      @style.Fr(fr) => {
        base_sizes.push(0.0)
        min_sizes.push(0.0)
        max_sizes.push(1.0e10) // Effectively unlimited
        total_fr = total_fr + fr
      }
      @style.Auto => {
        // Auto uses max-content for base size but can shrink to min-content
        base_sizes.push(max_content)
        min_sizes.push(min_content)
        max_sizes.push(1.0e10)
        fixed_size = fixed_size + max_content
      }
      @style.MinContent => {
        // MinContent track uses min-content size
        base_sizes.push(min_content)
        min_sizes.push(min_content)
        max_sizes.push(min_content)
        fixed_size = fixed_size + min_content
      }
      @style.MaxContent => {
        // MaxContent track uses max-content size
        base_sizes.push(max_content)
        min_sizes.push(max_content)
        max_sizes.push(max_content)
        fixed_size = fixed_size + max_content
      }
      @style.MinMax(min_track, max_track) => {
        let min_size = resolve_min_track_size(
          min_track, available_size, min_content, max_content,
        )
        let max_size = resolve_max_track_size(
          max_track, available_size, min_content, max_content,
        )
        // Base size depends on whether max is flexible or finite
        let base = if max_size < 1.0e9 {
          // Finite max: use it as base, clamped to min
          if max_size > min_size { max_size } else { min_size }
        } else {
          // Infinite max (fr/auto): use max-content as base, clamped to min
          if max_content > min_size { max_content } else { min_size }
        }
        base_sizes.push(base)
        min_sizes.push(min_size)
        max_sizes.push(max_size)
        fixed_size = fixed_size + base
      }
      @style.Repeat(_, _) => {
        // Repeat should be expanded before reaching here
        // Treat as auto if unexpanded
        base_sizes.push(max_content)
        min_sizes.push(min_content)
        max_sizes.push(1.0e10)
        fixed_size = fixed_size + max_content
      }
    }
  }

  // Phase 2: Distribute remaining space
  let remaining_space = max(0.0, available_size - fixed_size - total_gaps)

  // If we have fr units, distribute to them first
  if total_fr > 0.0 {
    let fr_unit = remaining_space / total_fr
    for i = 0; i < track_count; i = i + 1 {
      let template = all_templates[i]
      match template {
        @style.Fr(fr) => base_sizes[i] = fr * fr_unit
        _ => ()
      }
    }
  } else if size_is_definite {
    // No fr units but definite size - distribute remaining to auto and minmax tracks
    let space_to_distribute = remaining_space
    let mut growable_count = 0

    // Count tracks that can grow (Auto or MinMax with room to grow)
    for i = 0; i < track_count; i = i + 1 {
      match all_templates[i] {
        @style.Auto =>
          if max_sizes[i] > base_sizes[i] {
            growable_count = growable_count + 1
          }
        @style.MinMax(_, _) =>
          if max_sizes[i] > base_sizes[i] {
            growable_count = growable_count + 1
          }
        _ => ()
      }
    }

    // Distribute space evenly to growable tracks
    if growable_count > 0 {
      let space_per_track = space_to_distribute / growable_count.to_double()
      for i = 0; i < track_count; i = i + 1 {
        match all_templates[i] {
          @style.Auto => {
            let growth = min_double(
              space_per_track,
              max_sizes[i] - base_sizes[i],
            )
            base_sizes[i] = base_sizes[i] + growth
          }
          @style.MinMax(_, _) => {
            let growth = min_double(
              space_per_track,
              max_sizes[i] - base_sizes[i],
            )
            base_sizes[i] = base_sizes[i] + growth
          }
          _ => ()
        }
      }
    }
  }
  // If size is indefinite (auto), auto tracks just use their content size

  // Phase 2.5: Handle overflow - shrink flexible tracks if total exceeds available
  let mut total_size = 0.0
  for i = 0; i < track_count; i = i + 1 {
    total_size = total_size + base_sizes[i]
  }
  total_size = total_size + total_gaps
  if total_size > available_size {
    // We need to shrink tracks
    // Priority: 1) Auto tracks shrink first (to min-content)
    //           2) MinMax tracks shrink second (to their min)
    let mut remaining_overflow = total_size - available_size

    // Step 1: Shrink Auto tracks to min-content
    for i = 0; i < track_count; i = i + 1 {
      if remaining_overflow <= 0.0 {
        break
      }
      match all_templates[i] {
        @style.Auto => {
          let shrinkable = base_sizes[i] - min_sizes[i]
          if shrinkable > 0.0 {
            let shrink = min_double(shrinkable, remaining_overflow)
            base_sizes[i] = base_sizes[i] - shrink
            remaining_overflow = remaining_overflow - shrink
          }
        }
        _ => ()
      }
    }

    // Step 2: If still overflowing, shrink MinMax tracks to their minimum
    if remaining_overflow > 0.0 {
      let mut shrinkable_count = 0
      for i = 0; i < track_count; i = i + 1 {
        match all_templates[i] {
          @style.MinMax(_, _) =>
            if base_sizes[i] > min_sizes[i] {
              shrinkable_count = shrinkable_count + 1
            }
          _ => ()
        }
      }
      if shrinkable_count > 0 {
        let shrink_per_track = remaining_overflow / shrinkable_count.to_double()
        for i = 0; i < track_count; i = i + 1 {
          match all_templates[i] {
            @style.MinMax(_, _) =>
              // Don't shrink below minimum size
              base_sizes[i] = max(min_sizes[i], base_sizes[i] - shrink_per_track)
            _ => ()
          }
        }
      }
    }
  }

  // Phase 3: Build track array with positions
  // Also determine which tracks are stretchable (auto, fr, or minmax with flexible max)
  for i = 0; i < track_count; i = i + 1 {
    let is_stretchable = match all_templates[i] {
      @style.Auto => true
      @style.Fr(_) => true
      @style.MinMax(_, _) => true
      _ => false
    }
    tracks.push({ position, size: base_sizes[i], stretchable: is_stretchable })
    position = position + base_sizes[i] + gap
  }
  tracks
}

///|
/// Get auto template at index (cycles through auto_templates array)
fn get_auto_template(
  auto_templates : Array[@style.TrackSizingFunction],
  index : Int,
) -> @style.TrackSizingFunction {
  if auto_templates.length() == 0 {
    // Default to Auto if no auto templates specified
    @style.Auto
  } else {
    // Cycle through templates
    auto_templates[index % auto_templates.length()]
  }
}

///|
/// Get auto template in reverse order (for implicit tracks before explicit grid)
/// k is 1-indexed distance from explicit grid: k=1 is closest, uses last template
fn get_auto_template_reverse(
  auto_templates : Array[@style.TrackSizingFunction],
  k : Int,
) -> @style.TrackSizingFunction {
  if auto_templates.length() == 0 {
    @style.Auto
  } else {
    let length = auto_templates.length()
    // k=1 → last template (index length-1)
    // k=2 → second to last (index length-2)
    // etc., with wrapping
    let index = (length - 1 - (k - 1) % length + length) % length
    auto_templates[index]
  }
}

///|
/// Grid area bounds (row_start, row_end, col_start, col_end)
struct GridAreaBounds {
  row_start : Int
  row_end : Int
  col_start : Int
  col_end : Int
} derive(Show)

///|
/// Parse grid-template-areas into a 2D array of area names
fn parse_grid_template_areas(
  template_areas : Array[String],
) -> Array[Array[String]] {
  let result : Array[Array[String]] = []
  for i = 0; i < template_areas.length(); i = i + 1 {
    let row_str = template_areas[i]
    let cells : Array[String] = []
    // Split by whitespace
    let mut current = ""
    for c in row_str {
      if c == ' ' || c == '\t' {
        if current.length() > 0 {
          cells.push(current)
          current = ""
        }
      } else {
        current = current + c.to_string()
      }
    }
    if current.length() > 0 {
      cells.push(current)
    }
    result.push(cells)
  }
  result
}

///|
/// Find the bounds of a named grid area
fn find_grid_area_bounds(
  areas : Array[Array[String]],
  name : String,
) -> GridAreaBounds? {
  let mut min_row = -1
  let mut max_row = -1
  let mut min_col = -1
  let mut max_col = -1
  for row = 0; row < areas.length(); row = row + 1 {
    let cols = areas[row]
    for col = 0; col < cols.length(); col = col + 1 {
      if cols[col] == name {
        if min_row < 0 || row < min_row {
          min_row = row
        }
        if max_row < 0 || row > max_row {
          max_row = row
        }
        if min_col < 0 || col < min_col {
          min_col = col
        }
        if max_col < 0 || col > max_col {
          max_col = col
        }
      }
    }
  }
  if min_row >= 0 {
    Some({ row_start: min_row, row_end: max_row + 1, col_start: min_col, col_end: max_col + 1 })
  } else {
    None
  }
}

///|
/// Place grid items using auto-placement algorithm with occupancy tracking
fn place_grid_items(
  children : Array[@node.Node],
  explicit_columns : Int,
  explicit_rows : Int,
  auto_flow : @style.GridAutoFlow,
  grid_areas : Array[Array[String]],
) -> Array[GridItemPlacement] {
  let placements : Array[GridItemPlacement] = []
  let columns = if explicit_columns > 0 { explicit_columns } else { 1 }

  // Grid occupation matrix (simplified: row-first filling)
  // In a full implementation, we'd track which cells are occupied
  let mut next_row = 0
  let mut next_column = 0
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style

    // Skip hidden children
    if style.display == @style.None {
      placements.push({
        row_start: 0,
        row_end: 0,
        column_start: 0,
        column_end: 0,
      })
      continue
    }

    // Check for grid-area placement first
    let area_placement = match style.grid_area {
      Some(area_name) => find_grid_area_bounds(grid_areas, area_name)
      None => None
    }

    let (col_start, col_end, row_start, row_end) = match area_placement {
      Some(bounds) =>
        // Use area bounds
        (bounds.col_start, bounds.col_end, bounds.row_start, bounds.row_end)
      None => {
        // Resolve grid placement using grid-column and grid-row
        let (cs, ce) = resolve_line_placement(
          style.grid_column,
          next_column,
          columns,
        )
        let (rs, re) = resolve_line_placement(
          style.grid_row,
          next_row,
          explicit_rows,
        )
        (cs, ce, rs, re)
      }
    }
    placements.push({
      row_start,
      row_end,
      column_start: col_start,
      column_end: col_end,
    })

    // Check if this item has explicit positioning
    // Span is not explicit - it means "auto-place with this span"
    let has_explicit_column = match style.grid_column.start {
      @style.Auto | @style.Span(_) => false
      _ => true
    }
    let has_explicit_row = match style.grid_row.start {
      @style.Auto | @style.Span(_) => false
      _ => true
    }

    // Only advance position for auto-placed items (not explicitly positioned items)
    // An item with explicit position in the primary axis should not affect cursor
    let is_explicitly_positioned = has_explicit_column || has_explicit_row
    match auto_flow {
      @style.Row | @style.RowDense =>
        // Only advance if not explicitly positioned
        if not(is_explicitly_positioned) {
          next_column = col_end
          if next_column >= columns {
            next_column = 0
            next_row = next_row + 1
          }
        }
      @style.Column | @style.ColumnDense =>
        // Only advance if not explicitly positioned
        if not(is_explicitly_positioned) {
          next_row = row_end
          if next_row >= explicit_rows && explicit_rows > 0 {
            next_row = 0
            next_column = next_column + 1
          }
        }
    }
  }
  placements
}

///|
/// Resolve a grid line placement to start/end indices (0-indexed)
/// Negative indices are allowed - they indicate implicit tracks before the explicit grid
fn resolve_line_placement(
  line : @style.GridLine,
  auto_position : Int,
  explicit_count : Int,
) -> (Int, Int) {
  let start = match line.start {
    @style.Auto => auto_position
    @style.Line(n) =>
      if n > 0 {
        n - 1 // Convert 1-indexed to 0-indexed
      } else if n < 0 {
        // Negative indices count from end of explicit grid
        // For N explicit tracks, there are N+1 lines numbered 1 to N+1
        // Line(-1) = Line(N+1), Line(-2) = Line(N), etc.
        // Line number to track index: Line k → track k-1
        // For 1-column grid: Line(-1)=2→track 1, Line(-2)=1→track 0, Line(-3)=0→track -1
        explicit_count + 1 + n // Don't clamp - negative values are valid for implicit tracks
      } else {
        auto_position
      }
    @style.Span(_) => auto_position
  }
  let end = match line.end {
    @style.Auto => start + 1
    @style.Line(n) =>
      if n > 0 {
        n - 1
      } else if n < 0 {
        explicit_count + 1 + n // Don't clamp
      } else {
        start + 1
      }
    @style.Span(s) => start + s
  }

  // Handle span in start position
  let (final_start, final_end) = match line.start {
    @style.Span(s) =>
      match line.end {
        @style.Line(n) => {
          let e = if n > 0 { n - 1 } else { explicit_count + 1 + n }
          (e - s, e)
        }
        _ => (start, start + s)
      }
    _ => (start, end)
  }

  // Ensure end > start, but allow negative start values
  (
    final_start,
    if final_end > final_start {
      final_end
    } else {
      final_start + 1
    },
  )
}

///|
/// Get the bounds (position and size) for a span of tracks
fn get_span_bounds(
  tracks : Array[GridTrack],
  start : Int,
  end : Int,
) -> (Double, Double) {
  if tracks.length() == 0 {
    return (0.0, 0.0)
  }
  let track_count = tracks.length()
  let clamped_start = if start < track_count { start } else { track_count - 1 }
  let clamped_end = if end < track_count { end } else { track_count }
  if clamped_start >= track_count || clamped_end <= clamped_start {
    return (0.0, 0.0)
  }
  let start_track = tracks[clamped_start]
  let mut total_size = 0.0
  for i = clamped_start; i < clamped_end && i < track_count; i = i + 1 {
    total_size = total_size + tracks[i].size
  }

  // Add gaps between spanned tracks
  if clamped_end > clamped_start + 1 && clamped_start + 1 < track_count {
    let gap = tracks[clamped_start + 1].position -
      (start_track.position + start_track.size)
    total_size = total_size +
      gap * (clamped_end - clamped_start - 1).to_double()
  }
  (start_track.position, total_size)
}

///|
/// Compute layout for a child element
fn compute_child_layout(
  child : @node.Node,
  available_width : Double,
  available_height : Double,
) -> @node.Layout {
  // For leaf nodes with auto dimensions, use intrinsic sizes
  let intrinsic = get_intrinsic_from_measure(child, available_width, available_height)

  // Check if dimensions are constrained
  let width_is_constrained = match child.style.width {
    @types.Auto =>
      // Also constrained if max_width is set
      match child.style.max_width {
        @types.Auto => false
        _ => true
      }
    _ => true
  }

  // Determine default size for auto dimension
  // For leaf nodes:
  // - When width is unconstrained: use min height (content shrinks in both directions)
  // - When width is constrained: use max height (content can expand vertically)
  // For containers: use available size (will be computed by nested layout)
  let is_leaf = child.children.length() == 0
  let width_default = if is_leaf { intrinsic.min_width } else { available_width }
  // Height uses max if width is constrained (text wrapping behavior)
  let height_default = if is_leaf {
    if width_is_constrained { intrinsic.max_height } else { intrinsic.min_height }
  } else {
    available_height
  }

  // Resolve child size
  let mut width = resolve_dimension(
    child.style.width,
    available_width,
    width_default,
  )
  let mut height = resolve_dimension(
    child.style.height,
    available_height,
    height_default,
  )

  // Resolve padding and border for minimum size enforcement
  let padding_left = resolve_dimension(child.style.padding.left, available_width, 0.0)
  let padding_right = resolve_dimension(child.style.padding.right, available_width, 0.0)
  let padding_top = resolve_dimension(child.style.padding.top, available_height, 0.0)
  let padding_bottom = resolve_dimension(child.style.padding.bottom, available_height, 0.0)
  let border_left = resolve_dimension(child.style.border.left, available_width, 0.0)
  let border_right = resolve_dimension(child.style.border.right, available_width, 0.0)
  let border_top = resolve_dimension(child.style.border.top, available_height, 0.0)
  let border_bottom = resolve_dimension(child.style.border.bottom, available_height, 0.0)

  // Padding + border creates minimum size
  let min_width = padding_left + padding_right + border_left + border_right
  let min_height = padding_top + padding_bottom + border_top + border_bottom
  if width < min_width {
    width = min_width
  }
  if height < min_height {
    height = min_height
  }

  // Apply aspect_ratio if one dimension is auto
  match child.style.aspect_ratio {
    Some(ratio) => {
      let width_is_auto = match child.style.width {
        @types.Auto => true
        _ => false
      }
      let height_is_auto = match child.style.height {
        @types.Auto => true
        _ => false
      }
      if width_is_auto && not(height_is_auto) {
        // height is explicit, compute width from aspect_ratio
        width = height * ratio
      } else if height_is_auto && not(width_is_auto) {
        // width is explicit, compute height from aspect_ratio
        height = width / ratio
      }
    }
    None => ()
  }

  // For nested containers, recursively compute layout
  let child_layouts : Array[@node.Layout] = []
  if child.style.display == @style.Grid {
    // Recursively compute grid layout for nested grid containers
    let nested_layout = compute_grid_layout(child, width, height)
    // The nested layout's children need to be added
    for i = 0; i < nested_layout.children.length(); i = i + 1 {
      child_layouts.push(nested_layout.children[i])
    }
  } else if child.style.display == @style.Flex {
    // Recursively compute flex layout for nested flex containers
    let ctx : @node.LayoutContext = {
      available_width: width,
      available_height: Some(height),
    }
    let nested_layout = @flex.compute(child, ctx)
    for i = 0; i < nested_layout.children.length(); i = i + 1 {
      child_layouts.push(nested_layout.children[i])
    }
  } else {
    // For non-container children, still need to recursively compute layouts
    for i = 0; i < child.children.length(); i = i + 1 {
      let grandchild = child.children[i]
      let grandchild_layout = compute_child_layout(grandchild, width, height)
      child_layouts.push(grandchild_layout)
    }
  }

  {
    id: child.id,
    x: 0.0,
    y: 0.0,
    width,
    height,
    margin: default_rect(),
    padding: default_rect(),
    border: default_rect(),
    children: child_layouts,
  }
}

///|
/// Apply alignment to a grid item
fn apply_alignment(
  child : @node.Node,
  container_style : @style.Style,
  cell_x : Double,
  cell_y : Double,
  cell_width : Double,
  cell_height : Double,
  child_layout : @node.Layout,
) -> (Double, Double, Double, Double) {
  let child_style = child.style

  // Resolve child margins
  // CSS spec: All percentage margins (including top/bottom) are resolved against the width
  let margin_left = resolve_dimension(child_style.margin.left, cell_width, 0.0)
  let margin_right = resolve_dimension(
    child_style.margin.right,
    cell_width,
    0.0,
  )
  let margin_top = resolve_dimension(child_style.margin.top, cell_width, 0.0)
  let margin_bottom = resolve_dimension(
    child_style.margin.bottom,
    cell_width,
    0.0,
  )

  // Available space after margins
  let available_width = cell_width - margin_left - margin_right
  let available_height = cell_height - margin_top - margin_bottom

  // Get effective alignment
  // In Taffy, align_self applies to both axes when justify_self is not specified
  let align = match child_style.align_self {
    @style.Auto => container_style.align_items
    @style.Start => @style.Start
    @style.End => @style.End
    @style.Center => @style.Center
    @style.Stretch => @style.Stretch
  }
  // Use align_self for justify too (matches Taffy behavior)
  let justify = match child_style.align_self {
    @style.Auto => container_style.justify_items
    @style.Start => @style.Start
    @style.End => @style.End
    @style.Center => @style.Center
    @style.Stretch => @style.Stretch
  }

  // Check if aspect_ratio constrains dimensions
  let has_aspect_ratio = match child_style.aspect_ratio {
    Some(_) => true
    None => false
  }
  let width_is_auto = match child_style.width {
    @types.Auto => true
    _ => false
  }
  let height_is_auto = match child_style.height {
    @types.Auto => true
    _ => false
  }

  // Calculate item size - don't clamp to cell size, allow overflow
  // If aspect_ratio derived a dimension, don't stretch that dimension
  let mut item_width = match child_style.width {
    @types.Auto =>
      if has_aspect_ratio && not(height_is_auto) {
        // Width derived from aspect_ratio, use computed width
        child_layout.width
      } else if justify == @style.Stretch {
        available_width
      } else {
        child_layout.width
      }
    _ => child_layout.width // Keep explicit size, don't clamp
  }
  let mut item_height = match child_style.height {
    @types.Auto =>
      if has_aspect_ratio && not(width_is_auto) {
        // Height derived from aspect_ratio, use computed height
        child_layout.height
      } else if align == @style.Stretch {
        available_height
      } else {
        child_layout.height
      }
    _ => child_layout.height // Keep explicit size, don't clamp
  }

  // Apply min/max constraints
  let resolved_min_width = resolve_dimension(child_style.min_width, cell_width, 0.0)
  let resolved_max_width = resolve_dimension(child_style.max_width, cell_width, 1.0e10)
  let resolved_min_height = resolve_dimension(child_style.min_height, cell_height, 0.0)
  let resolved_max_height = resolve_dimension(child_style.max_height, cell_height, 1.0e10)
  if item_width < resolved_min_width {
    item_width = resolved_min_width
  }
  if item_width > resolved_max_width {
    item_width = resolved_max_width
  }
  if item_height < resolved_min_height {
    item_height = resolved_min_height
  }
  if item_height > resolved_max_height {
    item_height = resolved_max_height
  }

  // Calculate position based on alignment
  let x_offset = match justify {
    @style.Start => 0.0
    @style.End => available_width - item_width
    @style.Center => (available_width - item_width) / 2.0
    @style.Stretch => 0.0
    _ => 0.0
  }
  let y_offset = match align {
    @style.Start => 0.0
    @style.End => available_height - item_height
    @style.Center => (available_height - item_height) / 2.0
    @style.Stretch => 0.0
    _ => 0.0
  }

  // Apply inset for relative positioning
  let inset_left = resolve_dimension(child_style.inset.left, cell_width, 0.0)
  let inset_top = resolve_dimension(child_style.inset.top, cell_height, 0.0)

  (
    cell_x + margin_left + x_offset + inset_left,
    cell_y + margin_top + y_offset + inset_top,
    item_width,
    item_height,
  )
}

///|
/// Calculate the first baseline of a node
/// For blocks without children, baseline is at the bottom
/// For blocks with children, baseline is the first child's baseline
fn calculate_baseline(node : @node.Node, layout : @node.Layout) -> Double {
  if node.children.length() > 0 && layout.children.length() > 0 {
    // Baseline is the first child's baseline, offset by the child's position
    let first_child = node.children[0]
    let first_child_layout = layout.children[0]
    first_child_layout.y + calculate_baseline(first_child, first_child_layout)
  } else {
    // For blocks without children, baseline is at the bottom
    layout.height
  }
}

///|
/// Information about an item's baseline for alignment
struct BaselineInfo {
  index : Int // Index in children array
  row : Int // Row index
  ascent : Double // Distance from top to baseline
  descent : Double // Distance from baseline to bottom
  height : Double // Total height
} derive(Show)

///|
/// Calculate baseline info for an item
fn get_baseline_info(
  index : Int,
  row : Int,
  node : @node.Node,
  layout : @node.Layout,
) -> BaselineInfo {
  let baseline = calculate_baseline(node, layout)
  {
    index,
    row,
    ascent: baseline,
    descent: layout.height - baseline,
    height: layout.height,
  }
}
