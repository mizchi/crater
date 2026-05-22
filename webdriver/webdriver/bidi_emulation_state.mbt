///|
/// WebDriver BiDi emulation override state.
///
/// Each emulation feature follows the same precedence model:
/// context override, user-context override, then global override.
///
/// Per-session `@browser_http.Profile` values carry HTTP security state
/// only (cookies, auth, CORS/cache). User-agent overrides stay in this
/// emulation state so identity spoofing controls are separated from HTTP
/// credential state.
priv struct BidiEmulationState {
  mut emulation_user_agent_global : String?
  emulation_user_agent_by_context : Map[String, String] // top-level context -> userAgent override
  emulation_user_agent_by_user_context : Map[String, String] // user context -> userAgent override
  session_profiles : Map[String, @browser_http.Profile] // session id -> per-session profile
  mut emulation_locale_global : String?
  emulation_locale_by_context : Map[String, String] // top-level context -> locale override
  emulation_locale_by_user_context : Map[String, String] // user context -> locale override
  mut emulation_timezone_global : String?
  emulation_timezone_by_context : Map[String, String] // top-level context -> timezone override
  emulation_timezone_by_user_context : Map[String, String] // user context -> timezone override
  mut emulation_geolocation_global : Json?
  emulation_geolocation_by_context : Map[String, Json] // top-level context -> geolocation override
  emulation_geolocation_by_user_context : Map[String, Json] // user context -> geolocation override
  mut emulation_network_conditions_global : Json?
  emulation_network_conditions_by_context : Map[String, Json] // top-level context -> network conditions override
  emulation_network_conditions_by_user_context : Map[String, Json] // user context -> network conditions override
  mut emulation_screen_orientation_global : Json?
  emulation_screen_orientation_by_context : Map[String, Json] // top-level context -> screen orientation override
  emulation_screen_orientation_by_user_context : Map[String, Json] // user context -> screen orientation override
  mut emulation_screen_area_global : Json?
  emulation_screen_area_by_context : Map[String, Json] // top-level context -> screen area override
  emulation_screen_area_by_user_context : Map[String, Json] // user context -> screen area override
}

///|
fn BidiEmulationState::new() -> BidiEmulationState {
  {
    emulation_user_agent_global: None,
    emulation_user_agent_by_context: {},
    emulation_user_agent_by_user_context: {},
    emulation_locale_global: None,
    emulation_locale_by_context: {},
    emulation_locale_by_user_context: {},
    emulation_timezone_global: None,
    emulation_timezone_by_context: {},
    emulation_timezone_by_user_context: {},
    emulation_geolocation_global: None,
    emulation_geolocation_by_context: {},
    emulation_geolocation_by_user_context: {},
    emulation_network_conditions_global: None,
    emulation_network_conditions_by_context: {},
    emulation_network_conditions_by_user_context: {},
    emulation_screen_orientation_global: None,
    emulation_screen_orientation_by_context: {},
    emulation_screen_orientation_by_user_context: {},
    emulation_screen_area_global: None,
    emulation_screen_area_by_context: {},
    emulation_screen_area_by_user_context: {},
    session_profiles: {},
  }
}

///|
fn BidiEmulationState::reset(self : BidiEmulationState) -> Unit {
  self.emulation_user_agent_global = None
  clear_string_map(self.emulation_user_agent_by_context)
  clear_string_map(self.emulation_user_agent_by_user_context)
  self.emulation_locale_global = None
  clear_string_map(self.emulation_locale_by_context)
  clear_string_map(self.emulation_locale_by_user_context)
  self.emulation_timezone_global = None
  clear_string_map(self.emulation_timezone_by_context)
  clear_string_map(self.emulation_timezone_by_user_context)
  self.emulation_geolocation_global = None
  clear_json_map(self.emulation_geolocation_by_context)
  clear_json_map(self.emulation_geolocation_by_user_context)
  self.emulation_network_conditions_global = None
  clear_json_map(self.emulation_network_conditions_by_context)
  clear_json_map(self.emulation_network_conditions_by_user_context)
  self.emulation_screen_orientation_global = None
  clear_json_map(self.emulation_screen_orientation_by_context)
  clear_json_map(self.emulation_screen_orientation_by_user_context)
  self.emulation_screen_area_global = None
  clear_json_map(self.emulation_screen_area_by_context)
  clear_json_map(self.emulation_screen_area_by_user_context)
  clear_profile_map(self.session_profiles)
}

///|
/// Look up (or lazily create) the per-session profile for `ctx_id`.
/// Returns None when the session is unknown to the CDP session manager —
/// the caller should treat that as "ignore this update", not as an error.
fn BidiProtocol::profile_for_session(
  self : BidiProtocol,
  ctx_id : String,
) -> @browser_http.Profile? {
  if !self.manager.has_session(ctx_id) {
    return None
  }
  match self.emulation_state.session_profiles.get(ctx_id) {
    Some(profile) => Some(profile)
    None => {
      let profile = @browser_http.Profile::default()
      self.emulation_state.session_profiles[ctx_id] = profile
      Some(profile)
    }
  }
}

///|
fn clear_profile_map(values : Map[String, @browser_http.Profile]) -> Unit {
  let keys : Array[String] = []
  for key, _ in values {
    keys.push(key)
  }
  for key in keys {
    values.remove(key)
  }
}

///|
fn clear_string_map(values : Map[String, String]) -> Unit {
  let keys : Array[String] = []
  for key, _ in values {
    keys.push(key)
  }
  for key in keys {
    values.remove(key)
  }
}

///|
fn clear_json_map(values : Map[String, Json]) -> Unit {
  let keys : Array[String] = []
  for key, _ in values {
    keys.push(key)
  }
  for key in keys {
    values.remove(key)
  }
}
