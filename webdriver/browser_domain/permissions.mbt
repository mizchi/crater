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
