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
