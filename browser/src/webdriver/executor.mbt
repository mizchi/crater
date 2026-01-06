///|
/// Protocol-First Executor
///
/// All browser operations MUST go through this module.
/// This ensures:
/// 1. Consistent protocol handling
/// 2. Operation logging for debug/replay
/// 3. Single source of truth for all browser control

// =============================================================================
// Execution Context
// =============================================================================

///|
/// Execution context with logging and state management
pub struct Executor {
  manager : CdpSessionManager
  /// Enable operation logging
  mut logging_enabled : Bool
  /// Operation log (JSON-RPC format)
  operation_log : Array[String]
}

///|
/// Create a new executor
pub fn Executor::new() -> Executor {
  {
    manager: CdpSessionManager::new(),
    logging_enabled: false,
    operation_log: [],
  }
}

///|
/// Create executor with custom viewport (viewport info stored but not used in pure protocol mode)
pub fn Executor::new_with_viewport(_width : Int, _height : Int) -> Executor {
  {
    manager: CdpSessionManager::new(),
    logging_enabled: false,
    operation_log: [],
  }
}

///|
/// Enable operation logging
pub fn Executor::enable_logging(self : Executor) -> Unit {
  self.logging_enabled = true
}

///|
/// Disable operation logging
pub fn Executor::disable_logging(self : Executor) -> Unit {
  self.logging_enabled = false
}

///|
/// Get operation log
pub fn Executor::get_log(self : Executor) -> Array[String] {
  self.operation_log
}

///|
/// Clear operation log
pub fn Executor::clear_log(self : Executor) -> Unit {
  self.operation_log.clear()
}

// =============================================================================
// Core Execute Function - ALL OPERATIONS GO THROUGH HERE
// =============================================================================

///|
/// Execute an API method and return result
/// This is THE central entry point for all browser operations.
pub async fn Executor::execute(
  self : Executor,
  api_method : ApiMethod,
) -> ApiResult[String] {
  // Log the operation if enabled
  if self.logging_enabled {
    self.log_method(api_method)
  }
  // Execute via the handler
  let request = method_to_request(api_method)
  let response = handle_rpc(self.manager, request)
  // Convert RPC response to ApiResult
  let result = rpc_response_to_result(response)
  // Log the result if enabled
  if self.logging_enabled {
    self.log_result(result)
  }
  result
}

///|
/// Execute from JSON-RPC request string
pub async fn Executor::execute_json(self : Executor, json : String) -> String {
  // Parse JSON to RpcRequest
  let request = parse_rpc_request(json)
  // Log raw request if enabled
  if self.logging_enabled {
    self.operation_log.push("REQ: " + json)
  }
  // Execute
  let response = handle_rpc(self.manager, request)
  let response_json = response.to_json()
  // Log response if enabled
  if self.logging_enabled {
    self.operation_log.push("RES: " + response_json)
  }
  response_json
}

// =============================================================================
// Convenience Methods - All delegate to execute()
// =============================================================================

///|
/// Create a new browser context
pub async fn Executor::new_context(self : Executor) -> ApiResult[String] {
  self.execute(NewContext)
}

///|
/// Close a browser context
pub async fn Executor::close_context(
  self : Executor,
  context_id : String,
) -> ApiResult[String] {
  self.execute(CloseContext(context_id~))
}

///|
/// Navigate to URL
pub async fn Executor::goto(
  self : Executor,
  page_id : String,
  url : String,
) -> ApiResult[String] {
  self.execute(Goto(page_id~, url~))
}

///|
/// Go back in history
pub async fn Executor::go_back(
  self : Executor,
  page_id : String,
) -> ApiResult[String] {
  self.execute(GoBack(page_id~))
}

///|
/// Go forward in history
pub async fn Executor::go_forward(
  self : Executor,
  page_id : String,
) -> ApiResult[String] {
  self.execute(GoForward(page_id~))
}

///|
/// Reload page
pub async fn Executor::reload(
  self : Executor,
  page_id : String,
) -> ApiResult[String] {
  self.execute(Reload(page_id~))
}

///|
/// Get current URL
pub async fn Executor::url(
  self : Executor,
  page_id : String,
) -> ApiResult[String] {
  self.execute(Url(page_id~))
}

///|
/// Get page title
pub async fn Executor::title(
  self : Executor,
  page_id : String,
) -> ApiResult[String] {
  self.execute(Title(page_id~))
}

///|
/// Get page content
pub async fn Executor::content(
  self : Executor,
  page_id : String,
) -> ApiResult[String] {
  self.execute(Content(page_id~))
}

///|
/// Get screenshot (DOM tree as text in pure protocol mode)
pub async fn Executor::screenshot(
  self : Executor,
  page_id : String,
) -> ApiResult[String] {
  self.execute(Screenshot(page_id~))
}

// =============================================================================
// Internal Helpers
// =============================================================================

///|
/// Convert ApiMethod to RpcRequest
fn method_to_request(api_method : ApiMethod) -> RpcRequest {
  let method_name = api_method_to_string(api_method)
  let params = api_method_to_params(api_method)
  { jsonrpc: "2.0", id: RpcId::Num(0), method_name, params }
}

///|
/// Get method name string from ApiMethod
fn api_method_to_string(api_method : ApiMethod) -> String {
  match api_method {
    NewContext => "newContext"
    CloseContext(..) => "closeContext"
    NewPage(..) => "newPage"
    ClosePage(..) => "closePage"
    Pages(..) => "pages"
    Goto(..) => "goto"
    GoBack(..) => "goBack"
    GoForward(..) => "goForward"
    Reload(..) => "reload"
    Url(..) => "url"
    Title(..) => "title"
    Query(..) => "query"
    QueryAll(..) => "queryAll"
    WaitFor(..) => "waitFor"
    BoundingBox(..) => "boundingBox"
    TextContent(..) => "textContent"
    InnerText(..) => "innerText"
    InnerHtml(..) => "innerHtml"
    GetAttribute(..) => "getAttribute"
    IsVisible(..) => "isVisible"
    IsEnabled(..) => "isEnabled"
    IsChecked(..) => "isChecked"
    Click(..) => "click"
    DblClick(..) => "dblClick"
    RightClick(..) => "rightClick"
    Hover(..) => "hover"
    Focus(..) => "focus"
    Fill(..) => "fill"
    Press(..) => "press"
    Clear(..) => "clear"
    SelectOption(..) => "selectOption"
    Check(..) => "check"
    Uncheck(..) => "uncheck"
    MouseMove(..) => "mouseMove"
    MouseClick(..) => "mouseClick"
    MouseDown(..) => "mouseDown"
    MouseUp(..) => "mouseUp"
    KeyboardPress(..) => "keyboardPress"
    KeyboardType(..) => "keyboardType"
    Content(..) => "content"
    SetContent(..) => "setContent"
    ViewportSize(..) => "viewportSize"
    SetViewportSize(..) => "setViewportSize"
    Evaluate(..) => "evaluate"
    Screenshot(..) => "screenshot"
    ElementScreenshot(..) => "elementScreenshot"
    AccessibilitySnapshot(..) => "accessibilitySnapshot"
  }
}

///|
/// Extract params from ApiMethod
fn api_method_to_params(api_method : ApiMethod) -> Map[String, String] {
  let params : Map[String, String] = {}
  match api_method {
    NewContext => ()
    CloseContext(context_id~) => params["context_id"] = context_id
    NewPage(context_id~) => params["context_id"] = context_id
    ClosePage(page_id~) => params["page_id"] = page_id
    Pages(context_id~) => params["context_id"] = context_id
    Goto(page_id~, url~) => {
      params["page_id"] = page_id
      params["url"] = url
    }
    GoBack(page_id~) => params["page_id"] = page_id
    GoForward(page_id~) => params["page_id"] = page_id
    Reload(page_id~) => params["page_id"] = page_id
    Url(page_id~) => params["page_id"] = page_id
    Title(page_id~) => params["page_id"] = page_id
    Query(page_id~, selector~) => {
      params["page_id"] = page_id
      params["selector"] = selector
    }
    QueryAll(page_id~, selector~) => {
      params["page_id"] = page_id
      params["selector"] = selector
    }
    WaitFor(page_id~, selector~, timeout~) => {
      params["page_id"] = page_id
      params["selector"] = selector
      params["timeout"] = timeout.to_string()
    }
    BoundingBox(element_id~) => params["element_id"] = element_id
    TextContent(element_id~) => params["element_id"] = element_id
    InnerText(element_id~) => params["element_id"] = element_id
    InnerHtml(element_id~) => params["element_id"] = element_id
    GetAttribute(element_id~, name~) => {
      params["element_id"] = element_id
      params["name"] = name
    }
    IsVisible(element_id~) => params["element_id"] = element_id
    IsEnabled(element_id~) => params["element_id"] = element_id
    IsChecked(element_id~) => params["element_id"] = element_id
    Click(element_id~) => params["element_id"] = element_id
    DblClick(element_id~) => params["element_id"] = element_id
    RightClick(element_id~) => params["element_id"] = element_id
    Hover(element_id~) => params["element_id"] = element_id
    Focus(element_id~) => params["element_id"] = element_id
    Fill(element_id~, value~) => {
      params["element_id"] = element_id
      params["value"] = value
    }
    Press(element_id~, key~) => {
      params["element_id"] = element_id
      params["key"] = key
    }
    Clear(element_id~) => params["element_id"] = element_id
    SelectOption(element_id~, value~) => {
      params["element_id"] = element_id
      params["value"] = value
    }
    Check(element_id~) => params["element_id"] = element_id
    Uncheck(element_id~) => params["element_id"] = element_id
    MouseMove(page_id~, x~, y~) => {
      params["page_id"] = page_id
      params["x"] = x.to_string()
      params["y"] = y.to_string()
    }
    MouseClick(page_id~, x~, y~, button~) => {
      params["page_id"] = page_id
      params["x"] = x.to_string()
      params["y"] = y.to_string()
      params["button"] = button
    }
    MouseDown(page_id~, button~) => {
      params["page_id"] = page_id
      params["button"] = button
    }
    MouseUp(page_id~, button~) => {
      params["page_id"] = page_id
      params["button"] = button
    }
    KeyboardPress(page_id~, key~) => {
      params["page_id"] = page_id
      params["key"] = key
    }
    KeyboardType(page_id~, text~) => {
      params["page_id"] = page_id
      params["text"] = text
    }
    Content(page_id~) => params["page_id"] = page_id
    SetContent(page_id~, html~) => {
      params["page_id"] = page_id
      params["html"] = html
    }
    ViewportSize(page_id~) => params["page_id"] = page_id
    SetViewportSize(page_id~, width~, height~) => {
      params["page_id"] = page_id
      params["width"] = width.to_string()
      params["height"] = height.to_string()
    }
    Evaluate(page_id~, expression~) => {
      params["page_id"] = page_id
      params["expression"] = expression
    }
    Screenshot(page_id~) => params["page_id"] = page_id
    ElementScreenshot(element_id~) => params["element_id"] = element_id
    AccessibilitySnapshot(page_id~) => params["page_id"] = page_id
  }
  params
}

///|
/// Convert RpcResponse to ApiResult
fn rpc_response_to_result(response : RpcResponse) -> ApiResult[String] {
  match response {
    Success(result~, ..) => ApiResult::Ok(result)
    Error(message~, ..) => ApiResult::Err(InternalError(message~))
  }
}

///|
/// Parse JSON string to RpcRequest (simplified)
fn parse_rpc_request(json : String) -> RpcRequest {
  let obj = parse_json_object(json)
  let id = match obj.get("id") {
    Some(id_str) => {
      // Try to parse as integer
      let parsed = @strconv.parse_int(id_str) catch { _ => -1 }
      if parsed >= 0 {
        RpcId::Num(parsed)
      } else {
        RpcId::Str(id_str)
      }
    }
    None => RpcId::Null
  }
  let method_name = obj.get("method").unwrap_or("")
  // Parse params object if present
  let params : Map[String, String] = {}
  // For now, use simple key extraction from the JSON
  // A full implementation would parse nested objects
  { jsonrpc: obj.get("jsonrpc").unwrap_or("2.0"), id, method_name, params }
}

///|
/// Log an API method call
fn Executor::log_method(self : Executor, api_method : ApiMethod) -> Unit {
  let method_name = api_method_to_string(api_method)
  let params = api_method_to_params(api_method)
  let buf = StringBuilder::new()
  buf.write_string("CALL: ")
  buf.write_string(method_name)
  buf.write_string("(")
  let mut first = true
  for key, value in params {
    if not(first) {
      buf.write_string(", ")
    }
    buf.write_string(key)
    buf.write_string("=")
    buf.write_string(value)
    first = false
  }
  buf.write_string(")")
  self.operation_log.push(buf.to_string())
}

///|
/// Log a result
fn Executor::log_result(self : Executor, result : ApiResult[String]) -> Unit {
  match result {
    ApiResult::Ok(value) => self.operation_log.push("OK: " + value)
    ApiResult::Err(err) => self.operation_log.push("ERR: " + err.to_string())
  }
}
