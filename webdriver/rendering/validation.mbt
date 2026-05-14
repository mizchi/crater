///|
pub(all) enum RenderingValidationError {
  InvalidArgument(String)
  UnsupportedOperation(String)
  UnableToCaptureScreen(String)
}

///|
pub fn RenderingValidationError::name(
  self : RenderingValidationError,
) -> String {
  match self {
    InvalidArgument(_) => "invalid argument"
    UnsupportedOperation(_) => "unsupported operation"
    UnableToCaptureScreen(_) => "unable to capture screen"
  }
}

///|
pub fn RenderingValidationError::message(
  self : RenderingValidationError,
) -> String {
  match self {
    InvalidArgument(message)
    | UnsupportedOperation(message)
    | UnableToCaptureScreen(message) => message
  }
}

///|
pub(all) struct PrintOptions {
  orientation : String
  page_width_cm : Double
  page_height_cm : Double
  printable_width_cm : Double
  printable_height_cm : Double
  background : Bool
}

///|
/// Validate a single print page-range token.
pub fn is_valid_print_page_range(raw : String) -> Bool {
  let value = raw.trim().to_owned()
  if value.length() == 0 {
    return false
  }
  let parts : Array[StringView] = value.split("-").collect()
  if parts.length() == 1 {
    match @protocol.parse_decimal_string(value) {
      Some(v) => v >= 1
      None => false
    }
  } else if parts.length() == 2 {
    let start_text = parts[0].to_owned()
    let end_text = parts[1].to_owned()
    if start_text.length() == 0 && end_text.length() == 0 {
      return false
    }
    if start_text.length() == 0 {
      match @protocol.parse_decimal_string(end_text) {
        Some(end) => end >= 1
        None => false
      }
    } else if end_text.length() == 0 {
      match @protocol.parse_decimal_string(start_text) {
        Some(start) => start >= 1
        None => false
      }
    } else {
      let start = match @protocol.parse_decimal_string(start_text) {
        Some(v) => v
        None => return false
      }
      let end = match @protocol.parse_decimal_string(end_text) {
        Some(v) => v
        None => return false
      }
      start >= 1 && end >= 1 && start <= end
    }
  } else {
    false
  }
}

///|
pub fn normalize_print_options(
  params : Map[String, Json],
) -> Result[PrintOptions, RenderingValidationError] {
  match validate_print_background(params) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_print_margin(params) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_print_orientation(params) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_print_page(params) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_print_page_ranges(params) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_print_scale(params) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_print_shrink_to_fit(params) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  resolve_print_options(params)
}

///|
fn validate_print_background(
  params : Map[String, Json],
) -> Result[Unit, RenderingValidationError] {
  match params.get("background") {
    Some(True) | Some(False) | None => Ok(())
    Some(_) => Err(InvalidArgument("background must be a boolean"))
  }
}

///|
fn validate_print_margin(
  params : Map[String, Json],
) -> Result[Unit, RenderingValidationError] {
  match params.get("margin") {
    None => Ok(())
    Some(Object(margin)) => {
      for margin_side in ["top", "bottom", "left", "right"] {
        match margin.get(margin_side) {
          Some(value) =>
            match
              @protocol.json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(_) => ()
              None =>
                return Err(
                  InvalidArgument("margin values must be non-negative numbers"),
                )
            }
          None => ()
        }
      }
      Ok(())
    }
    Some(_) => Err(InvalidArgument("margin must be an object"))
  }
}

///|
fn validate_print_orientation(
  params : Map[String, Json],
) -> Result[Unit, RenderingValidationError] {
  match params.get("orientation") {
    Some(String("portrait")) | Some(String("landscape")) | None => Ok(())
    Some(String(_)) =>
      Err(InvalidArgument("orientation must be 'portrait' or 'landscape'"))
    Some(_) =>
      Err(InvalidArgument("orientation must be 'portrait' or 'landscape'"))
  }
}

///|
fn validate_print_page(
  params : Map[String, Json],
) -> Result[Unit, RenderingValidationError] {
  match params.get("page") {
    None => Ok(())
    Some(Object(page)) => {
      match page.get("width") {
        Some(value) =>
          if @protocol.json_as_safe_number(value, 0.035, 9007199254740991.0)
            is None {
            return Err(InvalidArgument("page.width must be a number >= 0.035"))
          }
        None => ()
      }
      match page.get("height") {
        Some(value) =>
          if @protocol.json_as_safe_number(value, 0.035, 9007199254740991.0)
            is None {
            return Err(InvalidArgument("page.height must be a number >= 0.035"))
          }
        None => ()
      }
      Ok(())
    }
    Some(_) => Err(InvalidArgument("page must be an object"))
  }
}

///|
fn validate_print_page_ranges(
  params : Map[String, Json],
) -> Result[Unit, RenderingValidationError] {
  match
    @protocol.get_map_field_with_alias(params, "pageRanges", "page_ranges") {
    None => Ok(())
    Some(Array(page_ranges)) => {
      for page_range in page_ranges {
        match page_range {
          Number(n, ..) =>
            if n < 1.0 || n != n.to_int64().to_double() {
              return Err(InvalidArgument("pageRanges entries are invalid"))
            }
          String(v) =>
            if !is_valid_print_page_range(v) {
              return Err(InvalidArgument("pageRanges entries are invalid"))
            }
          _ =>
            return Err(
              InvalidArgument("pageRanges must be an array of strings/integers"),
            )
        }
      }
      Ok(())
    }
    Some(_) =>
      Err(InvalidArgument("pageRanges must be an array of strings/integers"))
  }
}

///|
fn validate_print_scale(
  params : Map[String, Json],
) -> Result[Unit, RenderingValidationError] {
  match params.get("scale") {
    None => Ok(())
    Some(value) =>
      if @protocol.json_as_safe_number(value, 0.1, 2.0) is None {
        Err(InvalidArgument("scale must be a number in [0.1, 2.0]"))
      } else {
        Ok(())
      }
  }
}

///|
fn validate_print_shrink_to_fit(
  params : Map[String, Json],
) -> Result[Unit, RenderingValidationError] {
  match
    @protocol.get_map_field_with_alias(params, "shrinkToFit", "shrink_to_fit") {
    Some(True) | Some(False) | None => Ok(())
    Some(_) => Err(InvalidArgument("shrinkToFit must be a boolean"))
  }
}

///|
fn resolve_print_options(
  params : Map[String, Json],
) -> Result[PrintOptions, RenderingValidationError] {
  let orientation = match params.get("orientation") {
    Some(String("landscape")) => "landscape"
    _ => "portrait"
  }
  let mut page_width_cm = 21.59
  let mut page_height_cm = 27.94
  match params.get("page") {
    Some(Object(page)) => {
      match page.get("width") {
        Some(Number(width, ..)) => page_width_cm = width
        _ => ()
      }
      match page.get("height") {
        Some(Number(height, ..)) => page_height_cm = height
        _ => ()
      }
    }
    _ => ()
  }
  if orientation == "landscape" {
    let current_width = page_width_cm
    page_width_cm = page_height_cm
    page_height_cm = current_width
  }
  let mut margin_top = 0.0
  let mut margin_bottom = 0.0
  let mut margin_left = 0.0
  let mut margin_right = 0.0
  let mut has_margin_top = false
  let mut has_margin_bottom = false
  let mut has_margin_left = false
  let mut has_margin_right = false
  match params.get("margin") {
    Some(Object(margin)) => {
      match margin.get("top") {
        Some(Number(value, ..)) => {
          margin_top = value
          has_margin_top = true
        }
        _ => ()
      }
      match margin.get("bottom") {
        Some(Number(value, ..)) => {
          margin_bottom = value
          has_margin_bottom = true
        }
        _ => ()
      }
      match margin.get("left") {
        Some(Number(value, ..)) => {
          margin_left = value
          has_margin_left = true
        }
        _ => ()
      }
      match margin.get("right") {
        Some(Number(value, ..)) => {
          margin_right = value
          has_margin_right = true
        }
        _ => ()
      }
    }
    _ => ()
  }
  if margin_top >= page_height_cm ||
    margin_bottom >= page_height_cm ||
    margin_left >= page_width_cm ||
    margin_right >= page_width_cm {
    return Err(UnsupportedOperation("Margin consumes entire printable area"))
  }
  let background = match params.get("background") {
    Some(True) => true
    _ => false
  }
  let default_print_margin_cm = 1.0
  let minimum_printable_cm = 2.54 / 72.0
  let effective_margin_right = if has_margin_right {
    margin_right
  } else {
    default_print_margin_cm
  }
  let effective_margin_left = if has_margin_left {
    margin_left
  } else {
    default_print_margin_cm
  }
  let effective_margin_bottom = if has_margin_bottom {
    margin_bottom
  } else {
    default_print_margin_cm
  }
  let effective_margin_top = if has_margin_top {
    margin_top
  } else {
    default_print_margin_cm
  }
  let printable_width_cm = if has_margin_left &&
    margin_left + effective_margin_right > page_width_cm - minimum_printable_cm {
    page_width_cm - minimum_printable_cm
  } else if has_margin_right &&
    margin_right + effective_margin_left > page_width_cm - minimum_printable_cm {
    page_width_cm - minimum_printable_cm
  } else {
    page_width_cm
  }
  let printable_height_cm = if has_margin_top &&
    margin_top + effective_margin_bottom > page_height_cm - minimum_printable_cm {
    page_height_cm - minimum_printable_cm
  } else if has_margin_bottom &&
    margin_bottom + effective_margin_top > page_height_cm - minimum_printable_cm {
    page_height_cm - minimum_printable_cm
  } else {
    page_height_cm
  }
  Ok({
    orientation,
    page_width_cm,
    page_height_cm,
    printable_width_cm,
    printable_height_cm,
    background,
  })
}
