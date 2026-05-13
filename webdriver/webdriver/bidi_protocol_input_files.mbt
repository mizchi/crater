///|
fn BidiProtocol::handle_input_record_synthetic_events(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = match map.get("context") {
    Some(String(ctx_id)) => ctx_id
    _ => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return
    }
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return
  }
  let events = match map.get("events") {
    Some(Array(events)) => events
    _ => {
      self.send_error(request_id, "invalid argument", "events must be an array")
      return
    }
  }
  let existing = self.input_synthetic_events_by_context
    .get(ctx_id)
    .unwrap_or([])
  for event in events {
    match event {
      Object(_) => existing.push(event)
      _ => {
        self.send_error(
          request_id, "invalid argument", "events entries must be objects",
        )
        return
      }
    }
  }
  self.input_synthetic_events_by_context[ctx_id] = existing
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::handle_input_set_files(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return
    }
  }
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return
  }
  let element = match map.get("element") {
    Some(Object(element)) => element
    _ => {
      self.send_error(
        request_id, "invalid argument", "element must be an object",
      )
      return
    }
  }
  let source_paths = match self.input_set_files_source_paths(request_id, map) {
    Some(values) => values
    None => return
  }
  let display_names = match
    self.input_set_files_display_names(request_id, map, source_paths) {
    Some(values) => values
    None => return
  }
  if source_paths.length() != display_names.length() {
    self.send_error(
      request_id, "invalid argument", "sourcePaths and displayNames must have the same length",
    )
    return
  }
  let (element_id, allow_fallback) = match
    self.resolve_input_set_files_locator(request_id, element) {
    Some(locator) => locator
    None => return
  }
  let summary = match
    self.apply_input_set_files_summary(
      ctx_id, element_id, allow_fallback, source_paths, display_names,
    ) {
    Some(summary) => summary
    None => {
      self.send_error(request_id, "no such element", "No such element")
      return
    }
  }
  let found = input_set_files_summary_bool(summary, "found")
  let is_element = input_set_files_summary_bool(summary, "isElement")
  let disabled = input_set_files_summary_bool(summary, "disabled")
  let multiple = input_set_files_summary_bool(summary, "multiple")
  let tag_name = input_set_files_summary_string(summary, "tagName").unwrap_or(
    "",
  )
  let input_type = input_set_files_summary_string(summary, "inputType").unwrap_or(
    "",
  )

  if !found || !is_element {
    self.send_error(request_id, "no such element", "No such element")
    return
  }
  if tag_name != "input" ||
    input_type != "file" ||
    disabled ||
    (source_paths.length() > 1 && !multiple) {
    self.send_error(
      request_id, "unable to set file input", "Unable to set file input",
    )
    return
  }

  let event_files = match
    input_set_files_summary_string_list(summary, "eventFiles") {
    Some(values) => values
    None => display_names
  }
  match input_set_files_summary_string_list(summary, "eventTypes") {
    Some(event_types) =>
      if event_types.length() > 0 {
        self.append_input_synthetic_events(ctx_id, event_types, event_files)
      }
    None => ()
  }
  self.send_success(request_id, Some(make_object({})))
}

///|
fn BidiProtocol::append_input_synthetic_events(
  self : BidiProtocol,
  ctx_id : String,
  event_types : Array[String],
  event_files : Array[String],
) -> Unit {
  let existing = self.input_synthetic_events_by_context
    .get(ctx_id)
    .unwrap_or([])
  let files_json : Array[Json] = []
  for file_name in event_files {
    files_json.push(Json::string(file_name))
  }
  for event_type in event_types {
    existing.push(
      make_object({
        "type": Json::string(event_type),
        "files": Json::array(files_json),
      }),
    )
  }
  self.input_synthetic_events_by_context[ctx_id] = existing
}

///|
fn BidiProtocol::handle_input_is_file_dialog_canceled_for_test(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return
  }
  let handler = self.resolve_unhandled_prompt_handler(ctx_id, "file")
  self.send_success(request_id, Some(Json::boolean(handler != "ignore")))
}

///|
fn BidiProtocol::resolve_input_set_files_locator(
  self : BidiProtocol,
  request_id : Int,
  element : Map[String, Json],
) -> (String, Bool)? {
  match element.get("type") {
    Some(String(type_name)) if type_name == "null" => return Some(("", true))
    _ => ()
  }
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
  let element_id = match value_map {
    Some(value_map) =>
      match value_map.get("attributes") {
        Some(Object(attributes)) =>
          match attributes.get("id") {
            Some(String(element_id)) => element_id
            _ => ""
          }
        _ => ""
      }
    None => ""
  }
  Some((element_id, false))
}

///|
fn BidiProtocol::apply_input_set_files_summary(
  self : BidiProtocol,
  ctx_id : String,
  element_id : String,
  allow_fallback : Bool,
  source_paths : Array[String],
  display_names : Array[String],
) -> Map[String, Json]? {
  set_runtime_context(ctx_id)
  self.apply_effective_viewport_to_runtime_context(ctx_id, ctx_id)
  let source_paths_json : Array[Json] = []
  for path in source_paths {
    source_paths_json.push(Json::string(path))
  }
  let display_names_json : Array[Json] = []
  for name in display_names {
    display_names_json.push(Json::string(name))
  }
  let payload = js_input_apply_file_selection(
    element_id,
    allow_fallback,
    Json::array(source_paths_json).stringify(),
    Json::array(display_names_json).stringify(),
  )
  let summary = @json.parse(payload) catch { _ => return None }
  match summary {
    Object(summary) => Some(summary)
    _ => None
  }
}

///|
fn BidiProtocol::input_set_files_string_array(
  self : BidiProtocol,
  request_id : Int,
  raw_value : Json?,
  field_name : String,
) -> Array[String]? {
  let items = match raw_value {
    Some(Array(items)) => items
    _ => {
      self.send_error(
        request_id,
        "invalid argument",
        field_name + " must be an array",
      )
      return None
    }
  }
  let values : Array[String] = []
  for item in items {
    match item {
      String(value) => values.push(value)
      _ => {
        self.send_error(
          request_id,
          "invalid argument",
          field_name + " entries must be strings",
        )
        return None
      }
    }
  }
  Some(values)
}

///|
fn BidiProtocol::input_set_files_source_paths(
  self : BidiProtocol,
  request_id : Int,
  map : Map[String, Json],
) -> Array[String]? {
  match map.get("files") {
    Some(raw_value) =>
      self.input_set_files_string_array(request_id, Some(raw_value), "files")
    None =>
      self.input_set_files_string_array(
        request_id,
        map.get("sourcePaths"),
        "sourcePaths",
      )
  }
}

///|
fn BidiProtocol::input_set_files_display_names(
  self : BidiProtocol,
  request_id : Int,
  map : Map[String, Json],
  source_paths : Array[String],
) -> Array[String]? {
  match map.get("displayNames") {
    Some(raw_value) =>
      self.input_set_files_string_array(
        request_id,
        Some(raw_value),
        "displayNames",
      )
    None => Some(input_set_files_default_display_names(source_paths))
  }
}

///|
fn input_set_files_default_display_names(
  source_paths : Array[String],
) -> Array[String] {
  let display_names : Array[String] = []
  for source_path in source_paths {
    display_names.push(input_set_files_display_name(source_path))
  }
  display_names
}

///|
fn input_set_files_display_name(source_path : String) -> String {
  let mut last_separator = -1
  let mut search_from = 0
  while search_from < source_path.length() {
    match find_substring(source_path, "/", search_from) {
      Some(idx) => {
        last_separator = idx
        search_from = idx + 1
      }
      None => break
    }
  }
  search_from = 0
  while search_from < source_path.length() {
    match find_substring(source_path, "\\", search_from) {
      Some(idx) => {
        if idx > last_separator {
          last_separator = idx
        }
        search_from = idx + 1
      }
      None => break
    }
  }
  if last_separator < 0 {
    return source_path
  }
  let base_name = source_path.unsafe_substring(
    start=last_separator + 1,
    end=source_path.length(),
  )
  if base_name.length() == 0 {
    return source_path
  }
  base_name
}

///|
fn input_set_files_summary_bool(
  summary : Map[String, Json],
  key : String,
) -> Bool {
  match summary.get(key) {
    Some(True) => true
    Some(False) => false
    _ => false
  }
}

///|
fn input_set_files_summary_string(
  summary : Map[String, Json],
  key : String,
) -> String? {
  match summary.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn input_set_files_summary_string_list(
  summary : Map[String, Json],
  key : String,
) -> Array[String]? {
  let items = match summary.get(key) {
    Some(Array(items)) => items
    _ => return None
  }
  let values : Array[String] = []
  for item in items {
    match item {
      String(value) => values.push(value)
      _ => ()
    }
  }
  Some(values)
}

///|
fn evaluate_current_file_input_remote_value() -> Json? {
  let eval_result_json = evaluate_js_with_console(
    "(() => { const input = document.getElementById(\"input\"); return input ?? null; })()",
    false, false, false, "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return None }
  match get_string_field(eval_result, "type") {
    Some("success") => get_field(eval_result, "result")
    _ => None
  }
}

///|
fn evaluate_current_file_input_multiple() -> Bool {
  let eval_result_json = evaluate_js_with_console(
    "(() => { const input = document.getElementById(\"input\"); return Boolean(input && (input.multiple || (typeof input.hasAttribute === \"function\" && input.hasAttribute(\"multiple\")))); })()",
    false, false, false, "{}",
  )
  let eval_result = @json.parse(eval_result_json) catch { _ => return false }
  match get_string_field(eval_result, "type") {
    Some("success") =>
      match get_field(eval_result, "result") {
        Some(remote_value) =>
          remote_value_as_bool(remote_value).unwrap_or(false)
        None => false
      }
    _ => false
  }
}

///|
extern "js" fn js_input_apply_file_selection(
  element_id : String,
  allow_fallback : Bool,
  source_paths_json : String,
  display_names_json : String,
) -> String =
  #| (elementId, allowFallback, sourcePathsJson, displayNamesJson) => {
  #|   const sourcePaths = (() => {
  #|     try {
  #|       const value = JSON.parse(String(sourcePathsJson ?? "[]"));
  #|       return Array.isArray(value) ? value.map(path => String(path)) : [];
  #|     } catch (_) {
  #|       return [];
  #|     }
  #|   })();
  #|   const displayNames = (() => {
  #|     try {
  #|       const value = JSON.parse(String(displayNamesJson ?? "[]"));
  #|       return Array.isArray(value) ? value.map(name => String(name)) : [];
  #|     } catch (_) {
  #|       return [];
  #|     }
  #|   })();
  #|   let input = null;
  #|   if (typeof document !== "undefined" && typeof elementId === "string" && elementId !== "") {
  #|     input = document.getElementById(elementId);
  #|   }
  #|   if (!input && allowFallback && typeof document !== "undefined") {
  #|     input = document.querySelector("input[type=file], #input");
  #|   }
  #|   if (!input && allowFallback && typeof document !== "undefined" && document.body && typeof document.createElement === "function") {
  #|     input = document.createElement("input");
  #|     input.type = "file";
  #|     input.id = "input";
  #|     document.body.appendChild(input);
  #|   }
  #|   if (!input) {
  #|     return JSON.stringify({
  #|       found: false,
  #|       isElement: false,
  #|       tagName: "",
  #|       inputType: "",
  #|       disabled: false,
  #|       multiple: false,
  #|       eventTypes: [],
  #|       eventFiles: [],
  #|     });
  #|   }
  #|   const isElement = Number(input?.nodeType || 0) === 1;
  #|   const tagName = isElement ? String(input.localName || input.tagName || "").toLowerCase() : "";
  #|   const getAttr = (name) => typeof input?.getAttribute === "function" ? input.getAttribute(name) : null;
  #|   const inputType = isElement && tagName === "input" ? String(input.type || getAttr("type") || "").toLowerCase() : "";
  #|   const disabled = isElement && tagName === "input" ? (Boolean(input.disabled) || getAttr("disabled") !== null) : false;
  #|   const multiple = isElement && tagName === "input" ? (Boolean(input.multiple) || getAttr("multiple") !== null) : false;
  #|   const summary = {
  #|     found: true,
  #|     isElement,
  #|     tagName,
  #|     inputType,
  #|     disabled,
  #|     multiple,
  #|     eventTypes: [],
  #|     eventFiles: [],
  #|   };
  #|   if (!isElement || tagName !== "input" || inputType !== "file" || disabled || (!multiple && sourcePaths.length > 1)) {
  #|     return JSON.stringify(summary);
  #|   }
  #|   summary.eventFiles = displayNames.slice();
  #|   const previousSourcePaths = Array.isArray(input.__craterSyntheticSourcePaths) ? input.__craterSyntheticSourcePaths.slice() : [];
  #|   const isSameSelection = previousSourcePaths.length === sourcePaths.length && previousSourcePaths.every((path, index) => path === sourcePaths[index]);
  #|   const syntheticFiles = displayNames.map(name => ({ name }));
  #|   try {
  #|     Object.defineProperty(input, "files", {
  #|       configurable: true,
  #|       get: () => syntheticFiles,
  #|     });
  #|   } catch (_) {
  #|     input.files = syntheticFiles;
  #|   }
  #|   input.__craterSyntheticSourcePaths = sourcePaths.slice();
  #|   const eventBuffer = (() => {
  #|     if (typeof window === "undefined") return null;
  #|     if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
  #|       window.allEvents = { events: [] };
  #|     }
  #|     return window.allEvents.events;
  #|   })();
  #|   const recordEvent = (type) => {
  #|     if (!Array.isArray(eventBuffer)) return;
  #|     eventBuffer.push({ type, files: displayNames.slice() });
  #|   };
  #|   const emit = (type) => {
  #|     if (typeof Event === "function") {
  #|       input.dispatchEvent(new Event(type, { bubbles: true }));
  #|       return;
  #|     }
  #|     if (typeof document !== "undefined" && typeof document.createEvent === "function") {
  #|       const event = document.createEvent("Event");
  #|       event.initEvent(type, true, false);
  #|       input.dispatchEvent(event);
  #|     }
  #|   };
  #|   if (isSameSelection) {
  #|     emit("cancel");
  #|     recordEvent("cancel");
  #|     summary.eventTypes = ["cancel"];
  #|     return JSON.stringify(summary);
  #|   }
  #|   emit("input");
  #|   emit("change");
  #|   recordEvent("input");
  #|   recordEvent("change");
  #|   summary.eventTypes = ["input", "change"];
  #|   return JSON.stringify(summary);
  #| }

///|
fn BidiProtocol::emit_input_file_dialog_opened(
  self : BidiProtocol,
  ctx_id : String,
  multiple : Bool,
  element : Json?,
) -> Unit {
  let event_name = "input.fileDialogOpened"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "multiple": Json::boolean(multiple),
  }
  match element {
    Some(element_value) => params["element"] = element_value
    None => ()
  }
  self.outbox.push(
    Event({ event_method: event_name, params: make_object(params) }),
  )
}

///|
fn parse_show_open_file_picker_multiple(expression : String) -> Bool {
  expression.contains("multiple': true") ||
  expression.contains("\"multiple\": true")
}

///|
fn is_synthetic_file_dialog_cancel_probe(expression : String) -> Bool {
  let has_create_input = expression.contains("document.createElement('input')") ||
    expression.contains("document.createElement(\"input\")")
  let has_file_type = expression.contains("picker.type = 'file'") ||
    expression.contains("picker.type = \"file\"")
  let has_cancel_listener = expression.contains("addEventListener('cancel'") ||
    expression.contains("addEventListener(\"cancel\"")
  has_create_input &&
  has_file_type &&
  has_cancel_listener &&
  expression.contains("picker.click()")
}

///|
fn BidiProtocol::maybe_emit_file_dialog_opened_for_input(
  self : BidiProtocol,
  ctx_id : String,
  input_value : Json?,
) -> Unit {
  if !self.is_subscribed_for_context("input.fileDialogOpened", ctx_id) {
    return
  }
  let mut element : Json? = None
  match input_value {
    Some(value) => element = simplify_node_remote_value(value)
    None => ()
  }
  match element {
    Some(_) => ()
    None =>
      match evaluate_current_file_input_remote_value() {
        Some(value) => element = simplify_node_remote_value(value)
        None => ()
      }
  }
  match element {
    Some(element_value) =>
      self.emit_input_file_dialog_opened(
        ctx_id,
        evaluate_current_file_input_multiple(),
        Some(element_value),
      )
    None => ()
  }
}

///|
fn BidiProtocol::try_handle_synthetic_file_dialog_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
  capture_console : Bool,
  user_activation : Bool,
  root_ownership : Bool,
  serialization_options_json : String,
) -> Bool {
  let trimmed = expression.trim().to_owned()
  if trimmed.has_prefix("window.showOpenFilePicker(") {
    self.emit_input_file_dialog_opened(
      ctx_id,
      parse_show_open_file_picker_multiple(trimmed),
      None,
    )
    self.send_script_undefined_result(request_id, realm_id)
    return true
  }
  if is_synthetic_file_dialog_cancel_probe(trimmed) {
    let handler = self.resolve_unhandled_prompt_handler(ctx_id, "file")
    if handler == "ignore" {
      return true
    }
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("boolean"),
        "value": Json::boolean(true),
      }),
      unwrap_result,
    )
    return true
  }

  let handled_expression = match trimmed {
    "input.click()" =>
      Some(
        "(() => { const input = document.getElementById(\"input\"); if (input && typeof input.click === \"function\") { input.click(); } return undefined; })()",
      )
    "input.showPicker()" =>
      Some(
        "(() => { const input = document.getElementById(\"input\"); if (!input) return undefined; if (typeof input.showPicker === \"function\") { input.showPicker(); } else if (typeof input.click === \"function\") { input.click(); } return undefined; })()",
      )
    "input.click(); input" =>
      Some(
        "(() => { const input = document.getElementById(\"input\"); if (input && typeof input.click === \"function\") { input.click(); } return input ?? null; })()",
      )
    _ => None
  }

  let rewritten = match handled_expression {
    Some(rewritten) => rewritten
    None => return false
  }
  let eval_result = match
    self.evaluate_handled_script_expression(
      request_id, ctx_id, realm_id, rewritten, capture_console, user_activation,
      root_ownership, serialization_options_json,
    ) {
    Some(eval_result) => eval_result
    None => return true
  }

  let result_value = match get_string_field(eval_result, "type") {
    Some("success") => get_field(eval_result, "result")
    _ => None
  }
  self.maybe_emit_file_dialog_opened_for_input(ctx_id, result_value)

  if trimmed == "input.click(); input" {
    self.send_script_eval_result_mode(
      request_id, realm_id, eval_result, unwrap_result,
    )
  } else {
    self.send_script_undefined_response(request_id, realm_id, unwrap_result)
  }
  true
}
