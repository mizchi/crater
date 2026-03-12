///|
/// JSON-RPC Protocol Layer
///
/// Provides JSON-RPC 2.0 compatible request/response handling
/// for the Browser API.

// =============================================================================
// JSON-RPC Types
// =============================================================================

///|
/// JSON-RPC request
pub(all) struct RpcRequest {
  jsonrpc : String // Should be "2.0"
  id : RpcId
  method_name : String
  params : Map[String, String] // Simplified: all params as strings
} derive(Show)

///|
/// JSON-RPC request ID (can be string or number)
pub(all) enum RpcId {
  Num(Int)
  Str(String)
  Null
} derive(Show, Eq)

///|
/// JSON-RPC response
pub(all) enum RpcResponse {
  Success(id~ : RpcId, result~ : String) // result is JSON string
  Error(id~ : RpcId, code~ : Int, message~ : String, data~ : String?)
} derive(Show)

// =============================================================================
// JSON-RPC Error Codes
// =============================================================================

///|
/// Standard JSON-RPC error codes
pub(all) enum RpcErrorCode {
  ParseError // -32700
  InvalidRequest // -32600
  MethodNotFound // -32601
  InvalidParams // -32602
  InternalError // -32603
  // Custom codes for browser automation
  ElementNotFound // -32000
  PageNotFound // -32001
  Timeout // -32002
  NavigationFailed // -32003
} derive(Show, Eq)

///|
/// Get numeric error code
pub fn RpcErrorCode::code(self : RpcErrorCode) -> Int {
  match self {
    ParseError => -32700
    InvalidRequest => -32600
    MethodNotFound => -32601
    InvalidParams => -32602
    InternalError => -32603
    ElementNotFound => -32000
    PageNotFound => -32001
    Timeout => -32002
    NavigationFailed => -32003
  }
}

// =============================================================================
// JSON-RPC Serialization
// =============================================================================

///|
/// Serialize RpcId to JSON
pub fn RpcId::to_json(self : RpcId) -> String {
  match self {
    Num(n) => n.to_string()
    Str(s) => "\"" + s + "\""
    Null => "null"
  }
}

///|
/// Serialize RpcResponse to JSON
pub fn RpcResponse::to_json(self : RpcResponse) -> String {
  match self {
    Success(id~, result~) =>
      "{\"jsonrpc\":\"2.0\",\"id\":" +
      id.to_json() +
      ",\"result\":" +
      result +
      "}"
    Error(id~, code~, message~, data~) => {
      let mut json = "{\"jsonrpc\":\"2.0\",\"id\":" + id.to_json()
      json = json + ",\"error\":{\"code\":" + code.to_string()
      json = json + ",\"message\":\"" + escape_string(message) + "\""
      match data {
        Some(d) => json = json + ",\"data\":" + d
        None => ()
      }
      json = json + "}}"
      json
    }
  }
}

///|
/// Escape string for JSON
fn escape_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s.iter() {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

// =============================================================================
// JSON-RPC Response Builders
// =============================================================================

///|
/// Create success response with null result
pub fn rpc_success_null(id : RpcId) -> RpcResponse {
  Success(id~, result="null")
}

///|
/// Create success response with string result
pub fn rpc_success_string(id : RpcId, value : String) -> RpcResponse {
  Success(id~, result="\"" + escape_string(value) + "\"")
}

///|
/// Create success response with bool result
pub fn rpc_success_bool(id : RpcId, value : Bool) -> RpcResponse {
  Success(id~, result=if value { "true" } else { "false" })
}

///|
/// Create success response with number result
pub fn rpc_success_number(id : RpcId, value : Double) -> RpcResponse {
  Success(id~, result=value.to_string())
}

///|
/// Create success response with raw JSON result
pub fn rpc_success_json(id : RpcId, json : String) -> RpcResponse {
  Success(id~, result=json)
}

///|
/// Create error response
pub fn rpc_error(
  id : RpcId,
  code : RpcErrorCode,
  message : String,
) -> RpcResponse {
  Error(id~, code=code.code(), message~, data=None)
}

///|
/// Create error response with data
pub fn rpc_error_with_data(
  id : RpcId,
  code : RpcErrorCode,
  message : String,
  data : String,
) -> RpcResponse {
  Error(id~, code=code.code(), message~, data=Some(data))
}

// =============================================================================
// API Error to RPC Error Conversion
// =============================================================================

///|
/// Convert ApiError to RpcResponse
pub fn api_error_to_rpc(id : RpcId, err : ApiError) -> RpcResponse {
  match err {
    ElementNotFound(selector~) =>
      rpc_error(
        id,
        RpcErrorCode::ElementNotFound,
        "Element not found: " + selector,
      )
    PageNotFound(page_id~) =>
      rpc_error(id, RpcErrorCode::PageNotFound, "Page not found: " + page_id)
    ContextNotFound(context_id~) =>
      rpc_error(
        id,
        RpcErrorCode::PageNotFound,
        "Context not found: " + context_id,
      )
    ApiError::Timeout(message~) => rpc_error(id, RpcErrorCode::Timeout, message)
    NavigationFailed(url~, reason~) =>
      rpc_error(
        id,
        RpcErrorCode::NavigationFailed,
        "Navigation to " + url + " failed: " + reason,
      )
    ElementNotVisible(element_id~) =>
      rpc_error(id, InvalidParams, "Element not visible: " + element_id)
    ElementNotEnabled(element_id~) =>
      rpc_error(id, InvalidParams, "Element not enabled: " + element_id)
    EvalError(message~) =>
      rpc_error(id, RpcErrorCode::InternalError, "Eval error: " + message)
    InvalidArgument(message~) => rpc_error(id, InvalidParams, message)
    NotSupported(message~) => rpc_error(id, MethodNotFound, message)
    InternalError(message~) =>
      rpc_error(id, RpcErrorCode::InternalError, message)
  }
}

// =============================================================================
// Method Dispatch
// =============================================================================

///|
/// Parse method name to ApiMethod
pub fn parse_method(name : String) -> ApiMethod? {
  // Note: This is a simplified parser. In production, you'd want to
  // also parse the params here.
  match name {
    "newContext" | "Browser.createContext" => Some(NewContext)
    "newPage" | "Page.create" => Some(NewPage(context_id=""))
    "goto" | "Page.navigate" => Some(Goto(page_id="", url=""))
    "goBack" | "Page.goBack" => Some(GoBack(page_id=""))
    "goForward" | "Page.goForward" => Some(GoForward(page_id=""))
    "reload" | "Page.reload" => Some(Reload(page_id=""))
    "url" | "Page.url" => Some(Url(page_id=""))
    "title" | "Page.title" => Some(Title(page_id=""))
    "query" | "Element.query" => Some(Query(page_id="", selector=""))
    "queryAll" | "Element.queryAll" => Some(QueryAll(page_id="", selector=""))
    "click" | "Element.click" => Some(Click(element_id=""))
    "fill" | "Element.fill" => Some(Fill(element_id="", value=""))
    "textContent" | "Element.textContent" => Some(TextContent(element_id=""))
    "screenshot" | "Page.screenshot" => Some(Screenshot(page_id=""))
    "evaluate" | "Runtime.evaluate" => Some(Evaluate(page_id="", expression=""))
    "accessibilitySnapshot" | "Accessibility.snapshot" =>
      Some(AccessibilitySnapshot(page_id=""))
    _ => None
  }
}

// =============================================================================
// Simple JSON Parser (for params)
// =============================================================================

///|
/// Parse a simple JSON object into a Map
/// Note: This is a very simplified parser for demo purposes
pub fn parse_json_object(json : String) -> Map[String, String] {
  let result : Map[String, String] = {}
  let json = json.trim().to_string()

  // Remove outer braces
  if not(json.has_prefix("{")) || not(json.has_suffix("}")) {
    return result
  }
  let content = substring(json, 1, json.length() - 1)
  let pairs = split_json_pairs(content)
  for pair in pairs {
    let parts = split_at_colon(pair)
    if parts.length() == 2 {
      let key = unquote(parts[0].trim().to_string())
      let value = unquote(parts[1].trim().to_string())
      result[key] = value
    }
  }
  result
}

///|
/// Get substring
fn substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in s.iter() {
    if i >= start && i < end {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Split JSON at top-level commas
fn split_json_pairs(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut depth = 0
  let mut in_string = false
  for c in s.iter() {
    match c {
      '"' => {
        in_string = not(in_string)
        current.write_char(c)
      }
      '{' | '[' => {
        if not(in_string) {
          depth = depth + 1
        }
        current.write_char(c)
      }
      '}' | ']' => {
        if not(in_string) {
          depth = depth - 1
        }
        current.write_char(c)
      }
      ',' =>
        if not(in_string) && depth == 0 {
          result.push(current.to_string())
          current.reset()
        } else {
          current.write_char(c)
        }
      _ => current.write_char(c)
    }
  }
  let last = current.to_string()
  if not(last.trim().to_string().is_empty()) {
    result.push(last)
  }
  result
}

///|
/// Split at first colon (for key:value)
fn split_at_colon(s : String) -> Array[String] {
  let result : Array[String] = []
  let mut found = false
  let before = StringBuilder::new()
  let after = StringBuilder::new()
  for c in s.iter() {
    if c == ':' && not(found) {
      found = true
    } else if found {
      after.write_char(c)
    } else {
      before.write_char(c)
    }
  }
  result.push(before.to_string())
  if found {
    result.push(after.to_string())
  }
  result
}

///|
/// Remove quotes from string
fn unquote(s : String) -> String {
  let s = s.trim().to_string()
  if s.length() >= 2 && s.has_prefix("\"") && s.has_suffix("\"") {
    substring(s, 1, s.length() - 1)
  } else {
    s
  }
}
