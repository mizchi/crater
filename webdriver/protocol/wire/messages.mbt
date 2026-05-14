///|
/// Parsed BiDi request shape used by the implementation dispatcher.
pub(all) struct BidiWireRequest {
  id : Int
  method_name : String
  params : Json?
}

///|
pub fn parse_request(json_str : String) -> Result[BidiWireRequest, String] {
  match @bidi_wire.parse_request(json_str) {
    Ok(request) =>
      Ok({
        id: request.id,
        method_name: request.method_name,
        params: request.params,
      })
    Err(err) => Err(err)
  }
}

///|
pub fn success_response_to_json(id : Int, result : Json?) -> String {
  @bidi_wire.success_response_to_json(id, result)
}

///|
pub fn error_response_to_json(
  id : Int,
  error : String,
  message : String,
  stacktrace : String,
) -> String {
  @bidi_wire.error_response_to_json_with_stacktrace(
    id, error, message, stacktrace,
  )
}

///|
pub fn event_to_json(event_method : String, params : Json) -> String {
  @bidi_wire.event_to_json(event_method, params)
}
