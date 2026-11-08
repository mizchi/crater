///|
/// CDP Types
///
/// Chrome DevTools Protocol type definitions.
/// These map closely to the official CDP specification.

///|
/// CDP Node - representation of a DOM node in CDP
#derive(Debug)
pub struct CdpNode {
  node_id : Int32
  backend_node_id : Int32
  node_type : Int32 // 1=Element, 3=Text, 9=Document, etc.
  node_name : String
  local_name : String
  node_value : String
  child_node_count : Int32?
  children : Array[CdpNode]?
  attributes : Array[String]? // [name, value, name, value, ...]
  shadow_roots : Array[CdpNode]?
  shadow_root_type : String?
}

///|
pub extend CdpNode with @debug.Debug::{to_repr}

///|
/// CDP Box Model
#derive(Debug)
pub struct CdpBoxModel {
  content : Array[Double] // [x1,y1, x2,y2, x3,y3, x4,y4]
  padding : Array[Double]
  border : Array[Double]
  margin : Array[Double]
  width : Int32
  height : Int32
}

///|
pub extend CdpBoxModel with @debug.Debug::{to_repr}

///|
/// CDP Frame Info
#derive(Debug)
pub struct CdpFrameInfo {
  id : String
  parent_id : String?
  loader_id : String
  name : String
  url : String
  security_origin : String
  mime_type : String
}

///|
pub extend CdpFrameInfo with @debug.Debug::{to_repr}

///|
/// CDP Navigation Entry
#derive(Debug)
pub struct CdpNavigationEntry {
  id : Int32
  url : String
  title : String
  transition_type : String
}

///|
pub extend CdpNavigationEntry with @debug.Debug::{to_repr}

///|
/// CDP Error codes (subset)
#derive(Debug)
pub enum CdpErrorCode {
  InvalidParams // -32602
  InternalError // -32603
  NodeNotFound // -32000
  NoSuchElement // -32000
}

///|
pub extend CdpErrorCode with @debug.Debug::{to_repr}

///|
/// CDP Error
#derive(Debug)
pub struct CdpError {
  code : Int32
  message : String
}

///|
pub extend CdpError with @debug.Debug::{to_repr}

///|
/// Create CDP error from code
pub fn CdpError::from_code(code : CdpErrorCode, message : String) -> CdpError {
  let code_num = match code {
    InvalidParams => -32602
    InternalError => -32603
    NodeNotFound => -32000
    NoSuchElement => -32000
  }
  { code: code_num, message, }
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
