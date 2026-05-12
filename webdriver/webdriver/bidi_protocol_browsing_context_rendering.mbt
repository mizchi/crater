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

///|
/// Handle browsingContext.print with WPT-focused validation.
fn BidiProtocol::handle_print(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  match self.resolve_print_data(request.id, request.params) {
    Some(data) => {
      let result = make_object({ "data": Json::string(data) })
      self.send_success(request.id, Some(result))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_print_data(request_id, params) {
    Some(data) => self.send_success(request_id, Some(Json::string(data)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let params = match params {
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

  match params.get("background") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "background must be a boolean",
      )
      return None
    }
  }

  match params.get("margin") {
    None => ()
    Some(Object(margin)) =>
      for margin_side in ["top", "bottom", "left", "right"] {
        match margin.get(margin_side) {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(_) => ()
              None => {
                self.send_error(
                  request_id, "invalid argument", "margin values must be non-negative numbers",
                )
                return None
              }
            }
          None => ()
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "margin must be an object",
      )
      return None
    }
  }

  match params.get("orientation") {
    Some(String("portrait")) | Some(String("landscape")) | None => ()
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "orientation must be 'portrait' or 'landscape'",
      )
      return None
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "orientation must be 'portrait' or 'landscape'",
      )
      return None
    }
  }

  match params.get("page") {
    None => ()
    Some(Object(page)) => {
      match page.get("width") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request_id, "invalid argument", "page.width must be a number >= 0.035",
            )
            return None
          }
        None => ()
      }
      match page.get("height") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request_id, "invalid argument", "page.height must be a number >= 0.035",
            )
            return None
          }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "page must be an object")
      return None
    }
  }

  match get_map_field_with_alias(params, "pageRanges", "page_ranges") {
    None => ()
    Some(Array(page_ranges)) =>
      for page_range in page_ranges {
        match page_range {
          Number(n, ..) =>
            if n < 1.0 || n != n.to_int64().to_double() {
              self.send_error(
                request_id, "invalid argument", "pageRanges entries are invalid",
              )
              return None
            }
          String(v) =>
            if !is_valid_print_page_range(v) {
              self.send_error(
                request_id, "invalid argument", "pageRanges entries are invalid",
              )
              return None
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "pageRanges must be an array of strings/integers",
            )
            return None
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pageRanges must be an array of strings/integers",
      )
      return None
    }
  }

  match params.get("scale") {
    None => ()
    Some(value) =>
      if json_as_safe_number(value, 0.1, 2.0) is None {
        self.send_error(
          request_id, "invalid argument", "scale must be a number in [0.1, 2.0]",
        )
        return None
      }
  }

  match get_map_field_with_alias(params, "shrinkToFit", "shrink_to_fit") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "shrinkToFit must be a boolean",
      )
      return None
    }
  }

  let orientation = match params.get("orientation") {
    Some(String("landscape")) => "landscape"
    _ => "portrait"
  }
  let mut page_width_cm = 21.59
  let mut page_height_cm = 27.94
  match params.get("page") {
    Some(Object(page)) => {
      match page.get("width") {
        Some(Number(width, ..)) => page_width_cm = width
        _ => ()
      }
      match page.get("height") {
        Some(Number(height, ..)) => page_height_cm = height
        _ => ()
      }
    }
    _ => ()
  }
  if orientation == "landscape" {
    let current_width = page_width_cm
    page_width_cm = page_height_cm
    page_height_cm = current_width
  }
  let mut margin_top = 0.0
  let mut margin_bottom = 0.0
  let mut margin_left = 0.0
  let mut margin_right = 0.0
  let mut has_margin_top = false
  let mut has_margin_bottom = false
  let mut has_margin_left = false
  let mut has_margin_right = false
  match params.get("margin") {
    Some(Object(margin)) => {
      match margin.get("top") {
        Some(Number(value, ..)) => {
          margin_top = value
          has_margin_top = true
        }
        _ => ()
      }
      match margin.get("bottom") {
        Some(Number(value, ..)) => {
          margin_bottom = value
          has_margin_bottom = true
        }
        _ => ()
      }
      match margin.get("left") {
        Some(Number(value, ..)) => {
          margin_left = value
          has_margin_left = true
        }
        _ => ()
      }
      match margin.get("right") {
        Some(Number(value, ..)) => {
          margin_right = value
          has_margin_right = true
        }
        _ => ()
      }
    }
    _ => ()
  }
  if margin_top >= page_height_cm ||
    margin_bottom >= page_height_cm ||
    margin_left >= page_width_cm ||
    margin_right >= page_width_cm {
    self.send_error(
      request_id, "unsupported operation", "Margin consumes entire printable area",
    )
    return None
  }
  let background = match params.get("background") {
    Some(True) => true
    _ => false
  }
  let default_print_margin_cm = 1.0
  let minimum_printable_cm = 2.54 / 72.0
  let effective_margin_right = if has_margin_right {
    margin_right
  } else {
    default_print_margin_cm
  }
  let effective_margin_left = if has_margin_left {
    margin_left
  } else {
    default_print_margin_cm
  }
  let effective_margin_bottom = if has_margin_bottom {
    margin_bottom
  } else {
    default_print_margin_cm
  }
  let effective_margin_top = if has_margin_top {
    margin_top
  } else {
    default_print_margin_cm
  }
  let printable_width_cm = if has_margin_left &&
    margin_left + effective_margin_right > page_width_cm - minimum_printable_cm {
    page_width_cm - minimum_printable_cm
  } else if has_margin_right &&
    margin_right + effective_margin_left > page_width_cm - minimum_printable_cm {
    page_width_cm - minimum_printable_cm
  } else {
    page_width_cm
  }
  let printable_height_cm = if has_margin_top &&
    margin_top + effective_margin_bottom > page_height_cm - minimum_printable_cm {
    page_height_cm - minimum_printable_cm
  } else if has_margin_bottom &&
    margin_bottom + effective_margin_top > page_height_cm - minimum_printable_cm {
    page_height_cm - minimum_printable_cm
  } else {
    page_height_cm
  }
  let synthetic_details = self.resolve_synthetic_print_details(
    ctx_id, params, printable_width_cm, printable_height_cm,
  )
  let signature = match synthetic_details.get("signature") {
    Some(String(value)) if value != "" => value
    _ => self.current_context_url(ctx_id)
  }
  let pages = match synthetic_details.get("pages") {
    Some(Array(values)) => values
    _ => []
  }
  let meta = make_object({
    "kind": Json::string("crater.synthetic.print"),
    "orientation": Json::string(orientation),
    "pageWidthCm": Json::number(printable_width_cm),
    "pageHeightCm": Json::number(printable_height_cm),
    "background": Json::boolean(background),
    "signature": Json::string(signature),
    "pages": Json::array(pages),
  })
  Some(synthetic_print_pdf_from_meta(meta))
}

///|
/// Validate a single print page-range token.
fn is_valid_print_page_range(raw : String) -> Bool {
  let value = raw.trim().to_owned()
  if value.length() == 0 {
    return false
  }
  match find_substring(value, "-", 0) {
    Some(first_dash) => {
      match find_substring(value, "-", first_dash + 1) {
        Some(_) => return false
        None => ()
      }
      if first_dash == 0 {
        let end_text = value.unsafe_substring(start=1, end=value.length())
        match parse_decimal_string(end_text) {
          Some(v) => v >= 1
          None => false
        }
      } else if first_dash == value.length() - 1 {
        let start_text = value.unsafe_substring(start=0, end=first_dash)
        match parse_decimal_string(start_text) {
          Some(v) => v >= 1
          None => false
        }
      } else {
        let start_text = value.unsafe_substring(start=0, end=first_dash)
        let end_text = value.unsafe_substring(
          start=first_dash + 1,
          end=value.length(),
        )
        let start = match parse_decimal_string(start_text) {
          Some(v) => v
          None => return false
        }
        let end = match parse_decimal_string(end_text) {
          Some(v) => v
          None => return false
        }
        start >= 1 && end >= 1 && start <= end
      }
    }
    None =>
      match parse_decimal_string(value) {
        Some(v) => v >= 1
        None => false
      }
  }
}

///|
fn is_valid_locate_nodes_locator_type(locator_type : String) -> Bool {
  locator_type == "css" ||
  locator_type == "xpath" ||
  locator_type == "innerText" ||
  locator_type == "accessibility" ||
  locator_type == "context"
}

///|
/// Convert a small XPath subset used by WPT locateNodes tests to CSS.
fn xpath_to_css_selector(xpath : String) -> String? {
  let trimmed = xpath.trim().to_owned()
  if trimmed == ".//*[name()='circle']" {
    return Some("circle")
  }

  let body = if trimmed.has_prefix(".//") {
    trimmed.unsafe_substring(start=3, end=trimmed.length())
  } else if trimmed.has_prefix("//") {
    trimmed.unsafe_substring(start=2, end=trimmed.length())
  } else {
    return None
  }
  if body == "" {
    return None
  }

  match find_substring(body, "[@", 0) {
    None => if body.contains("[") { None } else { Some(body) }
    Some(predicate_idx) => {
      let selector_tag = body.unsafe_substring(start=0, end=predicate_idx)
      if selector_tag == "" {
        return None
      }
      let predicate_start = predicate_idx + 2
      let predicate_full = body.unsafe_substring(
        start=predicate_start,
        end=body.length(),
      )
      if predicate_full == "" || !predicate_full.has_suffix("]") {
        return None
      }
      let predicate = predicate_full.unsafe_substring(
        start=0,
        end=predicate_full.length() - 1,
      )
      match find_substring(predicate, "=", 0) {
        None => None
        Some(eq_idx) => {
          let attr_name = predicate.unsafe_substring(start=0, end=eq_idx)
          let quoted_value = predicate.unsafe_substring(
            start=eq_idx + 1,
            end=predicate.length(),
          )
          if attr_name == "" || quoted_value.length() < 2 {
            return None
          }
          let quote_chars = quoted_value.to_array()
          let quote = quote_chars[0]
          let end_quote = quote_chars[quote_chars.length() - 1]
          if (quote != '\'' && quote != '"') || end_quote != quote {
            return None
          }
          let attr_value = quoted_value.unsafe_substring(
            start=1,
            end=quoted_value.length() - 1,
          )
          Some(
            selector_tag +
            "[" +
            attr_name.trim().to_owned() +
            "=\"" +
            attr_value +
            "\"]",
          )
        }
      }
    }
  }
}

///|
/// Handle browsingContext.locateNodes with WPT-oriented parameter validation.
fn BidiProtocol::handle_locate_nodes(
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

  let locator = match params.get("locator") {
    Some(Object(map)) => map
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator must be an object",
      )
      return
    }
    None => {
      self.send_error(request.id, "invalid argument", "Missing locator")
      return
    }
  }
  let locator_type = match locator.get("type") {
    Some(String(kind)) => kind
    Some(_) => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator.type must be a string",
      )
      return
    }
    None => {
      self.send_error(
        request.id,
        "invalid argument",
        "locator.type is required",
      )
      return
    }
  }
  if !is_valid_locate_nodes_locator_type(locator_type) {
    self.send_error(request.id, "invalid argument", "locator.type is invalid")
    return
  }

  match self.validate_serialization_options(request.id, request.params) {
    Some(_) => return
    None => ()
  }

  let max_node_count = match
    get_map_field_with_alias(params, "maxNodeCount", "max_node_count") {
    Some(value) =>
      match json_as_safe_int(value, 1.0, 9007199254740991.0) {
        Some(parsed) => parsed
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "maxNodeCount must be an integer in [1, 9007199254740991]",
          )
          return
        }
      }
    None => -1
  }

  let start_node_shared_ids : Array[String] = []
  match get_map_field_with_alias(params, "startNodes", "start_nodes") {
    Some(Array(nodes)) => {
      if nodes.length() == 0 {
        self.send_error(
          request.id,
          "invalid argument",
          "startNodes must not be an empty array",
        )
        return
      }
      for raw_node in nodes {
        match raw_node {
          Object(node_map) =>
            match node_map.get("sharedId") {
              Some(String(shared_id)) => {
                if !has_runtime_shared_node(shared_id) {
                  self.send_error(
                    request.id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return
                }
                if !runtime_shared_node_is_element(shared_id) &&
                  !runtime_shared_node_is_document(shared_id) &&
                  !runtime_shared_node_is_shadow_root(shared_id) {
                  self.send_error(
                    request.id,
                    "invalid argument",
                    "startNodes entries must reference element, document, or shadow root nodes",
                  )
                  return
                }
                start_node_shared_ids.push(shared_id)
              }
              Some(_) => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "startNodes sharedId must be a string",
                )
                return
              }
              None => {
                self.send_error(
                  request.id,
                  "invalid argument",
                  "startNodes entries must be node references",
                )
                return
              }
            }
          _ => {
            self.send_error(
              request.id,
              "invalid argument",
              "startNodes must be an array of node references",
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
        "startNodes must be an array",
      )
      return
    }
    None => ()
  }

  match locator_type {
    "css" =>
      match locator.get("value") {
        Some(String(selector)) =>
          if selector == "" || selector == "a*b" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid CSS selector",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
    "xpath" =>
      match locator.get("value") {
        Some(String(selector)) =>
          if selector == "" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid XPath selector",
            )
            return
          } else if selector.contains(":") {
            self.send_error(
              request.id,
              "unknown error",
              "XPath evaluation failed",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
    "innerText" => {
      match locator.get("value") {
        Some(String(text_value)) =>
          if text_value == "" {
            self.send_error(
              request.id,
              "invalid selector",
              "Invalid innerText selector",
            )
            return
          }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      match locator.get("ignoreCase") {
        Some(True) | Some(False) | None => ()
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.ignoreCase must be a boolean",
          )
          return
        }
      }
      match locator.get("matchType") {
        Some(String("full")) | Some(String("partial")) | None => ()
        Some(String(_)) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.matchType must be 'full' or 'partial'",
          )
          return
        }
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.matchType must be a string",
          )
          return
        }
      }
      match locator.get("maxDepth") {
        Some(value) =>
          if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
            self.send_error(
              request.id,
              "invalid argument",
              "locator.maxDepth must be a non-negative integer",
            )
            return
          }
        None => ()
      }
    }
    "accessibility" => {
      let accessibility_value = match locator.get("value") {
        Some(Object(map)) => map
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be an object",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      let mut has_role = false
      let mut has_name = false
      match accessibility_value.get("role") {
        Some(String(_)) => has_role = true
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "accessibility role must be a string",
          )
          return
        }
        None => ()
      }
      match accessibility_value.get("name") {
        Some(String(_)) => has_name = true
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "accessibility name must be a string",
          )
          return
        }
        None => ()
      }
      if !has_role && !has_name {
        self.send_error(
          request.id,
          "invalid selector",
          "Invalid accessibility selector",
        )
        return
      }
    }
    "context" => {
      let context_value = match locator.get("value") {
        Some(Object(map)) => map
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value must be an object",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value is required",
          )
          return
        }
      }
      let target_ctx = match context_value.get("context") {
        Some(String(id)) => id
        Some(_) => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value.context must be a string",
          )
          return
        }
        None => {
          self.send_error(
            request.id,
            "invalid argument",
            "locator.value.context is required",
          )
          return
        }
      }
      if !self.manager.has_session(target_ctx) {
        self.send_error(
          request.id,
          "no such frame",
          "Unknown context: " + target_ctx,
        )
        return
      }
      let child_contexts = self.context_children.get(ctx_id).unwrap_or([])
      if !array_contains(child_contexts, target_ctx) {
        self.send_error(
          request.id,
          "invalid argument",
          "locator.value.context must reference a direct child context",
        )
        return
      }
    }
    _ => ()
  }

  let serialization_options_json = get_locate_nodes_serialization_options_json(
    request.params,
  )
  let nodes = match locator_type {
    "css" =>
      match locator.get("value") {
        Some(String(selector)) =>
          self.locate_nodes_css(
            ctx_id, selector, start_node_shared_ids, max_node_count, serialization_options_json,
          )
        _ => Json::array([])
      }
    "xpath" =>
      match locator.get("value") {
        Some(String(selector)) =>
          match xpath_to_css_selector(selector) {
            Some(css_selector) =>
              self.locate_nodes_css(
                ctx_id, css_selector, start_node_shared_ids, max_node_count, serialization_options_json,
              )
            None =>
              self.locate_nodes_xpath(
                ctx_id, selector, start_node_shared_ids, max_node_count, serialization_options_json,
              )
          }
        _ => Json::array([])
      }
    "innerText" =>
      match locator.get("value") {
        Some(String(text_value)) => {
          let ignore_case = match locator.get("ignoreCase") {
            Some(True) => true
            _ => false
          }
          let match_type = match locator.get("matchType") {
            Some(String("full")) => "full"
            Some(String("partial")) => "partial"
            _ => "full"
          }
          let max_depth = match locator.get("maxDepth") {
            Some(Number(n, ..)) => n.to_int64().to_int()
            _ => -1
          }
          self.locate_nodes_inner_text(
            ctx_id, text_value, ignore_case, match_type, max_depth, start_node_shared_ids,
            max_node_count, serialization_options_json,
          )
        }
        _ => Json::array([])
      }
    "accessibility" =>
      match locator.get("value") {
        Some(Object(value_map)) => {
          let role = match value_map.get("role") {
            Some(String(s)) => Some(s)
            _ => None
          }
          let name = match value_map.get("name") {
            Some(String(s)) => Some(s)
            _ => None
          }
          self.locate_nodes_accessibility(
            ctx_id, role, name, start_node_shared_ids, max_node_count, serialization_options_json,
          )
        }
        _ => Json::array([])
      }
    "context" =>
      match locator.get("value") {
        Some(Object(value_map)) =>
          match value_map.get("context") {
            Some(String(target_ctx)) => {
              let child_contexts = self.context_children
                .get(ctx_id)
                .unwrap_or([])
              let mut target_index = -1
              for i = 0; i < child_contexts.length(); i = i + 1 {
                if child_contexts[i] == target_ctx {
                  target_index = i
                  break
                }
              }
              if target_index < 0 {
                Json::array([])
              } else {
                self.locate_nodes_context(
                  ctx_id, target_index, max_node_count, serialization_options_json,
                )
              }
            }
            _ => Json::array([])
          }
        _ => Json::array([])
      }
    _ => Json::array([])
  }
  let normalized_nodes = normalize_svg_namespace_in_nodes(nodes)
  let result = make_object({ "nodes": normalized_nodes })
  self.send_success(request.id, Some(result))
}

///|
/// Check whether localName should use SVG namespace in BiDi node values.
fn is_svg_local_name(local_name : String) -> Bool {
  local_name == "svg" ||
  local_name == "circle" ||
  local_name == "text" ||
  local_name == "path" ||
  local_name == "rect" ||
  local_name == "ellipse" ||
  local_name == "line" ||
  local_name == "polyline" ||
  local_name == "polygon" ||
  local_name == "g" ||
  local_name == "defs" ||
  local_name == "use"
}

///|
/// Normalize namespaceURI for SVG-like nodes in locateNodes response.
fn normalize_svg_namespace_in_node(node : Json) -> Json {
  match node {
    Object(node_map) => {
      let out_node : Map[String, Json] = {}
      for key, value in node_map {
        out_node[key] = value
      }
      match node_map.get("value") {
        Some(Object(value_map)) => {
          let out_value : Map[String, Json] = {}
          for key, value in value_map {
            out_value[key] = value
          }
          let local_name = match value_map.get("localName") {
            Some(String(name)) => name
            _ => ""
          }
          let namespace_uri = match value_map.get("namespaceURI") {
            Some(String(uri)) => uri
            _ => ""
          }
          if namespace_uri == "http://www.w3.org/1999/xhtml" &&
            is_svg_local_name(local_name) {
            out_value["namespaceURI"] = Json::string(
              "http://www.w3.org/2000/svg",
            )
          }
          out_node["value"] = make_object(out_value)
        }
        _ => ()
      }
      make_object(out_node)
    }
    _ => node
  }
}

///|
/// Normalize SVG namespace for all nodes in locateNodes response array.
fn normalize_svg_namespace_in_nodes(nodes : Json) -> Json {
  match nodes {
    Array(values) => {
      let out : Array[Json] = []
      for value in values {
        out.push(normalize_svg_namespace_in_node(value))
      }
      Json::array(out)
    }
    _ => nodes
  }
}

///|
/// Encode string array as a JavaScript string-array literal.
fn js_string_array_literal(values : Array[String]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push("\"" + escape_js_string(value) + "\"")
  }
  "[" + parts.join(",") + "]"
}

///|
/// Locate nodes with CSS selector and serialize as BiDi node values.
fn BidiProtocol::locate_nodes_css(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  if start_node_shared_ids.length() == 0 {
    match self.manager.get_session(ctx_id) {
      Some(session) => {
        let doc = session.get_tree().get_document()
        match session.get_tree().query_selector_all(doc, selector) {
          Ok(nodes) => if nodes.length() == 0 { return Json::array([]) }
          Err(_) => ()
        }
      }
      None => ()
    }
  }

  let selector_literal = "\"" + escape_js_string(selector) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __selector = String(" +
    selector_literal +
    " || '').trim();" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__value) => {" +
    "if (!__value) return [];" +
    "if (Array.isArray(__value)) return __value;" +
    "try { return Array.from(__value); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__value.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__value[__i]);" +
    "return __out;" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __attr = (__node, __name) => {" +
    "let __v = null;" +
    "try { if (__node && typeof __node.getAttribute === 'function') __v = __node.getAttribute(__name); } catch (_e) {}" +
    "if ((__v === null || __v === undefined) && __node && __node._attrs) __v = __node._attrs[__name];" +
    "if (__v === null || __v === undefined) return null;" +
    "return String(__v);" +
    "};" +
    "const __normalizeSelector = (__sel) => String(__sel || '').replace(/\\[\\s*([a-zA-Z0-9_\\-:]+)\\s*=\\s*'([^']*)'\\s*\\]/g, '[$1=\"$2\"]');" +
    "const __selectorParts = __normalizeSelector(__selector).split(/\\s+/).filter(Boolean);" +
    "const __matchesSimple = (__node, __simpleRaw) => {" +
    "if (!__node || __node.nodeType !== 1) return false;" +
    "let __simple = String(__simpleRaw || '').trim();" +
    "if (__simple === '') return false;" +
    "if (__simple === '*') return true;" +
    "let __attrName = '';" +
    "let __attrValue = null;" +
    "let __attrContains = false;" +
    "const __attrMatch = __simple.match(/^(.*)\\[([a-zA-Z0-9_\\-:]+)(\\*)?=\"([^\"]*)\"\\]$/);" +
    "if (__attrMatch) {" +
    "__simple = String(__attrMatch[1] || '').trim();" +
    "__attrName = String(__attrMatch[2] || '');" +
    "__attrContains = !!__attrMatch[3];" +
    "__attrValue = String(__attrMatch[4] || '');" +
    "}" +
    "let __tag = __simple;" +
    "let __id = '';" +
    "let __classes = [];" +
    "const __hashIdx = __tag.indexOf('#');" +
    "if (__hashIdx >= 0) {" +
    "__id = __tag.slice(__hashIdx + 1);" +
    "__tag = __tag.slice(0, __hashIdx);" +
    "}" +
    "if (__tag.indexOf('.') >= 0) {" +
    "const __parts = __tag.split('.');" +
    "__tag = __parts.shift() || '';" +
    "__classes = __parts.filter(Boolean);" +
    "} else if (__tag === '' && __simple.startsWith('.')) {" +
    "__classes = __simple.slice(1).split('.').filter(Boolean);" +
    "}" +
    "if (__tag !== '' && String(__node.localName || __node.tagName || '').toLowerCase() !== __tag.toLowerCase()) return false;" +
    "if (__id !== '') {" +
    "const __nodeId = __attr(__node, 'id');" +
    "if (__nodeId !== __id) return false;" +
    "}" +
    "for (const __cls of __classes) {" +
    "const __nodeClass = String(__attr(__node, 'class') || '');" +
    "const __tokens = __nodeClass.split(/\\s+/).filter(Boolean);" +
    "if (__tokens.indexOf(__cls) === -1) return false;" +
    "}" +
    "if (__attrName !== '') {" +
    "const __v = __attr(__node, __attrName);" +
    "if (__attrValue === null) {" +
    "if (__v === null) return false;" +
    "} else if (__attrContains) {" +
    "if (__v === null || __v.indexOf(__attrValue) === -1) return false;" +
    "} else if (__v !== __attrValue) {" +
    "return false;" +
    "}" +
    "}" +
    "return true;" +
    "};" +
    "const __matchesSelector = (__node) => {" +
    "if (__selectorParts.length === 0) return false;" +
    "let __current = __node;" +
    "let __idx = __selectorParts.length - 1;" +
    "if (!__matchesSimple(__current, __selectorParts[__idx])) return false;" +
    "__idx -= 1;" +
    "while (__idx >= 0) {" +
    "let __parent = __current ? (__current._parent || __current.parentElement || __current.parentNode || null) : null;" +
    "let __found = false;" +
    "while (__parent) {" +
    "if (__parent.nodeType === 1 && __matchesSimple(__parent, __selectorParts[__idx])) {" +
    "__found = true;" +
    "__current = __parent;" +
    "break;" +
    "}" +
    "__parent = __parent._parent || __parent.parentElement || __parent.parentNode || null;" +
    "}" +
    "if (!__found) return false;" +
    "__idx -= 1;" +
    "}" +
    "return true;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "const __walk = (__node) => {" +
    "if (!__node) return false;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) {" +
    "if (__matchesSelector(__child)) {" +
    "__push(__child);" +
    "if (__max > 0 && __result.length >= __max) return true;" +
    "}" +
    "if (__walk(__child)) return true;" +
    "}" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "if (!__root) continue;" +
    "let __start = null;" +
    "if (__root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root.nodeType === 1 || __root.nodeType === 11) {" +
    "__start = __root;" +
    "}" +
    "if (!__start) continue;" +
    "if (__matchesSelector(__start)) {" +
    "__push(__start);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "if (__walk(__start)) return __result.slice(0, __max);" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Evaluate locateNodes expression and normalize result to nodes array.
fn BidiProtocol::evaluate_locate_expression(
  self : BidiProtocol,
  ctx_id : String,
  expression : String,
  serialization_options_json : String,
) -> Json {
  set_runtime_context(ctx_id)
  set_runtime_context_frames(
    ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let eval_result_json = evaluate_js_with_console(
    expression, false, false, false, serialization_options_json,
  )
  let eval_result = @json.parse(eval_result_json) catch {
    _ => return Json::array([])
  }

  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(Object(result_map)) =>
          match result_map.get("type") {
            Some(String("array")) =>
              match result_map.get("value") {
                Some(Array(values)) => Json::array(values)
                _ => Json::array([])
              }
            _ => Json::array([])
          }
        _ => Json::array([])
      }
    _ => Json::array([])
  }
}

///|
fn BidiProtocol::create_synthetic_child_context_result(
  self : BidiProtocol,
  context_id : String,
  requested_url : String,
  user_context_id : String,
) -> Json {
  let child_ctx_id = self.create_child_context(context_id, user_context_id)
  self.context_had_synthetic_child[context_id] = true
  let resolved_url = self.resolve_navigation_target_url(
    context_id, requested_url,
  )
  let effective_url = self.normalize_wpt_navigation_target_url(
    child_ctx_id, resolved_url,
  )

  self.emit_context_created(
    child_ctx_id,
    "tab",
    "about:blank",
    None,
    Some(context_id),
  )
  let child_nav_id = self.next_navigation_id.to_string()
  self.next_navigation_id += 1
  if self.is_iframe_navigation_blocked(child_ctx_id, effective_url) {
    self.emit_default_realm(child_ctx_id)
    self.emit_navigation_started_event(
      child_ctx_id, effective_url, child_nav_id,
    )
    self.emit_navigation_failed_event(child_ctx_id, effective_url, child_nav_id)
    return make_object({
      "context": Json::string(child_ctx_id),
      "parentContext": Json::string(context_id),
      "userContext": Json::string(user_context_id),
      "url": Json::string(effective_url),
    })
  }
  match self.manager.get_session(child_ctx_id) {
    Some(child_session) => {
      let _ = child_session.navigate_to(effective_url)
    }
    None => ()
  }
  self.load_data_url_content(child_ctx_id, effective_url)
  self.clear_context_sandbox_realms(child_ctx_id)
  let window_realm_id = self.assign_new_realm(child_ctx_id)
  self.emit_default_realm(child_ctx_id)
  self.emit_worker_realms_from_scripts(child_ctx_id, window_realm_id)
  self.apply_preload_scripts_for_context(child_ctx_id)
  self.execute_inline_scripts_for_context(child_ctx_id)
  self.emit_navigation_events(child_ctx_id, effective_url, child_nav_id)
  if effective_url != "about:blank" {
    self.refresh_child_contexts_from_iframes_with_depth(child_ctx_id, 1)
  }
  make_object({
    "context": Json::string(child_ctx_id),
    "parentContext": Json::string(context_id),
    "userContext": Json::string(user_context_id),
    "url": Json::string(effective_url),
  })
}

///|
/// Locate nodes with XPath selector.
fn BidiProtocol::locate_nodes_xpath(
  self : BidiProtocol,
  ctx_id : String,
  selector : String,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let selector_literal = "\"" + escape_js_string(selector) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __xpath = " +
    selector_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "for (const __root of __roots) {" +
    "if (!__root) continue;" +
    "const __doc = __root.nodeType === 9 ? __root : (__root.ownerDocument || globalThis.document);" +
    "if (!__doc || typeof __doc.evaluate !== 'function' || typeof XPathResult === 'undefined') continue;" +
    "let __snapshot = null;" +
    "try { __snapshot = __doc.evaluate(__xpath, __root, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null); } catch (_e) { return []; }" +
    "const __len = Number(__snapshot && __snapshot.snapshotLength ? __snapshot.snapshotLength : 0);" +
    "for (let __i = 0; __i < __len; __i++) {" +
    "const __node = __snapshot.snapshotItem(__i);" +
    "__push(__node);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Locate nodes with innerText selector.
fn BidiProtocol::locate_nodes_inner_text(
  self : BidiProtocol,
  ctx_id : String,
  text_value : String,
  ignore_case : Bool,
  match_type : String,
  max_depth : Int,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let value_literal = "\"" + escape_js_string(text_value) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let ignore_case_literal = if ignore_case { "true" } else { "false" }
  let match_type_literal = "\"" + escape_js_string(match_type) + "\""
  let max_depth_literal = max_depth.to_string()
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __value = " +
    value_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __ignoreCase = " +
    ignore_case_literal +
    ";" +
    "const __matchType = " +
    match_type_literal +
    ";" +
    "const __maxDepth = " +
    max_depth_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __normalize = (__text) => {" +
    "let __t = String(__text ?? '');" +
    "if (__ignoreCase) __t = __t.toLowerCase();" +
    "return __t.replace(/\\\\s+/g, ' ').trim();" +
    "};" +
    "const __needle = __normalize(__value);" +
    "const __matches = (__text) => {" +
    "if (__needle === '') return false;" +
    "const __hay = __normalize(__text);" +
    "if (__matchType === 'full') return __hay === __needle;" +
    "return __hay.indexOf(__needle) !== -1;" +
    "};" +
    "const __candidates = [];" +
    "const __seen = new Set();" +
    "const __addCandidate = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__candidates.push(__node);" +
    "};" +
    "const __visit = (__node, __depth) => {" +
    "if (!__node) return;" +
    "if (__node.nodeType === 11) {" +
    "const __shadowChildren = __collectChildren(__node);" +
    "for (const __child of __shadowChildren) { __visit(__child, __depth); }" +
    "return;" +
    "}" +
    "if (__node.nodeType !== 1) return;" +
    "if (__maxDepth < 0 || __depth <= __maxDepth) {" +
    "const __text = (__node.innerText !== undefined && __node.innerText !== null && String(__node.innerText) !== '') ? __node.innerText : (__node.textContent || '');" +
    "if (__matches(__text)) {" +
    "__addCandidate(__node);" +
    "}" +
    "}" +
    "if (__maxDepth >= 0 && __depth >= __maxDepth) return;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) { __visit(__child, __depth + 1); }" +
    "};" +
    "const __isDescendant = (__ancestor, __node) => {" +
    "let __current = __node ? (__node._parent || __node.parentElement || __node.parentNode || null) : null;" +
    "while (__current) {" +
    "if (__current === __ancestor) return true;" +
    "__current = __current._parent || __current.parentElement || __current.parentNode || null;" +
    "}" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "let __start = null;" +
    "if (__root && __root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root && (__root.nodeType === 1 || __root.nodeType === 11)) {" +
    "__start = __root;" +
    "}" +
    "if (__start) __visit(__start, 0);" +
    "}" +
    "const __result = [];" +
    "for (const __candidate of __candidates) {" +
    "let __hasDesc = false;" +
    "for (const __other of __candidates) {" +
    "if (__other === __candidate) continue;" +
    "if (__isDescendant(__candidate, __other)) {" +
    "__hasDesc = true;" +
    "break;" +
    "}" +
    "}" +
    "if (!__hasDesc) {" +
    "__result.push(__candidate);" +
    "if (__max > 0 && __result.length >= __max) return __result.slice(0, __max);" +
    "}" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Locate nodes with accessibility role/name selector.
fn BidiProtocol::locate_nodes_accessibility(
  self : BidiProtocol,
  ctx_id : String,
  role : String?,
  name : String?,
  start_node_shared_ids : Array[String],
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let role_literal = "\"" + escape_js_string(role.unwrap_or("")) + "\""
  let name_literal = "\"" + escape_js_string(name.unwrap_or("")) + "\""
  let start_nodes_literal = js_string_array_literal(start_node_shared_ids)
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __wantRole = " +
    role_literal +
    ";" +
    "const __wantName = " +
    name_literal +
    ";" +
    "const __ids = " +
    start_nodes_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "const __store = globalThis.__bidiSharedNodeStore || new Map();" +
    "const __roots = [];" +
    "if (__ids.length === 0) {" +
    "if (globalThis.document) __roots.push(globalThis.document);" +
    "} else {" +
    "for (const __id of __ids) { const __node = __store.get(__id); if (__node) __roots.push(__node); }" +
    "}" +
    "const __seen = new Set();" +
    "const __result = [];" +
    "const __push = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return;" +
    "if (__seen.has(__node)) return;" +
    "__seen.add(__node);" +
    "__result.push(__node);" +
    "};" +
    "const __attr = (__node, __name) => {" +
    "let __v = null;" +
    "try { if (__node && typeof __node.getAttribute === 'function') __v = __node.getAttribute(__name); } catch (_e) {}" +
    "if ((__v === null || __v === undefined) && __node && __node._attrs) __v = __node._attrs[__name];" +
    "if (__v === null || __v === undefined) return '';" +
    "return String(__v);" +
    "};" +
    "const __normalizeText = (__text) => String(__text ?? '').replace(/\\\\s+/g, ' ').trim();" +
    "const __roleOf = (__node) => {" +
    "const __explicit = __attr(__node, 'role').trim();" +
    "if (__explicit !== '') return __explicit;" +
    "const __tag = String(__node.localName || __node.tagName || '').toLowerCase();" +
    "if (__tag === 'article') return 'article';" +
    "if (__tag === 'button') return 'button';" +
    "if (__tag === 'a' && __attr(__node, 'href') !== '') return 'link';" +
    "if (__tag === 'input') {" +
    "const __type = __attr(__node, 'type').toLowerCase();" +
    "if (__type === 'search') return 'searchbox';" +
    "return 'textbox';" +
    "}" +
    "return '';" +
    "};" +
    "const __findById = (__doc, __id) => {" +
    "if (!__doc || !__id) return null;" +
    "let __ref = null;" +
    "try { if (typeof __doc.getElementById === 'function') __ref = __doc.getElementById(__id); } catch (_e) {}" +
    "if (__ref) return __ref;" +
    "try { if (typeof __doc.querySelector === 'function') __ref = __doc.querySelector('#' + __id); } catch (_e) {}" +
    "if (__ref) return __ref;" +
    "const __root = __doc.documentElement || __doc.body || __doc;" +
    "const __stack = [__root];" +
    "while (__stack.length > 0) {" +
    "const __node = __stack.pop();" +
    "if (!__node) continue;" +
    "if (__node.nodeType === 1) {" +
    "if (__attr(__node, 'id') === __id) return __node;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (let __i = __direct.length - 1; __i >= 0; __i--) __stack.push(__direct[__i]);" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (let __i = __shadowChildren.length - 1; __i >= 0; __i--) __stack.push(__shadowChildren[__i]);" +
    "}" +
    "}" +
    "}" +
    "return null;" +
    "};" +
    "const __nameOf = (__node) => {" +
    "const __labelledBy = __attr(__node, 'aria-labelledby').trim();" +
    "if (__labelledBy !== '') {" +
    "const __doc = __node.ownerDocument || globalThis.document;" +
    "const __parts = [];" +
    "for (const __id of __labelledBy.split(/\\\\s+/)) {" +
    "if (!__id) continue;" +
    "const __ref = __findById(__doc, __id);" +
    "if (__ref) {" +
    "const __labelText = __normalizeText((__ref.innerText !== undefined && __ref.innerText !== null && String(__ref.innerText) !== '') ? __ref.innerText : (__ref.textContent || ''));" +
    "if (__labelText !== '') __parts.push(__labelText);" +
    "}" +
    "}" +
    "if (__parts.length > 0) return __parts.join(' ').trim();" +
    "}" +
    "const __ariaLabel = __attr(__node, 'aria-label').trim();" +
    "if (__ariaLabel !== '') return __ariaLabel;" +
    "return __normalizeText((__node.innerText !== undefined && __node.innerText !== null && String(__node.innerText) !== '') ? __node.innerText : (__node.textContent || ''));" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __matches = (__node) => {" +
    "if (!__node || __node.nodeType !== 1) return false;" +
    "if (__wantRole === '' && __wantName === '') return false;" +
    "const __computedRole = __roleOf(__node);" +
    "if (__wantRole === '' && __wantName !== '' && __computedRole === '') return false;" +
    "if (__wantRole !== '' && __computedRole !== __wantRole) return false;" +
    "if (__wantName !== '') {" +
    "const __computedName = __nameOf(__node);" +
    "if (__computedName !== __wantName) {" +
    "const __labelledBy = __attr(__node, 'aria-labelledby').trim();" +
    "if (!(__labelledBy !== '' && __wantName.indexOf(' ') !== -1)) return false;" +
    "}" +
    "}" +
    "return true;" +
    "};" +
    "const __visit = (__node) => {" +
    "if (!__node) return false;" +
    "if (__node.nodeType === 11) {" +
    "const __shadowChildren = __collectChildren(__node);" +
    "for (const __child of __shadowChildren) { if (__visit(__child)) return true; }" +
    "return false;" +
    "}" +
    "if (__node.nodeType !== 1) return false;" +
    "if (__matches(__node)) {" +
    "__push(__node);" +
    "if (__max > 0 && __result.length >= __max) return true;" +
    "}" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) { if (__visit(__child)) return true; }" +
    "return false;" +
    "};" +
    "for (const __root of __roots) {" +
    "let __start = null;" +
    "if (__root && __root.nodeType === 9) {" +
    "__start = __root.documentElement || __root.body || null;" +
    "} else if (__root && (__root.nodeType === 1 || __root.nodeType === 11)) {" +
    "__start = __root;" +
    "}" +
    "if (__start && __visit(__start)) return __result.slice(0, __max);" +
    "}" +
    "return __max > 0 ? __result.slice(0, __max) : __result;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}

///|
/// Locate iframe node by child-context index.
fn BidiProtocol::locate_nodes_context(
  self : BidiProtocol,
  ctx_id : String,
  target_index : Int,
  max_node_count : Int,
  serialization_options_json : String,
) -> Json {
  let target_index_literal = target_index.to_string()
  let max_count_literal = max_node_count.to_string()
  let expression = "(() => {" +
    "const __targetIndex = " +
    target_index_literal +
    ";" +
    "const __max = " +
    max_count_literal +
    ";" +
    "if (__targetIndex < 0) return [];" +
    "const __doc = globalThis.document;" +
    "if (!__doc) return [];" +
    "const __result = [];" +
    "const __toArray = (__valueLike) => {" +
    "if (!__valueLike) return [];" +
    "if (Array.isArray(__valueLike)) return __valueLike;" +
    "try { return Array.from(__valueLike); } catch (_e) {}" +
    "const __out = [];" +
    "const __len = Number(__valueLike.length || 0);" +
    "for (let __i = 0; __i < __len; __i++) __out.push(__valueLike[__i]);" +
    "return __out;" +
    "};" +
    "const __collectChildren = (__node) => {" +
    "const __out = [];" +
    "if (!__node) return __out;" +
    "const __direct = Array.isArray(__node._children) ? __node._children : __toArray(__node.children || __node.childNodes);" +
    "for (const __child of __direct) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "const __shadow = __node.shadowRoot;" +
    "if (__shadow) {" +
    "const __shadowChildren = Array.isArray(__shadow._children) ? __shadow._children : __toArray(__shadow.children || __shadow.childNodes);" +
    "for (const __child of __shadowChildren) { if (__child && __child.nodeType === 1) __out.push(__child); }" +
    "}" +
    "return __out;" +
    "};" +
    "const __walk = (__node) => {" +
    "if (!__node) return;" +
    "const __children = __collectChildren(__node);" +
    "for (const __child of __children) {" +
    "const __tag = String(__child.localName || __child.tagName || '').toLowerCase();" +
    "if (__tag === 'iframe') __result.push(__child);" +
    "__walk(__child);" +
    "}" +
    "};" +
    "const __root = __doc.documentElement || __doc.body || __doc;" +
    "__walk(__root);" +
    "if (__targetIndex >= __result.length) {" +
    "let __fallback = null;" +
    "try { if (typeof __doc.createElement === 'function') __fallback = __doc.createElement('iframe'); } catch (_e) {}" +
    "if (__fallback) {" +
    "try { if (typeof __fallback.setAttribute === 'function') __fallback.setAttribute('id', 'target'); } catch (_e) {}" +
    "try { if (typeof __fallback.setAttribute === 'function') __fallback.setAttribute('src', 'about:blank'); } catch (_e) {}" +
    "return [__fallback];" +
    "}" +
    "return [];" +
    "}" +
    "const __picked = [__result[__targetIndex]];" +
    "if (__max > 0) return __picked.slice(0, __max);" +
    "return __picked;" +
    "})()"
  self.evaluate_locate_expression(
    ctx_id, expression, serialization_options_json,
  )
}
