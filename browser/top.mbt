///|
pub using @shell {type Browser, type OutputMode}

///|
pub using @http {
  type CredentialsMode,
  type FetchOptions,
  type HttpResponse,
  type RequestMode,
  type RequestSandbox,
}

///|
pub using @http_cache {
  type CacheDirectives,
  type CacheEntry,
  type MemoryCacheBackend,
}

///|
pub using @http_cookie_jar {type CookieJar, type ParsedCookie}

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
