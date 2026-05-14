///|
/// Compatibility wrappers for pure BiDi protocol JSON helpers.

///|
fn make_object(map : Map[String, Json]) -> Json {
  @protocol.make_object(map)
}

///|
fn get_field(json : Json, key : String) -> Json? {
  @protocol.get_field(json, key)
}

///|
fn get_string_field(json : Json, key : String) -> String? {
  @protocol.get_string_field(json, key)
}

///|
fn get_int_field(json : Json, key : String) -> Int? {
  @protocol.get_int_field(json, key)
}

///|
fn get_string_param(params : Json?, key : String) -> String? {
  @protocol.get_string_param(params, key)
}

///|
fn get_param_raw(params : Json?, key : String) -> Json? {
  @protocol.get_param_raw(params, key)
}

///|
fn get_param_raw_with_alias(
  params : Json?,
  key : String,
  alias_key : String,
) -> Json? {
  @protocol.get_param_raw_with_alias(params, key, alias_key)
}

///|
fn get_map_field_with_alias(
  map : Map[String, Json],
  key : String,
  alias_key : String,
) -> Json? {
  @protocol.get_map_field_with_alias(map, key, alias_key)
}

///|
fn canonicalize_serialization_options_map(
  raw_opts : Map[String, Json],
) -> Map[String, Json] {
  @protocol.canonicalize_serialization_options_map(raw_opts)
}

///|
fn get_serialization_options_json(params : Json?) -> String {
  @protocol.get_serialization_options_json(params)
}

///|
fn get_locate_nodes_serialization_options_json(params : Json?) -> String {
  @protocol.get_locate_nodes_serialization_options_json(params)
}

///|
fn has_serialization_options_param(params : Json?) -> Bool {
  @protocol.has_serialization_options_param(params)
}

///|
fn resolve_runtime_context_id(
  params : Json?,
  ctx_id : String,
  realm_id : String,
  realm_is_sandbox : Bool,
) -> String {
  @protocol.resolve_runtime_context_id(
    params, ctx_id, realm_id, realm_is_sandbox,
  )
}
