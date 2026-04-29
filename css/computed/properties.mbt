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
    | "white-space"
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
    "pointer-events" => true
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
    "pointer-events" => "auto"
    "scroll-snap-type" => "none"
    "scroll-snap-align" => "none"
    // Sizing
    "width" | "height" | "min-width" | "min-height" => "auto"
    "max-width" | "max-height" => "none"
    // Box model
    "margin"
    | "margin-top"
    | "margin-right"
    | "margin-bottom"
    | "margin-left" => "0"
    "margin-trim" => "none"
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
    "columns" | "column-count" | "column-width" => "auto"
    "column-fill" => "balance"
    "break-before" | "break-after" | "break-inside" | "page-break-inside" =>
      "auto"
    "column-span" => "none"
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
    "text-align" => "start"
    "font-weight" => "400"
    "white-space" => "normal"
    "text-overflow" => "clip"
    "text-decoration" | "text-decoration-line" => "none"
    "box-shadow" => "none"
    // Containment
    "contain" => "none"
    "contain-intrinsic-size"
    | "contain-intrinsic-inline-size"
    | "contain-intrinsic-block-size" => "none"
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
    let inner = v_str.unsafe_substring(start=12, end=v_str.length() - 1)
    // Parse the inner value as a length
    match inner.strip_suffix("px") {
      Some(num_str) => {
        let n = @string.parse_double(num_str.to_string()) catch {
          _ => return @types.Dimension::Auto
        }
        return @types.Dimension::FitContent(n)
      }
      None => ()
    }
    // Try percentage
    match inner.strip_suffix("%") {
      Some(num_str) => {
        let n = @string.parse_double(num_str.to_string()) catch {
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
      let n = @string.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Length(n)
    }
    None => ()
  }
  // Try to parse as percentage
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_string()) catch {
        _ => return @types.Dimension::Auto
      }
      return @types.Dimension::Percent(n / 100.0)
    }
    None => ()
  }
  // Try to parse as plain number (treated as px)
  let n = @string.parse_double(v.to_string()) catch {
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
  let mut has_visible_style = false
  for part in parts {
    let lower = part.to_lower()
    match lower {
      "thin" => return @types.Dimension::Length(1.0)
      "medium" => return @types.Dimension::Length(3.0)
      "thick" => return @types.Dimension::Length(5.0)
      "solid"
      | "dotted"
      | "dashed"
      | "double"
      | "groove"
      | "ridge"
      | "inset"
      | "outset" => {
        has_visible_style = true
        continue
      }
      "none" | "hidden" => continue
      _ => ()
    }
    // Check if this part looks like a dimension (ends with px or is a number)
    if part.has_suffix("px") {
      match part.strip_suffix("px") {
        Some(num_str) => {
          let n = @string.parse_double(num_str.to_string()) catch {
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
      let n = @string.parse_double(part) catch { _ => continue }
      return @types.Dimension::Length(n)
    }
  }

  // Compatible default for style-only shorthand like "border: solid".
  if has_visible_style {
    @types.Dimension::Length(1.5)
  } else {
    // Default: no border
    @types.Dimension::Length(0.0)
  }
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
  let normalized = value.trim().to_lower().to_string()
  let parts = split_whitespace(normalized)
  if parts.length() == 0 {
    return @types.Display::Block
  }
  if parts.length() == 2 {
    let first = parts[0]
    let second = parts[1]
    if (first == "math" && second == "inline") ||
      (first == "inline" && second == "math") {
      return @types.Display::Inline
    }
    if (first == "math" && second == "block") ||
      (first == "block" && second == "math") {
      return @types.Display::Block
    }
    if (first == "flow-root" && second == "list-item") ||
      (first == "list-item" && second == "flow-root") {
      return @types.Display::FlowRoot
    }
  }
  if parts.length() > 1 {
    return @types.Display::Block
  }
  match parts[0] {
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
    "math" => @types.Display::Inline
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
    // Ruby internal display types are inline-level for layout-tree comparison.
    // (Full ruby formatting context is not yet implemented.)
    "ruby" => @types.Display::Inline
    "ruby-base" => @types.Display::Inline
    "ruby-base-container" => @types.Display::Inline
    "ruby-text" => @types.Display::Inline
    "ruby-text-container" => @types.Display::Inline
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
pub fn parse_float_with_direction(
  value : String,
  direction : @style.Direction,
) -> @types.Float {
  match value.trim().to_lower() {
    "inline-start" =>
      if direction.is_rtl() {
        @types.Float::Right
      } else {
        @types.Float::Left
      }
    "inline-end" =>
      if direction.is_rtl() {
        @types.Float::Left
      } else {
        @types.Float::Right
      }
    _ => parse_float(value)
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
pub fn parse_clear_with_direction(
  value : String,
  direction : @style.Direction,
) -> @types.Clear {
  match value.trim().to_lower() {
    "inline-start" =>
      if direction.is_rtl() {
        @types.Clear::Right
      } else {
        @types.Clear::Left
      }
    "inline-end" =>
      if direction.is_rtl() {
        @types.Clear::Left
      } else {
        @types.Clear::Right
      }
    _ => parse_clear(value)
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
fn tokenize_alignment_value(value : String) -> Array[String] {
  value
  .trim()
  .to_lower()
  .split(" ")
  .map(fn(part) { part.to_string().trim().to_string() })
  .filter(fn(part) { !part.is_empty() })
  .collect()
}

///|
fn parse_alignment_keyword(value : String) -> @types.Alignment {
  match value {
    "flex-start" => @types.Alignment::FlexStart
    "flex-end" => @types.Alignment::FlexEnd
    "start" => @types.Alignment::Start
    "end" => @types.Alignment::End
    "left" => @types.Alignment::Left
    "right" => @types.Alignment::Right
    "center" => @types.Alignment::Center
    "space-between" => @types.Alignment::SpaceBetween
    "space-around" => @types.Alignment::SpaceAround
    "space-evenly" => @types.Alignment::SpaceEvenly
    "stretch" => @types.Alignment::Stretch
    "baseline" | "first baseline" => @types.Alignment::Baseline
    // Fallback alignment for last-baseline in axis alignment.
    "last baseline" => @types.Alignment::End
    _ => @types.Alignment::FlexStart
  }
}

///|
fn parse_alignment_segment(
  tokens : Array[String],
  start : Int,
) -> (String, Int)? {
  if start >= tokens.length() {
    return None
  }
  let head = tokens[start]
  if start + 1 < tokens.length() {
    let next = tokens[start + 1]
    if head == "safe" ||
      head == "unsafe" ||
      ((head == "first" || head == "last") && next == "baseline") {
      return Some((head + " " + next, start + 2))
    }
  }
  Some((head, start + 1))
}

///|
/// Parse alignment value (justify-content, align-items, align-content)
/// Note: flex-start/flex-end are flex-relative (affected by wrap-reverse)
///       start/end are physical/logical (not affected by wrap-reverse)
pub fn parse_alignment_with_overflow(
  value : String,
) -> (@types.Alignment, Bool) {
  let tokens = tokenize_alignment_value(value)
  if tokens.is_empty() {
    return (@types.Alignment::FlexStart, false)
  }
  let mut offset = 0
  let mut is_safe = false
  let mut is_unsafe = false
  if tokens[0] == "safe" {
    is_safe = true
    offset = 1
  } else if tokens[0] == "unsafe" {
    is_unsafe = true
    offset = 1
  }
  if offset >= tokens.length() {
    return (@types.Alignment::FlexStart, false)
  }
  let keyword = if offset + 1 < tokens.length() &&
    tokens[offset + 1] == "baseline" &&
    (tokens[offset] == "first" || tokens[offset] == "last") {
    tokens[offset] + " baseline"
  } else {
    tokens[offset]
  }
  let parsed = parse_alignment_keyword(keyword)
  let parsed = if is_safe {
    match parsed {
      @types.Alignment::Center
      | @types.Alignment::End
      | @types.Alignment::FlexEnd => @types.Alignment::Start
      _ => parsed
    }
  } else {
    parsed
  }
  (parsed, is_unsafe)
}

///|
pub fn parse_alignment(value : String) -> @types.Alignment {
  let (alignment, _) = parse_alignment_with_overflow(value)
  alignment
}

///|
/// Parse place-content shorthand.
/// Returns (align_content, justify_content).
pub fn parse_place_content_with_overflow(
  value : String,
) -> ((@types.Alignment, Bool), (@types.Alignment, Bool))? {
  let tokens = tokenize_alignment_value(value)
  if tokens.is_empty() {
    return None
  }
  match parse_alignment_segment(tokens, 0) {
    Some((first, next_index)) => {
      let first_alignment = parse_alignment_with_overflow(first)
      if next_index >= tokens.length() {
        return Some((first_alignment, first_alignment))
      }
      match parse_alignment_segment(tokens, next_index) {
        Some((second, _)) =>
          Some((first_alignment, parse_alignment_with_overflow(second)))
        None => Some((first_alignment, first_alignment))
      }
    }
    None => None
  }
}

///|
/// Parse place-content shorthand.
/// Returns (align_content, justify_content).
pub fn parse_place_content(
  value : String,
) -> (@types.Alignment, @types.Alignment)? {
  match parse_place_content_with_overflow(value) {
    Some(((align_content, _), (justify_content, _))) =>
      Some((align_content, justify_content))
    None => None
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
    "baseline" | "first baseline" => @types.AlignSelf::Baseline
    // Fallback alignment for last-baseline in self alignment.
    "last baseline" => @types.AlignSelf::End
    _ => @types.AlignSelf::Auto
  }
}

///|
/// Parse overflow value
pub fn parse_overflow(value : String) -> @types.Overflow {
  match value.trim().to_lower() {
    "visible" => @types.Overflow::Visible
    "hidden" => @types.Overflow::Hidden
    "clip" => @types.Overflow::Clip
    "scroll" => @types.Overflow::Scroll
    "auto" => @types.Overflow::Auto
    _ => @types.Overflow::Visible
  }
}

///|
/// Parse scroll-snap-type value
/// Supports a minimal subset: none | x mandatory | y mandatory | both mandatory.
pub fn parse_scroll_snap_type(value : String) -> @style.ScrollSnapType {
  let tokens = value
    .trim()
    .to_lower()
    .split(" ")
    .map(fn(part) { part.to_string().trim().to_string() })
    .filter(fn(part) { !part.is_empty() })
    .collect()
  if tokens.is_empty() {
    return @style.ScrollSnapType::none()
  }

  let mut axis = @style.ScrollSnapAxis::None
  let mut strictness = @style.ScrollSnapStrictness::None
  for token in tokens {
    match token {
      "none" => return @style.ScrollSnapType::none()
      "x" | "inline" => axis = @style.ScrollSnapAxis::X
      "y" | "block" => axis = @style.ScrollSnapAxis::Y
      "both" => axis = @style.ScrollSnapAxis::Both
      "mandatory" => strictness = @style.ScrollSnapStrictness::Mandatory
      "proximity" => strictness = @style.ScrollSnapStrictness::Proximity
      _ => ()
    }
  }
  if axis == @style.ScrollSnapAxis::None ||
    strictness == @style.ScrollSnapStrictness::None {
    @style.ScrollSnapType::none()
  } else {
    { axis, strictness }
  }
}

///|
/// Parse scroll-snap-align value as (inline, block).
/// Supports keywords: none | start | end | center.
pub fn parse_scroll_snap_align(
  value : String,
) -> (@style.ScrollSnapAlign, @style.ScrollSnapAlign) {
  let tokens = value
    .trim()
    .to_lower()
    .split(" ")
    .map(fn(part) { part.to_string().trim().to_string() })
    .filter(fn(part) { !part.is_empty() })
    .collect()
  if tokens.is_empty() {
    return (@style.ScrollSnapAlign::None, @style.ScrollSnapAlign::None)
  }
  if tokens.length() == 1 {
    let keyword = parse_scroll_snap_align_keyword(tokens[0])
    return (keyword, keyword)
  }
  let block = parse_scroll_snap_align_keyword(tokens[0])
  let inline = parse_scroll_snap_align_keyword(tokens[1])
  (inline, block)
}

///|
fn parse_scroll_snap_align_keyword(value : String) -> @style.ScrollSnapAlign {
  match value.trim().to_lower() {
    "none" => @style.ScrollSnapAlign::None
    "start" => @style.ScrollSnapAlign::Start
    "end" => @style.ScrollSnapAlign::End
    "center" => @style.ScrollSnapAlign::Center
    _ => @style.ScrollSnapAlign::None
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
/// Parse text-align value
pub fn parse_text_align(value : String) -> @style.TextAlign {
  match value.trim().to_lower() {
    "center" => @style.TextAlign::Center
    "justify" => @style.TextAlign::Justify
    "left" => @style.TextAlign::Left
    "right" => @style.TextAlign::Right
    "end" => @style.TextAlign::End
    "start" | _ => @style.TextAlign::Start
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
    let num_str = view_to_string(v.view(start_offset=4))
    let num = @string.parse_int(num_str.trim().to_string()) catch { _ => 1 }
    return @types.GridPlacement::Span(num)
  }
  // Otherwise, parse as integer (line number)
  let line = @string.parse_int(v.to_string()) catch { _ => 0 }
  if line != 0 {
    @types.GridPlacement::Line(line)
  } else if is_basic_custom_ident(v) {
    // Browser-compatible fallback: unresolved custom identifiers in placement
    // create an implicit track before the item (equivalent to line 2 start).
    @types.GridPlacement::Line(2)
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
/// Parse grid-area shorthand:
/// <row-start> / <column-start> / <row-end> / <column-end>
pub fn parse_grid_area_shorthand(
  value : String,
) -> (
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
  @types.GridPlacement,
) {
  let v = value.trim()
  let parts = v
    .split("/")
    .map(fn(s) { s.trim().to_string() })
    .filter(fn(s) { !s.is_empty() })
    .collect()
  if parts.length() >= 4 {
    (
      parse_grid_placement(parts[0]),
      parse_grid_placement(parts[1]),
      parse_grid_placement(parts[2]),
      parse_grid_placement(parts[3]),
    )
  } else if parts.length() == 3 {
    (
      parse_grid_placement(parts[0]),
      parse_grid_placement(parts[1]),
      parse_grid_placement(parts[2]),
      @types.GridPlacement::Auto,
    )
  } else if parts.length() == 2 {
    (
      parse_grid_placement(parts[0]),
      parse_grid_placement(parts[1]),
      @types.GridPlacement::Auto,
      @types.GridPlacement::Auto,
    )
  } else if parts.length() == 1 {
    let start = parse_grid_placement(parts[0])
    (start, start, @types.GridPlacement::Auto, @types.GridPlacement::Auto)
  } else {
    (
      @types.GridPlacement::Auto,
      @types.GridPlacement::Auto,
      @types.GridPlacement::Auto,
      @types.GridPlacement::Auto,
    )
  }
}

///|
fn is_basic_custom_ident(value : StringView) -> Bool {
  if value.length() == 0 {
    return false
  }
  let first = value[0]
  let first_ok = (first >= 'a' && first <= 'z') ||
    (first >= 'A' && first <= 'Z') ||
    first == '_' ||
    first == '-'
  if !first_ok {
    return false
  }
  for i = 1; i < value.length(); i = i + 1 {
    let c = value[i]
    let ok = (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' ||
      c == '-'
    if !ok {
      return false
    }
  }
  true
}

///|
/// Parse a number value
pub fn parse_number(value : String) -> Double {
  @string.parse_double(value.trim().to_string()) catch {
    _ => 0.0
  }
}

///|
/// Parse an integer value
pub fn parse_integer(value : String) -> Int {
  @string.parse_int(value.trim().to_string()) catch {
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
/// Parse grid-template shorthand: `<rows> / <columns>`
pub fn parse_grid_template_shorthand(
  value : String,
) -> (Array[@types.TrackSizingFunction], Array[@types.TrackSizingFunction])? {
  let v = value.trim()
  if !v.contains("/") {
    return None
  }
  let parts = v.split("/").map(fn(s) { s.trim().to_string() }).collect()
  if parts.length() != 2 {
    return None
  }
  let rows = parse_grid_template_tracks(parts[0])
  let cols = parse_grid_template_tracks(parts[1])
  Some((rows, cols))
}

///|
/// Parse grid-template-areas CSS property value.
/// The value is a series of quoted strings like: "header header" "sidebar main" "footer footer"
pub fn parse_grid_template_areas_value(value : String) -> Array[String] {
  let result : Array[String] = []
  let v = value.trim()
  // Parse quoted strings - each quoted string is one row
  let mut i = 0
  while i < v.length() {
    let c = v[i].unsafe_to_char()
    if c == '"' || c == '\'' {
      let quote = c
      let mut end = i + 1
      while end < v.length() && v[end].unsafe_to_char() != quote {
        end = end + 1
      }
      if end > i + 1 {
        let row_str = view_to_string(v.view(start_offset=i + 1, end_offset=end))
        result.push(row_str.to_string())
      }
      i = end + 1
    } else {
      i = i + 1
    }
  }
  result
}

///|
/// Check if a value is a named grid area identifier (not a number, auto, or span keyword)
pub fn is_grid_area_name(value : String) -> Bool {
  let v = value.trim().to_lower()
  if v == "auto" ||
    v == "none" ||
    v == "inherit" ||
    v == "initial" ||
    v == "unset" {
    return false
  }
  if v.has_prefix("span") {
    return false
  }
  // Check if it's a number
  let parsed = @string.parse_int(v.to_string()) catch { _ => 0 }
  if parsed != 0 {
    return false
  }
  // Must be a valid custom ident
  is_basic_custom_ident(v)
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
      let width_str = view_to_string(v.view(end_offset=slash_pos)).trim()
      let height_str = view_to_string(v.view(start_offset=slash_pos + 1)).trim()
      let w = @string.parse_double(width_str.to_string()) catch {
        _ => return None
      }
      let h = @string.parse_double(height_str.to_string()) catch {
        _ => return None
      }
      if h != 0.0 {
        return Some(w / h)
      }
      return None
    }
  }
  // Try parsing as a single number
  let n = @string.parse_double(v.to_string()) catch { _ => return None }
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
    let content = view_to_string(
      v.view(start_offset=5, end_offset=v.length() - 1),
    ).trim()
    // Split by comma or space (both are valid in CSS)
    let parts : Array[String] = []
    let mut current = StringBuilder::new()
    for c in content.iter() {
      if c == ',' || c == ' ' {
        let s = current.to_string().trim().to_string()
        if !s.is_empty() {
          parts.push(s)
        }
        current = StringBuilder::new()
      } else {
        current.write_char(c)
      }
    }
    let last = current.to_string().trim().to_string()
    if !last.is_empty() {
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
/// Parse the supported subset of CSS clip-path.
/// Supports: none, inset(<top> <right> <bottom> <left>), circle(<r> at <x> <y>).
pub fn parse_clip_path(value : String) -> @style.ClipPath {
  let raw_v = value.trim().to_string()
  let v = raw_v.to_lower()
  if v == "none" || v == "initial" || v == "unset" || v.is_empty() {
    return @style.ClipPath::None
  }
  if v.has_prefix("inset(") && v.has_suffix(")") {
    let raw_content = view_to_string(
        v.view(start_offset=6, end_offset=v.length() - 1),
      )
      .trim()
      .to_string()
    let content = match raw_content.find("round") {
      Some(idx) =>
        raw_content.unsafe_substring(start=0, end=idx).trim().to_string()
      None => raw_content
    }
    let parts = split_clip_path_values(content)
    if parts.length() > 0 {
      let values = parts.map(parse_clip_path_inset_value)
      match values.length() {
        1 => {
          let v = values[0]
          return @style.ClipPath::Inset(v, v, v, v)
        }
        2 => {
          let vertical = values[0]
          let horizontal = values[1]
          return @style.ClipPath::Inset(
            vertical, horizontal, vertical, horizontal,
          )
        }
        3 =>
          return @style.ClipPath::Inset(
            values[0],
            values[1],
            values[2],
            values[1],
          )
        _ =>
          return @style.ClipPath::Inset(
            values[0],
            values[1],
            values[2],
            values[3],
          )
      }
    }
  }
  if v.has_prefix("rect(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=5, end_offset=v.length() - 1),
      )
      .trim()
      .to_string()
    return parse_clip_path_rect(content)
  }
  if v.has_prefix("xywh(") && v.has_suffix(")") {
    let raw_content = view_to_string(
        v.view(start_offset=5, end_offset=v.length() - 1),
      )
      .trim()
      .to_string()
    let content = match raw_content.find("round") {
      Some(idx) =>
        raw_content.unsafe_substring(start=0, end=idx).trim().to_string()
      None => raw_content
    }
    return parse_clip_path_xywh(content)
  }
  if v.has_prefix("circle(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=7, end_offset=v.length() - 1),
      )
      .trim()
      .to_string()
    return parse_clip_path_circle(content)
  }
  if v.has_prefix("ellipse(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=8, end_offset=v.length() - 1),
      )
      .trim()
      .to_string()
    return parse_clip_path_ellipse(content)
  }
  if v.has_prefix("polygon(") && v.has_suffix(")") {
    let content = view_to_string(
        v.view(start_offset=8, end_offset=v.length() - 1),
      )
      .trim()
      .to_string()
    return parse_clip_path_polygon(content)
  }
  if v.has_prefix("path(") && v.has_suffix(")") {
    let content = view_to_string(
        raw_v.view(start_offset=5, end_offset=raw_v.length() - 1),
      )
      .trim()
      .to_string()
    return parse_clip_path_path(content)
  }
  @style.ClipPath::None
}

///|
fn parse_clip_path_rect(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() < 4 {
    return @style.ClipPath::None
  }
  let top = parse_clip_path_shape_value(parts[0]) catch {
    _ => return @style.ClipPath::None
  }
  let right = parse_clip_path_shape_value(parts[1]) catch {
    _ => return @style.ClipPath::None
  }
  let bottom = parse_clip_path_shape_value(parts[2]) catch {
    _ => return @style.ClipPath::None
  }
  let left = parse_clip_path_shape_value(parts[3]) catch {
    _ => return @style.ClipPath::None
  }
  @style.ClipPath::Rect(top, right, bottom, left)
}

///|
fn parse_clip_path_xywh(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() < 4 {
    return @style.ClipPath::None
  }
  let x = parse_clip_path_shape_value(parts[0]) catch {
    _ => return @style.ClipPath::None
  }
  let y = parse_clip_path_shape_value(parts[1]) catch {
    _ => return @style.ClipPath::None
  }
  let width = parse_clip_path_shape_value(parts[2]) catch {
    _ => return @style.ClipPath::None
  }
  let height = parse_clip_path_shape_value(parts[3]) catch {
    _ => return @style.ClipPath::None
  }
  @style.ClipPath::Xywh(x, y, width, height)
}

///|
fn parse_clip_path_circle(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() == 0 {
    return @style.ClipPath::None
  }
  let mut at_index = -1
  for i in 0..<parts.length() {
    if parts[i] == "at" {
      at_index = i
      break
    }
  }
  let mut radius = -0.5
  let mut center_x = -0.5
  let mut center_y = -0.5
  if at_index == 0 {
    if parts.length() < 3 {
      return @style.ClipPath::None
    }
    center_x = parse_clip_path_shape_value(parts[1]) catch {
      _ => return @style.ClipPath::None
    }
    center_y = parse_clip_path_shape_value(parts[2]) catch {
      _ => return @style.ClipPath::None
    }
  } else if at_index > 0 {
    radius = parse_clip_path_shape_value(parts[0]) catch {
      _ => return @style.ClipPath::None
    }
    if parts.length() <= at_index + 2 {
      return @style.ClipPath::None
    }
    center_x = parse_clip_path_shape_value(parts[at_index + 1]) catch {
      _ => return @style.ClipPath::None
    }
    center_y = parse_clip_path_shape_value(parts[at_index + 2]) catch {
      _ => return @style.ClipPath::None
    }
  } else {
    radius = parse_clip_path_shape_value(parts[0]) catch {
      _ => return @style.ClipPath::None
    }
  }
  @style.ClipPath::Circle(radius, center_x, center_y)
}

///|
fn parse_clip_path_ellipse(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  if parts.length() == 0 {
    return @style.ClipPath::None
  }
  let mut at_index = -1
  for i in 0..<parts.length() {
    if parts[i] == "at" {
      at_index = i
      break
    }
  }
  let mut radius_x = -0.5
  let mut radius_y = -0.5
  let mut center_x = -0.5
  let mut center_y = -0.5
  if at_index == 0 {
    if parts.length() < 3 {
      return @style.ClipPath::None
    }
    center_x = parse_clip_path_shape_value(parts[1]) catch {
      _ => return @style.ClipPath::None
    }
    center_y = parse_clip_path_shape_value(parts[2]) catch {
      _ => return @style.ClipPath::None
    }
  } else if at_index > 0 {
    if at_index < 2 || parts.length() <= at_index + 2 {
      return @style.ClipPath::None
    }
    radius_x = parse_clip_path_shape_value(parts[0]) catch {
      _ => return @style.ClipPath::None
    }
    radius_y = parse_clip_path_shape_value(parts[1]) catch {
      _ => return @style.ClipPath::None
    }
    center_x = parse_clip_path_shape_value(parts[at_index + 1]) catch {
      _ => return @style.ClipPath::None
    }
    center_y = parse_clip_path_shape_value(parts[at_index + 2]) catch {
      _ => return @style.ClipPath::None
    }
  } else {
    if parts.length() < 2 {
      return @style.ClipPath::None
    }
    radius_x = parse_clip_path_shape_value(parts[0]) catch {
      _ => return @style.ClipPath::None
    }
    radius_y = parse_clip_path_shape_value(parts[1]) catch {
      _ => return @style.ClipPath::None
    }
  }
  @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y)
}

///|
fn parse_clip_path_polygon(content : String) -> @style.ClipPath {
  let parts = split_clip_path_values(content)
  let values : Array[Double] = []
  for part in parts {
    if part == "evenodd" || part == "nonzero" {
      continue
    }
    let v = parse_clip_path_shape_value(part) catch {
      _ => return @style.ClipPath::None
    }
    values.push(v)
  }
  if values.length() < 6 || values.length() % 2 != 0 {
    return @style.ClipPath::None
  }
  let points : Array[(Double, Double)] = []
  let mut i = 0
  while i + 1 < values.length() {
    points.push((values[i], values[i + 1]))
    i = i + 2
  }
  @style.ClipPath::Polygon(points)
}

///|
fn parse_clip_path_path(content : String) -> @style.ClipPath {
  let path_data = match extract_clip_path_path_string(content) {
    Some(v) => v
    None => return @style.ClipPath::None
  }
  parse_clip_path_path_data(path_data)
}

///|
fn extract_clip_path_path_string(content : String) -> String? {
  match extract_clip_path_path_string_with_quote(content, '"') {
    Some(v) => Some(v)
    None => extract_clip_path_path_string_with_quote(content, '\'')
  }
}

///|
fn extract_clip_path_path_string_with_quote(
  content : String,
  quote : Char,
) -> String? {
  let out = StringBuilder::new()
  let mut in_quote = false
  for c in content.iter() {
    if in_quote {
      if c == quote {
        return Some(out.to_string())
      }
      out.write_char(c)
    } else if c == quote {
      in_quote = true
    }
  }
  None
}

///|
fn parse_clip_path_path_data(path_data : String) -> @style.ClipPath {
  let tokens = tokenize_clip_path_path_data(path_data)
  let points : Array[(Double, Double)] = []
  let mut i = 0
  let mut command = ""
  let mut current_x = 0.0
  let mut current_y = 0.0
  let mut start_x = 0.0
  let mut start_y = 0.0
  let mut has_quadratic_control = false
  let mut quadratic_control_x = 0.0
  let mut quadratic_control_y = 0.0
  let mut has_cubic_control = false
  let mut cubic_control_x = 0.0
  let mut cubic_control_y = 0.0
  while i < tokens.length() {
    let token = tokens[i]
    if is_clip_path_path_command(token) {
      if token == "Z" || token == "z" {
        current_x = start_x
        current_y = start_y
        has_quadratic_control = false
        has_cubic_control = false
        command = ""
        i += 1
        continue
      }
      command = token
      i += 1
      continue
    }
    match command {
      "M" | "m" => {
        if i + 1 >= tokens.length() {
          return @style.ClipPath::None
        }
        let x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        if command == "m" {
          current_x += x
          current_y += y
        } else {
          current_x = x
          current_y = y
        }
        start_x = current_x
        start_y = current_y
        points.push((current_x, current_y))
        command = if command == "m" { "l" } else { "L" }
        has_quadratic_control = false
        has_cubic_control = false
        i += 2
      }
      "L" | "l" => {
        if i + 1 >= tokens.length() {
          return @style.ClipPath::None
        }
        let x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        if command == "l" {
          current_x += x
          current_y += y
        } else {
          current_x = x
          current_y = y
        }
        points.push((current_x, current_y))
        has_quadratic_control = false
        has_cubic_control = false
        i += 2
      }
      "H" | "h" => {
        let x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        if command == "h" {
          current_x += x
        } else {
          current_x = x
        }
        points.push((current_x, current_y))
        has_quadratic_control = false
        has_cubic_control = false
        i += 1
      }
      "V" | "v" => {
        let y = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        if command == "v" {
          current_y += y
        } else {
          current_y = y
        }
        points.push((current_x, current_y))
        has_quadratic_control = false
        has_cubic_control = false
        i += 1
      }
      "Q" | "q" => {
        if i + 3 >= tokens.length() {
          return @style.ClipPath::None
        }
        let control_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let control_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let absolute_control_x = if command == "q" {
          current_x + control_x
        } else {
          control_x
        }
        let absolute_control_y = if command == "q" {
          current_y + control_y
        } else {
          control_y
        }
        let absolute_end_x = if command == "q" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "q" {
          current_y + end_y
        } else {
          end_y
        }
        append_quadratic_path_points(
          points, current_x, current_y, absolute_control_x, absolute_control_y, absolute_end_x,
          absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_quadratic_control = true
        quadratic_control_x = absolute_control_x
        quadratic_control_y = absolute_control_y
        has_cubic_control = false
        i += 4
      }
      "T" | "t" => {
        if i + 1 >= tokens.length() {
          return @style.ClipPath::None
        }
        let end_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let absolute_control_x = if has_quadratic_control {
          2.0 * current_x - quadratic_control_x
        } else {
          current_x
        }
        let absolute_control_y = if has_quadratic_control {
          2.0 * current_y - quadratic_control_y
        } else {
          current_y
        }
        let absolute_end_x = if command == "t" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "t" {
          current_y + end_y
        } else {
          end_y
        }
        append_quadratic_path_points(
          points, current_x, current_y, absolute_control_x, absolute_control_y, absolute_end_x,
          absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_quadratic_control = true
        quadratic_control_x = absolute_control_x
        quadratic_control_y = absolute_control_y
        has_cubic_control = false
        i += 2
      }
      "C" | "c" => {
        if i + 5 >= tokens.length() {
          return @style.ClipPath::None
        }
        let control1_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let control1_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let control2_x = match parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let control2_y = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 4]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 5]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let absolute_control1_x = if command == "c" {
          current_x + control1_x
        } else {
          control1_x
        }
        let absolute_control1_y = if command == "c" {
          current_y + control1_y
        } else {
          control1_y
        }
        let absolute_control2_x = if command == "c" {
          current_x + control2_x
        } else {
          control2_x
        }
        let absolute_control2_y = if command == "c" {
          current_y + control2_y
        } else {
          control2_y
        }
        let absolute_end_x = if command == "c" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "c" {
          current_y + end_y
        } else {
          end_y
        }
        append_cubic_path_points(
          points, current_x, current_y, absolute_control1_x, absolute_control1_y,
          absolute_control2_x, absolute_control2_y, absolute_end_x, absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_cubic_control = true
        cubic_control_x = absolute_control2_x
        cubic_control_y = absolute_control2_y
        has_quadratic_control = false
        i += 6
      }
      "S" | "s" => {
        if i + 3 >= tokens.length() {
          return @style.ClipPath::None
        }
        let control2_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let control2_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let absolute_control1_x = if has_cubic_control {
          2.0 * current_x - cubic_control_x
        } else {
          current_x
        }
        let absolute_control1_y = if has_cubic_control {
          2.0 * current_y - cubic_control_y
        } else {
          current_y
        }
        let absolute_control2_x = if command == "s" {
          current_x + control2_x
        } else {
          control2_x
        }
        let absolute_control2_y = if command == "s" {
          current_y + control2_y
        } else {
          control2_y
        }
        let absolute_end_x = if command == "s" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "s" {
          current_y + end_y
        } else {
          end_y
        }
        append_cubic_path_points(
          points, current_x, current_y, absolute_control1_x, absolute_control1_y,
          absolute_control2_x, absolute_control2_y, absolute_end_x, absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_cubic_control = true
        cubic_control_x = absolute_control2_x
        cubic_control_y = absolute_control2_y
        has_quadratic_control = false
        i += 4
      }
      "A" | "a" => {
        if i + 6 >= tokens.length() {
          return @style.ClipPath::None
        }
        let radius_x = match parse_clip_path_path_number(tokens[i]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let radius_y = match parse_clip_path_path_number(tokens[i + 1]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let rotation_degrees = match
          parse_clip_path_path_number(tokens[i + 2]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let large_arc_flag = match parse_clip_path_path_number(tokens[i + 3]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let sweep_flag = match parse_clip_path_path_number(tokens[i + 4]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_x = match parse_clip_path_path_number(tokens[i + 5]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let end_y = match parse_clip_path_path_number(tokens[i + 6]) {
          Some(v) => v
          None => return @style.ClipPath::None
        }
        let absolute_end_x = if command == "a" {
          current_x + end_x
        } else {
          end_x
        }
        let absolute_end_y = if command == "a" {
          current_y + end_y
        } else {
          end_y
        }
        append_arc_path_points(
          points,
          current_x,
          current_y,
          radius_x,
          radius_y,
          rotation_degrees,
          large_arc_flag != 0.0,
          sweep_flag != 0.0,
          absolute_end_x,
          absolute_end_y,
        )
        current_x = absolute_end_x
        current_y = absolute_end_y
        has_quadratic_control = false
        has_cubic_control = false
        i += 7
      }
      _ => return @style.ClipPath::None
    }
  }
  if points.length() < 3 {
    return @style.ClipPath::None
  }
  @style.ClipPath::Polygon(points)
}

///|
fn tokenize_clip_path_path_data(path_data : String) -> Array[String] {
  let tokens : Array[String] = []
  let current = StringBuilder::new()
  for c in path_data.iter() {
    if is_clip_path_path_command_char(c) {
      flush_clip_path_path_token(tokens, current)
      tokens.push(clip_path_path_char_to_string(c))
    } else if c == ',' || c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      flush_clip_path_path_token(tokens, current)
    } else if c == '-' || c == '+' {
      let current_text = current.to_string()
      if !current_text.is_empty() &&
        !current_text.has_suffix("e") &&
        !current_text.has_suffix("E") {
        flush_clip_path_path_token(tokens, current)
      }
      current.write_char(c)
    } else {
      current.write_char(c)
    }
  }
  flush_clip_path_path_token(tokens, current)
  tokens
}

///|
fn flush_clip_path_path_token(
  tokens : Array[String],
  current : StringBuilder,
) -> Unit {
  let token = current.to_string().trim().to_string()
  if !token.is_empty() {
    tokens.push(token)
    current.reset()
  }
}

///|
fn append_quadratic_path_points(
  points : Array[(Double, Double)],
  start_x : Double,
  start_y : Double,
  control_x : Double,
  control_y : Double,
  end_x : Double,
  end_y : Double,
) -> Unit {
  let segments = 8
  for step in 1..<(segments + 1) {
    let t = step.to_double() / segments.to_double()
    let one_minus_t = 1.0 - t
    let x = one_minus_t * one_minus_t * start_x +
      2.0 * one_minus_t * t * control_x +
      t * t * end_x
    let y = one_minus_t * one_minus_t * start_y +
      2.0 * one_minus_t * t * control_y +
      t * t * end_y
    points.push((x, y))
  }
}

///|
fn append_cubic_path_points(
  points : Array[(Double, Double)],
  start_x : Double,
  start_y : Double,
  control1_x : Double,
  control1_y : Double,
  control2_x : Double,
  control2_y : Double,
  end_x : Double,
  end_y : Double,
) -> Unit {
  let segments = 8
  for step in 1..<(segments + 1) {
    let t = step.to_double() / segments.to_double()
    let one_minus_t = 1.0 - t
    let x = one_minus_t * one_minus_t * one_minus_t * start_x +
      3.0 * one_minus_t * one_minus_t * t * control1_x +
      3.0 * one_minus_t * t * t * control2_x +
      t * t * t * end_x
    let y = one_minus_t * one_minus_t * one_minus_t * start_y +
      3.0 * one_minus_t * one_minus_t * t * control1_y +
      3.0 * one_minus_t * t * t * control2_y +
      t * t * t * end_y
    points.push((x, y))
  }
}

///|
fn append_arc_path_points(
  points : Array[(Double, Double)],
  start_x : Double,
  start_y : Double,
  radius_x : Double,
  radius_y : Double,
  rotation_degrees : Double,
  large_arc : Bool,
  sweep : Bool,
  end_x : Double,
  end_y : Double,
) -> Unit {
  if (start_x == end_x && start_y == end_y) ||
    radius_x == 0.0 ||
    radius_y == 0.0 {
    points.push((end_x, end_y))
    return
  }
  let mut rx = if radius_x < 0.0 { -radius_x } else { radius_x }
  let mut ry = if radius_y < 0.0 { -radius_y } else { radius_y }
  let pi = 3.14159265358979323846
  let phi = rotation_degrees * pi / 180.0
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  let dx = (start_x - end_x) / 2.0
  let dy = (start_y - end_y) / 2.0
  let x1p = cos_phi * dx + sin_phi * dy
  let y1p = -sin_phi * dx + cos_phi * dy
  let lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
  if lambda > 1.0 {
    let scale = lambda.sqrt()
    rx = rx * scale
    ry = ry * scale
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let denominator = rx2 * y1p2 + ry2 * x1p2
  if denominator == 0.0 {
    points.push((end_x, end_y))
    return
  }
  let sq = (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / denominator
  let sq_abs = if sq < 0.0 { 0.0 } else { sq }
  let coef = sq_abs.sqrt() * (if large_arc == sweep { -1.0 } else { 1.0 })
  let cxp = coef * rx * y1p / ry
  let cyp = -coef * ry * x1p / rx
  let center_x = cos_phi * cxp - sin_phi * cyp + (start_x + end_x) / 2.0
  let center_y = sin_phi * cxp + cos_phi * cyp + (start_y + end_y) / 2.0
  let theta1 = clip_path_angle_between(
    1.0,
    0.0,
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
  )
  let mut dtheta = clip_path_angle_between(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  )
  if !sweep && dtheta > 0.0 {
    dtheta = dtheta - 2.0 * pi
  } else if sweep && dtheta < 0.0 {
    dtheta = dtheta + 2.0 * pi
  }
  let segments = clip_path_max_int((dtheta.abs() / pi * 8.0).to_int(), 2)
  for step in 1..<(segments + 1) {
    let t = step.to_double() / segments.to_double()
    let theta = theta1 + t * dtheta
    let cos_t = @math.cos(theta)
    let sin_t = @math.sin(theta)
    let x = cos_phi * rx * cos_t - sin_phi * ry * sin_t + center_x
    let y = sin_phi * rx * cos_t + cos_phi * ry * sin_t + center_y
    points.push((x, y))
  }
}

///|
fn clip_path_angle_between(
  ux : Double,
  uy : Double,
  vx : Double,
  vy : Double,
) -> Double {
  let dot = ux * vx + uy * vy
  let len_product = (ux * ux + uy * uy).sqrt() * (vx * vx + vy * vy).sqrt()
  if len_product == 0.0 {
    return 0.0
  }
  let mut cos_angle = dot / len_product
  if cos_angle > 1.0 {
    cos_angle = 1.0
  }
  if cos_angle < -1.0 {
    cos_angle = -1.0
  }
  let angle = @math.acos(cos_angle)
  let cross = ux * vy - uy * vx
  if cross < 0.0 {
    -angle
  } else {
    angle
  }
}

///|
fn clip_path_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn is_clip_path_path_command(token : String) -> Bool {
  token == "M" ||
  token == "m" ||
  token == "L" ||
  token == "l" ||
  token == "H" ||
  token == "h" ||
  token == "V" ||
  token == "v" ||
  token == "Q" ||
  token == "q" ||
  token == "T" ||
  token == "t" ||
  token == "C" ||
  token == "c" ||
  token == "S" ||
  token == "s" ||
  token == "A" ||
  token == "a" ||
  token == "Z" ||
  token == "z"
}

///|
fn is_clip_path_path_command_char(c : Char) -> Bool {
  c == 'M' ||
  c == 'm' ||
  c == 'L' ||
  c == 'l' ||
  c == 'H' ||
  c == 'h' ||
  c == 'V' ||
  c == 'v' ||
  c == 'Z' ||
  c == 'z' ||
  c == 'C' ||
  c == 'c' ||
  c == 'S' ||
  c == 's' ||
  c == 'Q' ||
  c == 'q' ||
  c == 'T' ||
  c == 't' ||
  c == 'A' ||
  c == 'a'
}

///|
fn clip_path_path_char_to_string(c : Char) -> String {
  let sb = StringBuilder::new()
  sb.write_char(c)
  sb.to_string()
}

///|
fn parse_clip_path_path_number(token : String) -> Double? {
  let value = @string.parse_double(token) catch { _ => return None }
  Some(value)
}

///|
fn split_clip_path_values(content : String) -> Array[String] {
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  for c in content.iter() {
    if c == ',' || c == ' ' || c == '\t' || c == '\n' {
      let s = current.to_string().trim().to_string()
      if !s.is_empty() {
        parts.push(s)
      }
      current = StringBuilder::new()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string().trim().to_string()
  if !last.is_empty() {
    parts.push(last)
  }
  parts
}

///|
fn parse_clip_path_shape_value(value : String) -> Double raise Error {
  let v = value.trim().to_lower()
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_string().trim())
      return -(n / 100.0)
    }
    None => ()
  }
  match v.strip_suffix("px") {
    Some(num_str) => @string.parse_double(num_str.to_string().trim())
    None => @string.parse_double(v)
  }
}

///|
fn parse_clip_path_inset_value(value : String) -> Double {
  let v = value.trim().to_lower()
  match v.strip_suffix("%") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_string().trim()) catch {
        _ => return 0.0
      }
      return -(n / 100.0)
    }
    None => ()
  }
  match v.strip_suffix("px") {
    Some(num_str) => {
      let n = @string.parse_double(num_str.to_string().trim()) catch {
        _ => return 0.0
      }
      return n
    }
    None => ()
  }
  @string.parse_double(v) catch {
    _ => 0.0
  }
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
      let n = @string.parse_double(num_str.to_string().trim()) catch {
        _ => return 0.0
      }
      return n
    }
    None => ()
  }
  // Parse plain number
  let n = @string.parse_double(v.to_string()) catch { _ => return 0.0 }
  n
}
