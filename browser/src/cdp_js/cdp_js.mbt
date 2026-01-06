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
