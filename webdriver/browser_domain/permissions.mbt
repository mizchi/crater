///|
/// Pure helpers for synthetic permissions domain handling.

///|
pub fn is_supported_permission_name(name : String) -> Bool {
  name == "geolocation" || name == "storage-access"
}

///|
pub fn permission_scope_key(
  permission_name : String,
  user_context_id : String,
  origin : String,
  embedded_origin : String,
) -> String {
  permission_name + "|" + user_context_id + "|" + origin + "|" + embedded_origin
}

///|
pub fn normalize_permission_origin(origin : String) -> String {
  if origin == "" || origin == "null" {
    return origin
  }
  if origin.has_suffix("/") &&
    (origin.has_prefix("http://") || origin.has_prefix("https://")) {
    return origin.unsafe_substring(start=0, end=origin.length() - 1)
  }
  origin
}

///|
pub fn permission_scope_belongs_to_user_context(
  key : String,
  user_context_id : String,
) -> Bool {
  match @protocol.find_substring(key, "|", 0) {
    Some(first_sep) =>
      match @protocol.find_substring(key, "|", first_sep + 1) {
        Some(second_sep) => {
          let scope_user_context = key.unsafe_substring(
            start=first_sep + 1,
            end=second_sep,
          )
          scope_user_context == user_context_id
        }
        None => false
      }
    None => false
  }
}

///|
pub fn extract_permissions_query_name(function_declaration : String) -> String? {
  match @protocol.extract_quoted_after_marker(function_declaration, "name: ") {
    Some(name) => Some(name)
    None => @protocol.extract_quoted_after_marker(function_declaration, "name:")
  }
}
