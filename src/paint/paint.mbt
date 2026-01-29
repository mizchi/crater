// =============================================================================
// Paint Module - Visual properties and stacking context
// =============================================================================
//
// This module handles visual properties that affect rendering but not layout:
// - z-index and stacking context
// - visibility
// - opacity
// - (future) transform, filters, etc.
//
// Types Visibility, ZIndex are defined in style/ module.

// =============================================================================
// Paint Properties (visual properties not affecting layout)
// =============================================================================

///|
pub(all) struct PaintProperties {
  z_index : @style.ZIndex
  visibility : @style.Visibility
  opacity : Double // 0.0 = transparent, 1.0 = opaque
  color : @types.Color // Text color (computed)
  background_color : @types.Color // Background color (computed)
}

///|
pub fn PaintProperties::default() -> PaintProperties {
  {
    z_index: @style.ZIndex::Auto,
    visibility: @style.Visibility::Visible,
    opacity: 1.0,
    color: @types.Color::black(),
    background_color: @types.Color::transparent(),
  }
}

///|
pub fn PaintProperties::from_style(style : @style.Style) -> PaintProperties {
  {
    z_index: style.z_index,
    visibility: style.visibility,
    opacity: style.opacity,
    color: style.color,
    background_color: style.background_color,
  }
}

///|
pub impl Show for PaintProperties with output(self, logger) {
  logger.write_string("PaintProperties { z_index: ")
  self.z_index.output(logger)
  logger.write_string(", visibility: ")
  self.visibility.output(logger)
  logger.write_string(", opacity: ")
  self.opacity.output(logger)
  logger.write_string(", color: ")
  self.color.output(logger)
  logger.write_string(", background_color: ")
  self.background_color.output(logger)
  logger.write_string(" }")
}

///|
/// Check if the element should be rendered
pub fn PaintProperties::should_render(self : PaintProperties) -> Bool {
  match self.visibility {
    @style.Visibility::Visible => self.opacity > 0.0
    _ => false
  }
}

///|
/// Get z-index value (auto treated as 0)
pub fn PaintProperties::z_index_value(self : PaintProperties) -> Int {
  match self.z_index {
    @style.ZIndex::Auto => 0
    @style.ZIndex::Value(v) => v
  }
}

// =============================================================================
// Paint Node - Layout node with paint properties
// =============================================================================

///|
/// A node in the paint tree, containing layout info and paint properties
pub(all) struct PaintNode {
  // Identity
  id : String
  tag : String
  // Layout info (from compute)
  x : Double
  y : Double
  width : Double
  height : Double
  // Overflow clipping
  overflow_x : @types.Overflow
  overflow_y : @types.Overflow
  // Scroll dimensions (content extent for scrollable areas)
  scroll_width : Double
  scroll_height : Double
  // Legacy clip property (for accessibility)
  clip : @types.ClipRect
  // Paint properties
  paint : PaintProperties
  // Stacking order (computed from z-index)
  stacking_order : Int
  // Text content (for text nodes)
  text : String?
  // Children
  children : Array[PaintNode]
  // TODO: Add href field for proper link hit testing
  // Currently links are matched by text content via Browser.links array
}

///|
pub fn PaintNode::new(
  id : String,
  tag : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : PaintProperties,
  children : Array[PaintNode],
  text? : String? = None,
  overflow_x? : @types.Overflow = @types.Visible,
  overflow_y? : @types.Overflow = @types.Visible,
  scroll_width? : Double = 0.0,
  scroll_height? : Double = 0.0,
  clip? : @types.ClipRect = @types.ClipRect::Auto,
) -> PaintNode {
  {
    id,
    tag,
    x,
    y,
    width,
    height,
    overflow_x,
    overflow_y,
    scroll_width: if scroll_width == 0.0 {
      width
    } else {
      scroll_width
    },
    scroll_height: if scroll_height == 0.0 {
      height
    } else {
      scroll_height
    },
    clip,
    paint,
    stacking_order: paint.z_index_value(),
    text,
    children,
  }
}

///|
pub impl Show for PaintNode with output(self, logger) {
  logger.write_string(self.id)
  logger.write_string(" (")
  self.x.output(logger)
  logger.write_string(", ")
  self.y.output(logger)
  logger.write_string(") ")
  self.width.output(logger)
  logger.write_string("x")
  self.height.output(logger)
  if self.stacking_order != 0 {
    logger.write_string(" z:")
    self.stacking_order.output(logger)
  }
  if not(self.paint.should_render()) {
    logger.write_string(" [hidden]")
  }
  if self.paint.opacity < 1.0 {
    logger.write_string(" opacity:")
    self.paint.opacity.output(logger)
  }
  if self.clips_content() {
    logger.write_string(" [clips]")
  }
}

///|
/// Check if this node clips its content (overflow: hidden/scroll/auto or legacy clip)
pub fn PaintNode::clips_content(self : PaintNode) -> Bool {
  // Check overflow
  let overflow_clips = match (self.overflow_x, self.overflow_y) {
    (@types.Visible, @types.Visible) => false
    _ => true
  }
  // Check legacy clip property
  let clip_clips = match self.clip {
    @types.ClipRect::Auto => false
    @types.ClipRect::Rect(_) => true
  }
  overflow_clips || clip_clips
}

///|
/// Check if this node has horizontal scrollbar
/// Returns true when overflow-x is scroll, or auto with overflow
pub fn PaintNode::has_horizontal_scrollbar(self : PaintNode) -> Bool {
  match self.overflow_x {
    @types.Overflow::Scroll => true
    @types.Overflow::Auto => self.scroll_width > self.width
    _ => false
  }
}

///|
/// Check if this node has vertical scrollbar
/// Returns true when overflow-y is scroll, or auto with overflow
pub fn PaintNode::has_vertical_scrollbar(self : PaintNode) -> Bool {
  match self.overflow_y {
    @types.Overflow::Scroll => true
    @types.Overflow::Auto => self.scroll_height > self.height
    _ => false
  }
}

///|
/// Check if this node is scrollable (has any scrollbar)
pub fn PaintNode::is_scrollable(self : PaintNode) -> Bool {
  self.has_horizontal_scrollbar() || self.has_vertical_scrollbar()
}

///|
/// Get scrollable content dimensions (how much content can be scrolled)
/// Returns (max_scroll_x, max_scroll_y)
pub fn PaintNode::get_max_scroll(self : PaintNode) -> (Double, Double) {
  let max_x = if self.scroll_width > self.width {
    self.scroll_width - self.width
  } else {
    0.0
  }
  let max_y = if self.scroll_height > self.height {
    self.scroll_height - self.height
  } else {
    0.0
  }
  (max_x, max_y)
}

///|
/// Check if this node has a legacy clip property set
pub fn PaintNode::has_legacy_clip(self : PaintNode) -> Bool {
  match self.clip {
    @types.ClipRect::Auto => false
    @types.ClipRect::Rect(_) => true
  }
}

///|
/// Get legacy clip rect values (top, right, bottom, left offsets from element edges)
/// Returns None if clip: auto
pub fn PaintNode::get_legacy_clip(
  self : PaintNode,
) -> (Double, Double, Double, Double)? {
  match self.clip {
    @types.ClipRect::Auto => None
    @types.ClipRect::Rect(top~, right~, bottom~, left~) =>
      Some((top, right, bottom, left))
  }
}

///|
/// Get the effective clip rect for rendering
/// For legacy clip: rect(top, right, bottom, left), computes absolute coordinates
/// For overflow clipping, returns element bounds
/// Returns (x, y, width, height)
pub fn PaintNode::get_clip_rect(
  self : PaintNode,
) -> (Double, Double, Double, Double)? {
  // Legacy clip takes precedence
  match self.clip {
    @types.ClipRect::Rect(top~, right~, bottom~, left~) => {
      // clip: rect() uses offsets from top-left corner
      // rect(top, right, bottom, left) means:
      //   top edge at 'top' pixels from element top
      //   right edge at 'right' pixels from element left
      //   bottom edge at 'bottom' pixels from element top
      //   left edge at 'left' pixels from element left
      let clip_x = self.x + left
      let clip_y = self.y + top
      let clip_width = right - left
      let clip_height = bottom - top
      Some((clip_x, clip_y, clip_width, clip_height))
    }
    @types.ClipRect::Auto =>
      // Fall back to overflow clipping
      match (self.overflow_x, self.overflow_y) {
        (@types.Visible, @types.Visible) => None
        _ => Some((self.x, self.y, self.width, self.height))
      }
  }
}

// =============================================================================
// Stacking Context Sorting
// =============================================================================

///|
/// Sort children by stacking order for correct rendering
/// CSS stacking order: lower z-index renders first (behind)
pub fn sort_by_stacking_order(nodes : Array[PaintNode]) -> Array[PaintNode] {
  // Create a copy to sort
  let sorted = nodes.copy()
  // Simple insertion sort (stable sort preserves DOM order for equal z-index)
  for i = 1; i < sorted.length(); i = i + 1 {
    let key = sorted[i]
    let key_order = key.stacking_order
    let mut j = i - 1
    while j >= 0 && sorted[j].stacking_order > key_order {
      sorted[j + 1] = sorted[j]
      j = j - 1
    }
    sorted[j + 1] = key
  }
  sorted
}

///|
/// Recursively sort all nodes in the tree by stacking order
pub fn sort_tree_by_stacking_order(node : PaintNode) -> PaintNode {
  let sorted_children = sort_by_stacking_order(node.children).map(
    sort_tree_by_stacking_order,
  )
  { ..node, children: sorted_children }
}

// =============================================================================
// Flatten for Rendering
// =============================================================================

///|
/// Flatten paint tree to a list of nodes in render order
/// (back to front, respecting stacking context)
pub fn flatten_for_rendering(node : PaintNode) -> Array[PaintNode] {
  let result : Array[PaintNode] = []
  fn collect(n : PaintNode, arr : Array[PaintNode]) -> Unit {
    // Skip invisible nodes
    if not(n.paint.should_render()) {
      return
    }
    // Add this node
    arr.push(n)
    // Add children (already sorted by stacking order)
    for child in n.children {
      collect(child, arr)
    }
  }

  collect(node, result)
  result
}

// =============================================================================
// Node + Layout → PaintNode Conversion
// =============================================================================

///|
/// Extract tag name from node ID
/// Node IDs have format: "tag#id", "tag.class", or "tag"
fn extract_tag_from_id(id : String) -> String {
  // "#text" is a special case for text nodes
  if id == "#text" {
    return "#text"
  }
  // Find first '#' or '.' to determine where tag name ends
  let mut end_pos : Int? = None
  for i, c in id {
    if c == '#' || c == '.' {
      end_pos = Some(i)
      break
    }
  }
  match end_pos {
    Some(pos) => try! id[:pos].to_string()
    None => id
  }
}

///|
/// Convert a Node and its Layout to a PaintNode tree
/// This combines style information from Node with position from Layout
pub fn from_node_and_layout(
  node : @node.Node,
  layout : @types.Layout,
) -> PaintNode {
  let paint = PaintProperties::from_style(node.style)
  let children : Array[PaintNode] = []

  // Match children by index (assumes same order)
  let child_count = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  for i = 0; i < child_count; i = i + 1 {
    children.push(from_node_and_layout(node.children[i], layout.children[i]))
  }

  // Apply CSS transform (translate) to visual position
  let transform = node.style.transform
  let translate_x = transform.compute_translate_x(layout.width)
  let translate_y = transform.compute_translate_y(layout.height)

  // Extract tag name from node ID
  let tag = extract_tag_from_id(node.id)
  PaintNode::new(
    node.id,
    tag,
    layout.x + translate_x,
    layout.y + translate_y,
    layout.width,
    layout.height,
    paint,
    children,
    text=layout.text,
    overflow_x=layout.overflow_x,
    overflow_y=layout.overflow_y,
    clip=node.style.clip,
  )
}

///|
/// Calculate the maximum extent (bottom Y position) of a layout tree
/// This recursively finds the furthest point any content reaches
fn calculate_layout_extent(layout : @types.Layout, parent_y : Double) -> Double {
  let abs_y = parent_y + layout.y
  let mut max_extent = abs_y + layout.height
  for child in layout.children {
    let child_extent = calculate_layout_extent(child, abs_y)
    if child_extent > max_extent {
      max_extent = child_extent
    }
  }
  max_extent
}

///|
/// Convert a Node and its Layout to a PaintNode tree with viewport culling.
/// Nodes completely outside the viewport are skipped to reduce memory and improve rendering performance.
/// Parameters:
///   - node: The Node tree with style information
///   - layout: The Layout tree with position information
///   - viewport_top: Top Y coordinate of visible viewport (after scroll)
///   - viewport_bottom: Bottom Y coordinate of visible viewport
///   - parent_y: Absolute Y position of parent (for computing absolute positions)
pub fn from_node_and_layout_with_viewport(
  node : @node.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> PaintNode? {
  // Compute absolute Y position
  let abs_y = parent_y + layout.y

  // Calculate effective bottom including all descendants
  // This handles cases where:
  // 1. Parent has height: 100% (resolves to viewport height) but children extend beyond
  // 2. Parent has height: 0 but children have content
  // Recursively find the true content extent
  let effective_bottom = calculate_layout_extent(layout, abs_y)

  // Skip nodes that are completely outside the viewport
  // A node is outside if its effective bottom edge is above viewport top
  // or its top edge is below viewport bottom
  if effective_bottom < viewport_top || abs_y > viewport_bottom {
    return None
  }
  let paint = PaintProperties::from_style(node.style)
  let children : Array[PaintNode] = []

  // Match children by index (assumes same order)
  let child_count = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  for i = 0; i < child_count; i = i + 1 {
    // Recursively process children with viewport culling
    match
      from_node_and_layout_with_viewport(
        node.children[i],
        layout.children[i],
        viewport_top,
        viewport_bottom,
        abs_y,
      ) {
      Some(child) => children.push(child)
      None => () // Child is outside viewport, skip it
    }
  }

  // Apply CSS transform (translate) to visual position
  let transform = node.style.transform
  let translate_x = transform.compute_translate_x(layout.width)
  let translate_y = transform.compute_translate_y(layout.height)

  // Extract tag name from node ID
  let tag = extract_tag_from_id(node.id)
  Some(
    PaintNode::new(
      node.id,
      tag,
      layout.x + translate_x,
      layout.y + translate_y,
      layout.width,
      layout.height,
      paint,
      children,
      text=layout.text,
      overflow_x=layout.overflow_x,
      overflow_y=layout.overflow_y,
      clip=node.style.clip,
    ),
  )
}

///|
/// Convert a Layout tree to PaintNode tree using default styles
/// Use this when Node tree is not available
pub fn from_layout(layout : @types.Layout) -> PaintNode {
  let default_style = @style.Style::default()
  let paint = PaintProperties::from_style(default_style)
  let children : Array[PaintNode] = []
  for child in layout.children {
    children.push(from_layout(child))
  }
  let tag = extract_tag_from_id(layout.id)
  PaintNode::new(
    layout.id,
    tag,
    layout.x,
    layout.y,
    layout.width,
    layout.height,
    paint,
    children,
    text=layout.text,
    overflow_x=layout.overflow_x,
    overflow_y=layout.overflow_y,
  )
}

// =============================================================================
// Scrollable Element Detection
// =============================================================================

///|
/// Scrollable element info for initializing scroll states
pub(all) struct ScrollableElement {
  id : String
  scroll_width : Double
  scroll_height : Double
  client_width : Double
  client_height : Double
}

///|
/// Collect all scrollable elements from a PaintNode tree
/// Returns elements that have overflow: auto/scroll and content exceeding bounds
pub fn collect_scrollable_elements(
  node : PaintNode,
) -> Array[ScrollableElement] {
  let result : Array[ScrollableElement] = []
  fn collect(n : PaintNode, arr : Array[ScrollableElement]) -> Unit {
    // Check if this node is scrollable
    if n.is_scrollable() {
      arr.push({
        id: n.id,
        scroll_width: n.scroll_width,
        scroll_height: n.scroll_height,
        client_width: n.width,
        client_height: n.height,
      })
    }
    // Recurse into children
    for child in n.children {
      collect(child, arr)
    }
  }

  collect(node, result)
  result
}

///|
/// Hit test result for scrollable element
pub(all) struct ScrollableHitResult {
  id : String
  x : Double
  y : Double
  width : Double
  height : Double
  scroll_width : Double
  scroll_height : Double
}

///|
/// Find the innermost scrollable element at the given coordinates
/// Returns None if no scrollable element is found at that position
pub fn find_scrollable_at(
  node : PaintNode,
  x : Double,
  y : Double,
  parent_x : Double,
  parent_y : Double,
) -> ScrollableHitResult? {
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  // Check if point is inside this node
  if x < abs_x ||
    x >= abs_x + node.width ||
    y < abs_y ||
    y >= abs_y + node.height {
    return None
  }
  // Check children first (innermost element wins)
  for child in node.children {
    match find_scrollable_at(child, x, y, abs_x, abs_y) {
      Some(result) => return Some(result)
      None => ()
    }
  }
  // If this node is scrollable and point is inside, return it
  if node.is_scrollable() {
    return Some({
      id: node.id,
      x: abs_x,
      y: abs_y,
      width: node.width,
      height: node.height,
      scroll_width: node.scroll_width,
      scroll_height: node.scroll_height,
    })
  }
  None
}
