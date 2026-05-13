///|
/// Validate browser.setDownloadBehavior parameters.
fn BidiProtocol::validate_browser_set_download_behavior(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(m)) => m
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return Some(())
    }
  }

  match map.get("downloadBehavior") {
    Some(Null) => ()
    Some(Object(download_behavior)) => {
      let behavior_type = match download_behavior.get("type") {
        Some(String(kind)) => kind
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "downloadBehavior.type must be a string",
          )
          return Some(())
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "downloadBehavior.type is required",
          )
          return Some(())
        }
      }

      if behavior_type != "allowed" &&
        behavior_type != "denied" &&
        behavior_type != "default" {
        self.send_error(
          request_id, "invalid argument", "downloadBehavior.type is invalid",
        )
        return Some(())
      }

      if behavior_type == "allowed" {
        match download_behavior.get("destinationFolder") {
          Some(String(_)) => ()
          _ => {
            self.send_error(
              request_id, "invalid argument", "downloadBehavior.destinationFolder must be a string",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "downloadBehavior must be an object or null",
      )
      return Some(())
    }
    None => ()
  }

  match get_map_field_with_alias(map, "userContexts", "user_contexts") {
    Some(Array(user_contexts)) => {
      if user_contexts.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return Some(())
      }
      for raw_user_context in user_contexts {
        match raw_user_context {
          String(user_context_id) =>
            if !self.user_contexts.contains(user_context_id) {
              self.send_error(
                request_id,
                "no such user context",
                "Unknown user context: " + user_context_id,
              )
              return Some(())
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return Some(())
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return Some(())
    }
    None => ()
  }

  None
}
