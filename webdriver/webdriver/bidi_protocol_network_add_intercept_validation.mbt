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
