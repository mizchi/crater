// =============================================================================
// CSS Grid Layout Implementation
// =============================================================================

///|
/// Calculate scroll dimensions from children layouts
/// Returns (scroll_width, scroll_height) representing the scrollable content size
fn calculate_scroll_dimensions(
  container_width : Double,
  container_height : Double,
  padding : @types.Rect[Double],
  children : Array[@types.Layout],
) -> (Double, Double) {
  // Start with content box dimensions
  let mut max_right = container_width - padding.left - padding.right
  let mut max_bottom = container_height - padding.top - padding.bottom
  // Find the maximum extent of all children
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let child_right = child.x + child.width + child.margin.right
    let child_bottom = child.y + child.height + child.margin.bottom
    if child_right > max_right {
      max_right = child_right
    }
    if child_bottom > max_bottom {
      max_bottom = child_bottom
    }
  }
  (max_right, max_bottom)
}

// =============================================================================
// Intrinsic Size Cache for Grid
// =============================================================================

///|
/// Cache for intrinsic size calculations during a single layout pass
/// Key: node_uid * 4 + axis * 2 + sizing_type
/// axis: 0 = column (width), 1 = row (height)
/// sizing_type: 0 = min_content, 1 = max_content
priv struct GridIntrinsicCache {
  data : Map[Int, Double]
}

///|
fn GridIntrinsicCache::new() -> GridIntrinsicCache {
  { data: {} }
}

///|
fn GridIntrinsicCache::get(
  self : GridIntrinsicCache,
  node_uid : Int,
  is_row : Bool,
  is_max_content : Bool,
) -> Double? {
  let axis = if is_row { 1 } else { 0 }
  let sizing = if is_max_content { 1 } else { 0 }
  let key = node_uid * 4 + axis * 2 + sizing
  self.data.get(key)
}

///|
fn GridIntrinsicCache::set(
  self : GridIntrinsicCache,
  node_uid : Int,
  is_row : Bool,
  is_max_content : Bool,
  value : Double,
) -> Unit {
  let axis = if is_row { 1 } else { 0 }
  let sizing = if is_max_content { 1 } else { 0 }
  let key = node_uid * 4 + axis * 2 + sizing
  self.data.set(key, value)
}

// =============================================================================
// Display: Contents Support for Grid
// =============================================================================

///|
/// A grid item with tracking information for display: contents reconstruction
priv struct FlattenedGridChild {
  node : @node.Node
  /// Index of the immediate child of grid container (for DOM ordering)
  original_child_index : Int
  /// Parent nodes with display: contents (for tree reconstruction)
  contents_ancestors : Array[@node.Node]
}

///|
/// Flatten children for grid layout, unwrapping display: contents nodes.
fn flatten_children_for_grid(node : @node.Node) -> Array[FlattenedGridChild] {
  let result : Array[FlattenedGridChild] = []
  let children = node.children
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    if child.style.display == @types.Contents {
      // This is a contents element - flatten its children
      flatten_grid_children_recursive(child.children, i, [child], result)
    } else {
      // Regular child - add it directly
      result.push({
        node: child,
        original_child_index: i,
        contents_ancestors: [],
      })
    }
  }
  result
}

///|
/// Recursively flatten grid children, tracking contents ancestors
fn flatten_grid_children_recursive(
  children : Array[@node.Node],
  original_index : Int,
  ancestors : Array[@node.Node],
  result : Array[FlattenedGridChild],
) -> Unit {
  for child in children {
    if child.style.display == @types.Contents {
      // Nested contents - continue flattening
      let new_ancestors = ancestors.copy()
      new_ancestors.push(child)
      flatten_grid_children_recursive(
        child.children,
        original_index,
        new_ancestors,
        result,
      )
    } else {
      // Regular child - add as grid item
      result.push({
        node: child,
        original_child_index: original_index,
        contents_ancestors: ancestors.copy(),
      })
    }
  }
}

///|
/// Create a zero-size layout for a display: contents element in grid
fn create_grid_contents_layout(
  node : @node.Node,
  children_layouts : Array[@types.Layout],
) -> @types.Layout {
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: @types.Rect::zero(),
    padding: @types.Rect::zero(),
    border: @types.Rect::zero(),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: children_layouts,
    text: node.text,
  }
}

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
  min_track : @types.MinTrackSizing,
  available_size : Double,
  min_content_size : Double,
  max_content_size : Double,
  size_is_definite? : Bool = true,
) -> Double {
  match min_track {
    @types.MinTrackSizing::Length(v) => v
    @types.MinTrackSizing::Percent(p) =>
      // In indefinite containers, percent behaves as auto (0.0)
      if size_is_definite {
        available_size * p
      } else {
        0.0
      }
    @types.MinTrackSizing::Auto => 0.0 // Auto in minmax uses 0 as minimum
    @types.MinTrackSizing::MinContent => min_content_size
    @types.MinTrackSizing::MaxContent => max_content_size
  }
}

///|
/// Resolve maximum track sizing to a concrete size
fn resolve_max_track_size(
  max_track : @types.MaxTrackSizing,
  available_size : Double,
  min_content_size : Double,
  max_content_size : Double,
  size_is_definite? : Bool = true,
) -> Double {
  match max_track {
    @types.MaxTrackSizing::Length(v) => v
    @types.MaxTrackSizing::Percent(p) =>
      // In indefinite containers, percent behaves as auto (max-content)
      if size_is_definite {
        available_size * p
      } else {
        max_content_size
      }
    @types.MaxTrackSizing::Fr(_) => 1.0e10 // Fr in max position means flexible
    @types.MaxTrackSizing::Auto => 1.0e10
    @types.MaxTrackSizing::MinContent => min_content_size
    @types.MaxTrackSizing::MaxContent => max_content_size
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
/// Compute grid layout with LayoutContext interface (matches flex/block signature)
pub fn compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let available_height = ctx.available_height.unwrap_or(0.0)
  let is_block_level = node.style.display == @types.Grid
  // When called with Definite sizing_mode, the container size may be extrinsically definite.
  // Only treat it as definite for block-level grid with width/height:auto, or when stretched.
  let is_definite_mode = ctx.sizing_mode == @types.Definite
  let width_is_extrinsic_definite = is_definite_mode &&
    (ctx.stretch_width || (is_block_level && node.style.width == @types.Auto))
  let height_is_extrinsic_definite = is_definite_mode &&
    ctx.available_height is Some(_) &&
    (ctx.stretch_height || (is_block_level && node.style.height == @types.Auto))
  compute_grid_layout_internal(
    node,
    ctx.available_width,
    available_height,
    width_is_extrinsic_definite,
    height_is_extrinsic_definite,
    ctx.sizing_mode,
    is_block_level,
    ctx.viewport_width,
    ctx.viewport_height,
    dispatch,
  )
}

///|
/// @deprecated Use @dispatch.compute_layout instead
/// Compute layout for any node type, delegating to the appropriate module
/// based on the node's display type (Grid, Flex, or Block)
pub fn compute_layout(
  node : @node.Node,
  available_width : Double,
  available_height : Double,
) -> @types.Layout {
  // Create dispatch function for cross-layout type dispatch
  let dispatch = @node.DispatchFn(fn(n, c, d) {
    match n.style.display {
      @types.Flex | @types.InlineFlex => @flex.compute(n, c, d)
      @types.Grid | @types.InlineGrid => compute(n, c, d)
      _ => @block.compute(n, c, d)
    }
  })
  let ctx : @types.LayoutContext = {
    available_width,
    available_height: Some(available_height),
    sizing_mode: @types.MaxContent,
    viewport_width: available_width,
    viewport_height: available_height,
    stretch_width: false,
    stretch_height: false,
  }
  match node.style.display {
    @types.Flex | @types.InlineFlex => @flex.compute_root(node, ctx, dispatch)
    @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
      @block.compute(node, ctx, dispatch)
    @types.Grid | @types.InlineGrid => compute(node, ctx, dispatch)
    @types.Display::None | @types.Contents =>
      @absolute.create_zero_layout(node.id)
    // Table display types - fall through to block for now (handled by dispatch)
    @types.Table
    | @types.InlineTable
    | @types.TableRow
    | @types.TableCell
    | @types.TableCaption
    | @types.TableRowGroup
    | @types.TableHeaderGroup
    | @types.TableFooterGroup
    | @types.TableColumn
    | @types.TableColumnGroup => @block.compute(node, ctx, dispatch)
  }
}

///|
/// Compute grid layout for a node
pub fn compute_grid_layout(
  node : @node.Node,
  available_width : Double,
  available_height : Double,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  // Call internal function with size_is_definite = false by default
  // (public API assumes caller doesn't know about definiteness)
  // For intrinsic sizing contexts, use MaxContent mode with content-based sizing
  compute_grid_layout_internal(
    node,
    available_width,
    available_height,
    false,
    false,
    @types.MaxContent,
    false,
    available_width, // Use available_width as viewport fallback
    available_height, // Use available_height as viewport fallback
    dispatch,
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
  sizing_mode : @types.SizingMode,
  is_block_level : Bool,
  viewport_width : Double,
  viewport_height : Double,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = node.style
  let is_vertical_writing = style.writing_mode.is_vertical()
  let is_block_rtl = style.writing_mode.is_block_rtl()
  let original_children = node.children

  // Flatten children for display: contents support
  let flattened = flatten_children_for_grid(node)
  // Extract just the nodes for grid item processing
  let children : Array[@node.Node] = []
  for flat in flattened {
    children.push(flat.node)
  }

  // Map to collect layouts for display: contents children reconstruction
  let contents_layouts : Map[Int, Array[@types.Layout]] = {}

  // Create cache for intrinsic size calculations
  let intrinsic_cache = GridIntrinsicCache::new()

  // Resolve container size first (needed for auto-fill expansion)
  // For intrinsic sizing, percentages should resolve against the specified size
  // (or 0 when width/height is auto/intrinsic).
  let is_intrinsic_sizing = sizing_mode == @types.MaxContent
  let container_width_for_expansion = if width_is_extrinsically_definite {
    available_width
  } else if is_intrinsic_sizing {
    resolve_intrinsic_dimension(
      style.width,
      available_width,
      width_is_extrinsically_definite,
    )
  } else {
    resolve_dimension(style.width, available_width, available_width)
  }
  let container_height_for_expansion = if height_is_extrinsically_definite {
    available_height
  } else if is_intrinsic_sizing {
    resolve_intrinsic_dimension(
      style.height,
      available_height,
      height_is_extrinsically_definite,
    )
  } else {
    resolve_dimension(style.height, available_height, available_height)
  }

  // Expand repeat() in templates early (needed for correct column/row counts)
  let (expanded_columns, auto_fit_columns) = expand_track_templates(
    style.grid_template_columns,
    container_width_for_expansion,
  )
  let (expanded_rows, auto_fit_rows) = expand_track_templates(
    style.grid_template_rows,
    container_height_for_expansion,
  )
  let mut has_fit_content_percent_columns = false
  for t in expanded_columns {
    match t {
      @types.FitContentPercent(_) => has_fit_content_percent_columns = true
      _ => ()
    }
  }
  let mut has_fit_content_percent_rows = false
  for t in expanded_rows {
    match t {
      @types.FitContentPercent(_) => has_fit_content_percent_rows = true
      _ => ()
    }
  }
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
  let collapse_columns = compute_auto_fit_collapse(
    children, adjusted_placements, auto_fit_columns, col_offset, total_column_count,
    true,
  )
  let collapse_rows = compute_auto_fit_collapse(
    children, adjusted_placements, auto_fit_rows, row_offset, total_row_count, false,
  )

  // Resolve container size (preliminary for percentage calculations)
  let preliminary_width = if width_is_extrinsically_definite {
    available_width
  } else if is_intrinsic_sizing {
    resolve_intrinsic_dimension(
      style.width,
      available_width,
      width_is_extrinsically_definite,
    )
  } else {
    resolve_dimension(style.width, available_width, available_width)
  }
  let preliminary_height = if height_is_extrinsically_definite {
    available_height
  } else if is_intrinsic_sizing {
    resolve_intrinsic_dimension(
      style.height,
      available_height,
      height_is_extrinsically_definite,
    )
  } else {
    resolve_dimension(style.height, available_height, available_height)
  }

  // Get padding and border
  let percent_base_width = if is_intrinsic_sizing {
    if viewport_width > 0.0 && viewport_width > preliminary_width {
      viewport_width
    } else {
      preliminary_width
    }
  } else if viewport_width > 0.0 && viewport_width > available_width {
    viewport_width
  } else {
    preliminary_width
  }
  let padding_left = resolve_dimension(
    style.padding.left,
    percent_base_width,
    0.0,
  )
  let padding_right = resolve_dimension(
    style.padding.right,
    percent_base_width,
    0.0,
  )
  // CSS spec: percent padding resolves against width, not height
  let padding_top = resolve_dimension(
    style.padding.top,
    percent_base_width,
    0.0,
  )
  let padding_bottom = resolve_dimension(
    style.padding.bottom,
    percent_base_width,
    0.0,
  )
  let border_left = resolve_dimension(
    style.border.left,
    percent_base_width,
    0.0,
  )
  let border_right = resolve_dimension(
    style.border.right,
    percent_base_width,
    0.0,
  )
  let border_top = resolve_dimension(style.border.top, preliminary_height, 0.0)
  let border_bottom = resolve_dimension(
    style.border.bottom,
    preliminary_height,
    0.0,
  )
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
  let content_height_for_intrinsic = if preliminary_content_height > 0.0 {
    preliminary_content_height
  } else {
    0.0
  }
  let content_width_for_intrinsic = if is_intrinsic_sizing {
    if preliminary_content_width > 0.0 {
      preliminary_content_width
    } else {
      0.0
    }
  } else if preliminary_content_width > 0.0 {
    preliminary_content_width
  } else {
    0.0
  }
  let margin_percent_base = if is_intrinsic_sizing {
    match style.width {
      @types.Auto
      | @types.MinContent
      | @types.MaxContent
      | @types.FitContent(_) => 0.0
      _ => content_width_for_intrinsic
    }
  } else {
    content_width_for_intrinsic
  }
  let width_is_auto_for_gap = match style.width {
    @types.Auto
    | @types.MinContent
    | @types.MaxContent
    | @types.FitContent(_) => true
    _ => false
  }
  let width_is_definite_for_gap = not(width_is_auto_for_gap) ||
    width_is_extrinsically_definite
  let width_is_min_content_for_gap = match style.width {
    @types.MinContent => true
    _ => false
  }
  let has_percent_gap = (match style.column_gap {
      @types.Percent(_) => true
      _ => false
    }) ||
    (match style.row_gap {
      @types.Percent(_) => true
      _ => false
    })
  let needs_intrinsic_gap_base = is_intrinsic_sizing &&
    width_is_auto_for_gap &&
    has_percent_gap
  let mut gapless_total_track_width = 0.0
  if needs_intrinsic_gap_base {
    let (gapless_min, gapless_max) = calculate_track_intrinsic_sizes(
      children,
      adjusted_placements,
      total_column_count,
      true, // is_column
      content_width_for_intrinsic,
      content_height_for_intrinsic,
      0.0, // gapless
      margin_percent_base,
      expanded_columns,
      style.grid_auto_columns,
      col_offset,
      intrinsic_cache,
      dispatch,
    )
    let gapless_tracks = resolve_tracks_with_implicit(
      expanded_columns,
      style.grid_auto_columns,
      preliminary_content_width,
      0.0,
      gapless_min,
      gapless_max,
      col_offset,
      total_column_count,
      width_is_definite_for_gap,
      width_is_min_content_for_gap,
    )
    gapless_total_track_width = calculate_total_track_size(gapless_tracks, 0.0)
  }
  let gap_percent_base_width = if needs_intrinsic_gap_base &&
    gapless_total_track_width > 0.0 {
    gapless_total_track_width
  } else {
    percent_base_width
  }
  let column_gap = resolve_dimension(
    style.column_gap,
    gap_percent_base_width,
    0.0,
  )
  let row_gap = resolve_dimension(style.row_gap, gap_percent_base_width, 0.0)

  // Calculate intrinsic content sizes for tracks (min-content and max-content)
  let (column_min_content, column_max_content) = calculate_track_intrinsic_sizes(
    children,
    adjusted_placements,
    total_column_count,
    true, // is_column
    content_width_for_intrinsic,
    content_height_for_intrinsic,
    column_gap,
    margin_percent_base,
    expanded_columns,
    style.grid_auto_columns,
    col_offset,
    intrinsic_cache,
    dispatch,
  )
  let (row_min_content, row_max_content) = calculate_track_intrinsic_sizes(
    children,
    adjusted_placements,
    total_row_count,
    false, // is_column
    content_width_for_intrinsic, // CSS: percent padding resolves against width
    content_height_for_intrinsic,
    row_gap,
    margin_percent_base,
    expanded_rows,
    style.grid_auto_rows,
    row_offset,
    intrinsic_cache,
    dispatch,
  )
  let inline_is_min_content = if expanded_columns.length() > 0 {
    let mut all_min = true
    for t in expanded_columns {
      match t {
        @types.TrackSizingFunction::MinContent => ()
        _ => all_min = false
      }
    }
    all_min
  } else {
    false
  }
  let row_max_content_for_tracks = if inline_is_min_content {
    let adjusted : Array[Double] = []
    for v in row_min_content {
      adjusted.push(v)
    }
    adjusted
  } else {
    row_max_content
  }

  // Determine if container has auto/intrinsic sizing (needs content-based width/height)
  let width_is_auto = match style.width {
    @types.Auto
    | @types.MinContent
    | @types.MaxContent
    | @types.FitContent(_) => true
    @types.Percent(_) =>
      is_intrinsic_sizing && not(width_is_extrinsically_definite)
    _ => false
  }
  // Track if width is specifically Auto (vs intrinsic keywords like min-content)
  // Only Auto width should expand to fill for block-level containers
  let width_is_auto_only = match style.width {
    @types.Auto => true
    _ => false
  }
  // Track if width is min-content (fr tracks should be 0)
  let width_is_min_content = match style.width {
    @types.MinContent => true
    _ => false
  }
  let height_is_auto = match style.height {
    @types.Auto
    | @types.MinContent
    | @types.MaxContent
    | @types.FitContent(_) => true
    @types.Percent(_) =>
      is_intrinsic_sizing && not(height_is_extrinsically_definite)
    _ => false
  }
  // Track if height is min-content (fr tracks should be 0)
  let height_is_min_content = match style.height {
    @types.MinContent => true
    _ => false
  }

  // Size is definite for track sizing if:
  // 1. Style has explicit size (not Auto), OR
  // 2. Size is extrinsically definite (e.g., stretched in parent grid)
  let width_is_definite = not(width_is_auto) || width_is_extrinsically_definite
  let height_is_definite = not(height_is_auto) ||
    height_is_extrinsically_definite

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
    width_is_min_content, // Use min-content sizing (fr tracks = 0)
  )
  let row_tracks = resolve_tracks_with_implicit(
    expanded_rows,
    style.grid_auto_rows,
    preliminary_content_height,
    row_gap,
    row_min_content,
    row_max_content_for_tracks,
    row_offset,
    total_row_count,
    height_is_definite, // Distribute remaining space if height is definite
    height_is_min_content, // Use min-content sizing (fr tracks = 0)
  )
  if is_vertical_writing {
    adjust_block_tracks_for_measured_items(
      children,
      adjusted_placements,
      row_tracks,
      column_tracks,
      column_gap,
      true,
      expanded_columns,
      style.grid_auto_columns,
      col_offset,
    )
  } else {
    adjust_block_tracks_for_measured_items(
      children,
      adjusted_placements,
      column_tracks,
      row_tracks,
      row_gap,
      false,
      expanded_rows,
      style.grid_auto_rows,
      row_offset,
    )
  }
  collapse_auto_fit_tracks(column_tracks, collapse_columns, column_gap)
  collapse_auto_fit_tracks(row_tracks, collapse_rows, row_gap)

  // Check if we need baseline alignment
  let needs_baseline = style.align_items == @types.Baseline

  // For baseline alignment, we need to adjust row track sizes
  // based on max_ascent + max_descent for each row
  if needs_baseline {
    // Calculate baseline info for each item (preliminary pass)
    let row_baseline_heights : @hashmap.HashMap[Int, (Double, Double)] = @hashmap.new()
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let placement = adjusted_placements[i]
      if child.style.display == @types.Display::None {
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
      let child_inner = compute_child_layout(
        child, item_width, item_height, dispatch,
      )
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
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => min_width
  }
  let resolved_max_width = match style.max_width {
    @types.Length(v) => v
    @types.Percent(p) => p * available_width
    @types.Auto => 1.0e10
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      @double.infinity
  }
  let resolved_min_height = match style.min_height {
    @types.Length(v) => max(v, min_height)
    @types.Percent(p) => max(p * available_height, min_height)
    @types.Auto => min_height
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => {
      // For intrinsic min-height, use track heights + padding + border
      let total_track_height = calculate_total_track_size(row_tracks, row_gap)
      total_track_height +
      padding_top +
      padding_bottom +
      border_top +
      border_bottom
    }
  }
  let resolved_max_height = match style.max_height {
    @types.Length(v) => v
    @types.Percent(p) => p * available_height
    @types.Auto => 1.0e10
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => {
      // For intrinsic max-height, use track heights + padding + border
      let total_track_height = calculate_total_track_size(row_tracks, row_gap)
      total_track_height +
      padding_top +
      padding_bottom +
      border_top +
      border_bottom
    }
  }
  let container_width = if width_is_auto {
    // Block-level Grid in Definite sizing mode expands to fill available width
    // BUT only for `width: auto`, NOT for intrinsic keywords like min-content
    // Inline-level Grid and intrinsic sizing use content-based sizing
    if width_is_auto_only && is_block_level && sizing_mode == @types.Definite {
      // Block-level Grid with width: auto: expand to fill available width
      let clamped = if available_width > resolved_max_width {
        resolved_max_width
      } else {
        available_width
      }
      if clamped < resolved_min_width {
        resolved_min_width
      } else {
        clamped
      }
    } else {
      // Inline-level Grid or intrinsic sizing: content-based
      let total_track_width = calculate_total_track_size(
        column_tracks, column_gap,
      )
      let total_track_width_for_auto = if needs_intrinsic_gap_base &&
        gapless_total_track_width > 0.0 {
        gapless_total_track_width
      } else {
        total_track_width
      }

      // For percent tracks in indefinite containers, use content-based sizing
      let mut content_max_width = 0.0
      if sizing_mode == @types.MaxContent && has_fit_content_percent_columns {
        for i = 0; i < children.length(); i = i + 1 {
          let child = children[i]
          if child.style.display == @types.Display::None {
            continue
          }
          let (_min_content, max_content, margin_start, margin_end) = calculate_item_intrinsic_sizes(
            child, true, container_width_for_expansion, content_height_for_intrinsic,
            margin_percent_base, intrinsic_cache, dispatch,
          )
          let contribution = max_content + margin_start + margin_end
          if contribution > content_max_width {
            content_max_width = contribution
          }
        }
      } else {
        for i = 0; i < children.length(); i = i + 1 {
          let child = children[i]
          if child.style.display == @types.Display::None {
            continue
          }
          match child.style.width {
            @types.Length(w) =>
              if w > content_max_width {
                content_max_width = w
              }
            _ => ()
          }
        }
      }

      // Use max of track-based and content-based size
      let effective_width = max(total_track_width_for_auto, content_max_width)
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
    }
  } else if preliminary_width > min_width {
    preliminary_width
  } else {
    min_width
  }
  let container_height = if height_is_auto {
    // Check if aspect-ratio should determine height
    // CSS spec: aspect-ratio applies when one dimension is definite and other is auto
    let aspect_height : Double? = match style.aspect_ratio {
      Some(ratio) if ratio > 0.0 && not(width_is_auto) => {
        // Width is definite, calculate height from content-box width
        let content_width = container_width -
          padding_left -
          padding_right -
          border_left -
          border_right
        let content_height = content_width / ratio
        Some(
          content_height +
          padding_top +
          padding_bottom +
          border_top +
          border_bottom,
        )
      }
      _ => None
    }
    match aspect_height {
      Some(h) => {
        // Apply min/max constraints
        let clamped = if h > resolved_max_height {
          resolved_max_height
        } else {
          h
        }
        if clamped < resolved_min_height {
          resolved_min_height
        } else {
          clamped
        }
      }
      None => {
        // No aspect-ratio, use content-based sizing
        let total_track_height = calculate_total_track_size(row_tracks, row_gap)

        // For percent tracks in indefinite containers, use content-based sizing
        let mut content_max_height = 0.0
        if sizing_mode == @types.MaxContent && has_fit_content_percent_rows {
          for i = 0; i < children.length(); i = i + 1 {
            let child = children[i]
            if child.style.display == @types.Display::None {
              continue
            }
            let (_min_content, max_content, margin_start, margin_end) = calculate_item_intrinsic_sizes(
              child, false, container_width_for_expansion, content_height_for_intrinsic,
              margin_percent_base, intrinsic_cache, dispatch,
            )
            let contribution = max_content + margin_start + margin_end
            if contribution > content_max_height {
              content_max_height = contribution
            }
          }
        } else {
          for i = 0; i < children.length(); i = i + 1 {
            let child = children[i]
            if child.style.display == @types.Display::None {
              continue
            }
            match child.style.height {
              @types.Length(h) =>
                if h > content_max_height {
                  content_max_height = h
                }
              _ => ()
            }
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
      }
    }
    // Enforce minimum size from padding + border
  } else {
    // Height is explicitly set - apply min/max constraints
    let clamped = if preliminary_height > resolved_max_height {
      resolved_max_height
    } else {
      preliminary_height
    }
    if clamped < resolved_min_height {
      resolved_min_height
    } else if clamped < min_height {
      min_height
    } else {
      clamped
    }
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
        @types.TrackSizingFunction::Auto
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
        @types.TrackSizingFunction::Percent(p) => content_width * p
        @types.MinMax(min_track, @types.MaxTrackSizing::Percent(p)) => {
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
        @types.TrackSizingFunction::Auto
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
        @types.TrackSizingFunction::Percent(p) => content_height * p
        @types.MinMax(min_track, @types.MaxTrackSizing::Percent(p)) => {
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
  let preliminary_layouts : Array[@types.Layout] = []
  let baseline_infos : Array[BaselineInfo] = []
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let placement = adjusted_placements[i]

    // Skip hidden children
    if child.style.display == @types.Display::None {
      preliminary_layouts.push({
        id: child.id,
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        margin: default_rect(),
        padding: default_rect(),
        border: default_rect(),
        overflow_x: @types.Visible,
        overflow_y: @types.Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: [],
        text: child.text,
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
    if child.style.position == @types.Absolute {
      let abs_layout = layout_absolute_child(
        child, padding_box_left, padding_box_top, padding_box_width, padding_box_height,
        padding_left, // content_box_offset_x = content_box_left - padding_box_left
         padding_top, // content_box_offset_y = content_box_top - padding_box_top
         column_tracks, row_tracks, col_offset, row_offset, explicit_column_count,
        explicit_row_count, dispatch,
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

    // Handle fixed positioned children (relative to viewport)
    if child.style.position == @types.Fixed {
      let fixed_layout = layout_fixed_child(
        child, viewport_width, viewport_height, dispatch,
      )
      preliminary_layouts.push(fixed_layout)
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
    // In vertical writing mode, columns become rows and vice versa:
    // - column_tracks (from grid-template-columns) define the block axis (y in vertical mode)
    // - row_tracks (from grid-template-rows) define the inline axis (x in vertical mode)
    let (item_x, item_width, item_y, item_height) = if is_vertical_writing {
      let (y, h) = get_span_bounds(column_tracks, col_start, col_end)
      let (x, w) = get_span_bounds(row_tracks, row_start, row_end)
      (x, w, y, h)
    } else {
      let (x, w) = get_span_bounds(column_tracks, col_start, col_end)
      let (y, h) = get_span_bounds(row_tracks, row_start, row_end)
      (x, w, y, h)
    }

    // Determine if item should stretch based on alignment
    // This is needed for table children to know whether to use shrink-to-fit or fill available
    let child_style = child.style
    let justify : @types.Alignment = @core.resolve_align_self(
      child_style.justify_self,
      style.justify_items,
    )
    let align : @types.Alignment = @core.resolve_align_self(
      child_style.align_self,
      style.align_items,
    )
    let width_is_auto = match child_style.width {
      @types.Auto => true
      _ => false
    }
    let height_is_auto = match child_style.height {
      @types.Auto => true
      _ => false
    }
    let margin_left_auto = match child_style.margin.left {
      @types.Auto => true
      _ => false
    }
    let margin_right_auto = match child_style.margin.right {
      @types.Auto => true
      _ => false
    }
    let margin_top_auto = match child_style.margin.top {
      @types.Auto => true
      _ => false
    }
    let margin_bottom_auto = match child_style.margin.bottom {
      @types.Auto => true
      _ => false
    }
    let has_vertical_auto_margin = margin_top_auto || margin_bottom_auto
    let should_stretch_width = width_is_auto && justify == @types.Stretch
    let should_stretch_height = height_is_auto &&
      align == @types.Stretch &&
      not(has_vertical_auto_margin)

    // Resolve fixed margins to avoid passing margin space into child layout sizing
    let fixed_margin_left = if margin_left_auto {
      0.0
    } else {
      resolve_dimension(child_style.margin.left, content_box_width, 0.0)
    }
    let fixed_margin_right = if margin_right_auto {
      0.0
    } else {
      resolve_dimension(child_style.margin.right, content_box_width, 0.0)
    }
    let fixed_margin_top = if margin_top_auto {
      0.0
    } else {
      resolve_dimension(child_style.margin.top, content_box_width, 0.0)
    }
    let fixed_margin_bottom = if margin_bottom_auto {
      0.0
    } else {
      resolve_dimension(child_style.margin.bottom, content_box_width, 0.0)
    }
    let child_available_width = if width_is_auto {
      max(0.0, item_width - fixed_margin_left - fixed_margin_right)
    } else {
      item_width
    }
    let child_available_height = if height_is_auto {
      max(0.0, item_height - fixed_margin_top - fixed_margin_bottom)
    } else {
      item_height
    }

    // Compute child's inner layout
    let child_inner = compute_child_layout(
      child,
      child_available_width,
      child_available_height,
      dispatch,
      stretch_width=should_stretch_width,
      stretch_height=should_stretch_height,
      percent_base_width=content_box_width,
    )

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
    // For vertical-rl: flip x position (items flow from right to left)
    let positioned_x = if is_block_rtl {
      container_width - final_x - final_width
    } else {
      final_x
    }
    preliminary_layouts.push({
      id: child.id,
      x: positioned_x,
      y: final_y,
      width: final_width,
      height: final_height,
      margin: default_rect(),
      padding: default_rect(),
      border: default_rect(),
      overflow_x: child.style.overflow_x,
      overflow_y: child.style.overflow_y,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: child_inner.children,
      text: child.text,
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
  let child_layouts : Array[@types.Layout] = []
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

  // Reconstruct tree with display: contents elements
  // Group layouts by original_child_index
  for i = 0; i < flattened.length(); i = i + 1 {
    let flat = flattened[i]
    if flat.contents_ancestors.length() > 0 {
      // This is a child of a contents element
      let key = flat.original_child_index
      match contents_layouts.get(key) {
        Some(arr) => arr.push(child_layouts[i])
        None => contents_layouts.set(key, [child_layouts[i]])
      }
    }
  }

  // Build final children array with contents wrappers
  let final_children : Array[@types.Layout] = []
  let mut flattened_idx = 0
  for i = 0; i < original_children.length(); i = i + 1 {
    let orig_child = original_children[i]
    if orig_child.style.display == @types.Contents {
      // Create contents wrapper with its children's layouts
      match contents_layouts.get(i) {
        Some(layouts) =>
          final_children.push(create_grid_contents_layout(orig_child, layouts))
        None =>
          // Contents element with no children
          final_children.push(create_grid_contents_layout(orig_child, []))
      }
      // Regular child - use its layout from child_layouts
    } else if flattened_idx < child_layouts.length() {
      final_children.push(child_layouts[flattened_idx])
      flattened_idx = flattened_idx + 1
    }
  }
  // Calculate scroll dimensions
  let padding : @types.Rect[Double] = {
    left: padding_left,
    right: padding_right,
    top: padding_top,
    bottom: padding_bottom,
  }
  let (scroll_width, scroll_height) = calculate_scroll_dimensions(
    container_width, container_height, padding, final_children,
  )
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: container_width,
    height: container_height,
    margin: default_rect(),
    padding,
    border: {
      left: border_left,
      right: border_right,
      top: border_top,
      bottom: border_bottom,
    },
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    scroll_width,
    scroll_height,
    children: final_children,
    text: node.text,
  }
}

///|
/// Resolve a dimension value to a concrete size (delegates to Dimension::resolve_or)
fn resolve_dimension(
  dim : @types.Dimension,
  available : Double,
  default : Double,
) -> Double {
  dim.resolve_or(available, default)
}

///|
/// Resolve dimension for intrinsic sizing contexts.
/// Percentages resolve only when the containing size is extrinsically definite.
fn resolve_intrinsic_dimension(
  dim : @types.Dimension,
  available : Double,
  is_extrinsically_definite : Bool,
) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) =>
      if is_extrinsically_definite {
        available * p
      } else {
        0.0
      }
    @types.Auto => 0.0
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
  }
}

///|
/// Apply content alignment (justify-content/align-content) to tracks
fn apply_content_alignment(
  tracks : Array[GridTrack],
  container_size : Double,
  alignment : @types.Alignment,
) -> Unit {
  if tracks.length() == 0 {
    return
  }
  let core_tracks : Array[@core.ContentTrack] = []
  for track in tracks {
    core_tracks.push({
      position: track.position,
      size: track.size,
      stretchable: track.stretchable,
    })
  }
  let aligned = @core.align_content_tracks(
    core_tracks, container_size, alignment,
  )
  for i = 0; i < tracks.length(); i = i + 1 {
    let track = aligned[i]
    tracks[i] = {
      position: track.position,
      size: track.size,
      stretchable: track.stretchable,
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
  container_width : Double, // For resolving percent padding/widths
  container_height : Double, // For resolving percent heights (aspect ratio)
  gap : Double, // Track gap for span contribution adjustment
  margin_percent_base : Double, // For resolving percent margins in intrinsic sizing
  templates : Array[@types.TrackSizingFunction], // Track templates for type-aware distribution
  auto_templates : Array[@types.TrackSizingFunction], // Auto track templates
  explicit_offset : Int, // Offset for explicit tracks
  cache : GridIntrinsicCache, // Cache for intrinsic size calculations
  dispatch : @node.DispatchFn,
) -> (Array[Double], Array[Double]) {
  // (min_content_sizes, max_content_sizes)
  let min_sizes : Array[Double] = []
  let max_sizes : Array[Double] = []
  for i = 0; i < track_count; i = i + 1 {
    min_sizes.push(0.0)
    max_sizes.push(0.0)
  }

  // Build track type array for distribution decisions
  let track_types : Array[@types.TrackSizingFunction] = []
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
    if child.style.display == @types.Display::None {
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
      child, is_column, container_width, container_height, margin_percent_base, cache,
      dispatch,
    )
    let min_content_contribution = min_content + margin_start + margin_end
    let max_contribution = max_content + margin_start + margin_end

    // CSS Grid spec: for auto tracks, overflow:hidden items have minimum contribution of 0
    let overflow = if is_column {
      child.style.overflow_x
    } else {
      child.style.overflow_y
    }
    let has_overflow_clip = overflow != @types.Visible
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
        @types.TrackSizingFunction::MinContent => min_content_contrib
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
      let gap_total = if span > 1 { gap * (span - 1).to_double() } else { 0.0 }
      let min_content_span = max(0.0, min_content_contrib - gap_total)
      let max_span = max(0.0, max_contrib - gap_total)

      // Count track types for distribution
      let mut min_content_track_count = 0
      let mut auto_track_count = 0
      let mut all_fr = true
      let mut total_fr_value = 0.0
      for t = start; t < end; t = t + 1 {
        match track_types[t] {
          @types.TrackSizingFunction::MinContent =>
            min_content_track_count = min_content_track_count + 1
          @types.TrackSizingFunction::Auto =>
            auto_track_count = auto_track_count + 1
          @types.TrackSizingFunction::MaxContent =>
            auto_track_count = auto_track_count + 1
          @types.FitContentLength(_) => auto_track_count = auto_track_count + 1
          @types.FitContentPercent(_) => auto_track_count = auto_track_count + 1
          @types.TrackSizingFunction::Fr(fr) =>
            total_fr_value = total_fr_value + fr
          @types.TrackSizingFunction::Length(_) => all_fr = false
          @types.TrackSizingFunction::Percent(_) => all_fr = false
          _ => all_fr = false
        }
        match track_types[t] {
          @types.TrackSizingFunction::Fr(_) => ()
          _ => all_fr = false
        }
      }

      // Calculate current sum of spanned tracks for min_sizes
      let mut min_sum = 0.0
      for t = start; t < end; t = t + 1 {
        min_sum = min_sum + min_sizes[t]
      }
      let min_extra = min_content_span - min_sum

      // Distribute to min_sizes based on track type
      // min-content tracks: fixed at min-content unless no other tracks can grow
      // auto/max-content/fit-content/fr tracks: receive extra space
      if min_extra > 0.0 {
        if all_fr && total_fr_value > 0.0 {
          // All Fr tracks: distribute min_content proportionally
          for t = start; t < end; t = t + 1 {
            match track_types[t] {
              @types.TrackSizingFunction::Fr(fr) => {
                let proportion = fr / total_fr_value
                min_sizes[t] = min_sizes[t] + min_extra * proportion
              }
              _ => ()
            }
          }
        } else {
          // Mixed tracks: distribute based on what each track type needs
          let has_overflow_hidden = minimum_contrib < min_content_contrib
          if has_overflow_hidden {
            // With overflow:hidden: only min-content tracks get contribution
            if min_content_track_count > 0 {
              let per_min_content_track = min_extra /
                min_content_track_count.to_double()
              for t = start; t < end; t = t + 1 {
                match track_types[t] {
                  @types.TrackSizingFunction::MinContent =>
                    min_sizes[t] = min_sizes[t] + per_min_content_track
                  _ => ()
                }
              }
            }
          } else {
            // Without overflow:hidden: distribute to non-min-content intrinsic tracks
            let mut growable_weight = 0.0
            for t = start; t < end; t = t + 1 {
              match track_types[t] {
                @types.TrackSizingFunction::Length(_)
                | @types.TrackSizingFunction::Percent(_) => ()
                @types.TrackSizingFunction::MinContent => ()
                @types.TrackSizingFunction::Fr(fr) =>
                  growable_weight = growable_weight + fr
                _ => growable_weight = growable_weight + 1.0
              }
            }
            if growable_weight > 0.0 {
              for t = start; t < end; t = t + 1 {
                match track_types[t] {
                  @types.TrackSizingFunction::Length(_)
                  | @types.TrackSizingFunction::Percent(_) => ()
                  @types.TrackSizingFunction::MinContent => ()
                  @types.TrackSizingFunction::Fr(fr) =>
                    min_sizes[t] = min_sizes[t] +
                      min_extra * fr / growable_weight
                  _ => min_sizes[t] = min_sizes[t] + min_extra / growable_weight
                }
              }
            } else if min_content_track_count > 0 {
              // Fallback: distribute to min-content tracks if nothing else can grow
              let per_min_content_track = min_extra /
                min_content_track_count.to_double()
              for t = start; t < end; t = t + 1 {
                match track_types[t] {
                  @types.TrackSizingFunction::MinContent =>
                    min_sizes[t] = min_sizes[t] + per_min_content_track
                  _ => ()
                }
              }
            }
          }
        }
      }

      // After distributing min_extra, ensure max_sizes >= min_sizes
      // and calculate max_extra based on updated state
      for t = start; t < end; t = t + 1 {
        if max_sizes[t] < min_sizes[t] {
          max_sizes[t] = min_sizes[t]
        }
      }
      let mut max_sum = 0.0
      for t = start; t < end; t = t + 1 {
        max_sum = max_sum + max_sizes[t]
      }
      let max_extra = max_span - max_sum

      // Distribute extra space to max_sizes
      // CSS Grid spec priority: max-content tracks get priority, then auto tracks
      // min-content tracks don't grow
      if max_extra > 0.0 {
        if all_fr && total_fr_value > 0.0 {
          // Distribute proportionally based on fr values
          for t = start; t < end; t = t + 1 {
            match track_types[t] {
              @types.TrackSizingFunction::Fr(fr) => {
                let proportion = fr / total_fr_value
                max_sizes[t] = max_sizes[t] + max_extra * proportion
              }
              _ => ()
            }
          }
        } else {
          // Count max-content tracks (highest priority)
          let mut max_content_count = 0
          for t = start; t < end; t = t + 1 {
            match track_types[t] {
              @types.TrackSizingFunction::MaxContent =>
                max_content_count = max_content_count + 1
              _ => ()
            }
          }

          // Count auto/fit-content tracks (lower priority)
          let mut auto_count = 0
          for t = start; t < end; t = t + 1 {
            match track_types[t] {
              @types.TrackSizingFunction::Auto => auto_count = auto_count + 1
              @types.FitContentLength(_) => auto_count = auto_count + 1
              @types.FitContentPercent(_) => auto_count = auto_count + 1
              _ => ()
            }
          }
          if max_content_count > 0 {
            // max-content tracks get all the extra space
            let per_track = max_extra / max_content_count.to_double()
            for t = start; t < end; t = t + 1 {
              match track_types[t] {
                @types.TrackSizingFunction::MaxContent =>
                  max_sizes[t] = max_sizes[t] + per_track
                _ => ()
              }
            }
          } else if auto_count > 0 {
            // auto tracks get the extra space if no max-content tracks
            let per_track = max_extra / auto_count.to_double()
            for t = start; t < end; t = t + 1 {
              match track_types[t] {
                @types.TrackSizingFunction::Auto
                | @types.FitContentLength(_)
                | @types.FitContentPercent(_) =>
                  max_sizes[t] = max_sizes[t] + per_track
                _ => ()
              }
            }
          } else {
            // Fallback: distribute to all intrinsic tracks
            let mut intrinsic_count = 0
            for t = start; t < end; t = t + 1 {
              match track_types[t] {
                @types.TrackSizingFunction::Length(_) => ()
                @types.TrackSizingFunction::Percent(_) => ()
                @types.TrackSizingFunction::MinContent => ()
                _ => intrinsic_count = intrinsic_count + 1
              }
            }
            if intrinsic_count > 0 {
              let per_track = max_extra / intrinsic_count.to_double()
              for t = start; t < end; t = t + 1 {
                match track_types[t] {
                  @types.TrackSizingFunction::Length(_) => ()
                  @types.TrackSizingFunction::Percent(_) => ()
                  @types.TrackSizingFunction::MinContent => ()
                  _ => max_sizes[t] = max_sizes[t] + per_track
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
) -> @types.IntrinsicSize {
  match child.measure {
    Some(measure) => (measure.func)(available_width, available_height)
    None => @types.IntrinsicSize::default()
  }
}

///|
/// Calculate intrinsic sizes (min-content, max-content) for a single item
fn calculate_item_intrinsic_sizes(
  child : @node.Node,
  is_column : Bool,
  container_width : Double,
  container_height : Double,
  margin_percent_base : Double,
  cache : GridIntrinsicCache,
  dispatch : @node.DispatchFn,
) -> (Double, Double, Double, Double) {
  // Returns (min_content, max_content, margin_start, margin_end)
  if is_column {
    // Width intrinsic sizes
    let mut add_box = true
    let (min_content, max_content) = match child.style.width {
      @types.Length(v) => {
        add_box = false
        (v, v)
      }
      @types.Percent(p) => {
        add_box = false
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
            @types.Grid => {
              add_box = false
              // Compute grid layout for min-content with definite width (shrink to min)
              let min_layout = compute_grid_layout_internal(
                child,
                0.0,
                1.0e10,
                true,
                false,
                @types.MaxContent,
                false,
                0.0,
                1.0e10,
                dispatch,
              )
              // Compute grid layout for max-content (with large available width)
              let max_layout = compute_grid_layout(
                child, 1.0e10, 1.0e10, dispatch,
              )
              (min_layout.width, max_layout.width)
            }
            @types.Flex => {
              add_box = false
              // Calculate flex container's intrinsic size directly
              let is_row = match child.style.flex_direction {
                @types.Row | @types.RowReverse => true
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
                  if flex_child.style.display == @types.Display::None {
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
                    @types.MinContent
                    | @types.MaxContent
                    | @types.FitContent(_) => (0.0, 0.0)
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
                  if flex_child.style.display == @types.Display::None {
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
                    @types.MinContent
                    | @types.MaxContent
                    | @types.FitContent(_) => (0.0, 0.0)
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
            @types.Block => {
              add_box = false
              // Block layout for intrinsic width
              let available_height = if container_height > 0.0 {
                Some(container_height)
              } else {
                None
              }
              let min_ctx : @types.LayoutContext = {
                available_width: 0.0,
                available_height,
                sizing_mode: @types.MaxContent,
                viewport_width: container_width,
                viewport_height: 0.0,
                stretch_width: false,
                stretch_height: false,
              }
              let min_layout = @block.compute(child, min_ctx, dispatch)
              let max_ctx : @types.LayoutContext = {
                available_width: container_width,
                available_height,
                sizing_mode: @types.MaxContent,
                viewport_width: container_width,
                viewport_height: 0.0,
                stretch_width: false,
                stretch_height: false,
              }
              let max_layout = @block.compute(child, max_ctx, dispatch)
              (min_layout.width, max_layout.width)
            }
            @types.Table | @types.InlineTable => {
              add_box = false
              // Table layout for intrinsic width
              let width = @table.compute_intrinsic_size(child, true)
              (width, width)
            }
            _ => {
              // For other display types, use measure or defaults
              let intrinsic = get_intrinsic_from_measure(
                child, container_width, 1.0e10,
              )
              (intrinsic.min_width, intrinsic.max_width)
            }
          }
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) => (0.0, 0.0)
    }
    // Add padding and border to intrinsic sizes when needed
    let pl = resolve_dimension(child.style.padding.left, container_width, 0.0)
    let pr = resolve_dimension(child.style.padding.right, container_width, 0.0)
    let bl = resolve_dimension(child.style.border.left, container_width, 0.0)
    let br = resolve_dimension(child.style.border.right, container_width, 0.0)
    let box_size = pl + pr + bl + br
    let content_min = if add_box {
      if min_content + box_size > box_size {
        min_content + box_size
      } else {
        box_size
      }
    } else if min_content > box_size {
      min_content
    } else {
      box_size
    }
    let content_max = if add_box {
      if max_content + box_size > box_size {
        max_content + box_size
      } else {
        box_size
      }
    } else if max_content > box_size {
      max_content
    } else {
      box_size
    }

    // Apply min-width/max-width constraints
    // Note: padding+border (box_size) is the absolute minimum
    let style_min_width = match child.style.min_width {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width
      @types.Auto => 0.0
      @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
    }
    let style_max_width = match child.style.max_width {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width
      @types.Auto => 1.0e10
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        @double.infinity
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
    // Resolve margins - CSS spec: percentage margins resolve against container width
    let ml = match child.style.margin.left {
      @types.Length(v) => v
      @types.Percent(p) => p * margin_percent_base
      _ => 0.0
    }
    let mr = match child.style.margin.right {
      @types.Length(v) => v
      @types.Percent(p) => p * margin_percent_base
      _ => 0.0
    }
    (final_min, final_max, ml, mr)
  } else {
    // Height intrinsic sizes
    let mut add_box = true
    let (min_content, max_content) = match child.style.height {
      @types.Length(v) => {
        add_box = false
        (v, v)
      }
      @types.Percent(p) => {
        add_box = false
        if container_height > 0.0 {
          let resolved = p * container_height
          (resolved, resolved)
          // In an indefinite block-size context, percentage heights contribute
          // like auto for leaf replaced elements (intrinsic size), otherwise 0.
        } else if child.children.length() == 0 {
          let measure_available_width = match child.style.width {
            @types.Length(v) => v
            @types.Percent(p) => p * container_width
            @types.Auto
            | @types.MinContent
            | @types.MaxContent
            | @types.FitContent(_) => 1.0e10
          }
          let intrinsic = get_intrinsic_from_measure(
            child, measure_available_width, container_width,
          )
          (intrinsic.min_height, intrinsic.max_height)
        } else {
          (0.0, 0.0)
        }
      }
      @types.Auto =>
        if child.children.length() == 0 {
          // If inline size is definite on the item, measure height against that
          // width so wrapped content contributes correct block-size.
          let measure_available_width = match child.style.width {
            @types.Length(v) => v
            @types.Percent(p) => p * container_width
            @types.Auto
            | @types.MinContent
            | @types.MaxContent
            | @types.FitContent(_) => 1.0e10
          }
          let intrinsic = get_intrinsic_from_measure(
            child, measure_available_width, container_width,
          )
          (intrinsic.min_height, intrinsic.max_height)
        } else {
          // For containers, recursively compute layout to get intrinsic size
          match child.style.display {
            @types.Grid => {
              add_box = false
              let ml = match child.style.margin.left {
                @types.Length(v) => v
                @types.Percent(p) => p * margin_percent_base
                _ => 0.0
              }
              let mr = match child.style.margin.right {
                @types.Length(v) => v
                @types.Percent(p) => p * margin_percent_base
                _ => 0.0
              }
              let available_width_for_layout = if container_width > 0.0 {
                max(0.0, container_width - ml - mr)
              } else {
                0.0
              }
              // Determine intrinsic widths first, then compute heights at those widths
              let (min_width, max_width) = match child.style.width {
                @types.Length(w) => (w, w)
                @types.Percent(p) => {
                  let w = p * container_width
                  (w, w)
                }
                @types.Auto
                | @types.MinContent
                | @types.MaxContent
                | @types.FitContent(_) =>
                  if available_width_for_layout > 0.0 {
                    (available_width_for_layout, available_width_for_layout)
                  } else {
                    let min_layout = compute_grid_layout_internal(
                      child,
                      0.0,
                      1.0e10,
                      true,
                      false,
                      @types.MaxContent,
                      false,
                      0.0,
                      1.0e10,
                      dispatch,
                    )
                    let max_layout = compute_grid_layout(
                      child, 1.0e10, 1.0e10, dispatch,
                    )
                    (min_layout.width, max_layout.width)
                  }
              }
              let min_layout = compute_grid_layout_internal(
                child,
                min_width,
                0.0,
                true,
                false,
                @types.MaxContent,
                false,
                container_width,
                0.0,
                dispatch,
              )
              let max_layout = compute_grid_layout_internal(
                child,
                max_width,
                1.0e10,
                true,
                false,
                @types.MaxContent,
                false,
                container_width,
                1.0e10,
                dispatch,
              )
              (min_layout.height, max_layout.height)
            }
            @types.Flex => {
              add_box = false
              // Get width for flex layout: use explicit width if specified, else use container width
              let flex_available_width = match child.style.width {
                @types.Length(w) => w
                @types.Percent(p) => p * container_width
                @types.Auto => container_width
                @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
                  container_width
              }
              // Check cache for min-content height
              let min_height = match cache.get(child.uid, true, false) {
                Some(cached) => cached
                None => {
                  let min_ctx : @types.LayoutContext = {
                    available_width: flex_available_width,
                    available_height: Some(0.0),
                    sizing_mode: @types.MaxContent,
                    viewport_width: container_width,
                    viewport_height: 0.0,
                    stretch_width: false,
                    stretch_height: false,
                  }
                  let min_layout = @flex.compute(child, min_ctx, dispatch)
                  cache.set(child.uid, true, false, min_layout.height)
                  min_layout.height
                }
              }
              // Check cache for max-content height
              let max_height = match cache.get(child.uid, true, true) {
                Some(cached) => cached
                None => {
                  let max_ctx : @types.LayoutContext = {
                    available_width: flex_available_width,
                    available_height: Some(1.0e10),
                    sizing_mode: @types.MaxContent,
                    viewport_width: container_width,
                    viewport_height: 0.0,
                    stretch_width: false,
                    stretch_height: false,
                  }
                  let max_layout = @flex.compute(child, max_ctx, dispatch)
                  cache.set(child.uid, true, true, max_layout.height)
                  max_layout.height
                }
              }
              (min_height, max_height)
            }
            @types.Block => {
              add_box = false
              // Compute block layout for intrinsic height
              let min_ctx : @types.LayoutContext = {
                available_width: container_width,
                available_height: Some(0.0),
                sizing_mode: @types.MaxContent,
                viewport_width: container_width,
                viewport_height: 0.0,
                stretch_width: false,
                stretch_height: false,
              }
              let min_layout = @block.compute(child, min_ctx, dispatch)
              let max_ctx : @types.LayoutContext = {
                available_width: container_width,
                available_height: Some(1.0e10),
                sizing_mode: @types.MaxContent,
                viewport_width: container_width,
                viewport_height: 0.0,
                stretch_width: false,
                stretch_height: false,
              }
              let max_layout = @block.compute(child, max_ctx, dispatch)
              (min_layout.height, max_layout.height)
            }
            @types.Table | @types.InlineTable => {
              add_box = false
              // Table layout for intrinsic height
              let height = @table.compute_intrinsic_size(child, false)
              (height, height)
            }
            _ => {
              let intrinsic = get_intrinsic_from_measure(
                child, 1.0e10, container_width,
              )
              (intrinsic.min_height, intrinsic.max_height)
            }
          }
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) => (0.0, 0.0)
    }
    // Add padding and border (resolved against WIDTH per CSS spec)
    let pt = resolve_dimension(child.style.padding.top, container_width, 0.0)
    let pb = resolve_dimension(child.style.padding.bottom, container_width, 0.0)
    let bt = resolve_dimension(child.style.border.top, container_width, 0.0)
    let bb = resolve_dimension(child.style.border.bottom, container_width, 0.0)
    let box_size = pt + pb + bt + bb
    let content_min = if add_box {
      if min_content + box_size > box_size {
        min_content + box_size
      } else {
        box_size
      }
    } else if min_content > box_size {
      min_content
    } else {
      box_size
    }
    let content_max = if add_box {
      if max_content + box_size > box_size {
        max_content + box_size
      } else {
        box_size
      }
    } else if max_content > box_size {
      max_content
    } else {
      box_size
    }

    // Apply min-height/max-height constraints
    // Note: padding+border (box_size) is the absolute minimum
    let style_min_height = match child.style.min_height {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width // percent height resolves against width
      @types.Auto => 0.0
      @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
    }
    let style_max_height = match child.style.max_height {
      @types.Length(v) => v
      @types.Percent(p) => p * container_width
      @types.Auto => 1.0e10
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        @double.infinity
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
    // Resolve margins - CSS spec: all percentage margins resolve against container width
    let mt = match child.style.margin.top {
      @types.Length(v) => v
      @types.Percent(p) => p * margin_percent_base
      _ => 0.0
    }
    let mb = match child.style.margin.bottom {
      @types.Length(v) => v
      @types.Percent(p) => p * margin_percent_base
      _ => 0.0
    }
    (final_min, final_max, mt, mb)
  }
}

///|
/// Convert SingleTrackSizing to TrackSizingFunction
fn single_to_track(
  single : @types.SingleTrackSizing,
) -> @types.TrackSizingFunction {
  match single {
    @types.SingleTrackSizing::Length(v) => @types.TrackSizingFunction::Length(v)
    @types.SingleTrackSizing::Percent(p) =>
      @types.TrackSizingFunction::Percent(p)
    @types.SingleTrackSizing::Fr(f) => @types.TrackSizingFunction::Fr(f)
    @types.SingleTrackSizing::Auto => @types.TrackSizingFunction::Auto
    @types.SingleTrackSizing::MinContent =>
      @types.TrackSizingFunction::MinContent
    @types.SingleTrackSizing::MaxContent =>
      @types.TrackSizingFunction::MaxContent
    @types.SingleTrackSizing::MinMax(min, max) => @types.MinMax(min, max)
    @types.SingleTrackSizing::FitContentLength(v) => @types.FitContentLength(v)
    @types.SingleTrackSizing::FitContentPercent(p) =>
      @types.FitContentPercent(p)
  }
}

///|
/// Expand repeat() in track templates
fn expand_track_templates(
  templates : Array[@types.TrackSizingFunction],
  available_size : Double,
) -> (Array[@types.TrackSizingFunction], Array[Bool]) {
  // First, calculate fixed track sizes (non-repeat tracks)
  let mut fixed_size = 0.0
  for i = 0; i < templates.length(); i = i + 1 {
    match templates[i] {
      @types.TrackSizingFunction::Length(v) => fixed_size = fixed_size + v
      @types.TrackSizingFunction::Percent(p) =>
        fixed_size = fixed_size + available_size * p
      @types.Repeat(_, _) => () // Skip repeats
      _ => () // Fr, Auto, etc. don't contribute to fixed size
    }
  }
  let remaining_size = available_size - fixed_size
  let result : Array[@types.TrackSizingFunction] = []
  let auto_fit_mask : Array[Bool] = []
  for i = 0; i < templates.length(); i = i + 1 {
    match templates[i] {
      @types.Repeat(repeat_count, tracks) => {
        let repetitions = match repeat_count {
          @types.Count(n) => n
          @types.AutoFill => {
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
          @types.AutoFit => {
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
        let is_auto_fit = match repeat_count {
          @types.AutoFit => true
          _ => false
        }
        // Expand the tracks
        for r = 0; r < repetitions; r = r + 1 {
          for t = 0; t < tracks.length(); t = t + 1 {
            result.push(single_to_track(tracks[t]))
            auto_fit_mask.push(is_auto_fit)
          }
        }
      }
      other => {
        result.push(other)
        auto_fit_mask.push(false)
      }
    }
  }
  (result, auto_fit_mask)
}

///|
/// Calculate the total size of tracks in a repeat pattern
fn calculate_repeat_track_size(
  tracks : Array[@types.SingleTrackSizing],
  available_size : Double,
) -> Double {
  let mut total = 0.0
  for i = 0; i < tracks.length(); i = i + 1 {
    match tracks[i] {
      @types.SingleTrackSizing::Length(v) => total = total + v
      @types.SingleTrackSizing::Percent(p) => total = total + available_size * p
      @types.SingleTrackSizing::Fr(_) => total = total + 0.0 // Fr tracks are flexible
      @types.SingleTrackSizing::Auto => total = total + 0.0
      @types.SingleTrackSizing::MinContent => total = total + 0.0
      @types.SingleTrackSizing::MaxContent => total = total + 0.0
      @types.SingleTrackSizing::FitContentLength(v) => total = total + v
      @types.SingleTrackSizing::FitContentPercent(p) =>
        total = total + available_size * p
      @types.SingleTrackSizing::MinMax(min, _) =>
        match min {
          @types.MinTrackSizing::Length(v) => total = total + v
          @types.MinTrackSizing::Percent(p) =>
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
  explicit_templates : Array[@types.TrackSizingFunction],
  auto_templates : Array[@types.TrackSizingFunction],
  available_size : Double,
  gap : Double,
  min_content_sizes : Array[Double],
  max_content_sizes : Array[Double],
  offset : Int, // Number of implicit tracks before explicit grid
  total_count : Int, // Total number of tracks needed
  size_is_definite : Bool, // If false, auto tracks should not expand beyond content
  use_min_content : Bool, // If true, use min-content sizing (fr tracks = 0)
) -> Array[GridTrack] {
  let tracks : Array[GridTrack] = []
  let mut position = 0.0
  let explicit_count = explicit_templates.length()
  let track_count = total_count

  // Build complete template array: [implicit before] + [explicit] + [implicit after]
  let all_templates : Array[@types.TrackSizingFunction] = []

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
      @types.TrackSizingFunction::Length(v) => {
        base_sizes.push(v)
        min_sizes.push(v)
        max_sizes.push(v)
        fixed_size = fixed_size + v
      }
      @types.TrackSizingFunction::Percent(p) => {
        // Percent tracks resolve to 0 when container size is indefinite
        let size = if size_is_definite { available_size * p } else { 0.0 }
        base_sizes.push(size)
        min_sizes.push(size)
        max_sizes.push(size)
        fixed_size = fixed_size + size
      }
      @types.TrackSizingFunction::Fr(fr) => {
        // Fr tracks start with base size of 0, but min-content is the floor
        // During flex distribution, tracks cannot shrink below min-content
        base_sizes.push(0.0)
        min_sizes.push(min_content)
        max_sizes.push(1.0e10) // Effectively unlimited
        total_fr = total_fr + fr
        fr_track_count_phase1 = fr_track_count_phase1 + 1
      }
      @types.TrackSizingFunction::Auto => {
        // Auto uses max-content for base size but can shrink to min-content
        // Implicit tracks can shrink to 0 (implicit = outside explicit range)
        let is_implicit = i < explicit_start || i >= explicit_end
        let min_for_auto = if is_implicit { 0.0 } else { min_content }
        base_sizes.push(max_content)
        min_sizes.push(min_for_auto)
        max_sizes.push(1.0e10)
        fixed_size = fixed_size + max_content
      }
      @types.TrackSizingFunction::MinContent => {
        // MinContent track uses min-content size
        base_sizes.push(min_content)
        min_sizes.push(min_content)
        max_sizes.push(min_content)
        fixed_size = fixed_size + min_content
      }
      @types.TrackSizingFunction::MaxContent => {
        // MaxContent track uses max-content size
        base_sizes.push(max_content)
        min_sizes.push(max_content)
        max_sizes.push(max_content)
        fixed_size = fixed_size + max_content
      }
      @types.MinMax(min_track, max_track) => {
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
      @types.FitContentLength(limit) => {
        // fit-content(limit) = min(max-content, max(min-content, limit))
        // The track size is clamped between min-content and min(max-content, limit)
        let max_limit = if max_content < limit { max_content } else { limit }
        let base = if max_limit > min_content { max_limit } else { min_content }
        base_sizes.push(base)
        min_sizes.push(min_content)
        max_sizes.push(max_limit)
        fixed_size = fixed_size + base
      }
      @types.FitContentPercent(p) => {
        // fit-content(percent) - percent of container size as limit
        let limit = if size_is_definite {
          available_size * p
        } else {
          // Indefinite container: use percent of max-content as the limit
          max_content * p
        }
        let max_limit = if max_content < limit { max_content } else { limit }
        let base = if max_limit > min_content { max_limit } else { min_content }
        base_sizes.push(base)
        min_sizes.push(min_content)
        max_sizes.push(max_limit)
        fixed_size = fixed_size + base
      }
      @types.Repeat(_, _) => {
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
      // CSS Grid spec: Fr tracks cannot shrink below their min-content
      // Algorithm: iteratively freeze tracks that exceed their hypothetical fr size
      if total_fr > 0.0 {
        // Track which fr tracks are frozen (have reached min-content floor)
        let frozen : Array[Bool] = Array::make(track_count, false)
        let mut unfrozen_fr = total_fr
        let mut space_for_fr = remaining_space

        // Iteratively freeze tracks whose min-content exceeds hypothetical fr size
        let mut changed = true
        while changed {
          changed = false
          let effective_fr = if unfrozen_fr < 1.0 { 1.0 } else { unfrozen_fr }
          let hypothetical_fr_unit = space_for_fr / effective_fr
          for i = 0; i < track_count; i = i + 1 {
            if frozen[i] {
              continue
            }
            match all_templates[i] {
              @types.TrackSizingFunction::Fr(fr) => {
                let hypothetical_size = fr * hypothetical_fr_unit
                let min_size = min_sizes[i]
                if min_size > hypothetical_size {
                  // This track needs more than its fr share, freeze it
                  frozen[i] = true
                  base_sizes[i] = min_size
                  unfrozen_fr = unfrozen_fr - fr
                  space_for_fr = space_for_fr - min_size
                  changed = true
                }
              }
              _ => ()
            }
          }
        }

        // Distribute remaining space to unfrozen tracks
        if unfrozen_fr > 0.0 {
          let effective_fr = if unfrozen_fr < 1.0 { 1.0 } else { unfrozen_fr }
          let fr_unit = space_for_fr / effective_fr
          for i = 0; i < track_count; i = i + 1 {
            if frozen[i] {
              continue
            }
            match all_templates[i] {
              @types.TrackSizingFunction::Fr(fr) => base_sizes[i] = fr * fr_unit
              _ => ()
            }
          }
        }
      } else {
        // All fr values are 0 - distribute evenly
        let per_track = remaining_space / fr_track_count_phase1.to_double()
        for i = 0; i < track_count; i = i + 1 {
          match all_templates[i] {
            @types.TrackSizingFunction::Fr(_) =>
              base_sizes[i] = max(per_track, min_sizes[i])
            _ => ()
          }
        }
      }
    } else if use_min_content {
      // For min-content sizing: fr tracks stay at 0
      // Per CSS Grid spec: min-content contribution of fr tracks is 0
      ()
    } else {
      // Container size is indefinite (max-content/auto): Find hypothetical fr unit to maintain proportions
      // Per CSS Grid spec: fr unit = max(max-content / fr value) across all fr tracks
      let mut hypothetical_fr_unit = 0.0
      let mut fr_track_count = 0
      for i = 0; i < track_count; i = i + 1 {
        let template = all_templates[i]
        match template {
          @types.TrackSizingFunction::Fr(fr) => {
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
            @types.TrackSizingFunction::Fr(_) => {
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
            @types.TrackSizingFunction::Fr(fr) =>
              base_sizes[i] = fr * hypothetical_fr_unit
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
        @types.TrackSizingFunction::Auto =>
          if max_sizes[i] > base_sizes[i] {
            growable_count = growable_count + 1
          }
        @types.MinMax(_, _) =>
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
          @types.TrackSizingFunction::Auto => {
            let growth = min_double(
              space_per_track,
              max_sizes[i] - base_sizes[i],
            )
            base_sizes[i] = base_sizes[i] + growth
          }
          @types.MinMax(_, _) => {
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
  if size_is_definite && total_size > available_size {
    // We need to shrink tracks
    // Priority: 1) Auto tracks shrink first (to min-content)
    //           2) MinMax tracks shrink second (to their min)
    let mut remaining_overflow = total_size - available_size

    // Step 1: Shrink Auto tracks to min-content proportionally
    if remaining_overflow > 0.0 {
      let mut total_shrinkable = 0.0
      for i = 0; i < track_count; i = i + 1 {
        match all_templates[i] {
          @types.TrackSizingFunction::Auto => {
            let shrinkable = base_sizes[i] - min_sizes[i]
            if shrinkable > 0.0 {
              total_shrinkable = total_shrinkable + shrinkable
            }
          }
          _ => ()
        }
      }
      if total_shrinkable > 0.0 {
        let shrink_ratio = min_double(
          1.0,
          remaining_overflow / total_shrinkable,
        )
        for i = 0; i < track_count; i = i + 1 {
          match all_templates[i] {
            @types.TrackSizingFunction::Auto => {
              let shrinkable = base_sizes[i] - min_sizes[i]
              if shrinkable > 0.0 {
                let shrink = shrinkable * shrink_ratio
                base_sizes[i] = base_sizes[i] - shrink
              }
            }
            _ => ()
          }
        }
        remaining_overflow = remaining_overflow -
          total_shrinkable * shrink_ratio
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
          @types.MinMax(_, _) => {
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
            @types.MinMax(_, _) => {
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
      @types.TrackSizingFunction::Auto => true
      @types.TrackSizingFunction::Fr(_) => true
      @types.MinMax(_, _) => true
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
  auto_templates : Array[@types.TrackSizingFunction],
  index : Int,
) -> @types.TrackSizingFunction {
  if auto_templates.length() == 0 {
    // Default to Auto if no auto templates specified
    @types.TrackSizingFunction::Auto
  } else {
    // Cycle through templates
    auto_templates[index % auto_templates.length()]
  }
}

///|
/// Get auto template in reverse order (for implicit tracks before explicit grid)
/// k is 1-indexed distance from explicit grid: k=1 is closest, uses last template
fn get_auto_template_reverse(
  auto_templates : Array[@types.TrackSizingFunction],
  k : Int,
) -> @types.TrackSizingFunction {
  if auto_templates.length() == 0 {
    @types.TrackSizingFunction::Auto
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
/// Resolve effective template at track index with implicit before/after handling.
fn get_track_template_for_index(
  explicit_templates : Array[@types.TrackSizingFunction],
  auto_templates : Array[@types.TrackSizingFunction],
  explicit_offset : Int,
  index : Int,
) -> @types.TrackSizingFunction {
  if index < explicit_offset {
    let k = explicit_offset - index
    get_auto_template_reverse(auto_templates, k)
  } else if index < explicit_offset + explicit_templates.length() {
    explicit_templates[index - explicit_offset]
  } else {
    get_auto_template(
      auto_templates,
      index - explicit_offset - explicit_templates.length(),
    )
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
  auto_flow : @types.GridAutoFlow,
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
    if style.display == @types.Display::None {
      continue
    }
    // Skip absolute positioned items - they don't participate in grid placement
    if style.position == @types.Absolute || style.position == @types.Fixed {
      continue
    }

    // Check for explicit column Line placement
    match style.grid_column.start {
      @types.GridPlacement::Line(n) => {
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
      @types.GridPlacement::Line(n) => {
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
    if style.display == @types.Display::None {
      continue
    }
    // Skip absolute positioned items
    if style.position == @types.Absolute || style.position == @types.Fixed {
      continue
    }

    // Check if item has explicit Line positioning
    let has_explicit_column = match style.grid_column.start {
      @types.GridPlacement::Line(_) => true
      _ => false
    }
    let has_explicit_row = match style.grid_row.start {
      @types.GridPlacement::Line(_) => true
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
    if style.display == @types.Display::None {
      continue
    }
    // Skip absolute positioned items
    if style.position == @types.Absolute || style.position == @types.Fixed {
      continue
    }

    // Skip items already placed in Pass 2 (FULLY explicitly positioned)
    let has_explicit_column = match style.grid_column.start {
      @types.GridPlacement::Line(_) => true
      _ => false
    }
    let has_explicit_row = match style.grid_row.start {
      @types.GridPlacement::Line(_) => true
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
            @types.Row | @types.RowDense =>
              // Row-major: advance column, then row
              while is_cell_occupied(occupied, next_row, next_column) {
                next_column = next_column + 1
                if next_column >= columns {
                  next_column = min_col
                  next_row = next_row + 1
                }
              }
            @types.Column | @types.ColumnDense => {
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
        @types.Row | @types.RowDense => {
          next_column = col_end
          if next_column >= columns {
            next_column = min_col
            next_row = next_row + 1
          }
        }
        @types.Column | @types.ColumnDense => {
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
  line : @types.GridLine,
  auto_position : Int,
  explicit_count : Int,
) -> (Int, Int) {
  let start = match line.start {
    @types.GridPlacement::Auto => auto_position
    @types.GridPlacement::Line(n) =>
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
    @types.GridPlacement::Span(_) => auto_position
  }
  let end = match line.end {
    @types.GridPlacement::Auto => start + 1
    @types.GridPlacement::Line(n) =>
      if n > 0 {
        n - 1
      } else if n < 0 {
        explicit_count + 1 + n // Don't clamp
      } else {
        start + 1
      }
    @types.GridPlacement::Span(s) => start + s
  }

  // Handle span in start position
  let (final_start, final_end) = match line.start {
    @types.GridPlacement::Span(s) =>
      match line.end {
        @types.GridPlacement::Line(n) => {
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
/// Ensure block-axis tracks can accommodate measured items with constrained inline size
fn adjust_block_tracks_for_measured_items(
  children : Array[@node.Node],
  placements : Array[GridItemPlacement],
  inline_tracks : Array[GridTrack],
  block_tracks : Array[GridTrack],
  block_gap : Double,
  is_vertical_writing : Bool,
  explicit_templates : Array[@types.TrackSizingFunction],
  auto_templates : Array[@types.TrackSizingFunction],
  explicit_offset : Int,
) -> Unit {
  if block_tracks.length() == 0 {
    return
  }
  let required_sizes : Array[Double] = []
  for t in block_tracks {
    required_sizes.push(t.size)
  }
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    if child.style.display == @types.Display::None {
      continue
    }
    if child.children.length() != 0 {
      continue
    }
    match child.measure {
      None => continue
      Some(_) => ()
    }
    let placement = placements[i]
    let block_start = if is_vertical_writing {
      placement.column_start
    } else {
      placement.row_start
    }
    let block_end = if is_vertical_writing {
      placement.column_end
    } else {
      placement.row_end
    }
    if block_end - block_start != 1 {
      continue
    }
    if block_start < 0 || block_start >= block_tracks.length() {
      continue
    }
    let block_template = get_track_template_for_index(
      explicit_templates, auto_templates, explicit_offset, block_start,
    )
    // Min-content tracks must remain based on intrinsic min-content contributions.
    if block_template == @types.TrackSizingFunction::MinContent {
      continue
    }
    let inline_start = if is_vertical_writing {
      placement.row_start
    } else {
      placement.column_start
    }
    let inline_end = if is_vertical_writing {
      placement.row_end
    } else {
      placement.column_end
    }
    let (_, inline_size) = get_span_bounds(
      inline_tracks, inline_start, inline_end,
    )
    if inline_size <= 0.0 {
      continue
    }
    let intrinsic = get_intrinsic_from_measure(child, 0.0, 0.0)
    if intrinsic.max_width <= 0.0 || intrinsic.max_height <= 0.0 {
      continue
    }
    let scaled_height = if inline_size < intrinsic.max_width {
      let area = intrinsic.max_width * intrinsic.max_height
      let scaled = area / inline_size
      if scaled < intrinsic.min_height {
        intrinsic.min_height
      } else {
        scaled
      }
    } else {
      intrinsic.max_height
    }
    let (margin_start, margin_end) = if is_vertical_writing {
      (
        resolve_dimension(child.style.margin.left, inline_size, 0.0),
        resolve_dimension(child.style.margin.right, inline_size, 0.0),
      )
    } else {
      (
        resolve_dimension(child.style.margin.top, inline_size, 0.0),
        resolve_dimension(child.style.margin.bottom, inline_size, 0.0),
      )
    }
    let required = scaled_height + margin_start + margin_end
    if required > required_sizes[block_start] {
      required_sizes[block_start] = required
    }
  }
  let mut pos = 0.0
  for i = 0; i < block_tracks.length(); i = i + 1 {
    let size = required_sizes[i]
    block_tracks[i] = {
      position: pos,
      size,
      stretchable: block_tracks[i].stretchable,
    }
    pos = pos + size + block_gap
  }
}

///|
/// Mark empty auto-fit tracks for collapse
fn compute_auto_fit_collapse(
  children : Array[@node.Node],
  placements : Array[GridItemPlacement],
  auto_fit_mask : Array[Bool],
  offset : Int,
  total_count : Int,
  is_column : Bool,
) -> Array[Bool] {
  let collapse : Array[Bool] = []
  for _i = 0; _i < total_count; _i = _i + 1 {
    collapse.push(false)
  }
  let mut has_auto_fit = false
  for v in auto_fit_mask {
    if v {
      has_auto_fit = true
      break
    }
  }
  if not(has_auto_fit) {
    return collapse
  }
  let has_item : Array[Bool] = []
  for _i = 0; _i < total_count; _i = _i + 1 {
    has_item.push(false)
  }
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    if child.style.display == @types.Display::None {
      continue
    }
    let placement = placements[i]
    let (start, end) = if is_column {
      (placement.column_start, placement.column_end)
    } else {
      (placement.row_start, placement.row_end)
    }
    for t = start; t < end; t = t + 1 {
      if t >= 0 && t < total_count {
        has_item[t] = true
      }
    }
  }
  for i = 0; i < auto_fit_mask.length(); i = i + 1 {
    if auto_fit_mask[i] {
      let idx = offset + i
      if idx >= 0 && idx < total_count && not(has_item[idx]) {
        collapse[idx] = true
      }
    }
  }
  collapse
}

///|
/// Collapse auto-fit tracks by zeroing size and removing gaps around them
fn collapse_auto_fit_tracks(
  tracks : Array[GridTrack],
  collapse : Array[Bool],
  gap : Double,
) -> Unit {
  if tracks.length() == 0 {
    return
  }
  let mut pos = 0.0
  for i = 0; i < tracks.length(); i = i + 1 {
    let should_collapse = if i < collapse.length() {
      collapse[i]
    } else {
      false
    }
    let size = if should_collapse { 0.0 } else { tracks[i].size }
    let stretchable = if should_collapse {
      false
    } else {
      tracks[i].stretchable
    }
    tracks[i] = { position: pos, size, stretchable }
    if not(should_collapse) {
      pos = pos + size + gap
    }
  }
}

///|
/// Compute layout for a child element
fn compute_child_layout(
  child : @node.Node,
  available_width : Double,
  available_height : Double,
  dispatch : @node.DispatchFn,
  _viewport_width? : Double = 0.0,
  _viewport_height? : Double = 0.0,
  stretch_width? : Bool = false,
  stretch_height? : Bool = false,
  percent_base_width? : Double = 0.0,
) -> @types.Layout {
  let percent_width_base = if percent_base_width > 0.0 {
    percent_base_width
  } else {
    available_width
  }
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
    percent_width_base,
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
    percent_width_base,
    0.0,
  )
  let padding_right = resolve_dimension(
    child.style.padding.right,
    percent_width_base,
    0.0,
  )
  // CSS spec: percent padding resolves against containing block's WIDTH, not height
  let padding_top = resolve_dimension(
    child.style.padding.top,
    percent_width_base,
    0.0,
  )
  let padding_bottom = resolve_dimension(
    child.style.padding.bottom,
    percent_width_base,
    0.0,
  )
  let border_left = resolve_dimension(
    child.style.border.left,
    percent_width_base,
    0.0,
  )
  let border_right = resolve_dimension(
    child.style.border.right,
    percent_width_base,
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
  let min_box_width = padding_left + padding_right + border_left + border_right
  let min_box_height = padding_top + padding_bottom + border_top + border_bottom
  if width < min_box_width {
    width = min_box_width
  }
  if height < min_box_height {
    height = min_box_height
  }

  // Apply min/max constraints before aspect_ratio
  // Resolve min/max from style
  let min_width_constraint = resolve_dimension(
    child.style.min_width,
    percent_width_base,
    0.0,
  )
  let max_width_constraint = resolve_dimension(
    child.style.max_width,
    percent_width_base,
    1.0e10,
  )
  let min_height_constraint = resolve_dimension(
    child.style.min_height,
    available_height,
    0.0,
  )
  let max_height_constraint = resolve_dimension(
    child.style.max_height,
    available_height,
    1.0e10,
  )

  // Track if dimension was constrained
  let width_before_constraint = width
  let height_before_constraint = height

  // Apply constraints
  if width < min_width_constraint {
    width = min_width_constraint
  }
  if width > max_width_constraint {
    width = max_width_constraint
  }
  if height < min_height_constraint {
    height = min_height_constraint
  }
  if height > max_height_constraint {
    height = max_height_constraint
  }

  // Check if dimension was constrained by min/max
  let width_was_constrained = width != width_before_constraint
  let height_was_constrained = height != height_before_constraint

  // Apply aspect_ratio
  // CSS spec: aspect_ratio applies when one dimension is "definite" and other is "auto"
  // A dimension is "effectively definite" if:
  //   - It has an explicit value (Length/Percent), OR
  //   - It was constrained by min/max
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
      let width_is_definite = not(width_is_auto) || width_was_constrained
      let height_is_definite = not(height_is_auto) || height_was_constrained
      if not(width_is_definite) && height_is_definite {
        // height is definite, compute width from aspect_ratio
        width = height * ratio
        // Re-apply width constraints
        if width < min_width_constraint {
          width = min_width_constraint
        }
        if width > max_width_constraint {
          width = max_width_constraint
        }
      } else if not(height_is_definite) && width_is_definite {
        // width is definite, compute height from aspect_ratio
        height = width / ratio
        // Re-apply height constraints
        if height < min_height_constraint {
          height = min_height_constraint
        }
        if height > max_height_constraint {
          height = max_height_constraint
        }
      }
    }
    None => ()
  }

  // For nested containers, recursively compute layout
  let child_layouts : Array[@types.Layout] = []
  if child.style.display == @types.Grid {
    // Recursively compute grid layout for nested grid containers
    // When a grid item is stretched (width/height comes from cell size),
    // treat the size as extrinsically definite for track sizing
    // If the computed size is finite, treat it as extrinsically definite to
    // avoid re-resolving percentages against the already-resolved size.
    let width_is_extrinsic_definite = width < 1.0e9
    let height_is_extrinsic_definite = height < 1.0e9
    // Nested Grid: use Definite sizing since we're in a parent Grid context with known size
    let nested_is_block_level = child.style.display == @types.Grid
    let nested_layout = compute_grid_layout_internal(
      child,
      width,
      height,
      width_is_extrinsic_definite,
      height_is_extrinsic_definite,
      @types.Definite,
      nested_is_block_level,
      percent_width_base, // Use percent base for padding resolution
      available_height, // Use available_height as viewport fallback
      dispatch,
    )
    // The nested layout's children need to be added
    for i = 0; i < nested_layout.children.length(); i = i + 1 {
      child_layouts.push(nested_layout.children[i])
    }
  } else if child.style.display == @types.Flex {
    // Recursively compute flex layout for nested flex containers
    // For intrinsic sizing (1.0e10), use MaxContent mode to get actual size
    let is_intrinsic_width = available_width >= 1.0e9
    let is_intrinsic_height = available_height >= 1.0e9
    let sizing_mode = if is_intrinsic_width || is_intrinsic_height {
      @types.SizingMode::MaxContent
    } else {
      @types.SizingMode::Definite
    }
    let ctx : @types.LayoutContext = {
      available_width: width,
      available_height: Some(height),
      sizing_mode,
      viewport_width: available_width,
      viewport_height: available_height,
      stretch_width: false,
      stretch_height: false,
    }
    // Use dispatcher for cache support
    let @node.DispatchFn(dispatch_fn) = dispatch
    let nested_layout = dispatch_fn(child, ctx, dispatch)
    for i = 0; i < nested_layout.children.length(); i = i + 1 {
      child_layouts.push(nested_layout.children[i])
    }
    // For auto dimensions with intrinsic sizing, use computed size from Flex
    let width_is_auto = match child.style.width {
      @types.Auto => true
      _ => false
    }
    let height_is_auto = match child.style.height {
      @types.Auto => true
      _ => false
    }
    if width_is_auto && is_intrinsic_width {
      width = nested_layout.width
    }
    if height_is_auto && is_intrinsic_height {
      height = nested_layout.height
    }
  } else if child.style.display == @types.Table ||
    child.style.display == @types.InlineTable {
    // Recursively compute table layout for nested tables
    // Use stretch flags from parameters to tell table whether to stretch or shrink-to-fit
    let ctx : @types.LayoutContext = {
      available_width: width,
      available_height: Some(height),
      sizing_mode: @types.Definite,
      viewport_width: available_width,
      viewport_height: available_height,
      stretch_width,
      stretch_height,
    }
    let nested_layout = @table.compute(child, ctx, dispatch)
    for i = 0; i < nested_layout.children.length(); i = i + 1 {
      child_layouts.push(nested_layout.children[i])
    }
    // Update dimensions based on table layout
    let width_is_auto = match child.style.width {
      @types.Auto => true
      _ => false
    }
    let height_is_auto = match child.style.height {
      @types.Auto => true
      _ => false
    }
    if width_is_auto {
      width = nested_layout.width
    }
    if height_is_auto {
      height = nested_layout.height
    }
  } else {
    // For block/inline contents inside a grid item, use block layout so normal flow
    // (line stacking, margin collapse, etc.) is preserved instead of stretching
    // every descendant to the grid area's available height.
    let child_ctx : @types.LayoutContext = {
      available_width: width,
      available_height: Some(height),
      sizing_mode: @types.Definite,
      viewport_width: available_width,
      viewport_height: available_height,
      stretch_width: false,
      stretch_height: false,
    }
    let nested_layout = @block.compute(child, child_ctx, dispatch)
    for i = 0; i < nested_layout.children.length(); i = i + 1 {
      child_layouts.push(nested_layout.children[i])
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
    overflow_x: child.style.overflow_x,
    overflow_y: child.style.overflow_y,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: child_layouts,
    text: child.text,
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
  child_layout : @types.Layout,
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
  let align : @types.Alignment = @core.resolve_align_self(
    child_style.align_self,
    container_style.align_items,
  )
  // Use justify_self for horizontal alignment
  let justify : @types.Alignment = @core.resolve_align_self(
    child_style.justify_self,
    container_style.justify_items,
  )

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

  // Check if min/max constraints are present (which would override stretch)
  let has_max_width = match child_style.max_width {
    @types.Auto => false
    _ => true
  }
  let has_max_height = match child_style.max_height {
    @types.Auto => false
    _ => true
  }

  // Calculate item size - don't clamp to cell size, allow overflow
  // If aspect_ratio derived a dimension, don't stretch that dimension
  // Also respect max constraints - if max is set and smaller than available, use computed size
  let mut item_width = match child_style.width {
    @types.Auto =>
      if has_aspect_ratio && not(height_is_auto) {
        // Width derived from aspect_ratio, use computed width
        child_layout.width
      } else if has_aspect_ratio &&
        has_max_width &&
        child_layout.width < available_width {
        // aspect_ratio with max_width constraint, width was derived from height
        child_layout.width
      } else if justify == @types.Alignment::Stretch {
        // Stretch to fill available width
        available_width
      } else {
        child_layout.width
      }
    _ => child_layout.width // Keep explicit size, don't clamp
  }
  // CSS spec: auto margins override stretch alignment
  let has_vertical_auto_margin = margin_top_is_auto || margin_bottom_is_auto
  let mut item_height = match child_style.height {
    @types.Auto =>
      if has_aspect_ratio && not(width_is_auto) {
        // Height derived from aspect_ratio, use computed height
        child_layout.height
      } else if has_aspect_ratio &&
        has_max_height &&
        child_layout.height < available_height {
        // aspect_ratio with max_height constraint, height was derived from width
        child_layout.height
      } else if has_aspect_ratio &&
        has_max_width &&
        child_layout.height < available_height {
        // aspect_ratio with max_width: width was constrained, height derived
        child_layout.height
      } else if align == @types.Alignment::Stretch &&
        not(has_vertical_auto_margin) {
        // Stretch only if no auto margins
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
    cell_width,
    0.0,
  )
  let child_padding_bottom = resolve_dimension(
    child_style.padding.bottom,
    cell_width,
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
    cell_width,
    0.0,
  )
  let child_border_bottom = resolve_dimension(
    child_style.border.bottom,
    cell_width,
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
  let resolved_max_height = resolve_dimension(
    child_style.max_height,
    cell_height,
    1.0e10,
  )

  let (clamped_width, clamped_height) = @core.clamp_size_with_box_min(
    item_width, item_height, style_min_width, resolved_max_width, style_min_height,
    resolved_max_height, child_min_from_box, child_min_height_from_box,
  )
  item_width = clamped_width
  item_height = clamped_height

  // Calculate remaining space for auto margins
  let remaining_width = available_width - item_width
  let remaining_height = available_height - item_height

  // Calculate auto margins
  let (final_margin_left, final_margin_right) = @core.resolve_auto_margin_pair(
    margin_left_is_auto, margin_right_is_auto, fixed_margin_left, fixed_margin_right,
    remaining_width,
  )
  let (final_margin_top, final_margin_bottom) = @core.resolve_auto_margin_pair(
    margin_top_is_auto, margin_bottom_is_auto, fixed_margin_top, fixed_margin_bottom,
    remaining_height,
  )

  // Calculate position based on alignment (auto margins override alignment)
  let x_offset = @core.compute_grid_self_alignment_offset(
    justify, available_width, item_width, margin_left_is_auto, margin_right_is_auto,
  )
  let y_offset = @core.compute_grid_self_alignment_offset(
    align, available_height, item_height, margin_top_is_auto, margin_bottom_is_auto,
  )

  // Suppress unused variable warnings
  let _ = final_margin_right
  let _ = final_margin_bottom

  // Apply inset for relative positioning
  // left/top take precedence over right/bottom.
  let (inset_x, inset_y) = @core.resolve_relative_inset_offsets(
    child_style.inset,
    cell_width,
    Some(cell_height),
  )
  (
    cell_x + final_margin_left + x_offset + inset_x,
    cell_y + final_margin_top + y_offset + inset_y,
    item_width,
    item_height,
  )
}

///|
/// Calculate the first baseline of a node
/// For blocks without children, baseline is at the bottom
/// For blocks with children, baseline is the first child's baseline
fn calculate_baseline(node : @node.Node, layout : @types.Layout) -> Double {
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
  layout : @types.Layout,
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
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = child.style

  // Handle display:none - return zero-sized layout
  if style.display == @types.Display::None {
    return @absolute.create_zero_layout(child.id)
  }

  // Determine the containing block (grid area) for the absolute item
  // If grid-column/row are specified, use those grid lines
  // Otherwise, use the padding box of the container

  // Resolve grid area boundaries (Grid-specific)
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

  // Use shared absolute module for size calculation
  let params = @absolute.compute_size_params(style, area_width, area_height)

  // Apply aspect ratio to calculate missing dimension
  let (width, height) = @types.resolve_dimensions_with_aspect_ratio(
    params.initial_width,
    params.initial_height,
    style.aspect_ratio,
    params.min_width,
    params.max_width,
    params.min_height,
    params.max_height,
  )

  // Compute intrinsic size if needed
  let (child_width, child_height, child_inner) = match (width, height) {
    (Some(w), Some(h)) => {
      let inner = compute_child_layout(child, w, h, dispatch)
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_child_layout(child, w, 1.0e10, dispatch)
      let h = match style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      let inner = compute_child_layout(child, 1.0e10, h, dispatch)
      let w = match style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => inner.width
      }
      (w, h, inner)
    }
    (None, None) => {
      let inner = compute_child_layout(child, 1.0e10, 1.0e10, dispatch)
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

  // Calculate actual min/max constraints, handling max-content/min-content
  let needs_intrinsic = match style.max_width {
    @types.MaxContent | @types.MinContent => true
    _ =>
      match style.max_height {
        @types.MaxContent | @types.MinContent => true
        _ =>
          match style.min_width {
            @types.MaxContent | @types.MinContent => true
            _ =>
              match style.min_height {
                @types.MaxContent | @types.MinContent => true
                _ => false
              }
          }
      }
  }
  let intrinsic_size = if needs_intrinsic {
    compute_child_layout(child, 1.0e10, 1.0e10, dispatch)
  } else {
    child_inner
  }
  let actual_min_width = match style.min_width {
    @types.MaxContent | @types.MinContent => intrinsic_size.width
    _ => params.min_width
  }
  let actual_max_width = match style.max_width {
    @types.MaxContent | @types.MinContent => intrinsic_size.width
    _ => params.max_width
  }
  let actual_min_height = match style.min_height {
    @types.MaxContent | @types.MinContent => intrinsic_size.height
    _ => params.min_height
  }
  let actual_max_height = match style.max_height {
    @types.MaxContent | @types.MinContent => intrinsic_size.height
    _ => params.max_height
  }

  // Apply min/max constraints and re-apply aspect ratio
  let (final_width, final_height) = @absolute.apply_constraints_with_aspect_ratio(
    child_width, child_height, style, actual_min_width, actual_max_width, actual_min_height,
    actual_max_height,
  )

  // Compute position using shared module
  let (base_x, base_y) = @absolute.compute_inset_position(
    params, final_width, final_height, area_left, area_top, area_width, area_height,
  )

  // Apply align-self/justify-self for absolute children when insets are not specified
  // Grid absolute children use align-self/justify-self for positioning within grid area
  let x = @core.compute_grid_absolute_self_position(
    style.justify_self,
    base_x,
    area_left,
    area_width,
    final_width,
    params.margin_right,
    params.inset_left is None,
    params.inset_right is None,
  )
  let y = @core.compute_grid_absolute_self_position(
    style.align_self,
    base_y,
    area_top,
    area_height,
    final_height,
    params.margin_bottom,
    params.inset_top is None,
    params.inset_bottom is None,
  )
  {
    id: child.id,
    x,
    y,
    width: final_width,
    height: final_height,
    margin: default_rect(),
    padding: default_rect(),
    border: default_rect(),
    overflow_x: child.style.overflow_x,
    overflow_y: child.style.overflow_y,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: child_inner.children,
    text: child.text,
  }
}

///|
/// Layout a fixed-position child (positioned relative to viewport)
fn layout_fixed_child(
  child : @node.Node,
  viewport_width : Double,
  viewport_height : Double,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = child.style

  // Handle display:none - return zero-sized layout
  if style.display == @types.Display::None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation with viewport as containing block
  let params = @absolute.compute_size_params(
    style, viewport_width, viewport_height,
  )

  // Apply aspect ratio to calculate missing dimension
  let (width, height) = @types.resolve_dimensions_with_aspect_ratio(
    params.initial_width,
    params.initial_height,
    style.aspect_ratio,
    params.min_width,
    params.max_width,
    params.min_height,
    params.max_height,
  )

  // Compute intrinsic size if needed
  let (child_width, child_height, child_inner) = match (width, height) {
    (Some(w), Some(h)) => {
      let inner = compute_child_layout(child, w, h, dispatch)
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_child_layout(child, w, 1.0e10, dispatch)
      let h = match style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      let inner = compute_child_layout(child, 1.0e10, h, dispatch)
      let w = match style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => inner.width
      }
      (w, h, inner)
    }
    (None, None) => {
      let inner = compute_child_layout(child, 1.0e10, 1.0e10, dispatch)
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

  // Calculate actual min/max constraints, handling max-content/min-content
  let needs_intrinsic = match style.max_width {
    @types.MaxContent | @types.MinContent => true
    _ =>
      match style.max_height {
        @types.MaxContent | @types.MinContent => true
        _ =>
          match style.min_width {
            @types.MaxContent | @types.MinContent => true
            _ =>
              match style.min_height {
                @types.MaxContent | @types.MinContent => true
                _ => false
              }
          }
      }
  }
  let intrinsic_size = if needs_intrinsic {
    compute_child_layout(child, 1.0e10, 1.0e10, dispatch)
  } else {
    child_inner
  }
  let actual_min_width = match style.min_width {
    @types.MaxContent | @types.MinContent => intrinsic_size.width
    _ => params.min_width
  }
  let actual_max_width = match style.max_width {
    @types.MaxContent | @types.MinContent => intrinsic_size.width
    _ => params.max_width
  }
  let actual_min_height = match style.min_height {
    @types.MaxContent | @types.MinContent => intrinsic_size.height
    _ => params.min_height
  }
  let actual_max_height = match style.max_height {
    @types.MaxContent | @types.MinContent => intrinsic_size.height
    _ => params.max_height
  }

  // Apply min/max constraints and re-apply aspect ratio
  let (final_width, final_height) = @absolute.apply_constraints_with_aspect_ratio(
    child_width, child_height, style, actual_min_width, actual_max_width, actual_min_height,
    actual_max_height,
  )

  // Compute position relative to viewport (0, 0)
  let (x, y) = @absolute.compute_inset_position(
    params, final_width, final_height, 0.0, 0.0, viewport_width, viewport_height,
  )
  {
    id: child.id,
    x,
    y,
    width: final_width,
    height: final_height,
    margin: default_rect(),
    padding: default_rect(),
    border: default_rect(),
    overflow_x: child.style.overflow_x,
    overflow_y: child.style.overflow_y,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: child_inner.children,
    text: child.text,
  }
}

///|
/// Resolve the horizontal grid area for an absolute item
fn resolve_absolute_grid_area_x(
  grid_column : @types.GridLine,
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
  grid_row : @types.GridLine,
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
  placement : @types.GridPlacement,
  offset : Int,
  explicit_count : Int,
) -> Int? {
  match placement {
    @types.GridPlacement::Auto => None
    @types.GridPlacement::Line(n) =>
      if n > 0 {
        Some(n - 1 + offset)
      } else if n < 0 {
        Some(explicit_count + 1 + n + offset)
      } else {
        Some(offset)
      }
    @types.GridPlacement::Span(_) => None // Span without explicit end defaults to Auto
  }
}
