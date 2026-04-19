// =============================================================================
// Paint Traversal Package - PaintNode sorting and flattening
// =============================================================================

///|
/// Sort children by stacking order for correct rendering.
/// CSS stacking order: lower z-index renders first (behind).
pub fn sort_by_stacking_order(
  nodes : Array[@model.PaintNode],
) -> Array[@model.PaintNode] {
  if nodes.length() <= 1 {
    return nodes
  }
  let first_order = nodes[0].stacking_order
  let mut needs_sort = false
  for i = 1; i < nodes.length(); i = i + 1 {
    if nodes[i].stacking_order != first_order {
      needs_sort = true
      break
    }
  }
  if !needs_sort {
    return nodes
  }
  let sorted = nodes.copy()
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
pub fn sort_tree_by_stacking_order(node : @model.PaintNode) -> @model.PaintNode {
  if node.children.length() == 0 {
    return node
  }
  let sorted_children = sort_by_stacking_order(node.children).map(
    sort_tree_by_stacking_order,
  )
  { ..node, children: sorted_children }
}

///|
pub fn flatten_for_rendering(
  node : @model.PaintNode,
) -> Array[@model.PaintNode] {
  let result : Array[@model.PaintNode] = []
  fn collect(
    node : @model.PaintNode,
    result : Array[@model.PaintNode],
  ) -> Unit {
    if !node.paint.should_render() {
      return
    }
    result.push(node)
    for child in node.children {
      collect(child, result)
    }
  }

  collect(node, result)
  result
}
