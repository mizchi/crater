///|
/// Handle browsingContext.print with WPT-focused validation.
fn BidiProtocol::handle_print(
  self : BidiProtocol,
  request : BidiRequest,
) -> Unit {
  match self.resolve_print_data(request.id, request.params) {
    Some(data) => {
      let result = make_object({ "data": Json::string(data) })
      self.send_success(request.id, Some(result))
    }
    None => ()
  }
}

///|
fn BidiProtocol::handle_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit {
  match self.resolve_print_data(request_id, params) {
    Some(data) => self.send_success(request_id, Some(Json::string(data)))
    None => ()
  }
}

///|
fn BidiProtocol::resolve_print_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let params = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let ctx_id = match params.get("context") {
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

  match params.get("background") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "background must be a boolean",
      )
      return None
    }
  }

  match params.get("margin") {
    None => ()
    Some(Object(margin)) =>
      for margin_side in ["top", "bottom", "left", "right"] {
        match margin.get(margin_side) {
          Some(value) =>
            match json_as_safe_number(value, 0.0, 9007199254740991.0) {
              Some(_) => ()
              None => {
                self.send_error(
                  request_id, "invalid argument", "margin values must be non-negative numbers",
                )
                return None
              }
            }
          None => ()
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "margin must be an object",
      )
      return None
    }
  }

  match params.get("orientation") {
    Some(String("portrait")) | Some(String("landscape")) | None => ()
    Some(String(_)) => {
      self.send_error(
        request_id, "invalid argument", "orientation must be 'portrait' or 'landscape'",
      )
      return None
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "orientation must be 'portrait' or 'landscape'",
      )
      return None
    }
  }

  match params.get("page") {
    None => ()
    Some(Object(page)) => {
      match page.get("width") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request_id, "invalid argument", "page.width must be a number >= 0.035",
            )
            return None
          }
        None => ()
      }
      match page.get("height") {
        Some(value) =>
          if json_as_safe_number(value, 0.035, 9007199254740991.0) is None {
            self.send_error(
              request_id, "invalid argument", "page.height must be a number >= 0.035",
            )
            return None
          }
        None => ()
      }
    }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "page must be an object")
      return None
    }
  }

  match get_map_field_with_alias(params, "pageRanges", "page_ranges") {
    None => ()
    Some(Array(page_ranges)) =>
      for page_range in page_ranges {
        match page_range {
          Number(n, ..) =>
            if n < 1.0 || n != n.to_int64().to_double() {
              self.send_error(
                request_id, "invalid argument", "pageRanges entries are invalid",
              )
              return None
            }
          String(v) =>
            if !is_valid_print_page_range(v) {
              self.send_error(
                request_id, "invalid argument", "pageRanges entries are invalid",
              )
              return None
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "pageRanges must be an array of strings/integers",
            )
            return None
          }
        }
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "pageRanges must be an array of strings/integers",
      )
      return None
    }
  }

  match params.get("scale") {
    None => ()
    Some(value) =>
      if json_as_safe_number(value, 0.1, 2.0) is None {
        self.send_error(
          request_id, "invalid argument", "scale must be a number in [0.1, 2.0]",
        )
        return None
      }
  }

  match get_map_field_with_alias(params, "shrinkToFit", "shrink_to_fit") {
    Some(True) | Some(False) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "shrinkToFit must be a boolean",
      )
      return None
    }
  }

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
    self.send_error(
      request_id, "unsupported operation", "Margin consumes entire printable area",
    )
    return None
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
  let synthetic_details = self.resolve_synthetic_print_details(
    ctx_id, params, printable_width_cm, printable_height_cm,
  )
  let signature = match synthetic_details.get("signature") {
    Some(String(value)) if value != "" => value
    _ => self.current_context_url(ctx_id)
  }
  let pages = match synthetic_details.get("pages") {
    Some(Array(values)) => values
    _ => []
  }
  let meta = make_object({
    "kind": Json::string("crater.synthetic.print"),
    "orientation": Json::string(orientation),
    "pageWidthCm": Json::number(printable_width_cm),
    "pageHeightCm": Json::number(printable_height_cm),
    "background": Json::boolean(background),
    "signature": Json::string(signature),
    "pages": Json::array(pages),
  })
  Some(synthetic_print_pdf_from_meta(meta))
}

///|
/// Validate a single print page-range token.
fn is_valid_print_page_range(raw : String) -> Bool {
  let value = raw.trim().to_owned()
  if value.length() == 0 {
    return false
  }
  match find_substring(value, "-", 0) {
    Some(first_dash) => {
      match find_substring(value, "-", first_dash + 1) {
        Some(_) => return false
        None => ()
      }
      if first_dash == 0 {
        let end_text = value.unsafe_substring(start=1, end=value.length())
        match parse_decimal_string(end_text) {
          Some(v) => v >= 1
          None => false
        }
      } else if first_dash == value.length() - 1 {
        let start_text = value.unsafe_substring(start=0, end=first_dash)
        match parse_decimal_string(start_text) {
          Some(v) => v >= 1
          None => false
        }
      } else {
        let start_text = value.unsafe_substring(start=0, end=first_dash)
        let end_text = value.unsafe_substring(
          start=first_dash + 1,
          end=value.length(),
        )
        let start = match parse_decimal_string(start_text) {
          Some(v) => v
          None => return false
        }
        let end = match parse_decimal_string(end_text) {
          Some(v) => v
          None => return false
        }
        start >= 1 && end >= 1 && start <= end
      }
    }
    None =>
      match parse_decimal_string(value) {
        Some(v) => v >= 1
        None => false
      }
  }
}
