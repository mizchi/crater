///|
/// Pure helpers for synthetic screen orientation JSON payloads.

///|
pub fn default_screen_orientation_json() -> Json {
  @protocol.make_object({
    "natural": Json::string("portrait"),
    "type": Json::string("portrait-primary"),
    "angle": Json::number(0),
  })
}

///|
pub fn is_valid_screen_orientation_natural(value : String) -> Bool {
  value == "portrait" || value == "landscape"
}

///|
pub fn is_valid_screen_orientation_type(value : String) -> Bool {
  value == "portrait-primary" ||
  value == "portrait-secondary" ||
  value == "landscape-primary" ||
  value == "landscape-secondary"
}

///|
pub fn compute_screen_orientation_angle(
  orientation_type : String,
  natural : String,
) -> Int {
  match (natural, orientation_type) {
    ("portrait", "portrait-primary") => 0
    ("portrait", "landscape-primary") => 90
    ("portrait", "portrait-secondary") => 180
    ("portrait", "landscape-secondary") => 270
    ("landscape", "landscape-primary") => 0
    ("landscape", "portrait-primary") => 90
    ("landscape", "landscape-secondary") => 180
    ("landscape", "portrait-secondary") => 270
    _ => 0
  }
}

///|
pub fn normalize_screen_orientation_json(value : Json) -> Json? {
  let map = match value {
    Object(map) => map
    _ => return None
  }
  let natural = match map.get("natural") {
    Some(String(natural)) if is_valid_screen_orientation_natural(natural) =>
      natural
    _ => return None
  }
  let orientation_type = match map.get("type") {
    Some(String(orientation_type)) =>
      if is_valid_screen_orientation_type(orientation_type) {
        orientation_type
      } else {
        return None
      }
    _ => return None
  }
  Some(
    @protocol.make_object({
      "natural": Json::string(natural),
      "type": Json::string(orientation_type),
      "angle": Json::number(
        compute_screen_orientation_angle(orientation_type, natural).to_double(),
      ),
    }),
  )
}
