///|
/// Send script.evaluate success response with `undefined` result.
fn BidiProtocol::send_script_undefined_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
) -> Unit {
  self.send_script_remote_value_result(
    request_id,
    realm_id,
    make_object({ "type": Json::string("undefined") }),
  )
}

///|
fn BidiProtocol::send_script_remote_value_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  remote_value : Json,
) -> Unit {
  let result = make_object({
    "realm": Json::string(realm_id),
    "result": remote_value,
  })
  self.send_success(request_id, Some(result))
}

///|
fn BidiProtocol::send_script_synthetic_value_response(
  self : BidiProtocol,
  request_id : Int,
  remote_value : Json,
) -> Unit {
  let payload_value = match remote_value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("string")), Some(value)) => value
        (Some(String("number")), Some(value)) => value
        (Some(String("boolean")), Some(value)) => value
        _ => remote_value
      }
    _ => remote_value
  }
  let result = make_object({
    "id": Json::number(request_id.to_double()),
    "type": Json::string("success"),
    "value": payload_value,
  })
  self.send_raw(result.stringify())
}

///|
fn BidiProtocol::send_script_remote_value_response(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  remote_value : Json,
  unwrap_result : Bool,
) -> Unit {
  if unwrap_result {
    self.send_success(request_id, Some(remote_value))
  } else {
    self.send_script_remote_value_result(request_id, realm_id, remote_value)
  }
}

///|
fn BidiProtocol::send_script_exception_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  eval_result : Json,
) -> Unit {
  let exc_details = get_field(eval_result, "exceptionDetails").unwrap_or(
    make_object({}),
  )
  let result = make_object({
    "realm": Json::string(realm_id),
    "exceptionDetails": exc_details,
  })
  self.send_success(request_id, Some(result))
}

///|
fn BidiProtocol::send_script_undefined_response(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  unwrap_result : Bool,
) -> Unit {
  if unwrap_result {
    self.send_success(
      request_id,
      Some(make_object({ "type": Json::string("undefined") })),
    )
  } else {
    self.send_script_undefined_result(request_id, realm_id)
  }
}

///|
fn BidiProtocol::send_script_eval_result_mode(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  eval_result : Json,
  unwrap_result : Bool,
) -> Unit {
  match get_string_field(eval_result, "type") {
    Some("success") => {
      let bidi_value = get_field(eval_result, "result").unwrap_or(
        make_object({ "type": Json::string("undefined") }),
      )
      self.send_script_remote_value_response(
        request_id, realm_id, bidi_value, unwrap_result,
      )
    }
    Some("exception") =>
      self.send_script_exception_result(request_id, realm_id, eval_result)
    _ =>
      self.send_script_undefined_response(request_id, realm_id, unwrap_result)
  }
}

///|
/// Resolve unhandled prompt handler for context/prompt type.
fn BidiProtocol::resolve_unhandled_prompt_handler(
  self : BidiProtocol,
  ctx_id : String,
  prompt_type : String,
) -> String {
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  let behavior_key = if prompt_type == "beforeunload" {
    "beforeUnload"
  } else {
    prompt_type
  }
  match self.user_context_prompt_behavior.get(user_context_id) {
    Some(Object(behavior)) =>
      match behavior.get(behavior_key) {
        Some(String(handler)) => handler
        _ =>
          match behavior.get("default") {
            Some(String(default_handler)) => default_handler
            _ => if prompt_type == "file" { "ignore" } else { "dismiss" }
          }
      }
    _ => if prompt_type == "file" { "ignore" } else { "dismiss" }
  }
}

///|
/// Resolve effective download behavior for a context.
fn BidiProtocol::resolve_download_behavior(
  self : BidiProtocol,
  ctx_id : String,
) -> Json? {
  let user_context_id = self.context_user_context
    .get(ctx_id)
    .unwrap_or("default")
  match self.user_context_download_behavior.get(user_context_id) {
    Some(behavior) => Some(behavior)
    None => self.global_download_behavior
  }
}

///|
/// Extract prompt message argument from expression/source.
fn extract_prompt_message_from_source(
  source : String,
  prompt_type : String,
) -> String {
  let marker_candidates : Array[String] = []
  match prompt_type {
    "alert" => {
      marker_candidates.push("window.alert(")
      marker_candidates.push("alert(")
    }
    "confirm" => {
      marker_candidates.push("window.confirm(")
      marker_candidates.push("confirm(")
    }
    "prompt" => {
      marker_candidates.push("window.prompt(")
      marker_candidates.push("prompt(")
    }
    _ => ()
  }
  for marker in marker_candidates {
    match extract_quoted_after_marker(source, marker) {
      Some(message) => return message
      None => ()
    }
  }
  ""
}

///|
/// Extract prompt defaultValue argument when present.
fn extract_prompt_default_value_from_source(source : String) -> String? {
  let marker_candidates : Array[String] = []
  marker_candidates.push("window.prompt(")
  marker_candidates.push("prompt(")
  for marker in marker_candidates {
    match extract_second_quoted_after_marker(source, marker) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
/// Detect prompt-like inline scripts on navigated data URLs.
fn BidiProtocol::register_navigation_prompt_from_url(
  self : BidiProtocol,
  ctx_id : String,
  url : String,
) -> Unit {
  if !url.has_prefix("data:") {
    return
  }
  match parse_data_url(url) {
    Some((_content_type, content)) => {
      let mut prompt_type : String? = None
      let mut result_var : String? = None
      if content.contains("window.alert(") {
        prompt_type = Some("alert")
      } else if content.contains("window.confirm(") {
        prompt_type = Some("confirm")
        if content.contains("window.response = window.confirm(") {
          result_var = Some("window.response")
        }
      } else if content.contains("window.prompt(") {
        prompt_type = Some("prompt")
      }
      match prompt_type {
        Some(kind) => {
          let handler = self.resolve_unhandled_prompt_handler(ctx_id, kind)
          let message = extract_prompt_message_from_source(content, kind)
          let default_value = if kind == "prompt" {
            Some(
              extract_prompt_default_value_from_source(content).unwrap_or(""),
            )
          } else {
            None
          }
          self.clear_pending_prompt_state(ctx_id)
          self.pending_prompt_type[ctx_id] = kind
          match result_var {
            Some(name) => self.pending_prompt_result_var[ctx_id] = name
            None => ()
          }
          self.emit_user_prompt_opened(
            ctx_id, kind, handler, message, default_value,
          )
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
/// Build script.evaluate result payload for a handled user prompt.
fn BidiProtocol::send_script_prompt_result(
  self : BidiProtocol,
  request_id : Int,
  realm_id : String,
  prompt_type : String,
  accepted : Bool,
  user_text : String?,
  unwrap_result : Bool,
) -> Unit {
  let remote_value = match prompt_type {
    "confirm" =>
      make_object({
        "type": Json::string("boolean"),
        "value": Json::boolean(accepted),
      })
    "prompt" =>
      if accepted {
        make_object({
          "type": Json::string("string"),
          "value": Json::string(user_text.unwrap_or("")),
        })
      } else {
        make_object({ "type": Json::string("null") })
      }
    _ => make_object({ "type": Json::string("undefined") })
  }
  self.send_script_remote_value_response(
    request_id, realm_id, remote_value, unwrap_result,
  )
}

///|
/// Compatibility facade for the canonical remote_value_as_bool in @protocol.
fn remote_value_as_bool(value : Json) -> Bool? {
  @protocol.remote_value_as_bool(value)
}

///|
/// Compatibility facade for the canonical remote_value_as_string in @protocol.
fn remote_value_as_string(value : Json) -> String? {
  @protocol.remote_value_as_string(value)
}

///|
/// Compatibility facade for the canonical remote_value_as_number in @protocol.
fn remote_value_as_number(value : Json) -> Double? {
  @protocol.remote_value_as_number(value)
}

///|
fn simplify_node_remote_value(value : Json) -> Json? {
  match value {
    Object(map) =>
      match map.get("sharedId") {
        Some(String(shared_id)) =>
          Some(make_object({ "sharedId": Json::string(shared_id) }))
        _ => None
      }
    _ => None
  }
}
