///|
/// Top-level public API surface for `mizchi/crater-webdriver-bidi`.
///
/// Re-exports come straight from the source packages (`contract` / `rpc` /
/// `server`) rather than the kitchen-sink `webdriver` facade, so downstream
/// consumers see a single hop to the real definition. `webdriver` is still
/// re-exported for the transport (`BidiServer*`) and CDP-handler types that
/// have not been split out yet.
pub using @contract {
  type ApiError,
  type ApiMethod,
  type Capabilities,
  type ErrorCode,
  type PageLoadStrategy,
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
pub using @server {type SessionManager, type SessionState}

///|
pub using @webdriver {
  type BidiServer,
  type BidiServerConfig,
  type CdpHandlerError,
  type CdpSessionManager,
}

///|
pub fn parse_method(method_name : String) -> ApiMethod? {
  @webdriver.parse_method(method_name)
}

///|
pub fn handle_find_element(
  session : @cdp.CdpSession,
  strategy : String,
  selector : String,
) -> Result[Int, CdpHandlerError] {
  @webdriver.handle_find_element(session, strategy, selector)
}

///|
pub fn handle_find_elements(
  session : @cdp.CdpSession,
  strategy : String,
  selector : String,
) -> Result[Array[Int], CdpHandlerError] {
  @webdriver.handle_find_elements(session, strategy, selector)
}

///|
pub fn handle_get_element_attribute(
  session : @cdp.CdpSession,
  element_id : Int,
  name : String,
) -> Result[String?, CdpHandlerError] {
  @webdriver.handle_get_element_attribute(session, element_id, name)
}

///|
pub fn handle_get_element_tag_name(
  session : @cdp.CdpSession,
  element_id : Int,
) -> Result[String, CdpHandlerError] {
  @webdriver.handle_get_element_tag_name(session, element_id)
}

///|
pub fn handle_get_element_text(
  session : @cdp.CdpSession,
  element_id : Int,
) -> Result[String, CdpHandlerError] {
  @webdriver.handle_get_element_text(session, element_id)
}

///|
pub fn handle_get_current_url(session : @cdp.CdpSession) -> String {
  @webdriver.handle_get_current_url(session)
}

///|
pub fn handle_get_title(session : @cdp.CdpSession) -> String {
  @webdriver.handle_get_title(session)
}

///|
pub fn handle_navigate(
  session : @cdp.CdpSession,
  url : String,
) -> Result[Unit, CdpHandlerError] {
  @webdriver.handle_navigate(session, url)
}

///|
pub fn handle_element_click(
  session : @cdp.CdpSession,
  element_id : Int,
) -> Result[Unit, CdpHandlerError] {
  @webdriver.handle_element_click(session, element_id)
}

///|
pub fn handle_rpc(
  manager : CdpSessionManager,
  request : RpcRequest,
) -> RpcResponse {
  @webdriver.handle_rpc(manager, request)
}
