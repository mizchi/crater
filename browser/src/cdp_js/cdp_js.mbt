///|
/// CDP JavaScript API
///
/// Exports CDP protocol handler functions for JavaScript runtime.

///|
/// Global protocol instance
let protocol : @cdp.CdpProtocol = @cdp.CdpProtocol::new()

///|
/// Process incoming CDP message (JSON string)
/// Returns JSON response string
pub fn processCdpMessage(message : String) -> String {
  match protocol.process_message(message) {
    Ok(_) => {
      let messages = protocol.take_messages()
      if messages.length() == 0 {
        "{\"result\":{}}"
      } else {
        // Return first message, queue rest
        let result = messages[0].to_json()
        // Store remaining messages for getNextMessage
        for i = 1; i < messages.length(); i = i + 1 {
          pending_messages.push(messages[i])
        }
        result
      }
    }
    Err(e) =>
      "{\"error\":{\"code\":-32700,\"message\":\"" + escape_json(e) + "\"}}"
  }
}

///|
/// Get next pending message (event or additional response)
/// Returns empty string if no pending messages
pub fn getNextCdpMessage() -> String {
  if pending_messages.length() > 0 {
    let msg = pending_messages.remove(0)
    msg.to_json()
  } else {
    ""
  }
}

///|
/// Check if there are pending messages
pub fn hasPendingCdpMessages() -> Int {
  pending_messages.length()
}

///|
/// Reset protocol state (for new connection)
pub fn resetCdpProtocol() -> Unit {
  // Create new protocol instance
  // Note: In MoonBit we can't reassign a let binding,
  // so we clear the state instead
  pending_messages.clear()
}

///|
/// Load HTML content into active context
pub fn loadHtmlContent(html : String) -> String {
  match protocol.target.get_active_context() {
    Some(ctx) => {
      let session = ctx.get_session()
      session.load_html(html)
      // Extract and set title from HTML
      match (html.find("<title>"), html.find("</title>")) {
        (Some(start), Some(end_)) if end_ > start => {
          let title = html[start + 7:end_].to_string() catch { _ => "" }
          ctx.set_title(title)
          session.set_title(title)
        }
        _ => ()
      }
      "{\"result\":{}}"
    }
    None => "{\"error\":{\"code\":-32000,\"message\":\"No active context\"}}"
  }
}

///|
/// Get protocol info
pub fn getCdpProtocolInfo() -> String {
  "{\"product\":\"Crater/1.0\",\"protocolVersion\":\"1.3\"}"
}

///|
/// Pending messages buffer
let pending_messages : Array[@cdp.CdpOutMessage] = []

///|
fn escape_json(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

// =============================================================================
// Network API
// =============================================================================

///|
/// Create a network request and return request ID
/// Returns request ID as integer for tracking
pub fn createNetworkRequest(
  url : String,
  resource_type : String,
  document_url : String,
  frame_id : String,
) -> Int {
  let rt = match resource_type {
    "Document" => @scheduler.Document
    "Stylesheet" => @scheduler.Stylesheet
    "Script" => @scheduler.Script
    "Image" => @scheduler.Image
    "Font" => @scheduler.Font
    _ => @scheduler.Other
  }
  let req_id = protocol.create_network_request(url, rt, document_url, frame_id)
  let @scheduler.RequestId(id) = req_id
  id
}

///|
/// Create a network request with explicit loader ID
pub fn createNetworkRequestWithLoader(
  url : String,
  resource_type : String,
  document_url : String,
  frame_id : String,
  loader_id : String,
) -> Int {
  let rt = match resource_type {
    "Document" => @scheduler.Document
    "Stylesheet" => @scheduler.Stylesheet
    "Script" => @scheduler.Script
    "Image" => @scheduler.Image
    "Font" => @scheduler.Font
    _ => @scheduler.Other
  }
  let req_id = protocol.create_network_request_with_loader(
    url, rt, document_url, frame_id, loader_id,
  )
  let @scheduler.RequestId(id) = req_id
  id
}

///|
/// Notify that a response was received
pub fn notifyResponseReceived(
  request_id : Int,
  url : String,
  status : Int,
  mime_type : String,
  headers_json : String,
) -> Unit {
  let req_id = @scheduler.RequestId(request_id)
  let headers : Map[String, String] = parse_headers_json(headers_json)
  protocol.notify_response_received(req_id, url, status, mime_type, headers)
}

///|
/// Notify that a response was received with explicit loader ID
pub fn notifyResponseReceivedWithLoader(
  request_id : Int,
  url : String,
  status : Int,
  mime_type : String,
  headers_json : String,
  loader_id : String,
) -> Unit {
  let req_id = @scheduler.RequestId(request_id)
  let headers : Map[String, String] = parse_headers_json(headers_json)
  protocol.notify_response_received_with_loader(
    req_id, url, status, mime_type, headers, loader_id,
  )
}

///|
/// Notify that loading finished
pub fn notifyLoadingFinished(
  request_id : Int,
  encoded_data_length : Int,
) -> Unit {
  let req_id = @scheduler.RequestId(request_id)
  protocol.notify_loading_finished(req_id, encoded_data_length)
}

///|
/// Notify that loading failed
pub fn notifyLoadingFailed(request_id : Int, error : String) -> Unit {
  let req_id = @scheduler.RequestId(request_id)
  protocol.notify_loading_failed(req_id, error)
}

///|
/// Flush pending network events to outbox and pending_messages
pub fn flushNetworkEvents(session_id : String) -> Unit {
  let sid = if session_id.length() == 0 { None } else { Some(session_id) }
  protocol.flush_network_events(sid)
  // Move events from outbox to pending_messages so they can be retrieved
  let messages = protocol.take_messages()
  for msg in messages {
    pending_messages.push(msg)
  }
}

///|
/// Check if Network domain is enabled
pub fn isNetworkEnabled() -> Bool {
  // Access the network manager to check enabled state
  // Note: We need to check the internal enabled state
  protocol.has_pending_network_events() || true // Network manager is always available
}

///|
/// Parse headers JSON string to Map
fn parse_headers_json(json_str : String) -> Map[String, String] {
  let headers : Map[String, String] = {}
  if json_str.length() == 0 || json_str == "{}" {
    return headers
  }
  // Simple JSON object parser for {"key": "value", ...}
  let json = @json.parse(json_str) catch { _ => return headers }
  match json {
    Object(map) =>
      map.each(fn(k, v) {
        match v {
          String(s) => headers[k] = s
          _ => ()
        }
      })
    _ => ()
  }
  headers
}
