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
  size_is_definite? : Bool = true,
) -> Double {
  match min_track {
    @style.MinTrackSizing::Length(v) => v
    @style.MinTrackSizing::Percent(p) =>
      // In indefinite containers, percent behaves as auto (0.0)
      if size_is_definite {
        available_size * p
      } else {
        0.0
      }
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
  size_is_definite? : Bool = true,
) -> Double {
  match max_track {
    @style.MaxTrackSizing::Length(v) => v
    @style.MaxTrackSizing::Percent(p) =>
      // In indefinite containers, percent behaves as auto (max-content)
      if size_is_definite {
        available_size * p
      } else {
        max_content_size
      }
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
/// Static default rect for margins, padding, border (avoids repeated allocation)
let default_rect_value : @types.Rect[Double] = {
  left: 0.0,
  right: 0.0,
  top: 0.0,
  bottom: 0.0,
}

///|
/// Create default layout rect for margins, padding, border
fn default_rect() -> @types.Rect[Double] {
  default_rect_value
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
  // Call internal function with size_is_definite = false by default
  // (public API assumes caller doesn't know about definiteness)
  compute_grid_layout_internal(
    node, available_width, available_height, false, false,
  )
}

///|
/// Internal grid layout computation with explicit definiteness flags
fn compute_grid_layout_internal(
  node : @node.Node,
  available_width : Double,
  available_height : Double,
  width_is_extrinsically_definite : Bool,
  height_is_extrinsically_definite : Bool,
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
  // When there are negative placements, offsets shift the explicit grid,
  // so we must add offsets to explicit counts as well
  let total_column_count = max_int(
    explicit_column_count + col_offset,
    col_max_idx + col_offset,
  )
  let total_row_count = max_int(
    explicit_row_count + row_offset,
    row_max_idx + row_offset,
  )

  // Calculate intrinsic content sizes for tracks (min-content and max-content)
  let (column_min_content, column_max_content) = calculate_track_intrinsic_sizes(
    children,
    adjusted_placements,
    total_column_count,
    true, // is_column
    container_width_for_expansion,
    expanded_columns,
    style.grid_auto_columns,
    col_offset,
  )
  let (row_min_content, row_max_content) = calculate_track_intrinsic_sizes(
    children,
    adjusted_placements,
    total_row_count,
    false, // is_column
    container_width_for_expansion, // CSS: percent padding resolves against width
    expanded_rows,
    style.grid_auto_rows,
    row_offset,
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

  // Size is definite for track sizing if:
  // 1. Style has explicit size (not Auto), OR
  // 2. Size is extrinsically definite (e.g., stretched in parent grid)
  let width_is_definite = not(width_is_auto) || width_is_extrinsically_definite
  let height_is_definite = not(height_is_auto) ||
    height_is_extrinsically_definite

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
    width_is_definite, // Distribute remaining space if width is definite
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
    height_is_definite, // Distribute remaining space if height is definite
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
      let (_, item_width) = get_span_bounds(
        column_tracks,
        placement.column_start,
        placement.column_end,
      )
      let (_, item_height) = get_span_bounds(
        row_tracks,
        row_start,
        placement.row_end,
      )

      // Compute child layout for baseline info
      let child_inner = compute_child_layout(child, item_width, item_height)
      let baseline = calculate_baseline(child, child_inner)
      let descent = child_inner.height - baseline

      // Update max ascent/descent for this row
      let (current_ascent, current_descent) = row_baseline_heights
        .get(row_start)
        .unwrap_or((0.0, 0.0))
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

  // Resolve min/max width/height constraints
  let resolved_min_width = match style.min_width {
    @types.Length(v) => max(v, min_width)
    @types.Percent(p) => max(p * available_width, min_width)
    @types.Auto => min_width
  }
  let resolved_max_width = match style.max_width {
    @types.Length(v) => v
    @types.Percent(p) => p * available_width
    @types.Auto => 1.0e10
  }
  let resolved_min_height = match style.min_height {
    @types.Length(v) => max(v, min_height)
    @types.Percent(p) => max(p * available_height, min_height)
    @types.Auto => min_height
  }
  let resolved_max_height = match style.max_height {
    @types.Length(v) => v
    @types.Percent(p) => p * available_height
    @types.Auto => 1.0e10
  }
  let container_width = if width_is_auto {
    // Sum of track sizes + gaps + padding + border
    let total_track_width = calculate_total_track_size(
      column_tracks, column_gap,
    )

    // For percent tracks in indefinite containers, use content-based sizing
    let mut content_max_width = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      if child.style.display == @style.None {
        continue
      }
      match child.style.width {
        @types.Length(w) => if w > content_max_width { content_max_width = w }
        _ => ()
      }
    }

    // Use max of track-based and content-based size
    let effective_width = max(total_track_width, content_max_width)
    let raw_width = effective_width +
      padding_left +
      padding_right +
      border_left +
      border_right
    // Apply min/max constraints, with padding+border as absolute minimum
    let clamped = if raw_width > resolved_max_width {
      resolved_max_width
    } else {
      raw_width
    }
    if clamped < resolved_min_width {
      resolved_min_width
    } else {
      clamped
    }
    // Enforce minimum size from padding + border
  } else if preliminary_width > min_width {
    preliminary_width
  } else {
    min_width
  }
  let container_height = if height_is_auto {
    let total_track_height = calculate_total_track_size(row_tracks, row_gap)

    // For percent tracks in indefinite containers, use content-based sizing
    let mut content_max_height = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      if child.style.display == @style.None {
        continue
      }
      match child.style.height {
        @types.Length(h) => if h > content_max_height { content_max_height = h }
        _ => ()
      }
    }

    // Use max of track-based and content-based size
    let effective_height = max(total_track_height, content_max_height)
    let raw_height = effective_height +
      padding_top +
      padding_bottom +
      border_top +
      border_bottom
    // Apply min/max constraints, with padding+border as absolute minimum
    let clamped = if raw_height > resolved_max_height {
      resolved_max_height
    } else {
      raw_height
    }
    if clamped < resolved_min_height {
      resolved_min_height
    } else {
      clamped
    }
    // Enforce minimum size from padding + border
  } else if preliminary_height > min_height {
    preliminary_height
  } else {
    min_height
  }

  // Second pass: resolve percent tracks now that container size is known
  // This is needed for indefinite containers with percent-based tracks
  if width_is_auto {
    let content_width = container_width -
      padding_left -
      padding_right -
      border_left -
      border_right
    let mut pos = 0.0
    for i = 0; i < column_tracks.length(); i = i + 1 {
      let explicit_index = i - col_offset
      let template = if explicit_index >= 0 &&
        explicit_index < expanded_columns.length() {
        expanded_columns[explicit_index]
      } else {
        @style.Auto
      }
      let min_content = if i < column_min_content.length() {
        column_min_content[i]
      } else {
        0.0
      }
      let max_content = if i < column_max_content.length() {
        column_max_content[i]
      } else {
        0.0
      }
      let new_size = match template {
        @style.Percent(p) => content_width * p
        @style.MinMax(min_track, @style.MaxTrackSizing::Percent(p)) => {
          // CSS spec: when min > max in minmax(), min wins
          let percent_size = content_width * p
          let min_size = resolve_min_track_size(
            min_track,
            content_width,
            min_content,
            max_content,
            size_is_definite=true,
          )
          if min_size > percent_size {
            min_size
          } else {
            percent_size
          }
        }
        _ => column_tracks[i].size
      }
      column_tracks[i] = {
        position: pos,
        size: new_size,
        stretchable: column_tracks[i].stretchable,
      }
      pos = pos + new_size + column_gap
    }
  }
  if height_is_auto {
    let content_height = container_height -
      padding_top -
      padding_bottom -
      border_top -
      border_bottom
    let mut pos = 0.0
    for i = 0; i < row_tracks.length(); i = i + 1 {
      let explicit_index = i - row_offset
      let template = if explicit_index >= 0 &&
        explicit_index < expanded_rows.length() {
        expanded_rows[explicit_index]
      } else {
        @style.Auto
      }
      let min_content = if i < row_min_content.length() {
        row_min_content[i]
      } else {
        0.0
      }
      let max_content = if i < row_max_content.length() {
        row_max_content[i]
      } else {
        0.0
      }
      let new_size = match template {
        @style.Percent(p) => content_height * p
        @style.MinMax(min_track, @style.MaxTrackSizing::Percent(p)) => {
          // CSS spec: when min > max in minmax(), min wins
          let percent_size = content_height * p
          let min_size = resolve_min_track_size(
            min_track,
            content_height,
            min_content,
            max_content,
            size_is_definite=true,
          )
          if min_size > percent_size {
            min_size
          } else {
            percent_size
          }
        }
        _ => row_tracks[i].size
      }
      row_tracks[i] = {
        position: pos,
        size: new_size,
        stretchable: row_tracks[i].stretchable,
      }
      pos = pos + new_size + row_gap
    }
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

  // Padding box for absolute positioning (containing block)
  let padding_box_left = border_left
  let padding_box_top = border_top
  let padding_box_width = container_width - border_left - border_right
  let padding_box_height = container_height - border_top - border_bottom

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
      baseline_infos.push({
        index: i,
        row: -1,
        ascent: 0.0,
        descent: 0.0,
        height: 0.0,
      })
      continue
    }

    // Handle absolute positioned children
    if child.style.position == @style.Absolute {
      let abs_layout = layout_absolute_child(
        child,
        padding_box_left,
        padding_box_top,
        padding_box_width,
        padding_box_height,
        padding_left, // content_box_offset_x = content_box_left - padding_box_left
        padding_top, // content_box_offset_y = content_box_top - padding_box_top
        column_tracks,
        row_tracks,
        col_offset,
        row_offset,
        explicit_column_count,
        explicit_row_count,
      )
      preliminary_layouts.push(abs_layout)
      baseline_infos.push({
        index: i,
        row: -1,
        ascent: 0.0,
        descent: 0.0,
        height: 0.0,
      })
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
      baseline_infos.push({
        index: i,
        row: -1,
        ascent: 0.0,
        descent: 0.0,
        height: 0.0,
      })
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
        child_layouts.push({ ..layout, y: layout.y + baseline_offset })
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
  let track_count = tracks.length()
  match alignment {
    @style.Start | @style.Baseline =>
      // Start: tracks at start, no adjustment
      // Baseline: treated as start for content alignment
      ()
    @style.Stretch => {
      // Only distribute positive free_space
      if free_space <= 0.0 {
        return
      }
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
      if track_count <= 1 || free_space <= 0.0 {
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
      if free_space <= 0.0 {
        return
      }
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
      if free_space <= 0.0 {
        return
      }
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
/// Implements CSS Grid intrinsic sizing algorithm with support for spanning items
fn calculate_track_intrinsic_sizes(
  children : Array[@node.Node],
  placements : Array[GridItemPlacement],
  track_count : Int,
  is_column : Bool,
  container_width : Double, // For resolving percent padding
  templates : Array[@style.TrackSizingFunction], // Track templates for type-aware distribution
  auto_templates : Array[@style.TrackSizingFunction], // Auto track templates
  explicit_offset : Int, // Offset for explicit tracks
) -> (Array[Double], Array[Double]) {
  // (min_content_sizes, max_content_sizes)
  let min_sizes : Array[Double] = []
  let max_sizes : Array[Double] = []
  for i = 0; i < track_count; i = i + 1 {
    min_sizes.push(0.0)
    max_sizes.push(0.0)
  }

  // Build track type array for distribution decisions
  let track_types : Array[@style.TrackSizingFunction] = []
  let explicit_count = templates.length()
  for i = 0; i < track_count; i = i + 1 {
    let track_type = if i < explicit_offset {
      // Implicit track before explicit grid
      let k = explicit_offset - i
      get_auto_template_reverse(auto_templates, k)
    } else if i < explicit_offset + explicit_count {
      // Explicit track
      templates[i - explicit_offset]
    } else {
      // Implicit track after explicit grid
      get_auto_template(auto_templates, i - explicit_offset - explicit_count)
    }
    track_types.push(track_type)
  }

  // Collect item info with span lengths
  // (index, start, end, min_content_contrib, minimum_contrib, max_contrib)
  // min_content_contrib: for min-content tracks (unaffected by overflow)
  // minimum_contrib: for auto tracks (0 for overflow clips)
  let items : Array[(Int, Int, Int, Double, Double, Double)] = []
  let mut max_span = 1
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

    // Skip items outside track range
    if track_start < 0 || track_end > track_count {
      continue
    }
    let span = track_end - track_start
    if span > max_span {
      max_span = span
    }
    let (min_content, max_content, margin_start, margin_end) = calculate_item_intrinsic_sizes(
      child, is_column, container_width,
    )
    let min_content_contribution = min_content + margin_start + margin_end
    let max_contribution = max_content + margin_start + margin_end

    // CSS Grid spec: for auto tracks, overflow:hidden items have minimum contribution of 0
    let overflow = if is_column {
      child.style.overflow_x
    } else {
      child.style.overflow_y
    }
    let has_overflow_clip = overflow != @style.Visible
    let minimum_contribution = if has_overflow_clip {
      margin_start + margin_end
    } else {
      min_content_contribution
    }
    items.push(
      (
        i, track_start, track_end, min_content_contribution, minimum_contribution,
        max_contribution,
      ),
    )
  }

  // Phase 1: Handle single-span items
  for item in items {
    let (_, start, end, min_content_contrib, minimum_contrib, max_contrib) = item
    if end - start == 1 {
      // Choose which min contribution to use based on track type
      // For min-content tracks: use min_content_contrib
      // For auto/fr/other tracks: use minimum_contrib (respects overflow)
      let min_contrib = match track_types[start] {
        @style.MinContent => min_content_contrib
        _ => minimum_contrib
      }
      if min_contrib > min_sizes[start] {
        min_sizes[start] = min_contrib
      }
      if max_contrib > max_sizes[start] {
        max_sizes[start] = max_contrib
      }
    }
  }

  // Phase 2: Handle multi-span items (span 2, 3, ... up to max_span)
  for span_length = 2; span_length <= max_span; span_length = span_length + 1 {
    for item in items {
      let (_, start, end, min_content_contrib, minimum_contrib, max_contrib) = item
      let span = end - start
      if span != span_length {
        continue
      }

      // For spanning items, check if any spanned track is MinContent
      // If so, use min_content_contrib, otherwise use minimum_contrib
      let mut has_min_content_track = false
      for t = start; t < end; t = t + 1 {
        match track_types[t] {
          @style.MinContent => has_min_content_track = true
          _ => ()
        }
      }
      let min_contrib = if has_min_content_track {
        min_content_contrib
      } else {
        minimum_contrib
      }

      // Calculate current sum of spanned tracks
      let mut min_sum = 0.0
      let mut max_sum = 0.0
      for t = start; t < end; t = t + 1 {
        min_sum = min_sum + min_sizes[t]
        max_sum = max_sum + max_sizes[t]
      }

      // Calculate extra space needed
      let min_extra = min_contrib - min_sum
      let max_extra = max_contrib - max_sum

      // Count tracks that can grow for max-content distribution
      // MinContent tracks should not grow for max-content
      let mut growable_count = 0
      for t = start; t < end; t = t + 1 {
        let can_grow = match track_types[t] {
          @style.MinContent => false
          _ => true
        }
        if can_grow {
          growable_count = growable_count + 1
        }
      }

      // Check if all spanned tracks are Fr tracks and calculate total fr value
      let mut all_fr = true
      let mut total_fr_value = 0.0
      for t = start; t < end; t = t + 1 {
        match track_types[t] {
          @style.Fr(fr) => total_fr_value = total_fr_value + fr
          _ => all_fr = false
        }
      }

      // Distribute extra space to min_sizes
      if min_extra > 0.0 {
        if all_fr && total_fr_value > 0.0 {
          // Distribute proportionally based on fr values
          for t = start; t < end; t = t + 1 {
            match track_types[t] {
              @style.Fr(fr) => {
                let proportion = fr / total_fr_value
                min_sizes[t] = min_sizes[t] + min_extra * proportion
              }
              _ => ()
            }
          }
        } else {
          // Distribute evenly
          let per_track = min_extra / span.to_double()
          for t = start; t < end; t = t + 1 {
            min_sizes[t] = min_sizes[t] + per_track
          }
        }
      }

      // Distribute extra space to max_sizes
      // CSS Grid spec: First distribute min-content evenly, then prioritize max-content tracks
      if max_extra > 0.0 {
        if all_fr && total_fr_value > 0.0 {
          // Distribute proportionally based on fr values
          for t = start; t < end; t = t + 1 {
            match track_types[t] {
              @style.Fr(fr) => {
                let proportion = fr / total_fr_value
                max_sizes[t] = max_sizes[t] + max_extra * proportion
              }
              _ => ()
            }
          }
        } else {
          // Split distribution into two phases:
          // 1. Distribute up to item's min-content contribution evenly
          // 2. Distribute remaining (max - min) to MaxContent tracks first

          // Calculate how much of max_extra corresponds to min-content
          // (min_contrib was already distributed to min_sizes)
          let min_contribution_base = min_extra + min_sum // item's min-content
          let max_contribution_base = max_extra + max_sum // item's max-content
          let beyond_min = max_contribution_base - min_contribution_base // max - min for item

          // First, ensure max_sizes reach at least min_sizes level (evenly distributed)
          for t = start; t < end; t = t + 1 {
            let growth_to_min = min_sizes[t] - max_sizes[t]
            if growth_to_min > 0.0 {
              max_sizes[t] = min_sizes[t]
            }
          }

          // Now distribute the beyond_min portion with priority
          if beyond_min > 0.0 {
            // Count different track types for prioritized distribution
            let mut max_content_count = 0
            let mut auto_count = 0
            let mut other_growable = 0
            for t = start; t < end; t = t + 1 {
              match track_types[t] {
                @style.MaxContent => max_content_count = max_content_count + 1
                @style.Auto => auto_count = auto_count + 1
                @style.MinContent => ()
                @style.Length(_) => ()
                @style.Percent(_) => ()
                _ => other_growable = other_growable + 1
              }
            }
            let mut remaining = beyond_min
            // First, distribute to MaxContent tracks
            if max_content_count > 0 && remaining > 0.0 {
              let per_track = remaining / max_content_count.to_double()
              for t = start; t < end; t = t + 1 {
                match track_types[t] {
                  @style.MaxContent => {
                    max_sizes[t] = max_sizes[t] + per_track
                    remaining = remaining - per_track
                  }
                  _ => ()
                }
              }
            }
            // Then, distribute to Auto tracks
            if auto_count > 0 && remaining > 0.0 {
              let per_track = remaining / auto_count.to_double()
              for t = start; t < end; t = t + 1 {
                match track_types[t] {
                  @style.Auto => {
                    max_sizes[t] = max_sizes[t] + per_track
                    remaining = remaining - per_track
                  }
                  _ => ()
                }
              }
            }
            // Finally, distribute to other growable tracks
            if other_growable > 0 && remaining > 0.0 {
              let per_track = remaining / other_growable.to_double()
              for t = start; t < end; t = t + 1 {
                let is_other = match track_types[t] {
                  @style.MaxContent => false
                  @style.Auto => false
                  @style.MinContent => false
                  @style.Length(_) => false
                  @style.Percent(_) => false
                  _ => true
                }
                if is_other {
                  max_sizes[t] = max_sizes[t] + per_track
                }
              }
            }
          }
        }
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
      @types.Auto =>
        // For leaf nodes, use measure function or defaults
        if child.children.length() == 0 {
          let intrinsic = get_intrinsic_from_measure(
            child, container_width, 1.0e10,
          )
          (intrinsic.min_width, intrinsic.max_width)
        } else {
          // For containers, recursively compute layout to get intrinsic size
          match child.style.display {
            @style.Grid => {
              // Compute grid layout for min-content (with 0 available width)
              let min_layout = compute_grid_layout(child, 0.0, 1.0e10)
              // Compute grid layout for max-content (with large available width)
              let max_layout = compute_grid_layout(child, 1.0e10, 1.0e10)
              (min_layout.width, max_layout.width)
            }
            @style.Flex => {
              // Calculate flex container's intrinsic size directly
              let is_row = match child.style.flex_direction {
                @style.Row | @style.RowReverse => true
                _ => false
              }
              let flex_gap = match child.style.column_gap {
                @types.Length(v) => v
                _ => 0.0
              }
              // Calculate min-content and max-content for flex container
              let (min_content, max_content) = if is_row {
                // Row: sum of children's widths (min-content for min, max-content for max)
                let mut min_sum = 0.0
                let mut max_sum = 0.0
                let mut visible_count = 0
                for flex_child in child.children {
                  if flex_child.style.display == @style.None {
                    continue
                  }
                  let (child_min, child_max) = match flex_child.style.width {
                    @types.Length(v) => (v, v)
                    @types.Percent(p) =>
                      (p * container_width, p * container_width)
                    @types.Auto => {
                      let intrinsic = get_intrinsic_from_measure(
                        flex_child, container_width, 1.0e10,
                      )
                      (intrinsic.min_width, intrinsic.max_width)
                    }
                  }
                  // Add margins
                  let ml = match flex_child.style.margin.left {
                    @types.Length(v) => v
                    _ => 0.0
                  }
                  let mr = match flex_child.style.margin.right {
                    @types.Length(v) => v
                    _ => 0.0
                  }
                  min_sum = min_sum + child_min + ml + mr
                  max_sum = max_sum + child_max + ml + mr
                  visible_count = visible_count + 1
                }
                // Add gaps between items
                if visible_count > 1 {
                  let total_gap = flex_gap * (visible_count - 1).to_double()
                  min_sum = min_sum + total_gap
                  max_sum = max_sum + total_gap
                }
                (min_sum, max_sum)
              } else {
                // Column: max of children's widths
                let mut min_max = 0.0
                let mut max_max = 0.0
                for flex_child in child.children {
                  if flex_child.style.display == @style.None {
                    continue
                  }
                  let (child_min, child_max) = match flex_child.style.width {
                    @types.Length(v) => (v, v)
                    @types.Percent(p) =>
                      (p * container_width, p * container_width)
                    @types.Auto => {
                      let intrinsic = get_intrinsic_from_measure(
                        flex_child, container_width, 1.0e10,
                      )
                      (intrinsic.min_width, intrinsic.max_width)
                    }
                  }
                  // Add margins
                  let ml = match flex_child.style.margin.left {
                    @types.Length(v) => v
                    _ => 0.0
                  }
                  let mr = match flex_child.style.margin.right {
                    @types.Length(v) => v
                    _ => 0.0
                  }
                  if child_min + ml + mr > min_max {
                    min_max = child_min + ml + mr
                  }
                  if child_max + ml + mr > max_max {
                    max_max = child_max + ml + mr
                  }
                }
                (min_max, max_max)
              }
              (min_content, max_content)
            }
            _ => {
              // For block/other display, use measure or defaults
              let intrinsic = get_intrinsic_from_measure(
                child, container_width, 1.0e10,
              )
              (intrinsic.min_width, intrinsic.max_width)
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
    let content_min = if min_content + box_size > box_size {
      min_content + box_size
    } else {
      box_size
    }
    let content_max = if max_content + box_size > box_size {
      max_content + box_size
    } else {
      box_size
    }

    // Apply min-width/max-width constraints
    // Note: padding+border (box_size) is the absolute minimum
    let style_min_width = match child.style.min_width {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width
      @types.Auto => 0.0
    }
    let style_max_width = match child.style.max_width {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width
      @types.Auto => 1.0e10
    }
    // Effective minimum is max of style min_width and box_size
    let effective_min = max(style_min_width, box_size)
    // Apply constraints: clamp to [effective_min, style_max_width], then ensure >= box_size
    let final_min = max(
      effective_min,
      if content_min < effective_min {
        effective_min
      } else {
        content_min
      },
    )
    let clamped_max = if content_max > style_max_width {
      style_max_width
    } else {
      content_max
    }
    let final_max = if clamped_max < effective_min {
      effective_min
    } else {
      clamped_max
    }
    let ml = match child.style.margin.left {
      @types.Length(v) => v
      _ => 0.0
    }
    let mr = match child.style.margin.right {
      @types.Length(v) => v
      _ => 0.0
    }
    (final_min, final_max, ml, mr)
  } else {
    // Height intrinsic sizes
    let (min_content, max_content) = match child.style.height {
      @types.Length(v) => (v, v)
      @types.Percent(_) =>
        // Percent height resolves against container height, but we don't have it here
        // Return 0 for percent heights in intrinsic sizing
        (0.0, 0.0)
      @types.Auto =>
        if child.children.length() == 0 {
          let intrinsic = get_intrinsic_from_measure(
            child, 1.0e10, container_width,
          )
          (intrinsic.min_height, intrinsic.max_height)
        } else {
          // For containers, recursively compute layout to get intrinsic size
          match child.style.display {
            @style.Grid => {
              // Compute grid layout for min-content (with 0 available height)
              let min_layout = compute_grid_layout(child, 1.0e10, 0.0)
              // Compute grid layout for max-content (with large available height)
              let max_layout = compute_grid_layout(child, 1.0e10, 1.0e10)
              (min_layout.height, max_layout.height)
            }
            @style.Flex => {
              // Compute flex layout for min-content (with 0 available height)
              let min_ctx : @node.LayoutContext = {
                available_width: 1.0e10,
                available_height: Some(0.0),
              }
              let min_layout = @flex.compute(child, min_ctx)
              // Compute flex layout for max-content (with large available height)
              let max_ctx : @node.LayoutContext = {
                available_width: 1.0e10,
                available_height: Some(1.0e10),
              }
              let max_layout = @flex.compute(child, max_ctx)
              (min_layout.height, max_layout.height)
            }
            _ => {
              let intrinsic = get_intrinsic_from_measure(
                child, 1.0e10, container_width,
              )
              (intrinsic.min_height, intrinsic.max_height)
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
    let content_min = if min_content + box_size > box_size {
      min_content + box_size
    } else {
      box_size
    }
    let content_max = if max_content + box_size > box_size {
      max_content + box_size
    } else {
      box_size
    }

    // Apply min-height/max-height constraints
    // Note: padding+border (box_size) is the absolute minimum
    let style_min_height = match child.style.min_height {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width // percent height resolves against width
      @types.Auto => 0.0
    }
    let style_max_height = match child.style.max_height {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width
      @types.Auto => 1.0e10
    }
    // Effective minimum is max of style min_height and box_size
    let effective_min = max(style_min_height, box_size)
    // Apply constraints: clamp to [effective_min, style_max_height], then ensure >= box_size
    let final_min = max(
      effective_min,
      if content_min < effective_min {
        effective_min
      } else {
        content_min
      },
    )
    let clamped_max = if content_max > style_max_height {
      style_max_height
    } else {
      content_max
    }
    let final_max = if clamped_max < effective_min {
      effective_min
    } else {
      clamped_max
    }
    let mt = match child.style.margin.top {
      @types.Length(v) => v
      _ => 0.0
    }
    let mb = match child.style.margin.bottom {
      @types.Length(v) => v
      _ => 0.0
    }
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
    @style.SingleTrackSizing::FitContentLength(v) => @style.FitContentLength(v)
    @style.SingleTrackSizing::FitContentPercent(p) =>
      @style.FitContentPercent(p)
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
      @style.SingleTrackSizing::FitContentLength(v) => total = total + v
      @style.SingleTrackSizing::FitContentPercent(p) =>
        total = total + available_size * p
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
  let track_count = total_count

  // Build complete template array: [implicit before] + [explicit] + [implicit after]
  let all_templates : Array[@style.TrackSizingFunction] = []

  // Implicit tracks before explicit grid
  for i = 0; i < offset; i = i + 1 {
    let k = offset - i
    all_templates.push(get_auto_template_reverse(auto_templates, k))
  }

  // Explicit tracks
  for i = 0; i < explicit_count; i = i + 1 {
    all_templates.push(explicit_templates[i])
  }

  // Implicit tracks after explicit grid
  let implicit_after = track_count - offset - explicit_count
  for i = 0; i < implicit_after; i = i + 1 {
    all_templates.push(get_auto_template(auto_templates, i))
  }

  // Range for explicit tracks (used to check if track is implicit)
  let explicit_start = offset
  let explicit_end = offset + explicit_count
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
  let mut fr_track_count_phase1 = 0
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
        fr_track_count_phase1 = fr_track_count_phase1 + 1
      }
      @style.Auto => {
        // Auto uses max-content for base size but can shrink to min-content
        // Implicit tracks can shrink to 0 (implicit = outside explicit range)
        let is_implicit = i < explicit_start || i >= explicit_end
        let min_for_auto = if is_implicit { 0.0 } else { min_content }
        base_sizes.push(max_content)
        min_sizes.push(min_for_auto)
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
          min_track,
          available_size,
          min_content,
          max_content,
          size_is_definite~,
        )
        let max_size = resolve_max_track_size(
          max_track,
          available_size,
          min_content,
          max_content,
          size_is_definite~,
        )
        // Base size depends on whether max is flexible or finite
        let base = if max_size < 1.0e9 {
          // Finite max: use it as base, clamped to min
          if max_size > min_size {
            max_size
          } else {
            min_size
          }
          // Infinite max (fr/auto): use max-content as base, clamped to min
        } else if max_content > min_size {
          max_content
        } else {
          min_size
        }
        base_sizes.push(base)
        min_sizes.push(min_size)
        max_sizes.push(max_size)
        fixed_size = fixed_size + base
      }
      @style.FitContentLength(limit) => {
        // fit-content(limit) = min(max-content, max(min-content, limit))
        // The track size is clamped between min-content and min(max-content, limit)
        let max_limit = if max_content < limit { max_content } else { limit }
        let base = if max_limit > min_content { max_limit } else { min_content }
        base_sizes.push(base)
        min_sizes.push(min_content)
        max_sizes.push(max_limit)
        fixed_size = fixed_size + base
      }
      @style.FitContentPercent(p) => {
        // fit-content(percent) - percent of container size as limit
        let limit = if size_is_definite { available_size * p } else { 1.0e10 }
        let max_limit = if max_content < limit { max_content } else { limit }
        let base = if max_limit > min_content { max_limit } else { min_content }
        base_sizes.push(base)
        min_sizes.push(min_content)
        max_sizes.push(max_limit)
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

  // If we have fr units, distribute to them
  if fr_track_count_phase1 > 0 {
    if size_is_definite {
      // Container size is definite: distribute remaining space to Fr tracks
      if total_fr > 0.0 {
        let fr_unit = remaining_space / total_fr
        for i = 0; i < track_count; i = i + 1 {
          let template = all_templates[i]
          match template {
            @style.Fr(fr) => base_sizes[i] = fr * fr_unit
            _ => ()
          }
        }
      } else {
        // All fr values are 0 - distribute evenly
        let per_track = remaining_space / fr_track_count_phase1.to_double()
        for i = 0; i < track_count; i = i + 1 {
          match all_templates[i] {
            @style.Fr(_) => base_sizes[i] = per_track
            _ => ()
          }
        }
      }
    } else {
      // Container size is indefinite: Find hypothetical fr unit to maintain proportions
      // Per CSS Grid spec: fr unit = max(max-content / fr value) across all fr tracks
      let mut hypothetical_fr_unit = 0.0
      let mut fr_track_count = 0
      for i = 0; i < track_count; i = i + 1 {
        let template = all_templates[i]
        match template {
          @style.Fr(fr) => {
            fr_track_count = fr_track_count + 1
            let max_content = if i < max_content_sizes.length() {
              max_content_sizes[i]
            } else {
              0.0
            }
            // Calculate what fr unit would be needed for this track's content
            if fr > 0.0 {
              let needed_fr_unit = max_content / fr
              if needed_fr_unit > hypothetical_fr_unit {
                hypothetical_fr_unit = needed_fr_unit
              }
            }
          }
          _ => ()
        }
      }
      // Apply the hypothetical fr unit to all fr tracks
      // If total_fr is 0, use max-content sizes directly (no redistribution)
      if total_fr == 0.0 && fr_track_count > 0 {
        // All fr values are 0, just use the intrinsic max-content sizes
        for i = 0; i < track_count; i = i + 1 {
          match all_templates[i] {
            @style.Fr(_) => {
              let max_content = if i < max_content_sizes.length() {
                max_content_sizes[i]
              } else {
                0.0
              }
              base_sizes[i] = max_content
            }
            _ => ()
          }
        }
      } else {
        for i = 0; i < track_count; i = i + 1 {
          let template = all_templates[i]
          match template {
            @style.Fr(fr) => base_sizes[i] = fr * hypothetical_fr_unit
            _ => ()
          }
        }
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
    // Single pass: count and shrink in one loop
    if remaining_overflow > 0.0 {
      // First count shrinkable tracks and total shrinkable space
      let mut shrinkable_count = 0
      let mut total_shrinkable = 0.0
      for i = 0; i < track_count; i = i + 1 {
        match all_templates[i] {
          @style.MinMax(_, _) => {
            let shrinkable = base_sizes[i] - min_sizes[i]
            if shrinkable > 0.0 {
              shrinkable_count = shrinkable_count + 1
              total_shrinkable = total_shrinkable + shrinkable
            }
          }
          _ => ()
        }
      }
      // Apply shrinking proportionally if there's shrinkable space
      if shrinkable_count > 0 && total_shrinkable > 0.0 {
        let shrink_ratio = min_double(
          1.0,
          remaining_overflow / total_shrinkable,
        )
        for i = 0; i < track_count; i = i + 1 {
          match all_templates[i] {
            @style.MinMax(_, _) => {
              let shrinkable = base_sizes[i] - min_sizes[i]
              if shrinkable > 0.0 {
                base_sizes[i] = base_sizes[i] - shrinkable * shrink_ratio
              }
            }
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
    Some({
      row_start: min_row,
      row_end: max_row + 1,
      col_start: min_col,
      col_end: max_col + 1,
    })
  } else {
    None
  }
}

///|
/// Place grid items using 2-pass auto-placement algorithm
/// Pass 1: Identify all explicit Line placements to determine grid bounds
/// Pass 2: Auto-place remaining items starting from the minimum column/row
fn place_grid_items(
  children : Array[@node.Node],
  explicit_columns : Int,
  explicit_rows : Int,
  auto_flow : @style.GridAutoFlow,
  grid_areas : Array[Array[String]],
) -> Array[GridItemPlacement] {
  let columns = if explicit_columns > 0 { explicit_columns } else { 1 }

  // === PASS 1: Find grid bounds from explicit Line placements ===
  let mut min_col = 0
  let mut min_row = 0
  let mut max_col = columns
  let mut max_row = if explicit_rows > 0 { explicit_rows } else { 1 }
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style
    if style.display == @style.None {
      continue
    }
    // Skip absolute positioned items - they don't participate in grid placement
    if style.position == @style.Absolute {
      continue
    }

    // Check for explicit column Line placement
    match style.grid_column.start {
      @style.Line(n) => {
        let col_idx = if n > 0 {
          n - 1
        } else if n < 0 {
          columns + 1 + n
        } else {
          0
        }
        if col_idx < min_col {
          min_col = col_idx
        }
        let end_idx = col_idx + 1
        if end_idx > max_col {
          max_col = end_idx
        }
      }
      _ => ()
    }

    // Check for explicit row Line placement
    match style.grid_row.start {
      @style.Line(n) => {
        let row_idx = if n > 0 {
          n - 1
        } else if n < 0 {
          explicit_rows + 1 + n
        } else {
          0
        }
        if row_idx < min_row {
          min_row = row_idx
        }
        let end_idx = row_idx + 1
        if end_idx > max_row {
          max_row = end_idx
        }
      }
      _ => ()
    }
  }

  // === PASS 2: Place explicitly positioned items first ===
  // This ensures we know which cells are occupied before auto-placement
  let placements : Array[GridItemPlacement] = []
  let occupied : Array[(Int, Int)] = []

  // Initialize placements array
  for i = 0; i < children.length(); i = i + 1 {
    placements.push({ row_start: 0, row_end: 0, column_start: 0, column_end: 0 })
  }

  // First, place FULLY explicitly positioned items (both column and row are Line)
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style
    if style.display == @style.None {
      continue
    }
    // Skip absolute positioned items
    if style.position == @style.Absolute {
      continue
    }

    // Check if item has explicit Line positioning
    let has_explicit_column = match style.grid_column.start {
      @style.Line(_) => true
      _ => false
    }
    let has_explicit_row = match style.grid_row.start {
      @style.Line(_) => true
      _ => false
    }

    // Only process FULLY explicitly positioned items (both column AND row)
    // Semi-explicit items (one explicit, one auto) will be processed in Pass 3
    if not(has_explicit_column && has_explicit_row) {
      continue
    }

    // Check for grid-area placement
    let area_placement = match style.grid_area {
      Some(area_name) => find_grid_area_bounds(grid_areas, area_name)
      None => None
    }
    let (col_start, col_end, row_start, row_end) = match area_placement {
      Some(bounds) =>
        (bounds.col_start, bounds.col_end, bounds.row_start, bounds.row_end)
      None => {
        let (cs, ce) = resolve_line_placement(
          style.grid_column,
          0, // auto_position not used for explicit items
          columns,
        )
        let (rs, re) = resolve_line_placement(style.grid_row, 0, explicit_rows)
        (cs, ce, rs, re)
      }
    }
    placements[i] = {
      row_start,
      row_end,
      column_start: col_start,
      column_end: col_end,
    }

    // Mark cells as occupied
    for r = row_start; r < row_end; r = r + 1 {
      for c = col_start; c < col_end; c = c + 1 {
        occupied.push((r, c))
      }
    }
  }

  // === PASS 3: Auto-place remaining items ===
  // Auto-placement cursor starts at the minimum index (to fill implicit tracks first)
  let mut next_row = min_row
  let mut next_column = min_col

  // Helper to check if a cell is occupied
  fn is_cell_occupied(
    occupied : Array[(Int, Int)],
    row : Int,
    col : Int,
  ) -> Bool {
    for i = 0; i < occupied.length(); i = i + 1 {
      let (r, c) = occupied[i]
      if r == row && c == col {
        return true
      }
    }
    false
  }

  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style
    if style.display == @style.None {
      continue
    }
    // Skip absolute positioned items
    if style.position == @style.Absolute {
      continue
    }

    // Skip items already placed in Pass 2 (FULLY explicitly positioned)
    let has_explicit_column = match style.grid_column.start {
      @style.Line(_) => true
      _ => false
    }
    let has_explicit_row = match style.grid_row.start {
      @style.Line(_) => true
      _ => false
    }
    if has_explicit_column && has_explicit_row {
      continue
    }

    // Check for grid-area placement
    let area_placement = match style.grid_area {
      Some(area_name) => find_grid_area_bounds(grid_areas, area_name)
      None => None
    }
    let (col_start, col_end, row_start, row_end) = match area_placement {
      Some(bounds) =>
        (bounds.col_start, bounds.col_end, bounds.row_start, bounds.row_end)
      None =>
        // For semi-explicit items, use explicit position for one dimension,
        // cursor for the other
        if has_explicit_row {
          // Explicit row, auto column - find first unoccupied column in that row
          let (rs, re) = resolve_line_placement(
            style.grid_row,
            0,
            explicit_rows,
          )
          let row_to_check = rs
          let mut col_cursor = min_col
          while is_cell_occupied(occupied, row_to_check, col_cursor) {
            col_cursor = col_cursor + 1
            // Don't wrap for semi-explicit items, just extend
          }
          let (cs, ce) = resolve_line_placement(
            style.grid_column,
            col_cursor,
            columns,
          )
          (cs, ce, rs, re)
        } else if has_explicit_column {
          // Explicit column, auto row - find first unoccupied row in that column
          let (cs, ce) = resolve_line_placement(style.grid_column, 0, columns)
          let col_to_check = cs
          let mut row_cursor = min_row
          while is_cell_occupied(occupied, row_cursor, col_to_check) {
            row_cursor = row_cursor + 1
            // Don't wrap for semi-explicit items, just extend
          }
          let (rs, re) = resolve_line_placement(
            style.grid_row,
            row_cursor,
            explicit_rows,
          )
          (cs, ce, rs, re)
        } else {
          // Fully auto-placed: find next unoccupied cell
          match auto_flow {
            @style.Row | @style.RowDense =>
              // Row-major: advance column, then row
              while is_cell_occupied(occupied, next_row, next_column) {
                next_column = next_column + 1
                if next_column >= columns {
                  next_column = min_col
                  next_row = next_row + 1
                }
              }
            @style.Column | @style.ColumnDense => {
              // Column-major: advance row, then column
              let rows = if explicit_rows > 0 { explicit_rows } else { 1 }
              while is_cell_occupied(occupied, next_row, next_column) {
                next_row = next_row + 1
                if next_row >= rows {
                  next_row = min_row
                  next_column = next_column + 1
                }
              }
            }
          }
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
    placements[i] = {
      row_start,
      row_end,
      column_start: col_start,
      column_end: col_end,
    }

    // Mark cells as occupied
    for r = row_start; r < row_end; r = r + 1 {
      for c = col_start; c < col_end; c = c + 1 {
        occupied.push((r, c))
      }
    }

    // Advance cursor only for fully auto-placed items
    if not(has_explicit_column) && not(has_explicit_row) {
      match auto_flow {
        @style.Row | @style.RowDense => {
          next_column = col_end
          if next_column >= columns {
            next_column = min_col
            next_row = next_row + 1
          }
        }
        @style.Column | @style.ColumnDense => {
          next_row = row_end
          let rows = if explicit_rows > 0 { explicit_rows } else { 1 }
          if next_row >= rows {
            next_row = min_row
            next_column = next_column + 1
          }
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
  let intrinsic = get_intrinsic_from_measure(
    child, available_width, available_height,
  )

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
  let width_default = if is_leaf {
    intrinsic.min_width
  } else {
    available_width
  }
  // Height uses max if width is constrained (text wrapping behavior)
  let height_default = if is_leaf {
    if width_is_constrained {
      intrinsic.max_height
    } else {
      intrinsic.min_height
    }
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
  let padding_left = resolve_dimension(
    child.style.padding.left,
    available_width,
    0.0,
  )
  let padding_right = resolve_dimension(
    child.style.padding.right,
    available_width,
    0.0,
  )
  let padding_top = resolve_dimension(
    child.style.padding.top,
    available_height,
    0.0,
  )
  let padding_bottom = resolve_dimension(
    child.style.padding.bottom,
    available_height,
    0.0,
  )
  let border_left = resolve_dimension(
    child.style.border.left,
    available_width,
    0.0,
  )
  let border_right = resolve_dimension(
    child.style.border.right,
    available_width,
    0.0,
  )
  let border_top = resolve_dimension(
    child.style.border.top,
    available_height,
    0.0,
  )
  let border_bottom = resolve_dimension(
    child.style.border.bottom,
    available_height,
    0.0,
  )

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
    // When a grid item is stretched (width/height comes from cell size),
    // treat the size as extrinsically definite for track sizing
    let width_is_extrinsic_definite = match child.style.width {
      @types.Auto => true // Size came from stretching
      _ => false
    }
    let height_is_extrinsic_definite = match child.style.height {
      @types.Auto => true // Size came from stretching
      _ => false
    }
    let nested_layout = compute_grid_layout_internal(
      child, width, height, width_is_extrinsic_definite, height_is_extrinsic_definite,
    )
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

  // Check for auto margins
  let margin_left_is_auto = match child_style.margin.left {
    @types.Auto => true
    _ => false
  }
  let margin_right_is_auto = match child_style.margin.right {
    @types.Auto => true
    _ => false
  }
  let margin_top_is_auto = match child_style.margin.top {
    @types.Auto => true
    _ => false
  }
  let margin_bottom_is_auto = match child_style.margin.bottom {
    @types.Auto => true
    _ => false
  }

  // Resolve non-auto margins
  // CSS spec: All percentage margins (including top/bottom) are resolved against the width
  let fixed_margin_left = if margin_left_is_auto {
    0.0
  } else {
    resolve_dimension(child_style.margin.left, cell_width, 0.0)
  }
  let fixed_margin_right = if margin_right_is_auto {
    0.0
  } else {
    resolve_dimension(child_style.margin.right, cell_width, 0.0)
  }
  let fixed_margin_top = if margin_top_is_auto {
    0.0
  } else {
    resolve_dimension(child_style.margin.top, cell_width, 0.0)
  }
  let fixed_margin_bottom = if margin_bottom_is_auto {
    0.0
  } else {
    resolve_dimension(child_style.margin.bottom, cell_width, 0.0)
  }

  // Available space after fixed margins
  let available_width = cell_width - fixed_margin_left - fixed_margin_right
  let available_height = cell_height - fixed_margin_top - fixed_margin_bottom

  // Get effective alignment
  // In Taffy, align_self applies to both axes when justify_self is not specified
  let align : @style.Alignment = match child_style.align_self {
    @style.AlignSelf::Auto => container_style.align_items
    @style.AlignSelf::Start => @style.Alignment::Start
    @style.AlignSelf::End => @style.Alignment::End
    @style.AlignSelf::Center => @style.Alignment::Center
    @style.AlignSelf::Stretch => @style.Alignment::Stretch
  }
  // Use justify_self for horizontal alignment
  let justify : @style.Alignment = match child_style.justify_self {
    @style.AlignSelf::Auto => container_style.justify_items
    @style.AlignSelf::Start => @style.Alignment::Start
    @style.AlignSelf::End => @style.Alignment::End
    @style.AlignSelf::Center => @style.Alignment::Center
    @style.AlignSelf::Stretch => @style.Alignment::Stretch
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
      } else if justify == @style.Alignment::Stretch {
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
      } else if align == @style.Alignment::Stretch {
        available_height
      } else {
        child_layout.height
      }
    _ => child_layout.height // Keep explicit size, don't clamp
  }

  // Calculate child's padding + border as absolute minimum
  let child_padding_left = resolve_dimension(
    child_style.padding.left,
    cell_width,
    0.0,
  )
  let child_padding_right = resolve_dimension(
    child_style.padding.right,
    cell_width,
    0.0,
  )
  let child_padding_top = resolve_dimension(
    child_style.padding.top,
    cell_height,
    0.0,
  )
  let child_padding_bottom = resolve_dimension(
    child_style.padding.bottom,
    cell_height,
    0.0,
  )
  let child_border_left = resolve_dimension(
    child_style.border.left,
    cell_width,
    0.0,
  )
  let child_border_right = resolve_dimension(
    child_style.border.right,
    cell_width,
    0.0,
  )
  let child_border_top = resolve_dimension(
    child_style.border.top,
    cell_height,
    0.0,
  )
  let child_border_bottom = resolve_dimension(
    child_style.border.bottom,
    cell_height,
    0.0,
  )
  let child_min_from_box = child_padding_left +
    child_padding_right +
    child_border_left +
    child_border_right
  let child_min_height_from_box = child_padding_top +
    child_padding_bottom +
    child_border_top +
    child_border_bottom

  // Apply min/max constraints, with padding+border as absolute minimum
  let style_min_width = resolve_dimension(
    child_style.min_width,
    cell_width,
    0.0,
  )
  let resolved_min_width = max(style_min_width, child_min_from_box)
  let resolved_max_width = resolve_dimension(
    child_style.max_width,
    cell_width,
    1.0e10,
  )
  let style_min_height = resolve_dimension(
    child_style.min_height,
    cell_height,
    0.0,
  )
  let resolved_min_height = max(style_min_height, child_min_height_from_box)
  let resolved_max_height = resolve_dimension(
    child_style.max_height,
    cell_height,
    1.0e10,
  )

  // Clamp: min <= size <= max, but min always wins if min > max
  if item_width > resolved_max_width {
    item_width = resolved_max_width
  }
  if item_width < resolved_min_width {
    item_width = resolved_min_width
  }
  if item_height > resolved_max_height {
    item_height = resolved_max_height
  }
  if item_height < resolved_min_height {
    item_height = resolved_min_height
  }

  // Calculate remaining space for auto margins
  let remaining_width = available_width - item_width
  let remaining_height = available_height - item_height

  // Calculate auto margins
  let (final_margin_left, final_margin_right) = if margin_left_is_auto &&
    margin_right_is_auto {
    // Both auto: split remaining space evenly
    let auto_margin = if remaining_width > 0.0 {
      remaining_width / 2.0
    } else {
      0.0
    }
    (auto_margin, auto_margin)
  } else if margin_left_is_auto {
    // Only left auto: absorb all remaining space
    let auto_margin = if remaining_width > 0.0 { remaining_width } else { 0.0 }
    (auto_margin, fixed_margin_right)
  } else if margin_right_is_auto {
    // Only right auto: absorb all remaining space
    let auto_margin = if remaining_width > 0.0 { remaining_width } else { 0.0 }
    (fixed_margin_left, auto_margin)
  } else {
    (fixed_margin_left, fixed_margin_right)
  }
  let (final_margin_top, final_margin_bottom) = if margin_top_is_auto &&
    margin_bottom_is_auto {
    let auto_margin = if remaining_height > 0.0 {
      remaining_height / 2.0
    } else {
      0.0
    }
    (auto_margin, auto_margin)
  } else if margin_top_is_auto {
    let auto_margin = if remaining_height > 0.0 {
      remaining_height
    } else {
      0.0
    }
    (auto_margin, fixed_margin_bottom)
  } else if margin_bottom_is_auto {
    let auto_margin = if remaining_height > 0.0 {
      remaining_height
    } else {
      0.0
    }
    (fixed_margin_top, auto_margin)
  } else {
    (fixed_margin_top, fixed_margin_bottom)
  }

  // Calculate position based on alignment (auto margins override alignment)
  let x_offset = if margin_left_is_auto || margin_right_is_auto {
    0.0 // Auto margins handle positioning
  } else {
    match justify {
      @style.Alignment::Start => 0.0
      @style.Alignment::End => available_width - item_width
      @style.Alignment::Center => (available_width - item_width) / 2.0
      @style.Alignment::Stretch => 0.0
      _ => 0.0
    }
  }
  let y_offset = if margin_top_is_auto || margin_bottom_is_auto {
    0.0 // Auto margins handle positioning
  } else {
    match align {
      @style.Alignment::Start => 0.0
      @style.Alignment::End => available_height - item_height
      @style.Alignment::Center => (available_height - item_height) / 2.0
      @style.Alignment::Stretch => 0.0
      _ => 0.0
    }
  }

  // Suppress unused variable warnings
  let _ = final_margin_right
  let _ = final_margin_bottom

  // Apply inset for relative positioning
  let inset_left = resolve_dimension(child_style.inset.left, cell_width, 0.0)
  let inset_top = resolve_dimension(child_style.inset.top, cell_height, 0.0)
  (
    cell_x + final_margin_left + x_offset + inset_left,
    cell_y + final_margin_top + y_offset + inset_top,
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

///|
/// Layout an absolutely positioned child within a grid container
fn layout_absolute_child(
  child : @node.Node,
  padding_box_left : Double,
  padding_box_top : Double,
  padding_box_width : Double,
  padding_box_height : Double,
  content_box_offset_x : Double, // content_box_left - padding_box_left (= padding_left)
  content_box_offset_y : Double, // content_box_top - padding_box_top (= padding_top)
  column_tracks : Array[GridTrack],
  row_tracks : Array[GridTrack],
  col_offset : Int,
  row_offset : Int,
  explicit_column_count : Int,
  explicit_row_count : Int,
) -> @node.Layout {
  let style = child.style

  // Handle display:none - return zero-sized layout
  if style.display == @style.None {
    return {
      id: child.id,
      x: 0.0,
      y: 0.0,
      width: 0.0,
      height: 0.0,
      margin: default_rect(),
      padding: default_rect(),
      border: default_rect(),
      children: [],
    }
  }

  // Determine the containing block (grid area) for the absolute item
  // If grid-column/row are specified, use those grid lines
  // Otherwise, use the padding box of the container

  // Resolve grid area boundaries
  let (area_left, area_right) = resolve_absolute_grid_area_x(
    style.grid_column,
    column_tracks,
    col_offset,
    explicit_column_count,
    padding_box_left,
    padding_box_left + padding_box_width,
    content_box_offset_x,
  )
  let (area_top, area_bottom) = resolve_absolute_grid_area_y(
    style.grid_row,
    row_tracks,
    row_offset,
    explicit_row_count,
    padding_box_top,
    padding_box_top + padding_box_height,
    content_box_offset_y,
  )

  let area_width = area_right - area_left
  let area_height = area_bottom - area_top

  // Resolve margin values
  let margin_left = resolve_length_dimension(style.margin.left, area_width)
  let margin_right = resolve_length_dimension(style.margin.right, area_width)
  let margin_top = resolve_length_dimension(style.margin.top, area_height)
  let margin_bottom = resolve_length_dimension(style.margin.bottom, area_height)

  // Resolve inset values
  let inset_left = resolve_inset(style.inset.left, area_width)
  let inset_right = resolve_inset(style.inset.right, area_width)
  let inset_top = resolve_inset(style.inset.top, area_height)
  let inset_bottom = resolve_inset(style.inset.bottom, area_height)

  // Determine initial size
  // Priority: explicit width > insets > intrinsic
  let initial_width = match style.width {
    @types.Length(w) => Some(w)
    @types.Percent(p) => Some(area_width * p)
    @types.Auto =>
      match (inset_left, inset_right) {
        (Some(l), Some(r)) => {
          let w = area_width - l - r - margin_left - margin_right
          if w > 0.0 { Some(w) } else { Some(0.0) }
        }
        _ => None
      }
  }

  let initial_height = match style.height {
    @types.Length(h) => Some(h)
    @types.Percent(p) => Some(area_height * p)
    @types.Auto =>
      match (inset_top, inset_bottom) {
        (Some(t), Some(b)) => {
          let h = area_height - t - b - margin_top - margin_bottom
          if h > 0.0 { Some(h) } else { Some(0.0) }
        }
        _ => None
      }
  }

  // Resolve min/max constraints for aspect ratio calculation
  let min_w = match style.min_width {
    @types.Length(v) => v
    @types.Percent(p) => area_width * p
    @types.Auto => 0.0
  }
  let max_w = match style.max_width {
    @types.Length(v) => v
    @types.Percent(p) => area_width * p
    @types.Auto => @double.infinity
  }
  let min_h = match style.min_height {
    @types.Length(v) => v
    @types.Percent(p) => area_height * p
    @types.Auto => 0.0
  }
  let max_h = match style.max_height {
    @types.Length(v) => v
    @types.Percent(p) => area_height * p
    @types.Auto => @double.infinity
  }

  // Apply aspect ratio to calculate missing dimension
  let (width, height) = @types.resolve_dimensions_with_aspect_ratio(
    initial_width,
    initial_height,
    style.aspect_ratio,
    min_w,
    max_w,
    min_h,
    max_h,
  )

  // Compute intrinsic size if needed
  let (child_width, child_height, child_inner) = match (width, height) {
    (Some(w), Some(h)) => {
      let inner = compute_child_layout(child, w, h)
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_child_layout(child, w, 1.0e10)
      // Apply aspect_ratio to intrinsic size
      let h = match style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      let inner = compute_child_layout(child, 1.0e10, h)
      // Apply aspect_ratio to intrinsic size
      let w = match style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => inner.width
      }
      (w, h, inner)
    }
    (None, None) => {
      let inner = compute_child_layout(child, 1.0e10, 1.0e10)
      // Apply aspect_ratio to intrinsic size
      match style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let w = inner.width
          let h = w / ar
          (w, h, inner)
        }
        _ => (inner.width, inner.height, inner)
      }
    }
  }

  // Apply min/max constraints
  let final_width = clamp_value(child_width, min_w, max_w)
  let final_height = clamp_value(child_height, min_h, max_h)

  // Re-apply aspect ratio after min/max constraints
  let (final_width, final_height) = match style.aspect_ratio {
    Some(ar) if ar > 0.0 => {
      // Check if width or height has constraint
      let width_has_constraint = match style.max_width {
        @types.Length(_) => true
        @types.Percent(_) => true
        @types.Auto =>
          match style.min_width {
            @types.Length(_) => true
            @types.Percent(_) => true
            @types.Auto => false
          }
      }
      let height_has_constraint = match style.max_height {
        @types.Length(_) => true
        @types.Percent(_) => true
        @types.Auto =>
          match style.min_height {
            @types.Length(_) => true
            @types.Percent(_) => true
            @types.Auto => false
          }
      }
      if height_has_constraint && not(width_has_constraint) {
        (final_height * ar, final_height)
      } else {
        (final_width, final_width / ar)
      }
    }
    _ => (final_width, final_height)
  }

  // Determine position (including margin)
  let x = match inset_left {
    Some(l) => area_left + l + margin_left
    None =>
      match inset_right {
        Some(r) => area_right - r - margin_right - final_width
        None => area_left + margin_left // Default to start
      }
  }

  let y = match inset_top {
    Some(t) => area_top + t + margin_top
    None =>
      match inset_bottom {
        Some(b) => area_bottom - b - margin_bottom - final_height
        None => area_top + margin_top // Default to start
      }
  }

  {
    id: child.id,
    x,
    y,
    width: final_width,
    height: final_height,
    margin: default_rect(),
    padding: default_rect(),
    border: default_rect(),
    children: child_inner.children,
  }
}

///|
/// Clamp a value between min and max
fn clamp_value(value : Double, min_val : Double, max_val : Double) -> Double {
  if value < min_val {
    min_val
  } else if value > max_val {
    max_val
  } else {
    value
  }
}

///|
/// Resolve inset dimension (left, right, top, bottom)
fn resolve_inset(dim : @types.Dimension, available : Double) -> Double? {
  match dim {
    @types.Length(v) => Some(v)
    @types.Percent(p) => Some(available * p)
    @types.Auto => None
  }
}

///|
/// Resolve length dimension (margin, etc.) - Auto becomes 0
fn resolve_length_dimension(dim : @types.Dimension, available : Double) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) => available * p
    @types.Auto => 0.0
  }
}

///|
/// Resolve the horizontal grid area for an absolute item
fn resolve_absolute_grid_area_x(
  grid_column : @style.GridLine,
  column_tracks : Array[GridTrack],
  col_offset : Int,
  explicit_column_count : Int,
  default_left : Double,
  default_right : Double,
  content_box_offset : Double, // content_box_left - padding_box_left
) -> (Double, Double) {
  let start_line = resolve_absolute_grid_line(
    grid_column.start,
    col_offset,
    explicit_column_count,
  )
  let end_line = resolve_absolute_grid_line(
    grid_column.end,
    col_offset,
    explicit_column_count,
  )

  // Track positions are relative to content box, so add offset to convert to padding box
  let left = match start_line {
    Some(idx) =>
      if idx >= 0 && idx < column_tracks.length() {
        column_tracks[idx].position + content_box_offset
      } else {
        default_left
      }
    None => default_left
  }

  let right = match end_line {
    Some(idx) =>
      if idx >= 0 && idx < column_tracks.length() {
        column_tracks[idx].position + content_box_offset
      } else if idx == column_tracks.length() {
        // End line after last track
        let last = column_tracks[column_tracks.length() - 1]
        last.position + last.size + content_box_offset
      } else {
        default_right
      }
    None => default_right
  }

  (left, right)
}

///|
/// Resolve the vertical grid area for an absolute item
fn resolve_absolute_grid_area_y(
  grid_row : @style.GridLine,
  row_tracks : Array[GridTrack],
  row_offset : Int,
  explicit_row_count : Int,
  default_top : Double,
  default_bottom : Double,
  content_box_offset : Double, // content_box_top - padding_box_top
) -> (Double, Double) {
  let start_line = resolve_absolute_grid_line(
    grid_row.start,
    row_offset,
    explicit_row_count,
  )
  let end_line = resolve_absolute_grid_line(
    grid_row.end,
    row_offset,
    explicit_row_count,
  )

  // Track positions are relative to content box, so add offset to convert to padding box
  let top = match start_line {
    Some(idx) =>
      if idx >= 0 && idx < row_tracks.length() {
        row_tracks[idx].position + content_box_offset
      } else {
        default_top
      }
    None => default_top
  }

  let bottom = match end_line {
    Some(idx) =>
      if idx >= 0 && idx < row_tracks.length() {
        row_tracks[idx].position + content_box_offset
      } else if idx == row_tracks.length() {
        // End line after last track
        let last = row_tracks[row_tracks.length() - 1]
        last.position + last.size + content_box_offset
      } else {
        default_bottom
      }
    None => default_bottom
  }

  (top, bottom)
}

///|
/// Resolve a grid placement to a track index for absolute positioning
/// Returns None if the placement is Auto
fn resolve_absolute_grid_line(
  placement : @style.GridPlacement,
  offset : Int,
  explicit_count : Int,
) -> Int? {
  match placement {
    @style.Auto => None
    @style.Line(n) =>
      if n > 0 {
        Some(n - 1 + offset)
      } else if n < 0 {
        Some(explicit_count + 1 + n + offset)
      } else {
        Some(offset)
      }
    @style.Span(_) => None // Span without explicit end defaults to Auto
  }
}
