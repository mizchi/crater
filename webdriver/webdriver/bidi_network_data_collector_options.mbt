///|
fn network_collector_matches_scope(
  options : Map[String, Json],
  ancestry : Array[String],
  user_context : String,
) -> Bool {
  match options.get("contexts") {
    Some(Array(contexts)) =>
      if contexts.length() > 0 {
        let mut matched = false
        for item in contexts {
          match item {
            String(ctx_id) if array_contains_string(ancestry, ctx_id) => {
              matched = true
              break
            }
            _ => ()
          }
        }
        if !matched {
          return false
        }
      }
    _ => ()
  }
  match options.get("userContexts") {
    Some(Array(user_contexts)) =>
      if user_contexts.length() > 0 {
        let mut matched = false
        for item in user_contexts {
          match item {
            String(candidate) if candidate == user_context => {
              matched = true
              break
            }
            _ => ()
          }
        }
        if !matched {
          return false
        }
      }
    _ => ()
  }
  true
}

///|
fn network_collector_data_types(options : Map[String, Json]) -> Array[String] {
  let data_types : Array[String] = []
  match options.get("dataTypes") {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(name) => data_types.push(name)
          _ => ()
        }
      }
    _ => ()
  }
  data_types
}

///|
fn network_collector_max_encoded_size(options : Map[String, Json]) -> Int {
  match options.get("maxEncodedDataSize") {
    Some(Number(n, ..)) => n.to_int()
    _ => 1000
  }
}

///|
fn network_bytes_value_encoded_size(value : Json) -> Int {
  match value {
    Object(map) =>
      match map.get("value") {
        Some(String(payload)) => js_utf8_byte_length(payload)
        _ => 0
      }
    _ => 0
  }
}
