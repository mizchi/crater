///|
/// Top-level public API surface for `mizchi/crater-webdriver-bidi`.
///
/// Re-exports come straight from the source packages (`contract` / `rpc` /
/// `server`) rather than the broad `webdriver` implementation facade, so
/// downstream consumers see a single hop to the real definition. The
/// implementation package is still used for the transport (`BidiServer*`).
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
pub using @webdriver {type BidiServer, type BidiServerConfig}

///|
pub fn parse_method(method_name : String) -> ApiMethod? {
  @rpc.parse_method(method_name)
}
