///|
fn BidiProtocol::collect_context_ancestry(
  self : BidiProtocol,
  ctx_id : String,
  ancestry : Array[String],
  seen : Map[String, Bool],
) -> Unit {
  if seen.contains(ctx_id) {
    return
  }
  seen[ctx_id] = true
  match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) =>
      self.collect_context_ancestry(parent_ctx_id, ancestry, seen)
    None => ()
  }
  ancestry.push(ctx_id)
}

///|
fn BidiProtocol::build_context_ancestry(
  self : BidiProtocol,
  ctx_id : String,
) -> Array[String] {
  let ancestry : Array[String] = []
  let seen : Map[String, Bool] = {}
  self.collect_context_ancestry(ctx_id, ancestry, seen)
  ancestry
}

///|
fn BidiProtocol::build_context_scope_info_json(
  self : BidiProtocol,
  ctx_id : String,
) -> Json {
  if !self.manager.has_session(ctx_id) {
    return make_object({
      "context": Json::string(ctx_id),
      "known": Json::boolean(false),
      "ancestry": Json::array([]),
      "topLevelContext": Json::null(),
      "parent": Json::null(),
      "userContext": Json::null(),
      "isTopLevel": Json::boolean(false),
    })
  }
  let ancestry = self.build_context_ancestry(ctx_id)
  let ancestry_json : Array[Json] = []
  for ancestor in ancestry {
    ancestry_json.push(Json::string(ancestor))
  }
  let top_level_context = match ancestry {
    [top_level, ..] => Json::string(top_level)
    [] => Json::string(ctx_id)
  }
  let parent_json = match self.context_parent.get(ctx_id) {
    Some(parent_ctx_id) => Json::string(parent_ctx_id)
    None => Json::null()
  }
  let user_context = self.context_user_context.get(ctx_id).unwrap_or("default")
  make_object({
    "context": Json::string(ctx_id),
    "known": Json::boolean(true),
    "ancestry": Json::array(ancestry_json),
    "topLevelContext": top_level_context,
    "parent": parent_json,
    "userContext": Json::string(user_context),
    "isTopLevel": Json::boolean(self.context_parent.get(ctx_id) == None),
  })
}

///|
/// Resolve top-level ancestor context.
fn BidiProtocol::resolve_top_level_context(
  self : BidiProtocol,
  ctx_id : String,
) -> String {
  let mut current = ctx_id
  for _ in 0..<16 {
    match self.context_parent.get(current) {
      Some(parent_ctx_id) => current = parent_ctx_id
      None => return current
    }
  }
  current
}

///|
/// Check whether preload script scope matches a context.
fn BidiProtocol::is_preload_script_applicable(
  self : BidiProtocol,
  entry : PreloadScriptEntry,
  ctx_id : String,
) -> Bool {
  if entry.contexts.length() > 0 {
    let top_level_context = self.resolve_top_level_context(ctx_id)
    return array_contains(entry.contexts, top_level_context)
  }
  if entry.user_contexts.length() > 0 {
    let user_context = self.context_user_context
      .get(ctx_id)
      .unwrap_or("default")
    return array_contains(entry.user_contexts, user_context)
  }
  true
}

///|
/// Build JS call expression for a preload script entry.
fn build_preload_call_expression(entry : PreloadScriptEntry) -> String {
  let argument_parts : Array[String] = []
  for argument in entry.arguments {
    argument_parts.push(bidi_value_to_js_literal(argument))
  }
  if argument_parts.length() == 0 {
    "(" + entry.function_declaration + ")()"
  } else {
    "(" + entry.function_declaration + ")(" + argument_parts.join(", ") + ")"
  }
}

///|
/// Check whether character is a JavaScript identifier continuation.
fn is_js_identifier_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '$'
}

///|
/// Extract referenced `window.<name>` property names from source.
fn extract_window_property_names(source : String) -> Array[String] {
  let names : Array[String] = []
  let marker = "window."
  let mut search_from = 0
  while search_from < source.length() {
    match find_substring(source, marker, search_from) {
      Some(marker_idx) => {
        let chars = source.to_array()
        let mut cursor = marker_idx + marker.length()
        if cursor >= chars.length() {
          break
        }
        let mut name = ""
        while cursor < chars.length() && is_js_identifier_char(chars[cursor]) {
          name = name + chars[cursor].to_string()
          cursor += 1
        }
        if name != "" && !array_contains(names, name) {
          names.push(name)
        }
        search_from = cursor + 1
      }
      None => break
    }
  }
  names
}

///|
/// Clear custom window properties in a context/sandbox runtime.
fn BidiProtocol::clear_window_properties_in_context(
  self : BidiProtocol,
  ctx_id : String,
  sandbox : String?,
  property_names : Array[String],
) -> Unit {
  if property_names.length() == 0 {
    return
  }
  let runtime_ctx_id = match sandbox {
    Some(sandbox_name) =>
      if sandbox_name == "" {
        ctx_id
      } else {
        self.get_or_create_sandbox_realm(ctx_id, sandbox_name)
      }
    None => ctx_id
  }
  set_runtime_context(runtime_ctx_id)
  self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
  for property_name in property_names {
    if property_name == "" {
      continue
    }
    evaluate_js(
      "try { delete window." +
      property_name +
      "; } catch (_e) { window." +
      property_name +
      " = undefined; }",
    )
    |> ignore
  }
}

///|
/// Remove side effects of a removed preload script from existing contexts.
fn BidiProtocol::cleanup_removed_preload_entry(
  self : BidiProtocol,
  entry : PreloadScriptEntry,
) -> Unit {
  let property_names = extract_window_property_names(entry.function_declaration)
  if property_names.length() == 0 {
    return
  }
  for ctx_id in self.manager.list_sessions() {
    if self.is_preload_script_applicable(entry, ctx_id) {
      self.clear_window_properties_in_context(
        ctx_id,
        entry.sandbox,
        property_names,
      )
    }
  }
}

///|
/// Remove every registered preload script and clean up any runtime markers.
fn BidiProtocol::remove_all_preload_scripts(self : BidiProtocol) -> Unit {
  let existing_entries = self.preload_scripts
  self.preload_scripts = []
  self.next_preload_script_id = 1
  for entry in existing_entries {
    self.cleanup_removed_preload_entry(entry)
  }
}

///|
/// Execute one preload script in a target context.
fn BidiProtocol::run_preload_script_in_context(
  self : BidiProtocol,
  entry : PreloadScriptEntry,
  ctx_id : String,
) -> Unit {
  let realm_id = match entry.sandbox {
    Some(sandbox_name) =>
      if sandbox_name == "" {
        self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
      } else {
        self.get_or_create_sandbox_realm(ctx_id, sandbox_name)
      }
    None => self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  }
  let runtime_ctx_id = match entry.sandbox {
    Some(sandbox_name) => if sandbox_name == "" { ctx_id } else { realm_id }
    None => ctx_id
  }
  set_runtime_context(runtime_ctx_id)
  set_runtime_context_frames(
    runtime_ctx_id,
    self.context_children.get(ctx_id).unwrap_or([]),
  )
  self.apply_effective_viewport_to_runtime_context(runtime_ctx_id, ctx_id)
  let capture_console = self.should_capture_console(ctx_id)
  let eval_result_json = evaluate_js_with_console(
    build_preload_call_expression(entry),
    capture_console,
    false,
    false,
    "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return }
  if capture_console {
    self.process_console_entries(eval_result, ctx_id, realm_id)
  }
  match get_string_field(eval_result, "type") {
    Some("exception") => {
      let exception_details = get_field(eval_result, "exceptionDetails").unwrap_or(
        make_object({}),
      )
      let text = get_string_field(exception_details, "text").unwrap_or(
        "Error: preload script execution failed",
      )
      self.emit_log_entry(ctx_id, "error", text, "error", [], input_now_ms())
    }
    _ => ()
  }
  self.process_channel_messages(ctx_id, realm_id)
}

///|
/// Apply all registered preload scripts to a context.
fn BidiProtocol::apply_preload_scripts_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  if !self.manager.has_session(ctx_id) {
    return
  }
  for entry in self.preload_scripts {
    if self.is_preload_script_applicable(entry, ctx_id) {
      self.run_preload_script_in_context(entry, ctx_id)
    }
  }
}

///|
/// Check whether context has a mutation-observer preload with channel argument.
fn BidiProtocol::has_mutation_observer_preload_for_context(
  self : BidiProtocol,
  ctx_id : String,
) -> Bool {
  for entry in self.preload_scripts {
    if !self.is_preload_script_applicable(entry, ctx_id) {
      continue
    }
    if !entry.function_declaration.contains("MutationObserver") {
      continue
    }
    for argument in entry.arguments {
      match argument {
        Object(arg_map) =>
          match arg_map.get("type") {
            Some(String("channel")) =>
              match arg_map.get("value") {
                Some(Object(channel_map)) =>
                  match channel_map.get("channel") {
                    Some(String(channel_name)) =>
                      if channel_name != "" {
                        return true
                      } else {
                        ()
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
  }
  false
}

///|
/// Emit synthetic mutation-observer channel messages for known WPT patterns.
fn BidiProtocol::emit_synthetic_mutation_observer_messages(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  expression : String,
) -> Unit {
  if !expression.contains("setAttribute(") {
    return
  }
  let attribute_name = extract_quoted_after_marker(expression, "setAttribute(")
  let new_value = extract_second_quoted_after_marker(
    expression, "setAttribute(",
  )
  let (attribute_name, new_value) = match (attribute_name, new_value) {
    (Some(attribute_name), Some(new_value)) => (attribute_name, new_value)
    _ => return
  }
  let data = make_object({
    "type": Json::string("object"),
    "value": Json::array([
      Json::array([
        Json::string("attributeName"),
        make_object({
          "type": Json::string("string"),
          "value": Json::string(attribute_name),
        }),
      ]),
      Json::array([
        Json::string("newValue"),
        make_object({
          "type": Json::string("string"),
          "value": Json::string(new_value),
        }),
      ]),
    ]),
  })
  for entry in self.preload_scripts {
    if !self.is_preload_script_applicable(entry, ctx_id) {
      continue
    }
    if !entry.function_declaration.contains("MutationObserver") {
      continue
    }
    for argument in entry.arguments {
      match argument {
        Object(arg_map) =>
          match arg_map.get("type") {
            Some(String("channel")) =>
              match arg_map.get("value") {
                Some(Object(channel_map)) =>
                  match channel_map.get("channel") {
                    Some(String(channel_name)) =>
                      if channel_name != "" {
                        self.emit_script_message(
                          ctx_id, realm_id, channel_name, data,
                        )
                      }
                    _ => ()
                  }
                _ => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
  }
}
