///|
/// JavaScript Runtime Module - Executes JS with DOM bindings
///
/// MVP Implementation using Node.js vm module (JS target only)
/// Will be replaced with QuickJS later

///|
/// Error types for JS execution
/// Note: Some variants are reserved for future use
pub suberror JsError {
  // Reserved for future use when unsupported operations are detected
  NotSupported
  ExecutionError(String)
  // Reserved for future use when parsing JS syntax fails
  SyntaxError(String)
  // Reserved for future use when undefined references are detected
  ReferenceError(String)
}

///|
pub impl Show for JsError with output(self, logger) {
  match self {
    NotSupported => logger.write_string("JsError::NotSupported")
    ExecutionError(msg) => {
      logger.write_string("JsError::ExecutionError(")
      logger.write_string(msg)
      logger.write_string(")")
    }
    SyntaxError(msg) => {
      logger.write_string("JsError::SyntaxError(")
      logger.write_string(msg)
      logger.write_string(")")
    }
    ReferenceError(msg) => {
      logger.write_string("JsError::ReferenceError(")
      logger.write_string(msg)
      logger.write_string(")")
    }
  }
}

///|
/// Result of JS execution
pub struct JsResult {
  /// Return value (JSON serialized)
  value : String
  /// Console logs captured during execution
  logs : Array[String]
  /// Whether execution succeeded
  success : Bool
}

///|
/// Create a new JS result value
pub fn JsResult::new(
  value : String,
  logs : Array[String],
  success : Bool,
) -> JsResult {
  { value, logs, success }
}

///|
/// JavaScript runtime abstraction
pub(open) trait JsRuntime {
  /// Initialize runtime if needed (idempotent)
  init(Self) -> Unit

  /// Execute JS against DomTree and return result
  execute(Self, @dom.DomTree, String) -> JsResult raise JsError
}

///|
/// JavaScript execution context bound to a DomTree
pub struct JsContext {
  /// The DOM tree this context operates on
  dom : @dom.DomTree
  /// Console log buffer
  mut logs : Array[String]
  /// Runtime implementation
  runtime : &JsRuntime
}

///|
/// Create a new JS execution context with a DOM tree
pub fn JsContext::new(dom : @dom.DomTree) -> JsContext {
  { dom, logs: [], runtime: default_js_runtime() }
}

///|
/// Create a new JS execution context with explicit runtime
pub fn JsContext::new_with_runtime(
  dom : @dom.DomTree,
  runtime : &JsRuntime,
) -> JsContext {
  { dom, logs: [], runtime }
}

///|
/// Get the DOM tree from context
pub fn JsContext::get_dom(self : JsContext) -> @dom.DomTree {
  self.dom
}

///|
/// Clear console logs
pub fn JsContext::clear_logs(self : JsContext) -> Unit {
  self.logs = []
}

///|
/// Get captured console logs
pub fn JsContext::get_logs(self : JsContext) -> Array[String] {
  self.logs
}

///|
/// Execute JavaScript code with runtime abstraction
pub fn JsContext::execute(
  self : JsContext,
  code : String,
) -> JsResult raise JsError {
  self.runtime.init()
  let result = self.runtime.execute(self.dom, code)
  for log in result.logs {
    self.logs.push(log)
  }
  if not(result.success) {
    raise ExecutionError(result.value)
  }
  result
}
