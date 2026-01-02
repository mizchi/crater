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
  height == 0.0 &&
  border.top == 0.0 &&
  border.bottom == 0.0 &&
  padding.top == 0.0 &&
  padding.bottom == 0.0
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
    Some(escaped_margin) =>
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
    None =>
      // No escaped top margin, just handle bottom
      match result.collapsed.bottom {
        Some(escaped_margin) =>
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
        None => layout
      }
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

  // Note: Float is now supported - no warning needed

  // Handle leaf nodes with MeasureFunc (e.g., text nodes)
  // These nodes have no children but need intrinsic size from their measure function
  if node.children.length() == 0 {
    match node.measure {
      Some(mf) => {
        let parent_width = ctx.available_width
        let parent_height = ctx.available_height.unwrap_or(0.0)
        let margin = @types.resolve_rect(style.margin, parent_width)
        let padding = @types.resolve_rect(style.padding, parent_width)
        let border = @types.resolve_rect(style.border, parent_width)
        let available_h = ctx.available_height.unwrap_or(0.0)
        let intrinsic = (mf.func)(parent_width, available_h)

        // Calculate width - constrained by parent width
        let box_width = match style.width {
          @types.Length(w) => w
          @types.Percent(p) => parent_width * p
          @types.Auto => {
            let content_width = intrinsic.max_width +
              padding.horizontal_sum() +
              border.horizontal_sum()
            // Text should not exceed parent width
            @types.min(content_width, parent_width)
          }
        }

        // Calculate height
        let box_height = match style.height {
          @types.Length(h) => h
          @types.Percent(p) => parent_height * p
          @types.Auto =>
            intrinsic.max_height +
            padding.vertical_sum() +
            border.vertical_sum()
        }
        return {
          layout: {
            id: node.id,
            x: 0.0,
            y: 0.0,
            width: box_width,
            height: box_height,
            margin,
            padding,
            border,
            children: [],
          },
          collapsed: { top: None, bottom: None },
        }
      }
      None => ()
    }
  }

  // Resolve box model
  // For MaxContent sizing, percentage values resolve to 0 (CSS intrinsic sizing spec)
  let parent_width = ctx.available_width
  let parent_height = ctx.available_height.unwrap_or(0.0)
  let is_intrinsic_sizing = match ctx.sizing_mode {
    @node.MaxContent => true
    @node.Definite => false
  }
  let margin = if is_intrinsic_sizing {
    @types.resolve_rect_intrinsic(style.margin)
  } else {
    @types.resolve_rect(style.margin, parent_width)
  }
  let padding = if is_intrinsic_sizing {
    @types.resolve_rect_intrinsic(style.padding)
  } else {
    @types.resolve_rect(style.padding, parent_width)
  }
  let border = @types.resolve_rect(style.border, parent_width)

  // Check if margins can collapse with children
  // Collapse blocked by: border, padding, or overflow hidden/scroll/auto
  let overflow_blocks = match (style.overflow_x, style.overflow_y) {
    (@style.Overflow::Visible, @style.Overflow::Visible) => false
    _ => true
  }
  let can_collapse_top = border.top == 0.0 &&
    padding.top == 0.0 &&
    not(overflow_blocks)
  let can_collapse_bottom = border.bottom == 0.0 &&
    padding.bottom == 0.0 &&
    not(overflow_blocks)

  // Box width - depends on sizing mode and aspect_ratio
  // For MaxContent mode with width:Auto, we need to compute content width
  let use_max_content = match (ctx.sizing_mode, style.width) {
    (@node.MaxContent, @types.Auto) => true
    _ => false
  }
  // Check if we can calculate width from height + aspect_ratio
  let width_from_aspect_ratio : Double? = match
    (style.width, style.height, style.aspect_ratio) {
    (@types.Auto, @types.Length(h), Some(ratio)) => {
      // Width = (height - padding - border) * ratio + padding + border
      let content_height = h - padding.vertical_sum() - border.vertical_sum()
      Some(
        content_height * ratio +
        padding.horizontal_sum() +
        border.horizontal_sum(),
      )
    }
    (@types.Auto, @types.Percent(p), Some(ratio)) => {
      let h = parent_height * p
      let content_height = h - padding.vertical_sum() - border.vertical_sum()
      Some(
        content_height * ratio +
        padding.horizontal_sum() +
        border.horizontal_sum(),
      )
    }
    _ => None
  }
  let mut box_width = match width_from_aspect_ratio {
    Some(w) => w
    None =>
      match style.width {
        @types.Length(w) => w
        @types.Percent(p) => parent_width * p
        @types.Auto =>
          if use_max_content {
            // Will be computed from content - use parent_width as initial value for children
            parent_width - margin.horizontal_sum()
          } else {
            parent_width - margin.horizontal_sum()
          }
      }
  }

  // Apply min/max width constraints
  // CSS spec: min-width takes precedence over max-width when they conflict
  // So apply max first, then min
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

  // Ensure box_width is at least padding + border (CSS rule: padding/border override max-size)
  let min_box_width = padding.horizontal_sum() + border.horizontal_sum()
  if box_width < min_box_width {
    box_width = min_box_width
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

  // Map to store static positions for absolute children (their position in flow order)
  let absolute_static_positions : Map[Int, Int] = {} // index -> flow position (0 = before all, 1 = after first flow child, etc.)

  // Collect flow children nodes, styles, and indices
  // Also track where absolute children appear in the flow order
  // And separate float elements for special handling
  let flow_nodes : Array[@node.Node] = []
  let flow_styles : Array[@style.Style] = []
  let flow_indices : Array[Int] = []
  let float_nodes : Array[@node.Node] = []
  let float_indices : Array[Int] = []
  let mut flow_position = 0
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.display == @style.None {
      // Add zero-sized layout for display:none children (including descendants)
      layout_map[i] = create_zero_layout(child)
      continue
    }
    if child.style.position == @style.Absolute {
      // Record where this absolute child appears in flow order
      absolute_static_positions[i] = flow_position
      continue
    }
    // Check if this is a float element
    match child.style.float {
      @style.Float::Left | @style.Float::Right => {
        float_nodes.push(child)
        float_indices.push(i)
        // Float elements still advance flow position for absolute static positioning
        flow_position = flow_position + 1
      }
      @style.Float::None => {
        flow_nodes.push(child)
        flow_styles.push(child.style)
        flow_indices.push(i)
        flow_position = flow_position + 1
      }
    }
  }

  // Create float context for managing float positions
  let float_ctx = @float.FloatContext::new(
    child_available_width,
    padding.left + border.left,
  )

  // For MaxContent mode, first determine max-content width from children's contributions
  if use_max_content {
    let mut max_content_width = 0.0
    // Check if root itself has MeasureFunc (leaf node with intrinsic size)
    match node.measure {
      Some(mf) => {
        let intrinsic = (mf.func)(0.0, 0.0)
        max_content_width = intrinsic.max_width
      }
      None => ()
    }
    for i = 0; i < flow_nodes.length(); i = i + 1 {
      let child = flow_nodes[i]
      let child_style = flow_styles[i]

      // For intrinsic sizing, percentage margins resolve to 0 (CSS spec)
      // Only fixed margins contribute to intrinsic width
      let child_margin_left : Double = match child_style.margin.left {
        @types.Length(l) => l
        @types.Percent(_) => 0.0
        @types.Auto => 0.0
      }
      let child_margin_right : Double = match child_style.margin.right {
        @types.Length(r) => r
        @types.Percent(_) => 0.0
        @types.Auto => 0.0
      }
      let child_margin_sum = child_margin_left + child_margin_right

      // Calculate child's intrinsic width contribution
      // Note: padding+border override explicit width if too small
      // For intrinsic sizing, percentage padding also resolves to 0
      let child_padding_left : Double = match child_style.padding.left {
        @types.Length(l) => l
        @types.Percent(_) => 0.0
        @types.Auto => 0.0
      }
      let child_padding_right : Double = match child_style.padding.right {
        @types.Length(r) => r
        @types.Percent(_) => 0.0
        @types.Auto => 0.0
      }
      let child_border = @types.resolve_rect(child_style.border, parent_width)
      let child_min_box = child_padding_left +
        child_padding_right +
        child_border.horizontal_sum()
      let child_intrinsic_width : Double = match child_style.width {
        @types.Length(w) => @types.max(w, child_min_box)
        @types.Percent(_) => child_min_box // At minimum, padding+border
        @types.Auto =>
          // For width:auto, use max-content of child's content
          // Leaf nodes with MeasureFunc use intrinsic size
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width + child_min_box, child_min_box)
            }
            None =>
              if child.children.length() == 0 {
                child_min_box // Leaf nodes with no content have padding+border as minimum
              } else {
                // Recursively compute child's max-content width
                let intrinsic_ctx : @node.LayoutContext = {
                  available_width: parent_width, // Use parent_width as reference for percentages
                  available_height: child_available_height,
                  sizing_mode: @node.MaxContent,
                }
                let child_result = compute_with_collapse(
                  child, intrinsic_ctx, warnings,
                )
                child_result.layout.width
              }
          }
      }
      let child_contribution = child_intrinsic_width + child_margin_sum
      if child_contribution > max_content_width {
        max_content_width = child_contribution
      }
    }
    // Update box_width from max-content
    box_width = max_content_width +
      padding.horizontal_sum() +
      border.horizontal_sum()
    // Re-apply min/max constraints (max first, then min for precedence)
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
    // Ensure box_width is at least padding + border (CSS rule: padding/border override max-size)
    if box_width < min_box_width {
      box_width = min_box_width
    }
  }

  // Calculate actual child_available_width from final box_width
  let actual_child_available_width = box_width -
    padding.horizontal_sum() -
    border.horizontal_sum()

  // Now compute children's actual layout with the resolved width
  let flow_children : Array[LayoutWithCollapse] = []
  for i = 0; i < flow_nodes.length(); i = i + 1 {
    let child = flow_nodes[i]
    let child_ctx : @node.LayoutContext = {
      available_width: actual_child_available_width,
      available_height: child_available_height,
      sizing_mode: @node.Definite,
    }
    // Flex containers establish a new BFC, so use dispatch for them
    // and don't participate in margin collapsing
    let child_result = match child.style.display {
      @style.Flex => {
        // Use global dispatcher if available, otherwise use block layout
        // (tests without dispatcher setup will use block layout as fallback)
        let layout = match @node.get_layout_dispatcher() {
          Some(_) => @node.dispatch_layout(child, child_ctx)
          None => compute_with_collapse(child, child_ctx, warnings).layout
        }
        { layout, collapsed: { top: None, bottom: None } }
      }
      _ => compute_with_collapse(child, child_ctx, warnings)
    }
    flow_children.push(child_result)
  }

  // Layout float elements
  // Float elements are positioned using the float context
  let float_layouts : Array[@node.Layout] = []
  for i = 0; i < float_nodes.length(); i = i + 1 {
    let child = float_nodes[i]
    let child_style = child.style

    // Resolve child's box model
    let child_margin = @types.resolve_rect(
      child_style.margin,
      actual_child_available_width,
    )
    let child_padding = @types.resolve_rect(
      child_style.padding,
      actual_child_available_width,
    )
    let child_border = @types.resolve_rect(
      child_style.border,
      actual_child_available_width,
    )

    // Calculate child's width (float elements use shrink-to-fit)
    let child_width = match child_style.width {
      @types.Length(w) => w
      @types.Percent(p) => actual_child_available_width * p
      @types.Auto => {
        // Shrink-to-fit: compute intrinsic width
        let intrinsic_ctx : @node.LayoutContext = {
          available_width: actual_child_available_width,
          available_height: child_available_height,
          sizing_mode: @node.MaxContent,
        }
        let intrinsic_layout = compute_with_collapse(
            child, intrinsic_ctx, warnings,
          ).layout
        @types.min(intrinsic_layout.width, actual_child_available_width)
      }
    }

    // Compute child layout with determined width
    let child_content_width = child_width -
      child_padding.horizontal_sum() -
      child_border.horizontal_sum()
    let child_ctx : @node.LayoutContext = {
      available_width: if child_content_width > 0.0 {
        child_content_width
      } else {
        0.0
      },
      available_height: child_available_height,
      sizing_mode: @node.Definite,
    }
    let child_inner = compute_with_collapse(child, child_ctx, warnings).layout

    // Get child dimensions
    let final_width = child_inner.width
    let final_height = child_inner.height

    // Place the float using float context
    let (float_x, float_y) = float_ctx.place_float(
      child_style.float,
      final_width,
      final_height,
      child_margin.left,
      child_margin.right,
      child_margin.top,
      child_margin.bottom,
      0.0, // Start from top
    )
    let float_layout : @node.Layout = {
      id: child.id,
      x: float_x,
      y: float_y,
      width: final_width,
      height: final_height,
      margin: child_margin,
      padding: child_inner.padding,
      border: child_inner.border,
      children: child_inner.children,
    }
    float_layouts.push(float_layout)
    layout_map[float_indices[i]] = float_layout
  }

  // Track escaped margins for parent
  let mut escaped_top : Double? = None
  let mut escaped_bottom : Double? = None

  // Track y positions after each flow child (for absolute static positioning)
  // flow_y_positions[i] = y position after flow child i
  let flow_y_positions : Array[Double] = []
  let mut current_y = 0.0
  let mut prev_margin_bottom = 0.0
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child_result = flow_children[i]
    let child_layout = child_result.layout
    let child_collapsed = child_result.collapsed
    let is_first = i == 0
    let is_last = i == flow_children.length() - 1
    let child_style = flow_styles[i]

    // Handle clear property - move current_y below cleared floats
    match child_style.clear {
      @style.Clear::Left | @style.Clear::Right | @style.Clear::Both => {
        let clear_y = float_ctx.get_clear_y(child_style.clear, current_y)
        if clear_y > current_y {
          current_y = clear_y
          prev_margin_bottom = 0.0 // Reset margin collapse after clear
        }
      }
      @style.Clear::None => ()
    }

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
    let child_overflow_blocks = match
      (child_style.overflow_x, child_style.overflow_y) {
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
      ) &&
      not(child_overflow_blocks) &&
      not(child_has_aspect_ratio)

    // Calculate position and track escaping margins
    let child_y : Double = if is_first {
      if can_collapse_top {
        // First child margin escapes to parent
        if collapses_through {
          escaped_top = Some(
            collapse_margins(effective_margin_top, effective_margin_bottom),
          )
          prev_margin_bottom = effective_margin_bottom
        } else {
          escaped_top = Some(effective_margin_top)
          prev_margin_bottom = effective_margin_bottom
        }
        padding.top + border.top // Child at y=0 relative to content
      } else {
        // Margin blocked by border/padding
        if collapses_through {
          prev_margin_bottom = collapse_margins(
            effective_margin_top, effective_margin_bottom,
          )
        } else {
          prev_margin_bottom = effective_margin_bottom
        }
        current_y = effective_margin_top
        effective_margin_top + padding.top + border.top
      }
      // Sibling collapse
    } else if collapses_through {
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
      let available = child_available_width -
        child_layout.width -
        child_layout.margin.left -
        child_layout.margin.right
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

    // Apply inset offset for relative positioned children
    let (final_x, final_y) = if child_style.position == @style.Relative {
      let inset = child_style.inset
      // X offset: left takes precedence over right
      // Percentages resolve against containing block width
      let x_offset = match inset.left {
        @types.Length(l) => l
        @types.Percent(p) => box_width * p
        @types.Auto =>
          match inset.right {
            @types.Length(r) => -r
            @types.Percent(p) => -(box_width * p)
            @types.Auto => 0.0
          }
      }
      // Y offset: top takes precedence over bottom
      // CSS spec: percentages for top/bottom resolve against containing block HEIGHT
      // If height is auto/indefinite, percentage resolves to 0
      let y_offset = match inset.top {
        @types.Length(t) => t
        @types.Percent(p) =>
          match child_available_height {
            Some(h) => (h + padding.vertical_sum() + border.vertical_sum()) * p
            None => 0.0 // Height is auto, percentage resolves to 0
          }
        @types.Auto =>
          match inset.bottom {
            @types.Length(b) => -b
            @types.Percent(p) =>
              match child_available_height {
                Some(h) =>
                  -((h + padding.vertical_sum() + border.vertical_sum()) * p)
                None => 0.0
              }
            @types.Auto => 0.0
          }
      }
      (child_x + x_offset, child_y + y_offset)
    } else {
      (child_x, child_y)
    }

    // Position child and store in map with original index
    let positioned_layout : @node.Layout = {
      id: child_layout.id,
      x: final_x,
      y: final_y,
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

    // Record y position after this flow child (for absolute static positioning)
    flow_y_positions.push(current_y)

    // Handle last child's bottom margin escape
    if is_last && can_collapse_bottom {
      escaped_bottom = Some(prev_margin_bottom)
    }
  }

  // Calculate content height
  // If this is a BFC (overflow is not visible), include float heights
  let float_height = if overflow_blocks {
    // BFC contains floats - include their height
    float_ctx.get_float_height()
  } else {
    0.0
  }
  let flow_content_height = if flow_children.length() == 0 {
    0.0
  } else if can_collapse_bottom {
    @types.max(0.0, current_y) // Don't include escaped bottom margin
  } else {
    @types.max(0.0, current_y + prev_margin_bottom)
  }
  let content_height = @types.max(flow_content_height, float_height)

  // Box height - consider aspect_ratio
  let mut box_height = match style.height {
    @types.Length(h) => h
    @types.Percent(p) => parent_height * p
    @types.Auto =>
      match style.aspect_ratio {
        Some(ratio) => {
          // Height from aspect ratio: height = width / ratio
          let content_width = box_width -
            padding.horizontal_sum() -
            border.horizontal_sum()
          content_width / ratio + padding.vertical_sum() + border.vertical_sum()
        }
        None => content_height + padding.vertical_sum() + border.vertical_sum()
      }
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

  // Ensure box_height is at least padding + border (CSS rule: padding/border override max-size)
  let min_box_height = padding.vertical_sum() + border.vertical_sum()
  if box_height < min_box_height {
    box_height = min_box_height
  }

  // If aspect_ratio is set and height was constrained but width wasn't explicitly set,
  // recalculate width based on the constrained height
  match (style.aspect_ratio, style.width, style.height) {
    (Some(ratio), @types.Auto, @types.Auto) if ratio > 0.0 => {
      // Check if height was actually constrained by min/max
      let expected_height_from_width = (
          box_width - padding.horizontal_sum() - border.horizontal_sum()
        ) /
        ratio +
        padding.vertical_sum() +
        border.vertical_sum()
      if box_height != expected_height_from_width {
        // Height was constrained, recalculate width from constrained height
        let content_height = box_height -
          padding.vertical_sum() -
          border.vertical_sum()
        let new_width = content_height * ratio +
          padding.horizontal_sum() +
          border.horizontal_sum()
        // Apply min/max width constraints to new width
        let new_width = match style.max_width {
          @types.Length(max_w) =>
            if new_width > max_w {
              max_w
            } else {
              new_width
            }
          @types.Percent(p) => {
            let max_w = parent_width * p
            if new_width > max_w {
              max_w
            } else {
              new_width
            }
          }
          @types.Auto => new_width
        }
        let new_width = match style.min_width {
          @types.Length(min_w) =>
            if new_width < min_w {
              min_w
            } else {
              new_width
            }
          @types.Percent(p) => {
            let min_w = parent_width * p
            if new_width < min_w {
              min_w
            } else {
              new_width
            }
          }
          @types.Auto => new_width
        }
        box_width = new_width
      }
    }
    _ => ()
  }

  // Now handle absolute positioned children
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.position == @style.Absolute {
      // Get static y position for this absolute child
      let static_y = match absolute_static_positions.get(i) {
        Some(pos) =>
          // pos is the flow position (0 = before all flow children, 1 = after first, etc.)
          if pos == 0 {
            0.0
          } else if pos <= flow_y_positions.length() {
            flow_y_positions[pos - 1]
          } else {
            content_height
          }
        None => content_height // Default to end of flow content
      }
      let abs_layout = layout_absolute_child(
        child, box_width, box_height, border, static_y, warnings,
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
  static_y : Double, // Y position where the element would be in normal flow
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let child_style = child.style

  // Handle display:none - return zero-sized layout
  if child_style.display == @style.None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation
  let params = @absolute.compute_size_params(
    child_style, container_width, container_height,
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
      // Width is auto: use shrink-to-fit approach
      // Step 1: Compute intrinsic width using MaxContent sizing
      let intrinsic = compute_nested_intrinsic(child, Some(h), warnings)
      // Shrink-to-fit: min(max-content, available_width)
      let shrink_to_fit_width = if intrinsic.width < container_width {
        intrinsic.width
      } else {
        container_width
      }
      let w = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => shrink_to_fit_width
      }
      // Step 2: Re-layout with definite width
      let inner = compute_nested(child, w, Some(h), warnings)
      (w, h, inner)
    }
    (None, None) => {
      // Both width and height are auto: use shrink-to-fit approach
      // Step 1: Compute intrinsic size using MaxContent sizing
      let intrinsic = compute_nested_intrinsic(child, None, warnings)
      // Shrink-to-fit: min(max-content, available_width)
      let shrink_to_fit_width = if intrinsic.width < container_width {
        intrinsic.width
      } else {
        container_width
      }
      match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let w = shrink_to_fit_width
          let h = w / ar
          // Re-layout with definite size
          let inner = compute_nested(child, w, Some(h), warnings)
          (w, h, inner)
        }
        _ => {
          // Re-layout with definite width
          let inner = compute_nested(child, shrink_to_fit_width, None, warnings)
          (shrink_to_fit_width, inner.height, inner)
        }
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
  let child_padding = @types.resolve_rect(child_style.padding, container_width)
  let child_border = @types.resolve_rect(child_style.border, container_width)
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

  // Check if margins are Auto (for centering behavior)
  let margin_left_is_auto = @absolute.is_margin_auto(child_style.margin.left)
  let margin_right_is_auto = @absolute.is_margin_auto(child_style.margin.right)
  let margin_top_is_auto = @absolute.is_margin_auto(child_style.margin.top)
  let margin_bottom_is_auto = @absolute.is_margin_auto(
    child_style.margin.bottom,
  )

  // Calculate position
  // Note: For absolute positioning, the containing block is the padding box
  let child_x = match (params.inset_left, params.inset_right) {
    (Some(l), Some(r)) =>
      // Both insets specified
      // Check for margin auto centering behavior
      if margin_left_is_auto && margin_right_is_auto {
        // Both margins auto: try to center the element
        let available = container_width - l - r - child_width
        if available >= 0.0 {
          // Enough space: center by distributing margins equally
          l + available / 2.0 + parent_border.left
        } else {
          // Not enough space: CSS spec says for LTR, margin-left becomes 0
          // This makes child overflow on the right side
          l + parent_border.left
        }
      } else if margin_left_is_auto {
        // Only left margin auto: push to right
        container_width -
        child_width -
        r -
        params.margin_right +
        parent_border.left
      } else if margin_right_is_auto {
        // Only right margin auto: push to left
        l + params.margin_left + parent_border.left
      } else {
        // No auto margins: over-constrained, use left inset
        l + params.margin_left + parent_border.left
      }
    (Some(l), None) => l + params.margin_left + parent_border.left
    (None, Some(r)) =>
      container_width -
      child_width -
      r -
      params.margin_right -
      parent_border.right
    (None, None) => params.margin_left + parent_border.left
  }
  let child_y = match (params.inset_top, params.inset_bottom) {
    (Some(t), Some(b)) =>
      // Both insets specified
      // Check for margin auto centering behavior
      if margin_top_is_auto && margin_bottom_is_auto {
        // Both margins auto: try to center the element
        let available = container_height - t - b - child_height
        if available >= 0.0 {
          // Enough space: center by distributing margins equally
          t + available / 2.0 + parent_border.top
        } else {
          // Not enough space: CSS spec says margin-top becomes 0
          // This makes child overflow on the bottom side
          t + parent_border.top
        }
      } else if margin_top_is_auto {
        // Only top margin auto: push to bottom
        container_height -
        child_height -
        b -
        params.margin_bottom +
        parent_border.top
      } else if margin_bottom_is_auto {
        // Only bottom margin auto: push to top
        t + params.margin_top + parent_border.top
      } else {
        // No auto margins: over-constrained, use top inset
        t + params.margin_top + parent_border.top
      }
    (Some(t), None) => t + params.margin_top + parent_border.top
    (None, Some(b)) =>
      container_height -
      child_height -
      b -
      params.margin_bottom -
      parent_border.bottom
    (None, None) => static_y + params.margin_top + parent_border.top
  }
  let child_margin = @types.resolve_rect(child_style.margin, container_width)
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
  let padding = @types.resolve_rect(style.padding, available_width)
  let border = @types.resolve_rect(style.border, available_width)

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
          Some(intr) =>
            intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
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
      children: [],
    }
  }

  // For containers, recurse
  let ctx : @node.LayoutContext = {
    available_width,
    available_height,
    sizing_mode: @node.Definite,
  }
  compute_with_collapse(node, ctx, warnings).layout
}

///|
/// Compute nested children for intrinsic sizing (MaxContent mode)
/// This is used for shrink-to-fit calculations in absolute positioning
fn compute_nested_intrinsic(
  node : @node.Node,
  available_height : Double?,
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let style = node.style
  // Use 0 for percentage resolution in intrinsic sizing
  let padding = @types.resolve_rect(style.padding, 0.0)
  let border = @types.resolve_rect(style.border, 0.0)

  // For leaf nodes, return intrinsic size based on style
  if node.children.length() == 0 {
    // Get intrinsic size from MeasureFunc if available
    let intrinsic = match node.measure {
      Some(mf) => {
        let available_h = available_height.unwrap_or(0.0)
        Some((mf.func)(0.0, available_h))
      }
      None => None
    }

    // For intrinsic sizing, percentage widths resolve to 0
    let width = match style.width {
      @types.Length(w) => w
      @types.Percent(_) => 0.0 // Percentage resolves to 0 in intrinsic sizing
      @types.Auto =>
        match intrinsic {
          Some(intr) =>
            intr.max_width + padding.horizontal_sum() + border.horizontal_sum()
          None => padding.horizontal_sum() + border.horizontal_sum()
        }
    }
    let height = match style.height {
      @types.Length(h) => h
      @types.Percent(_) => padding.vertical_sum() + border.vertical_sum()
      @types.Auto =>
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
      children: [],
    }
  }

  // For containers, use MaxContent sizing mode
  let ctx : @node.LayoutContext = {
    available_width: @double.infinity,
    available_height,
    sizing_mode: @node.MaxContent,
  }
  compute_with_collapse(node, ctx, warnings).layout
}
