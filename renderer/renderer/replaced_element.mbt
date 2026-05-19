///|
/// Replaced element sizing and form-control helpers.

///|
/// Check if element is a replaced element (img, input, video, etc.)
/// Replaced elements have intrinsic dimensions and don't contain text
fn is_replaced_element(tag : String) -> Bool {
  match tag.to_lower() {
    "img"
    | "input"
    | "textarea"
    | "select"
    | "meter"
    | "progress"
    | "video"
    | "audio"
    | "canvas"
    | "svg"
    | "iframe"
    | "object"
    | "embed" => true
    _ => false
  }
}

///|
/// Create a MeasureFunc for image with intrinsic dimensions
fn create_image_measure(
  intrinsic_width : Double,
  intrinsic_height : Double,
) -> @layout_types.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @layout_types.IntrinsicSize {
      // If intrinsic size is specified, use it
      // Otherwise default to 0
      let width = if intrinsic_width > 0.0 { intrinsic_width } else { 0.0 }
      let height = if intrinsic_height > 0.0 { intrinsic_height } else { 0.0 }

      // For images with intrinsic dimensions, min and max are the same
      {
        min_width: width,
        max_width: width,
        min_height: height,
        max_height: height,
      }
    },
  }
}

///|
fn broken_img_alt_uses_non_replaced_overflow_box(style : @style.Style) -> Bool {
  style.overflow_x != @types.Visible || style.overflow_y != @types.Visible
}

///|
/// Create a MeasureFunc for input elements with intrinsic dimensions
fn create_input_measure(
  intrinsic_width : Double,
  intrinsic_height : Double,
) -> @layout_types.MeasureFunc {
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @layout_types.IntrinsicSize {
      // Input elements have fixed intrinsic dimensions based on type
      {
        min_width: intrinsic_width,
        max_width: intrinsic_width,
        min_height: intrinsic_height,
        max_height: intrinsic_height,
      }
    },
  }
}

///|
fn is_text_like_input_type(input_type : String) -> Bool {
  match input_type {
    "text" | "password" | "search" | "email" | "url" | "tel" | "number" => true
    _ => false
  }
}

///|
fn mask_password_value(value : String) -> String {
  let masked = StringBuilder::new()
  for _ in value {
    masked.write_char('*')
  }
  masked.to_string()
}

///|
fn resolve_input_paint_text(
  input_type : String,
  attributes : Map[String, String],
) -> String? {
  match input_type {
    "button" =>
      match attributes.get("value") {
        Some(value) if !value.is_empty() => return Some(value)
        _ => return None
      }
    "submit" =>
      match attributes.get("value") {
        Some(value) if !value.is_empty() => return Some(value)
        _ => return Some("Submit")
      }
    "reset" =>
      match attributes.get("value") {
        Some(value) if !value.is_empty() => return Some(value)
        _ => return Some("Reset")
      }
    _ => ()
  }
  if !is_text_like_input_type(input_type) {
    return None
  }
  match attributes.get("value") {
    Some(value) if !value.is_empty() =>
      if input_type == "password" {
        Some(mask_password_value(value))
      } else {
        Some(value)
      }
    _ =>
      match attributes.get("placeholder") {
        Some(placeholder) if !placeholder.is_empty() => Some(placeholder)
        _ => None
      }
  }
}

///|
fn input_uses_placeholder_text(
  input_type : String,
  attributes : Map[String, String],
) -> Bool {
  if !is_text_like_input_type(input_type) {
    return false
  }
  match attributes.get("value") {
    Some(value) if !value.is_empty() => false
    _ =>
      match attributes.get("placeholder") {
        Some(placeholder) => !placeholder.is_empty()
        None => false
      }
  }
}

///|
fn inset_is_definite(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Length(_) | @types.Percent(_) => true
    _ => false
  }
}

///|
fn should_preserve_auto_replaced_width(style : @style.Style) -> Bool {
  if style.width != @types.Auto {
    return false
  }
  match style.position {
    @types.Absolute | @types.Fixed =>
      inset_is_definite(style.inset.left) &&
      inset_is_definite(style.inset.right)
    _ => false
  }
}

///|
fn should_preserve_auto_replaced_height(style : @style.Style) -> Bool {
  if style.height != @types.Auto {
    return false
  }
  match style.position {
    @types.Absolute | @types.Fixed =>
      inset_is_definite(style.inset.top) &&
      inset_is_definite(style.inset.bottom)
    _ => false
  }
}

///|
fn is_definite_replaced_size(dim : @types.Dimension) -> Bool {
  match dim {
    @types.Length(_) => true
    _ => false
  }
}

///|
fn should_apply_intrinsic_replaced_aspect_ratio(
  width : @types.Dimension,
  height : @types.Dimension,
) -> Bool {
  !(is_definite_replaced_size(width) && is_definite_replaced_size(height))
}

///|
/// Estimate a control character advance from the active text metrics provider.
/// Falls back to the renderer's historical 0.5em approximation.
fn resolve_control_char_width(
  font_size : Double,
  line_height : Double,
  writing_mode : @style.WritingMode,
) -> Double {
  let zero_measure = create_text_measure_with_provider(
    "0",
    font_size,
    line_height,
    @style.WhiteSpace::Nowrap,
    writing_mode,
  )
  let intrinsic = (zero_measure.func)(9999.0, 9999.0)
  let measured = if intrinsic.max_width > 0.0 {
    intrinsic.max_width
  } else if intrinsic.min_width > 0.0 {
    intrinsic.min_width
  } else {
    0.0
  }
  if measured > 0.0 {
    measured
  } else {
    font_size * 0.5
  }
}

///|
fn resolve_control_label_width(
  label : String,
  font_size : Double,
  line_height : Double,
  writing_mode : @style.WritingMode,
) -> Double {
  if label.is_empty() {
    return 0.0
  }
  let label_measure = create_text_measure_with_provider(
    label,
    font_size,
    line_height,
    @style.WhiteSpace::Nowrap,
    writing_mode,
  )
  let intrinsic = (label_measure.func)(9999.0, 9999.0)
  let char_width = resolve_control_char_width(
    font_size, line_height, writing_mode,
  )
  let mut label_cols = 0
  let mut has_non_ascii = false
  for c in label.iter() {
    if c.to_int() > 127 {
      has_non_ascii = true
    }
    label_cols = label_cols + char_display_width(c)
  }
  let fallback_width = label_cols.to_double() * char_width
  let measured_width = if intrinsic.max_width > 0.0 {
    intrinsic.max_width
  } else if intrinsic.min_width > 0.0 {
    intrinsic.min_width
  } else {
    fallback_width
  }
  if has_non_ascii && measured_width < fallback_width {
    fallback_width
  } else {
    measured_width
  }
}

///|
/// Create a MeasureFunc for br elements
/// In horizontal writing-mode, br has 0 width and line-height height.
/// In vertical writing-mode, br advances one line on x-axis.
fn create_br_measure(
  line_height : Double,
  font_size : Double,
  writing_mode : @style.WritingMode,
) -> @layout_types.MeasureFunc {
  let is_vertical = writing_mode.is_vertical()
  let leading = if line_height > font_size {
    line_height - font_size
  } else {
    0.0
  }
  let base_advance = if font_size > 0.0 {
    font_size + leading * 0.1
  } else {
    line_height
  }
  let advance = if base_advance > 0.0 { base_advance } else { 0.0 }
  {
    func: fn(
      _available_width : Double,
      _available_height : Double,
    ) -> @layout_types.IntrinsicSize {
      if is_vertical {
        // Vertical flow: br occupies one column advance.
        {
          min_width: advance,
          max_width: advance,
          min_height: 0.0,
          max_height: 0.0,
        }
      } else {
        // Horizontal flow: br occupies one line advance.
        {
          min_width: 0.0,
          max_width: 0.0,
          min_height: advance,
          max_height: advance,
        }
      }
    },
  }
}
