///|
/// Handle browsingContext.captureScreenshot with WPT-focused validation.
fn BidiProtocol::handle_capture_screenshot(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  match self.resolve_capture_screenshot_data(request.id, request.params) {
    Some(data) => {
      let result = make_object({ "data": Json::string(data) })
      self.send_success(request.id, Some(result))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_capture_screenshot_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_capture_screenshot_data(request_id, params) {
    Some(data) => self.send_success(request_id, Some(Json::string(data)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_capture_screenshot_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let raw_params = params
  let params = match raw_params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return None
  }
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)

  match params.get("origin") {
    Some(String("viewport")) | Some(String("document")) | None => ()
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport' or 'document'",
      )
      return None
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport' or 'document'",
      )
      return None
    }
  }

  let mut has_box_clip = false
  let mut clip_box_width = 1.0
  let mut clip_box_height = 1.0
  match params.get("clip") {
    None => ()
    Some(Object(clip_map)) => {
      let clip_type = match clip_map.get("type") {
        Some(String(kind)) => kind
        _ => {
          self.send_error(
            request_id, "invalid argument", "clip.type must be a string",
          )
          return None
        }
      }

      if clip_type == "element" {
        match clip_map.get("element") {
          Some(Object(element)) =>
            match element.get("sharedId") {
              Some(String(shared_id)) =>
                if !has_runtime_shared_node(shared_id) ||
                  !runtime_shared_node_is_element(shared_id) {
                  self.send_error(
                    request_id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return None
                }
              _ => {
                self.send_error(
                  request_id, "invalid argument", "clip.element.sharedId must be a string",
                )
                return None
              }
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "clip.element must be a node reference",
            )
            return None
          }
        }
      } else if clip_type == "box" {
        has_box_clip = true
        let _clip_box_x = match clip_map.get("x") {
          Some(value) =>
            match
              json_as_safe_number(
                value, -9007199254740991.0, 9007199254740991.0,
              ) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
          }
        }
        let _clip_box_y = match clip_map.get("y") {
          Some(value) =>
            match
              json_as_safe_number(
                value, -9007199254740991.0, 9007199254740991.0,
              ) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
          }
        }
        clip_box_width = match clip_map.get("width") {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
          }
        }
        clip_box_height = match clip_map.get("height") {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(parsed) => parsed
              None => {
                self.send_error(
                  request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
                )
                return None
              }
            }
          None => {
            self.send_error(
              request_id, "invalid argument", "clip.box x/y/width/height must be numbers",
            )
            return None
          }
        }
      } else {
        self.send_error(request_id, "invalid argument", "clip.type is invalid")
        return None
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "clip must be an object")
      return None
    }
  }

  if has_box_clip && (clip_box_width <= 0.0 || clip_box_height <= 0.0) {
    self.send_error(
      request_id, "unable to capture screen", "Clip dimensions must be positive",
    )
    return None
  }

  match params.get("format") {
    None => ()
    Some(Object(format)) => {
      match format.get("type") {
        Some(String("image/png")) | Some(String("image/jpeg")) => ()
        Some(String(_)) => {
          self.send_error(
            request_id, "invalid argument", "format.type must be 'image/png' or 'image/jpeg'",
          )
          return None
        }
        _ => {
          self.send_error(
            request_id, "invalid argument", "format.type must be 'image/png' or 'image/jpeg'",
          )
          return None
        }
      }

      match format.get("quality") {
        Some(value) =>
          match json_as_safe_number(value, 0.0, 1.0) {
            Some(_) => ()
            None => {
              self.send_error(
                request_id, "invalid argument", "format.quality must be a number in [0,1]",
              )
              return None
            }
          }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "format must be an object",
      )
      return None
    }
  }

  match
    self.try_resolve_actual_capture_screenshot_data(request_id, ctx_id, params) {
    Some(data) => return Some(data)
    None => ()
  }

  match self.build_synthetic_capture_screenshot_result(ctx_id, raw_params) {
    Some(Object(result_map)) =>
      match result_map.get("error") {
        Some(String(error_name)) => {
          let message = match result_map.get("message") {
            Some(String(message)) => message
            _ => "Unable to capture screenshot"
          }
          self.send_error(request_id, error_name, message)
          None
        }
        _ =>
          match result_map.get("data") {
            Some(String(data)) => Some(data)
            _ => {
              self.send_error(
                request_id, "unknown error", "Failed to build synthetic screenshot",
              )
              None
            }
          }
      }
    _ => {
      self.send_error(
        request_id, "unknown error", "Failed to build synthetic screenshot",
      )
      None
    }
  }
}
