///|
/// Handle browsingContext.setViewport.
fn BidiProtocol::handle_set_viewport(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let mut target_context : String? = None
  match params.get("context") {
    Some(String(ctx_id)) => target_context = Some(ctx_id)
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => ()
  }

  let target_user_contexts : Array[String] = []
  match get_map_field_with_alias(params, "userContexts", "user_contexts") {
    Some(Array(user_contexts)) =>
      if user_contexts.length() == 0 {
        self.send_error(
          request.id,
          "invalid argument",
          "userContexts must not be an empty array",
        )
        return
      } else {
        for user_context in user_contexts {
          match user_context {
            String(user_context_id) =>
              if user_context_id == "" {
                self.send_error(
                  request.id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return
              } else if !self.user_contexts.contains(user_context_id) {
                self.send_error(
                  request.id,
                  "no such user context",
                  "Unknown user context: " + user_context_id,
                )
                return
              } else {
                target_user_contexts.push(user_context_id)
              }
            _ => {
              self.send_error(
                request.id,
                "invalid argument",
                "userContexts entries must be strings",
              )
              return
            }
          }
        }
      }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "userContexts must be an array",
      )
      return
    }
    None => ()
  }

  let has_context = target_context is Some(_)
  let has_user_contexts = target_user_contexts.length() > 0
  if has_context && has_user_contexts {
    self.send_error(
      request.id,
      "invalid argument",
      "context and userContexts are mutually exclusive",
    )
    return
  }
  if !has_context && !has_user_contexts {
    self.send_error(
      request.id,
      "invalid argument",
      "Either context or userContexts must be provided",
    )
    return
  }

  let mut viewport_mode = 0 // 0: keep, 1: reset(null), 2: set(object)
  let mut viewport_width = 0
  let mut viewport_height = 0
  match params.get("viewport") {
    Some(Null) => viewport_mode = 1
    Some(Object(viewport_map)) =>
      match (viewport_map.get("width"), viewport_map.get("height")) {
        (Some(width_json), Some(height_json)) =>
          match
            (
              json_as_safe_int(width_json, 0.0, 9007199254740991.0),
              json_as_safe_int(height_json, 0.0, 9007199254740991.0),
            ) {
            (Some(width), Some(height)) => {
              viewport_mode = 2
              viewport_width = width
              viewport_height = height
            }
            _ => {
              self.send_error(
                request.id,
                "invalid argument",
                "viewport.width and viewport.height must be non-negative integers",
              )
              return
            }
          }
        _ => {
          self.send_error(
            request.id,
            "invalid argument",
            "viewport must include width and height",
          )
          return
        }
      }
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "viewport must be an object or null",
      )
      return
    }
    None => ()
  }

  let mut dpr_mode = 0 // 0: keep, 1: reset(null), 2: set(number)
  let mut dpr_value = 1.0
  match
    get_map_field_with_alias(params, "devicePixelRatio", "device_pixel_ratio") {
    Some(Null) => dpr_mode = 1
    Some(value) =>
      match json_as_safe_number(value, 0.000000001, 9007199254740991.0) {
        Some(parsed_dpr) => {
          dpr_mode = 2
          dpr_value = parsed_dpr
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "devicePixelRatio must be a positive number",
          )
          return
        }
      }
    None => ()
  }

  match target_context {
    Some(ctx_id) => {
      if !self.manager.has_session(ctx_id) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return
      }
      if self.context_parent.contains(ctx_id) {
        self.send_error(
          request.id,
          "invalid argument",
          "context must be top-level",
        )
        return
      }

      if viewport_mode == 1 {
        self.context_viewport_width.remove(ctx_id)
        self.context_viewport_height.remove(ctx_id)
      } else if viewport_mode == 2 {
        self.context_viewport_width[ctx_id] = viewport_width
        self.context_viewport_height[ctx_id] = viewport_height
      }
      if dpr_mode == 1 {
        self.context_device_pixel_ratio.remove(ctx_id)
      } else if dpr_mode == 2 {
        self.context_device_pixel_ratio[ctx_id] = dpr_value
      }
      self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
    }
    None =>
      for user_context_id in target_user_contexts {
        if viewport_mode == 1 {
          self.user_context_viewport_width.remove(user_context_id)
          self.user_context_viewport_height.remove(user_context_id)
        } else if viewport_mode == 2 {
          self.user_context_viewport_width[user_context_id] = viewport_width
          self.user_context_viewport_height[user_context_id] = viewport_height
        }
        if dpr_mode == 1 {
          self.user_context_device_pixel_ratio.remove(user_context_id)
        } else if dpr_mode == 2 {
          self.user_context_device_pixel_ratio[user_context_id] = dpr_value
        }
      }
  }

  if has_user_contexts {
    for ctx_id in self.manager.list_sessions() {
      let ctx_user_context = self.context_user_context
        .get(ctx_id)
        .unwrap_or("default")
      if array_contains(target_user_contexts, ctx_user_context) {
        self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
      }
    }
  }

  self.send_success(request.id, Some(make_object({})))
}

///|
/// Handle browsingContext.traverseHistory.
fn BidiProtocol::handle_traverse_history(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  let params = match request.params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request.id,
        "invalid argument",
        "params must be an object",
      )
      return
    }
  }

  let ctx_id = match params.get("context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "context must be a string",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing context")
      return
    }
  }

  if !self.manager.has_session(ctx_id) {
    self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
    return
  }
  if self.context_parent.contains(ctx_id) {
    self.send_error(request.id, "invalid argument", "context must be top-level")
    return
  }

  let delta = match params.get("delta") {
    Some(value) =>
      match json_as_safe_int(value, -9007199254740991.0, 9007199254740991.0) {
        Some(parsed) => parsed
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "delta must be an integer in [-9007199254740991, 9007199254740991]",
          )
          return
        }
      }
    None => {
      self.send_error(request.id, "invalid argument", "Missing delta")
      return
    }
  }

  if delta == 0 {
    self.send_success(request.id, Some(make_object({})))
    return
  }

  match self.manager.get_session(ctx_id) {
    Some(session) => {
      let page = session.get_page()
      let history = match page.get_navigation_history() {
        Ok(entries) => entries
        Err(_) => {
          self.send_error(
            request.id,
            "unknown error",
            "Failed to inspect navigation history",
          )
          return
        }
      }
      let target_index = history.current_index + delta
      if target_index < 0 || target_index >= history.entries.length() {
        self.send_error(
          request.id,
          "no such history entry",
          "History traversal target is out of bounds",
        )
        return
      }

      let steps = if delta < 0 { 0 - delta } else { delta }
      if delta < 0 {
        let mut step = 0
        while step < steps {
          match page.go_back() {
            Ok(true) => ()
            _ => {
              self.send_error(
                request.id,
                "no such history entry",
                "History traversal target is out of bounds",
              )
              return
            }
          }
          step += 1
        }
      } else {
        let mut step = 0
        while step < steps {
          match page.go_forward() {
            Ok(true) => ()
            _ => {
              self.send_error(
                request.id,
                "no such history entry",
                "History traversal target is out of bounds",
              )
              return
            }
          }
          step += 1
        }
      }

      let destination = session.get_url()
      self.load_data_url_content(ctx_id, destination)
      let nav_id = self.next_navigation_id.to_string()
      self.next_navigation_id += 1
      self.emit_navigation_events(ctx_id, destination, nav_id)
      self.send_success(request.id, Some(make_object({})))
    }
    None => {
      self.send_error(request.id, "no such frame", "Unknown context: " + ctx_id)
      return
    }
  }
}
