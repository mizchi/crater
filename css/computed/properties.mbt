///|
/// CSS Property Metadata
/// Defines initial values and inheritance behavior for layout properties

///|
/// Whether a property is inherited by default
pub fn is_inherited(property : String) -> Bool {
  match property {
    // Text-related properties (inherited)
    "direction" | "writing-mode" | "text-align" | "line-height" | "font-size" |
    "font-family" | "font-weight" | "font-style" | "color" | "visibility" =>
      true
    // All layout properties are not inherited
    _ => false
  }
}

///|
/// Get the initial value for a property as a string
pub fn initial_value(property : String) -> String {
  match property {
    // Display
    "display" => "block"
    "position" => "relative"
    "float" => "none"
    "clear" => "none"
    // Overflow
    "overflow" | "overflow-x" | "overflow-y" => "visible"
    // Sizing
    "width" | "height" | "min-width" | "min-height" => "auto"
    "max-width" | "max-height" => "none"
    // Box model
    "margin" | "margin-top" | "margin-right" | "margin-bottom" | "margin-left" =>
      "0"
    "padding" | "padding-top" | "padding-right" | "padding-bottom" | "padding-left" =>
      "0"
    "border-width" | "border-top-width" | "border-right-width" | "border-bottom-width" |
    "border-left-width" =>
      "0"
    // Flexbox container
    "flex-direction" => "row"
    "flex-wrap" => "nowrap"
    "justify-content" => "flex-start"
    "align-items" => "stretch"
    "align-content" => "stretch"
    // Flexbox item
    "align-self" => "auto"
    "flex-grow" => "0"
    "flex-shrink" => "1"
    "flex-basis" => "auto"
    // Gap
    "gap" | "row-gap" | "column-gap" => "0"
    // Aspect ratio
    "aspect-ratio" => "auto"
    // Inset
    "top" | "right" | "bottom" | "left" | "inset" => "auto"
    // Grid container
    "grid-template-rows" | "grid-template-columns" => "none"
    "grid-auto-rows" | "grid-auto-columns" => "auto"
    "grid-auto-flow" => "row"
    // Grid item
    "grid-row-start" | "grid-row-end" | "grid-column-start" | "grid-column-end" =>
      "auto"
    // Text (inherited)
    "direction" => "ltr"
    "writing-mode" => "horizontal-tb"
    // Default
    _ => "auto"
  }
}

///|
/// Parse a dimension value from string
pub fn parse_dimension(value : String) -> @types.Dimension {
  let v = value.trim()
  if v == "auto" || v == "none" {
    return @types.Dimension::Auto
  }
  // Try to parse as length (px)
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = try {
        @strconv.parse_double(num_str.to_string())
      } catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n)
    }
    None => ()
  }
  // Try to parse as percentage
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = try {
        @strconv.parse_double(num_str.to_string())
      } catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Percent(n / 100.0)
    }
    None => ()
  }
  // Try to parse as plain number (treated as px)
  let n = try {
    @strconv.parse_double(v.to_string())
  } catch {
    _ => return @types.Dimension::Auto
  }
  @types.Dimension::Length(n)
}

///|
/// Parse display value
pub fn parse_display(value : String) -> @style.Display {
  match value.trim().to_lower() {
    "block" => @style.Display::Block
    "flex" => @style.Display::Flex
    "grid" => @style.Display::Grid
    "none" => @style.Display::None
    _ => @style.Display::Block
  }
}

///|
/// Parse position value
pub fn parse_position(value : String) -> @style.Position {
  match value.trim().to_lower() {
    "absolute" => @style.Position::Absolute
    "relative" | "static" | "fixed" | "sticky" => @style.Position::Relative
    _ => @style.Position::Relative
  }
}

///|
/// Parse float value
pub fn parse_float(value : String) -> @style.Float {
  match value.trim().to_lower() {
    "left" => @style.Float::Left
    "right" => @style.Float::Right
    "none" => @style.Float::None
    _ => @style.Float::None
  }
}

///|
/// Parse clear value
pub fn parse_clear(value : String) -> @style.Clear {
  match value.trim().to_lower() {
    "left" => @style.Clear::Left
    "right" => @style.Clear::Right
    "both" => @style.Clear::Both
    "none" => @style.Clear::None
    _ => @style.Clear::None
  }
}

///|
/// Parse flex-direction value
pub fn parse_flex_direction(value : String) -> @style.FlexDirection {
  match value.trim().to_lower() {
    "row" => @style.FlexDirection::Row
    "row-reverse" => @style.FlexDirection::RowReverse
    "column" => @style.FlexDirection::Column
    "column-reverse" => @style.FlexDirection::ColumnReverse
    _ => @style.FlexDirection::Row
  }
}

///|
/// Parse flex-wrap value
pub fn parse_flex_wrap(value : String) -> @style.FlexWrap {
  match value.trim().to_lower() {
    "nowrap" => @style.FlexWrap::NoWrap
    "wrap" => @style.FlexWrap::Wrap
    "wrap-reverse" => @style.FlexWrap::WrapReverse
    _ => @style.FlexWrap::NoWrap
  }
}

///|
/// Parse alignment value (justify-content, align-items, align-content)
/// Note: flex-start/flex-end are flex-relative (affected by wrap-reverse)
///       start/end are physical/logical (not affected by wrap-reverse)
pub fn parse_alignment(value : String) -> @style.Alignment {
  match value.trim().to_lower() {
    "flex-start" => @style.Alignment::FlexStart
    "flex-end" => @style.Alignment::FlexEnd
    "start" => @style.Alignment::Start
    "end" => @style.Alignment::End
    "center" => @style.Alignment::Center
    "space-between" => @style.Alignment::SpaceBetween
    "space-around" => @style.Alignment::SpaceAround
    "space-evenly" => @style.Alignment::SpaceEvenly
    "stretch" => @style.Alignment::Stretch
    "baseline" => @style.Alignment::Baseline
    _ => @style.Alignment::FlexStart
  }
}

///|
/// Parse align-self value
pub fn parse_align_self(value : String) -> @style.AlignSelf {
  match value.trim().to_lower() {
    "auto" => @style.AlignSelf::Auto
    "flex-start" | "start" => @style.AlignSelf::Start
    "flex-end" | "end" => @style.AlignSelf::End
    "center" => @style.AlignSelf::Center
    "stretch" => @style.AlignSelf::Stretch
    "baseline" => @style.AlignSelf::Baseline
    _ => @style.AlignSelf::Auto
  }
}

///|
/// Parse overflow value
pub fn parse_overflow(value : String) -> @style.Overflow {
  match value.trim().to_lower() {
    "visible" => @style.Overflow::Visible
    "hidden" => @style.Overflow::Hidden
    "scroll" => @style.Overflow::Scroll
    "auto" => @style.Overflow::Auto
    _ => @style.Overflow::Visible
  }
}

///|
/// Parse grid-auto-flow value
pub fn parse_grid_auto_flow(value : String) -> @style.GridAutoFlow {
  match value.trim().to_lower() {
    "row" => @style.GridAutoFlow::Row
    "column" => @style.GridAutoFlow::Column
    "row dense" | "dense row" => @style.GridAutoFlow::RowDense
    "column dense" | "dense column" => @style.GridAutoFlow::ColumnDense
    _ => @style.GridAutoFlow::Row
  }
}

///|
/// Parse a number value
pub fn parse_number(value : String) -> Double {
  try {
    @strconv.parse_double(value.trim().to_string())
  } catch {
    _ => 0.0
  }
}

///|
/// Parse an integer value
pub fn parse_integer(value : String) -> Int {
  try {
    @strconv.parse_int(value.trim().to_string())
  } catch {
    _ => 0
  }
}

///|
/// Parse a single track sizing value from string
/// Supports: length (px), percentage, fr, auto, min-content, max-content
fn parse_single_track(value : String) -> @style.TrackSizingFunction? {
  let v = value.trim()
  if v.is_empty() {
    return None
  }
  // auto
  if v == "auto" {
    return Some(@style.TrackSizingFunction::Auto)
  }
  // min-content
  if v == "min-content" {
    return Some(@style.TrackSizingFunction::MinContent)
  }
  // max-content
  if v == "max-content" {
    return Some(@style.TrackSizingFunction::MaxContent)
  }
  // none
  if v == "none" {
    return None
  }
  // fr unit
  match v.strip_suffix("fr") {
    Some(num_str) => {
      let n = try { @strconv.parse_double(num_str.to_string().trim()) } catch {
        _ => return None
      }
      return Some(@style.TrackSizingFunction::Fr(n))
    }
    None => ()
  }
  // percentage
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = try { @strconv.parse_double(num_str.to_string().trim()) } catch {
        _ => return None
      }
      return Some(@style.TrackSizingFunction::Percent(n / 100.0))
    }
    None => ()
  }
  // px unit
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = try { @strconv.parse_double(num_str.to_string().trim()) } catch {
        _ => return None
      }
      return Some(@style.TrackSizingFunction::Length(n))
    }
    None => ()
  }
  // Plain number (treated as px)
  let n = try { @strconv.parse_double(v.to_string()) } catch {
    _ => return None
  }
  Some(@style.TrackSizingFunction::Length(n))
}

///|
/// Parse grid-template-columns or grid-template-rows value
/// Supports space-separated track sizes: "100px 200px 1fr"
/// Note: minmax() and repeat() are not supported in this simple parser
pub fn parse_grid_template_tracks(value : String) -> Array[@style.TrackSizingFunction] {
  let result : Array[@style.TrackSizingFunction] = []
  let v = value.trim()
  if v.is_empty() || v == "none" {
    return result
  }
  // Split by whitespace
  let parts = v.split(" ")
  for part in parts {
    let part_str = part.to_string().trim()
    if part_str.is_empty() {
      continue
    }
    match parse_single_track(part_str.to_string()) {
      Some(track) => result.push(track)
      None => ()
    }
  }
  result
}

///|
/// Parse aspect-ratio value
pub fn parse_aspect_ratio(value : String) -> Double? {
  let v = value.trim()
  if v == "auto" {
    return None
  }
  // Check for ratio format: "16 / 9" or "16/9"
  if v.contains("/") {
    // Find the slash position
    let mut slash_pos = -1
    for i = 0; i < v.length(); i = i + 1 {
      if v[i].to_int().unsafe_to_char() == '/' {
        slash_pos = i
        break
      }
    }
    if slash_pos > 0 {
      // Use view slicing
      let width_str = try { v[:slash_pos].to_string().trim() } catch { _ => "" }
      let height_str = try {
        v[slash_pos + 1:].to_string().trim()
      } catch {
        _ => ""
      }
      let w = try { @strconv.parse_double(width_str.to_string()) } catch {
        _ => return None
      }
      let h = try { @strconv.parse_double(height_str.to_string()) } catch {
        _ => return None
      }
      if h != 0.0 {
        return Some(w / h)
      }
      return None
    }
  }
  // Try parsing as a single number
  let n = try { @strconv.parse_double(v.to_string()) } catch {
    _ => return None
  }
  Some(n)
}
