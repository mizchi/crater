///|
/// CSS Property Metadata
/// Defines initial values and inheritance behavior for layout properties

///|
/// Whether a property is inherited by default
pub fn is_inherited(property : String) -> Bool {
  match property {
    // Text-related properties (inherited)
    "direction"
    | "writing-mode"
    | "text-align"
    | "line-height"
    | "font-size"
    | "font-family"
    | "font-weight"
    | "font-style"
    | "color"
    | "visibility" => true
    // Table properties that are inherited
    "caption-side" | "border-collapse" | "border-spacing" => true
    // Containment is not inherited
    "contain" => false
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
    "margin"
    | "margin-top"
    | "margin-right"
    | "margin-bottom"
    | "margin-left" => "0"
    "padding"
    | "padding-top"
    | "padding-right"
    | "padding-bottom"
    | "padding-left" => "0"
    "border-width"
    | "border-top-width"
    | "border-right-width"
    | "border-bottom-width"
    | "border-left-width" => "0"
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
    // Gap (grid-gap is legacy alias)
    "gap"
    | "row-gap"
    | "column-gap"
    | "grid-gap"
    | "grid-row-gap"
    | "grid-column-gap" => "0"
    // Aspect ratio
    "aspect-ratio" => "auto"
    // Inset
    "top" | "right" | "bottom" | "left" | "inset" => "auto"
    // Grid container
    "grid-template-rows" | "grid-template-columns" => "none"
    "grid-auto-rows" | "grid-auto-columns" => "auto"
    "grid-auto-flow" => "row"
    // Grid item
    "grid-row-start"
    | "grid-row-end"
    | "grid-column-start"
    | "grid-column-end" => "auto"
    // Text (inherited)
    "direction" => "ltr"
    "writing-mode" => "horizontal-tb"
    // Containment
    "contain" => "none"
    // Table properties
    "caption-side" => "top"
    "border-collapse" => "separate"
    "border-spacing" => "0"
    "table-layout" => "auto"
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
  // Intrinsic sizing keywords
  if v == "min-content" {
    return @types.Dimension::MinContent
  }
  if v == "max-content" {
    return @types.Dimension::MaxContent
  }
  // fit-content(<length-percentage>)
  if v.has_prefix("fit-content(") && v.has_suffix(")") {
    // Extract content between "fit-content(" and ")"
    let v_str = v.to_string()
    let inner = v_str[12:v_str.length() - 1].to_string() catch {
      _ => return @types.Dimension::Auto
    }
    // Parse the inner value as a length
    match inner.strip_suffix("px") {
      Some(num_str) => {
        let n = @strconv.parse_double(num_str.to_string()) catch {
          _ => return @types.Dimension::Auto
        }
        return @types.Dimension::FitContent(n)
      }
      None => ()
    }
    // Try percentage
    match inner.strip_suffix("%") {
      Some(num_str) => {
        let n = @strconv.parse_double(num_str.to_string()) catch {
          _ => return @types.Dimension::Auto
        }
        // For fit-content, percentage is relative to available space
        // Store as negative to differentiate from length
        return @types.Dimension::FitContent(n)
      }
      None => ()
    }
    return @types.Dimension::Auto
  }
  // Try to parse as length (px)
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n)
    }
    None => ()
  }
  // Try to parse as percentage
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Percent(n / 100.0)
    }
    None => ()
  }
  // Try to parse as plain number (treated as px)
  let n = @strconv.parse_double(v.to_string()) catch {
    _ => return @types.Dimension::Auto
  }
  @types.Dimension::Length(n)
}

///|
/// Extract border width from shorthand value
/// Handles formats like "3px", "solid 3px", "1px solid red", "none", etc.
pub fn extract_border_width(value : String) -> @types.Dimension {
  let v = value.trim()

  // Handle "none" case
  if v == "none" || v == "0" {
    return @types.Dimension::Length(0.0)
  }

  // Split by whitespace and look for a dimension value
  let parts = split_whitespace(v.to_string())
  for part in parts {
    // Check if this part looks like a dimension (ends with px or is a number)
    if part.has_suffix("px") {
      match part.strip_suffix("px") {
        Some(num_str) => {
          let n = @strconv.parse_double(num_str.to_string()) catch {
            _ => continue
          }
          return @types.Dimension::Length(n)
        }
        None => continue
      }
    }
    // Try plain number
    let first_char = part[0].to_int()
    if first_char >= '0'.to_int() && first_char <= '9'.to_int() {
      let n = @strconv.parse_double(part) catch { _ => continue }
      return @types.Dimension::Length(n)
    }
  }

  // Default: no border
  @types.Dimension::Length(0.0)
}

///|
/// Split string by whitespace into parts
fn split_whitespace(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ' ' || c == '\t' || c == '\n' {
      if current.to_string().length() > 0 {
        result.push(current.to_string())
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    result.push(current.to_string())
  }
  result
}

///|
/// Parse display value
pub fn parse_display(value : String) -> @types.Display {
  match value.trim().to_lower() {
    "block" => @types.Display::Block
    "inline" => @types.Display::Inline
    "inline-block" => @types.Display::InlineBlock
    "flex" => @types.Display::Flex
    "inline-flex" => @types.Display::InlineFlex
    "grid" => @types.Display::Grid
    "inline-grid" => @types.Display::InlineGrid
    "none" => @types.Display::None
    "contents" => @types.Display::Contents
    "flow-root" => @types.Display::FlowRoot
    // Table display types
    "table" => @types.Display::Table
    "inline-table" => @types.Display::InlineTable
    "table-row" => @types.Display::TableRow
    "table-cell" => @types.Display::TableCell
    "table-caption" => @types.Display::TableCaption
    "table-row-group" => @types.Display::TableRowGroup
    "table-header-group" => @types.Display::TableHeaderGroup
    "table-footer-group" => @types.Display::TableFooterGroup
    "table-column" => @types.Display::TableColumn
    "table-column-group" => @types.Display::TableColumnGroup
    _ => @types.Display::Block
  }
}

///|
/// Parse position value
pub fn parse_position(value : String) -> @types.Position {
  match value.trim().to_lower() {
    "static" => @types.Position::Static
    "absolute" => @types.Position::Absolute
    "fixed" => @types.Position::Fixed
    "relative" | "sticky" => @types.Position::Relative
    _ => @types.Position::Static // Default is static
  }
}

///|
/// Parse float value
pub fn parse_float(value : String) -> @types.Float {
  match value.trim().to_lower() {
    "left" => @types.Float::Left
    "right" => @types.Float::Right
    "none" => @types.Float::None
    _ => @types.Float::None
  }
}

///|
/// Parse clear value
pub fn parse_clear(value : String) -> @types.Clear {
  match value.trim().to_lower() {
    "left" => @types.Clear::Left
    "right" => @types.Clear::Right
    "both" => @types.Clear::Both
    "none" => @types.Clear::None
    _ => @types.Clear::None
  }
}

///|
/// Parse flex-direction value
pub fn parse_flex_direction(value : String) -> @types.FlexDirection {
  match value.trim().to_lower() {
    "row" => @types.FlexDirection::Row
    "row-reverse" => @types.FlexDirection::RowReverse
    "column" => @types.FlexDirection::Column
    "column-reverse" => @types.FlexDirection::ColumnReverse
    _ => @types.FlexDirection::Row
  }
}

///|
/// Parse flex-wrap value
pub fn parse_flex_wrap(value : String) -> @types.FlexWrap {
  match value.trim().to_lower() {
    "nowrap" => @types.FlexWrap::NoWrap
    "wrap" => @types.FlexWrap::Wrap
    "wrap-reverse" => @types.FlexWrap::WrapReverse
    _ => @types.FlexWrap::NoWrap
  }
}

///|
/// Parse alignment value (justify-content, align-items, align-content)
/// Note: flex-start/flex-end are flex-relative (affected by wrap-reverse)
///       start/end are physical/logical (not affected by wrap-reverse)
pub fn parse_alignment(value : String) -> @types.Alignment {
  match value.trim().to_lower() {
    "flex-start" => @types.Alignment::FlexStart
    "flex-end" => @types.Alignment::FlexEnd
    "start" => @types.Alignment::Start
    "end" => @types.Alignment::End
    "center" => @types.Alignment::Center
    "space-between" => @types.Alignment::SpaceBetween
    "space-around" => @types.Alignment::SpaceAround
    "space-evenly" => @types.Alignment::SpaceEvenly
    "stretch" => @types.Alignment::Stretch
    "baseline" => @types.Alignment::Baseline
    _ => @types.Alignment::FlexStart
  }
}

///|
/// Parse align-self value
pub fn parse_align_self(value : String) -> @types.AlignSelf {
  match value.trim().to_lower() {
    "auto" => @types.AlignSelf::Auto
    "flex-start" | "start" => @types.AlignSelf::Start
    "flex-end" | "end" => @types.AlignSelf::End
    "center" => @types.AlignSelf::Center
    "stretch" => @types.AlignSelf::Stretch
    "baseline" => @types.AlignSelf::Baseline
    _ => @types.AlignSelf::Auto
  }
}

///|
/// Parse overflow value
pub fn parse_overflow(value : String) -> @types.Overflow {
  match value.trim().to_lower() {
    "visible" => @types.Overflow::Visible
    "hidden" => @types.Overflow::Hidden
    "scroll" => @types.Overflow::Scroll
    "auto" => @types.Overflow::Auto
    _ => @types.Overflow::Visible
  }
}

///|
/// Parse white-space value
pub fn parse_white_space(value : String) -> @style.WhiteSpace {
  match value.trim().to_lower() {
    "normal" => @style.WhiteSpace::Normal
    "nowrap" => @style.WhiteSpace::Nowrap
    "pre" => @style.WhiteSpace::Pre
    "pre-wrap" => @style.WhiteSpace::PreWrap
    "pre-line" => @style.WhiteSpace::PreLine
    _ => @style.WhiteSpace::Normal
  }
}

///|
/// Parse writing-mode value
pub fn parse_writing_mode(value : String) -> @style.WritingMode {
  match value.trim().to_lower() {
    "horizontal-tb" => @style.WritingMode::HorizontalTb
    "vertical-rl" => @style.WritingMode::VerticalRl
    "vertical-lr" => @style.WritingMode::VerticalLr
    // Legacy values
    "lr" | "lr-tb" | "rl" | "rl-tb" => @style.WritingMode::HorizontalTb
    "tb" | "tb-rl" => @style.WritingMode::VerticalRl
    "tb-lr" => @style.WritingMode::VerticalLr
    _ => @style.WritingMode::HorizontalTb
  }
}

///|
/// Parse direction value (ltr/rtl)
pub fn parse_direction(value : String) -> @style.Direction {
  match value.trim().to_lower() {
    "rtl" => @style.Direction::Rtl
    "ltr" | _ => @style.Direction::Ltr
  }
}

///|
/// Parse grid-auto-flow value
pub fn parse_grid_auto_flow(value : String) -> @types.GridAutoFlow {
  match value.trim().to_lower() {
    "row" => @types.GridAutoFlow::Row
    "column" => @types.GridAutoFlow::Column
    "row dense" | "dense row" => @types.GridAutoFlow::RowDense
    "column dense" | "dense column" => @types.GridAutoFlow::ColumnDense
    _ => @types.GridAutoFlow::Row
  }
}

///|
/// Parse a grid placement value (for grid-column-start, grid-row-end, etc.)
/// Supports: auto, <integer>, span <integer>
pub fn parse_grid_placement(value : String) -> @types.GridPlacement {
  let v = value.trim().to_lower()
  if v == "auto" {
    return @types.GridPlacement::Auto
  }
  // Check for "span N" pattern
  if v.has_prefix("span") {
    let num_str = v[4:].to_string() catch { _ => "" }
    let num = @strconv.parse_int(num_str.trim().to_string()) catch { _ => 1 }
    return @types.GridPlacement::Span(num)
  }
  // Otherwise, parse as integer (line number)
  let line = @strconv.parse_int(v.to_string()) catch { _ => 0 }
  if line != 0 {
    @types.GridPlacement::Line(line)
  } else {
    @types.GridPlacement::Auto
  }
}

///|
/// Parse grid-column or grid-row shorthand
/// Formats: <start>, <start> / <end>, <start> / span <n>
pub fn parse_grid_line_shorthand(
  value : String,
) -> (@types.GridPlacement, @types.GridPlacement) {
  let v = value.trim()
  // Check for "/" separator
  let parts = v.split("/").map(fn(s) { s.trim().to_string() }).collect()
  if parts.length() == 2 {
    let start = parse_grid_placement(parts[0])
    let end = parse_grid_placement(parts[1])
    (start, end)
  } else {
    // Single value: applies to start, end is auto
    let start = parse_grid_placement(v.to_string())
    (start, @types.GridPlacement::Auto)
  }
}

///|
/// Parse a number value
pub fn parse_number(value : String) -> Double {
  @strconv.parse_double(value.trim().to_string()) catch {
    _ => 0.0
  }
}

///|
/// Parse an integer value
pub fn parse_integer(value : String) -> Int {
  @strconv.parse_int(value.trim().to_string()) catch {
    _ => 0
  }
}

///|
/// Parse grid-template-columns or grid-template-rows value
/// Delegate to the full parser to support minmax() and repeat().
pub fn parse_grid_template_tracks(
  value : String,
) -> Array[@types.TrackSizingFunction] {
  @parser.parse_grid_template_tracks_from_string(value)
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
      let width_str = v[:slash_pos].to_string().trim() catch { _ => "" }
      let height_str = v[slash_pos + 1:].to_string().trim() catch { _ => "" }
      let w = @strconv.parse_double(width_str.to_string()) catch {
        _ => return None
      }
      let h = @strconv.parse_double(height_str.to_string()) catch {
        _ => return None
      }
      if h != 0.0 {
        return Some(w / h)
      }
      return None
    }
  }
  // Try parsing as a single number
  let n = @strconv.parse_double(v.to_string()) catch { _ => return None }
  Some(n)
}

///|
/// Parse CSS clip property value
/// Supports: auto, rect(top, right, bottom, left)
/// Note: This is a deprecated property but widely used for accessibility
pub fn parse_clip(value : String) -> @types.ClipRect {
  let v = value.trim().to_lower()
  if v == "auto" || v == "initial" || v == "unset" {
    return @types.ClipRect::Auto
  }
  // Parse rect(top, right, bottom, left)
  if v.has_prefix("rect(") && v.has_suffix(")") {
    // Extract the content inside rect()
    let content = v[5:v.length() - 1].to_string().trim() catch {
        _ => return @types.ClipRect::Auto
      }
    // Split by comma or space (both are valid in CSS)
    let parts : Array[String] = []
    let mut current = StringBuilder::new()
    for c in content.iter() {
      if c == ',' || c == ' ' {
        let s = current.to_string().trim().to_string()
        if not(s.is_empty()) {
          parts.push(s)
        }
        current = StringBuilder::new()
      } else {
        current.write_char(c)
      }
    }
    let last = current.to_string().trim().to_string()
    if not(last.is_empty()) {
      parts.push(last)
    }
    if parts.length() == 4 {
      let top = parse_clip_value(parts[0])
      let right = parse_clip_value(parts[1])
      let bottom = parse_clip_value(parts[2])
      let left = parse_clip_value(parts[3])
      return @types.ClipRect::Rect(top~, right~, bottom~, left~)
    }
  }
  @types.ClipRect::Auto
}

///|
/// Parse a single clip rect value (auto or length)
fn parse_clip_value(value : String) -> Double {
  let v = value.trim().to_lower()
  if v == "auto" {
    // auto in clip rect context means 0 (no offset)
    return 0.0
  }
  // Parse px value
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @strconv.parse_double(num_str.to_string().trim()) catch {
        _ => return 0.0
      }
      return n
    }
    None => ()
  }
  // Parse plain number
  let n = @strconv.parse_double(v.to_string()) catch { _ => return 0.0 }
  n
}
