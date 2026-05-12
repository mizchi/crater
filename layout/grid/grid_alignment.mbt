///|
/// Grid overflow alignment helpers
///
/// Handles initial overflow content alignment before track sizing logic.

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
fn overflow_alignment_track_offset(
  alignment : @types.Alignment,
  _is_unsafe : Bool,
  available : Double,
  content_size : Double,
  current_min : Double,
  start_is_min : Bool,
  is_inline_axis : Bool,
) -> Double {
  let free_space = available - content_size
  if free_space >= 0.0 {
    return 0.0
  }
  let target_start = if start_is_min { 0.0 } else { free_space }
  let target_end = if start_is_min { free_space } else { 0.0 }
  let target_min = match alignment {
    @types.Alignment::Start | @types.Alignment::FlexStart => target_start
    @types.Alignment::End | @types.Alignment::FlexEnd => target_end
    @types.Alignment::Center => free_space / 2.0
    @types.Alignment::Left => if is_inline_axis { 0.0 } else { target_start }
    @types.Alignment::Right =>
      if is_inline_axis {
        free_space
      } else {
        target_end
      }
    // Distribution/baseline/stretch fall back to content-distribution start.
    _ => target_start
  }
  target_min - current_min
}

///|
priv struct AlignmentContentBounds {
  min_x : Double
  max_x : Double
  min_y : Double
  max_y : Double
}

///|
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
fn overflow_creates_scroll_container(overflow : @types.Overflow) -> Bool {
  match overflow {
    @types.Visible | @types.Clip => false
    @types.Hidden | @types.Scroll | @types.Auto => true
  }
}

///|
fn apply_initial_overflow_content_alignment(
  style : @style.Style,
  container_width : Double,
  container_height : Double,
  padding : @types.Rect[Double],
  children : Array[@types.Layout],
) -> Array[@types.Layout] {
  if children.is_empty() {
    return children
  }
  let content_box_width = container_width - padding.left - padding.right
  let content_box_height = container_height - padding.top - padding.bottom
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
  let bounds = calculate_alignment_content_bounds(
    container_width, container_height, padding, children,
  )
  let inline_min = if style.writing_mode.is_vertical() {
    bounds.min_y
  } else {
    bounds.min_x
  }
  let inline_max = if style.writing_mode.is_vertical() {
    bounds.max_y
  } else {
    bounds.max_x
  }
  let block_min = if style.writing_mode.is_vertical() {
    bounds.min_x
  } else {
    bounds.min_y
  }
  let block_max = if style.writing_mode.is_vertical() {
    bounds.max_x
  } else {
    bounds.max_y
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
  let inline_scrollable = if style.writing_mode.is_vertical() {
    overflow_creates_scroll_container(style.overflow_y) &&
    inline_content > inline_available
  } else {
    overflow_creates_scroll_container(style.overflow_x) &&
    inline_content > inline_available
  }
  let block_scrollable = if style.writing_mode.is_vertical() {
    overflow_creates_scroll_container(style.overflow_x) &&
    block_content > block_available
  } else {
    overflow_creates_scroll_container(style.overflow_y) &&
    block_content > block_available
  }
  if !inline_scrollable && !block_scrollable {
    return children
  }
  let inline_offset = if inline_scrollable {
    overflow_alignment_track_offset(
      style.justify_content,
      style.justify_content_unsafe,
      inline_available,
      inline_content,
      inline_min,
      logical_start_is_physical_min_inline(style.writing_mode, style.direction),
      true,
    )
  } else {
    0.0
  }
  let block_offset = if block_scrollable {
    overflow_alignment_track_offset(
      style.align_content,
      style.align_content_unsafe,
      block_available,
      block_content,
      block_min,
      logical_start_is_physical_min_block(style.writing_mode),
      false,
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
    return children
  }
  children.map(fn(child) {
    { ..child, x: child.x + offset_x, y: child.y + offset_y }
  })
}
