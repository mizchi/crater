///|
/// LayoutNode - Mutable node for incremental layout computation
/// Unlike Node (immutable), LayoutNode tracks dirty state and caches results

///|
/// Global counter for generating unique layout node IDs
let layout_node_uid_counter : Ref[Int] = { val: 0 }

///|
fn next_layout_uid() -> Int {
  let uid = layout_node_uid_counter.val
  layout_node_uid_counter.val = uid + 1
  uid
}

///|
/// Constraint key for cache lookup
pub struct ConstraintKey {
  available_width : Double
  available_height : Double? // None means unconstrained
  sizing_mode : @node.SizingMode
} derive(Eq)

///|
pub fn ConstraintKey::new(
  available_width : Double,
  available_height : Double?,
  sizing_mode : @node.SizingMode,
) -> ConstraintKey {
  { available_width, available_height, sizing_mode }
}

///|
/// Check if two constraints are approximately equal
pub fn ConstraintKey::approx_eq(
  self : ConstraintKey,
  other : ConstraintKey,
) -> Bool {
  let width_eq = (self.available_width - other.available_width).abs() < 0.001
  let height_eq = match (self.available_height, other.available_height) {
    (Some(a), Some(b)) => (a - b).abs() < 0.001
    (None, None) => true
    _ => false
  }
  width_eq && height_eq && self.sizing_mode == other.sizing_mode
}

///|
/// Cached layout result
pub struct LayoutCache {
  constraint : ConstraintKey
  result : @node.Layout
}

///|
/// Mutable layout node with dirty tracking
pub struct LayoutNode {
  id : String
  uid : Int
  style : @style.Style
  children : Array[LayoutNode]
  measure : @node.MeasureFunc?
  text : String?
  // Dirty bits
  mut dirty : Bool
  mut children_dirty : Bool
  // Cache
  mut cached_layout : LayoutCache?
  // Dependencies (computed from style)
  dependencies : DependencyKind
}

///|
pub fn LayoutNode::new(
  id : String,
  style : @style.Style,
  children : Array[LayoutNode],
) -> LayoutNode {
  {
    id,
    uid: next_layout_uid(),
    style,
    children,
    measure: None,
    text: None,
    dirty: true, // Initially dirty
    children_dirty: false,
    cached_layout: None,
    dependencies: analyze_style_dependencies(style),
  }
}

///|
pub fn LayoutNode::leaf(id : String, style : @style.Style) -> LayoutNode {
  {
    id,
    uid: next_layout_uid(),
    style,
    children: [],
    measure: None,
    text: None,
    dirty: true,
    children_dirty: false,
    cached_layout: None,
    dependencies: analyze_style_dependencies(style),
  }
}

///|
pub fn LayoutNode::with_measure(
  id : String,
  style : @style.Style,
  measure : @node.MeasureFunc,
) -> LayoutNode {
  {
    id,
    uid: next_layout_uid(),
    style,
    children: [],
    measure: Some(measure),
    text: None,
    dirty: true,
    children_dirty: false,
    cached_layout: None,
    dependencies: analyze_style_dependencies(style),
  }
}

///|
/// Mark this node as dirty and invalidate cache
pub fn LayoutNode::mark_dirty(self : LayoutNode) -> Unit {
  if self.dirty {
    return // Already dirty
  }
  self.dirty = true
  self.cached_layout = None
  // Also clear intrinsic size cache for this node
  @dispatch.clear_intrinsic_cache_for_node(self.uid)
}

///|
/// Mark that children need re-layout
pub fn LayoutNode::mark_children_dirty(self : LayoutNode) -> Unit {
  if self.children_dirty {
    return
  }
  self.children_dirty = true
}

///|
/// Clear dirty bits after layout
pub fn LayoutNode::clear_dirty(self : LayoutNode) -> Unit {
  self.dirty = false
  self.children_dirty = false
}

///|
/// Check if this node or any children need layout
pub fn LayoutNode::needs_layout(self : LayoutNode) -> Bool {
  self.dirty || self.children_dirty
}

///|
/// Convert LayoutNode to immutable Node (for existing layout functions)
/// Preserves uid for cache lookup
pub fn LayoutNode::to_node(self : LayoutNode) -> @node.Node {
  let children = self.children.map(fn(child) { child.to_node() })
  @node.Node::with_uid(self.id, self.uid, self.style, children)
}

///|
/// Create LayoutNode from immutable Node
pub fn LayoutNode::from_node(node : @node.Node) -> LayoutNode {
  let children = node.children.map(fn(child) { LayoutNode::from_node(child) })
  {
    id: node.id,
    uid: node.uid,
    style: node.style,
    children,
    measure: node.measure,
    text: node.text,
    dirty: true,
    children_dirty: false,
    cached_layout: None,
    dependencies: analyze_style_dependencies(node.style),
  }
}
