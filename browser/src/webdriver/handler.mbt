///|
/// WebDriver Handler - Connects WebDriver/RPC protocol to Browser implementation
///
/// This module provides the dispatch layer that routes incoming
/// API commands to actual browser operations.

// =============================================================================
// Browser Context Manager
// =============================================================================

///|
/// Manages browser instances for WebDriver sessions
pub struct BrowserManager {
  browsers : Map[String, @browser.Browser]
  mut next_id : Int
  default_width : Int
  default_height : Int
}

///|
/// Create a new browser manager
pub fn BrowserManager::new() -> BrowserManager {
  { browsers: {}, next_id: 1, default_width: 800, default_height: 600 }
}

///|
/// Create a new browser manager with custom viewport
pub fn BrowserManager::new_with_viewport(
  width : Int,
  height : Int,
) -> BrowserManager {
  { browsers: {}, next_id: 1, default_width: width, default_height: height }
}

///|
/// Generate a unique context ID
fn BrowserManager::generate_id(self : BrowserManager) -> String {
  let id = "ctx-" + self.next_id.to_string()
  self.next_id = self.next_id + 1
  id
}

///|
/// Create a new browser context
pub fn BrowserManager::create_context(self : BrowserManager) -> String {
  let id = self.generate_id()
  let browser = @browser.Browser::new(self.default_width, self.default_height)
  self.browsers[id] = browser
  id
}

///|
/// Get a browser by context ID
pub fn BrowserManager::get_browser(
  self : BrowserManager,
  context_id : String,
) -> @browser.Browser? {
  self.browsers.get(context_id)
}

///|
/// Close a browser context
pub fn BrowserManager::close_context(
  self : BrowserManager,
  context_id : String,
) -> Bool {
  match self.browsers.get(context_id) {
    Some(_) => {
      self.browsers.remove(context_id)
      true
    }
    None => false
  }
}

///|
/// List all context IDs
pub fn BrowserManager::list_contexts(self : BrowserManager) -> Array[String] {
  let ids : Array[String] = []
  for id, _ in self.browsers {
    ids.push(id)
  }
  ids
}

// =============================================================================
// RPC Handler
// =============================================================================

///|
/// Handle an RPC request and return a response
/// This is the main entry point for processing JSON-RPC requests
pub async fn handle_rpc(
  manager : BrowserManager,
  request : RpcRequest,
) -> RpcResponse {
  let id = request.id
  let parsed = parse_method(request.method_name)
  match parsed {
    None =>
      rpc_error(id, MethodNotFound, "Unknown method: " + request.method_name)
    Some(api_method) => dispatch_method(manager, id, api_method, request.params)
  }
}

///|
/// Dispatch an API method to the appropriate handler
async fn dispatch_method(
  manager : BrowserManager,
  id : RpcId,
  api_method : ApiMethod,
  params : Map[String, String],
) -> RpcResponse {
  match api_method {
    // Context management
    NewContext => {
      let context_id = manager.create_context()
      rpc_success_string(id, context_id)
    }
    CloseContext(context_id~) => {
      let ctx_id = params.get("context_id").unwrap_or(context_id)
      if manager.close_context(ctx_id) {
        rpc_success_null(id)
      } else {
        api_error_to_rpc(id, ContextNotFound(context_id=ctx_id))
      }
    }
    // Navigation
    Goto(page_id~, url~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      let nav_url = params.get("url").unwrap_or(url)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) =>
          try {
            let _ = browser.navigate(nav_url)
            rpc_success_null(id)
          } catch {
            err =>
              api_error_to_rpc(
                id,
                NavigationFailed(url=nav_url, reason=err.to_string()),
              )
          }
      }
    }
    GoBack(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) =>
          try {
            let result = browser.go_back()
            match result {
              Some(url) => rpc_success_string(id, url)
              None => rpc_success_null(id)
            }
          } catch {
            err => api_error_to_rpc(id, InternalError(message=err.to_string()))
          }
      }
    }
    GoForward(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) =>
          try {
            let result = browser.go_forward()
            match result {
              Some(url) => rpc_success_string(id, url)
              None => rpc_success_null(id)
            }
          } catch {
            err => api_error_to_rpc(id, InternalError(message=err.to_string()))
          }
      }
    }
    Reload(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) => {
          let url = browser.current_url
          if url.length() == 0 {
            rpc_success_null(id)
          } else {
            try {
              let _ = browser.navigate(url)
              rpc_success_null(id)
            } catch {
              err =>
                api_error_to_rpc(
                  id,
                  NavigationFailed(url~, reason=err.to_string()),
                )
            }
          }
        }
      }
    }
    // Page state
    Url(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) => rpc_success_string(id, browser.current_url)
      }
    }
    Title(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) => {
          // Extract title from HTML - simple approach
          let title = extract_title(browser.html_content)
          rpc_success_string(id, title)
        }
      }
    }
    Content(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) => rpc_success_string(id, browser.html_content)
      }
    }
    // Screenshot (returns ANSI text representation)
    Screenshot(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_browser(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(browser) => {
          let text = browser.render_text()
          rpc_success_string(id, text)
        }
      }
    }
    // Not implemented yet
    _ => rpc_error(id, MethodNotFound, "Method not yet implemented")
  }
}

///|
/// Extract title from HTML content
fn extract_title(html : String) -> String {
  // Simple title extraction - look for <title>...</title>
  let lower = html.to_lower()
  let start_tag = "<title>"
  let end_tag = "</title>"
  match lower.find(start_tag) {
    None => ""
    Some(start_idx) => {
      let content_start = start_idx + start_tag.length()
      let rest = html[content_start:].to_string() catch { _ => return "" }
      let rest_lower = rest.to_lower()
      match rest_lower.find(end_tag) {
        None => ""
        Some(end_idx) => rest[:end_idx].to_string() catch { _ => "" }
      }
    }
  }
}
