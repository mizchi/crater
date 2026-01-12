///|
/// WebDriver Handler - Connects WebDriver/RPC protocol to CDP implementation
///
/// This module provides the dispatch layer that routes incoming
/// API commands to CDP-based browser operations.

// =============================================================================
// RPC Handler
// =============================================================================

///|
/// Handle an RPC request and return a response
/// This is the main entry point for processing JSON-RPC requests
pub fn handle_rpc(
  manager : CdpSessionManager,
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
fn dispatch_method(
  manager : CdpSessionManager,
  id : RpcId,
  api_method : ApiMethod,
  params : Map[String, String],
) -> RpcResponse {
  match api_method {
    // Context management (session = page in this simplified model)
    NewContext => {
      let session_id = manager.create_session()
      rpc_success_string(id, session_id)
    }
    CloseContext(context_id~) => {
      let ctx_id = params.get("context_id").unwrap_or(context_id)
      if manager.close_session(ctx_id) {
        rpc_success_null(id)
      } else {
        api_error_to_rpc(id, ContextNotFound(context_id=ctx_id))
      }
    }
    // Navigation
    Goto(page_id~, url~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      let nav_url = params.get("url").unwrap_or(url)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) =>
          match handle_navigate(session, nav_url) {
            Ok(_) => rpc_success_null(id)
            Err(err) => {
              let (_, message) = err.to_w3c_error()
              api_error_to_rpc(
                id,
                NavigationFailed(url=nav_url, reason=message),
              )
            }
          }
      }
    }
    GoBack(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) => {
          let page = session.get_page()
          match page.go_back() {
            Ok(true) => rpc_success_string(id, page.get_url())
            Ok(false) => rpc_success_null(id)
            Err(e) => api_error_to_rpc(id, InternalError(message=e.message))
          }
        }
      }
    }
    GoForward(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) => {
          let page = session.get_page()
          match page.go_forward() {
            Ok(true) => rpc_success_string(id, page.get_url())
            Ok(false) => rpc_success_null(id)
            Err(e) => api_error_to_rpc(id, InternalError(message=e.message))
          }
        }
      }
    }
    Reload(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) => {
          let page = session.get_page()
          match page.reload() {
            Ok(_) => rpc_success_null(id)
            Err(e) => api_error_to_rpc(id, InternalError(message=e.message))
          }
        }
      }
    }
    // Page state
    Url(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) => rpc_success_string(id, handle_get_current_url(session))
      }
    }
    Title(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) => rpc_success_string(id, handle_get_title(session))
      }
    }
    Content(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) => {
          // Get outer HTML of document
          let dom = session.get_dom()
          let doc_id = session.get_tree().get_document().to_int()
          match dom.get_outer_html(doc_id) {
            Ok(html) => rpc_success_string(id, html)
            Err(e) => api_error_to_rpc(id, InternalError(message=e.message))
          }
        }
      }
    }
    // Element finding
    Query(page_id~, selector~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      let sel = params.get("selector").unwrap_or(selector)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) =>
          match handle_find_element(session, "css selector", sel) {
            Ok(element_id) =>
              rpc_success_string(id, "element-" + element_id.to_string())
            Err(err) => {
              let (_, message) = err.to_w3c_error()
              api_error_to_rpc(id, ElementNotFound(selector=message))
            }
          }
      }
    }
    QueryAll(page_id~, selector~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      let sel = params.get("selector").unwrap_or(selector)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) =>
          match handle_find_elements(session, "css selector", sel) {
            Ok(element_ids) => {
              let ids_json = element_ids
                .map(fn(eid) { "\"element-" + eid.to_string() + "\"" })
                .join(",")
              rpc_success_json(id, "[" + ids_json + "]")
            }
            Err(err) => {
              let (_, message) = err.to_w3c_error()
              api_error_to_rpc(id, ElementNotFound(selector=message))
            }
          }
      }
    }
    // Element operations
    TextContent(element_id~) => {
      let elem_id = params.get("element_id").unwrap_or(element_id)
      handle_element_op(manager, id, elem_id, fn(session, node_id) {
        handle_get_element_text(session, node_id)
      })
    }
    GetAttribute(element_id~, name~) => {
      let elem_id = params.get("element_id").unwrap_or(element_id)
      let attr_name = params.get("name").unwrap_or(name)
      handle_element_attr_op(manager, id, elem_id, attr_name)
    }
    Click(element_id~) => {
      let elem_id = params.get("element_id").unwrap_or(element_id)
      handle_element_click_op(manager, id, elem_id)
    }
    // Screenshot (returns DOM tree as text)
    Screenshot(page_id~) => {
      let ctx_id = params.get("page_id").unwrap_or(page_id)
      match manager.get_session(ctx_id) {
        None => api_error_to_rpc(id, PageNotFound(page_id=ctx_id))
        Some(session) => {
          let dom = session.get_dom()
          let doc_id = session.get_tree().get_document().to_int()
          match dom.get_outer_html(doc_id) {
            Ok(html) => rpc_success_string(id, html)
            Err(e) => api_error_to_rpc(id, InternalError(message=e.message))
          }
        }
      }
    }
    // Not implemented yet
    _ => rpc_error(id, MethodNotFound, "Method not yet implemented")
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

///|
/// Parse element ID string to node ID
fn parse_element_id(element_id : String) -> Int? {
  // Format: "element-123" or just "123"
  let id_str = if element_id.has_prefix("element-") {
    element_id[8:].to_string() catch {
      _ => return None
    }
  } else {
    element_id
  }
  Some(@strconv.parse_int(id_str)) catch {
    _ => None
  }
}

///|
/// Get session from element ID (format: "ctx-1:element-123" or "element-123")
fn get_session_for_element(
  manager : CdpSessionManager,
  element_id : String,
) -> (@cdp.CdpSession, Int)? {
  // Try to find session containing this element
  // For now, search all sessions
  let node_id = match parse_element_id(element_id) {
    Some(id) => id
    None => return None
  }
  for session_id in manager.list_sessions() {
    match manager.get_session(session_id) {
      Some(session) => return Some((session, node_id))
      None => continue
    }
  }
  None
}

///|
/// Handle element operation with common error handling
fn handle_element_op(
  manager : CdpSessionManager,
  id : RpcId,
  element_id : String,
  op : (@cdp.CdpSession, Int) -> Result[String, CdpHandlerError],
) -> RpcResponse {
  match get_session_for_element(manager, element_id) {
    None => api_error_to_rpc(id, ElementNotFound(selector=element_id))
    Some((session, node_id)) =>
      match op(session, node_id) {
        Ok(result) => rpc_success_string(id, result)
        Err(err) => {
          let (_, message) = err.to_w3c_error()
          api_error_to_rpc(id, InternalError(message~))
        }
      }
  }
}

///|
/// Handle element attribute operation
fn handle_element_attr_op(
  manager : CdpSessionManager,
  id : RpcId,
  element_id : String,
  attr_name : String,
) -> RpcResponse {
  match get_session_for_element(manager, element_id) {
    None => api_error_to_rpc(id, ElementNotFound(selector=element_id))
    Some((session, node_id)) =>
      match handle_get_element_attribute(session, node_id, attr_name) {
        Ok(Some(value)) => rpc_success_string(id, value)
        Ok(None) => rpc_success_null(id)
        Err(err) => {
          let (_, message) = err.to_w3c_error()
          api_error_to_rpc(id, InternalError(message~))
        }
      }
  }
}

///|
/// Handle element click operation
fn handle_element_click_op(
  manager : CdpSessionManager,
  id : RpcId,
  element_id : String,
) -> RpcResponse {
  match get_session_for_element(manager, element_id) {
    None => api_error_to_rpc(id, ElementNotFound(selector=element_id))
    Some((session, node_id)) =>
      match handle_element_click(session, node_id) {
        Ok(_) => rpc_success_null(id)
        Err(err) => {
          let (_, message) = err.to_w3c_error()
          api_error_to_rpc(id, InternalError(message~))
        }
      }
  }
}
