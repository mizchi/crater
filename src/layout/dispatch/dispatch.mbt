///|
/// Layout dispatcher - chooses the correct layout algorithm based on display type
/// This module resolves the circular dependency between block and flex layouts.

///|
/// Compute layout for a node, dispatching to the appropriate layout algorithm
/// based on the node's display property.
pub fn compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  match node.style.display {
    @types.Flex | @types.InlineFlex =>
      apply_initial_scroll_snap(node, @flex.compute(node, ctx, dispatch))
    @types.Grid | @types.InlineGrid =>
      apply_initial_scroll_snap(node, @grid.compute(node, ctx, dispatch))
    @types.Table | @types.InlineTable =>
      apply_initial_scroll_snap(node, @table.compute(node, ctx, dispatch))
    _ => @block.compute(node, ctx, dispatch)
  }
}

///|
fn apply_initial_scroll_snap(
  node : @node.Node,
  layout : @types.Layout,
) -> @types.Layout {
  if layout.children.is_empty() {
    return layout
  }
  if not(node.style.scroll_snap_type.is_mandatory()) {
    return layout
  }

  let supports_snap_x = node.style.scroll_snap_type.snaps_x() &&
    overflow_creates_scroll_container(node.style.overflow_x)
  let supports_snap_y = node.style.scroll_snap_type.snaps_y() &&
    overflow_creates_scroll_container(node.style.overflow_y)
  if not(supports_snap_x) && not(supports_snap_y) {
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

///|
/// Create the default dispatch function
pub fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) { compute(node, ctx, dispatch) })
}

///|
/// Compute layout with the default dispatcher (convenience function)
pub fn compute_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  let dispatch = default_dispatch()
  compute(node, ctx, dispatch)
}

///|
/// Clear intrinsic size cache for a specific node.
/// Call this when a node is marked dirty.
pub fn clear_intrinsic_cache_for_node(uid : Int) -> Unit {
  @flex.clear_intrinsic_cache_for_node(uid)
}

///|
/// Reset all intrinsic size caches.
/// Call this for a full re-layout.
pub fn reset_intrinsic_cache() -> Unit {
  @flex.reset_intrinsic_cache()
  @flex.reset_resolved_cache()
}

///|
/// Initialize the global layout dispatcher
/// Required for incremental compute caching to work properly
pub fn setup() -> Unit {
  @node.set_layout_dispatcher(
    @node.LayoutDispatchFunc(fn(node, ctx) {
      let dispatch = default_dispatch()
      compute(node, ctx, dispatch)
    }),
  )
}
