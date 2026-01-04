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
  // Paint properties
  paint : PaintProperties
  // Stacking order (computed from z-index)
  stacking_order : Int
  // Text content (for text nodes)
  text : String?
  // Children
  children : Array[PaintNode]
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
) -> PaintNode {
  {
    id,
    tag,
    x,
    y,
    width,
    height,
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
/// Convert a Node and its Layout to a PaintNode tree
/// This combines style information from Node with position from Layout
pub fn from_node_and_layout(
  node : @node.Node,
  layout : @node.Layout,
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

  // Determine tag from node id (heuristic: use id or default to "div")
  let tag = if node.id == "#text" {
    "#text"
  } else if node.id.has_prefix("body") {
    "body"
  } else if node.id.has_prefix("html") {
    "html"
  } else {
    "div"
  }
  PaintNode::new(
    node.id,
    tag,
    layout.x,
    layout.y,
    layout.width,
    layout.height,
    paint,
    children,
    text=layout.text,
  )
}

///|
/// Convert a Layout tree to PaintNode tree using default styles
/// Use this when Node tree is not available
pub fn from_layout(layout : @node.Layout) -> PaintNode {
  let default_style = @style.Style::default()
  let paint = PaintProperties::from_style(default_style)
  let children : Array[PaintNode] = []
  for child in layout.children {
    children.push(from_layout(child))
  }
  let tag = if layout.id == "#text" { "#text" } else { "div" }
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
  )
}
