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

///|
pub using @node {type DispatchFn, type LayoutDispatchFunc}

// =============================================================================
// Re-exports from tree
// =============================================================================

///|
pub using @tree {type LayoutNode, type LayoutTree, type CacheStats}

///|
pub using @tree {type IntrinsicState, type ResourceId}

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

///|
fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) {
    @dispatch.compute(node, ctx, dispatch)
  })
}

///|
/// Initialize the global layout dispatcher used by incremental layout.
pub fn setup() -> Unit {
  @dispatch.setup()
}

///|
/// Reset all intrinsic size caches.
pub fn reset_intrinsic_cache() -> Unit {
  @dispatch.reset_intrinsic_cache()
}

///|
/// Clear intrinsic cache for a specific node uid.
pub fn clear_intrinsic_cache_for_node(uid : Int) -> Unit {
  @dispatch.clear_intrinsic_cache_for_node(uid)
}

///|
/// Compute layout for a node tree with given viewport.
pub fn compute_layout(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @types.Layout {
  let ctx : @types.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @types.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
    stretch_width: false,
    stretch_height: false,
  }
  dispatch_compute(node, ctx)
}

///|
/// Compute layout with warning aggregation.
pub fn compute_layout_with_warnings(
  node : @node.Node,
  viewport : @types.Size[Double],
) -> @types.LayoutResult {
  let ctx : @types.LayoutContext = {
    available_width: viewport.width,
    available_height: Some(viewport.height),
    sizing_mode: @types.MaxContent,
    viewport_width: viewport.width,
    viewport_height: viewport.height,
    stretch_width: false,
    stretch_height: false,
  }
  dispatch_compute_with_warnings(node, ctx)
}

///|
fn dispatch_compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  let dispatch = default_dispatch()
  match node.style.display {
    @types.Flex | @types.InlineFlex => @flex.compute(node, ctx, dispatch)
    @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
      @block.compute(node, ctx, dispatch)
    _ => @dispatch.compute_layout(node, ctx)
  }
}

///|
fn dispatch_compute_with_warnings(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.LayoutResult {
  let dispatch = default_dispatch()
  match node.style.display {
    @types.Flex | @types.InlineFlex =>
      @flex.compute_with_warnings(node, ctx, dispatch)
    @types.Block | @types.Inline | @types.InlineBlock | @types.FlowRoot =>
      @block.compute_with_warnings(node, ctx, dispatch)
    _ => {
      let layout = @dispatch.compute_layout(node, ctx)
      { layout, warnings: [] }
    }
  }
}

///|
/// Compute layout with an explicit LayoutContext.
pub fn compute_layout_in_context(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  @dispatch.compute_layout(node, ctx)
}

///|
pub fn compute_block_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  @block.compute(node, ctx, default_dispatch())
}

///|
pub fn compute_block_layout_with_dispatch(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  @block.compute(node, ctx, dispatch)
}

///|
pub fn compute_flex_layout(
  node : @node.Node,
  ctx : @types.LayoutContext,
) -> @types.Layout {
  @flex.compute(node, ctx, default_dispatch())
}

///|
pub fn compute_flex_layout_with_dispatch(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  @flex.compute(node, ctx, dispatch)
}

///|
pub fn compute_grid_layout_in_context(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  @grid.compute(node, ctx, dispatch)
}

///|
pub fn compute_grid_layout(
  node : @node.Node,
  available_width : Double,
  available_height : Double,
) -> @types.Layout {
  @grid.compute_layout(node, available_width, available_height)
}
