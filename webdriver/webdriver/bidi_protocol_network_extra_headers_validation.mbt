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
