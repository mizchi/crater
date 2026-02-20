///|
/// Create a zero-sized layout for a node (used for display:none)
/// Recursively creates zero layouts for all descendants
fn create_zero_layout(node : @node.Node) -> @types.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@types.Layout] = []
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
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
/// Calculate scroll dimensions from children layouts
/// Returns (scroll_width, scroll_height) representing the scrollable content size
fn calculate_scroll_dimensions(
  container_width : Double,
  container_height : Double,
  padding : @types.Rect[Double],
  children : Array[@types.Layout],
) -> (Double, Double) {
  // Start with content box dimensions (container minus padding is content area)
  let mut max_right = container_width - padding.left - padding.right
  let mut max_bottom = container_height - padding.top - padding.bottom
  // Find the maximum extent of all children
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    // Child position is relative to content box (after padding)
    // Include child's margin in the extent
    let child_right = child.x + child.width + child.margin.right
    let child_bottom = child.y + child.height + child.margin.bottom
    if child_right > max_right {
      max_right = child_right
    }
    if child_bottom > max_bottom {
      max_bottom = child_bottom
    }
    // Also consider child's scroll extent for nested scrollers
    if child.scroll_width > child.width {
      let nested_right = child.x + child.scroll_width + child.margin.right
      if nested_right > max_right {
        max_right = nested_right
      }
    }
    if child.scroll_height > child.height {
      let nested_bottom = child.y + child.scroll_height + child.margin.bottom
      if nested_bottom > max_bottom {
        max_bottom = nested_bottom
      }
    }
  }
  // Return scroll dimensions (content extent, not including padding)
  // Minimum is the container's content area
  (max_right, max_bottom)
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
/// Whether this subtree contains replaced-like measured descendants that rely on
/// percentage sizing. In quirks-like cases browsers propagate a usable
/// block-size through auto-height wrappers for these elements.
fn has_percent_sized_replaced_descendant(node : @node.Node) -> Bool {
  for child in node.children {
    let child_uses_percent_size = match
      (child.style.width, child.style.height) {
      (@types.Percent(_), _) => true
      (_, @types.Percent(_)) => true
      _ => false
    }
    let child_is_measured_leaf = match child.measure {
      Some(_) => child.children.length() == 0
      None => false
    }
    if child_is_measured_leaf && child_uses_percent_size {
      return true
    }
    if has_percent_sized_replaced_descendant(child) {
      return true
    }
  }
  false
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
  layout : @types.Layout
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
  let is_vertical_writing = node.style.writing_mode.is_vertical()
  let flow_children : Array[@node.Node] = []
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
    flow_children.push(child)
  }
  let inline_only = @inline.should_establish_ifc(flow_children)
  let mut inline_has_forced_break = false
  if inline_only && not(is_vertical_writing) {
    for child in flow_children {
      if child.id == "br" {
        inline_has_forced_break = true
        break
      }
    }
  }
  let mut current_inline_line_width = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      max_content_width = intrinsic.max_width
    }
    None => ()
  }
  // Calculate max-content width from children
  for child in flow_children {
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
      @types.Percent(p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.max_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.Auto =>
        match child.measure {
          Some(mf) => {
            let intrinsic = (mf.func)(0.0, 0.0)
            @types.max(intrinsic.max_width + child_min_box, child_min_box)
          }
          None => {
            let recursive_width = calculate_children_max_content_width(
              child, parent_width,
            )
            let grid_track_width = estimate_grid_track_intrinsic_width(
              child_style,
            )
            let content_width = if grid_track_width > recursive_width {
              grid_track_width
            } else {
              recursive_width
            }
            content_width + child_min_box
          }
        }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        child_min_box
    }
    let child_contribution = child_intrinsic_width + child_margin_sum
    if is_vertical_writing {
      // In vertical writing mode, normal-flow blocks advance horizontally.
      max_content_width = max_content_width + child_contribution
    } else if inline_only && inline_has_forced_break {
      // Respect forced line breaks (<br>) in inline formatting contexts.
      // max-content width is the widest forced line, not total sum.
      current_inline_line_width = current_inline_line_width + child_contribution
      if child.id == "br" {
        if current_inline_line_width > max_content_width {
          max_content_width = current_inline_line_width
        }
        current_inline_line_width = 0.0
      }
    } else if inline_only {
      // No forced breaks: max-content is one unwrapped line.
      max_content_width = max_content_width + child_contribution
    } else if child_contribution > max_content_width {
      max_content_width = child_contribution
    }
  }
  if inline_only &&
    inline_has_forced_break &&
    current_inline_line_width > max_content_width {
    max_content_width = current_inline_line_width
  }
  if max_content_width < 0.0 {
    0.0
  } else {
    max_content_width
  }
}

///|
/// Calculate min-content width of children for intrinsic sizing
fn calculate_children_min_content_width(
  node : @node.Node,
  parent_width : Double,
  parent_content_height : Double?,
) -> Double {
  let mut min_content_width = 0.0
  let is_vertical_writing = node.style.writing_mode.is_vertical()
  let flow_children : Array[@node.Node] = []
  for child in node.children {
    // Skip display:none, absolute, fixed, and float elements
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    match child.style.float {
      @types.Float::Left | @types.Float::Right => continue
      @types.Float::None => ()
    }
    flow_children.push(child)
  }
  let inline_only = @inline.should_establish_ifc(flow_children)
  let mut inline_needs_line_width = false
  if inline_only && not(is_vertical_writing) {
    for child in flow_children {
      if child.id == "br" {
        inline_needs_line_width = true
        break
      }
      let margin_left = resolve_dimension_intrinsic(child.style.margin.left)
      let margin_right = resolve_dimension_intrinsic(child.style.margin.right)
      if margin_left + margin_right < 0.0 {
        inline_needs_line_width = true
        break
      }
    }
  }
  let mut current_inline_line_width = 0.0
  // Check if node itself has MeasureFunc (leaf node with intrinsic size)
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(0.0, 0.0)
      min_content_width = intrinsic.min_width
    }
    None => ()
  }
  // Calculate min-content width from children
  for child in flow_children {
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
    let child_padding_top = resolve_dimension_intrinsic(child_style.padding.top)
    let child_padding_bottom = resolve_dimension_intrinsic(
      child_style.padding.bottom,
    )
    let child_border = @types.resolve_rect(child_style.border, parent_width)
    let child_min_box = child_padding_left +
      child_padding_right +
      child_border.horizontal_sum()
    fn calc_aspect_width(
      ratio : Double,
      h : Double,
      box_sizing : @types.BoxSizing,
      padding_v : Double,
      border_v : Double,
      padding_h : Double,
      border_h : Double,
      min_box : Double,
    ) -> Double {
      if box_sizing == @types.BorderBox {
        if h > 0.0 {
          h * ratio
        } else {
          min_box
        }
      } else {
        let content_height = h - padding_v - border_v
        if content_height > 0.0 {
          content_height * ratio + padding_h + border_h
        } else {
          min_box
        }
      }
    }
    fn fallback_auto_min_width() -> Double {
      match child.measure {
        Some(mf) => {
          let intrinsic = (mf.func)(0.0, 0.0)
          @types.max(intrinsic.min_width + child_min_box, child_min_box)
        }
        None => {
          let recursive_width = calculate_children_min_content_width(
            child, parent_width, parent_content_height,
          )
          recursive_width + child_min_box
        }
      }
    }
    fn apply_intrinsic_inline_constraints(raw_width : Double) -> Double {
      let mut resolved = raw_width
      let width_is_inline_axis = not(child_style.writing_mode.is_vertical())
      // For intrinsic min-content contribution, percentages are indefinite and
      // resolve to 0 for inline-size constraints.
      match child_style.max_width {
        @types.Length(max_w) => if resolved > max_w { resolved = max_w }
        @types.Percent(_) =>
          if width_is_inline_axis && resolved > 0.0 {
            resolved = 0.0
          }
        _ => ()
      }
      // min-width takes precedence over max-width when both are specified.
      match child_style.min_width {
        @types.Length(min_w) => if resolved < min_w { resolved = min_w }
        @types.Percent(_) =>
          if width_is_inline_axis && resolved < 0.0 {
            resolved = 0.0
          }
        _ => ()
      }
      if resolved < child_min_box {
        child_min_box
      } else {
        resolved
      }
    }
    // Calculate child's intrinsic min-content width
    let child_intrinsic_width_raw : Double = match child_style.width {
      @types.Length(w) => @types.max(w, child_min_box)
      @types.Percent(p) =>
        if child_style.writing_mode.is_vertical() &&
          child.children.length() == 0 {
          match child.measure {
            Some(mf) => {
              let intrinsic = (mf.func)(0.0, 0.0)
              @types.max(intrinsic.min_width * p + child_min_box, child_min_box)
            }
            None => child_min_box
          }
        } else {
          child_min_box
        }
      @types.Auto =>
        match (child_style.aspect_ratio, child_style.height) {
          (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
            calc_aspect_width(
              ratio,
              h,
              child_style.box_sizing,
              child_padding_top + child_padding_bottom,
              child_border.vertical_sum(),
              child_padding_left + child_padding_right,
              child_border.horizontal_sum(),
              child_min_box,
            )
          (Some(ratio), @types.Percent(p)) if ratio > 0.0 =>
            match parent_content_height {
              Some(parent_h) =>
                calc_aspect_width(
                  ratio,
                  parent_h * p,
                  child_style.box_sizing,
                  child_padding_top + child_padding_bottom,
                  child_border.vertical_sum(),
                  child_padding_left + child_padding_right,
                  child_border.horizontal_sum(),
                  child_min_box,
                )
              None => fallback_auto_min_width()
            }
          (Some(ratio), @types.Auto) if ratio > 0.0 => {
            let is_flex_row_parent = match
              (node.style.display, node.style.flex_direction) {
              (@types.Flex | @types.InlineFlex, @types.Row | @types.RowReverse) =>
                true
              _ => false
            }
            let align_cross = match child_style.align_self {
              @types.AlignSelf::Auto => node.style.align_items
              @types.AlignSelf::Start => @types.Start
              @types.AlignSelf::End => @types.End
              @types.AlignSelf::Center => @types.Center
              @types.AlignSelf::Stretch => @types.Stretch
              @types.AlignSelf::Baseline => @types.Baseline
            }
            if is_flex_row_parent && align_cross == @types.Stretch {
              match parent_content_height {
                Some(parent_h) =>
                  calc_aspect_width(
                    ratio,
                    parent_h,
                    child_style.box_sizing,
                    child_padding_top + child_padding_bottom,
                    child_border.vertical_sum(),
                    child_padding_left + child_padding_right,
                    child_border.horizontal_sum(),
                    child_min_box,
                  )
                None => fallback_auto_min_width()
              }
            } else {
              fallback_auto_min_width()
            }
          }
          _ => fallback_auto_min_width()
        }
      @types.MinContent | @types.FitContent(_) => {
        let recursive_width = calculate_children_min_content_width(
          child,
          parent_width,
          None,
        )
        recursive_width + child_min_box
      }
      @types.MaxContent => {
        let recursive_width = calculate_children_max_content_width(
          child, parent_width,
        )
        recursive_width + child_min_box
      }
    }
    let child_intrinsic_width = apply_intrinsic_inline_constraints(
      child_intrinsic_width_raw,
    )
    let child_contribution = child_intrinsic_width + child_margin_sum
    if is_vertical_writing {
      min_content_width = min_content_width + child_contribution
    } else if inline_needs_line_width {
      current_inline_line_width = current_inline_line_width + child_contribution
      if child.id == "br" {
        if current_inline_line_width > min_content_width {
          min_content_width = current_inline_line_width
        }
        current_inline_line_width = 0.0
      }
    } else if child_contribution > min_content_width {
      min_content_width = child_contribution
    }
  }
  if inline_needs_line_width && current_inline_line_width > min_content_width {
    min_content_width = current_inline_line_width
  }
  if min_content_width < 0.0 {
    0.0
  } else {
    min_content_width
  }
}

///|
fn resolve_single_track_intrinsic(track : @types.SingleTrackSizing) -> Double {
  match track {
    @types.SingleTrackSizing::Length(v) => v
    @types.SingleTrackSizing::FitContentLength(v) => v
    @types.SingleTrackSizing::MinMax(min_track, _max_track) =>
      match min_track {
        @types.MinTrackSizing::Length(v) => v
        _ => 0.0
      }
    _ => 0.0
  }
}

///|
fn resolve_track_intrinsic(track : @types.TrackSizingFunction) -> Double {
  match track {
    @types.TrackSizingFunction::Length(v) => v
    @types.FitContentLength(v) => v
    @types.TrackSizingFunction::MinMax(min_track, _max_track) =>
      match min_track {
        @types.MinTrackSizing::Length(v) => v
        _ => 0.0
      }
    @types.TrackSizingFunction::Repeat(count, tracks) =>
      match count {
        @types.RepeatCount::Count(n) => {
          let mut unit = 0.0
          for t in tracks {
            unit = unit + resolve_single_track_intrinsic(t)
          }
          unit * n.to_double()
        }
        _ => 0.0
      }
    _ => 0.0
  }
}

///|
fn estimate_grid_track_intrinsic_width(style : @style.Style) -> Double {
  if style.display != @types.Grid && style.display != @types.InlineGrid {
    return 0.0
  }
  let mut width = 0.0
  for track in style.grid_template_columns {
    width = width + resolve_track_intrinsic(track)
  }
  if style.grid_template_columns.length() > 1 {
    let gap = resolve_dimension_intrinsic(style.column_gap)
    width = width + gap * (style.grid_template_columns.length() - 1).to_double()
  }
  width
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
    if child.style.display == @types.Display::None ||
      child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      continue
    }
    // Skip floats for height calculation in normal flow
    match child.style.float {
      @types.Float::Left | @types.Float::Right => continue
      @types.Float::None => ()
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
fn get_children_total_height(children : Array[@types.Layout]) -> Double {
  let mut total_height = 0.0
  for child in children {
    // Only count the child's box height, not margins
    // Margins are handled through margin collapsing in the parent
    total_height = total_height + child.height
  }
  total_height
}

///|
/// Get total width of children (used for vertical writing-mode)
fn get_children_total_width(children : Array[@types.Layout]) -> Double {
  let mut total_width = 0.0
  for child in children {
    total_width = total_width + child.width
  }
  total_width
}

///|
/// Browser-compat quirk for inline wrappers that only contain floated content.
/// Browsers report zero-sized inline box shifted after its float contribution.
fn adjust_inline_span_float_quirk(
  layout : @types.Layout,
  is_vertical_writing : Bool,
) -> @types.Layout {
  if layout.id != "span" ||
    is_vertical_writing ||
    layout.height != 0.0 ||
    layout.width <= 0.0 ||
    layout.children.length() == 0 {
    return layout
  }

  let mut has_visible_child = false
  for child in layout.children {
    if child.width > 0.0 || child.height > 0.0 {
      has_visible_child = true
      break
    }
  }

  if not(has_visible_child) {
    return layout
  }

  let shifted_children : Array[@types.Layout] = []
  for child in layout.children {
    shifted_children.push({ ..child, x: child.x - layout.width })
  }

  {
    ..layout,
    x: layout.x + layout.width,
    width: 0.0,
    children: shifted_children,
  }
}

///|
/// Check if flow_nodes contains both inline and block level elements
/// This determines whether we need anonymous block box processing
fn has_mixed_inline_block_content(flow_nodes : Array[@node.Node]) -> Bool {
  let mut has_inline = false
  let mut has_block = false
  for node in flow_nodes {
    if node.style.display == @types.Display::None {
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
  ctx : @types.LayoutContext,
  warnings : Array[@types.LayoutWarning],
  layout_map : Map[Int, @types.Layout],
  dispatch : @node.DispatchFn,
  writing_mode? : @style.WritingMode = @style.WritingMode::HorizontalTb,
) -> MixedContentResult {
  // In vertical writing-mode, blocks flow horizontally instead of vertically
  let is_vertical = writing_mode.is_vertical()
  let mut current_pos = 0.0 // y in horizontal, x in vertical
  let mut prev_margin_end = 0.0
  let mut escaped_start : Double? = None
  let mut escaped_end : Double? = None
  let content_offset_x = padding.left + border.left
  let content_offset_y = padding.top + border.top
  for i = 0; i < groups.length(); i = i + 1 {
    let group = groups[i]
    let is_first = i == 0
    let _is_last = i == groups.length() - 1
    match group {
      InlineGroup(nodes~, indices~) => {
        // Collapse previous block's margin with anonymous block (no margin)
        current_pos = current_pos + prev_margin_end
        prev_margin_end = 0.0
        // Process inline group through IFC (anonymous block box)
        let ifc_result = @inline.compute_ifc(
          nodes,
          available_width,
          available_height,
          if is_vertical {
            content_offset_x + current_pos
          } else {
            content_offset_x
          },
          if is_vertical {
            content_offset_y
          } else {
            content_offset_y + current_pos
          },
          dispatch,
          container_writing_mode=writing_mode,
        )
        // Store layouts with original indices
        for j = 0; j < indices.length(); j = j + 1 {
          if j < ifc_result.layouts.length() {
            layout_map[indices[j]] = ifc_result.layouts[j]
          }
        }
        // Anonymous blocks don't have margins, so no collapse
        current_pos = current_pos + ifc_result.total_height
      }
      BlockChild(node~, index~) => {
        // Process block child with margin collapsing
        // Keep auto-height flex/grid children unconstrained on block axis.
        // Otherwise mixed-content path can incorrectly stretch them to the
        // parent's available height (e.g. viewport-sized body context).
        let child_height_for_ctx : Double? = match node.style.display {
          @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
            match node.style.height {
              @types.Auto =>
                if node.style.writing_mode.is_vertical() {
                  available_height
                } else {
                  None
                }
              _ => available_height
            }
          _ => available_height
        }
        let child_ctx : @types.LayoutContext = {
          available_width,
          available_height: child_height_for_ctx,
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        // Use dispatch for flex/grid containers, block layout for others
        let @node.DispatchFn(dispatch_fn) = dispatch
        let child_layout = match node.style.display {
          @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
            dispatch_fn(node, child_ctx, dispatch)
          _ => compute_with_collapse(node, child_ctx, warnings, dispatch).layout
        }
        // Calculate margin values - use appropriate axis based on writing mode
        let margin_start = if is_vertical {
          child_layout.margin.left
        } else {
          child_layout.margin.top
        }
        let margin_end = if is_vertical {
          child_layout.margin.right
        } else {
          child_layout.margin.bottom
        }
        // Collapse margins (only in horizontal mode; vertical mode uses physical margins)
        let collapsed = if is_vertical {
          margin_start // No collapse in vertical mode for now
        } else {
          collapse_margins(prev_margin_end, margin_start)
        }
        // Handle first child - check if margin escapes
        let edge_padding = if is_vertical { padding.left } else { padding.top }
        let edge_border = if is_vertical { border.left } else { border.top }
        if is_first && escaped_start is None {
          // Check if we can collapse through (parent has no padding/border on start edge)
          if edge_padding == 0.0 && edge_border == 0.0 {
            escaped_start = Some(margin_start)
          } else {
            current_pos = current_pos + margin_start
          }
        } else {
          current_pos = current_pos + collapsed
        }
        // Position and store layout - swap x/y based on writing mode
        let base_x = if is_vertical {
          content_offset_x + current_pos
        } else {
          content_offset_x + child_layout.margin.left
        }
        let base_y = if is_vertical {
          content_offset_y + child_layout.margin.top
        } else {
          content_offset_y + current_pos
        }
        let (layout_x, layout_width, layout_children) = if node.id == "span" {
          let mut has_visible_child = false
          for grand_layout in child_layout.children {
            if grand_layout.width > 0.0 || grand_layout.height > 0.0 {
              has_visible_child = true
              break
            }
          }
          if has_visible_child {
            let shifted_children : Array[@types.Layout] = []
            for grand_layout in child_layout.children {
              shifted_children.push({
                ..grand_layout,
                x: grand_layout.x - child_layout.width,
              })
            }
            (base_x + child_layout.width, 0.0, shifted_children)
          } else {
            (base_x, child_layout.width, child_layout.children)
          }
        } else {
          (base_x, child_layout.width, child_layout.children)
        }
        let positioned_layout : @types.Layout = {
          id: child_layout.id,
          x: layout_x,
          y: base_y,
          width: layout_width,
          height: child_layout.height,
          margin: child_layout.margin,
          padding: child_layout.padding,
          border: child_layout.border,
          overflow_x: child_layout.overflow_x,
          overflow_y: child_layout.overflow_y,
          scroll_width: child_layout.scroll_width,
          scroll_height: child_layout.scroll_height,
          children: layout_children,
          text: child_layout.text,
        }
        layout_map[index] = positioned_layout
        // Update state - advance by width in vertical mode, height in horizontal
        let child_size = if is_vertical {
          child_layout.width
        } else {
          child_layout.height
        }
        current_pos = current_pos + child_size
        prev_margin_end = margin_end
        escaped_end = Some(margin_end)
      }
    }
  }
  // Add final margin if not escaping
  let end_padding = if is_vertical { padding.right } else { padding.bottom }
  let end_border = if is_vertical { border.right } else { border.bottom }
  if end_padding > 0.0 || end_border > 0.0 {
    current_pos = current_pos + prev_margin_end
    escaped_end = None
  }
  // content_height represents the content size in the block flow direction
  // In vertical mode, this is actually content width, but we use the same name for simplicity
  {
    content_height: current_pos,
    escaped_top: escaped_start,
    escaped_bottom: escaped_end,
  }
}

///|
/// Compute layout with collapse at root level (no parent to escape to)
fn compute_root_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let result = compute_with_collapse(node, ctx, warnings, dispatch)
  let layout = result.layout

  // At root level, escaped margins position children and add to height
  match result.collapsed.top {
    Some(escaped_margin) =>
      // Adjust first child position and height
      if layout.children.length() > 0 {
        // Need to adjust children positions by escaped margin
        let adjusted_children : Array[@types.Layout] = []
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
            scroll_width: child.scroll_width,
            scroll_height: child.scroll_height,
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
          scroll_width: layout.scroll_width,
          scroll_height: layout.scroll_height,
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
            scroll_width: layout.scroll_width,
            scroll_height: layout.scroll_height,
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
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.LayoutResult {
  let warnings : Array[@types.LayoutWarning] = []
  let layout = compute_root_layout(node, ctx, warnings, dispatch)
  { layout, warnings }
}

///|
/// Compute block layout for a node and its children
pub fn compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let warnings : Array[@types.LayoutWarning] = []
  compute_root_layout(node, ctx, warnings, dispatch)
}

///|
/// Internal function that computes layout with margin collapse tracking
fn compute_with_collapse(
  node : @node.Node,
  ctx : @types.LayoutContext,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> LayoutWithCollapse {
  let style = node.style

  // Handle display: contents - element doesn't generate a box but children do
  if style.display == @types.Contents {
    // Compute children layouts using parent context
    // Position children as if they were direct children of the parent
    let children_layouts : Array[@types.Layout] = []
    let mut current_pos = 0.0
    let mut prev_margin_end = 0.0
    let mut first_child_margin_top : Double? = None
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      let child_result = compute_with_collapse(child, ctx, warnings, dispatch)
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
        collapse_margins(prev_margin_end, child_margin_top)
      }
      current_pos = current_pos + collapsed
      // Position child
      let positioned_child : @types.Layout = {
        id: child_layout.id,
        x: child_layout.x,
        y: current_pos,
        width: child_layout.width,
        height: child_layout.height,
        margin: child_layout.margin,
        padding: child_layout.padding,
        border: child_layout.border,
        overflow_x: child_layout.overflow_x,
        overflow_y: child_layout.overflow_y,
        scroll_width: child_layout.scroll_width,
        scroll_height: child_layout.scroll_height,
        children: child_layout.children,
        text: child_layout.text,
      }
      children_layouts.push(positioned_child)
      current_pos = current_pos + child_layout.height
      prev_margin_end = child_margin_bottom
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
        overflow_x: @types.Visible,
        overflow_y: @types.Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: children_layouts,
        text: node.text,
      },
      // Pass through the first child's margin for collapse with siblings
      collapsed: { top: first_child_margin_top, bottom: Some(prev_margin_end) },
    }
  }

  // Note: Float is now supported - no warning needed

  // Handle leaf nodes with MeasureFunc (e.g., text nodes)
  // These nodes have no children but need intrinsic size from their measure function
  if node.children.length() == 0 {
    match node.measure {
      Some(mf) => {
        let parent_width = ctx.available_width
        let parent_height_opt = ctx.available_height
        let parent_height = parent_height_opt.unwrap_or(0.0)
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
          @types.Length(_) => true
          @types.Percent(_) => parent_height_opt is Some(_)
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
              // Text nodes should wrap to available inline size, but replaced elements
              // keep their intrinsic width contribution for shrink-to-fit/abspos sizing.
              if node.text is Some(_) && ctx.sizing_mode == @types.Definite {
                Some(@types.min(content_width, parent_width))
              } else {
                Some(content_width)
              }
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            Some(parent_width)
        }

        // Calculate initial height
        // For replaced elements with aspect_ratio:
        // - If height is Auto AND width is definite, let aspect_ratio compute height
        let initial_height : Double? = match style.height {
          @types.Length(h) => Some(h)
          @types.Percent(p) =>
            match parent_height_opt {
              Some(ph) => Some(ph * p)
              None =>
                Some(
                  intrinsic.max_height +
                  padding.vertical_sum() +
                  border.vertical_sum(),
                )
            }
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
            scroll_width: 0.0,
            scroll_height: 0.0,
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
  let parent_height_opt = ctx.available_height
  let parent_height = ctx.available_height.unwrap_or(0.0)
  let is_intrinsic_sizing = match ctx.sizing_mode {
    @types.MaxContent => true
    @types.Definite => false
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
  // Collapse blocked by: border/padding, BFC-establishing properties.
  // contain:layout/paint/size also establish an independent formatting context.
  let overflow_blocks = match (style.overflow_x, style.overflow_y) {
    (@types.Overflow::Visible, @types.Overflow::Visible) => false
    _ => true
  }
  let is_float_container = match style.float {
    @types.Float::None => false
    _ => true
  }
  let establishes_bfc = overflow_blocks ||
    is_float_container ||
    style.display == @types.FlowRoot ||
    style.contain.layout ||
    style.contain.paint ||
    style.contain.size
  let can_collapse_top = border.top == 0.0 &&
    padding.top == 0.0 &&
    not(establishes_bfc)
  let can_collapse_bottom = border.bottom == 0.0 &&
    padding.bottom == 0.0 &&
    not(establishes_bfc)
  let has_available_height = match ctx.available_height {
    Some(_) => true
    None => false
  }
  let auto_height_with_percent_replaced = match style.height {
    @types.Auto => has_percent_sized_replaced_descendant(node)
    _ => false
  }
  let should_fill_from_percent_replaced = style.writing_mode.is_vertical() &&
    has_available_height &&
    auto_height_with_percent_replaced
  let fill_vertical_auto_height = style.writing_mode.is_vertical() &&
    (ctx.stretch_height || should_fill_from_percent_replaced) &&
    (
      style.display == @types.Block ||
      style.display == @types.FlowRoot ||
      style.display == @types.Table
    )

  // Box width - depends on sizing mode and aspect_ratio
  // For MaxContent mode with width:Auto, or explicit width: max-content/min-content
  // InlineBlock elements also use shrink-to-fit (max-content) when width is auto
  let is_inline_block = style.display == @types.InlineBlock ||
    style.display == @types.TableCell
  let use_max_content = match (ctx.sizing_mode, style.width) {
    (@types.MaxContent, @types.Auto) => true
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
      if style.box_sizing == @types.BorderBox {
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
    (@types.Auto, @types.Percent(p), Some(ratio)) =>
      match parent_height_opt {
        Some(ph) => {
          let h = ph * p
          if style.box_sizing == @types.BorderBox {
            Some(h * ratio)
          } else {
            let content_height = h -
              padding.vertical_sum() -
              border.vertical_sum()
            Some(
              content_height * ratio +
              padding.horizontal_sum() +
              border.horizontal_sum(),
            )
          }
        }
        None => None
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
    @types.MaxContent | @types.FitContent(_) => {
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
          if style.box_sizing == @types.BorderBox {
            h * ar
          } else {
            (h - padding.vertical_sum() - border.vertical_sum()) * ar +
            padding.horizontal_sum() +
            border.horizontal_sum()
          }
        (Some(ar), @types.Percent(p)) if ar > 0.0 =>
          match parent_height_opt {
            Some(ph) => {
              let h = ph * p
              if style.box_sizing == @types.BorderBox {
                h * ar
              } else {
                (h - padding.vertical_sum() - border.vertical_sum()) * ar +
                padding.horizontal_sum() +
                border.horizontal_sum()
              }
            }
            None => 0.0
          }
        _ => 0.0
      }
      let intrinsic_width = @types.max(children_width, aspect_width)
      if box_width > intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.MinContent => {
      let intrinsic_width = calculate_children_min_content_width(
          node,
          parent_width,
          None,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      if box_width > intrinsic_width {
        box_width = intrinsic_width
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
    @types.MaxContent => {
      // Calculate max-content width of children
      let intrinsic_width = calculate_children_max_content_width(
          node, parent_width,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      if box_width < intrinsic_width {
        box_width = intrinsic_width
      }
    }
    @types.MinContent | @types.FitContent(_) => {
      // fit-content/min-content minimum should not exceed min-content contribution.
      let intrinsic_width = calculate_children_min_content_width(
          node,
          parent_width,
          None,
        ) +
        padding.horizontal_sum() +
        border.horizontal_sum()
      if box_width < intrinsic_width {
        box_width = intrinsic_width
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
      match parent_height_opt {
        Some(ph) =>
          Some(ph * p - padding.vertical_sum() - border.vertical_sum())
        None =>
          // Percentage height in an indefinite containing block behaves like auto.
          // If max-height is definite, use that constrained content height so
          // descendants with percentage heights can resolve against the used size.
          match style.max_height {
            @types.Length(max_h) =>
              Some(
                @types.max(
                  0.0,
                  max_h - padding.vertical_sum() - border.vertical_sum(),
                ),
              )
            _ => None
          }
      }
    @types.Auto =>
      if ctx.stretch_height {
        match ctx.available_height {
          Some(available_h) =>
            Some(
              @types.max(
                0.0,
                available_h - padding.vertical_sum() - border.vertical_sum(),
              ),
            )
          None => None
        }
      } else {
        match (ctx.sizing_mode, style.aspect_ratio) {
          (@types.Definite, Some(ratio)) if ratio > 0.0 =>
            if style.box_sizing == @types.BorderBox {
              Some(
                @types.max(
                  0.0,
                  box_width / ratio -
                  padding.vertical_sum() -
                  border.vertical_sum(),
                ),
              )
            } else {
              let content_w = box_width -
                padding.horizontal_sum() -
                border.horizontal_sum()
              Some(@types.max(0.0, content_w / ratio))
            }
          _ =>
            match ctx.available_height {
              // Compatibility: propagate a usable block-size through auto wrappers
              // when percent-sized descendants need it. The root body also
              // uses viewport-height as the percentage basis in practice.
              Some(available_h) if node.id == "body" ||
                has_percent_sized_replaced_descendant(node) =>
                Some(
                  @types.max(
                    0.0,
                    available_h - padding.vertical_sum() - border.vertical_sum(),
                  ),
                )
              _ => None
            }
        }
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      match ctx.available_height {
        Some(available_h) if node.id == "body" ||
          has_percent_sized_replaced_descendant(node) =>
          Some(
            @types.max(
              0.0,
              available_h - padding.vertical_sum() - border.vertical_sum(),
            ),
          )
        _ => None
      }
  }

  // Map to store layouts by original index
  let layout_map : Map[Int, @types.Layout] = {}

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
    if child.style.display == @types.Display::None {
      // Add zero-sized layout for display:none children (including descendants)
      layout_map[i] = create_zero_layout(child)
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      // Record where this absolute/fixed child appears in flow order
      absolute_static_positions[i] = flow_position
      continue
    }
    // Check if this is a float element
    match child.style.float {
      @types.Float::Left | @types.Float::Right => {
        float_nodes.push(child)
        float_indices.push(i)
        // Float elements still advance flow position for absolute static positioning
        flow_position = flow_position + 1
      }
      @types.Float::None => {
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
    let inline_only = @inline.should_establish_ifc(flow_nodes)
    let mut inline_has_forced_break = false
    if inline_only && not(style.writing_mode.is_vertical()) {
      for child in flow_nodes {
        if child.id == "br" {
          inline_has_forced_break = true
          break
        }
      }
    }
    let mut current_inline_line_width = 0.0
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
        let has_intrinsic_width_constraint = match
          (child_style.min_width, child_style.max_width) {
          (@types.MinContent | @types.MaxContent | @types.FitContent(_), _) =>
            true
          (_, @types.MinContent | @types.MaxContent | @types.FitContent(_)) =>
            true
          _ => false
        }
        let child_recursive_intrinsic_width : Double? = if has_intrinsic_width_constraint &&
          child.children.length() > 0 {
          // Recursively compute child's intrinsic width so min/max intrinsic
          // constraints (e.g. fit-content) are applied on the child itself.
          let intrinsic_ctx : @types.LayoutContext = {
            available_width: parent_width,
            available_height: child_available_height,
            sizing_mode: @types.MaxContent,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          }
          let @node.DispatchFn(dispatch_fn) = dispatch
          let child_width = match child_style.display {
            @types.Flex
            | @types.InlineFlex
            | @types.Grid
            | @types.InlineGrid
            | @types.Table
            | @types.InlineTable =>
              dispatch_fn(child, intrinsic_ctx, dispatch).width
            _ =>
              compute_with_collapse(child, intrinsic_ctx, warnings, dispatch).layout.width
          }
          Some(child_width)
        } else {
          None
        }
        // Helper function to calculate width from aspect-ratio
        fn calc_aspect_width(
          ratio : Double,
          h : Double,
          box_sizing : @types.BoxSizing,
          padding_v : Double,
          border_v : Double,
          padding_h : Double,
          border_h : Double,
          min_box : Double,
        ) -> Double {
          if box_sizing == @types.BorderBox {
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
        fn compute_recursive_child_width() -> Double {
          let intrinsic_ctx : @types.LayoutContext = {
            available_width: parent_width, // Use parent_width as reference for percentages
            available_height: child_available_height,
            sizing_mode: @types.MaxContent,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          }
          let @node.DispatchFn(dispatch_fn) = dispatch
          match child_style.display {
            @types.Flex
            | @types.InlineFlex
            | @types.Grid
            | @types.InlineGrid
            | @types.Table
            | @types.InlineTable =>
              dispatch_fn(child, intrinsic_ctx, dispatch).width
            _ =>
              compute_with_collapse(child, intrinsic_ctx, warnings, dispatch).layout.width
          }
        }
        let child_intrinsic_width : Double = match child_style.width {
          @types.Length(w) =>
            match child_recursive_intrinsic_width {
              Some(recursive_w) => recursive_w
              None => @types.max(w, child_min_box)
            }
          @types.Percent(p) =>
            if child_style.writing_mode.is_vertical() &&
              child.children.length() == 0 {
              match child.measure {
                Some(mf) => {
                  let intrinsic = (mf.func)(0.0, 0.0)
                  @types.max(
                    intrinsic.max_width * p + child_min_box,
                    child_min_box,
                  )
                }
                None => child_min_box
              }
            } else if child.children.length() == 0 {
              let measured_aspect_width : Double? = match
                (child.measure, child_style.aspect_ratio) {
                (Some(mf), Some(ratio)) if ratio > 0.0 => {
                  let intrinsic = (mf.func)(0.0, 0.0)
                  let resolved_height : Double? = match child_style.height {
                    @types.Length(h) => Some(h)
                    @types.Percent(height_p) =>
                      match child_available_height {
                        Some(parent_content_h) =>
                          Some(parent_content_h * height_p)
                        None => None
                      }
                    @types.Auto
                    | @types.MinContent
                    | @types.MaxContent
                    | @types.FitContent(_) => {
                      let min_h = match child_style.min_height {
                        @types.Length(h) => h
                        @types.Percent(height_p) =>
                          match child_available_height {
                            Some(parent_content_h) =>
                              parent_content_h * height_p
                            None => 0.0
                          }
                        _ => 0.0
                      }
                      let max_h = match child_style.max_height {
                        @types.Length(h) => h
                        @types.Percent(height_p) =>
                          match child_available_height {
                            Some(parent_content_h) =>
                              parent_content_h * height_p
                            None => @double.infinity
                          }
                        _ => @double.infinity
                      }
                      if max_h < @double.infinity || min_h > 0.0 {
                        Some(
                          @types.clamp(
                            intrinsic.max_height +
                            child_padding_v +
                            child_border.vertical_sum(),
                            min_h,
                            max_h,
                          ),
                        )
                      } else {
                        None
                      }
                    }
                  }
                  match resolved_height {
                    Some(h) =>
                      Some(
                        calc_aspect_width(
                          ratio,
                          h,
                          child_style.box_sizing,
                          child_padding_v,
                          child_border.vertical_sum(),
                          child_padding_left + child_padding_right,
                          child_border.horizontal_sum(),
                          child_min_box,
                        ),
                      )
                    None => None
                  }
                }
                _ => None
              }
              match measured_aspect_width {
                Some(w) => @types.max(w, child_min_box)
                None =>
                  if has_intrinsic_width_constraint {
                    match child_recursive_intrinsic_width {
                      Some(recursive_w) => recursive_w
                      None => child_min_box
                    }
                  } else if has_percent_sized_replaced_descendant(child) {
                    match child_available_height {
                      Some(h) =>
                        @types.max(h * p + child_min_box, child_min_box)
                      None =>
                        if child.children.length() == 0 {
                          child_min_box
                        } else {
                          let recursive_w = compute_recursive_child_width()
                          @types.max(recursive_w, child_min_box)
                        }
                    }
                  } else {
                    child_min_box
                  }
              }
            } else if has_intrinsic_width_constraint {
              match child_recursive_intrinsic_width {
                Some(recursive_w) => recursive_w
                None => child_min_box
              }
            } else if has_percent_sized_replaced_descendant(child) {
              match child_available_height {
                Some(h) => @types.max(h * p + child_min_box, child_min_box)
                None =>
                  if child.children.length() == 0 {
                    child_min_box
                  } else {
                    let recursive_w = compute_recursive_child_width()
                    @types.max(recursive_w, child_min_box)
                  }
              }
            } else {
              child_min_box // At minimum, padding+border
            }
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
                    // Percentage heights resolve against containing block content box.
                    let h = parent_content_h * p
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
                      // Recursively compute child's max-content width.
                      // Grid/Flex/Table children must be dispatched to their own
                      // layout algorithms in intrinsic sizing.
                      compute_recursive_child_width()
                    }
                }
            }
          @types.MinContent | @types.MaxContent => child_min_box
          @types.FitContent(_) =>
            if child.children.length() == 0 {
              child_min_box
            } else {
              let recursive_w = compute_recursive_child_width()
              @types.max(recursive_w, child_min_box)
            }
        }
        let child_contribution = child_intrinsic_width + child_margin_sum
        if style.writing_mode.is_vertical() {
          max_content_width = max_content_width + child_contribution
        } else if inline_only && inline_has_forced_break {
          current_inline_line_width = current_inline_line_width +
            child_contribution
          if child.id == "br" {
            if current_inline_line_width > max_content_width {
              max_content_width = current_inline_line_width
            }
            current_inline_line_width = 0.0
          }
        } else if inline_only {
          max_content_width = max_content_width + child_contribution
        } else if child_contribution > max_content_width {
          max_content_width = child_contribution
        }
      }
      if inline_only &&
        inline_has_forced_break &&
        current_inline_line_width > max_content_width {
        max_content_width = current_inline_line_width
      }

      // Floats also contribute to shrink-to-fit/max-content width.
      // Use the total inline span of floats to match fit-content behavior.
      let mut float_total_width = 0.0
      for child in float_nodes {
        let child_style = child.style
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
        let child_padding_v = resolve_dimension_intrinsic(
            child_style.padding.top,
          ) +
          resolve_dimension_intrinsic(child_style.padding.bottom)
        fn calc_float_aspect_width(
          ratio : Double,
          h : Double,
          box_sizing : @types.BoxSizing,
          padding_v : Double,
          border_v : Double,
          padding_h : Double,
          border_h : Double,
          min_box : Double,
        ) -> Double {
          if box_sizing == @types.BorderBox {
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
        fn compute_float_recursive_width(
          width_keyword : @types.Dimension,
        ) -> Double {
          let intrinsic_basis_width = if parent_width > 0.0 {
            parent_width
          } else {
            ctx.viewport_width
          }
          let intrinsic_child = @node.Node::with_uid_and_measure(
            child.id,
            child.uid,
            { ..child_style, width: width_keyword },
            child.children,
            child.measure,
            child.text,
          )
          let intrinsic_ctx : @types.LayoutContext = {
            available_width: intrinsic_basis_width,
            available_height: child_available_height,
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          }
          let @node.DispatchFn(dispatch_fn) = dispatch
          match child_style.display {
            @types.Flex
            | @types.InlineFlex
            | @types.Grid
            | @types.InlineGrid
            | @types.Table
            | @types.InlineTable =>
              dispatch_fn(intrinsic_child, intrinsic_ctx, dispatch).width
            _ =>
              compute_with_collapse(
                intrinsic_child, intrinsic_ctx, warnings, dispatch,
              ).layout.width
          }
        }
        let child_intrinsic_width : Double = match child_style.width {
          @types.Length(w) => @types.max(w, child_min_box)
          @types.Percent(_) => child_min_box
          @types.Auto =>
            match (child_style.aspect_ratio, child_style.height) {
              (Some(ratio), @types.Length(h)) if ratio > 0.0 =>
                calc_float_aspect_width(
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
                match child_available_height {
                  Some(parent_content_h) => {
                    let h = parent_content_h * p
                    calc_float_aspect_width(
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
                  None => child_min_box
                }
              _ =>
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
                      child_min_box
                    } else {
                      let recursive_w = compute_float_recursive_width(
                        @types.MaxContent,
                      )
                      @types.max(recursive_w, child_min_box)
                    }
                }
            }
          @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
            child_min_box
        }
        float_total_width = float_total_width +
          child_intrinsic_width +
          child_margin_sum
      }
      if float_total_width > max_content_width {
        max_content_width = float_total_width
      }
    }
    if max_content_width < 0.0 {
      max_content_width = 0.0
    }
    let min_content_width = calculate_children_min_content_width(
        node, parent_width, child_available_height,
      ) +
      padding.horizontal_sum() +
      border.horizontal_sum()
    let shrink_available_width = if box_width > 0.0 { box_width } else { 0.0 }
    // Update box_width from intrinsic width according to specified width keyword.
    box_width = match style.width {
      @types.MinContent => min_content_width
      @types.Auto =>
        if is_inline_block {
          // Inline-block width:auto uses shrink-to-fit.
          let preferred_max = max_content_width +
            padding.horizontal_sum() +
            border.horizontal_sum()
          let mut shrink_to_fit = @types.max(
            min_content_width, shrink_available_width,
          )
          if shrink_to_fit > preferred_max {
            shrink_to_fit = preferred_max
          }
          shrink_to_fit
        } else {
          max_content_width + padding.horizontal_sum() + border.horizontal_sum()
        }
      @types.MaxContent | @types.FitContent(_) =>
        max_content_width + padding.horizontal_sum() + border.horizontal_sum()
      _ =>
        max_content_width + padding.horizontal_sum() + border.horizontal_sum()
    }
    // Re-apply min/max constraints (max first, then min for precedence)
    match style.max_width {
      @types.Length(max_w) => if box_width > max_w { box_width = max_w }
      @types.Percent(p) => {
        let max_w = parent_width * p
        if box_width > max_w {
          box_width = max_w
        }
      }
      @types.MaxContent | @types.FitContent(_) => {
        // Calculate intrinsic max-content width of children
        let intrinsic_width = calculate_children_max_content_width(
            node, parent_width,
          ) +
          padding.horizontal_sum() +
          border.horizontal_sum()
        if box_width > intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.MinContent => {
        let intrinsic_width = calculate_children_min_content_width(
            node, parent_width, child_available_height,
          ) +
          padding.horizontal_sum() +
          border.horizontal_sum()
        if box_width > intrinsic_width {
          box_width = intrinsic_width
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
      @types.MaxContent => {
        // Calculate intrinsic max-content width of children
        let intrinsic_width = calculate_children_max_content_width(
            node, parent_width,
          ) +
          padding.horizontal_sum() +
          border.horizontal_sum()
        if box_width < intrinsic_width {
          box_width = intrinsic_width
        }
      }
      @types.MinContent | @types.FitContent(_) => {
        let intrinsic_width = calculate_children_min_content_width(
            node, parent_width, child_available_height,
          ) +
          padding.horizontal_sum() +
          border.horizontal_sum()
        if box_width < intrinsic_width {
          box_width = intrinsic_width
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

  // Check if we should use Inline Formatting Context (IFC)
  // IFC is used when all flow children are inline-level elements
  let use_ifc = @inline.should_establish_ifc(flow_nodes)
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
      dispatch,
      container_writing_mode=style.writing_mode,
    )

    // Store IFC layouts with original indices
    for i = 0; i < flow_indices.length(); i = i + 1 {
      if i < ifc_result.layouts.length() {
        layout_map[flow_indices[i]] = adjust_inline_span_float_quirk(
          ifc_result.layouts[i],
          style.writing_mode.is_vertical(),
        )
      }
    }

    // Calculate box height from IFC content
    let mut content_height = ifc_result.total_height
    if establishes_bfc {
      // Include floated descendants wrapped by zero-height inline boxes.
      let mut ifc_descendant_extent = 0.0
      for i = 0; i < flow_indices.length(); i = i + 1 {
        match layout_map.get(flow_indices[i]) {
          Some(layout) => {
            let descendant_h = get_children_total_height(layout.children)
            let child_block = if layout.height > descendant_h {
              layout.height
            } else {
              descendant_h
            }
            let extent = layout.y + child_block
            if extent > ifc_descendant_extent {
              ifc_descendant_extent = extent
            }
          }
          None => ()
        }
      }
      if ifc_descendant_extent > content_height {
        content_height = ifc_descendant_extent
      }
    }
    let mut box_height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) =>
        match parent_height_opt {
          Some(ph) => ph * p
          None =>
            content_height + padding.vertical_sum() + border.vertical_sum()
        }
      @types.Auto =>
        if fill_vertical_auto_height {
          match parent_height_opt {
            Some(ph) => @types.max(0.0, ph - margin.top - margin.bottom)
            None =>
              content_height + padding.vertical_sum() + border.vertical_sum()
          }
        } else {
          content_height + padding.vertical_sum() + border.vertical_sum()
        }
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
      if child.style.position == @types.Absolute {
        let abs_layout = layout_absolute_child(
          child, box_width, box_height, border, content_height, warnings, dispatch,
        )
        layout_map[i] = abs_layout
      }
    }

    // Handle fixed children (positioned relative to viewport)
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      if child.style.position == @types.Fixed {
        let fixed_layout = layout_fixed_child_for_parent(
          child,
          style,
          parent_width,
          if parent_height > 0.0 {
            parent_height
          } else {
            ctx.viewport_height
          },
          box_width,
          box_height,
          border,
          ctx.viewport_width,
          ctx.viewport_height,
          warnings,
          dispatch,
        )
        layout_map[i] = fixed_layout
      }
    }

    // Assemble child_layouts in original order
    let child_layouts : Array[@types.Layout] = []
    for i = 0; i < node.children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(layout) => child_layouts.push(layout)
        None => ()
      }
    }
    // Calculate scroll dimensions
    let (scroll_width, scroll_height) = calculate_scroll_dimensions(
      box_width, box_height, padding, child_layouts,
    )
    let layout : @types.Layout = {
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
      scroll_width,
      scroll_height,
      children: child_layouts,
      text: node.text,
    }
    return { layout, collapsed: { top: None, bottom: None } }
  } else if has_mixed {
    // Mixed inline/block content - use anonymous block boxes
    let groups = group_flow_children_for_anonymous_blocks(
      flow_nodes, flow_indices,
    )
    let mixed_result = compute_mixed_content_layout(
      groups,
      actual_child_available_width,
      child_available_height,
      padding,
      border,
      ctx,
      warnings,
      layout_map,
      dispatch,
      writing_mode=style.writing_mode,
    )
    // Calculate box height from mixed content
    let mut content_height = mixed_result.content_height
    if establishes_bfc {
      // Floats in descendant anonymous/block wrappers still participate in this BFC.
      // Include their visual block extent when mixed-content grouping is used.
      let mut mixed_descendant_extent = 0.0
      for i = 0; i < node.children.length(); i = i + 1 {
        match layout_map.get(i) {
          Some(layout) => {
            let descendant_h = get_children_total_height(layout.children)
            let child_block = if layout.height > descendant_h {
              layout.height
            } else {
              descendant_h
            }
            let extent = layout.y + child_block
            if extent > mixed_descendant_extent {
              mixed_descendant_extent = extent
            }
          }
          None => ()
        }
      }
      if mixed_descendant_extent > content_height {
        content_height = mixed_descendant_extent
      }
    }
    let mut box_height = match style.height {
      @types.Length(h) => h
      @types.Percent(p) =>
        match parent_height_opt {
          Some(ph) => ph * p
          None =>
            content_height + padding.vertical_sum() + border.vertical_sum()
        }
      @types.Auto =>
        if fill_vertical_auto_height {
          match parent_height_opt {
            Some(ph) => @types.max(0.0, ph - margin.top - margin.bottom)
            None =>
              content_height + padding.vertical_sum() + border.vertical_sum()
          }
        } else {
          content_height + padding.vertical_sum() + border.vertical_sum()
        }
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
      if child.style.position == @types.Absolute {
        let abs_layout = layout_absolute_child(
          child, box_width, box_height, border, content_height, warnings, dispatch,
        )
        layout_map[i] = abs_layout
      }
    }
    // Handle fixed children (positioned relative to viewport)
    for i = 0; i < node.children.length(); i = i + 1 {
      let child = node.children[i]
      if child.style.position == @types.Fixed {
        let fixed_layout = layout_fixed_child_for_parent(
          child,
          style,
          parent_width,
          if parent_height > 0.0 {
            parent_height
          } else {
            ctx.viewport_height
          },
          box_width,
          box_height,
          border,
          ctx.viewport_width,
          ctx.viewport_height,
          warnings,
          dispatch,
        )
        layout_map[i] = fixed_layout
      }
    }
    // Assemble child_layouts in original order
    let child_layouts : Array[@types.Layout] = []
    for i = 0; i < node.children.length(); i = i + 1 {
      match layout_map.get(i) {
        Some(layout) => child_layouts.push(layout)
        None => ()
      }
    }
    // Calculate scroll dimensions
    let (scroll_width, scroll_height) = calculate_scroll_dimensions(
      box_width, box_height, padding, child_layouts,
    )
    let layout : @types.Layout = {
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
      scroll_width,
      scroll_height,
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
      @types.Flex
      | @types.InlineFlex
      | @types.Grid
      | @types.InlineGrid
      | @types.InlineBlock
      | @types.Table
      | @types.InlineTable => {
        // For BFC-establishing children with auto height, don't pass available_height
        // This allows them to size to their content rather than stretching to fill
        // the available space. Flex item sizing should be decided by the flex/grid parent.
        let child_height_for_ctx : Double? = match child.style.height {
          @types.Auto =>
            if child.style.writing_mode.is_vertical() {
              child_available_height
            } else {
              None
            }
          _ => child_available_height
        }
        let child_ctx : @types.LayoutContext = {
          available_width: actual_child_available_width,
          available_height: child_height_for_ctx,
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        // Use dispatch for flex/grid/table containers
        let @node.DispatchFn(dispatch_fn) = dispatch
        let layout = dispatch_fn(child, child_ctx, dispatch)
        { layout, collapsed: { top: None, bottom: None } }
      }
      _ => {
        let child_ctx : @types.LayoutContext = {
          available_width: actual_child_available_width,
          available_height: child_available_height,
          sizing_mode: @types.Definite,
          viewport_width: ctx.viewport_width,
          viewport_height: ctx.viewport_height,
          stretch_width: false,
          stretch_height: false,
        }
        compute_with_collapse(child, child_ctx, warnings, dispatch)
      }
    }
    flow_children.push(child_result)
  }

  // Layout float elements
  // Float elements are positioned using the float context
  let float_layouts : Array[@types.Layout] = []
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
      @types.Percent(_) =>
        // Keep parent content height as the percentage basis.
        // The float node itself resolves its own percentage height later.
        child_available_height
      _ => child_available_height
    }

    // Calculate child's width (float elements use shrink-to-fit)
    let child_width = match child_style.width {
      @types.Length(w) => w
      @types.Percent(p) => actual_child_available_width * p
      @types.Auto => {
        let @node.DispatchFn(dispatch_fn) = dispatch
        fn compute_float_keyword_width(
          width_keyword : @types.Dimension,
        ) -> Double {
          let keyword_style = { ..child_style, width: width_keyword }
          let keyword_child = @node.Node::with_uid_and_measure(
            child.id,
            child.uid,
            keyword_style,
            child.children,
            child.measure,
            child.text,
          )
          let keyword_padding = @types.resolve_rect(
            keyword_style.padding,
            actual_child_available_width,
          )
          let keyword_border = @types.resolve_rect(
            keyword_style.border,
            actual_child_available_width,
          )
          let provisional_width = actual_child_available_width
          let content_width = provisional_width -
            keyword_padding.horizontal_sum() -
            keyword_border.horizontal_sum()
          let keyword_height_for_ctx : Double? = match keyword_style.display {
            @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
              match keyword_style.height {
                @types.Auto =>
                  if keyword_style.writing_mode.is_vertical() {
                    float_available_height
                  } else {
                    None
                  }
                _ => float_available_height
              }
            _ => float_available_height
          }
          let keyword_ctx : @types.LayoutContext = {
            available_width: if content_width > 0.0 {
              content_width
            } else {
              0.0
            },
            available_height: keyword_height_for_ctx,
            sizing_mode: @types.Definite,
            viewport_width: ctx.viewport_width,
            viewport_height: ctx.viewport_height,
            stretch_width: false,
            stretch_height: false,
          }
          match keyword_style.display {
            @types.Flex
            | @types.InlineFlex
            | @types.Grid
            | @types.InlineGrid
            | @types.Table
            | @types.InlineTable =>
              dispatch_fn(keyword_child, keyword_ctx, dispatch).width
            _ =>
              compute_with_collapse(
                keyword_child, keyword_ctx, warnings, dispatch,
              ).layout.width
          }
        }
        let preferred_max = compute_float_keyword_width(@types.MaxContent)
        let mut preferred_min = compute_float_keyword_width(@types.MinContent)
        if float_available_height is Some(_) &&
          has_percent_sized_replaced_descendant(child) &&
          preferred_max > preferred_min {
          // Browser-compat quirk: percent-sized replaced descendants in auto-height
          // wrappers behave as if preferred-min tracks preferred width.
          preferred_min = preferred_max
        }
        let available_for_shrink = if actual_child_available_width > 0.0 {
          actual_child_available_width
        } else {
          0.0
        }
        let mut shrink_to_fit = @types.max(preferred_min, available_for_shrink)
        if shrink_to_fit > preferred_max {
          shrink_to_fit = preferred_max
        }
        if shrink_to_fit < 0.0 {
          0.0
        } else {
          shrink_to_fit
        }
      }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        actual_child_available_width
    }

    // Compute child layout with determined width
    let child_content_width = child_width -
      child_padding.horizontal_sum() -
      child_border.horizontal_sum()
    let child_for_layout = match child_style.width {
      @types.Auto =>
        @node.Node::with_uid_and_measure(
          child.id,
          child.uid,
          { ..child_style, width: @types.Length(child_width) },
          child.children,
          child.measure,
          child.text,
        )
      _ => child
    }
    // For BFC-establishing children (flex/grid) with auto height, don't pass available_height
    // This allows them to size to their content rather than stretching
    // Use float_available_height which accounts for float's own explicit height
    let child_height_for_ctx : Double? = match child_style.display {
      @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
        match child_style.height {
          @types.Auto =>
            if child_style.writing_mode.is_vertical() {
              float_available_height
            } else {
              None
            }
          _ => float_available_height
        }
      _ => float_available_height
    }
    let child_ctx : @types.LayoutContext = {
      available_width: if child_content_width > 0.0 {
        child_content_width
      } else {
        0.0
      },
      available_height: child_height_for_ctx,
      sizing_mode: @types.Definite,
      viewport_width: ctx.viewport_width,
      viewport_height: ctx.viewport_height,
      stretch_width: false,
      stretch_height: false,
    }
    // Use dispatch for flex/grid elements, block layout for others
    let @node.DispatchFn(dispatch_fn) = dispatch
    let child_inner = match child_style.display {
      @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
        dispatch_fn(child_for_layout, child_ctx, dispatch)
      _ =>
        compute_with_collapse(child_for_layout, child_ctx, warnings, dispatch).layout
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
    let float_layout : @types.Layout = {
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
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: child_inner.children,
      text: child.text,
    }
    float_layouts.push(float_layout)
    layout_map[float_indices[i]] = float_layout
  }

  // Track escaped margins for parent
  let mut escaped_top : Double? = None
  let mut escaped_bottom : Double? = None

  // Check for vertical writing mode - affects block flow direction
  let is_vertical_writing = style.writing_mode.is_vertical()
  let is_block_rtl = style.writing_mode.is_block_rtl()

  // Track positions after each flow child (for absolute static positioning)
  // In horizontal mode: tracks y position. In vertical mode: tracks x position.
  let flow_y_positions : Array[Double] = []
  let mut current_pos = 0.0 // y in horizontal, x in vertical
  let mut prev_margin_end = 0.0
  for i = 0; i < flow_children.length(); i = i + 1 {
    let child_result = flow_children[i]
    let child_layout = child_result.layout
    let child_collapsed = child_result.collapsed
    let is_first = i == 0
    let is_last = i == flow_children.length() - 1
    let child_style = flow_styles[i]

    // Handle clear property - move current_pos below cleared floats
    match child_style.clear {
      @types.Clear::Left | @types.Clear::Right | @types.Clear::Both => {
        let clear_y = float_ctx.get_clear_y(child_style.clear, current_pos)
        if clear_y > current_pos {
          current_pos = clear_y
          prev_margin_end = 0.0 // Reset margin collapse after clear
        }
      }
      @types.Clear::None => ()
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
    // Blocked by: height, border, padding, BFC-establishing properties, aspect_ratio
    let child_overflow_blocks = match
      (child_style.overflow_x, child_style.overflow_y) {
      (@types.Overflow::Visible, @types.Overflow::Visible) => false
      _ => true
    }
    let child_establishes_bfc = child_overflow_blocks ||
      child_style.display == @types.FlowRoot ||
      child_style.contain.layout ||
      child_style.contain.paint ||
      child_style.contain.size
    let child_has_aspect_ratio = match child_style.aspect_ratio {
      Some(_) => true
      None => false
    }
    // For display: contents, use children's height for collapse check
    let effective_height_for_collapse = if child_style.display ==
      @types.Contents {
      get_children_total_height(child_layout.children)
    } else {
      child_layout.height
    }
    let collapses_through = can_collapse_through(
        effective_height_for_collapse,
        child_layout.border,
        child_layout.padding,
      ) &&
      not(child_establishes_bfc) &&
      not(child_has_aspect_ratio)

    // Calculate position and track escaping margins
    let child_y : Double = if is_first {
      if can_collapse_top {
        // First child margin escapes to parent
        if collapses_through {
          escaped_top = Some(
            collapse_margins(effective_margin_top, effective_margin_bottom),
          )
          prev_margin_end = effective_margin_bottom
        } else {
          escaped_top = Some(effective_margin_top)
          prev_margin_end = effective_margin_bottom
        }
        padding.top + border.top // Child at y=0 relative to content
      } else {
        // Margin blocked by border/padding
        if collapses_through {
          prev_margin_end = collapse_margins(
            effective_margin_top, effective_margin_bottom,
          )
        } else {
          prev_margin_end = effective_margin_bottom
        }
        current_pos = effective_margin_top
        effective_margin_top + padding.top + border.top
      }
      // Sibling collapse
    } else if collapses_through {
      // Collapse-through: element positioned after collapsed margin gap
      let all_collapsed = collapse_margins(
        prev_margin_end,
        collapse_margins(effective_margin_top, effective_margin_bottom),
      )
      prev_margin_end = all_collapsed
      // Position at the same y as where next sibling would be
      current_pos + all_collapsed + padding.top + border.top
    } else {
      let collapsed = collapse_margins(prev_margin_end, effective_margin_top)
      current_pos = current_pos + collapsed
      prev_margin_end = effective_margin_bottom
      current_pos + padding.top + border.top
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
    let (final_x, final_y) = if child_style.position != @types.Absolute &&
      child_style.position != @types.Fixed {
      let height_context = match child_available_height {
        Some(h) => Some(h + padding.vertical_sum() + border.vertical_sum())
        None => None
      }
      let (x_offset, y_offset) = @core.resolve_relative_inset_offsets(
        child_style.inset,
        box_width,
        height_context,
      )
      (child_x + x_offset, child_y + y_offset)
    } else {
      (child_x, child_y)
    }

    // Position child and store in map with original index
    // In vertical writing mode, swap x/y positioning
    let (positioned_x, positioned_y) = if is_vertical_writing {
      // In vertical mode: blocks flow horizontally (x advances), y is fixed
      // child_y was calculated as block position (should be x), child_x as cross position (should be y)
      let x_from_left = final_y -
        padding.top -
        border.top +
        padding.left +
        border.left
      let final_x_pos = if is_block_rtl {
        // For vertical-rl: position from right side of container
        box_width - x_from_left - child_layout.width
      } else {
        // For vertical-lr: position from left side (normal)
        x_from_left
      }
      (final_x_pos, child_layout.margin.top + padding.top + border.top)
    } else {
      (final_x, final_y)
    }
    let adjusted_layout = adjust_inline_span_float_quirk(
      { ..child_layout, x: positioned_x },
      is_vertical_writing,
    )
    let positioned_layout : @types.Layout = {
      id: adjusted_layout.id,
      x: adjusted_layout.x,
      y: positioned_y,
      width: adjusted_layout.width,
      height: adjusted_layout.height,
      margin: adjusted_layout.margin,
      padding: adjusted_layout.padding,
      border: adjusted_layout.border,
      overflow_x: adjusted_layout.overflow_x,
      overflow_y: adjusted_layout.overflow_y,
      scroll_width: adjusted_layout.scroll_width,
      scroll_height: adjusted_layout.scroll_height,
      children: adjusted_layout.children,
      text: adjusted_layout.text,
    }
    layout_map[flow_indices[i]] = positioned_layout

    // Update current_pos (only if not collapsing through)
    if not(collapses_through) {
      // For display: contents, use children's total height instead of element's height (which is 0)
      // In vertical mode, we advance by width instead of height
      let effective_size = if child_style.display == @types.Contents {
        if is_vertical_writing {
          get_children_total_width(child_layout.children)
        } else {
          get_children_total_height(child_layout.children)
        }
      } else if is_vertical_writing {
        child_layout.width
      } else {
        child_layout.height
      }
      if is_first && can_collapse_top {
        current_pos = effective_size
      } else if is_first {
        current_pos = effective_margin_top + effective_size
      } else {
        current_pos = current_pos + effective_size
      }
    }

    // Record y position after this flow child (for absolute static positioning)
    flow_y_positions.push(current_pos)

    // Handle last child's bottom margin escape
    if is_last && can_collapse_bottom {
      escaped_bottom = Some(prev_margin_end)
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
    @types.max(0.0, current_pos) // Don't include escaped bottom margin
  } else {
    @types.max(0.0, current_pos + prev_margin_end)
  }
  let content_height = @types.max(flow_content_height, float_height)
  let mut content_height_for_auto = content_height

  if is_vertical_writing {
    // In vertical writing mode, block-flow accumulates on x while auto height
    // should use the inline-axis extent (max cross-size of in-flow children).
    let mut inline_cross_extent = 0.0
    for idx in flow_indices {
      match layout_map.get(idx) {
        Some(child_layout) => {
          let extent = child_layout.y +
            child_layout.height +
            child_layout.margin.bottom
          if extent > inline_cross_extent {
            inline_cross_extent = extent
          }
        }
        None => ()
      }
    }
    for idx in float_indices {
      match layout_map.get(idx) {
        Some(child_layout) => {
          let extent = child_layout.y +
            child_layout.height +
            child_layout.margin.bottom
          if extent > inline_cross_extent {
            inline_cross_extent = extent
          }
        }
        None => ()
      }
    }
    content_height_for_auto = @types.max(inline_cross_extent, float_height)

    // For unconstrained vertical blocks, auto width should follow block-flow extent.
    match (style.width, style.min_width, style.max_width) {
      (@types.Auto, @types.Auto, @types.Auto) => {
        box_width = content_height +
          padding.horizontal_sum() +
          border.horizontal_sum()
        let min_box_width = padding.horizontal_sum() + border.horizontal_sum()
        if box_width < min_box_width {
          box_width = min_box_width
        }
      }
      _ => ()
    }
  }

  // Box height - consider aspect_ratio
  let mut box_height = match style.height {
    @types.Length(h) => h
    @types.Percent(p) =>
      match parent_height_opt {
        Some(ph) => ph * p
        None =>
          content_height_for_auto +
          padding.vertical_sum() +
          border.vertical_sum()
      }
    @types.Auto =>
      match style.aspect_ratio {
        Some(ratio) =>
          // With box-sizing: border-box, aspect-ratio applies to border-box dimensions
          if style.box_sizing == @types.BorderBox {
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
        None =>
          if fill_vertical_auto_height {
            match parent_height_opt {
              Some(ph) => @types.max(0.0, ph - margin.top - margin.bottom)
              None =>
                content_height_for_auto +
                padding.vertical_sum() +
                border.vertical_sum()
            }
          } else {
            content_height_for_auto +
            padding.vertical_sum() +
            border.vertical_sum()
          }
      }
    @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
      content_height_for_auto + padding.vertical_sum() + border.vertical_sum()
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
      let min_h = content_height_for_auto +
        padding.vertical_sum() +
        border.vertical_sum()
      if box_height < min_h {
        box_height = min_h
      }
    }
    @types.FitContent(_) => {
      // fit-content for min-height acts like min-content
      let min_h = content_height_for_auto +
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
      let max_h = content_height_for_auto +
        padding.vertical_sum() +
        border.vertical_sum()
      if box_height > max_h {
        box_height = max_h
      }
    }
    @types.FitContent(_) => {
      // fit-content for max-height acts like max-content
      let max_h = content_height_for_auto +
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
    if child.style.position == @types.Absolute {
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
        child, box_width, box_height, border, static_y, warnings, dispatch,
      )
      layout_map[i] = abs_layout
    }
  }

  // Handle fixed positioned children (relative to viewport)
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.position == @types.Fixed {
      let fixed_layout = layout_fixed_child_for_parent(
        child,
        style,
        parent_width,
        if parent_height > 0.0 {
          parent_height
        } else {
          ctx.viewport_height
        },
        box_width,
        box_height,
        border,
        ctx.viewport_width,
        ctx.viewport_height,
        warnings,
        dispatch,
      )
      layout_map[i] = fixed_layout
    }
  }

  // Assemble child_layouts in original order
  let child_layouts : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    match layout_map.get(i) {
      Some(layout) => child_layouts.push(layout)
      None => () // Should not happen
    }
  }
  // Calculate scroll dimensions
  let (scroll_width, scroll_height) = calculate_scroll_dimensions(
    box_width, box_height, padding, child_layouts,
  )
  let layout : @types.Layout = {
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
    scroll_width,
    scroll_height,
    children: child_layouts,
    text: node.text,
  }
  { layout, collapsed: { top: escaped_top, bottom: escaped_bottom } }
}

///|
fn resolve_fixed_inset_offset(
  dim : @types.Dimension,
  available : Double,
) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(p) => available * p
    _ => 0.0
  }
}

///|
fn establishes_fixed_containing_block(style : @style.Style) -> Bool {
  style.contain.paint || style.contain.layout || not(style.transform.is_none())
}

///|
fn estimate_self_offset_for_fixed(
  style : @style.Style,
  parent_width : Double,
  parent_height : Double,
) -> (Double, Double) {
  match style.position {
    @types.Absolute | @types.Fixed =>
      (
        resolve_fixed_inset_offset(style.inset.left, parent_width),
        resolve_fixed_inset_offset(style.inset.top, parent_height),
      )
    _ => (0.0, 0.0)
  }
}

///|
fn layout_fixed_child_for_parent(
  child : @node.Node,
  parent_style : @style.Style,
  parent_width : Double,
  parent_height : Double,
  container_width : Double,
  container_height : Double,
  parent_border : @types.Rect[Double],
  viewport_width : Double,
  viewport_height : Double,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  if establishes_fixed_containing_block(parent_style) {
    // Transform/filter/backdrop-filter/perspective/containment establish CB for fixed descendants.
    return layout_absolute_child(
      child, container_width, container_height, parent_border, 0.0, warnings, dispatch,
    )
  }
  let fixed_layout = layout_fixed_child(
    child, viewport_width, viewport_height, warnings, dispatch,
  )
  // Fixed boxes are viewport-relative; convert to parent-relative coordinates.
  let (parent_offset_x, parent_offset_y) = estimate_self_offset_for_fixed(
    parent_style, parent_width, parent_height,
  )
  {
    ..fixed_layout,
    x: fixed_layout.x - parent_offset_x,
    y: fixed_layout.y - parent_offset_y,
  }
}

///|
/// Layout an absolutely positioned child within a block container
fn layout_absolute_child(
  child : @node.Node,
  container_width : Double,
  container_height : Double,
  parent_border : @types.Rect[Double],
  static_y : Double, // Y position where the element would be in normal flow
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let child_style = child.style
  let cb_width = if container_width > parent_border.horizontal_sum() {
    container_width - parent_border.horizontal_sum()
  } else {
    0.0
  }
  let cb_height = if container_height > parent_border.vertical_sum() {
    container_height - parent_border.vertical_sum()
  } else {
    0.0
  }

  // Handle display:none - return zero-sized layout
  if child_style.display == @types.Display::None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation
  let params = @absolute.compute_size_params(child_style, cb_width, cb_height)

  // When used size is already resolved for abs/fixed items, passing that value
  // directly as available size would re-resolve percentage widths/heights.
  // Convert used size back to the containing-block basis for nested layout.
  fn nested_basis_width(used_width : Double) -> Double {
    match child_style.width {
      @types.Percent(p) if p > 0.0 => used_width / p
      _ => used_width
    }
  }
  fn nested_basis_height(used_height : Double?) -> Double? {
    match used_height {
      Some(h) =>
        match child_style.height {
          @types.Percent(p) if p > 0.0 => Some(h / p)
          _ => Some(h)
        }
      None => None
    }
  }

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

  fn compute_abs_intrinsic_width(
    width_keyword : @types.Dimension,
    intrinsic_height : Double?,
  ) -> Double {
    let intrinsic_child = @node.Node::with_uid_and_measure(
      child.id,
      child.uid,
      { ..child_style, width: width_keyword },
      child.children,
      child.measure,
      child.text,
    )
    compute_nested_intrinsic(
      intrinsic_child, intrinsic_height, warnings, dispatch,
    ).width
  }

  fn resolve_abs_shrink_to_fit_width(intrinsic_height : Double?) -> Double {
    let preferred_max = compute_abs_intrinsic_width(
      @types.MaxContent,
      intrinsic_height,
    )
    let mut preferred_min = compute_abs_intrinsic_width(
      @types.MinContent,
      intrinsic_height,
    )
    if intrinsic_height is Some(_) &&
      has_percent_sized_replaced_descendant(child) &&
      preferred_max > preferred_min {
      preferred_min = preferred_max
    }
    let available_for_shrink = if cb_width > 0.0 { cb_width } else { 0.0 }
    let mut shrink_to_fit = @types.max(preferred_min, available_for_shrink)
    if shrink_to_fit > preferred_max {
      shrink_to_fit = preferred_max
    }
    if shrink_to_fit < 0.0 {
      0.0
    } else {
      shrink_to_fit
    }
  }

  // Compute intrinsic size if needed, and get child's inner layout
  let (child_width, child_height, child_inner) = match
    (initial_width, initial_height) {
    (Some(w), Some(h)) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        None,
        warnings,
        dispatch,
      )
      let h = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      // Width is auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_abs_shrink_to_fit_width(Some(h))
      let w = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => shrink_to_fit_width
      }
      // Step 2: Re-layout with definite width
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (None, None) => {
      // Both width and height are auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_abs_shrink_to_fit_width(None)
      match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let w = shrink_to_fit_width
          let h = w / ar
          // Re-layout with definite size
          let inner = compute_nested(
            child,
            nested_basis_width(w),
            nested_basis_height(Some(h)),
            warnings,
            dispatch,
          )
          (w, h, inner)
        }
        _ => {
          // Re-layout with definite width
          let inner = compute_nested(
            child,
            nested_basis_width(shrink_to_fit_width),
            None,
            warnings,
            dispatch,
          )
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
    compute_nested_intrinsic(child, None, warnings, dispatch)
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
  let child_padding = @types.resolve_rect(child_style.padding, cb_width)
  let child_border = @types.resolve_rect(child_style.border, cb_width)
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
        let available = cb_width - l - r - child_width
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
        cb_width - child_width - r - params.margin_right + parent_border.left
      } else if margin_right_is_auto {
        // Only right margin auto: push to left
        l + params.margin_left + parent_border.left
      } else {
        // No auto margins: over-constrained, use left inset
        l + params.margin_left + parent_border.left
      }
    (Some(l), None) => l + params.margin_left + parent_border.left
    (None, Some(r)) =>
      cb_width - child_width - r - params.margin_right - parent_border.right
    (None, None) => params.margin_left + parent_border.left
  }
  let child_y = match (params.inset_top, params.inset_bottom) {
    (Some(t), Some(b)) =>
      // Both insets specified
      // Check for margin auto centering behavior
      if margin_top_is_auto && margin_bottom_is_auto {
        // Both margins auto: try to center the element
        let available = cb_height - t - b - child_height
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
        cb_height - child_height - b - params.margin_bottom + parent_border.top
      } else if margin_bottom_is_auto {
        // Only bottom margin auto: push to top
        t + params.margin_top + parent_border.top
      } else {
        // No auto margins: over-constrained, use top inset
        t + params.margin_top + parent_border.top
      }
    (Some(t), None) => t + params.margin_top + parent_border.top
    (None, Some(b)) =>
      cb_height - child_height - b - params.margin_bottom - parent_border.bottom
    (None, None) => static_y + params.margin_top + parent_border.top
  }
  let child_margin = @types.resolve_rect(child_style.margin, cb_width)
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
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let child_style = child.style

  // Handle display:none - return zero-sized layout
  if child_style.display == @types.Display::None {
    return @absolute.create_zero_layout(child.id)
  }

  // Use shared absolute module for size calculation with viewport as containing block
  let params = @absolute.compute_size_params(
    child_style, viewport_width, viewport_height,
  )

  fn nested_basis_width(used_width : Double) -> Double {
    match child_style.width {
      @types.Percent(p) if p > 0.0 => used_width / p
      _ => used_width
    }
  }
  fn nested_basis_height(used_height : Double?) -> Double? {
    match used_height {
      Some(h) =>
        match child_style.height {
          @types.Percent(p) if p > 0.0 => Some(h / p)
          _ => Some(h)
        }
      None => None
    }
  }

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

  fn compute_fixed_intrinsic_width(
    width_keyword : @types.Dimension,
    intrinsic_height : Double?,
  ) -> Double {
    let intrinsic_child = @node.Node::with_uid_and_measure(
      child.id,
      child.uid,
      { ..child_style, width: width_keyword },
      child.children,
      child.measure,
      child.text,
    )
    compute_nested_intrinsic(
      intrinsic_child, intrinsic_height, warnings, dispatch,
    ).width
  }

  fn resolve_fixed_shrink_to_fit_width(intrinsic_height : Double?) -> Double {
    let preferred_max = compute_fixed_intrinsic_width(
      @types.MaxContent,
      intrinsic_height,
    )
    let mut preferred_min = compute_fixed_intrinsic_width(
      @types.MinContent,
      intrinsic_height,
    )
    if intrinsic_height is Some(_) &&
      has_percent_sized_replaced_descendant(child) &&
      preferred_max > preferred_min {
      preferred_min = preferred_max
    }
    let available_for_shrink = if viewport_width > 0.0 {
      viewport_width
    } else {
      0.0
    }
    let mut shrink_to_fit = @types.max(preferred_min, available_for_shrink)
    if shrink_to_fit > preferred_max {
      shrink_to_fit = preferred_max
    }
    if shrink_to_fit < 0.0 {
      0.0
    } else {
      shrink_to_fit
    }
  }

  // Compute intrinsic size if needed, and get child's inner layout
  let (child_width, child_height, child_inner) = match
    (initial_width, initial_height) {
    (Some(w), Some(h)) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (Some(w), None) => {
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        None,
        warnings,
        dispatch,
      )
      let h = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => w / ar
        _ => inner.height
      }
      (w, h, inner)
    }
    (None, Some(h)) => {
      // Width is auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_fixed_shrink_to_fit_width(Some(h))
      let w = match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => h * ar
        _ => shrink_to_fit_width
      }
      let inner = compute_nested(
        child,
        nested_basis_width(w),
        nested_basis_height(Some(h)),
        warnings,
        dispatch,
      )
      (w, h, inner)
    }
    (None, None) => {
      // Both width and height are auto: use shrink-to-fit approach
      let shrink_to_fit_width = resolve_fixed_shrink_to_fit_width(None)
      match child_style.aspect_ratio {
        Some(ar) if ar > 0.0 => {
          let w = shrink_to_fit_width
          let h = w / ar
          let inner = compute_nested(
            child,
            nested_basis_width(w),
            nested_basis_height(Some(h)),
            warnings,
            dispatch,
          )
          (w, h, inner)
        }
        _ => {
          let inner = compute_nested(
            child,
            nested_basis_width(shrink_to_fit_width),
            None,
            warnings,
            dispatch,
          )
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

  // Calculate position relative to viewport (0, 0), including margin:auto behavior
  let (child_x, child_y) = @absolute.compute_position_with_margin_auto(
    params, child_style, child_width, child_height, 0.0, 0.0, viewport_width, viewport_height,
  )
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
    scroll_width: 0.0,
    scroll_height: 0.0,
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
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
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
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: node.text,
    }
  }

  // For containers, recurse
  let ctx : @types.LayoutContext = {
    available_width,
    available_height,
    sizing_mode: @types.Definite,
    viewport_width: available_width,
    viewport_height: available_height.unwrap_or(0.0),
    stretch_width: false,
    stretch_height: false,
  }
  // Use dispatch for flex/grid containers, block layout for others
  let @node.DispatchFn(dispatch_fn) = dispatch
  match node.style.display {
    @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
      dispatch_fn(node, ctx, dispatch)
    _ => compute_with_collapse(node, ctx, warnings, dispatch).layout
  }
}

///|
/// Compute nested children for intrinsic sizing (MaxContent mode)
/// This is used for shrink-to-fit calculations in absolute positioning
fn compute_nested_intrinsic(
  node : @node.Node,
  available_height : Double?,
  warnings : Array[@types.LayoutWarning],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
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
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: node.text,
    }
  }

  // For containers, use MaxContent sizing mode
  let ctx : @types.LayoutContext = {
    available_width: @double.infinity,
    available_height,
    sizing_mode: @types.MaxContent,
    viewport_width: 0.0,
    viewport_height: available_height.unwrap_or(0.0),
    stretch_width: false,
    stretch_height: false,
  }
  // Use dispatch for flex/grid containers, block layout for others
  let @node.DispatchFn(dispatch_fn) = dispatch
  match node.style.display {
    @types.Flex | @types.InlineFlex | @types.Grid | @types.InlineGrid =>
      dispatch_fn(node, ctx, dispatch)
    _ => compute_with_collapse(node, ctx, warnings, dispatch).layout
  }
}
