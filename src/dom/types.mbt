///|
/// Core Types for Browser Primitives
///
/// These types are used by all layers:
/// - Core Primitives (direct API)
/// - CDP Domains
/// - WebDriver
/// - WASM exports

///|
/// Node identifier - opaque handle to a DOM node
pub struct NodeId(Int) derive(Eq, Hash, Show)

///|
/// Rectangle with position and size
pub struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Show)

///|
/// 2D Point
pub struct Point {
  x : Double
  y : Double
} derive(Eq, Show)

///|
/// Node type enumeration
pub enum NodeType {
  Document
  DocumentType
  Element
  Text
  Comment
} derive(Eq, Show)

///|
/// Convert DOM node type constant to NodeType
/// See: https://developer.mozilla.org/en-US/docs/Web/API/Node/nodeType
pub fn NodeType::from_dom_constant(value : Int) -> NodeType? {
  match value {
    1 => Some(Element)
    3 => Some(Text)
    8 => Some(Comment)
    9 => Some(Document)
    10 => Some(DocumentType)
    _ => None
  }
}

///|
/// Basic node information
pub struct NodeInfo {
  node_id : NodeId
  node_type : NodeType
  node_name : String
  node_value : String
  child_count : Int
} derive(Show)

///|
/// Core error types
pub enum CoreError {
  NodeNotFound(node_id~ : NodeId)
  InvalidOperation(message~ : String)
} derive(Show)

///|
/// Scroll state for a scrollable element
pub struct ScrollState {
  scroll_left : Double
  scroll_top : Double
  scroll_width : Double
  scroll_height : Double
  client_width : Double
  client_height : Double
} derive(Eq, Show)

///|
/// Create a new ScrollState
pub fn ScrollState::new(
  scroll_width : Double,
  scroll_height : Double,
  client_width : Double,
  client_height : Double,
) -> ScrollState {
  {
    scroll_left: 0.0,
    scroll_top: 0.0,
    scroll_width,
    scroll_height,
    client_width,
    client_height,
  }
}

///|
/// Create a default ScrollState (no scrolling)
pub fn ScrollState::default() -> ScrollState {
  {
    scroll_left: 0.0,
    scroll_top: 0.0,
    scroll_width: 0.0,
    scroll_height: 0.0,
    client_width: 0.0,
    client_height: 0.0,
  }
}

///|
/// Clamp a value between min and max
fn clamp(value : Double, min_val : Double, max_val : Double) -> Double {
  if value < min_val {
    min_val
  } else if value > max_val {
    max_val
  } else {
    value
  }
}

///|
/// Set scroll position (clamped to valid range)
pub fn ScrollState::scroll_to(
  self : ScrollState,
  left : Double,
  top : Double,
) -> ScrollState {
  let max_left = if self.scroll_width > self.client_width {
    self.scroll_width - self.client_width
  } else {
    0.0
  }
  let max_top = if self.scroll_height > self.client_height {
    self.scroll_height - self.client_height
  } else {
    0.0
  }
  {
    ..self,
    scroll_left: clamp(left, 0.0, max_left),
    scroll_top: clamp(top, 0.0, max_top),
  }
}

///|
/// Scroll by delta (relative scroll)
pub fn ScrollState::scroll_by(
  self : ScrollState,
  delta_x : Double,
  delta_y : Double,
) -> ScrollState {
  self.scroll_to(self.scroll_left + delta_x, self.scroll_top + delta_y)
}

///|
/// Check if horizontal scrolling is possible
pub fn ScrollState::can_scroll_x(self : ScrollState) -> Bool {
  self.scroll_width > self.client_width
}

///|
/// Check if vertical scrolling is possible
pub fn ScrollState::can_scroll_y(self : ScrollState) -> Bool {
  self.scroll_height > self.client_height
}

///|
/// Get maximum scroll position (horizontal)
pub fn ScrollState::max_scroll_left(self : ScrollState) -> Double {
  if self.scroll_width > self.client_width {
    self.scroll_width - self.client_width
  } else {
    0.0
  }
}

///|
/// Get maximum scroll position (vertical)
pub fn ScrollState::max_scroll_top(self : ScrollState) -> Double {
  if self.scroll_height > self.client_height {
    self.scroll_height - self.client_height
  } else {
    0.0
  }
}

///|
/// Create a new Rect
pub fn Rect::new(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Rect {
  { x, y, width, height }
}

///|
/// Convert Rect to center point
pub fn Rect::center(self : Rect) -> Point {
  { x: self.x + self.width / 2.0, y: self.y + self.height / 2.0 }
}

///|
/// Create NodeId from Int
pub fn NodeId::from_int(id : Int) -> NodeId {
  NodeId(id)
}

///|
/// Get Int value from NodeId
pub fn NodeId::to_int(self : NodeId) -> Int {
  self.0
}

// =============================================================================
// SVG DOM Geometry Types
// =============================================================================

///|
/// SVGRect - represents a rectangle in SVG coordinate space
/// Used by getBBox(), getClientRect(), and other SVG methods
pub struct SVGRect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Show)

///|
/// Create a new SVGRect
pub fn SVGRect::new(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> SVGRect {
  { x, y, width, height }
}

///|
/// Create an empty SVGRect (0, 0, 0, 0)
pub fn SVGRect::empty() -> SVGRect {
  { x: 0.0, y: 0.0, width: 0.0, height: 0.0 }
}

///|
/// Convert SVGRect to Rect
pub fn SVGRect::to_rect(self : SVGRect) -> Rect {
  { x: self.x, y: self.y, width: self.width, height: self.height }
}

///|
/// Create SVGRect from Rect
pub fn SVGRect::from_rect(rect : Rect) -> SVGRect {
  { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
}

///|
/// SVGPoint - represents a point in SVG coordinate space
/// Has matrixTransform method for coordinate transformations
pub struct SVGPoint {
  x : Double
  y : Double
} derive(Eq, Show)

///|
/// Create a new SVGPoint
pub fn SVGPoint::new(x : Double, y : Double) -> SVGPoint {
  { x, y }
}

///|
/// Create an SVGPoint at origin (0, 0)
pub fn SVGPoint::origin() -> SVGPoint {
  { x: 0.0, y: 0.0 }
}

///|
/// Transform this point by a matrix
pub fn SVGPoint::matrix_transform(
  self : SVGPoint,
  matrix : SVGMatrix,
) -> SVGPoint {
  let new_x = matrix.a * self.x + matrix.c * self.y + matrix.e
  let new_y = matrix.b * self.x + matrix.d * self.y + matrix.f
  { x: new_x, y: new_y }
}

///|
/// SVGMatrix - 2D transformation matrix for SVG
/// Represents a 3x3 matrix: | a c e |
///                          | b d f |
///                          | 0 0 1 |
pub struct SVGMatrix {
  a : Double // scale x
  b : Double // skew y
  c : Double // skew x
  d : Double // scale y
  e : Double // translate x
  f : Double // translate y
} derive(Eq, Show)

///|
/// Create an identity matrix
pub fn SVGMatrix::identity() -> SVGMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
/// Create a new SVGMatrix with specified values
pub fn SVGMatrix::new(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> SVGMatrix {
  { a, b, c, d, e, f }
}

///|
/// Multiply this matrix by another matrix (this * other)
pub fn SVGMatrix::multiply(self : SVGMatrix, other : SVGMatrix) -> SVGMatrix {
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    e: self.a * other.e + self.c * other.f + self.e,
    f: self.b * other.e + self.d * other.f + self.f,
  }
}

///|
/// Get the inverse of this matrix
pub fn SVGMatrix::inverse(self : SVGMatrix) -> SVGMatrix? {
  let det = self.a * self.d - self.b * self.c
  if det == 0.0 {
    return None
  }
  let inv_det = 1.0 / det
  Some({
    a: self.d * inv_det,
    b: -self.b * inv_det,
    c: -self.c * inv_det,
    d: self.a * inv_det,
    e: (self.c * self.f - self.d * self.e) * inv_det,
    f: (self.b * self.e - self.a * self.f) * inv_det,
  })
}

///|
/// Create a translation matrix
pub fn SVGMatrix::translate(tx : Double, ty : Double) -> SVGMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: tx, f: ty }
}

///|
/// Create a scale matrix
pub fn SVGMatrix::scale(sx : Double, sy : Double) -> SVGMatrix {
  { a: sx, b: 0.0, c: 0.0, d: sy, e: 0.0, f: 0.0 }
}

///|
/// Create a uniform scale matrix
pub fn SVGMatrix::scale_uniform(s : Double) -> SVGMatrix {
  SVGMatrix::scale(s, s)
}

///|
/// Create a rotation matrix (angle in radians)
pub fn SVGMatrix::rotate(angle : Double) -> SVGMatrix {
  let cos_a = @math.cos(angle)
  let sin_a = @math.sin(angle)
  { a: cos_a, b: sin_a, c: -sin_a, d: cos_a, e: 0.0, f: 0.0 }
}

///|
/// Create a rotation matrix (angle in degrees)
pub fn SVGMatrix::rotate_deg(angle_deg : Double) -> SVGMatrix {
  SVGMatrix::rotate(angle_deg * 3.14159265358979323846 / 180.0)
}

///|
/// Create a skew X matrix (angle in radians)
pub fn SVGMatrix::skew_x(angle : Double) -> SVGMatrix {
  { a: 1.0, b: 0.0, c: @math.tan(angle), d: 1.0, e: 0.0, f: 0.0 }
}

///|
/// Create a skew Y matrix (angle in radians)
pub fn SVGMatrix::skew_y(angle : Double) -> SVGMatrix {
  { a: 1.0, b: @math.tan(angle), c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
/// Apply translation to this matrix (returns new matrix)
pub fn SVGMatrix::translate_self(
  self : SVGMatrix,
  tx : Double,
  ty : Double,
) -> SVGMatrix {
  self.multiply(SVGMatrix::translate(tx, ty))
}

///|
/// Apply scale to this matrix (returns new matrix)
pub fn SVGMatrix::scale_self(
  self : SVGMatrix,
  sx : Double,
  sy : Double,
) -> SVGMatrix {
  self.multiply(SVGMatrix::scale(sx, sy))
}

///|
/// Apply rotation to this matrix (returns new matrix)
pub fn SVGMatrix::rotate_self(self : SVGMatrix, angle : Double) -> SVGMatrix {
  self.multiply(SVGMatrix::rotate(angle))
}

///|
/// Flip on X axis
pub fn SVGMatrix::flip_x(self : SVGMatrix) -> SVGMatrix {
  self.multiply(SVGMatrix::scale(-1.0, 1.0))
}

///|
/// Flip on Y axis
pub fn SVGMatrix::flip_y(self : SVGMatrix) -> SVGMatrix {
  self.multiply(SVGMatrix::scale(1.0, -1.0))
}
