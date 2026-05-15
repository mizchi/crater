///|
/// Pure helpers for reading BiDi script remote-value JSON objects.

///|
pub fn remote_value_as_bool(value : Json) -> Bool? {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("boolean")), Some(True)) => Some(true)
        (Some(String("boolean")), Some(False)) => Some(false)
        _ => None
      }
    _ => None
  }
}

///|
pub fn remote_value_as_string(value : Json) -> String? {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("string")), Some(String(value))) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
pub fn remote_value_as_number(value : Json) -> Double? {
  match value {
    Object(map) =>
      match (map.get("type"), map.get("value")) {
        (Some(String("number")), Some(Number(n, ..))) => Some(n)
        _ => None
      }
    _ => None
  }
}
