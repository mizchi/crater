///|
/// BiDi request message
priv struct BidiRequest {
  id : Int
  method_name : String
  params : Json?
}

///|
/// BiDi response message
priv struct BidiResponse {
  id : Int
  result : Json?
  error : BidiError?
}

///|
/// BiDi error payload
priv struct BidiError {
  error : String
  message : String
  stacktrace : String
}

///|
/// BiDi event message
priv struct BidiEvent {
  event_method : String
  params : Json
}

///|
/// Outgoing BiDi message
priv enum BidiOutMessage {
  Response(BidiResponse)
  Event(BidiEvent)
  Raw(String)
}

///|
/// Process incoming JSON message
fn BidiProtocol::process_message(
  self : BidiProtocol,
  json_str : String,
) -> Result[Unit, String] {
  let parsed = match @bidi_wire.parse_request(json_str) {
    Ok(request) => request
    Err(err) => return Err(err)
  }
  let request : BidiRequest = {
    id: parsed.id,
    method_name: parsed.method_name,
    params: parsed.params,
  }
  self.dispatch(request)
}

///|
/// Take and clear outgoing messages
fn BidiProtocol::take_messages(self : BidiProtocol) -> Array[BidiOutMessage] {
  let out = self.outbox
  self.outbox = []
  out
}

///|
/// Convert outgoing message to JSON string
fn BidiOutMessage::to_json(self : BidiOutMessage) -> String {
  match self {
    Response(resp) => response_to_json(resp)
    Event(evt) => event_to_json(evt)
    Raw(raw) => raw
  }
}

///|
/// Send success response
fn BidiProtocol::send_success(
  self : BidiProtocol,
  id : Int,
  result : Json?,
) -> Unit {
  let resp : BidiResponse = { id, result, error: None }
  self.outbox.push(Response(resp))
}

///|
/// Send a pre-serialized response JSON string
fn BidiProtocol::send_raw(self : BidiProtocol, json : String) -> Unit {
  self.outbox.push(Raw(json))
}

///|
/// Send error response
fn BidiProtocol::send_error(
  self : BidiProtocol,
  id : Int,
  code : String,
  message : String,
) -> Unit {
  let err : BidiError = { error: code, message, stacktrace: "" }
  let resp : BidiResponse = { id, result: None, error: Some(err) }
  self.outbox.push(Response(resp))
}

///|
/// Response JSON serialization
fn response_to_json(resp : BidiResponse) -> String {
  match resp.error {
    Some(err) =>
      @bidi_wire.error_response_to_json_with_stacktrace(
        resp.id,
        err.error,
        err.message,
        err.stacktrace,
      )
    None => @bidi_wire.success_response_to_json(resp.id, resp.result)
  }
}

///|
/// Event JSON serialization
fn event_to_json(evt : BidiEvent) -> String {
  @bidi_wire.event_to_json(evt.event_method, evt.params)
}
