///|
/// Validate input context parameter and return context ID.
fn BidiProtocol::validate_input_context(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let ctx_id = match get_param_raw(params, "context") {
    Some(String(id)) => id
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "context must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing context")
      return None
    }
  }
  if !self.manager.has_session(ctx_id) {
    self.send_error(request_id, "no such frame", "Unknown context: " + ctx_id)
    return None
  }
  Some(ctx_id)
}

///|
/// Validate pointer common property types/ranges.
fn BidiProtocol::validate_pointer_common_properties(
  self : BidiProtocol,
  request_id : Int,
  action_map : Map[String, Json],
) -> Bool {
  match action_map.get("width") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer width must be a non-negative integer",
        )
        return false
      }
    None => ()
  }
  match action_map.get("height") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 9007199254740991.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer height must be a non-negative integer",
        )
        return false
      }
    None => ()
  }
  match action_map.get("pressure") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer pressure must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("tangentialPressure") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer tangentialPressure must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("twist") {
    Some(value) =>
      if json_as_safe_int(value, 0.0, 359.0) is None {
        self.send_error(
          request_id, "invalid argument", "pointer twist must be an integer in [0, 359]",
        )
        return false
      }
    None => ()
  }
  match action_map.get("altitudeAngle") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer altitudeAngle must be a number",
      )
      return false
    }
    None => ()
  }
  match action_map.get("azimuthAngle") {
    Some(Number(_)) => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pointer azimuthAngle must be a number",
      )
      return false
    }
    None => ()
  }
  true
}

///|
/// Resolve pointer/wheel origin with integer offsets.
fn BidiProtocol::resolve_pointer_origin(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  origin : Json?,
  offset_x : Double,
  offset_y : Double,
  allow_pointer_origin : Bool,
) -> (Double, Double, String)? {
  match origin {
    None | Some(String("viewport")) => Some((offset_x, offset_y, ""))
    Some(String("pointer")) =>
      if allow_pointer_origin {
        Some(
          (
            self.input_pointer_x.get(ctx_id).unwrap_or(0.0) + offset_x,
            self.input_pointer_y.get(ctx_id).unwrap_or(0.0) + offset_y,
            self.input_pointer_target_shared.get(ctx_id).unwrap_or(""),
          ),
        )
      } else {
        self.send_error(
          request_id, "invalid argument", "pointer origin is not supported for this action",
        )
        None
      }
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "origin must be 'viewport', 'pointer', or element origin",
      )
      None
    }
    Some(Object(origin_map)) => {
      let origin_type = match origin_map.get("type") {
        Some(String(s)) => s
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.type must be a string",
          )
          return None
        }
      }
      if origin_type != "element" {
        self.send_error(
          request_id, "invalid argument", "origin.type must be 'element'",
        )
        return None
      }
      let element_obj = match origin_map.get("element") {
        Some(Object(elem)) => elem
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.element must be an object",
          )
          return None
        }
      }
      let shared_id = match element_obj.get("sharedId") {
        Some(String(id)) => id
        _ => {
          self.send_error(
            request_id, "invalid argument", "origin.element.sharedId must be a string",
          )
          return None
        }
      }
      if !has_runtime_shared_node(shared_id) ||
        !runtime_shared_node_is_element(shared_id) {
        self.send_error(
          request_id,
          "no such element",
          "Unknown element: " + shared_id,
        )
        return None
      }
      let center_json = @json.parse(
        get_runtime_shared_node_center_json(shared_id),
      ) catch {
        _ => make_object({})
      }
      let center_x = match get_field(center_json, "x") {
        Some(Number(n, ..)) => n
        _ => 0.0
      }
      let center_y = match get_field(center_json, "y") {
        Some(Number(n, ..)) => n
        _ => 0.0
      }
      Some((center_x + offset_x, center_y + offset_y, shared_id))
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "origin must be a string or object",
      )
      None
    }
  }
}

///|
/// Validate pointer target coordinates against viewport.
fn BidiProtocol::ensure_pointer_within_viewport(
  self : BidiProtocol,
  request_id : Int,
  x : Double,
  y : Double,
) -> Bool {
  if x < 0.0 || y < 0.0 || x > 1024.0 || y > 768.0 {
    self.send_error(
      request_id, "move target out of bounds", "Target coordinate is outside viewport",
    )
    false
  } else {
    true
  }
}

///|
/// Absolute value helper for doubles.
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
/// Parse safe integer JSON value.
fn json_as_safe_int(value : Json, min : Double, max : Double) -> Int? {
  match value {
    Number(n, ..) =>
      if n == n.to_int64().to_double() && n >= min && n <= max {
        Some(n.to_int64().to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse safe JSON number value.
fn json_as_safe_number(value : Json, min : Double, max : Double) -> Double? {
  match value {
    Number(n, ..) => if n >= min && n <= max { Some(n) } else { None }
    _ => None
  }
}

///|
/// Normalize WebDriver special key value for internal state tracking.
fn normalize_input_key(value : String) -> String {
  match value {
    "\uE003" => "Backspace"
    "\uE004" => "Tab"
    "\uE006" | "\uE007" => "Enter"
    "\uE008" | "\uE050" => "Shift"
    "\uE009" | "\uE051" => "Control"
    "\uE00A" | "\uE052" => "Alt"
    "\uE00C" => "Escape"
    "\uE03D" | "\uE053" => "Meta"
    _ => value
  }
}

///|
/// Convert normalized key names back to WebDriver key values for dispatch.
fn restore_input_key_for_dispatch(value : String) -> String {
  match value {
    "Shift" => "\uE008"
    "Control" => "\uE009"
    "Alt" => "\uE00A"
    "Meta" => "\uE03D"
    "Enter" => "\uE006"
    "Escape" => "\uE00C"
    _ => value
  }
}

///|
/// Push pressed key in stack order.
fn BidiProtocol::push_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Unit {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  keys.push(key)
  self.input_pressed_keys[ctx_id] = keys
}

///|
/// Check whether key is currently pressed in the context.
fn BidiProtocol::has_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Bool {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  for existing in keys {
    if existing == key {
      return true
    }
  }
  false
}

///|
/// Remove first matching pressed key.
fn BidiProtocol::remove_pressed_key(
  self : BidiProtocol,
  ctx_id : String,
  key : String,
) -> Unit {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let filtered : Array[String] = []
  let mut removed = false
  for existing in keys {
    if !removed && existing == key {
      removed = true
    } else {
      filtered.push(existing)
    }
  }
  if filtered.length() == 0 {
    self.input_pressed_keys.remove(ctx_id)
  } else {
    self.input_pressed_keys[ctx_id] = filtered
  }
}

///|
/// Resolve modifier booleans from pressed key state.
fn BidiProtocol::resolve_input_modifiers(
  self : BidiProtocol,
  ctx_id : String,
  current_key : String,
  include_current : Bool,
) -> (Bool, Bool, Bool, Bool) {
  let keys = self.input_pressed_keys.get(ctx_id).unwrap_or([])
  let mut ctrl = false
  let mut alt = false
  let mut shift = false
  let mut meta = false
  for key in keys {
    if key == "Control" {
      ctrl = true
    } else if key == "Alt" {
      alt = true
    } else if key == "Shift" {
      shift = true
    } else if key == "Meta" {
      meta = true
    }
  }
  if include_current {
    if current_key == "Control" {
      ctrl = true
    } else if current_key == "Alt" {
      alt = true
    } else if current_key == "Shift" {
      shift = true
    } else if current_key == "Meta" {
      meta = true
    }
  }
  (ctrl, alt, shift, meta)
}

///|
/// Convert pointer button to bit mask compatible with MouseEvent.buttons.
fn button_to_mask(button : Int) -> Int {
  match button {
    0 => 1
    1 => 4
    2 => 2
    _ => 0
  }
}

///|
/// Check whether button bit mask exists in state.
fn button_state_contains(state : Int, mask : Int) -> Bool {
  if mask == 1 {
    state % 2 == 1
  } else if mask == 2 {
    state / 2 % 2 == 1
  } else if mask == 4 {
    state / 4 % 2 == 1
  } else {
    false
  }
}

///|
/// Add button into button state bitfield.
fn button_state_add(state : Int, button : Int) -> Int {
  let mask = button_to_mask(button)
  if mask == 0 || button_state_contains(state, mask) {
    state
  } else {
    state + mask
  }
}

///|
/// Remove button from button state bitfield.
fn button_state_remove(state : Int, button : Int) -> Int {
  let mask = button_to_mask(button)
  if mask == 0 || !button_state_contains(state, mask) {
    state
  } else {
    state - mask
  }
}
