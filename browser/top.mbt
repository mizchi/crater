///|
pub using @shell {type Browser, type OutputMode}

///|
pub using @cdp {
  type CdpBoxModel,
  type CdpContext,
  type CdpError,
  type CdpErrorCode,
  type CdpEvent,
  type CdpFrameInfo,
  type CdpNavigateResult,
  type CdpNavigationEntry,
  type CdpNavigationHistory,
  type CdpNode,
  type CdpOutMessage,
  type CdpProtocol,
  type CdpRequest,
  type CdpResponse,
  type CdpResponseError,
  type CdpSession,
  type DomDomain,
  type InputDomain,
  type PageDomain,
}

///|
pub using @http {
  type CacheDirectives,
  type CacheEntry,
  type CookieJar,
  type CredentialsMode,
  type FetchOptions,
  type HttpResponse,
  type MemoryCacheBackend,
  type ParsedCookie,
  type RequestMode,
  type RequestSandbox,
}

///|
pub using @js {
  type AsyncExecutionMode,
  type JsContext,
  type JsResult,
  type ScriptExecutor,
}

///|
pub fn browser(width : Int, height : Int, terminal_cols? : Int) -> Browser {
  @shell.Browser::new(width, height, terminal_cols?)
}

///|
pub fn cdp_protocol() -> CdpProtocol {
  @cdp.CdpProtocol::new()
}

///|
pub fn create_dom_init_code(dom_tree : @dom.DomTree) -> String {
  @js.create_dom_init_code(dom_tree)
}

///|
pub fn serialize_dom_for_mock(dom_tree : @dom.DomTree) -> String {
  @js.serialize_dom_for_mock(dom_tree)
}

///|
pub fn serialize_dom_to_html(dom_tree : @dom.DomTree) -> String {
  @js.serialize_dom_to_html(dom_tree)
}
