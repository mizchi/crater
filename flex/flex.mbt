// =============================================================================
// Flexbox Layout Implementation
// =============================================================================

///|
/// Layout with DOM index for sorting
priv struct IndexedLayout {
  dom_index : Int
  layout : @node.Layout
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
/// Compute the intrinsic (content-based) size of a node on the main axis
/// This is used when flex-basis and main size are both Auto
fn compute_intrinsic_main_size(
  node : @node.Node,
  is_row : Bool,
  available_cross : Double?,
) -> Double {
  let style = node.style
  let children = node.children

  // Leaf nodes have 0 intrinsic size (unless we support text/image intrinsic sizes)
  if children.length() == 0 {
    return 0.0
  }

  // For containers, compute based on display type and children
  match style.display {
    @style.Flex =>
      compute_intrinsic_flex_main_size(node, is_row, available_cross)
    @style.Block =>
      compute_intrinsic_block_main_size(node, is_row, available_cross)
    _ => 0.0
  }
}

///|
/// Compute intrinsic size for a flex container
/// parent_is_row: true = compute width, false = compute height
fn compute_intrinsic_flex_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
) -> Double {
  let style = node.style
  let children = node.children

  // Check if this flex container is row or column
  let child_is_row = match style.flex_direction {
    @style.Row | @style.RowReverse => true
    @style.Column | @style.ColumnReverse => false
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
      if child_style.display == @style.None {
        continue
      }
      if child_style.position == @style.Absolute {
        continue
      }
      let child_margin = @types.resolve_rect(child_style.margin, child_available_width)

      let child_main = if child_is_row {
        // Main axis is width
        match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          @types.Percent(p) =>
            child_available_width * p + child_margin.left + child_margin.right
          @types.Auto =>
            compute_intrinsic_main_size(child, true, None) +
            child_margin.left +
            child_margin.right
        }
      } else {
        // Main axis is height
        match child_style.height {
          @types.Length(h) => h + child_margin.top + child_margin.bottom
          @types.Percent(_) => child_margin.top + child_margin.bottom
          @types.Auto =>
            compute_intrinsic_main_size(child, false, Some(child_available_width)) +
            child_margin.top +
            child_margin.bottom
        }
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
    // Computing along this container's cross axis: max of children's sizes
    let mut max_cross = 0.0
    for i = 0; i < children.length(); i = i + 1 {
      let child = children[i]
      let child_style = child.style
      if child_style.display == @style.None {
        continue
      }
      if child_style.position == @style.Absolute {
        continue
      }
      let child_margin = @types.resolve_rect(child_style.margin, child_available_width)

      let child_cross = if child_is_row {
        // Cross axis is height (we want height for a Row container)
        match child_style.height {
          @types.Length(h) => h + child_margin.top + child_margin.bottom
          @types.Percent(_) => child_margin.top + child_margin.bottom
          @types.Auto =>
            compute_intrinsic_main_size(child, false, Some(child_available_width)) +
            child_margin.top +
            child_margin.bottom
        }
      } else {
        // Cross axis is width (we want width for a Column container)
        match child_style.width {
          @types.Length(w) => w + child_margin.left + child_margin.right
          @types.Percent(p) =>
            child_available_width * p + child_margin.left + child_margin.right
          @types.Auto =>
            compute_intrinsic_main_size(child, true, None) +
            child_margin.left +
            child_margin.right
        }
      }
      if child_cross > max_cross {
        max_cross = child_cross
      }
    }

    // Add padding and border on cross axis
    if child_is_row {
      max_cross + padding.top + padding.bottom + border.top + border.bottom
    } else {
      max_cross + padding.left + padding.right + border.left + border.right
    }
  }
}

///|
/// Compute intrinsic main size for a block container
fn compute_intrinsic_block_main_size(
  node : @node.Node,
  parent_is_row : Bool,
  available_cross : Double?,
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
      if child_style.display == @style.None {
        continue
      }
      if child_style.position == @style.Absolute {
        continue
      }
      let child_margin = @types.resolve_rect(child_style.margin, available_width)
      let child_width = match child_style.width {
        @types.Length(w) => w + child_margin.left + child_margin.right
        _ =>
          compute_intrinsic_main_size(child, true, None) +
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
      if child_style.display == @style.None {
        continue
      }
      if child_style.position == @style.Absolute {
        continue
      }
      let child_margin = @types.resolve_rect(child_style.margin, available_width)
      let child_height = match child_style.height {
        @types.Length(h) => h + child_margin.top + child_margin.bottom
        _ =>
          compute_intrinsic_main_size(child, false, Some(available_width)) +
          child_margin.top +
          child_margin.bottom
      }
      total_height = total_height + child_height
    }
    total_height + padding.top + padding.bottom + border.top + border.bottom
  }
}


///|
/// Compute the baseline of a node for baseline alignment
/// For leaf nodes: baseline = height (bottom of box)
/// For Column flex containers: baseline = first child's baseline
/// For Row flex containers: baseline = max baseline of first-row children
fn compute_node_baseline(node : @node.Node, node_height : Double) -> Double {
  let children = node.children

  // Leaf nodes: baseline is the bottom of the box
  if children.length() == 0 {
    return node_height
  }
  let style = node.style

  // Only Flex containers have special baseline behavior
  match style.display {
    @style.Flex =>
      match style.flex_direction {
        @style.Column | @style.ColumnReverse => {
          // For Column flex: baseline is first child's baseline
          // Find first in-flow child
          for i = 0; i < children.length(); i = i + 1 {
            let child = children[i]
            if child.style.display == @style.None {
              continue
            }
            if child.style.position == @style.Absolute {
              continue
            }
            // Get first child's height
            let child_height = match child.style.height {
              @types.Length(h) => h
              _ => 0.0 // For auto height, use 0 (will be computed later)
            }
            // Recursively compute child's baseline
            return compute_node_baseline(child, child_height)
          }
          // No in-flow children, use own height
          return node_height
        }
        _ => node_height // For Row flex: baseline is the bottom
      }
    _ => node_height
  }
}

///|
/// Compute flex layout for a node and its children
pub fn compute(node : @node.Node, ctx : @node.LayoutContext) -> @node.Layout {
  let warnings : Array[@node.LayoutWarning] = []
  compute_internal(node, ctx, warnings)
}

///|
/// Compute flex layout with warnings
pub fn compute_with_warnings(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.LayoutResult {
  let warnings : Array[@node.LayoutWarning] = []
  let layout = compute_internal(node, ctx, warnings)
  { layout, warnings }
}

///|
fn compute_internal(
  node : @node.Node,
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let style = node.style

  // Check for unsupported features
  match style.float {
    @style.Left | @style.Right => warnings.push(@node.UnsupportedFloat(node.id))
    @style.None => ()
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
  let mut container_width = match style.width {
    @types.Length(w) => w
    @types.Percent(p) => parent_width * p
    @types.Auto => parent_width - margin.horizontal_sum()
  }

  // Apply min/max width
  match style.min_width {
    @types.Length(v) => if container_width < v { container_width = v }
    @types.Percent(p) => {
      let v = parent_width * p
      if container_width < v {
        container_width = v
      }
    }
    @types.Auto => ()
  }
  match style.max_width {
    @types.Length(v) => if container_width > v { container_width = v }
    @types.Percent(p) => {
      let v = parent_width * p
      if container_width > v {
        container_width = v
      }
    }
    @types.Auto => ()
  }

  // Content area
  let content_width = container_width -
    padding.horizontal_sum() -
    border.horizontal_sum()
  let content_height : Double? = match style.height {
    @types.Length(h) => Some(h - padding.vertical_sum() - border.vertical_sum())
    @types.Percent(p) =>
      Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
    @types.Auto => None
  }

  // Determine main/cross axis based on flex-direction
  let is_row = match style.flex_direction {
    @style.Row | @style.RowReverse => true
    @style.Column | @style.ColumnReverse => false
  }
  let is_reverse = match style.flex_direction {
    @style.RowReverse | @style.ColumnReverse => true
    _ => false
  }

  // For main size, if container size is auto, we need special handling
  // min-height should only cause GROW (not SHRINK) when content < min
  // Get initial values (may be adjusted later for Column flex with min_height)
  let initial_main_size_defined = if is_row {
    true
  } else {
    content_height != None
  }
  let initial_main_size = if is_row {
    content_width
  } else {
    match content_height {
      Some(ch) => ch
      None => 0.0
    }
  }

  // Get min_height for Column flex auto height adjustment
  let min_main_for_grow : Double? = if not(is_row) && content_height == None {
    match style.min_height {
      @types.Length(min_h) =>
        Some(min_h - padding.vertical_sum() - border.vertical_sum())
      @types.Percent(p) =>
        Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
      @types.Auto => None
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
  let children = node.children
  let child_count = children.length()
  if child_count == 0 {
    // No children - just return container
    let container_height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) => parent_height * p
      @types.Auto => padding.vertical_sum() + border.vertical_sum()
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
      children: [],
    }
  }

  // Collect flex items info (skip display:none children)
  let flex_items : Array[FlexItem] = Array::new(capacity=child_count)
  let mut total_flex_grow = 0.0
  let mut total_flex_shrink = 0.0
  let mut total_base_main = 0.0
  for i = 0; i < child_count; i = i + 1 {
    let child = children[i]
    let child_style = child.style

    // Skip display:none children
    if child_style.display == @style.None {
      continue
    }

    // Skip absolutely positioned children (they don't participate in flex layout)
    if child_style.position == @style.Absolute {
      continue
    }
    let child_margin = @types.resolve_rect(child_style.margin, content_width)

    // Get explicit cross dimension value for aspect_ratio calculation
    let explicit_cross : Double? = if is_row {
      match child_style.height {
        @types.Length(h) => Some(h)
        @types.Percent(p) =>
          match content_height {
            Some(ch) => Some(ch * p)
            None => None
          }
        @types.Auto => None
      }
    } else {
      match child_style.width {
        @types.Length(w) => Some(w)
        @types.Percent(p) => Some(content_width * p)
        @types.Auto => None
      }
    }

    // Calculate base size on main axis (flex-basis takes priority over width/height)
    let base_main = match child_style.flex_basis {
      @types.Length(b) => b
      @types.Percent(p) =>
        if is_row {
          content_width * p
        } else {
          match content_height {
            Some(ch) => ch * p
            None => 0.0
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
                    @style.Wrap | @style.WrapReverse => true
                    _ => false
                  }
                  let is_row_flex = match child_style.flex_direction {
                    @style.Row | @style.RowReverse => true
                    _ => false
                  }
                  // Note: Check for wrap/direction regardless of explicit display
                  if is_wrap && is_row_flex {
                    content_width // Use available width for row wrap container
                  } else {
                    // Compute intrinsic width from children
                    compute_intrinsic_main_size(child, true, content_height)
                  }
                }
              }
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
                    @style.Wrap | @style.WrapReverse => true
                    _ => false
                  }
                  let is_col_flex = match child_style.flex_direction {
                    @style.Column | @style.ColumnReverse => true
                    _ => false
                  }
                  // Note: Check for wrap/direction regardless of explicit display
                  match content_height {
                    Some(ch) if is_wrap && is_col_flex =>
                      ch // Use available height for column wrap container
                    _ =>
                      // Compute intrinsic height from children
                      compute_intrinsic_main_size(child, false, Some(content_width))
                  }
                }
              }
          }
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
          }
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
          }
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
                  compute_intrinsic_main_size(child, false, Some(content_width)),
                  true,
                )
              } else {
                (0.0, true)
              }
          }
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
                @style.Wrap | @style.WrapReverse => true
                _ => false
              }
              let is_row_flex = match child_style.flex_direction {
                @style.Row | @style.RowReverse => true
                _ => false
              }
              // Note: Check for wrap/direction regardless of explicit display
              // (flex_wrap/flex_direction imply flex behavior)
              if is_wrap && is_row_flex {
                (content_width, true) // Use available width for row wrap container
              } else if child.children.length() > 0 {
                // Compute intrinsic width for containers with children
                (compute_intrinsic_main_size(child, true, content_height), true)
              } else {
                (0.0, true)
              }
            }
          }
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
    let (min_main, max_main) = if is_row {
      let min_w = match child_style.min_width {
        @types.Length(v) => v
        @types.Percent(p) => content_width * p
        @types.Auto =>
          // Auto min-width: use intrinsic content size for containers
          if child.children.length() > 0 {
            compute_intrinsic_main_size(child, true, content_height)
          } else {
            0.0
          }
      }
      let max_w = match child_style.max_width {
        @types.Length(v) => v
        @types.Percent(p) => content_width * p
        @types.Auto => 1.0e10 // Effectively infinity
      }
      (min_w, max_w)
    } else {
      let min_h = match child_style.min_height {
        @types.Length(v) => v
        @types.Percent(p) =>
          match content_height {
            Some(ch) => ch * p
            None => 0.0
          }
        @types.Auto =>
          // Auto min-height: use intrinsic content size for containers
          if child.children.length() > 0 {
            compute_intrinsic_main_size(child, false, Some(content_width))
          } else {
            0.0
          }
      }
      let max_h = match child_style.max_height {
        @types.Length(v) => v
        @types.Percent(p) =>
          match content_height {
            Some(ch) => ch * p
            None => 1.0e10
          }
        @types.Auto => 1.0e10
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
      compute_node_baseline(child, base_cross)
    } else {
      base_cross // For column flex, baseline = height (simplified)
    }
    let item : FlexItem = {
      index: i,
      base_main,
      base_cross,
      final_main: base_main,
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
    }
    flex_items.push(item)
    total_base_main = total_base_main + base_main + margin_main
    total_flex_grow = total_flex_grow + child_style.flex_grow
    total_flex_shrink = total_flex_shrink + child_style.flex_shrink
  }

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
    @style.Wrap | @style.WrapReverse => true
    @style.NoWrap => false
  }
  if should_wrap && main_size_defined {
    // Wrap mode: split items into lines based on main size overflow
    let mut current_line_items : Array[FlexItem] = Array::new()
    let mut current_line_main = 0.0
    let mut current_line_cross = 0.0
    for i = 0; i < flex_items.length(); i = i + 1 {
      let item = flex_items[i]
      let item_main_with_margin = item.base_main + item.margin_main
      let gap_if_not_first = if current_line_items.length() > 0 {
        main_gap
      } else {
        0.0
      }

      // Check if item fits in current line
      if current_line_items.length() > 0 &&
        current_line_main + gap_if_not_first + item_main_with_margin > main_size {
        // Start new line
        flex_lines.push({
          items: current_line_items,
          cross_size: current_line_cross,
        })
        current_line_items = Array::new()
        current_line_main = 0.0
        current_line_cross = 0.0
      }

      // Add item to current line
      if current_line_items.length() > 0 {
        current_line_main = current_line_main + main_gap
      }
      current_line_items.push(item)
      current_line_main = current_line_main + item_main_with_margin
      current_line_cross = max(
        current_line_cross,
        item.base_cross + item.margin_cross,
      )
    }

    // Don't forget the last line
    if current_line_items.length() > 0 {
      flex_lines.push({
        items: current_line_items,
        cross_size: current_line_cross,
      })
    }
  } else {
    // NoWrap: all items in one line
    let mut line_cross = 0.0
    for item in flex_items {
      line_cross = max(line_cross, item.base_cross + item.margin_cross)
    }
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
        for i = 0; i < flex_items.length(); i = i + 1 {
          let item = flex_items[i]
          if item.frozen {
            used_space = used_space + item.final_main + item.margin_main
          } else {
            used_space = used_space + item.base_main + item.margin_main
            // Scaled flex shrink factor = flex_shrink * flex_basis
            total_scaled_shrink = total_scaled_shrink +
              item.flex_shrink * item.base_main
          }
        }
        let overflow = used_space + total_gap_for_grow - main_size
        if overflow <= 0.0 || total_scaled_shrink == 0.0 {
          break
        }

        // Shrink unfrozen items proportionally to their scaled shrink factor
        let mut any_clamped = false
        for i = 0; i < flex_items.length(); i = i + 1 {
          let item = flex_items[i]
          if not(item.frozen) && item.flex_shrink > 0.0 {
            // Each item's shrink = overflow * (item_scaled_shrink / total_scaled_shrink)
            let item_scaled_shrink = item.flex_shrink * item.base_main
            let shrink_ratio = item_scaled_shrink / total_scaled_shrink
            let shrink_amount = overflow * shrink_ratio
            let target = max(0.0, item.base_main - shrink_amount)
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
          break
        }
      }
    }
  }

  // Apply min/max constraints on main axis
  for i = 0; i < flex_items.length(); i = i + 1 {
    let item = flex_items[i]
    let child_style = children[item.index].style
    let original_main = item.final_main
    let mut final_main = original_main
    if is_row {
      match child_style.min_width {
        @types.Length(v) => if final_main < v { final_main = v }
        @types.Percent(p) => {
          let v = content_width * p
          if final_main < v {
            final_main = v
          }
        }
        @types.Auto => ()
      }
      match child_style.max_width {
        @types.Length(v) => if final_main > v { final_main = v }
        @types.Percent(p) => {
          let v = content_width * p
          if final_main > v {
            final_main = v
          }
        }
        @types.Auto => ()
      }
    } else {
      match child_style.min_height {
        @types.Length(v) => if final_main < v { final_main = v }
        @types.Percent(p) =>
          match content_height {
            Some(ch) => {
              let v = ch * p
              if final_main < v {
                final_main = v
              }
            }
            None => ()
          }
        @types.Auto => ()
      }
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
    let child_style = children[item.index].style

    // Determine effective alignment (align-self overrides align-items)
    let effective_align = match child_style.align_self {
      @style.Auto => style.align_items
      @style.AlignSelf::Stretch => @style.Stretch
      _ => @style.Start
    } // Non-stretch align-self means don't stretch

    // For stretch alignment, item takes full cross size only if cross dimension is auto
    // For non-stretch with aspect_ratio, recalculate cross from constrained main dimension
    let final_cross = match effective_align {
      @style.Stretch =>
        if item.cross_is_auto {
          match cross_size {
            Some(cs) => cs - item.margin_cross
            None => item.base_cross
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
            None => item.base_cross
          }
        } else {
          item.base_cross
        }
    }

    // Apply min/max on cross axis
    let mut constrained_cross = final_cross
    if is_row {
      match child_style.min_height {
        @types.Length(v) => if constrained_cross < v { constrained_cross = v }
        _ => ()
      }
      match child_style.max_height {
        @types.Length(v) => if constrained_cross > v { constrained_cross = v }
        _ => ()
      }
    } else {
      match child_style.min_width {
        @types.Length(v) => if constrained_cross < v { constrained_cross = v }
        _ => ()
      }
      match child_style.max_width {
        @types.Length(v) => if constrained_cross > v { constrained_cross = v }
        _ => ()
      }
    }

    // Only update if cross size changed from base
    if constrained_cross != item.base_cross {
      flex_items[i] = { ..item, final_cross: constrained_cross }
    }
    max_cross = max(max_cross, constrained_cross + item.margin_cross)
  }

  // Phase 3.5: Sync updated items back to flex_lines and recalculate cross sizes
  // MoonBit creates new structs on update, so flex_lines[0].items may have stale data
  // For NoWrap mode, we need to copy the updated items back
  if not(should_wrap) && flex_lines.length() == 1 {
    // Copy updated flex_items to flex_lines[0]
    flex_lines[0] = { ..flex_lines[0], items: flex_items }
  }

  // Recalculate each line's cross_size based on final_cross
  for line_idx = 0; line_idx < flex_lines.length(); line_idx = line_idx + 1 {
    let line = flex_lines[line_idx]
    let mut new_cross_size = 0.0
    for i = 0; i < line.items.length(); i = i + 1 {
      let item = line.items[i]
      new_cross_size = max(new_cross_size, item.final_cross + item.margin_cross)
    }
    flex_lines[line_idx] = { ..line, cross_size: new_cross_size }
  }

  // Phase 4 & 5: Position items and build layouts
  // For multi-line (wrap), we need to process each line separately
  // Use IndexedLayout to preserve DOM order when mixing flex and absolute children
  let indexed_layouts : Array[IndexedLayout] = Array::new(
    capacity=child_count,
  )

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

  // Calculate line positions using align-content
  let cross_free_space = effective_cross - total_lines_cross

  // Handle align-content: Stretch - distribute extra space to lines
  // NOTE: Stretch applies to line SIZE even in single-line containers
  let line_count = flex_lines.length()
  if style.align_content == @style.Stretch &&
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
  let effective_align_content_for_position : @style.Alignment = if should_wrap {
    style.align_content
  } else {
    @style.Start
  }
  let (line_start_offset, line_gap) = @alignment.compute_justify(
    effective_align_content_for_position,
    cross_free_space,
    line_count,
  )
  // For Stretch, cross_free_space was distributed to lines, so use 0 for line_gap
  let effective_line_gap = if style.align_content == @style.Stretch {
    0.0
  } else {
    line_gap
  }
  let total_line_gap = cross_gap + effective_line_gap

  // Handle wrap-reverse: lines are positioned in reverse order on cross axis
  let is_wrap_reverse = match style.flex_wrap {
    @style.WrapReverse => true
    _ => false
  }

  // Process each line
  // For wrap-reverse, we start from the end of cross axis and work backwards
  let cross_size_resolved = match cross_size {
    Some(cs) => cs
    None => total_lines_cross
  }
  let mut cross_pos = if is_wrap_reverse {
    // Start from cross-end
    cross_size_resolved - line_start_offset
  } else {
    line_start_offset
  }
  for line_idx = 0; line_idx < flex_lines.length(); line_idx = line_idx + 1 {
    let line = flex_lines[line_idx]
    let line_items = line.items
    let line_cross_size = line.cross_size

    // For wrap-reverse, adjust cross_pos to position from end of line
    let line_cross_pos = if is_wrap_reverse {
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
    let line_free_space = main_size - line_main_used

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
        @style.Start => @style.Alignment::End
        @style.End => @style.Alignment::Start
        other => other
      }
    } else {
      style.justify_content
    }
    let (start_offset, justify_gap) = if auto_margin_count > 0 {
      (0.0, 0.0)
    } else {
      @alignment.compute_justify(effective_justify, line_free_space, line_item_count)
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
      let child = children[item.index]

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
      let effective_align = if has_cross_auto_margin {
        @style.Alignment::Start // Auto margins will handle alignment
      } else {
        match child.style.align_self {
          @style.Auto => style.align_items
          @style.AlignSelf::Start => @style.Start
          @style.AlignSelf::End => @style.End
          @style.AlignSelf::Center => @style.Center
          @style.AlignSelf::Stretch => @style.Stretch
        }
      }

      // For stretch, use line cross size (with min/max constraints) if cross_is_auto
      let item_cross = match effective_align {
        @style.Stretch =>
          if item.cross_is_auto {
            // Apply min/max constraints to stretched size
            let stretched = line_cross_size - item.margin_cross
            // item.final_cross already has constraints, use min of stretched and final_cross
            // to handle max constraints, and max with final_cross to handle min constraints
            let child = children[item.index]
            let child_style = child.style
            let mut constrained = stretched
            if is_row {
              match child_style.min_height {
                @types.Length(v) => if constrained < v { constrained = v }
                _ => ()
              }
              match child_style.max_height {
                @types.Length(v) => if constrained > v { constrained = v }
                _ => ()
              }
            } else {
              match child_style.min_width {
                @types.Length(v) => if constrained < v { constrained = v }
                _ => ()
              }
              match child_style.max_width {
                @types.Length(v) => if constrained > v { constrained = v }
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
          @style.Baseline => {
            let cross_start_margin = if is_row {
              item.margin.top
            } else {
              item.margin.left
            }
            max_baseline - item.baseline - cross_start_margin
          }
          _ =>
            compute_align(
              effective_align,
              item_cross,
              line_cross_size,
              item.margin_cross,
            )
        }
      }

      // For wrap-reverse, reverse the alignment within the line
      // Items that were at cross-start should now be at cross-end
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

      let (child_x, child_y) = if is_row {
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
      let (child_width, child_height) = if is_row {
        (item.final_main, item_cross)
      } else {
        (item_cross, item.final_main)
      }
      let child_layout : @node.Layout = if child.children.length() == 0 {
        let child_style = child.style
        let child_padding = @types.resolve_rect(child_style.padding, child_width)
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
          children: [],
        }
      } else {
        let child_ctx : @node.LayoutContext = {
          available_width: child_width,
          available_height: Some(child_height),
          sizing_mode: @node.Definite,
        }
        let nested_layout = compute_nested(child, child_ctx, warnings)
        {
          id: child.id,
          x: child_x,
          y: child_y,
          width: child_width,
          height: child_height,
          margin: item.margin,
          padding: nested_layout.padding,
          border: nested_layout.border,
          children: nested_layout.children,
        }
      }
      indexed_layouts.push({ dom_index: item.index, layout: child_layout })

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
    // For wrap-reverse, we move backwards (toward cross-start)
    cross_pos = if is_wrap_reverse {
      cross_pos - line_cross_size - total_line_gap
    } else {
      cross_pos + line_cross_size + total_line_gap
    }
  }

  // Calculate container height
  // For wrap mode, use total_lines_cross; for single line, use max_cross
  let container_height = match style.height {
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
  }

  // Apply min/max height
  let mut final_height = container_height
  match style.min_height {
    @types.Length(v) => if final_height < v { final_height = v }
    @types.Percent(p) => {
      let v = parent_height * p
      if final_height < v {
        final_height = v
      }
    }
    @types.Auto => ()
  }
  match style.max_height {
    @types.Length(v) => if final_height > v { final_height = v }
    @types.Percent(p) => {
      let v = parent_height * p
      if final_height > v {
        final_height = v
      }
    }
    @types.Auto => ()
  }

  // Process absolutely positioned children
  for i = 0; i < child_count; i = i + 1 {
    let child = children[i]
    let child_style = child.style

    // Only process absolutely positioned children
    if child_style.position != @style.Absolute {
      continue
    }

    // Skip display:none children - create zero-sized layout
    if child_style.display == @style.None {
      indexed_layouts.push({
        dom_index: i,
        layout: @absolute.create_zero_layout(child.id),
      })
      continue
    }

    // Use shared absolute module for size calculation
    let params = @absolute.compute_size_params(
      child_style,
      container_width,
      final_height,
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
    let (child_width, child_height, child_inner) = match (
      initial_width,
      initial_height,
    ) {
      (Some(w), Some(h)) => {
        let inner = compute_nested(
          child,
          { available_width: w, available_height: Some(h), sizing_mode: @node.Definite },
          warnings,
        )
        (w, h, inner)
      }
      (Some(w), None) => {
        let inner = compute_nested(
          child,
          { available_width: w, available_height: None, sizing_mode: @node.Definite },
          warnings,
        )
        (w, inner.height, inner)
      }
      (None, Some(h)) => {
        let inner = compute_nested(
          child,
          { available_width: container_width, available_height: Some(h), sizing_mode: @node.Definite },
          warnings,
        )
        (inner.width, h, inner)
      }
      (None, None) => {
        let inner = compute_nested(
          child,
          { available_width: container_width, available_height: Some(final_height), sizing_mode: @node.Definite },
          warnings,
        )
        match child_style.aspect_ratio {
          Some(ar) if ar > 0.0 => {
            let w = inner.width
            let h = w / ar
            (w, h, inner)
          }
          _ => (inner.width, inner.height, inner)
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
              container_width - child_width - r - params.margin_right - border.right
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
        @style.WrapReverse => true
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
      params.margin_left + align_offset + border.left
    }

    let child_y = if has_vertical_inset {
      match params.inset_top {
        Some(t) => t + params.margin_top + border.top
        None =>
          match params.inset_bottom {
            Some(b) =>
              final_height - child_height - b - params.margin_bottom - border.bottom
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
        @style.WrapReverse => true
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
      params.margin_top + align_offset + border.top
    }

    let child_margin = @types.resolve_rect(child_style.margin, container_width)

    // Build child layout
    let child_layout : @node.Layout = {
      id: child.id,
      x: child_x,
      y: child_y,
      width: child_width,
      height: child_height,
      margin: child_margin,
      padding: child_inner.padding,
      border: child_inner.border,
      children: child_inner.children,
    }
    indexed_layouts.push({ dom_index: i, layout: child_layout })
  }

  // Sort indexed_layouts by DOM index to restore original child order
  indexed_layouts.sort_by(fn(a, b) { a.dom_index - b.dom_index })

  // Extract layouts from indexed_layouts
  let child_layouts : Array[@node.Layout] = Array::new(
    capacity=indexed_layouts.length(),
  )
  for il in indexed_layouts {
    child_layouts.push(il.layout)
  }

  // If width is auto and is row direction, calculate actual width from child layouts
  let final_width = if width_is_auto && is_row && child_layouts.length() > 0 {
    // Calculate content width used
    let mut max_x = 0.0
    for child in child_layouts {
      let right_edge = child.x + child.width + child.margin.right
      if right_edge > max_x {
        max_x = right_edge
      }
    }
    max_x + padding.horizontal_sum() + border.horizontal_sum()
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
    children: child_layouts,
  }
}

///|
/// Compute nested children for a flex item
fn compute_nested(
  node : @node.Node,
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
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
          Some(intr) => intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
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
          Some(intr) => intr.max_height + padding.vertical_sum() + border.vertical_sum()
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
      children: [],
    }
  }

  // For containers, recurse based on display type
  match style.display {
    @style.Flex => compute_internal(node, ctx, warnings)
    _ =>
      // Default to flex for now (block will be handled by dispatcher)
      compute_internal(node, ctx, warnings)
  }
}

///|
/// Flex item intermediate data
priv struct FlexItem {
  index : Int
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
}

///|
/// Flex line for wrap support
priv struct FlexLine {
  items : Array[FlexItem]
  cross_size : Double // Height of this line (in row layout)
}

///|
/// Compute align-items positioning
fn compute_align(
  align : @style.Alignment,
  item_cross : Double,
  container_cross : Double,
  margin_cross : Double,
) -> Double {
  let available = container_cross - item_cross - margin_cross
  match align {
    @style.Start => 0.0
    @style.End => available
    @style.Center => available / 2.0
    @style.Stretch => 0.0 // Already handled in cross size calculation
    @style.Baseline => available // For simple boxes, baseline = bottom = End alignment
    _ => 0.0 // Default to start for space-* alignments
  }
}

