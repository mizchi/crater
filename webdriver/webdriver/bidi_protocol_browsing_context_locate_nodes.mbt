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
