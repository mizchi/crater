///|
/// Serialized value object must include at least one discriminator key.
fn is_valid_serialized_value_map(value_map : Map[String, Json]) -> Bool {
  value_map.contains("type") ||
  value_map.contains("handle") ||
  value_map.contains("sharedId")
}

///|
/// Validate optional handle/sharedId references in a serialized value.
fn BidiProtocol::validate_serialized_reference_fields(
  self : BidiProtocol,
  request_id : Int,
  value_map : Map[String, Json],
) -> Unit? {
  match value_map.get("handle") {
    Some(String(handle_id)) =>
      if !has_runtime_handle(handle_id) {
        self.send_error(
          request_id,
          "no such handle",
          "Unknown handle: " + handle_id,
        )
        return Some(())
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "handle must be a string")
      return Some(())
    }
    None => ()
  }
  match value_map.get("sharedId") {
    Some(String(shared_id)) =>
      if !has_runtime_shared_node(shared_id) {
        self.send_error(
          request_id,
          "no such node",
          "Unknown sharedId: " + shared_id,
        )
        return Some(())
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "sharedId must be a string",
      )
      return Some(())
    }
    None => ()
  }
  None
}
