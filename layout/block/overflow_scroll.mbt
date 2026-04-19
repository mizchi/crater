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
/// Content bounds for initial overflow alignment.
priv struct AlignmentContentBounds {
  min_x : Double
  max_x : Double
  min_y : Double
  max_y : Double
}

///|
/// Calculate content bounds including negative overflow.
/// Used for initial overflow alignment where pre-positioned children can start
/// from negative coordinates in vertical/rtl writing modes.
fn calculate_alignment_content_bounds(
  container_width : Double,
  container_height : Double,
  padding : @types.Rect[Double],
  children : Array[@types.Layout],
) -> AlignmentContentBounds {
  let mut min_left = 0.0
  let mut min_top = 0.0
  let mut max_right = container_width - padding.left - padding.right
  let mut max_bottom = container_height - padding.top - padding.bottom
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let child_left = child.x - child.margin.left
    let child_top = child.y - child.margin.top
    let child_right = child.x + child.width + child.margin.right
    let child_bottom = child.y + child.height + child.margin.bottom
    if child_left < min_left {
      min_left = child_left
    }
    if child_top < min_top {
      min_top = child_top
    }
    if child_right > max_right {
      max_right = child_right
    }
    if child_bottom > max_bottom {
      max_bottom = child_bottom
    }
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
  { min_x: min_left, max_x: max_right, min_y: min_top, max_y: max_bottom }
}

///|
fn should_apply_overflow_content_alignment(style : @style.Style) -> Bool {
  style.justify_content != @types.Alignment::Start ||
  style.align_content != @types.Alignment::Stretch
}

///|
fn logical_start_is_physical_min_inline(
  writing_mode : @style.WritingMode,
  direction : @style.Direction,
) -> Bool {
  if writing_mode.is_vertical() {
    direction == @style.Direction::Ltr
  } else {
    direction == @style.Direction::Ltr
  }
}

///|
fn logical_start_is_physical_min_block(
  writing_mode : @style.WritingMode,
) -> Bool {
  match writing_mode {
    @style.WritingMode::VerticalRl => false
    @style.WritingMode::HorizontalTb | @style.WritingMode::VerticalLr => true
  }
}

///|
fn compute_overflow_alignment_offset(
  alignment : @types.Alignment,
  is_unsafe : Bool,
  available : Double,
  content_size : Double,
  current_min : Double,
  start_is_min : Bool,
) -> Double {
  let free_space = available - content_size
  let fallback_to_start = fn() -> Double {
    if start_is_min {
      0.0
    } else {
      free_space
    }
  }
  let align_to_end = fn() -> Double {
    if start_is_min {
      free_space
    } else {
      0.0
    }
  }
  let target_min = match alignment {
    @types.Alignment::Start | @types.Alignment::FlexStart => fallback_to_start()
    @types.Alignment::End | @types.Alignment::FlexEnd =>
      if free_space < 0.0 && !is_unsafe {
        fallback_to_start()
      } else {
        align_to_end()
      }
    @types.Alignment::Center =>
      if free_space < 0.0 && !is_unsafe {
        fallback_to_start()
      } else {
        free_space / 2.0
      }
    // Distribution/baseline/stretch values are not position anchors when overflowing.
    // Initial scroll position falls back to content-distribution start side.
    _ => fallback_to_start()
  }
  target_min - current_min
}

///|
fn apply_initial_overflow_content_alignment(
  node : @node.Node,
  layout : @types.Layout,
) -> @types.Layout {
  if layout.children.is_empty() {
    return layout
  }
  let style = node.style
  if !should_apply_overflow_content_alignment(style) {
    return layout
  }

  let inline_scrollable = if style.writing_mode.is_vertical() {
    overflow_creates_scroll_container(style.overflow_y)
  } else {
    overflow_creates_scroll_container(style.overflow_x)
  }
  let block_scrollable = if style.writing_mode.is_vertical() {
    overflow_creates_scroll_container(style.overflow_x)
  } else {
    overflow_creates_scroll_container(style.overflow_y)
  }
  if !inline_scrollable && !block_scrollable {
    return layout
  }

  let content_box_width = if layout.width > layout.padding.horizontal_sum() {
    layout.width - layout.padding.horizontal_sum()
  } else {
    0.0
  }
  let content_box_height = if layout.height > layout.padding.vertical_sum() {
    layout.height - layout.padding.vertical_sum()
  } else {
    0.0
  }

  let inline_available = if style.writing_mode.is_vertical() {
    content_box_height
  } else {
    content_box_width
  }
  let block_available = if style.writing_mode.is_vertical() {
    content_box_width
  } else {
    content_box_height
  }

  let content_bounds = calculate_alignment_content_bounds(
    layout.width,
    layout.height,
    layout.padding,
    layout.children,
  )
  let inline_min = if style.writing_mode.is_vertical() {
    content_bounds.min_y
  } else {
    content_bounds.min_x
  }
  let inline_max = if style.writing_mode.is_vertical() {
    content_bounds.max_y
  } else {
    content_bounds.max_x
  }
  let block_min = if style.writing_mode.is_vertical() {
    content_bounds.min_x
  } else {
    content_bounds.min_y
  }
  let block_max = if style.writing_mode.is_vertical() {
    content_bounds.max_x
  } else {
    content_bounds.max_y
  }
  let inline_content = if inline_max > inline_min {
    inline_max - inline_min
  } else {
    0.0
  }
  let block_content = if block_max > block_min {
    block_max - block_min
  } else {
    0.0
  }

  // Block containers use content distribution on the block axis.
  // Inline-axis initial scroll position falls back to logical start.
  let inline_offset = if inline_scrollable {
    compute_overflow_alignment_offset(
      @types.Alignment::Start,
      false,
      inline_available,
      inline_content,
      inline_min,
      logical_start_is_physical_min_inline(style.writing_mode, style.direction),
    )
  } else {
    0.0
  }
  let block_offset = if block_scrollable {
    compute_overflow_alignment_offset(
      style.align_content,
      style.align_content_unsafe,
      block_available,
      block_content,
      block_min,
      logical_start_is_physical_min_block(style.writing_mode),
    )
  } else {
    0.0
  }

  let (offset_x, offset_y) = if style.writing_mode.is_vertical() {
    (block_offset, inline_offset)
  } else {
    (inline_offset, block_offset)
  }
  if offset_x.abs() <= 0.0001 && offset_y.abs() <= 0.0001 {
    return layout
  }

  let shifted_children = layout.children.map(fn(child) {
    { ..child, x: child.x + offset_x, y: child.y + offset_y }
  })
  { ..layout, children: shifted_children }
}

///|
/// Apply initial scroll-snap offset for mandatory center snapping.
fn apply_initial_scroll_snap(
  node : @node.Node,
  layout : @types.Layout,
) -> @types.Layout {
  let layout = apply_initial_overflow_content_alignment(node, layout)
  if layout.children.is_empty() {
    return layout
  }
  if !node.style.scroll_snap_type.is_mandatory() {
    return layout
  }

  let supports_snap_x = node.style.scroll_snap_type.snaps_x() &&
    overflow_creates_scroll_container(node.style.overflow_x)
  let supports_snap_y = node.style.scroll_snap_type.snaps_y() &&
    overflow_creates_scroll_container(node.style.overflow_y)
  if !supports_snap_x && !supports_snap_y {
    return layout
  }

  let max_scroll_x = if layout.scroll_width > layout.width {
    layout.scroll_width - layout.width
  } else {
    0.0
  }
  let max_scroll_y = if layout.scroll_height > layout.height {
    layout.scroll_height - layout.height
  } else {
    0.0
  }
  let snap_x = if supports_snap_x && max_scroll_x > 0.0 {
    find_initial_snap_offset_x(node, layout, max_scroll_x)
  } else {
    None
  }
  let snap_y = if supports_snap_y && max_scroll_y > 0.0 {
    find_initial_snap_offset_y(node, layout, max_scroll_y)
  } else {
    None
  }
  let offset_x = snap_x.unwrap_or(0.0)
  let offset_y = snap_y.unwrap_or(0.0)
  if offset_x.abs() <= 0.0001 && offset_y.abs() <= 0.0001 {
    return layout
  }

  let shifted_children = layout.children.map(fn(child) {
    { ..child, x: child.x - offset_x, y: child.y - offset_y }
  })
  { ..layout, children: shifted_children }
}

///|
fn overflow_creates_scroll_container(overflow : @types.Overflow) -> Bool {
  match overflow {
    @types.Visible | @types.Clip => false
    @types.Hidden | @types.Scroll | @types.Auto => true
  }
}

///|
fn find_initial_snap_offset_x(
  node : @node.Node,
  layout : @types.Layout,
  max_scroll : Double,
) -> Double? {
  let count = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  let mut best_offset : Double? = None
  for i = 0; i < count; i = i + 1 {
    let child_node = node.children[i]
    if child_node.style.scroll_snap_align_x != @style.ScrollSnapAlign::Center {
      continue
    }
    let child_layout = layout.children[i]
    let raw = child_layout.x + child_layout.width / 2.0 - layout.width / 2.0
    let candidate = clamp(raw, 0.0, max_scroll)
    best_offset = choose_nearer_to_origin(best_offset, candidate)
  }
  best_offset
}

///|
fn find_initial_snap_offset_y(
  node : @node.Node,
  layout : @types.Layout,
  max_scroll : Double,
) -> Double? {
  let count = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  let mut best_offset : Double? = None
  for i = 0; i < count; i = i + 1 {
    let child_node = node.children[i]
    if child_node.style.scroll_snap_align_y != @style.ScrollSnapAlign::Center {
      continue
    }
    let child_layout = layout.children[i]
    let raw = child_layout.y + child_layout.height / 2.0 - layout.height / 2.0
    let candidate = clamp(raw, 0.0, max_scroll)
    best_offset = choose_nearer_to_origin(best_offset, candidate)
  }
  best_offset
}

///|
fn choose_nearer_to_origin(current : Double?, candidate : Double) -> Double? {
  match current {
    Some(existing) =>
      if candidate.abs() < existing.abs() {
        Some(candidate)
      } else {
        Some(existing)
      }
    None => Some(candidate)
  }
}

///|
fn clamp(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
