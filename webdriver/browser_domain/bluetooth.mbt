///|
/// Pure helpers for synthetic bluetooth domain handling.

///|
pub fn bluetooth_device_field_string(device : Json, field : String) -> String? {
  match device {
    Object(map) =>
      match map.get(field) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
pub fn find_bluetooth_device_for_name(
  devices : Array[Json],
  expected_name : String?,
) -> Json {
  match expected_name {
    Some(expected_name) =>
      for device in devices {
        match bluetooth_device_field_string(device, "name") {
          Some(name) if name == expected_name => return device
          _ => ()
        }
      }
    None => ()
  }
  devices[0]
}

///|
pub fn upsert_bluetooth_device(
  devices : Array[Json],
  next_device : Json,
  address : String,
) -> Array[Json] {
  let out : Array[Json] = []
  let mut replaced = false
  for device in devices {
    match bluetooth_device_field_string(device, "address") {
      Some(current_address) if current_address == address => {
        out.push(next_device)
        replaced = true
      }
      _ => out.push(device)
    }
  }
  if !replaced {
    out.push(next_device)
  }
  out
}

///|
pub fn extract_first_bluetooth_string_argument(params : Json?) -> String? {
  match @protocol.get_param_raw(params, "arguments") {
    Some(Array(args)) if args.length() > 0 =>
      match args[0] {
        Object(map) =>
          match (map.get("type"), map.get("value")) {
            (Some(String("string")), Some(String(value))) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
pub fn make_bluetooth_requested_device_remote_value(
  address : String,
  name : String,
) -> Json {
  @protocol.make_object({
    "type": Json::string("object"),
    "value": Json::array([
      Json::array([
        Json::string("id"),
        @protocol.make_object({
          "type": Json::string("string"),
          "value": Json::string(address),
        }),
      ]),
      Json::array([
        Json::string("name"),
        @protocol.make_object({
          "type": Json::string("string"),
          "value": Json::string(name),
        }),
      ]),
    ]),
  })
}

///|
pub fn bluetooth_scope_key(ctx_id : String, address : String) -> String {
  ctx_id + "|" + address
}

///|
pub fn bluetooth_characteristic_prefix_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
) -> String {
  ctx_id + "|" + address + "|" + service_uuid + "|"
}

///|
pub fn bluetooth_characteristic_scope_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
) -> String {
  bluetooth_characteristic_prefix_key(ctx_id, address, service_uuid) +
  characteristic_uuid
}

///|
pub fn bluetooth_descriptor_prefix_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
) -> String {
  bluetooth_characteristic_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  ) +
  "|"
}

///|
pub fn bluetooth_descriptor_scope_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
  descriptor_uuid : String,
) -> String {
  bluetooth_descriptor_prefix_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  ) +
  descriptor_uuid
}

///|
pub fn make_bluetooth_byte_remote_value(data : Array[Json]) -> Json {
  let items : Array[Json] = []
  for entry in data {
    match entry {
      Number(value, ..) =>
        items.push(
          @protocol.make_object({
            "type": Json::string("number"),
            "value": Json::number(value),
          }),
        )
      _ => ()
    }
  }
  @protocol.make_object({
    "type": Json::string("array"),
    "value": Json::array(items),
  })
}

///|
pub fn extract_bluetooth_call_string_argument(
  source : String,
  method_name : String,
) -> String {
  let single_prefix = method_name + "('"
  match @protocol.find_substring(source, single_prefix, 0) {
    Some(start_idx) => {
      let value_start = start_idx + single_prefix.length()
      match @protocol.find_substring(source, "')", value_start) {
        Some(end_idx) if end_idx >= value_start =>
          source.unsafe_substring(start=value_start, end=end_idx)
        _ => ""
      }
    }
    None => {
      let double_prefix = method_name + "(\""
      match @protocol.find_substring(source, double_prefix, 0) {
        Some(start_idx) => {
          let value_start = start_idx + double_prefix.length()
          match @protocol.find_substring(source, "\")", value_start) {
            Some(end_idx) if end_idx >= value_start =>
              source.unsafe_substring(start=value_start, end=end_idx)
            _ => ""
          }
        }
        None => ""
      }
    }
  }
}

///|
pub fn extract_bluetooth_uint8_array_data(source : String) -> Array[Json] {
  let prefix = "new Uint8Array("
  match @protocol.find_substring(source, prefix, 0) {
    Some(start_idx) => {
      let data_start = start_idx + prefix.length()
      match @protocol.find_substring(source, ")", data_start) {
        Some(end_idx) if end_idx >= data_start => {
          let raw = source.unsafe_substring(start=data_start, end=end_idx)
          extract_bluetooth_byte_array_literal(raw.trim().to_owned())
        }
        _ => []
      }
    }
    None => []
  }
}

///|
pub fn extract_bluetooth_byte_array_literal(raw : String) -> Array[Json] {
  if raw.length() < 2 || !raw.has_prefix("[") || !raw.has_suffix("]") {
    return []
  }
  let body = raw.unsafe_substring(start=1, end=raw.length() - 1)
  if body.trim().to_owned() == "" {
    return []
  }
  let out : Array[Json] = []
  for part in body.split(",") {
    let value_text = part.trim().to_owned()
    if value_text == "" {
      continue
    }
    let value = @string.parse_int(value_text) catch { _ => -1 }
    if value >= 0 && value <= 255 {
      out.push(Json::number(value.to_double()))
    }
  }
  out
}
