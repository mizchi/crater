///|
/// WebDriver BiDi WebSocket Server (Deno backend)
///
/// Uses Deno.serve with WebSocket upgrade for BiDi protocol.

///|
/// BiDi server configuration
pub(all) struct BidiServerConfig {
  host : String
  port : Int
  /// Optional auth token. If set, clients must connect to /session/<token>.
  /// If empty, authentication is disabled (legacy behavior).
  auth_token : String
}

///|
/// Default configuration (generates a random auth token)
pub fn BidiServerConfig::default() -> BidiServerConfig {
  { host: "127.0.0.1", port: 9222, auth_token: generate_auth_token() }
}

///|
pub fn BidiServerConfig::web_socket_url(self : BidiServerConfig) -> String {
  if self.auth_token.is_empty() {
    "ws://\{self.host}:\{self.port}"
  } else {
    "ws://\{self.host}:\{self.port}/session/\{self.auth_token}"
  }
}

///|
/// Generate a random auth token using crypto.randomUUID
extern "js" fn js_generate_auth_token() -> String =
  #| () => {
  #|   try {
  #|     return crypto.randomUUID().replace(/-/g, "");
  #|   } catch (_e) {
  #|     return Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
  #|   }
  #| }

///|
pub fn generate_auth_token() -> String {
  js_generate_auth_token()
}

///|
/// Extract URL pathname from a request
extern "js" fn js_get_request_pathname(request : @core.Any) -> String =
  #| (req) => {
  #|   try {
  #|     return new URL(req.url).pathname;
  #|   } catch (_e) {
  #|     return "/";
  #|   }
  #| }

///|
/// BiDi server state
pub struct BidiServer {
  config : BidiServerConfig
  priv protocol : BidiProtocol
  mut server : @core.Any?
}

///|
/// Create new BiDi server
pub fn BidiServer::new(
  config? : BidiServerConfig = BidiServerConfig::default(),
) -> BidiServer {
  { config, protocol: BidiProtocol::new(), server: None }
}

///|
/// Validate auth token from request path.
/// Expected path: /session/<token> when auth is enabled.
fn BidiServer::validate_auth(self : BidiServer, request : @core.Any) -> Bool {
  let token = self.config.auth_token
  if token.is_empty() {
    return true // Auth disabled
  }
  let path = js_get_request_pathname(request)
  path == "/session/" + token
}

///|
/// Deno.upgradeWebSocket FFI
extern "js" fn upgrade_websocket(request : @core.Any) -> @core.Any =
  #| (req) => Deno.upgradeWebSocket(req)

///|
/// Env flag helper for optional debug tracing.
extern "js" fn env_flag_enabled(name : String) -> Bool =
  #| (name) => {
  #|   try {
  #|     return typeof Deno !== "undefined" && Deno.env.get(name) === "1";
  #|   } catch (_e) {
  #|     return false;
  #|   }
  #| }

///|
/// Console log helper for optional server tracing.
extern "js" fn js_console_log(message : String) -> Unit =
  #| (message) => console.log(message)

///|
/// Convert JS value to string for debug logs.
extern "js" fn js_value_to_string(value : @core.Any) -> String =
  #| (value) => {
  #|   try {
  #|     if (value && typeof value === "object") {
  #|       const msg = value.message ?? value.reason ?? value.type;
  #|       if (msg !== undefined) return String(msg);
  #|     }
  #|     return String(value);
  #|   } catch (_e) {
  #|     return "[unprintable]";
  #|   }
  #| }

///|
/// Debug trace hook (disabled unless CRATER_BIDI_SERVER_TRACE=1).
fn bidi_server_trace(message : String) -> Unit {
  if env_flag_enabled("CRATER_BIDI_SERVER_TRACE") {
    js_console_log("[bidi-server] " + message)
  }
}

///|
/// Check if request is WebSocket upgrade
fn is_websocket_request(request : @core.Any) -> Bool {
  let headers : @core.Any = request._get("headers")
  let upgrade_any = headers._call("get", [@core.any("upgrade")])
  // Check if upgrade header exists (not null/undefined)
  if @core.is_nullish(upgrade_any) {
    return false
  }
  let upgrade : String = upgrade_any.cast()
  upgrade.to_lower() == "websocket"
}

///|
/// Handle WebSocket message, returns all response/event messages
fn BidiServer::handle_message(
  self : BidiServer,
  data : String,
) -> Array[String] {
  match self.protocol.process_message(data) {
    Ok(_) => {
      let messages = self.protocol.take_messages()
      let result : Array[String] = []
      for msg in messages {
        result.push(msg.to_json())
      }
      result
    }
    Err(e) =>
      [
        "{\"type\":\"error\",\"error\":\"unknown error\",\"message\":\"" +
        e +
        "\"}",
      ]
  }
}

///|
/// Setup WebSocket event handlers with async support
fn BidiServer::setup_websocket(self : BidiServer, socket : @core.Any) -> Unit {
  reset_runtime_js_state()
  reset_paint_provider()
  bidi_server_trace("setup_websocket: begin reset")
  self.protocol.reset_session_runtime_state()
  bidi_server_trace("setup_websocket: reset done")
  // Store socket reference for async responses
  let socket_epoch = self.protocol.set_socket(socket)
  bidi_server_trace("setup_websocket: socket epoch=" + socket_epoch.to_string())

  // onopen
  socket["onopen"] = @core.any(
    @core.from_fn1(fn(_event : @core.Any) {
      // Connection opened, could log or initialize
      bidi_server_trace("ws onopen")
    }),
  )

  // onmessage - process BiDi messages (supports async via socket)
  socket["onmessage"] = @core.any(
    @core.from_fn1(fn(event : @core.Any) {
      bidi_server_trace("ws onmessage: received")
      let raw_data = event._get("data")
      if @core.is_nullish(raw_data) {
        bidi_server_trace("ws onmessage: nullish data")
        return
      }
      let data : String = raw_data.cast()
      // handle_message returns sync responses; async responses sent via socket
      let messages = self.handle_message(data)
      bidi_server_trace(
        "ws onmessage: responses=" + messages.length().to_string(),
      )
      for msg in messages {
        socket._call("send", [@core.any(msg)]) |> ignore
      }
    }),
  )

  // onerror
  socket["onerror"] = @core.any(
    @core.from_fn1(fn(event : @core.Any) {
      // Error handling
      bidi_server_trace("ws onerror: " + js_value_to_string(event))
    }),
  )

  // onclose
  socket["onclose"] = @core.any(
    @core.from_fn1(fn(_event : @core.Any) {
      // Connection closed
      bidi_server_trace("ws onclose: epoch=" + socket_epoch.to_string())
      if self.protocol.is_current_socket_epoch(socket_epoch) {
        bidi_server_trace("ws onclose: reset current epoch")
        self.protocol.reset_session_runtime_state()
        self.protocol.clear_socket()
        bidi_server_trace("ws onclose: reset done")
      }
    }),
  )
}

///|
/// Create HTTP response for non-WebSocket requests
extern "js" fn create_response(body : String, status : Int) -> @core.Any =
  #| (body, status) => new Response(body, { status, headers: { "Content-Type": "application/json" } })

///|
fn bidi_status_response_body(config : BidiServerConfig) -> String {
  let auth_enabled = if config.auth_token.is_empty() { "false" } else { "true" }
  let web_socket_url = escape_json_string(config.web_socket_url())
  "{\"ready\":true,\"message\":\"Crater WebDriver BiDi Server\",\"webSocketUrl\":\"" +
  web_socket_url +
  "\",\"authEnabled\":" +
  auth_enabled +
  "}"
}

///|
/// Start the BiDi server using Deno.serve
pub fn BidiServer::start(self : BidiServer) -> Unit {
  let d = @deno.deno()

  // Create request handler
  let handler = @core.from_fn1(fn(request : @core.Any) -> @core.Any {
    if is_websocket_request(request) {
      // Security: validate auth token before upgrading
      if !self.validate_auth(request) {
        let body = "{\"error\":\"unauthorized\",\"message\":\"Invalid or missing auth token\"}"
        return create_response(body, 403)
      }
      // Upgrade to WebSocket
      let upgrade_result = upgrade_websocket(request)
      let socket : @core.Any = upgrade_result._get("socket")
      let response : @core.Any = upgrade_result._get("response")
      self.setup_websocket(socket)
      response
    } else {
      // Return status response for HTTP requests
      let body = bidi_status_response_body(self.config)
      create_response(body, 200)
    }
  })

  // Start server with Deno.serve
  let opts : @core.Any = @core.from_entries([
    ("port", @core.any(self.config.port)),
    ("hostname", @core.any(self.config.host)),
  ]).cast()

  // Call Deno.serve with options and handler
  self.server = Some(d.as_any()._call("serve", [opts, @core.any(handler)]))
}

///|
/// Stop the server
pub fn BidiServer::stop(self : BidiServer) -> Unit {
  match self.server {
    Some(srv) => {
      srv._call("shutdown", []) |> ignore
      self.server = None
    }
    None => ()
  }
}
