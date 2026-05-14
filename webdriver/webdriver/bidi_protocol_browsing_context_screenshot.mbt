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

  let screenshot_options = match
    @rendering.normalize_capture_screenshot_options(params) {
    Ok(options) => options
    Err(error) => {
      self.send_error(request_id, error.name(), error.message())
      return None
    }
  }
  match screenshot_options.clip {
    @rendering.ElementClip(shared_id) =>
      if !has_runtime_shared_node(shared_id) ||
        !runtime_shared_node_is_element(shared_id) {
        self.send_error(
          request_id,
          "no such node",
          "Unknown sharedId: " + shared_id,
        )
        return None
      }
    _ => ()
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
