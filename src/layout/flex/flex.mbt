// =============================================================================
// Flexbox Layout Implementation
// =============================================================================

///|
/// Layout with DOM index for sorting
priv struct IndexedLayout {
  dom_index : Int
  layout : @types.Layout
}

///|
/// Session-scoped cache for intrinsic size computation.
/// Key: (node_uid * 2 + is_row_flag)
/// This dramatically reduces redundant calculations in deep nesting.
priv struct IntrinsicCache {
  data : Map[Int, Double]
}

///|
fn IntrinsicCache::new() -> IntrinsicCache {
  { data: {} }
}

///|
/// Global intrinsic cache that persists across incremental layout updates.
/// This avoids recomputing intrinsic sizes for unchanged nodes.
let global_intrinsic_cache : Ref[Map[Int, Double]] = { val: {} }

///|
/// Clear intrinsic cache entries for a specific node.
/// Call this when a node is marked dirty.
pub fn clear_intrinsic_cache_for_node(uid : Int) -> Unit {
  let cache = global_intrinsic_cache.val
  // Clear both width and height entries (uid*2 and uid*2+1)
  cache.remove(uid * 2)
  cache.remove(uid * 2 + 1)
}

///|
/// Clear intrinsic cache for a node and all its descendants.
/// More efficient than clearing entries one by one.
pub fn clear_intrinsic_cache_for_subtree(node : @node.Node) -> Unit {
  clear_intrinsic_cache_for_node(node.uid)
  for child in node.children {
    clear_intrinsic_cache_for_subtree(child)
  }
}

///|
/// Reset the global intrinsic cache entirely.
/// Call this for a full re-layout.
pub fn reset_intrinsic_cache() -> Unit {
  global_intrinsic_cache.val = {}
}

// =============================================================================
// Resolved Style Cache
// =============================================================================

///|
/// Cached resolved rectangle values (padding, margin, border)
priv struct ResolvedRects {
  padding : @types.Rect[Double]
  margin : @types.Rect[Double]
  border : @types.Rect[Double]
}

///|
/// Global cache for resolved style values.
/// Key: node_uid * 1000000 + quantized_parent_width
/// This avoids repeated resolve_rect calls for the same node/width combination.
let global_resolved_cache : Ref[Map[Int, ResolvedRects]] = { val: {} }

///|
/// Quantize parent_width to reduce cache key variation
/// Uses 0.1px precision which is sufficient for layout
fn quantize_width(width : Double) -> Int {
  (width * 10.0).to_int()
}

///|
/// Get or compute resolved rects for a node's style
fn get_resolved_rects(
  style : @style.Style,
  node_uid : Int,
  parent_width : Double,
) -> ResolvedRects {
  let key = node_uid * 1000000 + quantize_width(parent_width)
  match global_resolved_cache.val.get(key) {
    Some(cached) => cached
    None => {
      let resolved : ResolvedRects = {
        padding: @types.resolve_rect(style.padding, parent_width),
        margin: @types.resolve_rect(style.margin, parent_width),
        border: @types.resolve_rect(style.border, parent_width),
      }
      global_resolved_cache.val.set(key, resolved)
      resolved
    }
  }
}

///|
/// Reset resolved style cache
pub fn reset_resolved_cache() -> Unit {
  global_resolved_cache.val = {}
}

///|
/// Resolve a dimension to pixels for intrinsic sizing
/// Percentages resolve to 0 in intrinsic sizing mode
fn resolve_dimension_intrinsic(dim : @types.Dimension) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(_) => 0.0
    @types.Auto => 0.0
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
  }
}

///|
/// Calculate max-content width of children for intrinsic sizing
/// This is used when min-width or max-width is max-content/min-content
fn calculate_children_max_content_width(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let mut max_content_width = 0.0
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      max_content_width = intrinsic.max_width
    }
    None => ()
  }
  for child in node.children {
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => continue
      @types.Float::None => ()
    }
    let child_style = child.style
    let child_margin_left = resolve_dimension_intrinsic(child_style.margin.left)
    let child_margin_right = resolve_dimension_intrinsic(
      child_style.margin.right,
    )
    let child_margin_sum = child_margin_left + child_margin_right
    let child_padding_left = resolve_dimension_intrinsic(
      child_style.padding.left,
    )
    let child_padding_right = resolve_dimension_intrinsic(
      child_style.padding.right,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_left +
      child_padding_right +
      child_border.horizontal_sum()
    let child_intrinsic_width : Double = match child_style.width {
      @types.Length(w) => @types.max(w, child_min_box)
      @types.Percent(_) => child_min_box
      @types.Auto =>
        match child.measure {
          Some(mf) => {
            let intrinsic = (mf.func)(0.0, 0.0)
            @types.max(intrinsic.max_width + child_min_box, child_min_box)
          }
          None =>
            calculate_children_max_content_width(child, parent_width) +
            child_min_box
        }
      @types.MaxContent | @types.MinContent =>
        calculate_children_max_content_width(child, parent_width) +
        child_min_box
      @types.FitContent(_) => child_min_box
    }
    let child_contribution = child_intrinsic_width + child_margin_sum
    if child_contribution > max_content_width {
      max_content_width = child_contribution
    }
  }
  max_content_width
}

///|
fn IntrinsicCache::get(
  self : IntrinsicCache,
  node_uid : Int,
  is_row : Bool,
) -> Double? {
  let key = node_uid * 2 + (if is_row { 1 } else { 0 })
  // Check session cache first, then global cache
  match self.data.get(key) {
    Some(v) => Some(v)
    None => global_intrinsic_cache.val.get(key)
  }
}

///|
fn IntrinsicCache::set(
  self : IntrinsicCache,
  node_uid : Int,
  is_row : Bool,
  value : Double,
) -> Unit {
  let key = node_uid * 2 + (if is_row { 1 } else { 0 })
  // Update both session and global cache
  self.data.set(key, value)
  global_intrinsic_cache.val.set(key, value)
}

// =============================================================================
// Display: Contents Support
// =============================================================================

///|
/// A flex item with tracking information for display: contents reconstruction
priv struct FlattenedChild {
  node : @node.Node
  /// Index of the immediate child of flex container (for DOM ordering)
  original_child_index : Int
  /// Path from the original child to this node (for display: contents)
  /// Empty for direct children, contains parent nodes for nested contents
  contents_ancestors : Array[@node.Node]
}

///|
/// Flatten children for flex layout, unwrapping display: contents nodes.
/// Returns an array of nodes that should be treated as flex items.
/// For display: contents elements, their children become flex items instead.
fn flatten_children_for_flex(node : @node.Node) -> Array[FlattenedChild] {
  let result : Array[FlattenedChild] = []
  let children = node.children
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    if child.style.display == @types.Contents {
      // This is a contents element - flatten its children
      flatten_children_recursive(child.children, i, [child], result)
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
/// Recursively flatten children, tracking contents ancestors for layout reconstruction
fn flatten_children_recursive(
  children : Array[@node.Node],
  original_index : Int,
  ancestors : Array[@node.Node],
  result : Array[FlattenedChild],
) -> Unit {
  for child in children {
    if child.style.display == @types.Contents {
      // This is a contents element - flatten its children instead
      // Add this node to the ancestors path
      let new_ancestors = ancestors.copy()
      new_ancestors.push(child)
      flatten_children_recursive(
        child.children,
        original_index,
        new_ancestors,
        result,
      )
    } else {
      // Regular child - add it as a flex item
      result.push({
        node: child,
        original_child_index: original_index,
        contents_ancestors: ancestors.copy(),
      })
    }
  }
}

///|
/// Create a zero-size layout for a display: contents element
fn create_contents_layout(
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
fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Compute measured cross size with proportional scaling for text-like content.
/// When the main dimension is constrained below max, the cross dimension scales proportionally.
/// This simulates text wrapping behavior where content area stays constant.
/// Parameters:
///   - intrinsic: The intrinsic size from MeasureFunc
///   - constrained_main: The actual constrained main dimension
///   - is_row: true = main is width, cross is height
fn compute_measured_cross_size(
  intrinsic : @types.IntrinsicSize,
  constrained_main : Double,
  is_row : Bool,
) -> Double {
  if is_row {
    // Computing height based on constrained width
    let max_width = intrinsic.max_width
    let max_height = intrinsic.max_height
    // Handle edge cases: unconstrained, no content, or zero/negative constraint
    if constrained_main >= max_width ||
      max_width <= 0.0 ||
      constrained_main <= 0.0 {
      max_height
    } else {
      // Proportional scaling: content area = max_width * max_height
      // new_height = area / constrained_width
      let area = max_width * max_height
      let scaled = area / constrained_main
      // Clamp to at least min_height
      max(intrinsic.min_height, scaled)
    }
  } else {
    // Computing width based on constrained height
    let max_width = intrinsic.max_width
    let max_height = intrinsic.max_height
    // Handle edge cases: unconstrained, no content, or zero/negative constraint
    if constrained_main >= max_height ||
      max_height <= 0.0 ||
      constrained_main <= 0.0 {
      max_width
    } else {
      // Proportional scaling
      let area = max_width * max_height
      let scaled = area / constrained_main
      max(intrinsic.min_width, scaled)
    }
  }
}

///|
/// Compute the intrinsic (content-based) size of a node on the main axis
/// This is used when flex-basis and main size are both Auto
fn compute_intrinsic_main_size(
  node : @node.Node,
  is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  // Check cache first (ignoring available_cross for simplicity)
  match cache.get(node.uid, is_row) {
    Some(cached) => return cached
    None => ()
  }
  let style = node.style
  let children = node.children

  // CSS Containment: contain: size makes intrinsic size 0 in both axes
  // contain: inline-size makes intrinsic size 0 only in inline (horizontal) axis
  // Note: padding and border are still included, only content contribution is 0
  if style.contain.size || (style.contain.inline_size && is_row) {
    let available_width = match available_cross {
      Some(w) if not(is_row) => w
      _ => 0.0
    }
    let padding = @types.resolve_rect(style.padding, available_width)
    let border = @types.resolve_rect(style.border, available_width)
    let result = if is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
    cache.set(node.uid, is_row, result)
    return result
  }

  // Leaf nodes: use MeasureFunc if available, otherwise 0
  let result = if children.length() == 0 {
    match node.measure {
      Some(mf) => {
        // Call MeasureFunc to get intrinsic size
        let intrinsic = (mf.func)(0.0, 0.0)
        // For measured nodes, apply proportional scaling when cross is constrained
        // This simulates text wrapping: when width is constrained, height increases proportionally
        if is_row {
          // Computing width - check if height is constrained
          match available_cross {
            Some(h) if h < intrinsic.max_height && intrinsic.max_height > 0.0 =>
              // Width scales proportionally when height is constrained
              compute_measured_cross_size(intrinsic, h, false)
            _ => intrinsic.max_width
          }
        } else {
          // Computing height - check if width is constrained
          match available_cross {
            Some(w) if w < intrinsic.max_width && intrinsic.max_width > 0.0 =>
              // Height scales proportionally when width is constrained
              compute_measured_cross_size(intrinsic, w, true)
            _ => intrinsic.max_height
          }
        }
      }
      None => 0.0
    }
  } else {
    // For containers, compute based on display type and children
    match style.display {
      @types.Flex =>
        compute_intrinsic_flex_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Block =>
        compute_intrinsic_block_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Grid | @types.InlineGrid =>
        compute_intrinsic_grid_main_size(
          node, is_row, available_cross, dispatch,
        )
      @types.Table | @types.InlineTable =>
        @table.compute_intrinsic_size(node, is_row)
      _ => 0.0
    }
  }

  // Cache the result for future lookups
  cache.set(node.uid, is_row, result)
  result
}

///|
/// Compute the min-content size of a node on the main axis
/// This is used for automatic minimum size calculation (min-width: auto / min-height: auto)
/// Unlike compute_intrinsic_main_size which returns max-content (full unwrapped width),
/// this returns min-content (longest unbreakable unit, e.g., longest word)
fn compute_min_content_main_size(
  node : @node.Node,
  is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children

  // CSS Containment: contain: size makes intrinsic size 0 in both axes
  // contain: inline-size makes intrinsic size 0 only in inline (horizontal) axis
  if style.contain.size || (style.contain.inline_size && is_row) {
    let available_width = match available_cross {
      Some(w) if not(is_row) => w
      _ => 0.0
    }
    let padding = @types.resolve_rect(style.padding, available_width)
    let border = @types.resolve_rect(style.border, available_width)
    return if is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
  }

  // Leaf nodes: use MeasureFunc if available, otherwise 0
  if children.length() == 0 {
    match node.measure {
      Some(mf) => {
        // Call MeasureFunc to get intrinsic size
        let intrinsic = (mf.func)(0.0, 0.0)
        // For min-content, return min_width (longest unbreakable unit)
        if is_row {
          intrinsic.min_width
        } else {
          // For height, min-content is the height at min_width
          let constrained = (mf.func)(intrinsic.min_width, 0.0)
          constrained.max_height
        }
      }
      None => 0.0
    }
  } else {
    // For containers, recursively compute min-content
    // Note: This is simplified - ideally we'd have separate min-content functions
    // for each display type, but for now we reuse the max-content functions
    // which gives us a conservative (larger) minimum
    match style.display {
      @types.Flex =>
        compute_min_content_flex_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      @types.Block =>
        compute_min_content_block_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
      _ =>
        // Fall back to max-content for other display types
        compute_intrinsic_main_size(
          node, is_row, available_cross, cache, dispatch,
        )
    }
  }
}

///|
/// Compute min-content size for a flex container
fn compute_min_content_flex_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children

  // Check if this flex container is row or column
  // Account for writing-mode: vertical modes swap row/column
  let is_vertical_writing = style.writing_mode.is_vertical()
  let direction_is_row = match style.flex_direction {
    @types.Row | @types.RowReverse => true
    @types.Column | @types.ColumnReverse => false
  }
  let child_is_row = if is_vertical_writing {
    not(direction_is_row)
  } else {
    direction_is_row
  }

  // Determine if we're computing along this container's main axis or cross axis
  let compute_main_axis = parent_is_row == child_is_row
  let child_available_width = if parent_is_row {
    match style.width {
      @types.Length(w) => w
      _ => 0.0
    }
  } else {
    match available_cross {
      Some(w) => w
      None =>
        match style.width {
          @types.Length(w) => w
          _ => 0.0
        }
    }
  }
  let padding = @types.resolve_rect(style.padding, child_available_width)
  let border = @types.resolve_rect(style.border, child_available_width)
  if compute_main_axis {
    // For min-content on main axis: sum of min-content sizes (no wrapping)
    let mut total_main = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        child_available_width,
      )
      let child_main = if child_is_row {
        match child_style.width {
          @types.Length(w) => w
          _ => compute_min_content_main_size(child, true, None, cache, dispatch)
        }
      } else {
        match child_style.height {
          @types.Length(h) => h
          _ =>
            compute_min_content_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            )
        }
      }
      let margin_main = if child_is_row {
        child_resolved.margin.left + child_resolved.margin.right
      } else {
        child_resolved.margin.top + child_resolved.margin.bottom
      }
      total_main = total_main + child_main + margin_main
    }
    let padding_border = if child_is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
    total_main + padding_border
  } else {
    // Cross axis: max of min-content sizes
    let mut max_cross = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        child_available_width,
      )
      let child_cross = if child_is_row {
        match child_style.height {
          @types.Length(h) => h
          _ =>
            compute_min_content_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            )
        }
      } else {
        match child_style.width {
          @types.Length(w) => w
          _ => compute_min_content_main_size(child, true, None, cache, dispatch)
        }
      }
      let margin_cross = if child_is_row {
        child_resolved.margin.top + child_resolved.margin.bottom
      } else {
        child_resolved.margin.left + child_resolved.margin.right
      }
      max_cross = max(max_cross, child_cross + margin_cross)
    }
    let padding_border_cross = if parent_is_row {
      padding.horizontal_sum() + border.horizontal_sum()
    } else {
      padding.vertical_sum() + border.vertical_sum()
    }
    max_cross + padding_border_cross
  }
}

///|
/// Compute min-content size for a block container
fn compute_min_content_block_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children
  let available_width = match available_cross {
    Some(w) if not(parent_is_row) => w
    _ =>
      match style.width {
        @types.Length(w) => w
        _ => 0.0
      }
  }
  let padding = @types.resolve_rect(style.padding, available_width)
  let border = @types.resolve_rect(style.border, available_width)
  if parent_is_row {
    // Compute min-content width: max of children's min-content widths
    let mut max_width = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        available_width,
      )
      let child_width = match child_style.width {
        @types.Length(w) =>
          w + child_resolved.margin.left + child_resolved.margin.right
        _ =>
          compute_min_content_main_size(child, true, None, cache, dispatch) +
          child_resolved.margin.left +
          child_resolved.margin.right
      }
      max_width = max(max_width, child_width)
    }
    max_width + padding.left + padding.right + border.left + border.right
  } else {
    // Compute min-content height: sum of children's heights
    let mut total_height = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        available_width,
      )
      let child_height = match child_style.height {
        @types.Length(h) => h
        _ =>
          compute_min_content_main_size(
            child,
            false,
            Some(available_width),
            cache,
            dispatch,
          )
      }
      total_height = total_height +
        child_height +
        child_resolved.margin.top +
        child_resolved.margin.bottom
    }
    total_height + padding.top + padding.bottom + border.top + border.bottom
  }
}

///|
/// Compute intrinsic size for a flex container
/// parent_is_row: true = compute width, false = compute height
fn compute_intrinsic_flex_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children

  // Check if this flex container is row or column
  // Account for writing-mode: vertical modes swap row/column
  let is_vertical_writing = style.writing_mode.is_vertical()
  let direction_is_row = match style.flex_direction {
    @types.Row | @types.RowReverse => true
    @types.Column | @types.ColumnReverse => false
  }
  let child_is_row = if is_vertical_writing {
    not(direction_is_row)
  } else {
    direction_is_row
  }

  // Determine if we're computing along this container's main axis or cross axis
  // parent_is_row = true means we want WIDTH
  // parent_is_row = false means we want HEIGHT
  // child_is_row = true means container's main axis is WIDTH, cross is HEIGHT
  // child_is_row = false means container's main axis is HEIGHT, cross is WIDTH
  let compute_main_axis = parent_is_row == child_is_row

  // For the child flex container, compute available width for resolving percentages
  let child_available_width = if parent_is_row {
    match style.width {
      @types.Length(w) => w
      _ => 0.0
    }
  } else {
    match available_cross {
      Some(w) => w
      None =>
        match style.width {
          @types.Length(w) => w
          _ => 0.0
        }
    }
  }
  let padding = @types.resolve_rect(style.padding, child_available_width)
  let border = @types.resolve_rect(style.border, child_available_width)
  if compute_main_axis {
    // Computing along this container's main axis: sum children's sizes
    let main_gap = if child_is_row {
      style.column_gap.resolve_or(child_available_width, 0.0)
    } else {
      style.row_gap.resolve_or(0.0, 0.0)
    }
    let mut total_main = 0.0
    let mut item_count = 0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects for all child box model values
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        child_available_width,
      )
      let child_margin = child_resolved.margin
      let child_padding = child_resolved.padding
      let child_border = child_resolved.border
      let child_min_width = child_padding.horizontal_sum() +
        child_border.horizontal_sum()
      let child_min_height = child_padding.vertical_sum() +
        child_border.vertical_sum()
      let child_main = if child_is_row {
        // Main axis is width
        let base_width = match child_style.width {
          @types.Length(w) => w
          @types.Percent(p) => child_available_width * p
          @types.Auto =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch)
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch)
        }
        let effective_width = if base_width < child_min_width {
          child_min_width
        } else {
          base_width
        }
        effective_width + child_margin.left + child_margin.right
      } else {
        // Main axis is height
        let base_height = match child_style.height {
          @types.Length(h) => h
          @types.Percent(_) => 0.0
          @types.Auto =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            )
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            )
        }
        let effective_height = if base_height < child_min_height {
          child_min_height
        } else {
          base_height
        }
        effective_height + child_margin.top + child_margin.bottom
      }
      total_main = total_main + child_main
      item_count = item_count + 1
    }
    if item_count > 1 {
      total_main = total_main + main_gap * (item_count - 1).to_double()
    }
    if child_is_row {
      total_main + padding.left + padding.right + border.left + border.right
    } else {
      total_main + padding.top + padding.bottom + border.top + border.bottom
    }
  } else {
    // Computing along this container's cross axis
    // For wrap containers, we need to account for multiple lines
    let is_wrap = match style.flex_wrap {
      @types.Wrap | @types.WrapReverse => true
      _ => false
    }

    // Determine available main size for line breaking
    // For percentage widths, we need to resolve against available_cross
    let available_main : Double? = if is_wrap {
      if child_is_row {
        // Row wrap: main is width
        // Use resolved width if explicit, otherwise available_cross
        match style.width {
          @types.Length(w) => Some(w)
          @types.Percent(p) =>
            match available_cross {
              Some(ac) => Some(ac * p)
              None => None
            }
          @types.Auto => available_cross
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            available_cross
        }
      } else {
        // Column wrap: main is height, available from available_cross parameter
        // But for column containers, we typically don't have available height
        None
      }
    } else {
      None
    }

    // Get gap for line breaking calculation
    let main_gap = if child_is_row {
      style.column_gap.resolve_or(child_available_width, 0.0)
    } else {
      style.row_gap.resolve_or(0.0, 0.0)
    }

    // Collect items with their sizes
    let items : Array[(Double, Double)] = [] // (main_size, cross_size)
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        child_available_width,
      )
      let child_margin = child_resolved.margin
      let (child_main, child_cross) = if child_is_row {
        // Main is width, cross is height
        let main = match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          @types.Percent(p) =>
            child_available_width * p + child_margin.left + child_margin.right
          @types.Auto =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
        }
        let cross = match child_style.height {
          @types.Length(h) => h + child_margin.top + child_margin.bottom
          @types.Percent(_) => child_margin.top + child_margin.bottom
          @types.Auto =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
        }
        (main, cross)
      } else {
        // Main is height, cross is width
        let main = match child_style.height {
          @types.Length(h) => h + child_margin.top + child_margin.bottom
          @types.Percent(_) => child_margin.top + child_margin.bottom
          @types.Auto =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(
              child,
              false,
              Some(child_available_width),
              cache,
              dispatch,
            ) +
            child_margin.top +
            child_margin.bottom
        }
        let cross = match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          @types.Percent(p) =>
            child_available_width * p + child_margin.left + child_margin.right
          @types.Auto =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            compute_intrinsic_main_size(child, true, None, cache, dispatch) +
            child_margin.left +
            child_margin.right
        }
        (main, cross)
      }
      items.push((child_main, child_cross))
    }

    // Calculate total cross size
    let total_cross = match available_main {
      Some(avail) if is_wrap && avail > 0.0 => {
        // Wrap: distribute items into lines
        let lines_cross : Array[Double] = []
        let mut line_main = 0.0
        let mut line_max_cross = 0.0
        let mut line_item_count = 0
        for i = 0; i < items.length(); i = i + 1 {
          let (item_main, item_cross) = items[i]
          // Check if adding this item would exceed available main
          let needed = if line_item_count > 0 {
            line_main + main_gap + item_main
          } else {
            item_main
          }
          if line_item_count > 0 && needed > avail {
            // Start new line
            lines_cross.push(line_max_cross)
            line_main = item_main
            line_max_cross = item_cross
            line_item_count = 1
          } else {
            // Add to current line
            line_main = needed
            if item_cross > line_max_cross {
              line_max_cross = item_cross
            }
            line_item_count = line_item_count + 1
          }
        }
        // Add last line
        if line_item_count > 0 {
          lines_cross.push(line_max_cross)
        }
        // Sum all lines
        let mut sum = 0.0
        for line_cross in lines_cross {
          sum = sum + line_cross
        }
        sum
      }
      _ => {
        // No wrap or no available main: max of all cross sizes
        let mut max_cross = 0.0
        for i = 0; i < items.length(); i = i + 1 {
          let (_, item_cross) = items[i]
          if item_cross > max_cross {
            max_cross = item_cross
          }
        }
        max_cross
      }
    }

    // Add padding and border on cross axis
    if child_is_row {
      total_cross + padding.top + padding.bottom + border.top + border.bottom
    } else {
      total_cross + padding.left + padding.right + border.left + border.right
    }
  }
}

///|
/// Compute intrinsic main size for a grid container
fn compute_intrinsic_grid_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  dispatch : @node.DispatchFn,
) -> Double {
  // Use the layout dispatcher to compute Grid layout and get its size
  // For Grid containers as flex items, we need to compute actual layout
  // to determine intrinsic size
  let available_width = if parent_is_row {
    // Computing width - use max-content (large available)
    1.0e10
  } else {
    // Computing height - use available cross as width if provided
    match available_cross {
      Some(w) => w
      None => 1.0e10
    }
  }
  let available_height = if parent_is_row {
    // Computing width - height comes from available_cross
    available_cross
  } else {
    // Computing height - use max-content
    None
  }
  let ctx : @types.LayoutContext = {
    available_width,
    available_height,
    sizing_mode: @types.MaxContent,
    viewport_width: available_width,
    viewport_height: available_height.unwrap_or(0.0),
    stretch_width: false,
    stretch_height: false,
  }
  let @node.DispatchFn(dispatch_fn) = dispatch
  let layout = dispatch_fn(node, ctx, dispatch)
  if parent_is_row {
    layout.width
  } else {
    layout.height
  }
}

///|
/// Compute intrinsic size for a block container
fn compute_intrinsic_block_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> Double {
  let style = node.style
  let children = node.children
  let available_width = match available_cross {
    Some(w) if not(parent_is_row) => w
    _ =>
      match style.width {
        @types.Length(w) => w
        _ => 0.0
      }
  }
  let padding = @types.resolve_rect(style.padding, available_width)
  let border = @types.resolve_rect(style.border, available_width)

  // For block layout, if parent is row, intrinsic width is max of children's widths
  // If parent is column, intrinsic height is sum of children's heights
  if parent_is_row {
    // Compute intrinsic width
    let mut max_width = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        available_width,
      )
      let child_margin = child_resolved.margin
      let child_width = match child_style.width {
        @types.Length(w) => w + child_margin.left + child_margin.right
        _ =>
          compute_intrinsic_main_size(child, true, None, cache, dispatch) +
          child_margin.left +
          child_margin.right
      }
      max_width = max(max_width, child_width)
    }
    max_width + padding.left + padding.right + border.left + border.right
  } else {
    // Compute intrinsic height
    let mut total_height = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @types.Display::None {
        continue
      }
      if child_style.position == @types.Absolute ||
        child_style.position == @types.Fixed {
        continue
      }
      // Use cached resolved rects
      let child_resolved = get_resolved_rects(
        child_style,
        child.uid,
        available_width,
      )
      let child_margin = child_resolved.margin
      let child_height = match child_style.height {
        @types.Length(h) => h + child_margin.top + child_margin.bottom
        _ =>
          compute_intrinsic_main_size(
            child,
            false,
            Some(available_width),
            cache,
            dispatch,
          ) +
          child_margin.top +
          child_margin.bottom
      }
      total_height = total_height + child_height
    }
    total_height + padding.top + padding.bottom + border.top + border.bottom
  }
}

///|
/// Create a zero-sized layout for display: none elements.
/// Recursively creates zero-sized layouts for all children.
fn create_hidden_layout(node : @node.Node) -> @types.Layout {
  let children : Array[@types.Layout] = []
  for child in node.children {
    children.push(create_hidden_layout(child))
  }
  let zero_rect : @types.Rect[Double] = {
    top: 0.0,
    right: 0.0,
    bottom: 0.0,
    left: 0.0,
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    children,
    text: None,
  }
}

///|
/// Compute flex layout for a node and its children
pub fn compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let warnings : Array[@types.LayoutWarning] = []
  let cache = IntrinsicCache::new()
  compute_internal(node, ctx, warnings, cache, dispatch)
}

///|
/// Compute flex layout for root-level containers
/// Root flex containers with width:auto use content-based sizing (taffy behavior)
pub fn compute_root(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let warnings : Array[@types.LayoutWarning] = []
  let cache = IntrinsicCache::new()
  compute_internal(node, ctx, warnings, cache, dispatch, is_root=true)
}

///|
/// Compute flex layout with warnings
pub fn compute_with_warnings(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.LayoutResult {
  let warnings : Array[@types.LayoutWarning] = []
  let cache = IntrinsicCache::new()
  let layout = compute_internal(node, ctx, warnings, cache, dispatch)
  { layout, warnings }
}

///|
/// Result of traced layout computation
pub(all) struct TracedLayoutResult {
  layout : @types.Layout
  warnings : Array[@types.LayoutWarning]
  tracer : @trace.LayoutTracer
}

///|
/// Compute flex layout with dependency tracing for incremental layout optimization.
/// The tracer records input/output for each node, enabling future differential recalculation.
pub fn compute_with_trace(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> TracedLayoutResult {
  let warnings : Array[@types.LayoutWarning] = []
  let cache = IntrinsicCache::new()
  let tracer = @trace.LayoutTracer::new(true)
  // Perform layout computation
  let layout = compute_internal(node, ctx, warnings, cache, dispatch)
  // Collect traces by walking the result tree
  tracer.collect_from_tree(node, layout, ctx)
  { layout, warnings, tracer }
}

///|
fn compute_internal(
  node : @node.Node,
  ctx : @types.LayoutContext,
  warnings : Array[@types.LayoutWarning],
  cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
  is_root? : Bool = false,
) -> @types.Layout {
  let style = node.style

  // Handle display: none - return zero-sized layout with zero-sized children
  if style.display == @types.Display::None {
    return create_hidden_layout(node)
  }

  // Check for unsupported features
  match style.float {
    @types.Float::Left | @types.Float::Right =>
      warnings.push(@types.UnsupportedFloat(node.id))
    @types.Float::None => ()
  }
  let parent_width = ctx.available_width
  let parent_height = ctx.available_height.unwrap_or(0.0)

  // Resolve box model
  let margin = @types.resolve_rect(style.margin, parent_width)
  let padding = @types.resolve_rect(style.padding, parent_width)
  let border = @types.resolve_rect(style.border, parent_width)

  // Container size
  let width_is_auto = match style.width {
    @types.Auto => true
    _ => false
  }
  let height_is_auto = match style.height {
    @types.Auto => true
    _ => false
  }

  // For MaxContent sizing with auto size, check for MeasureFunc (leaf node with intrinsic size)
  // This applies when we have a flex container with no children but a MeasureFunc
  let intrinsic_from_measure : (Double, Double)? = match
    (
      ctx.sizing_mode,
      width_is_auto || height_is_auto,
      node.measure,
      node.children.length(),
    ) {
    (@types.MaxContent, true, Some(mf), 0) => {
      // Leaf flex node with MeasureFunc - use intrinsic size
      let intrinsic = (mf.func)(parent_width, parent_height)
      Some(
        (
          intrinsic.max_width +
          padding.horizontal_sum() +
          border.horizontal_sum(),
          intrinsic.max_height + padding.vertical_sum() + border.vertical_sum(),
        ),
      )
    }
    _ => None
  }
  // Check if this is a block-level flex container (Flex) vs inline-level (InlineFlex)
  let is_block_level = style.display == @types.Flex
  let mut container_width = match intrinsic_from_measure {
    Some((w, _)) => w
    None =>
      match style.width {
        @types.Length(w) => w
        @types.Percent(p) => parent_width * p
        @types.Auto =>
          match ctx.sizing_mode {
            // Block-level flex containers with width:auto should fill available width minus margins
            // Inline-level flex (InlineFlex) should use content-based sizing
            // Root-level flex should use content-based sizing (taffy behavior)
            @types.Definite =>
              if is_block_level && not(is_root) {
                let fill_width = parent_width - margin.horizontal_sum()
                let min_width = padding.horizontal_sum() +
                  border.horizontal_sum()
                if fill_width >= min_width {
                  fill_width
                } else if node.children.length() > 0 {
                  // When fill calculation would result in width < min,
                  // parent_width is likely the final content size (not available space).
                  // Use intrinsic sizing instead.
                  compute_intrinsic_main_size(
                    node,
                    true,
                    ctx.available_height,
                    cache,
                    dispatch,
                  )
                } else {
                  min_width
                }
                // InlineFlex or root Flex: use content-based sizing
              } else if node.children.length() > 0 {
                compute_intrinsic_main_size(
                  node,
                  true,
                  ctx.available_height,
                  cache,
                  dispatch,
                )
              } else {
                padding.horizontal_sum() + border.horizontal_sum()
              }
            @types.MaxContent =>
              // For MaxContent, compute intrinsic width
              if node.children.length() > 0 {
                // Use compute_intrinsic_main_size to get max-content width
                // Note: compute_intrinsic_flex_main_size already includes padding/border
                compute_intrinsic_main_size(
                  node,
                  true,
                  ctx.available_height,
                  cache,
                  dispatch,
                )
              } else {
                // Leaf node with no children: intrinsic size is padding + border
                // (MeasureFunc case is handled by intrinsic_from_measure above)
                padding.horizontal_sum() + border.horizontal_sum()
              }
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          // For intrinsic sizing keywords, compute intrinsic width
          if node.children.length() > 0 {
            compute_intrinsic_main_size(
              node,
              true,
              ctx.available_height,
              cache,
              dispatch,
            )
          } else {
            padding.horizontal_sum() + border.horizontal_sum()
          }
      }
  }

  // Apply min/max width
  // CSS spec: min-width takes precedence over max-width when they conflict
  // So apply max first, then min
  match style.max_width {
    @types.Length(v) => if container_width > v { container_width = v }
    @types.Percent(p) => {
      let v = parent_width * p
      if container_width > v {
        container_width = v
      }
    }
    @types.Auto => ()
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => ()
  }
  // CSS spec: padding + border is always the absolute minimum
  let padding_border_width = padding.horizontal_sum() + border.horizontal_sum()
  match style.min_width {
    @types.Length(v) => {
      let effective_min = max(v, padding_border_width)
      if container_width < effective_min {
        container_width = effective_min
      }
    }
    @types.Percent(p) => {
      let v = parent_width * p
      let effective_min = max(v, padding_border_width)
      if container_width < effective_min {
        container_width = effective_min
      }
    }
    @types.Auto =>
      if container_width < padding_border_width {
        container_width = padding_border_width
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      if container_width < padding_border_width {
        container_width = padding_border_width
      }
  }

  // Content area
  let content_width = container_width -
    padding.horizontal_sum() -
    border.horizontal_sum()
  // For Definite sizing mode with auto height, use available_height if provided
  // This handles stretched flex items whose height is determined by the parent
  // BUT: avoid using very large values (1e9+) which are used as "infinity" for intrinsic sizing
  // When available_height is provided in Definite mode, it represents the final constrained size
  // (e.g., max-height was already applied by parent), so we should respect it.
  let content_height : Double? = match intrinsic_from_measure {
    Some((_, h)) => Some(h - padding.vertical_sum() - border.vertical_sum())
    None =>
      match style.height {
        @types.Length(h) => {
          let mut height = h
          // In Definite mode, available_height may represent a constrained size (e.g., max-height applied)
          // If available_height is smaller than explicit height, use available_height
          match (ctx.sizing_mode, ctx.available_height) {
            (@types.Definite, Some(ah)) if ah < 1.0e9 && ah < h => height = ah
            _ => ()
          }
          Some(height - padding.vertical_sum() - border.vertical_sum())
        }
        @types.Percent(p) =>
          Some(
            parent_height * p - padding.vertical_sum() - border.vertical_sum(),
          )
        @types.Auto =>
          // In Definite mode with available_height, use it for stretched items
          // But only if it's not an "infinity" placeholder (< 1e9)
          match (ctx.sizing_mode, ctx.available_height) {
            (@types.Definite, Some(ah)) if ah < 1.0e9 =>
              Some(ah - padding.vertical_sum() - border.vertical_sum())
            _ => None
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
      }
  }

  // Determine main/cross axis based on flex-direction
  // In vertical writing mode, row and column are effectively swapped:
  // - flex-direction: row flows vertically (like column in horizontal-tb)
  // - flex-direction: column flows horizontally (like row in horizontal-tb)
  let is_vertical_writing = style.writing_mode.is_vertical()
  let is_block_rtl = style.writing_mode.is_block_rtl()
  let direction_is_row = match style.flex_direction {
    @types.Row | @types.RowReverse => true
    @types.Column | @types.ColumnReverse => false
  }
  // XOR with vertical writing mode to get effective axis
  let is_row = if is_vertical_writing {
    not(direction_is_row)
  } else {
    direction_is_row
  }
  // Determine if flex items should be reversed
  // For row direction with direction: rtl, the inline base direction is reversed
  let direction_reverse = match style.flex_direction {
    @types.RowReverse | @types.ColumnReverse => true
    _ => false
  }
  // RTL affects only row direction (inline axis)
  let is_rtl = style.direction.is_rtl()
  let is_reverse = if direction_is_row && is_rtl {
    // RTL + row = reverse, RTL + row-reverse = normal (double negative)
    not(direction_reverse)
  } else {
    direction_reverse
  }

  // For main size, if container size is auto, we need special handling
  // min-height should only cause GROW (not SHRINK) when content < min
  // Get initial values (may be adjusted later for Column flex with min_height)
  // For MaxContent/MinContent sizing, main size is NOT defined for auto-sized containers
  // (flex-grow/shrink should not be applied during intrinsic sizing)
  let is_intrinsic_sizing = match ctx.sizing_mode {
    @types.MaxContent => true
    _ => false
  }
  // For column flex wrap, we need to consider max-height even when height is auto
  // This allows items to wrap when they exceed the max-height constraint
  let max_height_for_wrap : Double? = if not(is_row) && content_height == None {
    match style.max_height {
      @types.Length(mh) =>
        Some(mh - padding.vertical_sum() - border.vertical_sum())
      @types.Percent(p) =>
        Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
      @types.Auto => None
      @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
    }
  } else {
    None
  }
  let initial_main_size_defined = if is_row {
    // Row flex: main size is defined unless we're doing intrinsic sizing with auto width
    not(is_intrinsic_sizing && width_is_auto)
  } else {
    // Column flex: main size is defined if height is explicit OR max-height is set (for wrap)
    content_height != None || max_height_for_wrap != None
  }
  let initial_main_size = if is_row {
    content_width
  } else {
    match content_height {
      Some(ch) => ch
      None =>
        // For wrap mode, use max-height as the line breaking constraint
        match max_height_for_wrap {
          Some(mh) => mh
          None => 0.0
        }
    }
  }

  // Get min_main for flex grow/justify-content adjustment
  // For Row flex: use min_width when width is auto
  // For Column flex: use min_height when height is auto
  let min_main_for_grow : Double? = if is_row {
    // Row flex: check min_width when width is auto
    if width_is_auto {
      match style.min_width {
        @types.Length(min_w) =>
          Some(min_w - padding.horizontal_sum() - border.horizontal_sum())
        @types.Percent(p) =>
          Some(
            parent_width * p -
            padding.horizontal_sum() -
            border.horizontal_sum(),
          )
        @types.Auto => None
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
      }
    } else {
      None
    }
    // Column flex: check min_height when height is auto
  } else if content_height == None {
    match style.min_height {
      @types.Length(min_h) =>
        Some(min_h - padding.vertical_sum() - border.vertical_sum())
      @types.Percent(p) =>
        Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
      @types.Auto => None
      @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
    }
  } else {
    None
  }
  let cross_size = if is_row { content_height } else { Some(content_width) }

  // Resolve gap values
  let main_gap = if is_row {
    style.column_gap.resolve_or(content_width, 0.0)
  } else {
    style.row_gap.resolve_or(parent_height, 0.0)
  }
  let cross_gap = if is_row {
    style.row_gap.resolve_or(parent_height, 0.0)
  } else {
    style.column_gap.resolve_or(content_width, 0.0)
  }
  // cross_gap will be used for wrap scenarios

  // Phase 1: Calculate base sizes for each child
  // Flatten children for display: contents support
  let flattened = flatten_children_for_flex(node)
  let children = node.children
  let child_count = children.length()
  if flattened.length() == 0 && child_count == 0 {
    // No children - just return container with intrinsic size if available
    let container_height = match intrinsic_from_measure {
      Some((_, h)) => h
      None =>
        match style.height {
          @types.Length(h) => h
          @types.Percent(p) => parent_height * p
          @types.Auto => padding.vertical_sum() + border.vertical_sum()
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            padding.vertical_sum() + border.vertical_sum()
        }
    }
    return {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width: container_width,
      height: container_height,
      margin,
      padding,
      border,
      overflow_x: style.overflow_x,
      overflow_y: style.overflow_y,
      children: [],
      text: node.text,
    }
  }

  // Collect flex items info (skip display:none children)
  // Use flattened children which expands display:contents elements
  let flex_items : Array[FlexItem] = Array::new(capacity=flattened.length())
  let mut total_flex_grow = 0.0
  let mut total_flex_shrink = 0.0
  let mut total_base_main = 0.0
  for i = 0; i < flattened.length(); i = i + 1 {
    let flat_child = flattened[i]
    let child = flat_child.node
    let child_style = child.style

    // Skip display:none children
    if child_style.display == @types.Display::None {
      continue
    }

    // Skip absolutely positioned children (they don't participate in flex layout)
    if child_style.position == @types.Absolute ||
      child_style.position == @types.Fixed {
      continue
    }
    // Use cached resolved rects for margin
    let child_resolved = get_resolved_rects(
      child_style,
      child.uid,
      content_width,
    )
    let child_margin = child_resolved.margin

    // Get explicit cross dimension value for aspect_ratio calculation
    // Only compute this when aspect_ratio is set (optimization: skip for common case)
    // When cross dimension is auto but has a min constraint, use the min value
    // for aspect-ratio calculation (combined with intrinsic size if available)
    let explicit_cross : Double? = match child_style.aspect_ratio {
      None => None // Fast path: skip expensive computation when aspect_ratio not set
      Some(_) =>
        if is_row {
          match child_style.height {
            @types.Length(h) => Some(h)
            @types.Percent(p) =>
              match content_height {
                Some(ch) => Some(ch * p)
                None => None
              }
            @types.Auto => {
              // Get intrinsic height from MeasureFunc if available
              let intrinsic_h = match child.measure {
                Some(mf) => {
                  let intrinsic = (mf.func)(content_width, 0.0)
                  intrinsic.max_height
                }
                None => 0.0
              }
              // Apply min/max constraints for aspect-ratio calculation
              let min_h = match child_style.min_height {
                @types.Length(h) => h
                @types.Percent(p) =>
                  match content_height {
                    Some(ch) => ch * p
                    None => 0.0
                  }
                _ => 0.0
              }
              let max_h = match child_style.max_height {
                @types.Length(h) => h
                @types.Percent(p) =>
                  match content_height {
                    Some(ch) => ch * p
                    None => @double.infinity
                  }
                _ => @double.infinity
              }
              // If max_height is set and less than intrinsic, use constrained value
              if max_h < @double.infinity || min_h > 0.0 {
                let constrained = @types.clamp(intrinsic_h, min_h, max_h)
                Some(constrained)
              } else {
                None
              }
            }
            @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
          }
        } else {
          match child_style.width {
            @types.Length(w) => Some(w)
            @types.Percent(p) => Some(content_width * p)
            @types.Auto => {
              // Get intrinsic width from MeasureFunc if available
              let intrinsic_w = match child.measure {
                Some(mf) => {
                  let intrinsic = (mf.func)(0.0, 0.0)
                  intrinsic.max_width
                }
                None => 0.0
              }
              // Apply min/max constraints for aspect-ratio calculation
              let min_w = match child_style.min_width {
                @types.Length(w) => w
                @types.Percent(p) => content_width * p
                _ => 0.0
              }
              let max_w = match child_style.max_width {
                @types.Length(w) => w
                @types.Percent(p) => content_width * p
                _ => @double.infinity
              }
              // If max_width is set and less than intrinsic, use constrained value
              if max_w < @double.infinity || min_w > 0.0 {
                let constrained = @types.clamp(intrinsic_w, min_w, max_w)
                Some(constrained)
              } else {
                None
              }
            }
            @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
          }
        }
    }

    // Calculate base size on main axis (flex-basis takes priority over width/height)
    // CSS spec: If flex-basis is a percentage of an indefinite size, it resolves
    // to content size (as if flex-basis: content was specified)
    let base_main = match child_style.flex_basis {
      @types.Length(b) => b
      @types.Percent(p) =>
        if is_row {
          content_width * p
        } else {
          match content_height {
            Some(ch) => ch * p
            None => {
              // Percentage of indefinite dimension resolves to content size
              // Compute intrinsic height from children
              let available_cross_for_child = content_width -
                child_margin.left -
                child_margin.right
              compute_intrinsic_main_size(
                child,
                false,
                Some(available_cross_for_child),
                cache,
                dispatch,
              )
            }
          }
        }
      @types.Auto =>
        if is_row {
          match child_style.width {
            @types.Length(w) => w
            @types.Percent(p) => content_width * p
            @types.Auto =>
              // Try to use aspect_ratio if cross dimension is known
              match (child_style.aspect_ratio, explicit_cross) {
                (Some(ratio), Some(cross_val)) => cross_val * ratio
                _ => {
                  // For wrap containers, use available main size as their main size
                  // CSS spec: wrap containers use definite available main size for layout
                  let is_wrap = match child_style.flex_wrap {
                    @types.Wrap | @types.WrapReverse => true
                    _ => false
                  }
                  let is_row_flex = match child_style.flex_direction {
                    @types.Row | @types.RowReverse => true
                    _ => false
                  }
                  // Note: Check for wrap/direction regardless of explicit display
                  if is_wrap && is_row_flex {
                    content_width // Use available width for row wrap container
                  } else {
                    // Compute intrinsic width from children
                    compute_intrinsic_main_size(
                      child, true, content_height, cache, dispatch,
                    )
                  }
                }
              }
            @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
              compute_intrinsic_main_size(
                child, true, content_height, cache, dispatch,
              )
          }
        } else {
          match child_style.height {
            @types.Length(h) => h
            @types.Percent(p) =>
              match content_height {
                Some(ch) => ch * p
                None => 0.0
              }
            @types.Auto =>
              // Try to use aspect_ratio if cross dimension is known
              match (child_style.aspect_ratio, explicit_cross) {
                (Some(ratio), Some(cross_val)) => cross_val / ratio
                _ => {
                  // For wrap containers, use available main size
                  let is_wrap = match child_style.flex_wrap {
                    @types.Wrap | @types.WrapReverse => true
                    _ => false
                  }
                  let is_col_flex = match child_style.flex_direction {
                    @types.Column | @types.ColumnReverse => true
                    _ => false
                  }
                  // Note: Check for wrap/direction regardless of explicit display
                  match content_height {
                    Some(ch) if is_wrap && is_col_flex => ch // Use available height for column wrap container
                    _ => {
                      // Compute intrinsic height from children
                      // For Column flex, the child's width is constrained by available cross space minus margin
                      let available_cross_for_child = content_width -
                        child_margin.left -
                        child_margin.right
                      compute_intrinsic_main_size(
                        child,
                        false,
                        Some(available_cross_for_child),
                        cache,
                        dispatch,
                      )
                    }
                  }
                }
              }
            @types.MinContent | @types.MaxContent | @types.FitContent(_) => {
              let available_cross_for_child = content_width -
                child_margin.left -
                child_margin.right
              compute_intrinsic_main_size(
                child,
                false,
                Some(available_cross_for_child),
                cache,
                dispatch,
              )
            }
          }
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        if is_row {
          compute_intrinsic_main_size(
            child, true, content_height, cache, dispatch,
          )
        } else {
          let available_cross_for_child = content_width -
            child_margin.left -
            child_margin.right
          compute_intrinsic_main_size(
            child,
            false,
            Some(available_cross_for_child),
            cache,
            dispatch,
          )
        }
    }

    // Get explicit main dimension value for aspect_ratio calculation on cross axis
    let explicit_main : Double? = if is_row {
      match child_style.flex_basis {
        @types.Length(b) => Some(b)
        @types.Percent(p) => Some(content_width * p)
        @types.Auto =>
          match child_style.width {
            @types.Length(w) => Some(w)
            @types.Percent(p) => Some(content_width * p)
            @types.Auto => None
            @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
      }
    } else {
      match child_style.flex_basis {
        @types.Length(b) => Some(b)
        @types.Percent(p) =>
          match content_height {
            Some(ch) => Some(ch * p)
            None => None
          }
        @types.Auto =>
          match child_style.height {
            @types.Length(h) => Some(h)
            @types.Percent(p) =>
              match content_height {
                Some(ch) => Some(ch * p)
                None => None
              }
            @types.Auto => None
            @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => None
      }
    }

    // Calculate size on cross axis
    // cross_is_auto indicates whether the cross style dimension is Auto
    // (this is used for stretch behavior - stretch only applies to Auto dimensions)
    let (base_cross, cross_is_auto) = if is_row {
      match child_style.height {
        @types.Length(h) => (h, false)
        @types.Percent(p) =>
          match content_height {
            Some(ch) => (ch * p, false)
            None => (0.0, false)
          }
        @types.Auto =>
          // Try to use aspect_ratio if main dimension is known
          // Otherwise compute intrinsic height from children
          match (child_style.aspect_ratio, explicit_main) {
            (Some(ratio), Some(main_val)) => (main_val / ratio, true)
            _ =>
              // Compute intrinsic height for containers with children
              if child.children.length() > 0 {
                (
                  compute_intrinsic_main_size(
                    child,
                    false,
                    Some(content_width),
                    cache,
                    dispatch,
                  ),
                  true,
                )
              } else {
                // Leaf node - use MeasureFunc if available
                match child.measure {
                  Some(mf) => {
                    let intrinsic = (mf.func)(content_width, 0.0)
                    (intrinsic.max_height, true)
                  }
                  None => (0.0, true)
                }
              }
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          (
            compute_intrinsic_main_size(
              child,
              false,
              Some(content_width),
              cache,
              dispatch,
            ),
            false,
          )
      }
    } else {
      match child_style.width {
        @types.Length(w) => (w, false)
        @types.Percent(p) => (content_width * p, false)
        @types.Auto =>
          // Try to use aspect_ratio if main dimension is known
          // Otherwise compute intrinsic width from children
          match (child_style.aspect_ratio, explicit_main) {
            (Some(ratio), Some(main_val)) => (main_val * ratio, true)
            _ => {
              // For row wrap containers, use available width
              // (they need a definite width to determine when to wrap)
              let is_wrap = match child_style.flex_wrap {
                @types.Wrap | @types.WrapReverse => true
                _ => false
              }
              let is_row_flex = match child_style.flex_direction {
                @types.Row | @types.RowReverse => true
                _ => false
              }
              // Note: Check for wrap/direction regardless of explicit display
              // (flex_wrap/flex_direction imply flex behavior)
              if is_wrap && is_row_flex {
                (content_width, true) // Use available width for row wrap container
              } else if child.children.length() > 0 {
                // Compute intrinsic width for containers with children
                (
                  compute_intrinsic_main_size(
                    child, true, content_height, cache, dispatch,
                  ),
                  true,
                )
              } else {
                // Leaf node - use MeasureFunc if available
                match child.measure {
                  Some(mf) => {
                    let intrinsic = (mf.func)(content_width, 0.0)
                    (intrinsic.max_width, true)
                  }
                  None => (0.0, true)
                }
              }
            }
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          (
            compute_intrinsic_main_size(
              child, true, content_height, cache, dispatch,
            ),
            false,
          )
      }
    }
    let margin_main = if is_row {
      child_margin.left + child_margin.right
    } else {
      child_margin.top + child_margin.bottom
    }
    let margin_cross = if is_row {
      child_margin.top + child_margin.bottom
    } else {
      child_margin.left + child_margin.right
    }

    // Calculate min/max constraints on main axis
    // Note: In CSS Flexbox, min-width/min-height: auto means the content minimum size
    // For flex items with children, this prevents shrinking below content size
    // Check if overflow is visible (affects automatic minimum size)
    let is_overflow_visible = match
      (child_style.overflow_x, child_style.overflow_y) {
      (@types.Overflow::Visible, @types.Overflow::Visible) => true
      _ => false
    }
    let (min_main, max_main) = if is_row {
      let max_w = match child_style.max_width {
        @types.Length(v) => v
        @types.Percent(p) => content_width * p
        @types.Auto => 1.0e10 // Effectively infinity
        @types.MaxContent | @types.MinContent => {
          // Calculate intrinsic width for max-width constraint
          let children_width = calculate_children_max_content_width(
              child, content_width,
            ) +
            child_resolved.padding.horizontal_sum() +
            child_resolved.border.horizontal_sum()
          // Consider aspect-ratio if height is specified
          let aspect_width = match
            (child_style.aspect_ratio, child_style.height) {
            (Some(ar), @types.Length(h)) if ar > 0.0 =>
              if child_style.box_sizing == @types.BorderBox {
                h * ar
              } else {
                (
                  h -
                  child_resolved.padding.vertical_sum() -
                  child_resolved.border.vertical_sum()
                ) *
                ar +
                child_resolved.padding.horizontal_sum() +
                child_resolved.border.horizontal_sum()
              }
            (Some(ar), @types.Percent(_)) if ar > 0.0 => {
              let h = match content_height {
                Some(ch) => ch
                None => 0.0
              }
              if child_style.box_sizing == @types.BorderBox {
                h * ar
              } else {
                (
                  h -
                  child_resolved.padding.vertical_sum() -
                  child_resolved.border.vertical_sum()
                ) *
                ar +
                child_resolved.padding.horizontal_sum() +
                child_resolved.border.horizontal_sum()
              }
            }
            _ => 0.0
          }
          @types.max(children_width, aspect_width)
        }
        @types.FitContent(_) => 1.0e10 // Effectively infinity
      }
      // CSS spec: padding + border is always the absolute minimum
      // Use cached resolved rects
      let padding_border_min = child_resolved.padding.horizontal_sum() +
        child_resolved.border.horizontal_sum()
      let min_w = match child_style.min_width {
        @types.Length(v) => max(v, padding_border_min) // Explicit min, but padding+border is absolute minimum
        @types.Percent(p) => max(content_width * p, padding_border_min)
        @types.Auto => {
          // Auto min-width: use intrinsic content size for containers/MeasureFunc
          // Only for overflow:visible; hidden/scroll/auto have automatic min = 0
          // CSS spec: clamped from above by specified size (width) and max-width
          let has_measure = match child.measure {
            Some(_) => true
            None => false
          }
          if is_overflow_visible && (child.children.length() > 0 || has_measure) {
            // Use min-content size for automatic minimum (not max-content)
            // This allows flex items to shrink below their max-content width
            let content_min = compute_min_content_main_size(
              child, true, content_height, cache, dispatch,
            )
            // Clamp by specified size (width) if set
            let specified_clamp = match child_style.width {
              @types.Length(w) => w
              @types.Percent(p) => content_width * p
              @types.Auto => 1.0e10 // No specified size, no clamp
              @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
                1.0e10 // No specified size, no clamp
            }
            // Clamp by min(specified_size, max_size) per CSS spec
            // But padding+border is always the absolute minimum
            max(
              padding_border_min,
              min(content_min, min(specified_clamp, max_w)),
            )
          } else {
            // No children or MeasureFunc: minimum is padding + border
            padding_border_min
          }
        }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          padding_border_min
      }
      (min_w, max_w)
    } else {
      let max_h = match child_style.max_height {
        @types.Length(v) => v
        @types.Percent(p) =>
          match content_height {
            Some(ch) => ch * p
            None => 1.0e10
          }
        @types.Auto => 1.0e10
        @types.MaxContent | @types.MinContent =>
          // Calculate intrinsic height for max-height constraint
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              intrinsic.max_height +
              child_resolved.padding.vertical_sum() +
              child_resolved.border.vertical_sum()
            }
            None => {
              // Sum children's heights
              let mut max_height = 0.0
              let children_for_height = child.children
              for c in children_for_height {
                if c.style.display == @types.Display::None ||
                  c.style.position == @types.Absolute ||
                  c.style.position == @types.Fixed {
                  continue
                }
                match c.measure {
                  Some(mf) => {
                    let intrinsic = (mf.func)(0.0, 0.0)
                    if intrinsic.max_height > max_height {
                      max_height = intrinsic.max_height
                    }
                  }
                  None => ()
                }
              }
              max_height +
              child_resolved.padding.vertical_sum() +
              child_resolved.border.vertical_sum()
            }
          }
        @types.FitContent(_) => 1.0e10
      }
      // CSS spec: padding + border is always the absolute minimum
      // Use cached resolved rects
      let padding_border_min = child_resolved.padding.vertical_sum() +
        child_resolved.border.vertical_sum()
      let min_h = match child_style.min_height {
        @types.Length(v) => max(v, padding_border_min) // Explicit min, but padding+border is absolute minimum
        @types.Percent(p) =>
          match content_height {
            Some(ch) => max(ch * p, padding_border_min)
            None => padding_border_min
          }
        @types.Auto => {
          // Auto min-height: use min-content size for containers/MeasureFunc
          // Only for overflow:visible; hidden/scroll/auto have automatic min = 0
          // CSS spec: clamped from above by specified size (height) and max-height
          let has_measure = match child.measure {
            Some(_) => true
            None => false
          }
          if is_overflow_visible && (child.children.length() > 0 || has_measure) {
            // Use min-content size for automatic minimum (not max-content)
            // This allows flex items to shrink below their max-content height
            let content_min = compute_min_content_main_size(
              child,
              false,
              Some(content_width),
              cache,
              dispatch,
            )
            // Clamp by specified size (height) if set
            let specified_clamp = match child_style.height {
              @types.Length(h) => h
              @types.Percent(p) =>
                match content_height {
                  Some(ch) => ch * p
                  None => 1.0e10
                }
              @types.Auto => 1.0e10 // No specified size, no clamp
              @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
                1.0e10 // No specified size, no clamp
            }
            // Clamp by min(specified_size, max_size) per CSS spec
            // But padding+border is always the absolute minimum
            max(
              padding_border_min,
              min(content_min, min(specified_clamp, max_h)),
            )
          } else {
            // No children or MeasureFunc: minimum is padding + border
            padding_border_min
          }
        }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          padding_border_min
      }
      (min_h, max_h)
    }

    // Detect auto margins
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

    // Map to main/cross axes based on direction
    let (margin_main_start_auto, margin_main_end_auto) = if is_row {
      if is_reverse {
        (margin_right_auto, margin_left_auto)
      } else {
        (margin_left_auto, margin_right_auto)
      }
    } else if is_reverse {
      (margin_bottom_auto, margin_top_auto)
    } else {
      (margin_top_auto, margin_bottom_auto)
    }
    let (margin_cross_start_auto, margin_cross_end_auto) = if is_row {
      (margin_top_auto, margin_bottom_auto)
    } else {
      (margin_left_auto, margin_right_auto)
    }

    // Compute baseline for this item (for Row flex, cross is height)
    // For Row: baseline is relative to the item's height
    // For Column: baseline is relative to the item's width (not commonly used)
    let baseline = if is_row {
      @baseline.compute_node_baseline(child, base_cross)
    } else {
      base_cross // For column flex, baseline = height (simplified)
    }
    // Initial final_main is clamped by min/max constraints
    // This ensures min_main is applied even when flex_grow = 0
    let initial_final_main = @types.max(
      min_main,
      @types.min(base_main, max_main),
    )
    let item : FlexItem = {
      index: i,
      original_child_index: flat_child.original_child_index,
      node: child,
      order: child_style.order,
      base_main,
      base_cross,
      final_main: initial_final_main,
      final_cross: base_cross,
      margin_main,
      margin_cross,
      margin: child_margin,
      flex_grow: child_style.flex_grow,
      flex_shrink: child_style.flex_shrink,
      cross_is_auto,
      min_main,
      max_main,
      frozen: false,
      margin_main_start_auto,
      margin_main_end_auto,
      margin_cross_start_auto,
      margin_cross_end_auto,
      baseline,
      align_self: child_style.align_self,
      contents_ancestors: flat_child.contents_ancestors,
    }
    flex_items.push(item)
    total_base_main = total_base_main + base_main + margin_main
    total_flex_grow = total_flex_grow + child_style.flex_grow
    total_flex_shrink = total_flex_shrink + child_style.flex_shrink
  }

  // Sort flex items by order property (stable sort preserves document order for equal orders)
  flex_items.sort_by(fn(a, b) {
    let order_cmp = a.order.compare(b.order)
    if order_cmp != 0 {
      order_cmp
    } else {
      // Equal order: preserve document order
      a.index.compare(b.index)
    }
  })

  // For Column flex with height: auto and min_height, only use min_height for GROW (not SHRINK)
  // If content size >= min_height, no flex distribution needed (items keep natural size)
  let (main_size_defined, main_size) = match min_main_for_grow {
    Some(min_main) =>
      // Column flex with height: auto and min_height set
      if total_base_main < min_main {
        // Content is smaller than min_height, allow flex_grow to fill the space
        (true, min_main)
      } else {
        // Content is larger than or equal to min_height, no shrink needed
        (false, 0.0)
      }
    None => (initial_main_size_defined, initial_main_size)
  }

  // Phase 1.5: Split items into flex lines (for wrap support)
  let flex_lines : Array[FlexLine] = Array::new()
  let should_wrap = match style.flex_wrap {
    @types.Wrap | @types.WrapReverse => true
    @types.NoWrap => false
  }
  if should_wrap && main_size_defined {
    // Wrap mode: split items into lines based on main size overflow
    let mut current_line_items : Array[FlexItem] = Array::new()
    let mut current_line_main = 0.0
    for i = 0; i < flex_items.length(); i = i + 1 {
      let item = flex_items[i]
      // Use hypothetical main size (clamped by min/max) for line breaking
      // CSS Flexbox spec: line breaking uses hypothetical main size, not base size
      let clamped_main = @types.max(
        item.min_main,
        @types.min(item.base_main, item.max_main),
      )
      let item_main_with_margin = clamped_main + item.margin_main
      let gap_if_not_first = if current_line_items.length() > 0 {
        main_gap
      } else {
        0.0
      }

      // Check if item fits in current line
      if current_line_items.length() > 0 &&
        current_line_main + gap_if_not_first + item_main_with_margin > main_size {
        // Start new line - compute cross size considering baseline alignment
        let line_cross = compute_line_cross_size(
          current_line_items,
          style.align_items,
          is_row,
        )
        flex_lines.push({ items: current_line_items, cross_size: line_cross })
        current_line_items = Array::new()
        current_line_main = 0.0
      }

      // Add item to current line
      if current_line_items.length() > 0 {
        current_line_main = current_line_main + main_gap
      }
      current_line_items.push(item)
      current_line_main = current_line_main + item_main_with_margin
    }

    // Don't forget the last line
    if current_line_items.length() > 0 {
      let line_cross = compute_line_cross_size(
        current_line_items,
        style.align_items,
        is_row,
      )
      flex_lines.push({ items: current_line_items, cross_size: line_cross })
    }
  } else {
    // NoWrap: all items in one line
    let line_cross = compute_line_cross_size(
      flex_items,
      style.align_items,
      is_row,
    )
    flex_lines.push({ items: flex_items, cross_size: line_cross })
  }

  // Phase 2: Distribute remaining space using CSS Flexbox freeze algorithm
  // This handles min/max constraints by iteratively freezing clamped items
  // Account for gaps between items in the remaining space calculation
  let item_count = flex_items.length()
  let total_gap_for_grow = if item_count > 1 {
    main_gap * (item_count - 1).to_double()
  } else {
    0.0
  }
  if main_size_defined && (total_flex_grow > 0.0 || total_flex_shrink > 0.0) {
    let initial_remaining = main_size - total_base_main - total_gap_for_grow
    if initial_remaining > 0.0 && total_flex_grow > 0.0 {
      // Grow items with freeze algorithm
      let max_iterations = 3
      for iter = 0; iter < max_iterations; iter = iter + 1 {
        // Calculate remaining space and unfrozen flex-grow
        let mut used_space = 0.0
        let mut unfrozen_flex_grow = 0.0
        for i = 0; i < flex_items.length(); i = i + 1 {
          let item = flex_items[i]
          if item.frozen {
            used_space = used_space + item.final_main + item.margin_main
          } else {
            used_space = used_space + item.base_main + item.margin_main
            unfrozen_flex_grow = unfrozen_flex_grow + item.flex_grow
          }
        }
        let remaining = main_size - used_space - total_gap_for_grow
        if remaining <= 0.0 || unfrozen_flex_grow == 0.0 {
          break
        }

        // Distribute to unfrozen items
        let mut any_clamped = false
        for i = 0; i < flex_items.length(); i = i + 1 {
          let item = flex_items[i]
          if not(item.frozen) && item.flex_grow > 0.0 {
            let grow_amount = if total_flex_grow < 1.0 {
              // When original sum < 1, each item gets remaining * its_flex_grow
              remaining * item.flex_grow
            } else {
              // When sum >= 1, distribute proportionally among unfrozen
              remaining * (item.flex_grow / unfrozen_flex_grow)
            }
            let target = item.base_main + grow_amount
            let clamped = max(item.min_main, min(item.max_main, target))
            if clamped != target {
              flex_items[i] = { ..item, final_main: clamped, frozen: true }
              any_clamped = true
            } else {
              flex_items[i] = { ..item, final_main: target }
            }
          }
        }
        if not(any_clamped) {
          break // No more clamping needed, distribution complete
        }
      }
    } else if initial_remaining < 0.0 && total_flex_shrink > 0.0 {
      // Shrink items with freeze algorithm
      // CSS spec: shrink is proportional to flex_shrink * flex_basis (scaled flex shrink factor)
      let max_iterations = 10
      for iter = 0; iter < max_iterations; iter = iter + 1 {
        // Calculate used space and total scaled flex shrink factor
        let mut used_space = 0.0
        let mut total_scaled_shrink = 0.0
        let mut unfrozen_flex_shrink = 0.0
        for i = 0; i < flex_items.length(); i = i + 1 {
          let item = flex_items[i]
          if item.frozen {
            used_space = used_space + item.final_main + item.margin_main
          } else {
            used_space = used_space + item.base_main + item.margin_main
            // Scaled flex shrink factor = flex_shrink * flex_basis
            total_scaled_shrink = total_scaled_shrink +
              item.flex_shrink * item.base_main
            unfrozen_flex_shrink = unfrozen_flex_shrink + item.flex_shrink
          }
        }
        let overflow = used_space + total_gap_for_grow - main_size
        if overflow <= 0.0 || total_scaled_shrink == 0.0 {
          break
        }

        // CSS spec: If sum of unfrozen flex shrink factors < 1, clamp the shrinkable space
        let actual_overflow = if total_flex_shrink < 1.0 {
          overflow * total_flex_shrink
        } else {
          overflow
        }

        // Shrink unfrozen items proportionally to their scaled shrink factor
        let mut any_clamped = false
        for i = 0; i < flex_items.length(); i = i + 1 {
          let item = flex_items[i]
          if not(item.frozen) && item.flex_shrink > 0.0 {
            // Each item's shrink = actual_overflow * (item_scaled_shrink / total_scaled_shrink)
            let item_scaled_shrink = item.flex_shrink * item.base_main
            let shrink_ratio = item_scaled_shrink / total_scaled_shrink
            let shrink_amount = actual_overflow * shrink_ratio
            // raw_target may be negative if shrink_amount exceeds base_main
            let raw_target = item.base_main - shrink_amount
            let target = max(0.0, raw_target)
            let clamped = max(item.min_main, min(item.max_main, target))
            // Freeze if raw calculation was clamped (including negative values)
            if clamped != raw_target {
              flex_items[i] = { ..item, final_main: clamped, frozen: true }
              any_clamped = true
            } else {
              flex_items[i] = { ..item, final_main: target }
            }
          }
        }
        if not(any_clamped) {
          break
        }
      }
    }
  }

  // Apply min/max constraints on main axis
  // CSS spec: min takes precedence over max, so apply max first, then min
  // For min-width/min-height: auto, use the automatic minimum size (item.min_main)
  for i = 0; i < flex_items.length(); i = i + 1 {
    let item = flex_items[i]
    let child_style = item.node.style
    let original_main = item.final_main
    let mut final_main = original_main
    if is_row {
      match child_style.max_width {
        @types.Length(v) => if final_main > v { final_main = v }
        @types.Percent(p) => {
          let v = content_width * p
          if final_main > v {
            final_main = v
          }
        }
        @types.Auto => ()
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => ()
      }
      // CSS spec: item.min_main already includes padding+border as absolute minimum
      // So always use item.min_main which is max(explicit_min, padding_border_min)
      if final_main < item.min_main {
        final_main = item.min_main
      }
    } else {
      match child_style.max_height {
        @types.Length(v) => if final_main > v { final_main = v }
        @types.Percent(p) =>
          match content_height {
            Some(ch) => {
              let v = ch * p
              if final_main > v {
                final_main = v
              }
            }
            None => ()
          }
        @types.Auto => ()
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => ()
      }
      // CSS spec: item.min_main already includes padding+border as absolute minimum
      // So always use item.min_main which is max(explicit_min, padding_border_min)
      if final_main < item.min_main {
        final_main = item.min_main
      }
    }

    // Only update if changed
    if final_main != original_main {
      flex_items[i] = { ..item, final_main, }
    }
  }

  // Phase 3: Handle cross axis sizing
  let mut max_cross : Double = 0.0
  for i = 0; i < flex_items.length(); i = i + 1 {
    let item = flex_items[i]
    let child_style = item.node.style

    // Determine effective alignment (align-self overrides align-items)
    let effective_align = match child_style.align_self {
      @types.AlignSelf::Auto => style.align_items
      @types.AlignSelf::Stretch => @types.Stretch
      @types.AlignSelf::Baseline => @types.Baseline
      _ => @types.Start
    } // Non-stretch/baseline align-self means don't stretch

    // For stretch alignment, item takes full cross size only if cross dimension is auto
    // For non-stretch with aspect_ratio, recalculate cross from constrained main dimension
    // NOTE: For wrap containers, stretch is deferred to Phase 5 where line_cross_size is known
    let is_wrap = match style.flex_wrap {
      @types.Wrap | @types.WrapReverse => true
      @types.NoWrap => false
    }
    // If final_main differs from content_width, we may need to recalculate cross size
    // because base_cross was computed using content_width, not the actual item width
    // This is especially important when text wrapping changes with different widths
    let child = item.node
    // Compare final_main with content_width (the width used to compute base_cross)
    let width_differs_from_base = (item.final_main - content_width).abs() > 0.01
    let needs_cross_recalc = width_differs_from_base &&
      is_row &&
      item.cross_is_auto &&
      (child.children.length() > 0 || child.measure is Some(_))
    let recalc_cross = fn() -> Double {
      compute_intrinsic_main_size(
        child,
        false,
        Some(item.final_main),
        cache,
        dispatch,
      )
    }
    let final_cross = match effective_align {
      @types.Stretch =>
        if item.cross_is_auto {
          if is_wrap {
            // For wrap containers, defer stretch to Phase 5 (use line_cross_size, not container cross_size)
            // But if main size changed, recalculate based on final_main
            if needs_cross_recalc {
              recalc_cross()
            } else {
              item.base_cross
            }
          } else {
            match cross_size {
              Some(cs) => cs - item.margin_cross
              None =>
                if needs_cross_recalc {
                  recalc_cross()
                } else {
                  item.base_cross
                }
            }
          }
        } else {
          item.base_cross
        }
      _ =>
        // If cross is auto and aspect_ratio is defined, calculate from main dimension
        if item.cross_is_auto {
          match child_style.aspect_ratio {
            Some(ratio) =>
              if is_row {
                // height = width / ratio
                item.final_main / ratio
              } else {
                // width = height * ratio
                item.final_main * ratio
              }
            None =>
              if needs_cross_recalc {
                recalc_cross()
              } else {
                item.base_cross
              }
          }
        } else {
          item.base_cross
        }
    }

    // Apply min/max on cross axis
    // CSS spec: min takes precedence over max, so apply max first, then min
    // Note: percentage constraints are resolved against the parent container's cross size
    let mut constrained_cross = final_cross
    if is_row {
      match child_style.max_height {
        @types.Length(v) => if constrained_cross > v { constrained_cross = v }
        @types.Percent(p) =>
          match cross_size {
            Some(cs) => {
              // Add back padding/border to get the full container height for percentage resolution
              let container_cross = cs +
                padding.vertical_sum() +
                border.vertical_sum()
              let v = container_cross * p
              if constrained_cross > v {
                constrained_cross = v
              }
            }
            None => ()
          }
        _ => ()
      }
      // CSS spec: padding + border is always the absolute minimum
      let child_padding = @types.resolve_rect(
        child_style.padding,
        content_width,
      )
      let child_border = @types.resolve_rect(child_style.border, content_width)
      let padding_border_min = child_padding.vertical_sum() +
        child_border.vertical_sum()
      match child_style.min_height {
        @types.Length(v) => {
          // Use max of explicit min and padding+border
          let effective_min = max(v, padding_border_min)
          if constrained_cross < effective_min {
            constrained_cross = effective_min
          }
        }
        @types.Percent(p) =>
          match cross_size {
            Some(cs) => {
              let container_cross = cs +
                padding.vertical_sum() +
                border.vertical_sum()
              let v = container_cross * p
              let effective_min = max(v, padding_border_min)
              if constrained_cross < effective_min {
                constrained_cross = effective_min
              }
            }
            None =>
              if constrained_cross < padding_border_min {
                constrained_cross = padding_border_min
              }
          }
        @types.Auto =>
          if constrained_cross < padding_border_min {
            constrained_cross = padding_border_min
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          if constrained_cross < padding_border_min {
            constrained_cross = padding_border_min
          }
      }
    } else {
      match child_style.max_width {
        @types.Length(v) => if constrained_cross > v { constrained_cross = v }
        @types.Percent(p) => {
          // For column flex, cross axis is width
          // content_width + padding + border = container_width
          let v = container_width * p
          if constrained_cross > v {
            constrained_cross = v
          }
        }
        @types.Auto => ()
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => ()
      }
      // CSS spec: padding + border is always the absolute minimum
      let child_padding = @types.resolve_rect(
        child_style.padding,
        content_width,
      )
      let child_border = @types.resolve_rect(child_style.border, content_width)
      let padding_border_min = child_padding.horizontal_sum() +
        child_border.horizontal_sum()
      match child_style.min_width {
        @types.Length(v) => {
          // Use max of explicit min and padding+border
          let effective_min = max(v, padding_border_min)
          if constrained_cross < effective_min {
            constrained_cross = effective_min
          }
        }
        @types.Percent(p) => {
          let v = container_width * p
          let effective_min = max(v, padding_border_min)
          if constrained_cross < effective_min {
            constrained_cross = effective_min
          }
        }
        @types.Auto =>
          if constrained_cross < padding_border_min {
            constrained_cross = padding_border_min
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          if constrained_cross < padding_border_min {
            constrained_cross = padding_border_min
          }
      }
    }

    // Only update if cross size changed from base
    if constrained_cross != item.base_cross {
      flex_items[i] = { ..item, final_cross: constrained_cross }
    }
    max_cross = max(max_cross, constrained_cross + item.margin_cross)
  }

  // Phase 3.5: Recalculate each line's cross_size based on updated final_cross from flex_items
  // MoonBit creates new structs on update, so line.items has stale cross data
  // We use flex_items for accurate cross_size calculation
  // For single-line: sync items back (needed for Phase 5 stretch)
  // For multi-line: only update cross_size, keep line.items for Phase 4 main positioning
  let mut flex_item_idx = 0
  for line_idx = 0; line_idx < flex_lines.length(); line_idx = line_idx + 1 {
    let line = flex_lines[line_idx]
    let line_item_count = line.items.length()

    // Collect updated items for this line
    let line_items : Array[FlexItem] = Array::new()
    for j = 0; j < line_item_count; j = j + 1 {
      line_items.push(flex_items[flex_item_idx])
      flex_item_idx = flex_item_idx + 1
    }

    // Recalculate cross size with baseline alignment consideration
    let new_cross_size = compute_line_cross_size(
      line_items,
      style.align_items,
      is_row,
    )

    // Update line with new cross_size
    if flex_lines.length() == 1 {
      // Single-line: sync items for Phase 5
      flex_lines[0] = { items: flex_items, cross_size: new_cross_size }
    } else {
      // Multi-line: only update cross_size, preserve line.items
      flex_lines[line_idx] = { ..line, cross_size: new_cross_size }
    }
  }

  // Phase 4 & 5: Position items and build layouts
  // For multi-line (wrap), we need to process each line separately
  // Use IndexedLayout to preserve DOM order when mixing flex and absolute children
  let indexed_layouts : Array[IndexedLayout] = Array::new(capacity=child_count)

  // Map to collect layouts for display: contents children
  // Key: original_child_index, Value: array of (layout, contents_ancestors)
  let contents_layouts : Map[Int, Array[(@types.Layout, Array[@node.Node])]] = {}

  // Calculate total cross size for all lines (for auto height)
  let mut total_lines_cross = 0.0
  for line_idx = 0; line_idx < flex_lines.length(); line_idx = line_idx + 1 {
    total_lines_cross = total_lines_cross + flex_lines[line_idx].cross_size
  }
  // Add cross gaps between lines
  if flex_lines.length() > 1 {
    total_lines_cross = total_lines_cross +
      cross_gap * (flex_lines.length() - 1).to_double()
  }

  // Effective cross size for the container
  let effective_cross = match cross_size {
    Some(cs) => cs
    None => total_lines_cross
  }

  // Calculate constrained cross size for align-items positioning in nowrap containers
  // This is used when container cross size differs from line cross size due to max/min constraints
  // Note: When ctx.sizing_mode is Definite and available_height is set, the container's cross size
  // has already been constrained by the parent (e.g., max-height was applied). In this case,
  // we should use the already-constrained value rather than re-applying percentage constraints.
  let align_cross_for_nowrap : Double? = if not(should_wrap) &&
    flex_lines.length() == 1 &&
    is_row {
    // Get the base cross size (content area)
    let base_cross = match cross_size {
      Some(cs) => cs + padding.vertical_sum() + border.vertical_sum() // explicit/constrained height
      None => total_lines_cross + padding.vertical_sum() + border.vertical_sum() // auto height
    }
    let mut constrained = base_cross
    // Only apply Length constraints here; Percent constraints should have been applied by parent
    // when this container was laid out as a flex item
    match style.max_height {
      @types.Length(v) => if constrained > v { constrained = v }
      _ => ()
    }
    match style.min_height {
      @types.Length(v) => if constrained < v { constrained = v }
      _ => ()
    }
    // Return constrained content area size
    Some(constrained - padding.vertical_sum() - border.vertical_sum())
  } else {
    None
  }

  // Calculate line positions using align-content
  let cross_free_space = effective_cross - total_lines_cross

  // Handle align-content: Stretch - distribute extra space to lines
  // NOTE: Stretch applies to line SIZE even in single-line containers
  let line_count = flex_lines.length()
  if style.align_content == @types.Stretch &&
    cross_free_space > 0.0 &&
    line_count > 0 {
    // Distribute extra cross space equally among lines
    let extra_per_line = cross_free_space / line_count.to_double()
    for line_idx = 0; line_idx < line_count; line_idx = line_idx + 1 {
      let line = flex_lines[line_idx]
      flex_lines[line_idx] = {
        ..line,
        cross_size: line.cross_size + extra_per_line,
      }
    }
  }

  // CSS spec: align-content positioning has no effect on single-line flex containers
  // For single-line containers (nowrap), line is always positioned at Start
  // Handle wrap-reverse: FlexStart/FlexEnd are flipped, but Start/End are not
  let css_wrap_reverse = match style.flex_wrap {
    @types.WrapReverse => true
    _ => false
  }
  // RTL affects inline axis direction:
  // - For row flex: main axis = inline, already handled by is_reverse above
  // - For column flex: cross axis = inline, handle here
  // Use direction_is_row (CSS row/column) not is_row (physical axis)
  let is_wrap_reverse = if not(direction_is_row) && is_rtl {
    not(css_wrap_reverse) // RTL inverts wrap direction for column flex
  } else {
    css_wrap_reverse
  }
  // For wrap-reverse with flex-relative alignment, the line positioning is handled
  // by uses_reversed_layout, so we don't need to flip here
  let effective_align_content_for_position : @types.Alignment = if should_wrap {
    style.align_content
  } else {
    @types.FlexStart
  }
  let (line_start_offset, line_gap) = @alignment.compute_justify(
    effective_align_content_for_position, cross_free_space, line_count,
  )
  // For Stretch, cross_free_space was distributed to lines, so use 0 for line_gap
  let effective_line_gap = if style.align_content == @types.Stretch {
    0.0
  } else {
    line_gap
  }
  let total_line_gap = cross_gap + effective_line_gap

  // Process each line
  // For wrap-reverse with flex-relative alignment (FlexStart/FlexEnd), start from cross-end
  // For wrap-reverse with physical alignment (Start/End), use normal positioning
  let cross_size_resolved = match cross_size {
    Some(cs) => cs
    None => total_lines_cross
  }
  // Determine if we should use reversed layout for line positioning
  // In wrap-reverse:
  // - For flex-relative alignment (FlexStart/FlexEnd/Stretch): position from physical end, move backward
  // - For physical alignment (Start/End): position from physical start, but reverse line ORDER
  // This means lines are always in reverse visual order, but the starting position differs
  let is_flex_relative_align = match style.align_content {
    @types.FlexStart
    | @types.FlexEnd
    | @types.Stretch
    | @types.Center
    | @types.SpaceBetween
    | @types.SpaceAround
    | @types.SpaceEvenly => true
    @types.Start | @types.End | @types.Baseline => false
  }
  let uses_reversed_position = is_wrap_reverse && is_flex_relative_align
  let mut cross_pos = if uses_reversed_position {
    // Start from cross-end for flex-relative alignment in wrap-reverse
    cross_size_resolved - line_start_offset
  } else {
    line_start_offset
  }
  // For single-line with definite cross size, we may need container cross size for alignment
  // when children are larger than parent (to allow negative alignment offsets)
  let is_single_line = flex_lines.length() == 1
  // For wrap-reverse with physical alignment (Start/End), iterate lines in reverse order
  // For wrap-reverse with flex-relative alignment, iterate normally but position from end
  let reverse_line_order = is_wrap_reverse && not(is_flex_relative_align)
  let line_count_int = flex_lines.length()
  for iter_idx = 0; iter_idx < line_count_int; iter_idx = iter_idx + 1 {
    let line_idx = if reverse_line_order {
      line_count_int - 1 - iter_idx
    } else {
      iter_idx
    }
    let line = flex_lines[line_idx]
    let line_items = line.items
    let line_cross_size = line.cross_size

    // For wrap-reverse with flex-relative alignment, adjust cross_pos to position from end of line
    let line_cross_pos = if uses_reversed_position {
      cross_pos - line_cross_size
    } else {
      cross_pos
    }

    // Calculate main axis positioning for this line
    let line_item_count = line_items.length()
    let line_total_main_gap = if line_item_count > 1 {
      main_gap * (line_item_count - 1).to_double()
    } else {
      0.0
    }
    let line_main_used : Double = {
      let mut sum = 0.0
      for i = 0; i < line_items.length(); i = i + 1 {
        let item = line_items[i]
        sum = sum + item.final_main + item.margin_main
      }
      sum + line_total_main_gap
    }
    // For auto-sized containers (main_size_defined = false), there's no free space
    // This is important for is_reverse to work correctly - items should be positioned
    // from the content end, not from a negative offset
    let line_free_space = if main_size_defined {
      main_size - line_main_used
    } else {
      0.0
    }

    // Count auto margins on main axis for this line
    let mut auto_margin_count = 0
    for item in line_items {
      if item.margin_main_start_auto {
        auto_margin_count = auto_margin_count + 1
      }
      if item.margin_main_end_auto {
        auto_margin_count = auto_margin_count + 1
      }
    }

    // Calculate auto margin size (only if there's positive free space)
    let auto_margin_size = if auto_margin_count > 0 && line_free_space > 0.0 {
      line_free_space / auto_margin_count.to_double()
    } else {
      0.0
    }

    // If auto margins exist, they absorb free space instead of justify-content
    // For reverse directions, flip Start/End in justify_content
    // In column-reverse: "start" means items at physical bottom, "end" means items at physical top
    // Flipping gives us the correct start_offset for the reversed positioning algorithm
    let effective_justify = if is_reverse {
      match style.justify_content {
        @types.Start => @types.Alignment::End
        @types.End => @types.Alignment::Start
        other => other
      }
    } else {
      style.justify_content
    }
    let (start_offset, justify_gap) = if auto_margin_count > 0 {
      (0.0, 0.0)
    } else {
      @alignment.compute_justify(
        effective_justify, line_free_space, line_item_count,
      )
    }
    let gap = main_gap + justify_gap
    let mut main_pos = start_offset

    // Calculate max baseline for this line (for Baseline alignment)
    // max_baseline is the maximum distance from cross-start to baseline across all items
    // This determines where the baseline will be in the line
    let mut max_baseline = 0.0
    for item in line_items {
      // Baseline position from cross-start (including margin)
      let cross_start_margin = if is_row {
        item.margin.top
      } else {
        item.margin.left
      }
      max_baseline = max(max_baseline, cross_start_margin + item.baseline)
    }

    // For is_reverse, calculate total used main first so we can position from the end
    let line_total_main = if is_reverse {
      let mut total = 0.0
      for item in line_items {
        total = total + item.final_main + item.margin_main
        if item.margin_main_start_auto {
          total = total + auto_margin_size
        }
        if item.margin_main_end_auto {
          total = total + auto_margin_size
        }
      }
      total = total + gap * (line_item_count - 1).to_double()
      total
    } else {
      0.0 // Not used for non-reverse
    }

    // Position items within this line
    // For is_reverse, we iterate in DOM order but calculate positions from the end
    // This keeps child_layouts in DOM order while placing items in reversed visual order

    // For is_reverse, track position from the end going backwards
    let mut reversed_main_pos = start_offset + line_total_main
    for j = 0; j < line_item_count; j = j + 1 {
      // Always access items in DOM order so child_layouts stays in DOM order
      let item = line_items[j]
      let child = item.node

      // Calculate auto margin adjustments for main axis
      let main_start_auto_margin = if item.margin_main_start_auto {
        auto_margin_size
      } else {
        0.0
      }
      let main_end_auto_margin = if item.margin_main_end_auto {
        auto_margin_size
      } else {
        0.0
      }

      // Compute cross position within the line based on align-self/align-items
      // Auto margins on cross axis override align-self/align-items
      let has_cross_auto_margin = item.margin_cross_start_auto ||
        item.margin_cross_end_auto
      let raw_effective_align = if has_cross_auto_margin {
        @types.Alignment::Start // Auto margins will handle alignment
      } else {
        match child.style.align_self {
          @types.AlignSelf::Auto => style.align_items
          @types.AlignSelf::Start => @types.Start
          @types.AlignSelf::End => @types.End
          @types.AlignSelf::Center => @types.Center
          @types.AlignSelf::Stretch => @types.Stretch
          @types.AlignSelf::Baseline => @types.Baseline
        }
      }
      // For column flex, baseline alignment is not meaningful (cross axis is inline axis)
      // Treat baseline as flex-start per CSS Flexbox spec
      let effective_align = match (is_row, raw_effective_align) {
        (false, @types.Baseline) => @types.FlexStart
        (_, align) => align
      }

      // For stretch, use line cross size (with min/max constraints) if cross_is_auto
      let item_cross = match effective_align {
        @types.Stretch =>
          if item.cross_is_auto {
            // Apply min/max constraints to stretched size
            let stretched = line_cross_size - item.margin_cross
            // item.final_cross already has constraints, use min of stretched and final_cross
            // to handle max constraints, and max with final_cross to handle min constraints
            let child = item.node
            let child_style = child.style
            let mut constrained = stretched
            // CSS spec: min takes precedence over max, so apply max first, then min
            // CSS spec: padding + border is always the absolute minimum
            let child_padding = @types.resolve_rect(child_style.padding, 0.0)
            let child_border = @types.resolve_rect(child_style.border, 0.0)
            if is_row {
              let padding_border_min = child_padding.vertical_sum() +
                child_border.vertical_sum()
              match child_style.max_height {
                @types.Length(v) => if constrained > v { constrained = v }
                _ => ()
              }
              match child_style.min_height {
                @types.Length(v) => {
                  // Use max of explicit min and padding+border
                  let effective_min = max(v, padding_border_min)
                  if constrained < effective_min {
                    constrained = effective_min
                  }
                }
                @types.Auto =>
                  if constrained < padding_border_min {
                    constrained = padding_border_min
                  }
                _ => ()
              }
            } else {
              let padding_border_min = child_padding.horizontal_sum() +
                child_border.horizontal_sum()
              match child_style.max_width {
                @types.Length(v) => if constrained > v { constrained = v }
                _ => ()
              }
              match child_style.min_width {
                @types.Length(v) => {
                  // Use max of explicit min and padding+border
                  let effective_min = max(v, padding_border_min)
                  if constrained < effective_min {
                    constrained = effective_min
                  }
                }
                @types.Auto =>
                  if constrained < padding_border_min {
                    constrained = padding_border_min
                  }
                _ => ()
              }
            }
            constrained
          } else {
            item.final_cross
          }
        _ => item.final_cross
      }

      // Calculate cross axis auto margin offset
      let cross_auto_offset = if has_cross_auto_margin {
        let cross_free = line_cross_size - item_cross - item.margin_cross
        if item.margin_cross_start_auto && item.margin_cross_end_auto {
          // Both auto: center the item
          cross_free / 2.0
        } else if item.margin_cross_start_auto {
          // Only start auto: push to end
          cross_free
        } else {
          // Only end auto: stay at start
          0.0
        }
      } else {
        0.0
      }

      // For Baseline alignment, position items so their baselines align at max_baseline
      // offset = max_baseline - item.baseline - cross_start_margin
      let base_cross_align_offset = if has_cross_auto_margin {
        cross_auto_offset
      } else {
        match effective_align {
          @types.Baseline => {
            let cross_start_margin = if is_row {
              item.margin.top
            } else {
              item.margin.left
            }
            max_baseline - item.baseline - cross_start_margin
          }
          _ => {
            // For single-line containers with definite cross size,
            // use container cross size when item is larger than container
            // to allow negative alignment offsets
            // NOTE: This only applies to nowrap containers; wrap containers should always use line_cross_size
            let item_total_cross = item_cross + item.margin_cross
            // For nowrap single-line, use constrained container size for alignment
            let align_cross_size = match align_cross_for_nowrap {
              Some(acs) => acs
              None =>
                if should_wrap {
                  // Wrap containers: always use line_cross_size for alignment
                  line_cross_size
                } else {
                  match cross_size {
                    Some(cs) =>
                      // Use container cross size when item is larger than container
                      // This allows proper centering with negative offsets
                      if is_single_line && item_total_cross > cs {
                        cs
                      } else {
                        line_cross_size
                      }
                    None => line_cross_size
                  }
                }
            }
            compute_align(
              effective_align,
              item_cross,
              align_cross_size,
              item.margin_cross,
            )
          }
        }
      }

      // For wrap-reverse, reverse the alignment within the line
      // Items that were at cross-start should now be at cross-end
      // This applies to ALL wrap-reverse containers regardless of align-content type
      let cross_align_offset = if is_wrap_reverse {
        let total_cross_used = item_cross + item.margin_cross
        line_cross_size - total_cross_used - base_cross_align_offset
      } else {
        base_cross_align_offset
      }
      let main_start = if is_row { item.margin.left } else { item.margin.top }
      let cross_start = if is_row { item.margin.top } else { item.margin.left }

      // For is_reverse, calculate position from the end going backwards
      let effective_main_pos = if is_reverse {
        // Position from end: current_end - item_size (not including end margin)
        reversed_main_pos - item.final_main - item.margin_main
      } else {
        main_pos
      }
      let (base_x, base_y) = if is_row {
        let x = effective_main_pos +
          main_start +
          main_start_auto_margin +
          padding.left +
          border.left
        let y = line_cross_pos +
          cross_align_offset +
          cross_start +
          padding.top +
          border.top
        (x, y)
      } else {
        let x = line_cross_pos +
          cross_align_offset +
          cross_start +
          padding.left +
          border.left
        let y = effective_main_pos +
          main_start +
          main_start_auto_margin +
          padding.top +
          border.top
        (x, y)
      }

      // Apply inset offsets for non-absolute positioned children
      // (Static and Relative both apply inset as offset from flow position)
      let child_style = child.style
      let (child_x, child_y) = if child_style.position != @types.Absolute &&
        child_style.position != @types.Fixed {
        // X offset: left takes precedence, otherwise use negative right
        let x_offset = match child_style.inset.left {
          @types.Length(v) => v
          @types.Percent(p) => content_width * p
          @types.Auto =>
            match child_style.inset.right {
              @types.Length(r) => -r
              @types.Percent(p) => -(content_width * p)
              _ => 0.0
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
        }
        // Y offset: top takes precedence, otherwise use negative bottom
        let y_offset = match child_style.inset.top {
          @types.Length(v) => v
          @types.Percent(p) =>
            match content_height {
              Some(ch) => ch * p
              None => 0.0
            }
          @types.Auto =>
            match child_style.inset.bottom {
              @types.Length(b) => -b
              @types.Percent(p) =>
                match content_height {
                  Some(ch) => -(ch * p)
                  None => 0.0
                }
              _ => 0.0
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
        }
        (base_x + x_offset, base_y + y_offset)
      } else {
        (base_x, base_y)
      }
      let (child_width, child_height) = if is_row {
        (item.final_main, item_cross)
      } else {
        (item_cross, item.final_main)
      }
      // For vertical-rl: flip x position (items flow from right to left)
      let (child_x, child_y) = if is_block_rtl {
        (container_width - child_x - child_width, child_y)
      } else {
        (child_x, child_y)
      }
      let child_layout : @types.Layout = if child.children.length() == 0 {
        let child_style = child.style
        let child_padding = @types.resolve_rect(
          child_style.padding,
          child_width,
        )
        let child_border = @types.resolve_rect(child_style.border, child_width)
        {
          id: child.id,
          x: child_x,
          y: child_y,
          width: child_width,
          height: child_height,
          margin: item.margin,
          padding: child_padding,
          border: child_border,
          overflow_x: child_style.overflow_x,
          overflow_y: child_style.overflow_y,
          children: [],
          text: child.text,
        }
      } else {
        let child_ctx : @types.LayoutContext = {
          available_width: child_width,
          available_height: Some(child_height),
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        let nested_layout = compute_nested(
          child, child_ctx, warnings, cache, dispatch,
        )
        {
          id: child.id,
          x: child_x,
          y: child_y,
          width: child_width,
          height: child_height,
          margin: item.margin,
          padding: nested_layout.padding,
          border: nested_layout.border,
          overflow_x: nested_layout.overflow_x,
          overflow_y: nested_layout.overflow_y,
          children: nested_layout.children,
          text: child.text,
        }
      }
      // Handle display: contents - collect layouts for later tree reconstruction
      if item.contents_ancestors.length() > 0 {
        // This item is inside a display: contents element
        let key = item.original_child_index
        match contents_layouts.get(key) {
          Some(arr) => arr.push((child_layout, item.contents_ancestors))
          None =>
            contents_layouts.set(key, [(child_layout, item.contents_ancestors)])
        }
      } else {
        // Direct child - push normally with original_child_index for DOM ordering
        indexed_layouts.push({
          dom_index: item.original_child_index,
          layout: child_layout,
        })
      }

      // Update position for next item
      if is_reverse {
        // Move backwards: subtract item size + gap
        reversed_main_pos = reversed_main_pos -
          item.final_main -
          item.margin_main -
          main_start_auto_margin -
          main_end_auto_margin -
          gap
      } else {
        main_pos = main_pos +
          item.final_main +
          item.margin_main +
          main_start_auto_margin +
          main_end_auto_margin +
          gap
      }
    }

    // Advance to next line
    // For wrap-reverse with flex-relative alignment, we move backwards (toward physical start)
    // For wrap-reverse with physical alignment, we move forwards (we iterate lines in reverse)
    cross_pos = if uses_reversed_position {
      cross_pos - line_cross_size - total_line_gap
    } else {
      cross_pos + line_cross_size + total_line_gap
    }
  }

  // Calculate container height
  // For wrap mode, use total_lines_cross; for single line, use max_cross
  // For leaf nodes with MeasureFunc, use intrinsic height
  let container_height = match intrinsic_from_measure {
    Some((_, h)) => h
    None =>
      match style.height {
        @types.Length(h) => h
        @types.Percent(p) => parent_height * p
        @types.Auto =>
          if is_row {
            // Row direction: cross size is height
            total_lines_cross + padding.vertical_sum() + border.vertical_sum()
          } else {
            // Column direction: main size is height
            // Calculate total main size including gaps within and between lines
            let mut total_main = 0.0
            for line_idx = 0
                line_idx < flex_lines.length()
                line_idx = line_idx + 1 {
              let line = flex_lines[line_idx]
              // Sum up item sizes + gaps within the line
              let mut line_main = 0.0
              for item in line.items {
                line_main = line_main + item.final_main + item.margin_main
              }
              // Add gaps between items within the line
              if line.items.length() > 1 {
                line_main = line_main +
                  main_gap * (line.items.length() - 1).to_double()
              }
              total_main = total_main + line_main
            }
            // Add cross_gap between lines (which is main gap in column wrap)
            if flex_lines.length() > 1 {
              total_main = total_main +
                cross_gap * (flex_lines.length() - 1).to_double()
            }
            total_main + padding.vertical_sum() + border.vertical_sum()
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
          // Intrinsic sizing - use content height
          if is_row {
            total_lines_cross + padding.vertical_sum() + border.vertical_sum()
          } else {
            // Column direction: calculate total main size from items
            let mut total_main = 0.0
            for line_idx = 0
                line_idx < flex_lines.length()
                line_idx = line_idx + 1 {
              let line = flex_lines[line_idx]
              let mut line_main = 0.0
              for item in line.items {
                // outer_main = final_main + margin_main
                line_main = line_main + item.final_main + item.margin_main
              }
              if line.items.length() > 1 {
                line_main = line_main +
                  main_gap * (line.items.length() - 1).to_double()
              }
              total_main = total_main + line_main
            }
            if flex_lines.length() > 1 {
              total_main = total_main +
                cross_gap * (flex_lines.length() - 1).to_double()
            }
            total_main + padding.vertical_sum() + border.vertical_sum()
          }
      }
  }

  // Apply min/max height
  // CSS spec: min-height takes precedence over max-height when they conflict
  // So apply max first, then min
  let mut final_height = container_height
  match style.max_height {
    @types.Length(v) => if final_height > v { final_height = v }
    @types.Percent(p) => {
      let v = parent_height * p
      if final_height > v {
        final_height = v
      }
    }
    @types.Auto => ()
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => ()
  }
  // CSS spec: padding + border is always the absolute minimum
  let padding_border_height = padding.vertical_sum() + border.vertical_sum()
  match style.min_height {
    @types.Length(v) => {
      let effective_min = max(v, padding_border_height)
      if final_height < effective_min {
        final_height = effective_min
      }
    }
    @types.Percent(p) => {
      let v = parent_height * p
      let effective_min = max(v, padding_border_height)
      if final_height < effective_min {
        final_height = effective_min
      }
    }
    @types.Auto =>
      if final_height < padding_border_height {
        final_height = padding_border_height
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      if final_height < padding_border_height {
        final_height = padding_border_height
      }
  }

  // Process absolutely positioned children
  for i = 0; i < child_count; i = i + 1 {
    let child = children[i]
    let child_style = child.style

    // Only process absolutely positioned children
    if child_style.position != @types.Absolute {
      continue
    }

    // Skip display:none children - create zero-sized layout
    if child_style.display == @types.Display::None {
      indexed_layouts.push({
        dom_index: i,
        layout: @absolute.create_zero_layout(child.id),
      })
      continue
    }

    // Use shared absolute module for size calculation
    // For absolute positioning, the containing block is the padding box (inside border)
    let padding_box_width = container_width - border.horizontal_sum()
    let padding_box_height = final_height - border.vertical_sum()
    let params = @absolute.compute_size_params(
      child_style, padding_box_width, padding_box_height,
    )

    // Apply aspect ratio to calculate missing dimension
    let (initial_width, initial_height) = @types.resolve_dimensions_with_aspect_ratio(
      params.initial_width,
      params.initial_height,
      child_style.aspect_ratio,
      params.min_width,
      params.max_width,
      params.min_height,
      params.max_height,
    )

    // Compute intrinsic size if needed, and get child's inner layout
    let (child_width, child_height, child_inner) = match
      (initial_width, initial_height) {
      (Some(w), Some(h)) => {
        let inner = compute_nested(
          child,
          {
            available_width: w,
            available_height: Some(h),
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        (w, h, inner)
      }
      (Some(w), None) => {
        let inner = compute_nested(
          child,
          {
            available_width: w,
            available_height: None,
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        (w, inner.height, inner)
      }
      (None, Some(h)) => {
        // Width is auto: use shrink-to-fit approach
        // Step 1: Compute intrinsic width using dedicated function
        // This correctly handles percentage children as 0 in intrinsic sizing
        let intrinsic_width = compute_intrinsic_main_size(
          child,
          true,
          Some(h),
          cache,
          dispatch,
        )
        // Shrink-to-fit: min(max-content, available_width)
        let shrink_to_fit_width = if intrinsic_width < container_width {
          intrinsic_width
        } else {
          container_width
        }
        // Step 2: Layout with definite width so percentage children resolve correctly
        let inner = compute_nested(
          child,
          {
            available_width: shrink_to_fit_width,
            available_height: Some(h),
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        (shrink_to_fit_width, h, inner)
      }
      (None, None) => {
        // Both width and height are auto: use shrink-to-fit approach
        // Step 1: Compute intrinsic size using dedicated function
        // This correctly handles percentage children as 0 in intrinsic sizing
        let intrinsic_width = compute_intrinsic_main_size(
          child,
          true,
          None,
          cache,
          dispatch,
        )
        // Shrink-to-fit: min(max-content, available_width)
        let shrink_to_fit_width = if intrinsic_width < container_width {
          intrinsic_width
        } else {
          container_width
        }
        // Step 2: Layout with definite width to get height and child layouts
        let inner = compute_nested(
          child,
          {
            available_width: shrink_to_fit_width,
            available_height: None,
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        match child_style.aspect_ratio {
          Some(ar) if ar > 0.0 => {
            let w = shrink_to_fit_width
            let h = w / ar
            (w, h, inner)
          }
          _ => (shrink_to_fit_width, inner.height, inner)
        }
      }
    }

    // Apply min/max constraints and re-apply aspect ratio
    let (child_width, child_height) = @absolute.apply_constraints_with_aspect_ratio(
      child_width,
      child_height,
      child_style,
      params.min_width,
      params.max_width,
      params.min_height,
      params.max_height,
    )

    // CSS rule: padding+border override explicit size constraints
    // Use cached resolved rects
    let child_resolved = get_resolved_rects(
      child_style,
      child.uid,
      container_width,
    )
    let child_padding = child_resolved.padding
    let child_border = child_resolved.border
    let min_child_width = child_padding.horizontal_sum() +
      child_border.horizontal_sum()
    let min_child_height = child_padding.vertical_sum() +
      child_border.vertical_sum()
    let child_width = if child_width < min_child_width {
      min_child_width
    } else {
      child_width
    }
    let child_height = if child_height < min_child_height {
      min_child_height
    } else {
      child_height
    }

    // Calculate position
    // If insets are specified, use them; otherwise use align_items/justify_content
    let has_horizontal_inset = params.inset_left != None ||
      params.inset_right != None
    let has_vertical_inset = params.inset_top != None ||
      params.inset_bottom != None

    // Note: For absolute positioning, the containing block is the padding box
    // (inside border, but NOT inside padding). So we add border but NOT padding
    // to position calculations.
    let child_x = if has_horizontal_inset {
      match params.inset_left {
        Some(l) => l + params.margin_left + border.left
        None =>
          match params.inset_right {
            Some(r) =>
              container_width -
              child_width -
              r -
              params.margin_right -
              border.right
            None => params.margin_left + border.left
          }
      }
    } else {
      // Use align_items for cross-axis positioning (x for row direction)
      let free_space = container_width -
        child_width -
        params.margin_left -
        params.margin_right
      let is_wrap_reverse = match style.flex_wrap {
        @types.WrapReverse => true
        _ => false
      }
      let align_offset = if is_row {
        // For row, main axis is horizontal
        // Use justify_self/justify_content for main axis (x)
        @alignment.compute_align_self_offset(
          child_style.justify_self,
          style.justify_content,
          free_space,
        )
      } else {
        // For column, cross axis is horizontal
        // Use align_self/align_items for cross axis (x)
        let offset = @alignment.compute_align_self_offset(
          child_style.align_self,
          style.align_items,
          free_space,
        )
        // WrapReverse flips cross-axis direction: Start <-> End
        if is_wrap_reverse && free_space > 0.0 {
          free_space - offset
        } else {
          offset
        }
      }
      // When no inset, child is at content box position (border + padding)
      params.margin_left + align_offset + border.left + padding.left
    }
    let child_y = if has_vertical_inset {
      match params.inset_top {
        Some(t) => t + params.margin_top + border.top
        None =>
          match params.inset_bottom {
            Some(b) =>
              final_height -
              child_height -
              b -
              params.margin_bottom -
              border.bottom
            None => params.margin_top + border.top
          }
      }
    } else {
      // Use justify_content for main-axis positioning (y for column direction)
      let free_space = final_height -
        child_height -
        params.margin_top -
        params.margin_bottom
      let is_wrap_reverse = match style.flex_wrap {
        @types.WrapReverse => true
        _ => false
      }
      let align_offset = if is_row {
        // For row, cross axis is vertical
        // Use align_self/align_items for cross axis (y)
        let offset = @alignment.compute_align_self_offset(
          child_style.align_self,
          style.align_items,
          free_space,
        )
        // WrapReverse flips cross-axis direction: Start <-> End
        if is_wrap_reverse && free_space > 0.0 {
          free_space - offset
        } else {
          offset
        }
      } else {
        // For column, main axis is vertical
        // Use justify_self/justify_content for main axis (y)
        @alignment.compute_align_self_offset(
          child_style.justify_self,
          style.justify_content,
          free_space,
        )
      }
      // When no inset, child is at content box position (border + padding)
      params.margin_top + align_offset + border.top + padding.top
    }
    // Use cached resolved rects (already computed above)
    let child_margin = child_resolved.margin

    // Build child layout
    let child_layout : @types.Layout = {
      id: child.id,
      x: child_x,
      y: child_y,
      width: child_width,
      height: child_height,
      margin: child_margin,
      padding: child_inner.padding,
      border: child_inner.border,
      overflow_x: child_style.overflow_x,
      overflow_y: child_style.overflow_y,
      children: child_inner.children,
      text: child.text,
    }
    indexed_layouts.push({ dom_index: i, layout: child_layout })
  }

  // Process fixed positioned children (relative to viewport)
  for i = 0; i < child_count; i = i + 1 {
    let child = children[i]
    let child_style = child.style

    // Only process fixed positioned children
    if child_style.position != @types.Fixed {
      continue
    }

    // Skip display:none children - create zero-sized layout
    if child_style.display == @types.Display::None {
      indexed_layouts.push({
        dom_index: i,
        layout: @absolute.create_zero_layout(child.id),
      })
      continue
    }

    // Use shared absolute module for size calculation with viewport as containing block
    let params = @absolute.compute_size_params(
      child_style,
      ctx.viewport_width,
      ctx.viewport_height,
    )

    // Apply aspect ratio to calculate missing dimension
    let (initial_width, initial_height) = @types.resolve_dimensions_with_aspect_ratio(
      params.initial_width,
      params.initial_height,
      child_style.aspect_ratio,
      params.min_width,
      params.max_width,
      params.min_height,
      params.max_height,
    )

    // Compute intrinsic size if needed
    let (child_width, child_height, child_inner) = match
      (initial_width, initial_height) {
      (Some(w), Some(h)) => {
        let inner = compute_nested(
          child,
          {
            available_width: w,
            available_height: Some(h),
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        (w, h, inner)
      }
      (Some(w), None) => {
        let inner = compute_nested(
          child,
          {
            available_width: w,
            available_height: None,
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        (w, inner.height, inner)
      }
      (None, Some(h)) => {
        // Width is auto: use shrink-to-fit approach
        let intrinsic_width = compute_intrinsic_main_size(
          child,
          is_row,
          Some(h),
          cache,
          dispatch,
        )
        let shrink_to_fit_width = if intrinsic_width < ctx.viewport_width {
          intrinsic_width
        } else {
          ctx.viewport_width
        }
        let inner = compute_nested(
          child,
          {
            available_width: shrink_to_fit_width,
            available_height: Some(h),
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        (shrink_to_fit_width, h, inner)
      }
      (None, None) => {
        // Both auto: use shrink-to-fit approach
        let intrinsic_width = compute_intrinsic_main_size(
          child,
          is_row,
          None,
          cache,
          dispatch,
        )
        let shrink_to_fit_width = if intrinsic_width < ctx.viewport_width {
          intrinsic_width
        } else {
          ctx.viewport_width
        }
        let inner = compute_nested(
          child,
          {
            available_width: shrink_to_fit_width,
            available_height: None,
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          },
          warnings,
          cache,
          dispatch,
        )
        (shrink_to_fit_width, inner.height, inner)
      }
    }

    // Apply min/max constraints
    let (child_width, child_height) = @absolute.apply_constraints_with_aspect_ratio(
      child_width,
      child_height,
      child_style,
      params.min_width,
      params.max_width,
      params.min_height,
      params.max_height,
    )

    // Check if margins are Auto (for centering behavior)
    let margin_left_is_auto = @absolute.is_margin_auto(child_style.margin.left)
    let margin_right_is_auto = @absolute.is_margin_auto(
      child_style.margin.right,
    )
    let margin_top_is_auto = @absolute.is_margin_auto(child_style.margin.top)
    let margin_bottom_is_auto = @absolute.is_margin_auto(
      child_style.margin.bottom,
    )

    // Calculate position relative to viewport
    let child_x = match (params.inset_left, params.inset_right) {
      (Some(l), Some(r)) =>
        if margin_left_is_auto && margin_right_is_auto {
          let available = ctx.viewport_width - l - r - child_width
          if available >= 0.0 {
            l + available / 2.0
          } else {
            l
          }
        } else if margin_left_is_auto {
          ctx.viewport_width - child_width - r - params.margin_right
        } else {
          l + params.margin_left
        }
      (Some(l), None) => l + params.margin_left
      (None, Some(r)) =>
        ctx.viewport_width - child_width - r - params.margin_right
      (None, None) => params.margin_left
    }
    let child_y = match (params.inset_top, params.inset_bottom) {
      (Some(t), Some(b)) =>
        if margin_top_is_auto && margin_bottom_is_auto {
          let available = ctx.viewport_height - t - b - child_height
          if available >= 0.0 {
            t + available / 2.0
          } else {
            t
          }
        } else if margin_top_is_auto {
          ctx.viewport_height - child_height - b - params.margin_bottom
        } else {
          t + params.margin_top
        }
      (Some(t), None) => t + params.margin_top
      (None, Some(b)) =>
        ctx.viewport_height - child_height - b - params.margin_bottom
      (None, None) => params.margin_top
    }
    // Use cached resolved rects
    let child_resolved = get_resolved_rects(
      child_style,
      child.uid,
      ctx.viewport_width,
    )

    // Build child layout
    let child_layout : @types.Layout = {
      id: child.id,
      x: child_x,
      y: child_y,
      width: child_width,
      height: child_height,
      margin: child_resolved.margin,
      padding: child_inner.padding,
      border: child_inner.border,
      overflow_x: child_style.overflow_x,
      overflow_y: child_style.overflow_y,
      children: child_inner.children,
      text: child.text,
    }
    indexed_layouts.push({ dom_index: i, layout: child_layout })
  }

  // Add display:none and display:contents children that were skipped during flex item processing
  // These children need to be in the final layout array with zero size (none) or wrapper structure (contents)
  for i = 0; i < child_count; i = i + 1 {
    let child = children[i]
    let child_style = child.style
    // Skip absolute/fixed children (already processed above)
    if child_style.position == @types.Absolute ||
      child_style.position == @types.Fixed {
      continue
    }
    // Add zero-sized layout for display:none children
    if child_style.display == @types.Display::None {
      indexed_layouts.push({ dom_index: i, layout: create_hidden_layout(child) })
      continue
    }
    // Handle display:contents children - build wrapper with collected layouts
    if child_style.display == @types.Contents {
      match contents_layouts.get(i) {
        Some(layouts_with_ancestors) => {
          // Build the contents tree structure
          // For simple case (single level of contents), just wrap the layouts
          let inner_layouts : Array[@types.Layout] = []
          for pair in layouts_with_ancestors {
            let (layout, _ancestors) = pair
            inner_layouts.push(layout)
          }
          let contents_layout = create_contents_layout(child, inner_layouts)
          indexed_layouts.push({ dom_index: i, layout: contents_layout })
        }
        None =>
          // Contents element with no children, create empty wrapper
          indexed_layouts.push({
            dom_index: i,
            layout: create_contents_layout(child, []),
          })
      }
    }
  }

  // Sort indexed_layouts by DOM index to restore original child order
  indexed_layouts.sort_by(fn(a, b) { a.dom_index - b.dom_index })

  // Extract layouts from indexed_layouts
  let child_layouts : Array[@types.Layout] = Array::new(
    capacity=indexed_layouts.length(),
  )
  for il in indexed_layouts {
    child_layouts.push(il.layout)
  }

  // If width is auto and is row direction, calculate actual width from child layouts
  // Note: Only non-absolute children should be counted for intrinsic width
  // IMPORTANT: For block-level flex containers with Definite sizing, use the already-calculated
  // container_width (which is parent_width - margins). Only calculate shrink-to-fit width
  // when in MaxContent sizing mode.
  let final_width = if width_is_auto && is_row && child_layouts.length() > 0 {
    match ctx.sizing_mode {
      @types.Definite =>
        // Block-level flex container: use container_width (already includes margin subtraction)
        container_width
      @types.MaxContent => {
        // Calculate content width used (only from non-absolute children)
        let mut max_x = 0.0
        let mut has_flow_children = false
        for i = 0; i < child_count; i = i + 1 {
          if children[i].style.position == @types.Absolute ||
            children[i].style.position == @types.Fixed {
            continue
          }
          if children[i].style.display == @types.Display::None {
            continue
          }
          has_flow_children = true
          let child_layout = child_layouts[i]
          let right_edge = child_layout.x +
            child_layout.width +
            child_layout.margin.right
          if right_edge > max_x {
            max_x = right_edge
          }
        }
        let content_width = if has_flow_children {
          max_x + padding.horizontal_sum() + border.horizontal_sum()
        } else {
          // No flow children - shrink to content (0) plus padding/border
          padding.horizontal_sum() + border.horizontal_sum()
        }
        // Apply min/max constraints to final width
        // CSS spec: min takes precedence over max
        let mut constrained_width = content_width
        match style.max_width {
          @types.Length(v) => if constrained_width > v { constrained_width = v }
          @types.Percent(p) => {
            let v = parent_width * p
            if constrained_width > v {
              constrained_width = v
            }
          }
          @types.Auto => ()
          @types.MinContent | @types.MaxContent | @types.FitContent(_) => ()
        }
        match style.min_width {
          @types.Length(v) => if constrained_width < v { constrained_width = v }
          @types.Percent(p) => {
            let v = parent_width * p
            if constrained_width < v {
              constrained_width = v
            }
          }
          @types.Auto => ()
          @types.MinContent | @types.MaxContent | @types.FitContent(_) => ()
        }
        constrained_width
      }
    }
  } else {
    container_width
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: final_width,
    height: final_height,
    margin,
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    children: child_layouts,
    text: node.text,
  }
}

///|
/// Compute nested children for a flex item
fn compute_nested(
  node : @node.Node,
  ctx : @types.LayoutContext,
  _warnings : Array[@types.LayoutWarning],
  _cache : IntrinsicCache,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = node.style
  let parent_width = ctx.available_width
  let padding = @types.resolve_rect(style.padding, parent_width)
  let border = @types.resolve_rect(style.border, parent_width)

  // For leaf nodes, return intrinsic size based on style
  // A leaf with no content has intrinsic size of 0 (plus padding/border)
  if node.children.length() == 0 {
    // Get intrinsic size from MeasureFunc if available
    let intrinsic = match node.measure {
      Some(mf) => {
        let available_h = ctx.available_height.unwrap_or(0.0)
        Some((mf.func)(ctx.available_width, available_h))
      }
      None => None
    }

    // Check if explicit size is set, otherwise use intrinsic or fallback
    let width = match style.width {
      @types.Length(w) => w
      @types.Percent(p) => ctx.available_width * p
      @types.Auto =>
        match intrinsic {
          Some(intr) =>
            intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
      @types.MinContent =>
        match intrinsic {
          Some(intr) =>
            intr.min_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
      @types.MaxContent | @types.FitContent(_) =>
        match intrinsic {
          Some(intr) =>
            intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
    }
    let height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) =>
        match ctx.available_height {
          Some(ah) => ah * p
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.Auto =>
        match intrinsic {
          Some(intr) =>
            intr.max_height + padding.vertical_sum() + border.vertical_sum()
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.MinContent =>
        match intrinsic {
          Some(intr) =>
            intr.min_height + padding.vertical_sum() + border.vertical_sum()
          None => padding.vertical_sum() + border.vertical_sum()
        }
      @types.MaxContent | @types.FitContent(_) =>
        match intrinsic {
          Some(intr) =>
            intr.max_height + padding.vertical_sum() + border.vertical_sum()
          None => padding.vertical_sum() + border.vertical_sum()
        }
    }
    return {
      id: node.id,
      x: 0.0,
      y: 0.0,
      width,
      height,
      margin: @types.Rect::zero(),
      padding,
      border,
      overflow_x: node.style.overflow_x,
      overflow_y: node.style.overflow_y,
      children: [],
      text: node.text,
    }
  }

  // Use dispatcher for nested children to enable cache hits
  let @node.DispatchFn(dispatch_fn) = dispatch
  dispatch_fn(node, ctx, dispatch)
}

///|
/// Flex item intermediate data
priv struct FlexItem {
  index : Int // Index in flattened array (used for sorting)
  original_child_index : Int // Index of immediate child of flex container (for DOM ordering)
  node : @node.Node // The actual node for this flex item
  order : Int // CSS order property for visual ordering
  base_main : Double
  base_cross : Double
  final_main : Double
  final_cross : Double
  margin_main : Double
  margin_cross : Double
  margin : @types.Rect[Double]
  flex_grow : Double
  flex_shrink : Double
  cross_is_auto : Bool
  min_main : Double // Resolved min constraint on main axis
  max_main : Double // Resolved max constraint on main axis (Infinity if none)
  frozen : Bool // Item is frozen (clamped to min/max)
  // Auto margin tracking for main axis
  margin_main_start_auto : Bool
  margin_main_end_auto : Bool
  // Auto margin tracking for cross axis
  margin_cross_start_auto : Bool
  margin_cross_end_auto : Bool
  // Baseline for baseline alignment (relative to item's cross start)
  baseline : Double
  // Align self for this item (resolved from style)
  align_self : @types.AlignSelf
  // Contents ancestors for display: contents support
  // Empty for direct children, contains parent nodes for nested contents
  contents_ancestors : Array[@node.Node]
}

///|
/// Flex line for wrap support
priv struct FlexLine {
  items : Array[FlexItem]
  cross_size : Double // Height of this line (in row layout)
}

///|
/// Calculate line cross size considering baseline alignment
/// For baseline alignment, line height = max_baseline_above + max_baseline_below
/// where baseline_above = margin_top + baseline (distance from cross-start to baseline)
/// and baseline_below = item_cross - baseline + margin_bottom (distance from baseline to cross-end)
fn compute_line_cross_size(
  items : Array[FlexItem],
  align_items : @types.Alignment,
  is_row : Bool,
) -> Double {
  // Fast path: if align_items is not Baseline, check if any item has align_self=Baseline
  // Most layouts don't use baseline alignment, so we can skip the complex calculation
  if align_items != @types.Baseline {
    // Quick scan for any baseline-aligned items
    let mut has_baseline_item = false
    for item in items {
      match item.align_self {
        @types.AlignSelf::Baseline => {
          has_baseline_item = true
          break
        }
        _ => ()
      }
    }
    if not(has_baseline_item) {
      // No baseline items - use simple max calculation
      let mut max_cross = 0.0
      for item in items {
        max_cross = max(max_cross, item.final_cross + item.margin_cross)
      }
      return max_cross
    }
  }

  // Full baseline-aware calculation
  let mut max_baseline_above = 0.0
  let mut max_baseline_below = 0.0
  let mut max_non_baseline_cross = 0.0
  let mut has_baseline_item = false
  for item in items {
    // Determine effective alignment for this item
    let effective_align = match item.align_self {
      @types.AlignSelf::Auto => align_items
      @types.AlignSelf::Baseline => @types.Baseline
      @types.AlignSelf::Start => @types.Start
      @types.AlignSelf::End => @types.End
      @types.AlignSelf::Center => @types.Center
      @types.AlignSelf::Stretch => @types.Stretch
    }

    // Check for auto margins which override alignment
    let has_cross_auto_margin = if is_row {
      item.margin_cross_start_auto || item.margin_cross_end_auto
    } else {
      item.margin_cross_start_auto || item.margin_cross_end_auto
    }

    // Use final_cross if available (after Phase 3), otherwise base_cross
    let item_cross = item.final_cross
    if not(has_cross_auto_margin) && effective_align == @types.Baseline {
      has_baseline_item = true
      // For baseline items, calculate above and below baseline
      let margin_start = if is_row { item.margin.top } else { item.margin.left }
      let margin_end = if is_row {
        item.margin.bottom
      } else {
        item.margin.right
      }
      let baseline_above = margin_start + item.baseline
      let baseline_below = item_cross - item.baseline + margin_end
      max_baseline_above = max(max_baseline_above, baseline_above)
      max_baseline_below = max(max_baseline_below, baseline_below)
    } else {
      // Non-baseline items contribute their full cross size
      max_non_baseline_cross = max(
        max_non_baseline_cross,
        item_cross + item.margin_cross,
      )
    }
  }
  if has_baseline_item {
    // Line cross size is max of:
    // 1. baseline_above + baseline_below (for baseline items)
    // 2. max non-baseline item cross size
    max(max_baseline_above + max_baseline_below, max_non_baseline_cross)
  } else {
    max_non_baseline_cross
  }
}

///|
/// Compute align-items positioning
fn compute_align(
  align : @types.Alignment,
  item_cross : Double,
  container_cross : Double,
  margin_cross : Double,
) -> Double {
  let available = container_cross - item_cross - margin_cross
  match align {
    @types.Start | @types.FlexStart => 0.0
    @types.End | @types.FlexEnd => available
    @types.Center => available / 2.0
    @types.Stretch => 0.0 // Already handled in cross size calculation
    @types.Baseline => available // For simple boxes, baseline = bottom = End alignment
    _ => 0.0 // Default to start for space-* alignments
  }
}
