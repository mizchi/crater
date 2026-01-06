///|
/// CDP Protocol Layer
///
/// JSON-RPC message handling for Chrome DevTools Protocol.
/// Handles parsing, dispatching, and response formatting.

///|
/// CDP Request message
pub struct CdpRequest {
  id : Int?
  request_method : String
  params : Json?
  session_id : String?
}

///|
/// CDP Response message
pub struct CdpResponse {
  id : Int?
  result : Json?
  error : CdpResponseError?
  session_id : String?
}

///|
/// CDP Response error
pub struct CdpResponseError {
  code : Int
  message : String
}

///|
/// Create new CDP response
pub fn CdpResponse::new(
  id : Int?,
  result : Json?,
  error : CdpResponseError?,
  session_id : String?,
) -> CdpResponse {
  { id, result, error, session_id }
}

///|
/// CDP Event message (no id)
pub struct CdpEvent {
  event_method : String
  params : Json?
  session_id : String?
}

///|
/// Create new CDP event
pub fn CdpEvent::new(
  event_method : String,
  params : Json?,
  session_id : String?,
) -> CdpEvent {
  { event_method, params, session_id }
}

///|
/// Message types that can be sent to clients
pub enum CdpOutMessage {
  Response(CdpResponse)
  Event(CdpEvent)
}

///|
/// Create Response message
pub fn CdpOutMessage::response(resp : CdpResponse) -> CdpOutMessage {
  Response(resp)
}

///|
/// Create Event message
pub fn CdpOutMessage::event(evt : CdpEvent) -> CdpOutMessage {
  Event(evt)
}

///|
/// CDP Protocol handler
pub struct CdpProtocol {
  /// Target domain
  target : TargetDomain
  /// Outgoing message buffer
  outbox : Array[CdpOutMessage]
  /// Enable lifecycle events
  mut lifecycle_events : Bool
}

///|
/// Create new protocol handler
pub fn CdpProtocol::new() -> CdpProtocol {
  { target: TargetDomain::new(), outbox: [], lifecycle_events: false }
}

///|
/// Process incoming JSON message
pub fn CdpProtocol::process_message(
  self : CdpProtocol,
  json_str : String,
) -> Result[Unit, String] {
  // Parse JSON
  let json = @json.parse(json_str) catch { _ => return Err("Invalid JSON") }
  // Extract fields
  let id = get_int_field(json, "id")
  let request_method = match get_string_field(json, "method") {
    Some(m) => m
    None => return Err("Missing method field")
  }
  let params = get_field(json, "params")
  let session_id = get_string_field(json, "sessionId")
  // Create request
  let request : CdpRequest = { id, request_method, params, session_id }
  // Dispatch
  self.dispatch(request)
}

///|
/// Dispatch request to appropriate domain
fn CdpProtocol::dispatch(
  self : CdpProtocol,
  request : CdpRequest,
) -> Result[Unit, String] {
  // Parse domain.action from method
  let parts = split_method(request.request_method)
  let (domain, action) = match parts {
    Some(p) => p
    None => return Err("Invalid method format")
  }
  // Dispatch to domain
  match domain {
    "Target" => self.dispatch_target(request, action)
    "DOM" => self.dispatch_dom(request, action)
    "Page" => self.dispatch_page(request, action)
    "Input" => self.dispatch_input(request, action)
    "Runtime" => self.dispatch_runtime(request, action)
    "Browser" => self.dispatch_browser(request, action)
    "Network" => self.dispatch_network(request, action)
    "Emulation" => self.dispatch_emulation(request, action)
    "Security" => self.dispatch_security(request, action)
    "Performance" => self.dispatch_performance(request, action)
    "Log" => self.dispatch_log(request, action)
    _ => {
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown domain: " + domain,
      )
      Ok(())
    }
  }
}

///|
/// Take all pending outgoing messages
pub fn CdpProtocol::take_messages(self : CdpProtocol) -> Array[CdpOutMessage] {
  let messages = self.outbox.copy()
  self.outbox.clear()
  messages
}

///|
/// Serialize outgoing message to JSON
pub fn CdpOutMessage::to_json(self : CdpOutMessage) -> String {
  match self {
    Response(resp) => response_to_json(resp)
    Event(evt) => event_to_json(evt)
  }
}

// =============================================================================
// Domain Dispatchers
// =============================================================================

///|
fn CdpProtocol::dispatch_target(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "createBrowserContext" =>
      match self.target.create_browser_context() {
        Ok(id) =>
          self.send_result(
            request.id,
            request.session_id,
            Some(make_object({ "browserContextId": Json::string(id) })),
          )
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    "disposeBrowserContext" => {
      let context_id = get_param_string(request.params, "browserContextId")
      match context_id {
        Some(id) =>
          match self.target.dispose_browser_context(id) {
            Ok(_) => self.send_result(request.id, request.session_id, None)
            Err(e) =>
              self.send_error(request.id, request.session_id, -32602, e.message)
          }
        None =>
          self.send_error(
            request.id,
            request.session_id,
            -32602,
            "Missing browserContextId",
          )
      }
    }
    "getBrowserContexts" => {
      let ids = self.target.get_browser_contexts()
      let json_ids = ids.map(fn(id) { Json::string(id) })
      self.send_result(
        request.id,
        request.session_id,
        Some(make_object({ "browserContextIds": Json::array(json_ids) })),
      )
    }
    "createTarget" => {
      let url = get_param_string(request.params, "url").unwrap_or("about:blank")
      let browser_context_id = get_param_string(
        request.params,
        "browserContextId",
      )
      match self.target.create_target(url, browser_context_id) {
        Ok(target_id) => {
          // Send targetCreated event if discover targets enabled
          if self.target.discover_targets {
            self.send_event(
              "Target.targetCreated",
              request.session_id,
              Some(
                make_object({
                  "targetInfo": target_info_to_json({
                    target_id,
                    target_type: "page",
                    title: "about:blank",
                    url,
                    attached: self.target.is_auto_attach(),
                    browser_context_id,
                  }),
                }),
              ),
            )
          }
          // Send attachedToTarget event if auto-attach is enabled
          if self.target.is_auto_attach() {
            // Get session ID from the context
            let session_id = match self.target.get_active_context() {
              Some(ctx) =>
                match ctx.get_session_id() {
                  Some(sid) => sid
                  None => "SID-" + target_id
                }
              None => "SID-" + target_id
            }
            self.send_event(
              "Target.attachedToTarget",
              None,
              Some(
                make_object({
                  "sessionId": Json::string(session_id),
                  "targetInfo": target_info_to_json({
                    target_id,
                    target_type: "page",
                    title: "about:blank",
                    url,
                    attached: true,
                    browser_context_id,
                  }),
                  "waitingForDebugger": Json::boolean(true),
                }),
              ),
            )
          }
          self.send_result(
            request.id,
            request.session_id,
            Some(make_object({ "targetId": Json::string(target_id) })),
          )
        }
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    }
    "closeTarget" => {
      let target_id = get_param_string(request.params, "targetId")
      match target_id {
        Some(tid) =>
          match self.target.close_target(tid) {
            Ok(_) => {
              // Get session ID before closing
              let session_id = match self.target.get_active_context() {
                Some(ctx) =>
                  match ctx.get_session_id() {
                    Some(sid) => sid
                    None => "SID-1"
                  }
                None => "SID-1"
              }
              self.send_result(
                request.id,
                request.session_id,
                Some(make_object({ "success": Json::boolean(true) })),
              )
              // Send detachedFromTarget event (for flatten mode)
              self.send_event(
                "Target.detachedFromTarget",
                None,
                Some(
                  make_object({
                    "sessionId": Json::string(session_id),
                    "targetId": Json::string(tid),
                  }),
                ),
              )
              // Send targetDestroyed event
              self.send_event(
                "Target.targetDestroyed",
                None,
                Some(make_object({ "targetId": Json::string(tid) })),
              )
            }
            Err(e) =>
              self.send_error(request.id, request.session_id, -32000, e.message)
          }
        None =>
          self.send_error(
            request.id,
            request.session_id,
            -32602,
            "Missing targetId",
          )
      }
    }
    "attachToTarget" => {
      let target_id = get_param_string(request.params, "targetId")
      match target_id {
        Some(tid) =>
          match self.target.attach_to_target(tid) {
            Ok(session_id) => {
              // Send attachedToTarget event
              self.send_event(
                "Target.attachedToTarget",
                None,
                Some(
                  make_object({
                    "sessionId": Json::string(session_id),
                    "targetInfo": target_info_to_json({
                      target_id: tid,
                      target_type: "page",
                      title: "about:blank",
                      url: "about:blank",
                      attached: true,
                      browser_context_id: None,
                    }),
                    "waitingForDebugger": Json::boolean(false),
                  }),
                ),
              )
              self.send_result(
                request.id,
                request.session_id,
                Some(make_object({ "sessionId": Json::string(session_id) })),
              )
            }
            Err(e) =>
              self.send_error(request.id, request.session_id, -32000, e.message)
          }
        None =>
          self.send_error(
            request.id,
            request.session_id,
            -32602,
            "Missing targetId",
          )
      }
    }
    "detachFromTarget" => {
      let session_id = get_param_string(request.params, "sessionId")
      let target_id = get_param_string(request.params, "targetId")
      match self.target.detach_from_target(session_id, target_id) {
        Ok(_) => self.send_result(request.id, request.session_id, None)
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    }
    "getTargets" => {
      let targets = self.target.get_targets()
      let json_targets = targets.map(fn(t) { target_info_to_json(t) })
      self.send_result(
        request.id,
        request.session_id,
        Some(make_object({ "targetInfos": Json::array(json_targets) })),
      )
    }
    "getTargetInfo" => {
      let target_id = get_param_string(request.params, "targetId")
      match self.target.get_target_info(target_id) {
        Ok(info) =>
          self.send_result(
            request.id,
            request.session_id,
            Some(make_object({ "targetInfo": target_info_to_json(info) })),
          )
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    }
    "setAutoAttach" => {
      let auto_attach = get_param_bool(request.params, "autoAttach").unwrap_or(
        false,
      )
      let wait_for_debugger = get_param_bool(
        request.params,
        "waitForDebuggerOnStart",
      ).unwrap_or(false)
      self.target.set_auto_attach(auto_attach, wait_for_debugger)
      self.send_result(request.id, request.session_id, None)
    }
    "setDiscoverTargets" => {
      let discover = get_param_bool(request.params, "discover").unwrap_or(false)
      self.target.set_discover_targets(discover)
      self.send_result(request.id, request.session_id, None)
    }
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Target method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_dom(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  // Get active context session
  let ctx = match self.target.get_active_context() {
    Some(c) => c
    None => {
      self.send_error(
        request.id,
        request.session_id,
        -32000,
        "No browser context",
      )
      return Ok(())
    }
  }
  let dom = ctx.get_session().get_dom()
  match action {
    "getDocument" => {
      let depth = get_param_int(request.params, "depth")
      match dom.get_document(depth) {
        Ok(doc) =>
          self.send_result(
            request.id,
            request.session_id,
            Some(make_object({ "root": cdp_node_to_json(doc) })),
          )
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    }
    "querySelector" => {
      let node_id = get_param_int(request.params, "nodeId").unwrap_or(0)
      let selector = get_param_string(request.params, "selector").unwrap_or("")
      match dom.query_selector(node_id, selector) {
        Ok(result) => {
          let result_json = match result {
            Some(id) => Json::number(id.to_double())
            None => Json::number(0.0)
          }
          self.send_result(
            request.id,
            request.session_id,
            Some(make_object({ "nodeId": result_json })),
          )
        }
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    }
    "querySelectorAll" => {
      let node_id = get_param_int(request.params, "nodeId").unwrap_or(0)
      let selector = get_param_string(request.params, "selector").unwrap_or("")
      match dom.query_selector_all(node_id, selector) {
        Ok(ids) => {
          let json_ids = ids.map(fn(id) { Json::number(id.to_double()) })
          self.send_result(
            request.id,
            request.session_id,
            Some(make_object({ "nodeIds": Json::array(json_ids) })),
          )
        }
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    }
    "enable" | "disable" =>
      self.send_result(request.id, request.session_id, None)
    "describeNode" =>
      // Return a fake node description for objectId-based queries
      self.send_result(
        request.id,
        request.session_id,
        Some(
          make_object({
            "node": make_object({
              "nodeId": Json::number(1.0),
              "backendNodeId": Json::number(1.0),
              "nodeType": Json::number(9.0), // DOCUMENT_NODE
              "nodeName": Json::string("#document"),
              "localName": Json::string(""),
              "nodeValue": Json::string(""),
              "childNodeCount": Json::number(1.0),
              "frameId": Json::string(ctx.get_session().get_target_id()),
            }),
          }),
        ),
      )
    "resolveNode" =>
      // Return a remote object reference for a node
      self.send_result(
        request.id,
        request.session_id,
        Some(
          make_object({
            "object": make_object({
              "type": Json::string("object"),
              "subtype": Json::string("node"),
              "className": Json::string("HTMLDocument"),
              "description": Json::string("#document"),
              "objectId": Json::string("{\"injectedScriptId\":1,\"id\":1}"),
            }),
          }),
        ),
      )
    "requestNode" =>
      // Return a node ID for a remote object
      self.send_result(
        request.id,
        request.session_id,
        Some(make_object({ "nodeId": Json::number(1.0) })),
      )
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown DOM method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_page(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  let ctx = match self.target.get_active_context() {
    Some(c) => c
    None => {
      self.send_error(
        request.id,
        request.session_id,
        -32000,
        "No browser context",
      )
      return Ok(())
    }
  }
  match action {
    "navigate" => {
      let url = get_param_string(request.params, "url").unwrap_or("about:blank")
      match ctx.navigate(url) {
        Ok(result) =>
          self.send_result(
            request.id,
            request.session_id,
            Some(
              make_object({
                "frameId": Json::string(result.frame_id),
                "loaderId": Json::string(result.loader_id),
              }),
            ),
          )
        Err(e) =>
          self.send_error(request.id, request.session_id, -32000, e.message)
      }
    }
    "getFrameTree" => {
      let target_id = ctx.get_target_id().unwrap_or("frame-0")
      self.send_result(
        request.id,
        request.session_id,
        Some(
          make_object({
            "frameTree": make_object({
              "frame": make_object({
                "id": Json::string(target_id),
                "loaderId": Json::string("loader-0"),
                "url": Json::string(ctx.get_url()),
                "securityOrigin": Json::string("://"),
                "mimeType": Json::string("text/html"),
              }),
            }),
          }),
        ),
      )
    }
    "setLifecycleEventsEnabled" => {
      self.lifecycle_events = get_param_bool(request.params, "enabled").unwrap_or(
        false,
      )
      self.send_result(request.id, request.session_id, None)
      // Send lifecycle events immediately for "blank" pages
      if self.lifecycle_events {
        let frame_id = ctx.get_target_id().unwrap_or("frame-0")
        let loader_id = "loader-1"
        // Send commit, DOMContentLoaded, load events
        self.send_event(
          "Page.lifecycleEvent",
          request.session_id,
          Some(
            make_object({
              "frameId": Json::string(frame_id),
              "loaderId": Json::string(loader_id),
              "name": Json::string("commit"),
              "timestamp": Json::number(0.0),
            }),
          ),
        )
        self.send_event(
          "Page.lifecycleEvent",
          request.session_id,
          Some(
            make_object({
              "frameId": Json::string(frame_id),
              "loaderId": Json::string(loader_id),
              "name": Json::string("DOMContentLoaded"),
              "timestamp": Json::number(0.0),
            }),
          ),
        )
        self.send_event(
          "Page.lifecycleEvent",
          request.session_id,
          Some(
            make_object({
              "frameId": Json::string(frame_id),
              "loaderId": Json::string(loader_id),
              "name": Json::string("load"),
              "timestamp": Json::number(0.0),
            }),
          ),
        )
      }
    }
    "enable" | "disable" | "bringToFront" | "stopLoading" =>
      self.send_result(request.id, request.session_id, None)
    "addScriptToEvaluateOnNewDocument" =>
      // Return a fake identifier - we don't actually execute scripts
      self.send_result(
        request.id,
        request.session_id,
        Some(make_object({ "identifier": Json::string("script-1") })),
      )
    "removeScriptToEvaluateOnNewDocument" =>
      self.send_result(request.id, request.session_id, None)
    "createIsolatedWorld" =>
      // Return an execution context ID
      self.send_result(
        request.id,
        request.session_id,
        Some(make_object({ "executionContextId": Json::number(1.0) })),
      )
    "setBypassCSP" | "setInterceptFileChooserDialog" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Page method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_input(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "dispatchMouseEvent" | "dispatchKeyEvent" | "insertText" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Input method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_runtime(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "enable" => {
      self.send_result(request.id, request.session_id, None)
      // Send executionContextCreated event for the main frame
      let target_id = match self.target.get_active_context() {
        Some(ctx) =>
          match ctx.get_target_id() {
            Some(tid) => tid
            None => "TID-1"
          }
        None => "TID-1"
      }
      self.send_event(
        "Runtime.executionContextCreated",
        request.session_id,
        Some(
          make_object({
            "context": make_object({
              "id": Json::number(1.0),
              "origin": Json::string("://"),
              "name": Json::string(""),
              "uniqueId": Json::string("-1"),
              "auxData": make_object({
                "isDefault": Json::boolean(true),
                "type": Json::string("default"),
                "frameId": Json::string(target_id),
              }),
            }),
          }),
        ),
      )
      // Also send isolated world context
      self.send_event(
        "Runtime.executionContextCreated",
        request.session_id,
        Some(
          make_object({
            "context": make_object({
              "id": Json::number(2.0),
              "origin": Json::string("://"),
              "name": Json::string("__puppeteer_utility_world__24.34.0"),
              "uniqueId": Json::string("-2"),
              "auxData": make_object({
                "isDefault": Json::boolean(false),
                "type": Json::string("isolated"),
                "frameId": Json::string(target_id),
              }),
            }),
          }),
        ),
      )
    }
    "disable" | "runIfWaitingForDebugger" =>
      self.send_result(request.id, request.session_id, None)
    "evaluate" => {
      // Get expression from params
      let expression = get_param_string(request.params, "expression").unwrap_or(
        "",
      )
      // Handle common expressions
      let result = if expression.contains("document.title") {
        // Return page title
        let title = match self.target.get_active_context() {
          Some(ctx) => ctx.get_title()
          None => ""
        }
        make_object({
          "result": make_object({
            "type": Json::string("string"),
            "value": Json::string(title),
          }),
        })
      } else if expression.contains("document.body") ||
        expression.contains("document.documentElement") {
        // Return a fake element reference
        make_object({
          "result": make_object({
            "type": Json::string("object"),
            "subtype": Json::string("node"),
            "className": Json::string("HTMLBodyElement"),
            "description": Json::string("body"),
            "objectId": Json::string("{\"injectedScriptId\":1,\"id\":1}"),
          }),
        })
      } else {
        // Return undefined for unknown expressions
        make_object({
          "result": make_object({ "type": Json::string("undefined") }),
        })
      }
      self.send_result(request.id, request.session_id, Some(result))
    }
    "callFunctionOn" => {
      // Parse functionDeclaration to handle common patterns
      let func_decl = get_param_string(request.params, "functionDeclaration").unwrap_or(
        "",
      )
      let result = if func_decl.contains("cssQuerySelector") &&
        not(func_decl.contains("cssQuerySelectorAll")) {
        // Handle puppeteer's querySelector: cssQuerySelector(element, selector)
        // Extract selector from arguments
        let selector = match request.params {
          Some(Object(map)) =>
            match map.get("arguments") {
              Some(Array(args)) if args.length() >= 2 =>
                // Second argument is the selector (first is the element)
                match args[1] {
                  Object(arg_map) =>
                    match arg_map.get("value") {
                      Some(String(s)) => s
                      _ => ""
                    }
                  _ => ""
                }
              _ => ""
            }
          _ => ""
        }
        if selector.length() > 0 {
          match self.target.get_active_context() {
            Some(ctx) => {
              let session = ctx.get_session()
              match session.query_selector(selector) {
                Ok(Some(node_id)) =>
                  // Return node reference
                  make_object({
                    "result": make_object({
                      "type": Json::string("object"),
                      "subtype": Json::string("node"),
                      "className": Json::string("HTMLElement"),
                      "description": Json::string(selector),
                      "objectId": Json::string(
                        "{\"injectedScriptId\":1,\"id\":" +
                        node_id.to_string() +
                        "}",
                      ),
                    }),
                  })
                Ok(None) | Err(_) =>
                  // Element not found - return null
                  make_object({
                    "result": make_object({
                      "type": Json::string("object"),
                      "subtype": Json::string("null"),
                      "value": Json::null(),
                    }),
                  })
              }
            }
            None =>
              make_object({
                "result": make_object({
                  "type": Json::string("object"),
                  "subtype": Json::string("null"),
                  "value": Json::null(),
                }),
              })
          }
        } else {
          make_object({
            "result": make_object({
              "type": Json::string("object"),
              "subtype": Json::string("null"),
              "value": Json::null(),
            }),
          })
        }
      } else if func_decl.contains("textContent") ||
        func_decl.contains("innerText") {
        // Handle getting element text content
        // Check for document.querySelector pattern: document.querySelector('h1')?.textContent
        let selector_from_func = extract_selector_from_function(func_decl)
        if selector_from_func.length() > 0 {
          // Direct querySelector in function - use extracted selector
          match self.target.get_active_context() {
            Some(ctx) => {
              let session = ctx.get_session()
              match session.query_selector(selector_from_func) {
                Ok(Some(node_id)) =>
                  match session.get_dom().get_outer_html(node_id) {
                    Ok(html) => {
                      let text = extract_text_from_html(html)
                      make_object({
                        "result": make_object({
                          "type": Json::string("string"),
                          "value": Json::string(text),
                        }),
                      })
                    }
                    Err(_) =>
                      make_object({
                        "result": make_object({
                          "type": Json::string("string"),
                          "value": Json::string(""),
                        }),
                      })
                  }
                Ok(None) | Err(_) =>
                  make_object({
                    "result": make_object({
                      "type": Json::string("object"),
                      "subtype": Json::string("null"),
                      "value": Json::null(),
                    }),
                  })
              }
            }
            None =>
              make_object({
                "result": make_object({
                  "type": Json::string("string"),
                  "value": Json::string(""),
                }),
              })
          }
        } else {
          // Element passed as argument - extract objectId
          let object_id = match request.params {
            Some(Object(map)) =>
              match map.get("arguments") {
                Some(Array(args)) if args.length() > 0 =>
                  match args[0] {
                    Object(arg_map) =>
                      match arg_map.get("objectId") {
                        Some(String(s)) => s
                        _ => ""
                      }
                    _ => ""
                  }
                _ => ""
              }
            _ => ""
          }
          let object_id = if object_id.length() > 0 {
            object_id
          } else {
            get_param_string(request.params, "objectId").unwrap_or("")
          }
          let node_id = parse_node_id_from_object_id(object_id)
          if node_id > 0 {
            match self.target.get_active_context() {
              Some(ctx) => {
                let session = ctx.get_session()
                match session.get_dom().get_outer_html(node_id) {
                  Ok(html) => {
                    let text = extract_text_from_html(html)
                    make_object({
                      "result": make_object({
                        "type": Json::string("string"),
                        "value": Json::string(text),
                      }),
                    })
                  }
                  Err(_) =>
                    make_object({
                      "result": make_object({
                        "type": Json::string("string"),
                        "value": Json::string(""),
                      }),
                    })
                }
              }
              None =>
                make_object({
                  "result": make_object({
                    "type": Json::string("string"),
                    "value": Json::string(""),
                  }),
                })
            }
          } else {
            make_object({
              "result": make_object({
                "type": Json::string("string"),
                "value": Json::string(""),
              }),
            })
          }
        }
      } else if func_decl.contains("document.title") &&
        not(func_decl.contains("document.write")) {
        // Return page title for title queries
        let title = match self.target.get_active_context() {
          Some(ctx) => ctx.get_title()
          None => ""
        }
        make_object({
          "result": make_object({
            "type": Json::string("string"),
            "value": Json::string(title),
          }),
        })
      } else if func_decl.contains("document.write") ||
        func_decl.contains("document.open") {
        // Handle setContent - extract HTML from arguments
        match request.params {
          Some(Object(map)) =>
            match map.get("arguments") {
              Some(Array(args)) =>
                for arg in args {
                  match get_string_field(arg, "value") {
                    Some(html) =>
                      match self.target.get_active_context() {
                        Some(ctx) => {
                          ctx.get_session().load_html(html)
                          // Also extract title from HTML if present
                          match (html.find("<title>"), html.find("</title>")) {
                            (Some(start), Some(end_)) if end_ > start => {
                              let title = html[start + 7:end_].to_string() catch {
                                _ => ""
                              }
                              ctx.set_title(title)
                            }
                            _ => ()
                          }
                        }
                        None => ()
                      }
                    None => ()
                  }
                }
              _ => ()
            }
          _ => ()
        }
        make_object({
          "result": make_object({ "type": Json::string("undefined") }),
        })
      } else if func_decl.contains("return") {
        // Try to extract simple return values like return"Hello from evaluate"
        match func_decl.find("return") {
          Some(ret_idx) => {
            let after_return = func_decl[ret_idx + 6:].to_string() catch {
              _ => ""
            }
            // Check for quoted string
            let has_dq = after_return.contains("\"")
            let has_sq = after_return.contains("'")
            if has_dq || has_sq {
              let quote = if has_dq { "\"" } else { "'" }
              match after_return.find(quote) {
                Some(q1) => {
                  let after_q1 = after_return[q1 + 1:].to_string() catch {
                    _ => ""
                  }
                  match after_q1.find(quote) {
                    Some(q2) => {
                      let value = after_q1[:q2].to_string() catch { _ => "" }
                      make_object({
                        "result": make_object({
                          "type": Json::string("string"),
                          "value": Json::string(value),
                        }),
                      })
                    }
                    None =>
                      make_object({
                        "result": make_object({
                          "type": Json::string("undefined"),
                        }),
                      })
                  }
                }
                None =>
                  if func_decl.contains("document") {
                    // Return a node reference for document-related calls
                    make_object({
                      "result": make_object({
                        "type": Json::string("object"),
                        "subtype": Json::string("node"),
                        "className": Json::string("HTMLDocument"),
                        "description": Json::string("#document"),
                        "objectId": Json::string(
                          "{\"injectedScriptId\":1,\"id\":1}",
                        ),
                      }),
                    })
                  } else {
                    make_object({
                      "result": make_object({
                        "type": Json::string("undefined"),
                      }),
                    })
                  }
              }
            } else if func_decl.contains("document") {
              // Return a node reference for document-related calls
              make_object({
                "result": make_object({
                  "type": Json::string("object"),
                  "subtype": Json::string("node"),
                  "className": Json::string("HTMLDocument"),
                  "description": Json::string("#document"),
                  "objectId": Json::string("{\"injectedScriptId\":1,\"id\":1}"),
                }),
              })
            } else {
              make_object({
                "result": make_object({ "type": Json::string("undefined") }),
              })
            }
          }
          None =>
            make_object({
              "result": make_object({ "type": Json::string("undefined") }),
            })
        }
      } else {
        make_object({
          "result": make_object({ "type": Json::string("undefined") }),
        })
      }
      self.send_result(request.id, request.session_id, Some(result))
    }
    "getProperties" | "releaseObject" | "releaseObjectGroup" =>
      self.send_result(
        request.id,
        request.session_id,
        Some(
          make_object({
            "result": Json::array([]),
            "internalProperties": Json::array([]),
            "privateProperties": Json::array([]),
          }),
        ),
      )
    "addBinding" | "discardConsoleEntries" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Runtime method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_browser(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "getVersion" =>
      self.send_result(
        request.id,
        request.session_id,
        Some(
          make_object({
            "protocolVersion": Json::string("1.3"),
            "product": Json::string("Crater/1.0"),
            "revision": Json::string("0"),
            "userAgent": Json::string("Crater"),
            "jsVersion": Json::string("0"),
          }),
        ),
      )
    "close" => self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Browser method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_network(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "enable" | "disable" | "setCacheDisabled" | "setExtraHTTPHeaders" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Network method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_emulation(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "setDeviceMetricsOverride"
    | "setTouchEmulationEnabled"
    | "setEmitTouchEventsForMouse" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Emulation method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_security(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "enable" | "disable" | "setIgnoreCertificateErrors" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Security method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_performance(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "enable" | "disable" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Performance method: " + action,
      )
  }
  Ok(())
}

///|
fn CdpProtocol::dispatch_log(
  self : CdpProtocol,
  request : CdpRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "enable" | "disable" | "clear" =>
      self.send_result(request.id, request.session_id, None)
    _ =>
      self.send_error(
        request.id,
        request.session_id,
        -32601,
        "Unknown Log method: " + action,
      )
  }
  Ok(())
}

// =============================================================================
// Response Helpers
// =============================================================================

///|
fn CdpProtocol::send_result(
  self : CdpProtocol,
  id : Int?,
  session_id : String?,
  result : Json?,
) -> Unit {
  self.outbox.push(Response({ id, result, error: None, session_id }))
}

///|
fn CdpProtocol::send_error(
  self : CdpProtocol,
  id : Int?,
  session_id : String?,
  code : Int,
  message : String,
) -> Unit {
  self.outbox.push(
    Response({ id, result: None, error: Some({ code, message }), session_id }),
  )
}

///|
fn CdpProtocol::send_event(
  self : CdpProtocol,
  event_method : String,
  session_id : String?,
  params : Json?,
) -> Unit {
  self.outbox.push(Event({ event_method, params, session_id }))
}

// =============================================================================
// JSON Helpers
// =============================================================================

///|
fn split_method(input : String) -> (String, String)? {
  let chars = input.to_array()
  for i, c in chars {
    if c == '.' {
      let domain = substring_arr(chars, 0, i)
      let action = substring_arr(chars, i + 1, chars.length())
      return Some((domain, action))
    }
  }
  None
}

///|
fn substring_arr(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
fn get_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn get_string_field(json : Json, key : String) -> String? {
  match get_field(json, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn get_int_field(json : Json, key : String) -> Int? {
  match get_field(json, key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
fn get_param_string(params : Json?, key : String) -> String? {
  match params {
    Some(p) => get_string_field(p, key)
    None => None
  }
}

///|
fn get_param_int(params : Json?, key : String) -> Int? {
  match params {
    Some(p) => get_int_field(p, key)
    None => None
  }
}

///|
fn get_param_bool(params : Json?, key : String) -> Bool? {
  match params {
    Some(Object(map)) =>
      match map.get(key) {
        Some(True) => Some(true)
        Some(False) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
fn make_object(map : Map[String, Json]) -> Json {
  Json::object(map)
}

///|
fn response_to_json(resp : CdpResponse) -> String {
  let obj : Map[String, Json] = {}
  match resp.id {
    Some(id) => obj["id"] = Json::number(id.to_double())
    None => ()
  }
  match resp.result {
    Some(r) => obj["result"] = r
    None =>
      match resp.error {
        Some(_) => ()
        None => obj["result"] = make_object({})
      }
  }
  match resp.error {
    Some(e) =>
      obj["error"] = make_object({
        "code": Json::number(e.code.to_double()),
        "message": Json::string(e.message),
      })
    None => ()
  }
  match resp.session_id {
    Some(sid) => obj["sessionId"] = Json::string(sid)
    None => ()
  }
  make_object(obj).stringify()
}

///|
fn event_to_json(evt : CdpEvent) -> String {
  let obj : Map[String, Json] = {}
  obj["method"] = Json::string(evt.event_method)
  match evt.params {
    Some(p) => obj["params"] = p
    None => obj["params"] = make_object({})
  }
  match evt.session_id {
    Some(sid) => obj["sessionId"] = Json::string(sid)
    None => ()
  }
  make_object(obj).stringify()
}

///|
fn target_info_to_json(info : TargetInfo) -> Json {
  let obj : Map[String, Json] = {}
  obj["targetId"] = Json::string(info.target_id)
  obj["type"] = Json::string(info.target_type)
  obj["title"] = Json::string(info.title)
  obj["url"] = Json::string(info.url)
  obj["attached"] = Json::boolean(info.attached)
  obj["canAccessOpener"] = Json::boolean(false)
  match info.browser_context_id {
    Some(id) => obj["browserContextId"] = Json::string(id)
    None => ()
  }
  make_object(obj)
}

///|
fn cdp_node_to_json(node : CdpNode) -> Json {
  let obj : Map[String, Json] = {}
  obj["nodeId"] = Json::number(node.node_id.to_double())
  obj["backendNodeId"] = Json::number(node.backend_node_id.to_double())
  obj["nodeType"] = Json::number(node.node_type.to_double())
  obj["nodeName"] = Json::string(node.node_name)
  obj["localName"] = Json::string(node.local_name)
  obj["nodeValue"] = Json::string(node.node_value)
  match node.child_node_count {
    Some(c) => obj["childNodeCount"] = Json::number(c.to_double())
    None => ()
  }
  match node.children {
    Some(children) => {
      let json_children = children.map(fn(c) { cdp_node_to_json(c) })
      obj["children"] = Json::array(json_children)
    }
    None => ()
  }
  match node.attributes {
    Some(attrs) => {
      let json_attrs = attrs.map(fn(a) { Json::string(a) })
      obj["attributes"] = Json::array(json_attrs)
    }
    None => ()
  }
  make_object(obj)
}

///|
/// Parse node ID from objectId string (format: {"injectedScriptId":1,"id":NODE_ID})
fn parse_node_id_from_object_id(object_id : String) -> Int {
  match object_id.find("\"id\":") {
    Some(idx) => {
      let after_id = object_id[idx + 5:].to_string() catch { _ => return 0 }
      // Find the end of the number
      let chars = after_id.to_array()
      let buf = StringBuilder::new()
      for i = 0; i < chars.length(); i = i + 1 {
        let c = chars[i]
        if c >= '0' && c <= '9' {
          buf.write_char(c)
        } else {
          break
        }
      }
      let num_str = buf.to_string()
      if num_str.length() > 0 {
        parse_int_simple(num_str)
      } else {
        0
      }
    }
    None => 0
  }
}

///|
/// Simple integer parsing
fn parse_int_simple(s : String) -> Int {
  let chars = s.to_array()
  let result = { val: 0 }
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      result.val = result.val * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result.val
}

///|
/// Extract text content from HTML (strips tags)
fn extract_text_from_html(html : String) -> String {
  let buf = StringBuilder::new()
  let chars = html.to_array()
  let in_tag = { val: false }
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c == '<' {
      in_tag.val = true
    } else if c == '>' {
      in_tag.val = false
    } else if not(in_tag.val) {
      buf.write_char(c)
    }
  }
  buf.to_string().trim().to_string()
}

///|
/// Extract CSS selector from document.querySelector patterns in function code
/// e.g., document.querySelector('h1')?.textContent -> "h1"
/// e.g., document.querySelector("div.class") -> "div.class"
fn extract_selector_from_function(func_decl : String) -> String {
  // Look for document.querySelector(' or document.querySelector("
  let single_quote_pattern = "document.querySelector('"
  let double_quote_pattern = "document.querySelector(\""
  match func_decl.find(single_quote_pattern) {
    Some(idx) => {
      let start = idx + single_quote_pattern.length()
      let rest = func_decl[start:].to_string() catch { _ => return "" }
      // Find closing quote
      match rest.find("'") {
        Some(end) => rest[:end].to_string() catch { _ => "" }
        None => ""
      }
    }
    None =>
      match func_decl.find(double_quote_pattern) {
        Some(idx) => {
          let start = idx + double_quote_pattern.length()
          let rest = func_decl[start:].to_string() catch { _ => return "" }
          match rest.find("\"") {
            Some(end) => rest[:end].to_string() catch { _ => "" }
            None => ""
          }
        }
        None => ""
      }
  }
}
