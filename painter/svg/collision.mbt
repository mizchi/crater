// ============================================================================
// Collision Detection
// ============================================================================

///|
/// Check collision between two circles
pub fn collide_circle_circle(
  cx1 : Double,
  cy1 : Double,
  r1 : Double,
  cx2 : Double,
  cy2 : Double,
  r2 : Double,
) -> Bool {
  @msvg.collide_circle_circle(cx1, cy1, r1, cx2, cy2, r2)
}

///|
/// Check collision between two axis-aligned rectangles
pub fn collide_rect_rect(
  x1 : Double,
  y1 : Double,
  w1 : Double,
  h1 : Double,
  x2 : Double,
  y2 : Double,
  w2 : Double,
  h2 : Double,
) -> Bool {
  @msvg.collide_rect_rect(x1, y1, w1, h1, x2, y2, w2, h2)
}

///|
/// Check collision between circle and rectangle
pub fn collide_circle_rect(
  cx : Double,
  cy : Double,
  r : Double,
  rx : Double,
  ry : Double,
  rw : Double,
  rh : Double,
) -> Bool {
  @msvg.collide_circle_rect(cx, cy, r, rx, ry, rw, rh)
}

///|
/// Check collision between two shapes
pub fn collide_shapes(shape1 : Shape, shape2 : Shape) -> Bool {
  @msvg.collide_shapes(shape1.to_msvg(), shape2.to_msvg())
}

///|
/// Check collision between two SVGNodes (considering transforms)
pub fn SVGNode::collides_with(self : SVGNode, other : SVGNode) -> Bool {
  self.to_msvg().collides_with(other.to_msvg())
}
