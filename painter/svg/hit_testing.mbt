// ============================================================================
// Hit Testing
// ============================================================================

///|
/// Hit test a shape (without transform)
pub fn hit_test_shape(px : Double, py : Double, shape : Shape) -> Bool {
  @msvg.hit_test_shape(px, py, shape_to_msvg(shape))
}

///|
/// Hit test an SVGNode at a point (in world coordinates)
/// Returns true if the point is inside the node's shape
pub fn SVGNode::hit_test(self : SVGNode, px : Double, py : Double) -> Bool {
  svg_node_to_msvg(self).hit_test(px, py)
}

///|
/// Find all nodes at a point (recursive, returns in front-to-back order)
pub fn SVGNode::hit_test_all(
  self : SVGNode,
  px : Double,
  py : Double,
) -> Array[SVGNode] {
  let results : Array[SVGNode] = []
  hit_test_recursive(self, px, py, Transform::identity(), results)
  results
}

///|
fn hit_test_recursive(
  node : SVGNode,
  px : Double,
  py : Double,
  parent_transform : Transform,
  results : Array[SVGNode],
) -> Unit {
  let world_transform = parent_transform.multiply(node.transform)
  let inv = world_transform.inverse()
  let (local_x, local_y) = inv.apply(px, py)
  // Check children first (front-to-back: last child is on top)
  for i = node.children.length() - 1; i >= 0; i = i - 1 {
    hit_test_recursive(node.children[i], px, py, world_transform, results)
  }
  // Then check this node
  if hit_test_shape(local_x, local_y, node.shape) {
    results.push(node)
  }
}
