///|
/// BiDi handler for browsingContext.getComputedStyles
fn BidiProtocol::handle_get_computed_styles(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_get_computed_styles(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::handle_get_all_computed_styles(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_get_all_computed_styles(request_id, params) {
    Some(result) => self.send_success(request_id, Some(result))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_get_computed_styles(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
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

  let _session = match self.manager.get_session(ctx_id) {
    Some(session) => session
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
      return None
    }
  }

  let mode = match params.get("mode") {
    None => "live-inline"
    Some(String(value)) =>
      match value {
        "live-inline" | "html-inline" => value
        _ => {
          self.send_error(
            request_id, "invalid argument", "mode must be 'live-inline' or 'html-inline'",
          )
          return None
        }
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "mode must be a string")
      return None
    }
  }

  let properties : Array[String] = match params.get("properties") {
    None => []
    Some(Array(items)) => {
      let props : Array[String] = []
      for item in items {
        match item {
          String(value) => props.push(value)
          _ => ()
        }
      }
      props
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "properties must be an array of strings",
      )
      return None
    }
  }

  let (html, target_selector) = match
    self.resolve_get_computed_styles_target(request_id, params, mode) {
    Some(target) => target
    None => return None
  }
  let result = @css.discover_computed_styles_with_state_names(
    html,
    target_selector,
    [],
    properties,
  )
  let styles_json : Map[String, Json] = {}
  result.normal.each(fn(prop, val) { styles_json[prop] = Json::string(val) })
  let out : Map[String, Json] = {}
  out["styles"] = make_object(styles_json)
  Some(make_object(out))
}

///|
fn BidiProtocol::resolve_get_all_computed_styles(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
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

  let _session = match self.manager.get_session(ctx_id) {
    Some(session) => session
    None => {
      self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
      return None
    }
  }

  let mode = match params.get("mode") {
    None => "live-inline"
    Some(String(value)) =>
      match value {
        "live-inline" | "html-inline" => value
        _ => {
          self.send_error(
            request_id, "invalid argument", "mode must be 'live-inline' or 'html-inline'",
          )
          return None
        }
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "mode must be a string")
      return None
    }
  }

  let properties : Array[String] = match params.get("properties") {
    None => []
    Some(Array(items)) => {
      let props : Array[String] = []
      for item in items {
        match item {
          String(value) => props.push(value)
          _ => ()
        }
      }
      props
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "properties must be an array of strings",
      )
      return None
    }
  }

  let html = responsive_breakpoint_source_html(mode)
  let styles = @css.discover_all_computed_styles(html, properties)
  let styles_json : Map[String, Json] = {}
  styles.each(fn(selector, style_map) {
    let entry_json : Map[String, Json] = {}
    style_map.each(fn(prop, value) { entry_json[prop] = Json::string(value) })
    styles_json[selector] = make_object(entry_json)
  })
  let out : Map[String, Json] = {}
  out["styles"] = make_object(styles_json)
  Some(make_object(out))
}

///|
fn BidiProtocol::resolve_get_computed_styles_target(
  self : BidiProtocol,
  request_id : Int,
  params : Map[String, Json],
  mode : String,
) -> (String, String)? {
  match params.get("selector") {
    Some(String(selector)) =>
      return Some((responsive_breakpoint_source_html(mode), selector))
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "selector must be a string",
      )
      return None
    }
    None => ()
  }

  match params.get("sharedId") {
    Some(String(shared_id)) => {
      match self.validate_get_computed_styles_shared_id(request_id, shared_id) {
        Some(_) => ()
        None => return None
      }
      return Some(
        (
          responsive_breakpoint_source_html_with_shared_node_marker(shared_id),
          computed_styles_target_marker_selector(),
        ),
      )
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "sharedId must be a string",
      )
      return None
    }
    None => ()
  }

  match params.get("shared_id") {
    Some(String(shared_id)) => {
      match self.validate_get_computed_styles_shared_id(request_id, shared_id) {
        Some(_) => ()
        None => return None
      }
      return Some(
        (
          responsive_breakpoint_source_html_with_shared_node_marker(shared_id),
          computed_styles_target_marker_selector(),
        ),
      )
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "shared_id must be a string",
      )
      return None
    }
    None => ()
  }

  match params.get("element") {
    Some(Object(element)) => {
      let shared_id = match
        self.resolve_get_computed_styles_element_shared_id(request_id, element) {
        Some(shared_id) => shared_id
        None => return None
      }
      return Some(
        (
          responsive_breakpoint_source_html_with_shared_node_marker(shared_id),
          computed_styles_target_marker_selector(),
        ),
      )
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "element must be a node reference",
      )
      return None
    }
    None => ()
  }

  match params.get("elementId") {
    Some(String(element_id)) =>
      return Some(
        (
          responsive_breakpoint_source_html_with_element_id_marker(element_id),
          computed_styles_target_marker_selector(),
        ),
      )
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "elementId must be a string",
      )
      return None
    }
    None => ()
  }

  match params.get("element_id") {
    Some(String(element_id)) =>
      return Some(
        (
          responsive_breakpoint_source_html_with_element_id_marker(element_id),
          computed_styles_target_marker_selector(),
        ),
      )
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "element_id must be a string",
      )
      return None
    }
    None => ()
  }

  self.send_error(
    request_id, "invalid argument", "Missing selector, sharedId, element, or elementId",
  )
  None
}

///|
fn BidiProtocol::resolve_get_computed_styles_element_shared_id(
  self : BidiProtocol,
  request_id : Int,
  element : Map[String, Json],
) -> String? {
  let value_map = match element.get("value") {
    Some(Object(value_map)) => Some(value_map)
    _ => None
  }
  let shared_id = match element.get("sharedId") {
    Some(String(shared_id)) => Some(shared_id)
    _ =>
      match value_map {
        Some(value_map) =>
          match value_map.get("sharedId") {
            Some(String(shared_id)) => Some(shared_id)
            _ => None
          }
        None => None
      }
  }
  let shared_id = match shared_id {
    Some(shared_id) => shared_id
    None => {
      self.send_error(
        request_id, "invalid argument", "element.sharedId must be a string",
      )
      return None
    }
  }
  match value_map {
    Some(value_map) =>
      match value_map.get("nodeType") {
        Some(Number(node_type, ..)) if node_type != 1.0 => {
          self.send_error(request_id, "no such element", "No such element")
          return None
        }
        _ => ()
      }
    None => ()
  }
  match self.validate_get_computed_styles_shared_id(request_id, shared_id) {
    Some(_) => ()
    None => return None
  }
  Some(shared_id)
}

///|
fn BidiProtocol::validate_get_computed_styles_shared_id(
  self : BidiProtocol,
  request_id : Int,
  shared_id : String,
) -> Unit? {
  if !has_runtime_shared_node(shared_id) {
    self.send_error(
      request_id,
      "no such node",
      "Unknown sharedId: " + shared_id,
    )
    return None
  }
  if !runtime_shared_node_is_element(shared_id) {
    self.send_error(request_id, "no such element", "No such element")
    return None
  }
  Some(())
}
