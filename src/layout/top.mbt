// =============================================================================
// Layout Package - Public API Entry Point
// =============================================================================
// This package re-exports Node and LayoutTree related types.
// For enum types (Display, Dimension, etc.), import "mizchi/crater/types" directly.
//
// Usage:
//   import {
//     "mizchi/crater/types",
//     "mizchi/crater/layout",
//   }
//   let style = @layout.Style::default()
//   style.display = @types.Flex
//   let node = @layout.Node::new("root", style, [])

// =============================================================================
// Re-exports from style
// =============================================================================

///|
pub using @style {type Style}

// =============================================================================
// Re-exports from node
// =============================================================================

///|
pub using @node {type Node}

// =============================================================================
// Re-exports from tree
// =============================================================================

///|
pub using @tree {type LayoutNode, type LayoutTree, type CacheStats}

// =============================================================================
// Convenience Constructors
// =============================================================================

///|
/// Create a new Size for viewport dimensions
pub fn size(width : Double, height : Double) -> @types.Size[Double] {
  @types.Size::new(width, height)
}

///|
/// Create a LayoutNode with default style (builder pattern start)
pub fn layout_node_create(id : String) -> @tree.LayoutNode {
  @tree.LayoutNode::create_with_id(id)
}

///|
/// Create a new LayoutTree from a LayoutNode
pub fn layout_tree(
  root : @tree.LayoutNode,
  viewport_width : Double,
  viewport_height : Double,
) -> @tree.LayoutTree {
  @tree.LayoutTree::new(root, viewport_width, viewport_height)
}

///|
/// Create a LayoutTree from an immutable Node
pub fn layout_tree_from_node(
  root : @node.Node,
  viewport_width : Double,
  viewport_height : Double,
) -> @tree.LayoutTree {
  @tree.LayoutTree::from_node(root, viewport_width, viewport_height)
}
