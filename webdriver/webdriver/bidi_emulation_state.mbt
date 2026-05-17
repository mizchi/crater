///|
/// WebDriver BiDi emulation override state.
///
/// Each emulation feature follows the same precedence model:
/// context override, user-context override, then global override.
///
/// Phase 1 of the browser-auth-cors plan additionally carries a per-session
/// `@browser_http.Profile` so emulation writes can be mirrored into the
/// session's profile. This is option (a) from Task 5 — the legacy
/// `emulation_user_agent_global` field stays as the primary read path; the
/// profile is the forward-compatible source of truth for later phases
/// (cookies, auth, CORS).
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
/// Mirror a global user-agent override into every known session profile.
/// Called from the `setUserAgentOverride` global branch so the profile
/// stays in sync with `emulation_user_agent_global`. Skips sessions that
/// the manager no longer knows about.
fn BidiProtocol::mirror_global_user_agent_to_session_profiles(
  self : BidiProtocol,
  user_agent : String?,
) -> Unit {
  // TODO(review): skip this iteration entirely when user_agent is None and
  // there are no existing session_profiles entries to clear, to avoid the
  // lazy-alloc side-effect of profile_for_session on a no-op global None set.
  // See code-review comment on commit 495dffe (Important #2).
  for ctx_id in self.manager.list_sessions() {
    match self.profile_for_session(ctx_id) {
      Some(profile) => profile.user_agent = user_agent
      None => ()
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
