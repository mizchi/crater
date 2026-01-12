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
    overflow_x: @style.Visible,
    overflow_y: @style.Visible,
    children,
    text: node.text,
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
/// Resolve a dimension to pixels for intrinsic sizing
/// Percentages resolve to 0 in intrinsic sizing mode
fn resolve_dimension_intrinsic(dim : @types.Dimension) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(_) => 0.0 // Percentages resolve to 0 in intrinsic sizing
    @types.Auto => 0.0
    @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
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
/// Flow child group for anonymous block box processing
/// When a block container has mixed inline/block children,
/// contiguous inline children are grouped together for IFC processing
priv enum FlowChildGroup {
  /// Contiguous inline elements (processed through IFC as anonymous block)
  InlineGroup(nodes~ : Array[@node.Node], indices~ : Array[Int])
  /// Single block-level element
  BlockChild(node~ : @node.Node, index~ : Int)
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
/// Calculate max-content width of children for intrinsic sizing
/// This is used when min-width or max-width is max-content/min-content
fn calculate_children_max_content_width(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let mut max_content_width = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      max_content_width = intrinsic.max_width
    }
    None => ()
  }
  // Calculate max-content width from children
  for child in node.children {
    // Skip display:none, absolute, fixed, and float elements
    if child.style.display == @style.None ||
      child.style.position == @style.Absolute ||
      child.style.position == @style.Fixed {
      continue
    }
    match child.style.float {
      @style.Float::Left | @style.Float::Right => continue
      @style.Float::None => ()
    }
    let child_style = child.style
    // Calculate child's margin contribution (percentages resolve to 0)
    let child_margin_left = resolve_dimension_intrinsic(child_style.margin.left)
    let child_margin_right = resolve_dimension_intrinsic(
      child_style.margin.right,
    )
    let child_margin_sum = child_margin_left + child_margin_right
    // Calculate child's padding (percentages resolve to 0)
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
    // Calculate child's intrinsic width
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
            // Recursively calculate for nested elements
            calculate_children_max_content_width(child, parent_width) +
            child_min_box
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        child_min_box
    }
    let child_contribution = child_intrinsic_width + child_margin_sum
    if child_contribution > max_content_width {
      max_content_width = child_contribution
    }
  }
  max_content_width
}

///|
/// Calculate max-content height of children for intrinsic sizing
/// This is used when min-height or max-height is max-content/min-content
fn calculate_children_max_content_height(
  node : @node.Node,
  parent_width : Double,
) -> Double {
  let mut total_height = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      total_height = intrinsic.min_height
    }
    None => ()
  }
  // Calculate height from children (simplified - sum of heights)
  for child in node.children {
    // Skip display:none, absolute, fixed elements
    if child.style.display == @style.None ||
      child.style.position == @style.Absolute ||
      child.style.position == @style.Fixed {
      continue
    }
    // Skip floats for height calculation in normal flow
    match child.style.float {
      @style.Float::Left | @style.Float::Right => continue
      @style.Float::None => ()
    }
    let child_style = child.style
    // Calculate child's vertical margins (percentages resolve to parent WIDTH, not height)
    let child_margin_top = resolve_dimension_intrinsic(child_style.margin.top)
    let child_margin_bottom = resolve_dimension_intrinsic(
      child_style.margin.bottom,
    )
    // Calculate child's padding and border
    let child_padding_top = resolve_dimension_intrinsic(child_style.padding.top)
    let child_padding_bottom = resolve_dimension_intrinsic(
      child_style.padding.bottom,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_top +
      child_padding_bottom +
      child_border.vertical_sum()
    // Calculate child's intrinsic height
    let child_intrinsic_height : Double = match child_style.height {
      @types.Length(h) => @types.max(h, child_min_box)
      @types.Percent(_) => child_min_box
      @types.Auto =>
        match child.measure {
          Some(mf) => {
            let intrinsic = (mf.func)(0.0, 0.0)
            @types.max(intrinsic.min_height + child_min_box, child_min_box)
          }
          None =>
            // Recursively calculate for nested elements
            calculate_children_max_content_height(child, parent_width) +
            child_min_box
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        child_min_box
    }
    // Add to total (simplified - not doing margin collapsing here)
    total_height = total_height +
      child_intrinsic_height +
      child_margin_top +
      child_margin_bottom
  }
  total_height
}

///|
/// Calculate total height contribution from children layouts
/// Used for display: contents elements where the parent needs children's height
/// Note: margins are handled through margin collapsing, not added to height
fn get_children_total_height(children : Array[@node.Layout]) -> Double {
  let mut total_height = 0.0
  for child in children {
    // Only count the child's box height, not margins
    // Margins are handled through margin collapsing in the parent
    total_height = total_height + child.height
  }
  total_height
}

///|
/// Check if flow_nodes contains both inline and block level elements
/// This determines whether we need anonymous block box processing
fn has_mixed_inline_block_content(flow_nodes : Array[@node.Node]) -> Bool {
  let mut has_inline = false
  let mut has_block = false
  for node in flow_nodes {
    if node.style.display == @style.None {
      continue
    }
    if @inline.is_inline_level(node.style.display) {
      has_inline = true
    } else {
      has_block = true
    }
    if has_inline && has_block {
      return true
    }
  }
  false
}

///|
/// Group contiguous inline elements together for anonymous block box processing
/// Block elements become individual BlockChild entries
/// Contiguous inline elements are grouped into InlineGroup entries
fn group_flow_children_for_anonymous_blocks(
  flow_nodes : Array[@node.Node],
  flow_indices : Array[Int],
) -> Array[FlowChildGroup] {
  let groups : Array[FlowChildGroup] = []
  let mut current_inline_nodes : Array[@node.Node] = []
  let mut current_inline_indices : Array[Int] = []
  for i = 0; i < flow_nodes.length(); i = i + 1 {
    let node = flow_nodes[i]
    let index = flow_indices[i]
    if @inline.is_inline_level(node.style.display) {
      // Add to current inline group
      current_inline_nodes.push(node)
      current_inline_indices.push(index)
    } else {
      // Block element: flush current inline group first
      if current_inline_nodes.length() > 0 {
        groups.push(
          InlineGroup(
            nodes=current_inline_nodes,
            indices=current_inline_indices,
          ),
        )
        current_inline_nodes = []
        current_inline_indices = []
      }
      // Add block child
      groups.push(BlockChild(node~, index~))
    }
  }
  // Flush remaining inline group
  if current_inline_nodes.length() > 0 {
    groups.push(
      InlineGroup(nodes=current_inline_nodes, indices=current_inline_indices),
    )
  }
  groups
}

///|
/// Result of mixed content layout processing
priv struct MixedContentResult {
  content_height : Double
  escaped_top : Double?
  escaped_bottom : Double?
}

///|
/// Compute layout for mixed inline/block content using anonymous block boxes
/// Each InlineGroup is processed through IFC, each BlockChild through block layout
fn compute_mixed_content_layout(
  groups : Array[FlowChildGroup],
  available_width : Double,
  available_height : Double?,
  padding : @types.Rect[Double],
  border : @types.Rect[Double],
  ctx : @node.LayoutContext,
  warnings : Array[@node.LayoutWarning],
  layout_map : Map[Int, @node.Layout],
) -> MixedContentResult {
  let mut current_y = 0.0
  let mut prev_margin_bottom = 0.0
  let mut escaped_top : Double? = None
  let mut escaped_bottom : Double? = None
  let content_offset_x = padding.left + border.left
  let content_offset_y = padding.top + border.top
  for i = 0; i < groups.length(); i = i + 1 {
    let group = groups[i]
    let is_first = i == 0
    let _is_last = i == groups.length() - 1
    match group {
      InlineGroup(nodes~, indices~) => {
        // Collapse previous block's bottom margin with anonymous block (no margin)
        // Anonymous blocks have no margin, so we just add current_y
        current_y = current_y + prev_margin_bottom
        prev_margin_bottom = 0.0
        // Process inline group through IFC (anonymous block box)
        let ifc_result = @inline.compute_ifc(
          nodes,
          available_width,
          available_height,
          content_offset_x,
          content_offset_y + current_y,
        )
        // Store layouts with original indices
        for j = 0; j < indices.length(); j = j + 1 {
          if j < ifc_result.layouts.length() {
            layout_map[indices[j]] = ifc_result.layouts[j]
          }
        }
        // Anonymous blocks don't have margins, so no collapse
        current_y = current_y + ifc_result.total_height
      }
      BlockChild(node~, index~) => {
        // Process block child with margin collapsing
        let child_ctx : @node.LayoutContext = {
          available_width,
          available_height,
          sizing_mode: @node.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
        }
        // Use dispatch_layout for flex/grid containers, block layout for others
        let child_layout = match node.style.display {
          @style.Flex | @style.InlineFlex | @style.Grid | @style.InlineGrid =>
            match @node.get_layout_dispatcher() {
              Some(_) => @node.dispatch_layout(node, child_ctx)
              None => compute_with_collapse(node, child_ctx, warnings).layout
            }
          _ => compute_with_collapse(node, child_ctx, warnings).layout
        }
        // Calculate margin values
        let margin_top = child_layout.margin.top
        let margin_bottom = child_layout.margin.bottom
        // Collapse margins
        let collapsed = collapse_margins(prev_margin_bottom, margin_top)
        // Handle first child - check if margin escapes
        if is_first && escaped_top is None {
          // Check if we can collapse through (parent has no padding/border top)
          if padding.top == 0.0 && border.top == 0.0 {
            escaped_top = Some(margin_top)
          } else {
            current_y = current_y + margin_top
          }
        } else {
          current_y = current_y + collapsed
        }
        // Position and store layout
        let positioned_layout : @node.Layout = {
          id: child_layout.id,
          x: content_offset_x + child_layout.margin.left,
          y: content_offset_y + current_y,
          width: child_layout.width,
          height: child_layout.height,
          margin: child_layout.margin,
          padding: child_layout.padding,
          border: child_layout.border,
          overflow_x: child_layout.overflow_x,
          overflow_y: child_layout.overflow_y,
          children: child_layout.children,
          text: child_layout.text,
        }
        layout_map[index] = positioned_layout
        // Update state
        current_y = current_y + child_layout.height
        prev_margin_bottom = margin_bottom
        escaped_bottom = Some(margin_bottom)
      }
    }
  }
  // Add final margin if not escaping
  if padding.bottom > 0.0 || border.bottom > 0.0 {
    current_y = current_y + prev_margin_bottom
    escaped_bottom = None
  }
  { content_height: current_y, escaped_top, escaped_bottom }
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
            overflow_x: child.overflow_x,
            overflow_y: child.overflow_y,
            children: child.children,
            text: child.text,
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
          overflow_x: layout.overflow_x,
          overflow_y: layout.overflow_y,
          children: adjusted_children,
          text: layout.text,
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
            overflow_x: layout.overflow_x,
            overflow_y: layout.overflow_y,
            children: layout.children,
            text: layout.text,
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

  // Handle display: contents - element doesn't generate a box but children do
  if style.display == @style.Contents {
    // Compute children layouts using parent context
    // Position children as if they were direct children of the parent
    let children_layouts : Array[@node.Layout] = []
    let mut current_y = 0.0
    let mut prev_margin_bottom = 0.0
    let mut first_child_margin_top : Double? = None
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      let child_result = compute_with_collapse(child, ctx, warnings)
      let child_layout = child_result.layout
      // Get child's margins
      let child_margin_top = child_layout.margin.top
      let child_margin_bottom = child_layout.margin.bottom
      // Track first child's margin for escape
      if i == 0 {
        first_child_margin_top = Some(child_margin_top)
      }
      // Collapse margins between siblings
      let collapsed = if i == 0 {
        0.0
      } else {
        collapse_margins(prev_margin_bottom, child_margin_top)
      }
      current_y = current_y + collapsed
      // Position child
      let positioned_child : @node.Layout = {
        id: child_layout.id,
        x: child_layout.x,
        y: current_y,
        width: child_layout.width,
        height: child_layout.height,
        margin: child_layout.margin,
        padding: child_layout.padding,
        border: child_layout.border,
        overflow_x: child_layout.overflow_x,
        overflow_y: child_layout.overflow_y,
        children: child_layout.children,
        text: child_layout.text,
      }
      children_layouts.push(positioned_child)
      current_y = current_y + child_layout.height
      prev_margin_bottom = child_margin_bottom
    }
    return {
      layout: {
        id: node.id,
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        margin: @types.Rect::zero(),
        padding: @types.Rect::zero(),
        border: @types.Rect::zero(),
        overflow_x: @style.Visible,
        overflow_y: @style.Visible,
        children: children_layouts,
        text: node.text,
      },
      // Pass through the first child's margin for collapse with siblings
      collapsed: {
        top: first_child_margin_top,
        bottom: Some(prev_margin_bottom),
      },
    }
  }

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

        // Resolve min/max constraints
        let min_width = style.min_width.resolve_or(parent_width, 0.0)
        let max_width = style.max_width.resolve_or(
          parent_width, @double.infinity,
        )
        let min_height = style.min_height.resolve_or(parent_height, 0.0)
        let max_height = style.max_height.resolve_or(
          parent_height, @double.infinity,
        )

        // Check if height/width are definite (non-Auto) for aspect_ratio handling
        let height_is_definite = match style.height {
          @types.Length(_) | @types.Percent(_) => true
          _ => false
        }
        let width_is_definite = match style.width {
          @types.Length(_) | @types.Percent(_) => true
          _ => false
        }

        // Calculate initial width
        // For replaced elements with aspect_ratio:
        // - If width is Auto AND height is definite, let aspect_ratio compute width
        let initial_width : Double? = match style.width {
          @types.Length(w) => Some(w)
          @types.Percent(p) => Some(parent_width * p)
          @types.Auto =>
            // If aspect_ratio is set and height is definite, use None to let aspect_ratio calculate
            if style.aspect_ratio is Some(_) && height_is_definite {
              None
            } else {
              let content_width = intrinsic.max_width +
                padding.horizontal_sum() +
                border.horizontal_sum()
              // Text should not exceed parent width
              Some(@types.min(content_width, parent_width))
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            Some(parent_width)
        }

        // Calculate initial height
        // For replaced elements with aspect_ratio:
        // - If height is Auto AND width is definite, let aspect_ratio compute height
        let initial_height : Double? = match style.height {
          @types.Length(h) => Some(h)
          @types.Percent(p) => Some(parent_height * p)
          @types.Auto =>
            // If aspect_ratio is set and width is definite, use None to let aspect_ratio calculate
            if style.aspect_ratio is Some(_) && width_is_definite {
              None
            } else {
              Some(
                intrinsic.max_height +
                padding.vertical_sum() +
                border.vertical_sum(),
              )
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            Some(0.0)
        }

        // Apply aspect_ratio and constraints
        let (final_width, final_height) = @types.resolve_dimensions_with_aspect_ratio(
          initial_width,
          initial_height,
          style.aspect_ratio,
          min_width,
          max_width,
          min_height,
          max_height,
        )
        let box_width = final_width.unwrap_or(0.0)
        let box_height = final_height.unwrap_or(0.0)

        // Re-apply aspect_ratio after min/max constraints if needed
        let (box_width, box_height) = @absolute.apply_constraints_with_aspect_ratio(
          box_width, box_height, style, min_width, max_width, min_height, max_height,
        )
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
            overflow_x: style.overflow_x,
            overflow_y: style.overflow_y,
            children: [],
            text: node.text,
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
  // Collapse blocked by: border, padding, overflow hidden/scroll/auto, or display:flow-root
  // display:flow-root establishes a new BFC, which blocks margin collapse
  let overflow_blocks = match (style.overflow_x, style.overflow_y) {
    (@style.Overflow::Visible, @style.Overflow::Visible) => false
    _ => true
  }
  let establishes_bfc = overflow_blocks || style.display == @style.FlowRoot
  let can_collapse_top = border.top == 0.0 &&
    padding.top == 0.0 &&
    not(establishes_bfc)
  let can_collapse_bottom = border.bottom == 0.0 &&
    padding.bottom == 0.0 &&
    not(establishes_bfc)

  // Box width - depends on sizing mode and aspect_ratio
  // For MaxContent mode with width:Auto, or explicit width: max-content/min-content
  // InlineBlock elements also use shrink-to-fit (max-content) when width is auto
  let is_inline_block = style.display == @style.InlineBlock
  let use_max_content = match (ctx.sizing_mode, style.width) {
    (@node.MaxContent, @types.Auto) => true
    (_, @types.MaxContent) => true
    (_, @types.MinContent) => true
    (_, @types.FitContent(_)) => true
    (_, @types.Auto) if is_inline_block => true
    _ => false
  }
  // Check if we can calculate width from height + aspect_ratio
  let width_from_aspect_ratio : Double? = match
    (style.width, style.height, style.aspect_ratio) {
    (@types.Auto, @types.Length(h), Some(ratio)) =>
      // With box-sizing: border-box, aspect-ratio applies to border-box dimensions
      // With content-box (default), it applies to content dimensions
      if style.box_sizing == @style.BorderBox {
        // aspect-ratio applies to border-box: width = height * ratio
        Some(h * ratio)
      } else {
        // aspect-ratio applies to content-box:
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
      if style.box_sizing == @style.BorderBox {
        Some(h * ratio)
      } else {
        let content_height = h - padding.vertical_sum() - border.vertical_sum()
        Some(
          content_height * ratio +
          padding.horizontal_sum() +
          border.horizontal_sum(),
        )
      }
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
        @types.MinContent | @types.MaxContent =>
          // Will be computed from content - use parent_width as initial value
          parent_width - margin.horizontal_sum()
        @types.FitContent(_) =>
          // fit-content: use parent_width, will be clamped later
          parent_width - margin.horizontal_sum()
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
    @types.MaxContent | @types.MinContent => {
      // Calculate intrinsic width for max-width constraint
      // For elements with aspect-ratio, use the larger of:
      // 1. Children's max-content width
      // 2. Width from aspect-ratio (if height is specified)
      let children_width = calculate_children_max_content_width(
          node, parent_width,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      let aspect_width = match (style.aspect_ratio, style.height) {
        (Some(ar), @types.Length(h)) if ar > 0.0 =>
          if style.box_sizing == @style.BorderBox {
            h * ar
          } else {
            (h - padding.vertical_sum() - border.vertical_sum()) * ar +
            padding.horizontal_sum() +
            border.horizontal_sum()
          }
        (Some(ar), @types.Percent(p)) if ar > 0.0 => {
          let h = parent_height * p
          if style.box_sizing == @style.BorderBox {
            h * ar
          } else {
            (h - padding.vertical_sum() - border.vertical_sum()) * ar +
            padding.horizontal_sum() +
            border.horizontal_sum()
          }
        }
        _ => 0.0
      }
      let intrinsic_width = @types.max(children_width, aspect_width)
      if box_width > intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.Auto | @types.FitContent(_) => ()
  }
  match style.min_width {
    @types.Length(min_w) => if box_width < min_w { box_width = min_w }
    @types.Percent(p) => {
      let min_w = parent_width * p
      if box_width < min_w {
        box_width = min_w
      }
    }
    @types.MaxContent | @types.MinContent => {
      // Calculate intrinsic width of children
      let intrinsic_width = calculate_children_max_content_width(
          node, parent_width,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      if box_width < intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.Auto | @types.FitContent(_) => ()
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
    @types.Auto
    | @types.MinContent
    | @types.MaxContent
    | @types.FitContent(_) => None
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
    if child.style.position == @style.Absolute ||
      child.style.position == @style.Fixed {
      // Record where this absolute/fixed child appears in flow order
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
  // But if aspect-ratio calculated width is available, prefer that
  if use_max_content && width_from_aspect_ratio is None {
    let mut max_content_width = 0.0
    // CSS Containment: contain: inline-size means intrinsic width is 0 (no content contribution)
    let skip_content_contribution = style.contain.inline_size ||
      style.contain.size
    if not(skip_content_contribution) {
      // Check if root itself has MeasureFunc (leaf node with intrinsic size)
      match node.measure {
        Some(mf) => {
          let intrinsic = (mf.func)(0.0, 0.0)
          max_content_width = intrinsic.max_width
        }
        None => ()
      }
    }
    // Skip children content calculation when contain: inline-size or size is set
    if not(skip_content_contribution) {
      for i = 0; i < flow_nodes.length(); i = i + 1 {
        let child = flow_nodes[i]
        let child_style = flow_styles[i]

        // For intrinsic sizing, percentage margins resolve to 0 (CSS spec)
        // Only fixed margins contribute to intrinsic width
        let child_margin_left : Double = match child_style.margin.left {
          @types.Length(l) => l
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_margin_right : Double = match child_style.margin.right {
          @types.Length(r) => r
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_margin_sum = child_margin_left + child_margin_right

        // Calculate child's intrinsic width contribution
        // Note: padding+border override explicit width if too small
        // For intrinsic sizing, percentage padding also resolves to 0
        let child_padding_left : Double = match child_style.padding.left {
          @types.Length(l) => l
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_padding_right : Double = match child_style.padding.right {
          @types.Length(r) => r
          @types.Percent(_) => 0.0
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => 0.0
        }
        let child_border = @types.resolve_rect(child_style.border, parent_width)
        let child_min_box = child_padding_left +
          child_padding_right +
          child_border.horizontal_sum()
        // Helper function to calculate width from aspect-ratio
        fn calc_aspect_width(
          ratio : Double,
          h : Double,
          box_sizing : @style.BoxSizing,
          padding_v : Double,
          border_v : Double,
          padding_h : Double,
          border_h : Double,
          min_box : Double,
        ) -> Double {
          if box_sizing == @style.BorderBox {
            h * ratio
          } else {
            let content_height = h - padding_v - border_v
            if content_height > 0.0 {
              content_height * ratio + padding_h + border_h
            } else {
              min_box
            }
          }
        }

        let child_padding_v = resolve_dimension_intrinsic(
            child_style.padding.top,
          ) +
          resolve_dimension_intrinsic(child_style.padding.bottom)
        let child_intrinsic_width : Double = match child_style.width {
          @types.Length(w) => @types.max(w, child_min_box)
          @types.Percent(_) => child_min_box // At minimum, padding+border
          @types.Auto =>
            // For width:auto, check if aspect-ratio can determine width from height
            // This applies to both MeasureFunc elements (canvas, img) and regular elements
            match (child_style.aspect_ratio, child_style.height) {
              (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
                // Height is explicit length, use aspect-ratio
                calc_aspect_width(
                  ratio,
                  h,
                  child_style.box_sizing,
                  child_padding_v,
                  child_border.vertical_sum(),
                  child_padding_left + child_padding_right,
                  child_border.horizontal_sum(),
                  child_min_box,
                )
              (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
                // Height is percentage, resolve from parent height
                match child_available_height {
                  Some(parent_content_h) => {
                    // child_available_height is already content height of parent
                    // Add back padding+border to get border-box height for percentage
                    let parent_h = parent_content_h +
                      padding.vertical_sum() +
                      border.vertical_sum()
                    let h = parent_h * p
                    calc_aspect_width(
                      ratio,
                      h,
                      child_style.box_sizing,
                      child_padding_v,
                      child_border.vertical_sum(),
                      child_padding_left + child_padding_right,
                      child_border.horizontal_sum(),
                      child_min_box,
                    )
                  }
                  None => child_min_box // Parent has no definite height
                }
              _ =>
                // No aspect-ratio or height is auto, fall back to intrinsic/content width
                match child.measure {
                  Some(mf) => {
                    let intrinsic = (mf.func)(0.0, 0.0)
                    @types.max(
                      intrinsic.max_width + child_min_box,
                      child_min_box,
                    )
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
                        viewport_width: ctx.viewport_width,
                        viewport_height: ctx.viewport_height,
                      }
                      let child_result = compute_with_collapse(
                        child, intrinsic_ctx, warnings,
                      )
                      child_result.layout.width
                    }
                }
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            child_min_box
        }
        let child_contribution = child_intrinsic_width + child_margin_sum
        if child_contribution > max_content_width {
          max_content_width = child_contribution
        }
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
      @types.MaxContent | @types.MinContent => {
        // Calculate intrinsic width of children
        let intrinsic_width = calculate_children_max_content_width(
            node, parent_width,
          ) +
          padding.horizontal_sum() +
          border.horizontal_sum()
        if box_width > intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.Auto | @types.FitContent(_) => ()
    }
    match style.min_width {
      @types.Length(min_w) => if box_width < min_w { box_width = min_w }
      @types.Percent(p) => {
        let min_w = parent_width * p
        if box_width < min_w {
          box_width = min_w
        }
      }
      @types.MaxContent | @types.MinContent => {
        // Calculate intrinsic width of children
        let intrinsic_width = calculate_children_max_content_width(
            node, parent_width,
          ) +
          padding.horizontal_sum() +
          border.horizontal_sum()
        if box_width < intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.Auto | @types.FitContent(_) => ()
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

  // Check if we should use Inline Formatting Context (IFC)
  // IFC is used when all flow children are inline-level elements
  // Only use IFC when the layout dispatcher is set (needed for proper InlineBlock layout)
  let use_ifc = @inline.should_establish_ifc(flow_nodes) &&
    @node.get_layout_dispatcher() is Some(_)
  // Check for mixed inline/block content (needs anonymous block boxes)
  let has_mixed = has_mixed_inline_block_content(flow_nodes)
  if use_ifc {
    // Use IFC for inline layout
    let ifc_result = @inline.compute_ifc(
      flow_nodes,
      actual_child_available_width,
      child_available_height,
      padding.left + border.left,
      padding.top + border.top,
    )

    // Store IFC layouts with original indices
    for i = 0; i < flow_indices.length(); i = i + 1 {
      if i < ifc_result.layouts.length() {
        layout_map[flow_indices[i]] = ifc_result.layouts[i]
      }
    }

    // Calculate box height from IFC content
    let content_height = ifc_result.total_height
    let mut box_height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) => parent_height * p
      @types.Auto =>
        content_height + padding.vertical_sum() + border.vertical_sum()
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        content_height + padding.vertical_sum() + border.vertical_sum()
    }

    // Apply min/max height constraints
    match style.min_height {
      @types.Length(min_h) => if box_height < min_h { box_height = min_h }
      @types.MaxContent | @types.MinContent => {
        let intrinsic_height = calculate_children_max_content_height(
            node, parent_width,
          ) +
          padding.vertical_sum() +
          border.vertical_sum()
        if box_height < intrinsic_height {
          box_height = intrinsic_height
        }
      }
      _ => ()
    }
    match style.max_height {
      @types.Length(max_h) => if box_height > max_h { box_height = max_h }
      @types.MaxContent | @types.MinContent => {
        let intrinsic_height = calculate_children_max_content_height(
            node, parent_width,
          ) +
          padding.vertical_sum() +
          border.vertical_sum()
        if box_height > intrinsic_height {
          box_height = intrinsic_height
        }
      }
      _ => ()
    }

    // Handle absolute children
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      if child.style.position == @style.Absolute {
        let abs_layout = layout_absolute_child(
          child, box_width, box_height, border, content_height, warnings,
        )
        layout_map[i] = abs_layout
      }
    }

    // Handle fixed children (positioned relative to viewport)
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      if child.style.position == @style.Fixed {
        let fixed_layout = layout_fixed_child(
          child,
          ctx.viewport_width,
          ctx.viewport_height,
          warnings,
        )
        layout_map[i] = fixed_layout
      }
    }

    // Assemble child_layouts in original order
    let child_layouts : Array[@node.Layout] = []
    for i = 0; i < node.children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(layout) => child_layouts.push(layout)
        None => ()
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
      overflow_x: style.overflow_x,
      overflow_y: style.overflow_y,
      children: child_layouts,
      text: node.text,
    }
    return { layout, collapsed: { top: None, bottom: None } }
  } else if has_mixed && @node.get_layout_dispatcher() is Some(_) {
    // Mixed inline/block content - use anonymous block boxes
    let groups = group_flow_children_for_anonymous_blocks(
      flow_nodes, flow_indices,
    )
    let mixed_result = compute_mixed_content_layout(
      groups, actual_child_available_width, child_available_height, padding, border,
      ctx, warnings, layout_map,
    )
    // Calculate box height from mixed content
    let content_height = mixed_result.content_height
    let mut box_height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) => parent_height * p
      @types.Auto =>
        content_height + padding.vertical_sum() + border.vertical_sum()
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        content_height + padding.vertical_sum() + border.vertical_sum()
    }
    // Apply min/max height constraints
    match style.min_height {
      @types.Length(min_h) => if box_height < min_h { box_height = min_h }
      @types.MaxContent | @types.MinContent => {
        let intrinsic_height = calculate_children_max_content_height(
            node, parent_width,
          ) +
          padding.vertical_sum() +
          border.vertical_sum()
        if box_height < intrinsic_height {
          box_height = intrinsic_height
        }
      }
      _ => ()
    }
    match style.max_height {
      @types.Length(max_h) => if box_height > max_h { box_height = max_h }
      @types.MaxContent | @types.MinContent => {
        let intrinsic_height = calculate_children_max_content_height(
            node, parent_width,
          ) +
          padding.vertical_sum() +
          border.vertical_sum()
        if box_height > intrinsic_height {
          box_height = intrinsic_height
        }
      }
      _ => ()
    }
    // Handle absolute children
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      if child.style.position == @style.Absolute {
        let abs_layout = layout_absolute_child(
          child, box_width, box_height, border, content_height, warnings,
        )
        layout_map[i] = abs_layout
      }
    }
    // Handle fixed children (positioned relative to viewport)
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      if child.style.position == @style.Fixed {
        let fixed_layout = layout_fixed_child(
          child,
          ctx.viewport_width,
          ctx.viewport_height,
          warnings,
        )
        layout_map[i] = fixed_layout
      }
    }
    // Assemble child_layouts in original order
    let child_layouts : Array[@node.Layout] = []
    for i = 0; i < node.children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(layout) => child_layouts.push(layout)
        None => ()
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
      overflow_x: style.overflow_x,
      overflow_y: style.overflow_y,
      children: child_layouts,
      text: node.text,
    }
    // Return with escaped margins from mixed content
    return {
      layout,
      collapsed: {
        top: mixed_result.escaped_top,
        bottom: mixed_result.escaped_bottom,
      },
    }
  }

  // Now compute children's actual layout with the resolved width (BFC path)
  let flow_children : Array[LayoutWithCollapse] = []
  for i = 0; i < flow_nodes.length(); i = i + 1 {
    let child = flow_nodes[i]
    // Flex, Grid, Table, and InlineBlock containers establish a new BFC, so use dispatch for them
    // and don't participate in margin collapsing
    let child_result = match child.style.display {
      @style.Flex
      | @style.InlineFlex
      | @style.Grid
      | @style.InlineGrid
      | @style.InlineBlock
      | @style.Table
      | @style.InlineTable => {
        // For BFC-establishing children with auto height, don't pass available_height
        // This allows them to size to their content rather than stretching to fill
        // the available space. Flex items are different - they get their final height
        // from their flex parent, which passes it as available_height.
        let child_height_for_ctx : Double? = match child.style.height {
          @types.Auto => None
          _ => child_available_height
        }
        let child_ctx : @node.LayoutContext = {
          available_width: actual_child_available_width,
          available_height: child_height_for_ctx,
          sizing_mode: @node.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
        }
        // Use global dispatcher if available, otherwise use block layout
        // (tests without dispatcher setup will use block layout as fallback)
        let layout = match @node.get_layout_dispatcher() {
          Some(_) => @node.dispatch_layout(child, child_ctx)
          None => compute_with_collapse(child, child_ctx, warnings).layout
        }
        { layout, collapsed: { top: None, bottom: None } }
      }
      _ => {
        let child_ctx : @node.LayoutContext = {
          available_width: actual_child_available_width,
          available_height: child_available_height,
          sizing_mode: @node.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
        }
        compute_with_collapse(child, child_ctx, warnings)
      }
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

    // For floats with explicit height, use that height for children's percentage resolution
    // This is important for intrinsic sizing when children have height: %
    let float_available_height : Double? = match child_style.height {
      @types.Length(h) =>
        Some(h - child_padding.vertical_sum() - child_border.vertical_sum())
      @types.Percent(p) =>
        match child_available_height {
          Some(parent_h) =>
            Some(
              parent_h * p -
              child_padding.vertical_sum() -
              child_border.vertical_sum(),
            )
          None => None
        }
      _ => child_available_height
    }

    // Calculate child's width (float elements use shrink-to-fit)
    let child_width = match child_style.width {
      @types.Length(w) => w
      @types.Percent(p) => actual_child_available_width * p
      @types.Auto => {
        // Shrink-to-fit: compute intrinsic width
        let intrinsic_ctx : @node.LayoutContext = {
          available_width: actual_child_available_width,
          available_height: float_available_height,
          sizing_mode: @node.MaxContent,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
        }
        // Use dispatch_layout for flex/grid elements, block layout for others
        let intrinsic_layout = match child_style.display {
          @style.Flex | @style.InlineFlex | @style.Grid | @style.InlineGrid =>
            match @node.get_layout_dispatcher() {
              Some(_) => @node.dispatch_layout(child, intrinsic_ctx)
              None =>
                compute_with_collapse(child, intrinsic_ctx, warnings).layout
            }
          _ => compute_with_collapse(child, intrinsic_ctx, warnings).layout
        }
        @types.min(intrinsic_layout.width, actual_child_available_width)
      }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        actual_child_available_width
    }

    // Compute child layout with determined width
    let child_content_width = child_width -
      child_padding.horizontal_sum() -
      child_border.horizontal_sum()
    // For BFC-establishing children (flex/grid) with auto height, don't pass available_height
    // This allows them to size to their content rather than stretching
    // Use float_available_height which accounts for float's own explicit height
    let child_height_for_ctx : Double? = match child_style.display {
      @style.Flex | @style.InlineFlex | @style.Grid | @style.InlineGrid =>
        match child_style.height {
          @types.Auto => None
          _ => float_available_height
        }
      _ => float_available_height
    }
    let child_ctx : @node.LayoutContext = {
      available_width: if child_content_width > 0.0 {
        child_content_width
      } else {
        0.0
      },
      available_height: child_height_for_ctx,
      sizing_mode: @node.Definite,
      viewport_width: ctx.viewport_width,
      viewport_height: ctx.viewport_height,
    }
    // Use dispatch_layout for flex/grid elements, block layout for others
    let child_inner = match child_style.display {
      @style.Flex | @style.InlineFlex | @style.Grid | @style.InlineGrid =>
        match @node.get_layout_dispatcher() {
          Some(_) => @node.dispatch_layout(child, child_ctx)
          None => compute_with_collapse(child, child_ctx, warnings).layout
        }
      _ => compute_with_collapse(child, child_ctx, warnings).layout
    }

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
      overflow_x: child.style.overflow_x,
      overflow_y: child.style.overflow_y,
      children: child_inner.children,
      text: child.text,
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
    // For display: contents, use children's height for collapse check
    let effective_height_for_collapse = if child_style.display ==
      @style.Contents {
      get_children_total_height(child_layout.children)
    } else {
      child_layout.height
    }
    let collapses_through = can_collapse_through(
        effective_height_for_collapse,
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

    // Apply inset offset for non-absolute positioned children
    // (Static and Relative both apply inset as offset from flow position)
    let (final_x, final_y) = if child_style.position != @style.Absolute &&
      child_style.position != @style.Fixed {
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
            @types.Auto
            | @types.MinContent
            | @types.MaxContent
            | @types.FitContent(_) => 0.0
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
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
            @types.Auto
            | @types.MinContent
            | @types.MaxContent
            | @types.FitContent(_) => 0.0
          }
        @types.MinContent | @types.MaxContent | @types.FitContent(_) => 0.0
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
      overflow_x: child_layout.overflow_x,
      overflow_y: child_layout.overflow_y,
      children: child_layout.children,
      text: child_layout.text,
    }
    layout_map[flow_indices[i]] = positioned_layout

    // Update current_y (only if not collapsing through)
    if not(collapses_through) {
      // For display: contents, use children's total height instead of element's height (which is 0)
      let effective_height = if child_style.display == @style.Contents {
        get_children_total_height(child_layout.children)
      } else {
        child_layout.height
      }
      if is_first && can_collapse_top {
        current_y = effective_height
      } else if is_first {
        current_y = effective_margin_top + effective_height
      } else {
        current_y = current_y + effective_height
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
  // If this is a BFC (overflow is not visible, or display:flow-root), include float heights
  let float_height = if establishes_bfc {
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
        Some(ratio) =>
          // With box-sizing: border-box, aspect-ratio applies to border-box dimensions
          if style.box_sizing == @style.BorderBox {
            // Height from aspect ratio on border-box: height = width / ratio
            box_width / ratio
          } else {
            // Height from aspect ratio on content-box: height = content_width / ratio
            let content_width = box_width -
              padding.horizontal_sum() -
              border.horizontal_sum()
            content_width / ratio +
            padding.vertical_sum() +
            border.vertical_sum()
          }
        None => content_height + padding.vertical_sum() + border.vertical_sum()
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      content_height + padding.vertical_sum() + border.vertical_sum()
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
    @types.MinContent | @types.MaxContent => {
      // min-height: min-content/max-content uses content height
      let min_h = content_height +
        padding.vertical_sum() +
        border.vertical_sum()
      if box_height < min_h {
        box_height = min_h
      }
    }
    @types.FitContent(_) => {
      // fit-content for min-height acts like min-content
      let min_h = content_height +
        padding.vertical_sum() +
        border.vertical_sum()
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
    @types.MinContent | @types.MaxContent => {
      // max-height: min-content/max-content caps at content height
      let max_h = content_height +
        padding.vertical_sum() +
        border.vertical_sum()
      if box_height > max_h {
        box_height = max_h
      }
    }
    @types.FitContent(_) => {
      // fit-content for max-height acts like max-content
      let max_h = content_height +
        padding.vertical_sum() +
        border.vertical_sum()
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
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => new_width
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
          @types.Auto
          | @types.MinContent
          | @types.MaxContent
          | @types.FitContent(_) => new_width
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

  // Handle fixed positioned children (relative to viewport)
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.position == @style.Fixed {
      let fixed_layout = layout_fixed_child(
        child,
        ctx.viewport_width,
        ctx.viewport_height,
        warnings,
      )
      layout_map[i] = fixed_layout
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
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    children: child_layouts,
    text: node.text,
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

  // Calculate actual min/max constraints, handling max-content/min-content
  // For intrinsic sizing, we need to compute the child's intrinsic size first
  let needs_intrinsic = match child_style.max_width {
    @types.MaxContent | @types.MinContent => true
    _ =>
      match child_style.max_height {
        @types.MaxContent | @types.MinContent => true
        _ =>
          match child_style.min_width {
            @types.MaxContent | @types.MinContent => true
            _ =>
              match child_style.min_height {
                @types.MaxContent | @types.MinContent => true
                _ => false
              }
          }
      }
  }
  let intrinsic_size = if needs_intrinsic {
    compute_nested_intrinsic(child, None, warnings)
  } else {
    child_inner
  }
  let actual_min_width = match child_style.min_width {
    @types.MaxContent | @types.MinContent => intrinsic_size.width
    _ => params.min_width
  }
  let actual_max_width = match child_style.max_width {
    @types.MaxContent | @types.MinContent => intrinsic_size.width
    _ => params.max_width
  }
  let actual_min_height = match child_style.min_height {
    @types.MaxContent | @types.MinContent => intrinsic_size.height
    _ => params.min_height
  }
  let actual_max_height = match child_style.max_height {
    @types.MaxContent | @types.MinContent => intrinsic_size.height
    _ => params.max_height
  }

  // Apply min/max constraints and re-apply aspect ratio
  let (child_width, child_height) = @absolute.apply_constraints_with_aspect_ratio(
    child_width, child_height, child_style, actual_min_width, actual_max_width, actual_min_height,
    actual_max_height,
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
    overflow_x: child_style.overflow_x,
    overflow_y: child_style.overflow_y,
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
  warnings : Array[@node.LayoutWarning],
) -> @node.Layout {
  let child_style = child.style

  // Handle display:none - return zero-sized layout
  if child_style.display == @style.None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation with viewport as containing block
  let params = @absolute.compute_size_params(
    child_style, viewport_width, viewport_height,
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
      let intrinsic = compute_nested_intrinsic(child, Some(h), warnings)
      let shrink_to_fit_width = if intrinsic.width < viewport_width {
        intrinsic.width
      } else {
        viewport_width
      }
      let w = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => shrink_to_fit_width
      }
      let inner = compute_nested(child, w, Some(h), warnings)
      (w, h, inner)
    }
    (None, None) => {
      // Both width and height are auto: use shrink-to-fit approach
      let intrinsic = compute_nested_intrinsic(child, None, warnings)
      let shrink_to_fit_width = if intrinsic.width < viewport_width {
        intrinsic.width
      } else {
        viewport_width
      }
      match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let w = shrink_to_fit_width
          let h = w / ar
          let inner = compute_nested(child, w, Some(h), warnings)
          (w, h, inner)
        }
        _ => {
          let inner = compute_nested(child, shrink_to_fit_width, None, warnings)
          (shrink_to_fit_width, inner.height, inner)
        }
      }
    }
  }

  // Calculate actual min/max constraints, handling max-content/min-content
  let actual_min_width = match child_style.min_width {
    @types.MaxContent | @types.MinContent => child_inner.width
    _ => params.min_width
  }
  let actual_max_width = match child_style.max_width {
    @types.MaxContent | @types.MinContent => child_inner.width
    _ => params.max_width
  }
  let actual_min_height = match child_style.min_height {
    @types.MaxContent | @types.MinContent => child_inner.height
    _ => params.min_height
  }
  let actual_max_height = match child_style.max_height {
    @types.MaxContent | @types.MinContent => child_inner.height
    _ => params.max_height
  }

  // Apply min/max constraints and re-apply aspect ratio
  let (child_width, child_height) = @absolute.apply_constraints_with_aspect_ratio(
    child_width, child_height, child_style, actual_min_width, actual_max_width, actual_min_height,
    actual_max_height,
  )

  // CSS rule: padding+border override explicit size constraints
  let child_padding = @types.resolve_rect(child_style.padding, viewport_width)
  let child_border = @types.resolve_rect(child_style.border, viewport_width)
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

  // Calculate position relative to viewport (0, 0)
  let child_x = match (params.inset_left, params.inset_right) {
    (Some(l), Some(r)) =>
      if margin_left_is_auto && margin_right_is_auto {
        let available = viewport_width - l - r - child_width
        if available >= 0.0 {
          l + available / 2.0
        } else {
          l
        }
      } else if margin_left_is_auto {
        viewport_width - child_width - r - params.margin_right
      } else if margin_right_is_auto {
        l + params.margin_left
      } else {
        l + params.margin_left
      }
    (Some(l), None) => l + params.margin_left
    (None, Some(r)) => viewport_width - child_width - r - params.margin_right
    (None, None) => params.margin_left // Default to 0 + margin
  }
  let child_y = match (params.inset_top, params.inset_bottom) {
    (Some(t), Some(b)) =>
      if margin_top_is_auto && margin_bottom_is_auto {
        let available = viewport_height - t - b - child_height
        if available >= 0.0 {
          t + available / 2.0
        } else {
          t
        }
      } else if margin_top_is_auto {
        viewport_height - child_height - b - params.margin_bottom
      } else if margin_bottom_is_auto {
        t + params.margin_top
      } else {
        t + params.margin_top
      }
    (Some(t), None) => t + params.margin_top
    (None, Some(b)) => viewport_height - child_height - b - params.margin_bottom
    (None, None) => params.margin_top // Default to 0 + margin
  }
  let child_margin = @types.resolve_rect(child_style.margin, viewport_width)
  {
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
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        padding.horizontal_sum() + border.horizontal_sum()
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
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        padding.vertical_sum() + border.vertical_sum()
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

  // For containers, recurse
  let ctx : @node.LayoutContext = {
    available_width,
    available_height,
    sizing_mode: @node.Definite,
    viewport_width: available_width,
    viewport_height: available_height.unwrap_or(0.0),
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
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        padding.horizontal_sum() + border.horizontal_sum()
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
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        padding.vertical_sum() + border.vertical_sum()
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

  // For containers, use MaxContent sizing mode
  let ctx : @node.LayoutContext = {
    available_width: @double.infinity,
    available_height,
    sizing_mode: @node.MaxContent,
    viewport_width: 0.0,
    viewport_height: available_height.unwrap_or(0.0),
  }
  compute_with_collapse(node, ctx, warnings).layout
}
