///|
/// Pure helpers for synthetic screen domain JSON payloads.

///|
pub fn build_screen_area_json(width : Int, height : Int) -> Json {
  @protocol.make_object({
    "width": Json::number(width.to_double()),
    "height": Json::number(height.to_double()),
    "availWidth": Json::number(width.to_double()),
    "availHeight": Json::number(height.to_double()),
  })
}

///|
pub fn normalize_screen_area_json(value : Json) -> Json? {
  let map = match value {
    Object(map) => map
    _ => return None
  }
  let width = match map.get("width") {
    Some(width) => @protocol.json_as_safe_int(width, 0.0, 9007199254740991.0)
    None => None
  }
  let height = match map.get("height") {
    Some(height) => @protocol.json_as_safe_int(height, 0.0, 9007199254740991.0)
    None => None
  }
  match (width, height) {
    (Some(width), Some(height)) => Some(build_screen_area_json(width, height))
    _ => None
  }
}
