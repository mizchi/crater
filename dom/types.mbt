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
  Element
  Text
  Comment
} derive(Eq, Show)

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
  InvalidSelector(selector~ : String)
  NavigationFailed(url~ : String, reason~ : String)
  Timeout(operation~ : String)
  InvalidOperation(message~ : String)
} derive(Show)

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
