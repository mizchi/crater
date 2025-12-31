///|
/// Create a zero-sized layout for a node (used for display:none)
/// Recursively creates zero layouts for all descendants
fn create_zero_layout(node : @node.Node) -> @node.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@node.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    children.push(create_zero_layout(node.children[i]))
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
    children,
  }
}

///|
/// Collapse two margins according to CSS rules:
/// - Both positive: use the larger one
/// - Both negative: use the more negative (smaller) one
/// - Mixed: add them (positive + negative)
fn collapse_margins(m1 : Double, m2 : Double) -> Double {
  if m1 >= 0.0 && m2 >= 0.0 {
    @types.max(m1, m2)
  } else if m1 <= 0.0 && m2 <= 0.0 {
    @types.min(m1, m2)
  } else {
    m1 + m2
  }
}

///|
/// Collapsed margins that escape from a child element
priv struct CollapsedMargins {
  top : Double? // Margin that escapes upward
  bottom : Double? // Margin that escapes downward
}

///|
/// Internal layout result with collapsed margin tracking
priv struct LayoutWithCollapse {
  layout : @node.Layout
  collapsed : CollapsedMargins
}

///|
/// Check if element can collapse through (zero height, no border/padding)
fn can_collapse_through(
  height : Double,
  border : @types.Rect[Double],
  padding : @types.Rect[Double],
) -> Bool {
  height == 0.0 && border.top == 0.0 && border.bottom == 0.0 && padding.top ==
  0.0 && padding.bottom == 0.0
}

///|
/// Compute layout with collapse at root level (no parent to escape to)
fn compute_root_layout(
  node : @node.Node,
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let result = compute_with_collapse(node, ctx, warnings)
  let layout = result.layout

  // At root level, escaped margins position children and add to height
  match result.collapsed.top {
    Some(escaped_margin) => {
      // Adjust first child position and height
      if layout.children.length() > 0 {
        // Need to adjust children positions by escaped margin
        let adjusted_children : Array[@node.Layout] = []
        for i = 0; i < layout.children.length(); i = i + 1 {
          let child = layout.children[i]
          // All children: shift by escaped margin
          adjusted_children.push({
            id: child.id,
            x: child.x,
            y: child.y + escaped_margin,
            width: child.width,
            height: child.height,
            margin: child.margin,
            padding: child.padding,
            border: child.border,
            children: child.children,
          })
        }
        // Calculate new height including escaped top margin
        let escaped_bottom = match result.collapsed.bottom {
          Some(m) => m
          None => 0.0
        }
        let new_height = layout.height + escaped_margin + escaped_bottom
        {
          id: layout.id,
          x: layout.x,
          y: layout.y,
          width: layout.width,
          height: new_height,
          margin: layout.margin,
          padding: layout.padding,
          border: layout.border,
          children: adjusted_children,
        }
      } else {
        layout
      }
    }
    None => {
      // No escaped top margin, just handle bottom
      match result.collapsed.bottom {
        Some(escaped_margin) => {
          {
            id: layout.id,
            x: layout.x,
            y: layout.y,
            width: layout.width,
            height: layout.height + escaped_margin,
            margin: layout.margin,
            padding: layout.padding,
            border: layout.border,
            children: layout.children,
          }
        }
        None => layout
      }
    }
  }
}

///|
/// Resolve a Rect[Dimension] (margin/padding/border) to Rect[Double]
fn resolve_rect(
  rect : @types.Rect[@types.Dimension],
  parent_width : Double,
) -> @types.Rect[Double] {
  {
    left: rect.left.resolve_or(parent_width, 0.0),
    right: rect.right.resolve_or(parent_width, 0.0),
    top: rect.top.resolve_or(parent_width, 0.0),
    bottom: rect.bottom.resolve_or(parent_width, 0.0),
  }
}

///|
/// Compute block layout with warnings for unsupported features
pub fn compute_with_warnings(
  node : @node.Node,
  ctx : @node.LayoutContext,
) -> @node.LayoutResult {
  let warnings : Array[@node.LayoutWarning] = []
  let layout = compute_root_layout(node, ctx, warnings)
  { layout, warnings }
}

///|
/// Compute block layout for a node and its children
pub fn compute(node : @node.Node, ctx : @node.LayoutContext) -> @node.Layout {
  let warnings : Array[@node.LayoutWarning] = []
  compute_root_layout(node, ctx, warnings)
}

///|
/// Internal function that computes layout with margin collapse tracking
fn compute_with_collapse(
  node : @node.Node,
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning],
) -> LayoutWithCollapse {
  let style = node.style

  // Check for unsupported features
  match style.float {
    @style.Left | @style.Right => warnings.push(@node.UnsupportedFloat(node.id))
    @style.None => ()
  }

  // Resolve box model
  let parent_width = ctx.available_width
  let parent_height = ctx.available_height.unwrap_or(0.0)
  let margin = resolve_rect(style.margin, parent_width)
  let padding = resolve_rect(style.padding, parent_width)
  let border = resolve_rect(style.border, parent_width)

  // Check if margins can collapse with children
  // Collapse blocked by: border, padding, or overflow hidden/scroll/auto
  let overflow_blocks = match (style.overflow_x, style.overflow_y) {
    (@style.Overflow::Visible, @style.Overflow::Visible) => false
    _ => true
  }
  let can_collapse_top = border.top == 0.0 && padding.top == 0.0 && not(
    overflow_blocks,
  )
  let can_collapse_bottom = border.bottom == 0.0 && padding.bottom == 0.0 && not(
    overflow_blocks,
  )

  // Box width
  let mut box_width = match style.width {
    @types.Length(w) => w
    @types.Percent(p) => parent_width * p
    @types.Auto => parent_width - margin.horizontal_sum()
  }

  // Apply min/max width constraints
  match style.min_width {
    @types.Length(min_w) => if box_width < min_w { box_width = min_w }
    @types.Percent(p) => {
      let min_w = parent_width * p
      if box_width < min_w {
        box_width = min_w
      }
    }
    @types.Auto => ()
  }
  match style.max_width {
    @types.Length(max_w) => if box_width > max_w { box_width = max_w }
    @types.Percent(p) => {
      let max_w = parent_width * p
      if box_width > max_w {
        box_width = max_w
      }
    }
    @types.Auto => ()
  }

  // Available width for children (content area)
  let child_available_width = box_width -
    padding.horizontal_sum() -
    border.horizontal_sum()

  // Calculate available height for children
  let child_available_height : Double? = match style.height {
    @types.Length(h) => Some(h - padding.vertical_sum() - border.vertical_sum())
    @types.Percent(p) =>
      Some(parent_height * p - padding.vertical_sum() - border.vertical_sum())
    @types.Auto => None
  }

  // Map to store layouts by original index
  let layout_map : Map[Int, @node.Layout] = {}

  // Collect flow children with their collapse info, original styles, and indices
  let flow_children : Array[LayoutWithCollapse] = []
  let flow_styles : Array[@style.Style] = []
  let flow_indices : Array[Int] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.display == @style.None {
      // Add zero-sized layout for display:none children (including descendants)
      layout_map[i] = create_zero_layout(child)
      continue
    }
    if child.style.position == @style.Absolute {
      continue
    }
    let child_ctx : @node.LayoutContext = {
      available_width: child_available_width,
      available_height: child_available_height,
    }
    flow_children.push(compute_with_collapse(child, child_ctx, warnings))
    flow_styles.push(child.style)
    flow_indices.push(i)
  }

  // Track escaped margins for parent
  let mut escaped_top : Double? = None
  let mut escaped_bottom : Double? = None
  let mut current_y = 0.0
  let mut prev_margin_bottom = 0.0

  for i = 0; i < flow_children.length(); i = i + 1 {
    let child_result = flow_children[i]
    let child_layout = child_result.layout
    let child_collapsed = child_result.collapsed
    let is_first = i == 0
    let is_last = i == flow_children.length() - 1

    // Get effective margins (including any that escaped from grandchildren)
    let effective_margin_top = match child_collapsed.top {
      Some(escaped) => collapse_margins(child_layout.margin.top, escaped)
      None => child_layout.margin.top
    }
    let effective_margin_bottom = match child_collapsed.bottom {
      Some(escaped) => collapse_margins(child_layout.margin.bottom, escaped)
      None => child_layout.margin.bottom
    }

    // Check if child collapses through
    // Blocked by: height, border, padding, overflow, aspect_ratio
    let child_style = flow_styles[i]
    let child_overflow_blocks = match (child_style.overflow_x, child_style.overflow_y) {
      (@style.Overflow::Visible, @style.Overflow::Visible) => false
      _ => true
    }
    let child_has_aspect_ratio = match child_style.aspect_ratio {
      Some(_) => true
      None => false
    }
    let collapses_through = can_collapse_through(
      child_layout.height,
      child_layout.border,
      child_layout.padding,
    ) && not(child_overflow_blocks) && not(child_has_aspect_ratio)

    // Calculate position and track escaping margins
    let child_y : Double = if is_first {
      if can_collapse_top {
        // First child margin escapes to parent
        if collapses_through {
          escaped_top = Some(collapse_margins(effective_margin_top, effective_margin_bottom))
          prev_margin_bottom = effective_margin_bottom
        } else {
          escaped_top = Some(effective_margin_top)
          prev_margin_bottom = effective_margin_bottom
        }
        padding.top + border.top // Child at y=0 relative to content
      } else {
        // Margin blocked by border/padding
        if collapses_through {
          prev_margin_bottom = collapse_margins(effective_margin_top, effective_margin_bottom)
        } else {
          prev_margin_bottom = effective_margin_bottom
        }
        current_y = effective_margin_top
        effective_margin_top + padding.top + border.top
      }
    } else {
      // Sibling collapse
      if collapses_through {
        // Collapse-through: element positioned after collapsed margin gap
        let all_collapsed = collapse_margins(
          prev_margin_bottom,
          collapse_margins(effective_margin_top, effective_margin_bottom),
        )
        prev_margin_bottom = all_collapsed
        // Position at the same y as where next sibling would be
        current_y + all_collapsed + padding.top + border.top
      } else {
        let collapsed = collapse_margins(prev_margin_bottom, effective_margin_top)
        current_y = current_y + collapsed
        prev_margin_bottom = effective_margin_bottom
        current_y + padding.top + border.top
      }
    }

    // Calculate x position considering margin auto
    let child_x = {
      let margin_left_auto = match child_style.margin.left {
        @types.Auto => true
        _ => false
      }
      let margin_right_auto = match child_style.margin.right {
        @types.Auto => true
        _ => false
      }
      // Available space for auto margins
      let available = child_available_width - child_layout.width -
        child_layout.margin.left - child_layout.margin.right
      if margin_left_auto && margin_right_auto {
        // Both auto: center
        let auto_margin = if available > 0.0 { available / 2.0 } else { 0.0 }
        auto_margin + padding.left + border.left
      } else if margin_left_auto {
        // Only left auto: push to right
        let auto_margin = if available > 0.0 { available } else { 0.0 }
        auto_margin + padding.left + border.left
      } else {
        // No auto or only right auto: use left margin
        child_layout.margin.left + padding.left + border.left
      }
    }

    // Position child and store in map with original index
    let positioned_layout : @node.Layout = {
      id: child_layout.id,
      x: child_x,
      y: child_y,
      width: child_layout.width,
      height: child_layout.height,
      margin: child_layout.margin,
      padding: child_layout.padding,
      border: child_layout.border,
      children: child_layout.children,
    }
    layout_map[flow_indices[i]] = positioned_layout

    // Update current_y (only if not collapsing through)
    if not(collapses_through) {
      if is_first && can_collapse_top {
        current_y = child_layout.height
      } else if is_first {
        current_y = effective_margin_top + child_layout.height
      } else {
        current_y = current_y + child_layout.height
      }
    }

    // Handle last child's bottom margin escape
    if is_last && can_collapse_bottom {
      escaped_bottom = Some(prev_margin_bottom)
    }
  }

  // Calculate content height
  let content_height = if flow_children.length() == 0 {
    0.0
  } else if can_collapse_bottom {
    @types.max(0.0, current_y) // Don't include escaped bottom margin
  } else {
    @types.max(0.0, current_y + prev_margin_bottom)
  }

  // Box height
  let mut box_height = match style.height {
    @types.Length(h) => h
    @types.Percent(p) => parent_height * p
    @types.Auto => content_height + padding.vertical_sum() + border.vertical_sum()
  }

  // Apply min/max height constraints
  match style.min_height {
    @types.Length(min_h) => if box_height < min_h { box_height = min_h }
    @types.Percent(p) => {
      let min_h = parent_height * p
      if box_height < min_h {
        box_height = min_h
      }
    }
    @types.Auto => ()
  }
  match style.max_height {
    @types.Length(max_h) => if box_height > max_h { box_height = max_h }
    @types.Percent(p) => {
      let max_h = parent_height * p
      if box_height > max_h {
        box_height = max_h
      }
    }
    @types.Auto => ()
  }

  // Now handle absolute positioned children
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.position == @style.Absolute {
      let abs_layout = layout_absolute_child(
        child,
        box_width,
        box_height,
        border,
        warnings,
      )
      layout_map[i] = abs_layout
    }
  }

  // Assemble child_layouts in original order
  let child_layouts : Array[@node.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    match layout_map.get(i) {
      Some(layout) => child_layouts.push(layout)
      None => () // Should not happen
    }
  }

  let layout : @node.Layout = {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: box_width,
    height: box_height,
    margin,
    padding,
    border,
    children: child_layouts,
  }

  { layout, collapsed: { top: escaped_top, bottom: escaped_bottom } }
}

///|
/// Layout an absolutely positioned child within a block container
fn layout_absolute_child(
  child : @node.Node,
  container_width : Double,
  container_height : Double,
  parent_border : @types.Rect[Double],
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let child_style = child.style

  // Handle display:none - return zero-sized layout
  if child_style.display == @style.None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation
  let params = @absolute.compute_size_params(
    child_style,
    container_width,
    container_height,
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
      let inner = compute_nested(child, w, Some(h), warnings)
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_nested(child, w, None, warnings)
      let h = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      let inner = compute_nested(child, container_width, Some(h), warnings)
      let w = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => inner.width
      }
      (w, h, inner)
    }
    (None, None) => {
      let inner = compute_nested(
        child,
        container_width,
        Some(container_height),
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

  // Check if margins are Auto (for centering behavior)
  let margin_left_is_auto = @absolute.is_margin_auto(child_style.margin.left)
  let margin_right_is_auto = @absolute.is_margin_auto(child_style.margin.right)
  let margin_top_is_auto = @absolute.is_margin_auto(child_style.margin.top)
  let margin_bottom_is_auto = @absolute.is_margin_auto(child_style.margin.bottom)

  // Calculate position
  // Note: For absolute positioning, the containing block is the padding box
  let child_x = match (params.inset_left, params.inset_right) {
    (Some(l), Some(r)) => {
      // Both insets specified
      // Check for margin auto centering behavior
      if margin_left_is_auto && margin_right_is_auto {
        // Both margins auto: center the element
        let available = container_width - l - r - child_width
        l + available / 2.0 + parent_border.left
      } else if margin_left_is_auto {
        // Only left margin auto: push to right
        container_width - child_width - r - params.margin_right + parent_border.left
      } else if margin_right_is_auto {
        // Only right margin auto: push to left
        l + params.margin_left + parent_border.left
      } else {
        // No auto margins: over-constrained, use left inset
        l + params.margin_left + parent_border.left
      }
    }
    (Some(l), None) => l + params.margin_left + parent_border.left
    (None, Some(r)) =>
      container_width - child_width - r - params.margin_right - parent_border.right
    (None, None) => params.margin_left + parent_border.left
  }

  let child_y = match (params.inset_top, params.inset_bottom) {
    (Some(t), Some(b)) => {
      // Both insets specified
      // Check for margin auto centering behavior
      if margin_top_is_auto && margin_bottom_is_auto {
        // Both margins auto: center the element
        let available = container_height - t - b - child_height
        t + available / 2.0 + parent_border.top
      } else if margin_top_is_auto {
        // Only top margin auto: push to bottom
        container_height - child_height - b - params.margin_bottom + parent_border.top
      } else if margin_bottom_is_auto {
        // Only bottom margin auto: push to top
        t + params.margin_top + parent_border.top
      } else {
        // No auto margins: over-constrained, use top inset
        t + params.margin_top + parent_border.top
      }
    }
    (Some(t), None) => t + params.margin_top + parent_border.top
    (None, Some(b)) =>
      container_height - child_height - b - params.margin_bottom - parent_border.bottom
    (None, None) => params.margin_top + parent_border.top
  }

  let child_margin = resolve_rect(child_style.margin, container_width)

  {
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
}

///|
/// Compute nested children for a block item
fn compute_nested(
  node : @node.Node,
  available_width : Double,
  available_height : Double?,
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let style = node.style
  let padding = resolve_rect(style.padding, available_width)
  let border = resolve_rect(style.border, available_width)

  // For leaf nodes, return intrinsic size based on style
  if node.children.length() == 0 {
    // Get intrinsic size from MeasureFunc if available
    let intrinsic = match node.measure {
      Some(mf) => {
        let available_h = available_height.unwrap_or(0.0)
        Some((mf.func)(available_width, available_h))
      }
      None => None
    }

    // Check if explicit size is set, otherwise use intrinsic or fallback
    let width = match style.width {
      @types.Length(w) => w
      @types.Percent(p) => available_width * p
      @types.Auto =>
        match intrinsic {
          Some(intr) => intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
    }
    let height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) =>
        match available_height {
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

  // For containers, recurse
  let ctx : @node.LayoutContext = {
    available_width,
    available_height,
  }
  compute_with_collapse(node, ctx, warnings).layout
}
