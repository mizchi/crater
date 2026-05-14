///|
/// Compatibility facade for WebDriver contract types.
///
/// Keep transport, runtime, and browser-domain implementation out of the
/// contract package. This package re-exports the pure request/response/API
/// shapes so existing `mizchi/crater-webdriver-bidi/webdriver` imports keep
/// compiling while new code can depend on `.../contract` directly.
pub using @contract {
  type ApiError,
  type ApiMethod,
  type ApiResult,
  type Capabilities,
  type ContextId,
  type ElementId,
  type ElementRect,
  type ErrorCode,
  type HttpMethod,
  type LocatorStrategy,
  type Modifiers,
  type MouseButton,
  type PageId,
  type PageLoadStrategy,
  type Point,
  type ProxyConfig,
  type Rect,
  type Selector,
  type Session,
  type Timeouts,
  type Viewport,
  type WebDriverCommand,
  type WebDriverError,
  type WebDriverRequest,
  type WebDriverResponse,
  type WebDriverValue,
  type WindowRect,
}

///|
pub using @rpc {
  type RpcErrorCode,
  type RpcId,
  type RpcRequest,
  type RpcResponse,
}

///|
pub fn escape_json_string(s : String) -> String {
  @contract.escape_json_string(s)
}

///|
pub fn success_null() -> WebDriverResponse {
  @contract.success_null()
}

///|
pub fn success_string(s : String) -> WebDriverResponse {
  @contract.success_string(s)
}

///|
pub fn success_bool(b : Bool) -> WebDriverResponse {
  @contract.success_bool(b)
}

///|
pub fn success_element(element_id : String) -> WebDriverResponse {
  @contract.success_element(element_id)
}

///|
pub fn success_object(map : Map[String, WebDriverValue]) -> WebDriverResponse {
  @contract.success_object(map)
}

///|
pub fn error_response(code : ErrorCode, message : String) -> WebDriverResponse {
  @contract.error_response(code, message)
}

///|
pub fn parse_request(
  method_str : String,
  path : String,
  body : String,
) -> WebDriverRequest {
  @contract.parse_request(method_str, path, body)
}

///|
pub fn rpc_success_null(id : RpcId) -> RpcResponse {
  @rpc.rpc_success_null(id)
}

///|
pub fn rpc_success_string(id : RpcId, value : String) -> RpcResponse {
  @rpc.rpc_success_string(id, value)
}

///|
pub fn rpc_success_bool(id : RpcId, value : Bool) -> RpcResponse {
  @rpc.rpc_success_bool(id, value)
}

///|
pub fn rpc_success_number(id : RpcId, value : Double) -> RpcResponse {
  @rpc.rpc_success_number(id, value)
}

///|
pub fn rpc_success_json(id : RpcId, json : String) -> RpcResponse {
  @rpc.rpc_success_json(id, json)
}

///|
pub fn rpc_error(
  id : RpcId,
  code : RpcErrorCode,
  message : String,
) -> RpcResponse {
  @rpc.rpc_error(id, code, message)
}

///|
pub fn rpc_error_with_data(
  id : RpcId,
  code : RpcErrorCode,
  message : String,
  data : String,
) -> RpcResponse {
  @rpc.rpc_error_with_data(id, code, message, data)
}

///|
pub fn api_error_to_rpc(id : RpcId, err : ApiError) -> RpcResponse {
  @rpc.api_error_to_rpc(id, err)
}

///|
pub fn parse_method(name : String) -> ApiMethod? {
  @rpc.parse_method(name)
}

///|
pub fn parse_json_object(json : String) -> Map[String, String] {
  @rpc.parse_json_object(json)
}
