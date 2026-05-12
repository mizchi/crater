///|
/// Validate this parameter for callFunction (must be a serialized value object)
fn BidiProtocol::validate_this_param(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "this") {
    Some(Object(value_map)) => {
      if !is_valid_serialized_value_map(value_map) {
        self.send_error(
          request_id, "invalid argument", "this must be a serialized value",
        )
        return Some(())
      }
      match value_map.get("sharedId") {
        Some(String(shared_id)) =>
          if !has_runtime_shared_node(shared_id) {
            self.send_error(
              request_id,
              "no such node",
              "Unknown sharedId: " + shared_id,
            )
            return Some(())
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "sharedId must be a string",
          )
          return Some(())
        }
        None => ()
      }
      match value_map.get("handle") {
        Some(String(handle_id)) =>
          if !has_runtime_handle(handle_id) {
            self.send_error(
              request_id,
              "no such handle",
              "Unknown handle: " + handle_id,
            )
            return Some(())
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "handle must be a string",
          )
          return Some(())
        }
        None => ()
      }
    }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "this must be a serialized value",
      )
      return Some(())
    }
  }
  None
}

///|
/// Validate arguments parameter for callFunction (must be array of serialized values)
fn BidiProtocol::validate_arguments_param(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  match get_param_raw(params, "arguments") {
    Some(Array(args)) =>
      // Each argument must be a serialized value (object)
      for arg in args {
        match arg {
          Object(arg_map) => {
            if !is_valid_serialized_value_map(arg_map) {
              self.send_error(
                request_id, "invalid argument", "arguments entries must be serialized values",
              )
              return Some(())
            }
            // Check for channel type special validation
            match arg_map.get("type") {
              Some(String("channel")) =>
                // Validate channel value
                match arg_map.get("value") {
                  Some(Object(channel_val)) => {
                    // Validate channel.channel (must be string)
                    match channel_val.get("channel") {
                      Some(String(_)) => ()
                      Some(_) => {
                        self.send_error(
                          request_id, "invalid argument", "channel.channel must be a string",
                        )
                        return Some(())
                      }
                      None => () // May be omitted
                    }
                    // Validate channel.ownership (must be "root" or "none")
                    match channel_val.get("ownership") {
                      Some(String(s)) =>
                        if s != "root" && s != "none" {
                          self.send_error(
                            request_id, "invalid argument", "channel.ownership must be 'root' or 'none'",
                          )
                          return Some(())
                        }
                      Some(_) => {
                        self.send_error(
                          request_id, "invalid argument", "channel.ownership must be a string",
                        )
                        return Some(())
                      }
                      None => ()
                    }
                    // Validate channel.serializationOptions
                    match channel_val.get("serializationOptions") {
                      Some(Object(ser_opts)) =>
                        match
                          self.validate_serialization_options_map(
                            request_id,
                            canonicalize_serialization_options_map(ser_opts),
                          ) {
                          Some(_) => return Some(())
                          None => ()
                        }
                      Some(_) => {
                        self.send_error(
                          request_id, "invalid argument", "serializationOptions must be an object",
                        )
                        return Some(())
                      }
                      None => ()
                    }
                  }
                  Some(_) => {
                    self.send_error(
                      request_id, "invalid argument", "channel value must be an object",
                    )
                    return Some(())
                  }
                  None => {
                    self.send_error(
                      request_id, "invalid argument", "channel type requires value",
                    )
                    return Some(())
                  }
                }
              _ => () // Other types don't need special validation here
            }
            // Validate handle if present
            match arg_map.get("handle") {
              Some(String(handle_id)) =>
                if !has_runtime_handle(handle_id) {
                  self.send_error(
                    request_id,
                    "no such handle",
                    "Unknown handle: " + handle_id,
                  )
                  return Some(())
                }
              Some(_) => {
                self.send_error(
                  request_id, "invalid argument", "handle must be a string",
                )
                return Some(())
              }
              None => ()
            }
            // Validate sharedId if present
            match arg_map.get("sharedId") {
              Some(String(shared_id)) =>
                if !has_runtime_shared_node(shared_id) {
                  self.send_error(
                    request_id,
                    "no such node",
                    "Unknown sharedId: " + shared_id,
                  )
                  return Some(())
                }
              Some(_) => {
                self.send_error(
                  request_id, "invalid argument", "sharedId must be a string",
                )
                return Some(())
              }
              None => ()
            }
          }
          _ => {
            self.send_error(
              request_id, "invalid argument", "arguments entries must be serialized values",
            )
            return Some(())
          }
        }
      }
    None => () // Optional
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "arguments must be an array",
      )
      return Some(())
    }
  }
  None
}

///|
/// Supported serialized argument types for script.addPreloadScript.
fn is_supported_preload_argument_type(type_name : String) -> Bool {
  type_name == "array" ||
  type_name == "bigint" ||
  type_name == "boolean" ||
  type_name == "channel" ||
  type_name == "date" ||
  type_name == "map" ||
  type_name == "null" ||
  type_name == "number" ||
  type_name == "object" ||
  type_name == "regexp" ||
  type_name == "set" ||
  type_name == "string" ||
  type_name == "undefined"
}

///|
/// Parse and validate script.addPreloadScript parameters.
fn BidiProtocol::parse_add_preload_script_params(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> AddPreloadScriptParams? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let function_declaration = match
    get_map_field_with_alias(map, "functionDeclaration", "function_declaration") {
    Some(String(function_declaration)) => function_declaration
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "functionDeclaration must be a string",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing functionDeclaration",
      )
      return None
    }
  }

  let mut arguments : Array[Json] = []
  match map.get("arguments") {
    Some(Array(args)) => arguments = args
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "arguments must be an array",
      )
      return None
    }
    None => ()
  }

  let argument_params = if map.contains("arguments") {
    Some(make_object({ "arguments": Json::array(arguments) }))
  } else {
    None
  }
  match self.validate_arguments_param(request_id, argument_params) {
    Some(_) => return None
    None => ()
  }
  for argument in arguments {
    match argument {
      Object(arg_map) =>
        match arg_map.get("type") {
          Some(String(type_name)) => {
            if !is_supported_preload_argument_type(type_name) {
              self.send_error(
                request_id, "invalid argument", "arguments entries must be serialized values",
              )
              return None
            }
            if type_name == "channel" {
              match arg_map.get("value") {
                Some(Object(channel_val)) =>
                  match channel_val.get("channel") {
                    Some(String(_)) => ()
                    _ => {
                      self.send_error(
                        request_id, "invalid argument", "channel.channel must be a string",
                      )
                      return None
                    }
                  }
                _ => ()
              }
            }
          }
          _ => ()
        }
      _ => ()
    }
  }

  let sandbox = match map.get("sandbox") {
    Some(String(name)) => Some(name)
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "sandbox must be a string",
      )
      return None
    }
    None => None
  }

  let contexts_raw = map.get("contexts")
  let contexts : Array[String] = []
  match contexts_raw {
    Some(Array(items)) => {
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "contexts must not be an empty array",
        )
        return None
      }
      for item in items {
        match item {
          String(ctx_id) =>
            if ctx_id == "" || !self.manager.has_session(ctx_id) {
              self.send_error(
                request_id,
                "no such frame",
                "Unknown context: " + ctx_id,
              )
              return None
            } else if self.context_parent.contains(ctx_id) {
              self.send_error(
                request_id, "invalid argument", "contexts entries must be top-level contexts",
              )
              return None
            } else if !array_contains(contexts, ctx_id) {
              contexts.push(ctx_id)
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "contexts entries must be strings",
            )
            return None
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "contexts must be an array",
      )
      return None
    }
    None => ()
  }

  let user_contexts_raw = get_map_field_with_alias(
    map, "userContexts", "user_contexts",
  )
  let user_contexts : Array[String] = []
  match user_contexts_raw {
    Some(Array(items)) => {
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "userContexts must not be an empty array",
        )
        return None
      }
      for item in items {
        match item {
          String(user_context_id) =>
            if user_context_id == "" ||
              !self.user_contexts.contains(user_context_id) {
              self.send_error(
                request_id,
                "no such user context",
                "Unknown user context: " + user_context_id,
              )
              return None
            } else if !array_contains(user_contexts, user_context_id) {
              user_contexts.push(user_context_id)
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "userContexts entries must be strings",
            )
            return None
          }
        }
      }
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "userContexts must be an array",
      )
      return None
    }
    None => ()
  }

  if contexts.length() > 0 && user_contexts.length() > 0 {
    self.send_error(
      request_id, "invalid argument", "contexts and userContexts cannot be used together",
    )
    return None
  }

  Some({ function_declaration, arguments, sandbox, contexts, user_contexts })
}

///|
fn BidiProtocol::register_preload_script(
  self : BidiProtocol,
  parsed : AddPreloadScriptParams,
) -> String {
  let script_id = "preload-" + self.next_preload_script_id.to_string()
  self.next_preload_script_id += 1
  self.preload_scripts.push({
    script_id,
    function_declaration: parsed.function_declaration,
    arguments: parsed.arguments,
    sandbox: parsed.sandbox,
    contexts: parsed.contexts,
    user_contexts: parsed.user_contexts,
  })
  script_id
}

///|
fn BidiProtocol::resolve_realms_list(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Array[Json]? {
  let context_filter = match get_param_raw(params, "context") {
    Some(String(ctx_id)) => {
      if !self.manager.has_session(ctx_id) {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + ctx_id,
        )
        return None
      }
      Some(ctx_id)
    }
    None => None
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
  }

  match get_param_raw(params, "type") {
    Some(String(t)) =>
      if t != "window" {
        self.send_error(request_id, "invalid argument", "type must be 'window'")
        return None
      }
    None => ()
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
  }

  let realms : Array[Json] = []
  for ctx_id in self.manager.list_sessions() {
    let should_include = match context_filter {
      Some(filter_ctx) => filter_ctx == ctx_id
      None => true
    }
    if should_include {
      let realm_id = self.context_realm.get(ctx_id).unwrap_or("realm-" + ctx_id)
      let origin = self.get_context_origin(ctx_id)
      realms.push(
        make_object({
          "realm": Json::string(realm_id),
          "context": Json::string(ctx_id),
          "type": Json::string("window"),
          "origin": Json::string(origin),
          "sandbox": Json::null(),
        }),
      )
      let prefix = ctx_id + "::"
      for key, sandbox_realm in self.context_sandbox_realm {
        if key.has_prefix(prefix) {
          let sandbox_name = key.unsafe_substring(
            start=prefix.length(),
            end=key.length(),
          )
          realms.push(
            make_object({
              "realm": Json::string(sandbox_realm),
              "context": Json::string(ctx_id),
              "type": Json::string("window"),
              "origin": Json::string(origin),
              "sandbox": Json::string(sandbox_name),
            }),
          )
        }
      }
    }
  }
  Some(realms)
}

///|
/// Serialized value object must include at least one discriminator key.
fn is_valid_serialized_value_map(value_map : Map[String, Json]) -> Bool {
  value_map.contains("type") ||
  value_map.contains("handle") ||
  value_map.contains("sharedId")
}

///|
/// Convert BiDi remote value to JS literal for function arguments
fn bidi_value_to_js_literal(value : Json) -> String {
  match value {
    Object(map) =>
      match map.get("sharedId") {
        Some(String(shared_id)) =>
          "((globalThis.__bidiSharedNodeStore && globalThis.__bidiSharedNodeStore.get(\"" +
          escape_js_string(shared_id) +
          "\")) ?? undefined)"
        _ =>
          match map.get("handle") {
            Some(String(handle_id)) =>
              "((globalThis.__bidiHandleStore && globalThis.__bidiHandleStore.get(\"" +
              escape_js_string(handle_id) +
              "\")) ?? undefined)"
            _ =>
              match map.get("type") {
                Some(String("undefined")) => "undefined"
                Some(String("null")) => "null"
                Some(String("boolean")) =>
                  match map.get("value") {
                    Some(True) => "true"
                    Some(False) => "false"
                    _ => "false"
                  }
                Some(String("number")) =>
                  match map.get("value") {
                    Some(Number(n, ..)) => n.to_string()
                    Some(String(s)) => s // NaN, Infinity, etc.
                    _ => "0"
                  }
                Some(String("string")) =>
                  match map.get("value") {
                    Some(String(s)) => "\"" + escape_js_string(s) + "\""
                    _ => "\"\""
                  }
                Some(String("bigint")) =>
                  match map.get("value") {
                    Some(String(s)) => s + "n"
                    _ => "0n"
                  }
                Some(String("channel")) =>
                  match map.get("value") {
                    Some(Object(channel_map)) => {
                      let channel_name = match channel_map.get("channel") {
                        Some(String(s)) => s
                        _ => "channel"
                      }
                      let ownership = match channel_map.get("ownership") {
                        Some(String(s)) => s
                        _ => "none"
                      }
                      let max_object_depth = match
                        channel_map.get("serializationOptions") {
                        Some(Object(ser_opts)) => {
                          let normalized_ser_opts = canonicalize_serialization_options_map(
                            ser_opts,
                          )
                          match normalized_ser_opts.get("maxObjectDepth") {
                            Some(Number(n, ..)) => n.to_string()
                            _ => "-1"
                          }
                        }
                        _ => "-1"
                      }
                      "((...__args) => {" +
                      "if (!globalThis.__bidiChannelMessages) globalThis.__bidiChannelMessages = [];" +
                      "globalThis.__bidiChannelMessages.push({" +
                      "channel: \"" +
                      escape_js_string(channel_name) +
                      "\"," +
                      "data: (__args.length > 0 ? __args[0] : undefined)," +
                      "ownership: \"" +
                      escape_js_string(ownership) +
                      "\"," +
                      "maxObjectDepth: " +
                      max_object_depth +
                      "});" +
                      "})"
                    }
                    _ => "(() => {})"
                  }
                Some(String("date")) =>
                  match map.get("value") {
                    Some(String(s)) =>
                      "new Date(\"" + escape_js_string(s) + "\")"
                    _ => "new Date(0)"
                  }
                Some(String("regexp")) =>
                  match map.get("value") {
                    Some(Object(regexp_map)) => {
                      let pattern = match regexp_map.get("pattern") {
                        Some(String(s)) => "\"" + escape_js_string(s) + "\""
                        _ => "\"\""
                      }
                      let flags = match regexp_map.get("flags") {
                        Some(String(s)) => "\"" + escape_js_string(s) + "\""
                        _ => "\"\""
                      }
                      "new RegExp(" + pattern + ", " + flags + ")"
                    }
                    _ => "new RegExp(\"\", \"\")"
                  }
                Some(String("array")) =>
                  match map.get("value") {
                    Some(Array(items)) => {
                      let parts : Array[String] = []
                      for item in items {
                        parts.push(bidi_value_to_js_literal(item))
                      }
                      "[" + parts.join(", ") + "]"
                    }
                    _ => "[]"
                  }
                Some(String("map")) =>
                  match map.get("value") {
                    Some(Array(entries)) => {
                      let parts : Array[String] = []
                      for entry in entries {
                        match entry {
                          Array(kv) if kv.length() >= 2 => {
                            let key = bidi_value_to_js_literal(kv[0])
                            let val = bidi_value_to_js_literal(kv[1])
                            parts.push("[" + key + ", " + val + "]")
                          }
                          _ => ()
                        }
                      }
                      "new Map([" + parts.join(", ") + "])"
                    }
                    _ => "new Map()"
                  }
                Some(String("set")) =>
                  match map.get("value") {
                    Some(Array(items)) => {
                      let parts : Array[String] = []
                      for item in items {
                        parts.push(bidi_value_to_js_literal(item))
                      }
                      "new Set([" + parts.join(", ") + "])"
                    }
                    _ => "new Set()"
                  }
                Some(String("object")) =>
                  match map.get("value") {
                    Some(Array(entries)) => {
                      let parts : Array[String] = []
                      for entry in entries {
                        match entry {
                          Array(kv) if kv.length() >= 2 => {
                            let key = match kv[0] {
                              String(s) => "\"" + escape_js_string(s) + "\""
                              _ => bidi_value_to_js_literal(kv[0])
                            }
                            let val = bidi_value_to_js_literal(kv[1])
                            parts.push(key + ": " + val)
                          }
                          _ => ()
                        }
                      }
                      "{" + parts.join(", ") + "}"
                    }
                    _ => "{}"
                  }
                _ => "undefined"
              }
          }
      }
    String(s) => "\"" + escape_js_string(s) + "\""
    Number(n, ..) => n.to_string()
    True => "true"
    False => "false"
    Null => "null"
    _ => "undefined"
  }
}

///|
/// Escape special characters in JS string
fn escape_js_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s.iter() {
    match c {
      '\\' => buf.write_string("\\\\")
      '"' => buf.write_string("\\\"")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}
