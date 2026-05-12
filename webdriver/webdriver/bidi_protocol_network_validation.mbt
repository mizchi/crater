///|
/// Validate network.addIntercept parameters.
/// Returns None when an error response has already been sent.
fn BidiProtocol::validate_network_add_intercept_params(
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

  let options : Map[String, Json] = {}

  let raw_phases = match map.get("phases") {
    Some(raw) => raw
    None => {
      self.send_error(request_id, "invalid argument", "Missing phases")
      return None
    }
  }
  let phases : Array[Json] = []
  match raw_phases {
    Array(items) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "phases must not be an empty array",
        )
        return None
      } else {
        for item in items {
          match item {
            String(phase_name) =>
              if is_valid_network_intercept_phase(phase_name) {
                phases.push(Json::string(phase_name))
              } else {
                self.send_error(
                  request_id, "invalid argument", "phase is invalid",
                )
                return None
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "phases entries must be strings",
              )
              return None
            }
          }
        }
      }
    _ => {
      self.send_error(request_id, "invalid argument", "phases must be an array")
      return None
    }
  }
  options["phases"] = Json::array(phases)

  let raw_url_patterns = get_map_field_with_alias(
    map, "urlPatterns", "url_patterns",
  )
  let url_patterns : Array[Json] = []
  match raw_url_patterns {
    Some(Array(items)) =>
      for item in items {
        let validated = match
          validate_network_intercept_url_pattern_entry(item) {
          Some(validated) => validated
          None => {
            self.send_error(
              request_id, "invalid argument", "urlPatterns entry is invalid",
            )
            return None
          }
        }
        url_patterns.push(validated)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "urlPatterns must be an array",
      )
      return None
    }
    None => ()
  }
  options["urlPatterns"] = Json::array(url_patterns)

  let raw_contexts : Json? = match map.get("contexts") {
    Some(Null) => None
    Some(raw) => Some(raw)
    None => None
  }
  match raw_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      } else {
        let contexts : Array[Json] = []
        for item in items {
          match item {
            String(ctx_id) =>
              if !self.manager.has_session(ctx_id) {
                self.send_error(
                  request_id,
                  "no such frame",
                  "Unknown context: " + ctx_id,
                )
                return None
              } else if self.context_parent.contains(ctx_id) {
                self.send_error(
                  request_id, "invalid argument", "context must be top-level",
                )
                return None
              } else {
                contexts.push(Json::string(ctx_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be strings",
              )
              return None
            }
          }
        }
        options["contexts"] = Json::array(contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  Some(options)
}

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

  let raw_data_types = match
    get_map_field_with_alias(map, "dataTypes", "data_types") {
    Some(raw) => raw
    None => {
      self.send_error(request_id, "invalid argument", "Missing dataTypes")
      return None
    }
  }
  let data_types : Array[Json] = []
  match raw_data_types {
    Array(items) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "dataTypes must not be an empty array",
        )
        return None
      } else {
        for item in items {
          match item {
            String(name) =>
              if name == "request" || name == "response" {
                data_types.push(Json::string(name))
              } else {
                self.send_error(
                  request_id, "invalid argument", "dataTypes entry is invalid",
                )
                return None
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "dataTypes entries must be strings",
              )
              return None
            }
          }
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "dataTypes must be an array",
      )
      return None
    }
  }
  options["dataTypes"] = Json::array(data_types)

  let raw_max_encoded_data_size = match
    get_map_field_with_alias(map, "maxEncodedDataSize", "max_encoded_data_size") {
    Some(raw) => raw
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing maxEncodedDataSize",
      )
      return None
    }
  }
  let max_encoded_data_size = match raw_max_encoded_data_size {
    Number(n, ..) => {
      let as_int = n.to_int()
      if as_int.to_double() != n || as_int <= 0 {
        self.send_error(
          request_id, "invalid argument", "maxEncodedDataSize must be a positive integer",
        )
        return None
      }
      if as_int > 1000000000 {
        self.send_error(
          request_id, "invalid argument", "maxEncodedDataSize exceeds the implementation limit",
        )
        return None
      }
      as_int
    }
    _ => {
      self.send_error(
        request_id, "invalid argument", "maxEncodedDataSize must be a positive integer",
      )
      return None
    }
  }
  options["maxEncodedDataSize"] = Json::number(
    max_encoded_data_size.to_double(),
  )

  let collector_type = match
    get_map_field_with_alias(map, "collectorType", "collector_type") {
    Some(String(name)) =>
      if name == "blob" || name == "base64" {
        name
      } else {
        self.send_error(
          request_id, "invalid argument", "collectorType is invalid",
        )
        return None
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "collectorType must be a string",
      )
      return None
    }
    None => "blob"
  }
  options["collectorType"] = Json::string(collector_type)

  match raw_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      } else {
        let contexts : Array[Json] = []
        for item in items {
          match item {
            String(ctx_id) =>
              if !self.manager.has_session(ctx_id) {
                self.send_error(
                  request_id,
                  "no such frame",
                  "Unknown context: " + ctx_id,
                )
                return None
              } else if self.context_parent.contains(ctx_id) {
                self.send_error(
                  request_id, "invalid argument", "context must be top-level",
                )
                return None
              } else {
                contexts.push(Json::string(ctx_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be strings",
              )
              return None
            }
          }
        }
        options["contexts"] = Json::array(contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  match raw_user_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return None
      } else {
        let user_contexts : Array[Json] = []
        for item in items {
          match item {
            String(user_context_id) =>
              if !self.user_contexts.get(user_context_id).unwrap_or(false) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else {
                user_contexts.push(Json::string(user_context_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "userContexts entries must be strings",
              )
              return None
            }
          }
        }
        options["userContexts"] = Json::array(user_contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return None
    }
    None => ()
  }

  Some(options)
}

///|
/// Validate network.setExtraHeaders parameters.
/// Returns None when an error response has already been sent.
fn BidiProtocol::validate_network_set_extra_headers_params(
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

  let raw_contexts = map.get("contexts")
  let raw_user_contexts = get_map_field_with_alias(
    map, "userContexts", "user_contexts",
  )
  if raw_contexts is Some(_) && raw_user_contexts is Some(_) {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts are mutually exclusive",
    )
    return None
  }

  let raw_headers = match map.get("headers") {
    Some(raw) => raw
    None => {
      self.send_error(request_id, "invalid argument", "Missing headers")
      return None
    }
  }

  let options : Map[String, Json] = {}

  let headers : Array[Json] = []
  match raw_headers {
    Array(items) =>
      for item in items {
        let header = match validate_network_extra_header_entry(item) {
          Some(header) => header
          None => {
            self.send_error(
              request_id, "invalid argument", "headers entry is invalid",
            )
            return None
          }
        }
        headers.push(header)
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "headers must be an array",
      )
      return None
    }
  }
  options["headers"] = Json::array(headers)

  match raw_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      } else {
        let contexts : Array[Json] = []
        for item in items {
          match item {
            String(ctx_id) =>
              if !self.manager.has_session(ctx_id) {
                self.send_error(
                  request_id,
                  "no such frame",
                  "Unknown context: " + ctx_id,
                )
                return None
              } else if self.context_parent.contains(ctx_id) {
                self.send_error(
                  request_id, "invalid argument", "context must be top-level",
                )
                return None
              } else {
                contexts.push(Json::string(ctx_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be strings",
              )
              return None
            }
          }
        }
        options["contexts"] = Json::array(contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  match raw_user_contexts {
    Some(Array(items)) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return None
      } else {
        let user_contexts : Array[Json] = []
        for item in items {
          match item {
            String(user_context_id) =>
              if !self.user_contexts.get(user_context_id).unwrap_or(false) {
                self.send_error(
                  request_id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return None
              } else {
                user_contexts.push(Json::string(user_context_id))
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "userContexts entries must be strings",
              )
              return None
            }
          }
        }
        options["userContexts"] = Json::array(user_contexts)
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return None
    }
    None => ()
  }

  Some(options)
}
