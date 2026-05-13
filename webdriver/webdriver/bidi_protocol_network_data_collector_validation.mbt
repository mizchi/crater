///|
/// Validate network.addDataCollector parameters.
/// Returns None when an error response has already been sent.
fn BidiProtocol::validate_network_add_data_collector_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Map[String, Json]? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let raw_contexts : Json? = match map.get("contexts") {
    Some(Null) => None
    Some(raw) => Some(raw)
    None => None
  }
  let raw_user_contexts : Json? = match
    get_map_field_with_alias(map, "userContexts", "user_contexts") {
    Some(Null) => None
    Some(raw) => Some(raw)
    None => None
  }
  if raw_contexts is Some(_) && raw_user_contexts is Some(_) {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts are mutually exclusive",
    )
    return None
  }

  let options : Map[String, Json] = {}

  match self.validate_network_data_collector_data_types(request_id, map) {
    Some(data_types) => options["dataTypes"] = data_types
    None => return None
  }
  match
    self.validate_network_data_collector_max_encoded_data_size(request_id, map) {
    Some(max_encoded_data_size) =>
      options["maxEncodedDataSize"] = max_encoded_data_size
    None => return None
  }
  match self.validate_network_data_collector_type(request_id, map) {
    Some(collector_type) => options["collectorType"] = collector_type
    None => return None
  }
  match
    self.validate_network_data_collector_contexts(request_id, raw_contexts) {
    Some(Some(contexts)) => options["contexts"] = contexts
    Some(None) => ()
    None => return None
  }
  match
    self.validate_network_data_collector_user_contexts(
      request_id, raw_user_contexts,
    ) {
    Some(Some(user_contexts)) => options["userContexts"] = user_contexts
    Some(None) => ()
    None => return None
  }

  Some(options)
}
