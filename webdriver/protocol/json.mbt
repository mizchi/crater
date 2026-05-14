///|
/// JSON helpers
pub fn make_object(map : Map[String, Json]) -> Json {
  Json::object(map)
}

///|
pub fn get_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
pub fn get_string_field(json : Json, key : String) -> String? {
  match get_field(json, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
pub fn get_int_field(json : Json, key : String) -> Int? {
  match get_field(json, key) {
    Some(Number(n, ..)) => Some(n.to_int())
    _ => None
  }
}

///|
pub fn get_string_param(params : Json?, key : String) -> String? {
  match params {
    Some(Object(map)) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Get raw parameter value without type conversion
pub fn get_param_raw(params : Json?, key : String) -> Json? {
  match params {
    Some(Object(map)) => map.get(key)
    _ => None
  }
}

///|
pub fn get_param_raw_with_alias(
  params : Json?,
  key : String,
  alias_key : String,
) -> Json? {
  match params {
    Some(Object(map)) => get_map_field_with_alias(map, key, alias_key)
    _ => None
  }
}

///|
/// Get map entry by primary key, then fallback alias.
pub fn get_map_field_with_alias(
  map : Map[String, Json],
  key : String,
  alias_key : String,
) -> Json? {
  match map.get(key) {
    Some(value) => Some(value)
    None => map.get(alias_key)
  }
}

///|
pub fn canonicalize_serialization_options_map(
  raw_opts : Map[String, Json],
) -> Map[String, Json] {
  let normalized : Map[String, Json] = {}
  for key, value in raw_opts {
    if key != "max_dom_depth" &&
      key != "max_object_depth" &&
      key != "include_shadow_tree" {
      normalized[key] = value
    }
  }
  match get_map_field_with_alias(raw_opts, "maxDomDepth", "max_dom_depth") {
    Some(value) => normalized["maxDomDepth"] = value
    None => ()
  }
  match
    get_map_field_with_alias(raw_opts, "maxObjectDepth", "max_object_depth") {
    Some(value) => normalized["maxObjectDepth"] = value
    None => ()
  }
  match
    get_map_field_with_alias(
      raw_opts, "includeShadowTree", "include_shadow_tree",
    ) {
    Some(value) => normalized["includeShadowTree"] = value
    None => ()
  }
  normalized
}

///|
/// Get serializationOptions as JSON string.
pub fn get_serialization_options_json(params : Json?) -> String {
  match
    get_param_raw_with_alias(
      params, "serializationOptions", "serialization_options",
    ) {
    Some(Object(opts)) =>
      make_object(canonicalize_serialization_options_map(opts)).stringify()
    _ => "{}"
  }
}

///|
/// Get serializationOptions for locateNodes with adjusted DOM depth semantics.
pub fn get_locate_nodes_serialization_options_json(params : Json?) -> String {
  match
    get_param_raw_with_alias(
      params, "serializationOptions", "serialization_options",
    ) {
    Some(Object(opts)) => {
      let normalized_opts = canonicalize_serialization_options_map(opts)
      let adjusted : Map[String, Json] = {}
      for key, value in normalized_opts {
        adjusted[key] = value
      }
      match normalized_opts.get("maxDomDepth") {
        Some(Number(n, ..)) => adjusted["maxDomDepth"] = Json::number(n + 2.0)
        _ => adjusted["maxDomDepth"] = Json::number(4.0)
      }
      match normalized_opts.get("includeShadowTree") {
        Some(String(mode)) => adjusted["includeShadowTree"] = Json::string(mode)
        _ => adjusted["includeShadowTree"] = Json::string("all")
      }
      make_object(adjusted).stringify()
    }
    _ => "{}"
  }
}

///|
/// Check if serializationOptions parameter is present.
pub fn has_serialization_options_param(params : Json?) -> Bool {
  match
    get_param_raw_with_alias(
      params, "serializationOptions", "serialization_options",
    ) {
    Some(Object(_)) => true
    _ => false
  }
}

///|
/// Determine runtime context key used by JS evaluator.
pub fn resolve_runtime_context_id(
  params : Json?,
  ctx_id : String,
  realm_id : String,
  realm_is_sandbox : Bool,
) -> String {
  match get_param_raw(params, "target") {
    Some(Object(target_map)) =>
      match target_map.get("sandbox") {
        Some(String(name)) => if name == "" { ctx_id } else { realm_id }
        _ => if realm_is_sandbox { realm_id } else { ctx_id }
      }
    _ => if realm_is_sandbox { realm_id } else { ctx_id }
  }
}
