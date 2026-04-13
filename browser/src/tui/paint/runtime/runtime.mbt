///|
pub using @paint_plain {type PaintNode}

///|
pub using @paint_scroll {type ScrollableElement}

///|
pub struct PreparedPaint {
  tree : PaintNode
  scrollable_elements : Array[ScrollableElement]
}

///|
pub fn prepare_viewport_paint(
  node : @node.Node,
  layout : @types.Layout,
  viewport_top : Double,
  viewport_bottom : Double,
  parent_y : Double,
) -> PreparedPaint? {
  match
    @paint_viewport.from_node_and_layout_with_viewport(
      node, layout, viewport_top, viewport_bottom, parent_y,
    ) {
    Some(paint_node) => {
      let tree = @paint_traversal.sort_tree_by_stacking_order(paint_node)
      let scrollable_elements = @paint_scroll.collect_scrollable_elements(tree)
      Some({ tree, scrollable_elements })
    }
    None => None
  }
}
