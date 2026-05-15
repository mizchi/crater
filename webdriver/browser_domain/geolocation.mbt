///|
/// Pure helpers for synthetic geolocation domain JSON payloads.

///|
pub fn default_geolocation_coordinates_json() -> Json {
  @protocol.make_object({
    "latitude": Json::number(35.6895),
    "longitude": Json::number(139.6917),
    "accuracy": Json::number(1.0),
  })
}

///|
pub fn build_geolocation_coordinates_override(coordinates : Json) -> Json {
  @protocol.make_object({
    "kind": Json::string("coordinates"),
    "coordinates": coordinates,
  })
}

///|
pub fn build_geolocation_error_override(error_type : String) -> Json {
  @protocol.make_object({
    "kind": Json::string("error"),
    "error": @protocol.make_object({ "type": Json::string(error_type) }),
  })
}

///|
pub fn push_geolocation_number_remote_entry(
  entries : Array[Json],
  coordinates_map : Map[String, Json],
  key : String,
) -> Unit {
  match coordinates_map.get(key) {
    Some(Number(value, ..)) =>
      entries.push(
        Json::array([
          Json::string(key),
          @protocol.make_object({
            "type": Json::string("number"),
            "value": Json::number(value),
          }),
        ]),
      )
    _ => ()
  }
}

///|
pub fn build_geolocation_coordinates_remote_value(coordinates : Json) -> Json {
  let entries : Array[Json] = []
  match coordinates {
    Object(coordinates_map) => {
      push_geolocation_number_remote_entry(entries, coordinates_map, "latitude")
      push_geolocation_number_remote_entry(
        entries, coordinates_map, "longitude",
      )
      push_geolocation_number_remote_entry(entries, coordinates_map, "accuracy")
      push_geolocation_number_remote_entry(entries, coordinates_map, "altitude")
      push_geolocation_number_remote_entry(
        entries, coordinates_map, "altitudeAccuracy",
      )
      push_geolocation_number_remote_entry(entries, coordinates_map, "heading")
      push_geolocation_number_remote_entry(entries, coordinates_map, "speed")
    }
    _ => ()
  }
  @protocol.make_object({
    "type": Json::string("object"),
    "value": Json::array(entries),
  })
}

///|
pub fn build_geolocation_error_remote_value(code : Int) -> Json {
  @protocol.make_object({
    "type": Json::string("object"),
    "value": Json::array([
      Json::array([
        Json::string("code"),
        @protocol.make_object({
          "type": Json::string("number"),
          "value": Json::number(code.to_double()),
        }),
      ]),
    ]),
  })
}

///|
pub fn geolocation_watch_scope_key(ctx_id : String, watch_id : Int) -> String {
  ctx_id + "|" + watch_id.to_string()
}

///|
pub fn normalize_geolocation_number_json(
  value : Json,
  min : Double,
  max : Double,
) -> Double? {
  @protocol.json_as_safe_number(value, min, max)
}
