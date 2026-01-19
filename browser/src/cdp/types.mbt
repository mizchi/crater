///|
/// CDP Types
///
/// Chrome DevTools Protocol type definitions.
/// These map closely to the official CDP specification.

///|
/// CDP Node - representation of a DOM node in CDP
pub struct CdpNode {
  node_id : Int
  backend_node_id : Int
  node_type : Int // 1=Element, 3=Text, 9=Document, etc.
  node_name : String
  local_name : String
  node_value : String
  child_node_count : Int?
  children : Array[CdpNode]?
  attributes : Array[String]? // [name, value, name, value, ...]
} derive(Show)

///|
/// CDP Box Model
pub struct CdpBoxModel {
  content : Array[Double] // [x1,y1, x2,y2, x3,y3, x4,y4]
  padding : Array[Double]
  border : Array[Double]
  margin : Array[Double]
  width : Int
  height : Int
} derive(Show)

///|
/// CDP Frame Info
pub struct CdpFrameInfo {
  id : String
  parent_id : String?
  loader_id : String
  name : String
  url : String
  security_origin : String
  mime_type : String
} derive(Show)

///|
/// CDP Navigation Entry
pub struct CdpNavigationEntry {
  id : Int
  url : String
  title : String
  transition_type : String
} derive(Show)

///|
/// CDP Error codes (subset)
pub enum CdpErrorCode {
  InvalidParams // -32602
  InternalError // -32603
  NodeNotFound // -32000
  NoSuchElement // -32000
} derive(Show)

///|
/// CDP Error
pub struct CdpError {
  code : Int
  message : String
} derive(Show)

///|
/// Create CDP error from code
pub fn CdpError::from_code(code : CdpErrorCode, message : String) -> CdpError {
  let code_num = match code {
    InvalidParams => -32602
    InternalError => -32603
    NodeNotFound => -32000
    NoSuchElement => -32000
  }
  { code: code_num, message }
}

///|
/// Convert core error to CDP error
pub fn core_to_cdp_error(err : @dom.CoreError) -> CdpError {
  match err {
    @dom.NodeNotFound(node_id~) =>
      CdpError::from_code(
        NodeNotFound,
        "Node not found: " + node_id.to_string(),
      )
    @dom.InvalidOperation(message~) =>
      CdpError::from_code(InvalidParams, message)
  }
}
