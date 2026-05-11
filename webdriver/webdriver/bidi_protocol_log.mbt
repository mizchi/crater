///|
/// Emit log.entryAdded event
fn BidiProtocol::emit_log_entry_with_details(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  entry_type : String,
  level : String,
  text : String,
  console_method : String?,
  args : Array[Json],
  timestamp : Double,
  stack_trace : Json?,
) -> Unit {
  let params_map : Map[String, Json] = {
    "level": Json::string(level),
    "source": make_object({
      "realm": Json::string(realm_id),
      "context": Json::string(ctx_id),
    }),
    "text": Json::string(text),
    "timestamp": Json::number(timestamp),
    "type": Json::string(entry_type),
  }
  if entry_type == "console" {
    params_map["method"] = Json::string(console_method.unwrap_or("log"))
    params_map["args"] = Json::array(args)
  }
  match stack_trace {
    Some(value) => params_map["stackTrace"] = value
    None => ()
  }
  let params = make_object(params_map)
  if !self.is_subscribed_for_context("log.entryAdded", ctx_id) {
    self.subscription_state.buffer_log_entry(ctx_id, params)
    return
  }
  self.outbox.push(Event({ event_method: "log.entryAdded", params }))
}

///|
/// Emit log.entryAdded event for console entries.
fn BidiProtocol::emit_log_entry(
  self : BidiProtocol,
  ctx_id : String,
  level : String,
  text : String,
  console_method : String,
  args : Array[Json],
  timestamp : Double,
) -> Unit {
  let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
  self.emit_log_entry_with_details(
    ctx_id,
    realm_id,
    "console",
    level,
    text,
    Some(console_method),
    args,
    timestamp,
    None,
  )
}

///|
/// Emit log.entryAdded event for javascript errors.
fn BidiProtocol::emit_javascript_log_entry(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  level : String,
  text : String,
  timestamp : Double,
  stack_trace : Json?,
) -> Unit {
  self.emit_log_entry_with_details(
    ctx_id,
    realm_id,
    "javascript",
    level,
    text,
    None,
    [],
    timestamp,
    stack_trace,
  )
}

///|
/// Process console entries from JS evaluation result and emit log events
fn BidiProtocol::process_console_entries(
  self : BidiProtocol,
  eval_result : Json,
  ctx_id : String,
  realm_id : String,
) -> Unit {
  match get_field(eval_result, "consoleEntries") {
    Some(Array(entries)) =>
      for entry in entries {
        match entry {
          Object(_) => {
            let entry_type = get_string_field(entry, "type").unwrap_or(
              "console",
            )
            let level = get_string_field(entry, "level").unwrap_or("info")
            let console_method = get_string_field(entry, "method").unwrap_or(
              "log",
            )
            let text = get_string_field(entry, "text").unwrap_or("")
            let entry_realm_raw = get_string_field(entry, "realm").unwrap_or(
              realm_id,
            )
            let entry_realm = if entry_realm_raw == "" {
              realm_id
            } else {
              entry_realm_raw
            }
            let args = match get_field(entry, "args") {
              Some(Array(values)) => values
              _ => []
            }
            let timestamp = match get_field(entry, "timestamp") {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
            let stack_trace = match get_field(entry, "stackTrace") {
              Some(Object(_)) => get_field(entry, "stackTrace")
              _ => None
            }
            if entry_type == "javascript" {
              self.emit_javascript_log_entry(
                ctx_id, entry_realm, level, text, timestamp, stack_trace,
              )
            } else {
              self.emit_log_entry_with_details(
                ctx_id,
                entry_realm,
                "console",
                level,
                text,
                Some(console_method),
                args,
                timestamp,
                stack_trace,
              )
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
/// Emit script.message event.
fn BidiProtocol::emit_script_message(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
  channel : String,
  data : Json,
) -> Unit {
  let event_name = "script.message"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params = make_object({
    "channel": Json::string(channel),
    "data": data,
    "source": make_object({
      "realm": Json::string(realm_id),
      "context": Json::string(ctx_id),
    }),
  })
  self.outbox.push(Event({ event_method: event_name, params }))
}

///|
/// Drain pending channel callback messages from JS runtime and emit script.message.
fn BidiProtocol::process_channel_messages(
  self : BidiProtocol,
  ctx_id : String,
  realm_id : String,
) -> Unit {
  let channel_messages = @json.parse(take_channel_messages_json()) catch {
    _ => Json::array([])
  }
  match channel_messages {
    Array(entries) =>
      for entry in entries {
        match entry {
          Object(msg_map) => {
            let channel = match msg_map.get("channel") {
              Some(String(s)) => s
              _ => ""
            }
            if channel != "" {
              let data = msg_map
                .get("data")
                .unwrap_or(make_object({ "type": Json::string("undefined") }))
              self.emit_script_message(ctx_id, realm_id, channel, data)
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
}
