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
  /// Network manager
  network : @scheduler.NetworkManager
  /// Outgoing message buffer
  outbox : Array[CdpOutMessage]
  /// Enable lifecycle events
  mut lifecycle_events : Bool
}

///|
/// Create new protocol handler
pub fn CdpProtocol::new() -> CdpProtocol {
  {
    target: TargetDomain::new(),
    network: @scheduler.NetworkManager::new(),
    outbox: [],
    lifecycle_events: false,
  }
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
      // Only handle document.title for page.title() support
      let result = if expression.contains("document.title") {
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
      } else {
        // JS execution not implemented - return undefined
        make_object({
          "result": make_object({ "type": Json::string("undefined") }),
        })
      }
      self.send_result(request.id, request.session_id, Some(result))
    }
    "callFunctionOn" => {
      // Only handle patterns required by puppeteer internals:
      // - cssQuerySelector for page.$()
      // - document.write for page.setContent()
      let func_decl = get_param_string(request.params, "functionDeclaration").unwrap_or(
        "",
      )
      let result = if func_decl.contains("cssQuerySelector") &&
        not(func_decl.contains("cssQuerySelectorAll")) {
        // Handle puppeteer's querySelector: cssQuerySelector(element, selector)
        let selector = match request.params {
          Some(Object(map)) =>
            match map.get("arguments") {
              Some(Array(args)) if args.length() >= 2 =>
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
      } else {
        // JS execution not implemented - return undefined
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
    "enable" => {
      self.network.enable()
      self.send_result(request.id, request.session_id, None)
    }
    "disable" => {
      self.network.disable()
      self.send_result(request.id, request.session_id, None)
    }
    "setCacheDisabled" | "setExtraHTTPHeaders" | "setUserAgentOverride" =>
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

// =============================================================================
// Network API (外部から呼び出される)
// =============================================================================

///|
/// Create a new network request (returns request ID for tracking)
pub fn CdpProtocol::create_network_request(
  self : CdpProtocol,
  url : String,
  resource_type : @scheduler.ResourceType,
  document_url : String,
  frame_id : String,
) -> @scheduler.RequestId {
  let request = @scheduler.NetworkRequest::new(
    url,
    resource_type,
    document_url~,
    frame_id~,
  )
  let request_id = request.id
  self.network.start_request(request)
  request_id
}

///|
/// Create a new network request with explicit loader ID
pub fn CdpProtocol::create_network_request_with_loader(
  self : CdpProtocol,
  url : String,
  resource_type : @scheduler.ResourceType,
  document_url : String,
  frame_id : String,
  loader_id : String,
) -> @scheduler.RequestId {
  let request = @scheduler.NetworkRequest::new(
    url,
    resource_type,
    document_url~,
    frame_id~,
  ).with_loader_id(loader_id)
  let request_id = request.id
  self.network.start_request(request)
  request_id
}

///|
/// Notify response received
pub fn CdpProtocol::notify_response_received(
  self : CdpProtocol,
  request_id : @scheduler.RequestId,
  url : String,
  status : Int,
  mime_type : String,
  headers : Map[String, String],
) -> Unit {
  let response = @scheduler.NetworkResponse::new(request_id, url, status)
    .with_mime_type(mime_type)
    .with_headers(headers)
  self.network.receive_response(response)
}

///|
/// Notify response received with explicit loader ID
pub fn CdpProtocol::notify_response_received_with_loader(
  self : CdpProtocol,
  request_id : @scheduler.RequestId,
  url : String,
  status : Int,
  mime_type : String,
  headers : Map[String, String],
  loader_id : String,
) -> Unit {
  let response = @scheduler.NetworkResponse::new(request_id, url, status)
    .with_mime_type(mime_type)
    .with_headers(headers)
    .with_loader_id(loader_id)
  self.network.receive_response(response)
}

///|
/// Notify loading finished
pub fn CdpProtocol::notify_loading_finished(
  self : CdpProtocol,
  request_id : @scheduler.RequestId,
  encoded_data_length : Int,
) -> Unit {
  self.network.finish_loading(request_id, encoded_data_length)
}

///|
/// Notify loading failed
pub fn CdpProtocol::notify_loading_failed(
  self : CdpProtocol,
  request_id : @scheduler.RequestId,
  error : String,
) -> Unit {
  self.network.fail_loading(request_id, error)
}

///|
/// Process pending network events and add them to outbox
pub fn CdpProtocol::flush_network_events(
  self : CdpProtocol,
  session_id : String?,
) -> Unit {
  let events = self.network.drain_events()
  for event in events {
    let (event_method, params) = network_event_to_cdp(event)
    self.send_event(event_method, session_id, Some(params))
  }
}

///|
/// Check if there are pending network events
pub fn CdpProtocol::has_pending_network_events(self : CdpProtocol) -> Bool {
  self.network.has_pending_events()
}

///|
/// Get network manager for direct access
pub fn CdpProtocol::get_network_manager(
  self : CdpProtocol,
) -> @scheduler.NetworkManager {
  self.network
}

// =============================================================================
// Network Event to CDP JSON
// =============================================================================

///|
fn network_event_to_cdp(event : @scheduler.NetworkEvent) -> (String, Json) {
  match event {
    @scheduler.RequestWillBeSent(req) => (
      "Network.requestWillBeSent",
      request_will_be_sent_to_json(req),
    )
    @scheduler.ResponseReceived(res) => (
      "Network.responseReceived",
      response_received_to_json(res),
    )
    @scheduler.LoadingFinished(request_id~, encoded_data_length~) => (
      "Network.loadingFinished",
      loading_finished_to_json(request_id, encoded_data_length),
    )
    @scheduler.LoadingFailed(request_id~, error~) => (
      "Network.loadingFailed",
      loading_failed_to_json(request_id, error),
    )
  }
}

///|
fn request_will_be_sent_to_json(req : @scheduler.NetworkRequest) -> Json {
  let @scheduler.RequestId(id) = req.id
  let request_id = "REQ-\{id}"
  make_object({
    "requestId": Json::string(request_id),
    "loaderId": Json::string(req.loader_id),
    "documentURL": Json::string(req.document_url),
    "request": make_object({
      "url": Json::string(req.url),
      "method": Json::string(req.http_method.to_string()),
      "headers": headers_to_json(req.headers),
    }),
    "timestamp": Json::number(req.timestamp),
    "wallTime": Json::number(req.timestamp),
    "initiator": make_object({ "type": Json::string("other") }),
    "type": Json::string(resource_type_to_string(req.resource_type)),
    "frameId": Json::string(req.frame_id),
  })
}

///|
fn response_received_to_json(res : @scheduler.NetworkResponse) -> Json {
  let @scheduler.RequestId(id) = res.request_id
  let request_id = "REQ-\{id}"
  make_object({
    "requestId": Json::string(request_id),
    "loaderId": Json::string(res.loader_id),
    "timestamp": Json::number(res.timestamp),
    "type": Json::string("Document"),
    "response": make_object({
      "url": Json::string(res.url),
      "status": Json::number(res.status.to_double()),
      "statusText": Json::string(res.status_text),
      "headers": headers_to_json(res.headers),
      "mimeType": Json::string(res.mime_type),
    }),
  })
}

///|
fn loading_finished_to_json(
  request_id : @scheduler.RequestId,
  encoded_data_length : Int,
) -> Json {
  let @scheduler.RequestId(id) = request_id
  make_object({
    "requestId": Json::string("REQ-\{id}"),
    "timestamp": Json::number(0.0),
    "encodedDataLength": Json::number(encoded_data_length.to_double()),
  })
}

///|
fn loading_failed_to_json(
  request_id : @scheduler.RequestId,
  error : String,
) -> Json {
  let @scheduler.RequestId(id) = request_id
  make_object({
    "requestId": Json::string("REQ-\{id}"),
    "timestamp": Json::number(0.0),
    "type": Json::string("Document"),
    "errorText": Json::string(error),
    "canceled": Json::boolean(false),
  })
}

///|
fn headers_to_json(headers : Map[String, String]) -> Json {
  let obj : Map[String, Json] = {}
  headers.each(fn(k, v) { obj[k] = Json::string(v) })
  make_object(obj)
}

///|
fn resource_type_to_string(rt : @scheduler.ResourceType) -> String {
  match rt {
    @scheduler.Document => "Document"
    @scheduler.Stylesheet => "Stylesheet"
    @scheduler.Script => "Script"
    @scheduler.Image => "Image"
    @scheduler.Font => "Font"
    @scheduler.Other => "Other"
  }
}
