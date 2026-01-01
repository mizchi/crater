///|
/// Inline style parser - parses CSS property declarations
/// e.g., "width: 100px; height: 50px; display: flex"

// Default viewport size for inline parser vh/vw resolution
let default_viewport_width : Double = 1000.0
let default_viewport_height : Double = 1000.0

///|
/// Parse a dimension value (length, percent, auto)
/// vh/vw are converted to Length using default viewport (1000x1000)
fn parse_dimension(tokens : ArrayView[@token.Token]) -> @types.Dimension? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Dimension(value, unit) => {
      if unit == "px" {
        Some(@types.Length(value))
      } else if unit == "%" {
        Some(@types.Percent(value / 100.0))
      } else if unit == "vw" {
        // Convert vw to pixels using default viewport width
        Some(@types.Length(value * default_viewport_width / 100.0))
      } else if unit == "vh" {
        // Convert vh to pixels using default viewport height
        Some(@types.Length(value * default_viewport_height / 100.0))
      } else if unit == "em" || unit == "rem" {
        // em/rem treated as 16px multiplier for now
        Some(@types.Length(value * 16.0))
      } else {
        // Other units treated as px
        Some(@types.Length(value))
      }
    }
    @token.Token::Percentage(value) => Some(@types.Percent(value / 100.0))
    @token.Token::Number(value, _) => {
      // Unitless 0 is valid
      if value == 0.0 {
        Some(@types.Length(0.0))
      } else {
        None
      }
    }
    @token.Token::Ident(s) => {
      if s == "auto" {
        Some(@types.Auto)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Parse multiple dimension values (for shorthand properties like margin, padding)
fn parse_multi_dimensions(tokens : ArrayView[@token.Token], max_count : Int) -> Array[@types.Dimension] {
  let result : Array[@types.Dimension] = []
  let mut rest = tokens
  while result.length() < max_count && rest.length() > 0 {
    // Skip whitespace
    rest = skip_whitespace(rest)
    if rest.length() == 0 {
      break
    }
    // Try to parse a dimension
    match parse_dimension(rest) {
      Some(dim) => {
        result.push(dim)
        rest = rest[1:]
      }
      None => break
    }
  }
  result
}

///|
/// Parse display property
fn parse_display(tokens : ArrayView[@token.Token]) -> @style.Display? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "block" {
        Some(@style.Block)
      } else if s == "flex" {
        Some(@style.Flex)
      } else if s == "grid" {
        Some(@style.Grid)
      } else if s == "none" {
        Some(@style.Display::None)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse position property
fn parse_position(tokens : ArrayView[@token.Token]) -> @style.Position? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "relative" {
        Some(@style.Relative)
      } else if s == "absolute" {
        Some(@style.Absolute)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse flex-direction property
fn parse_flex_direction(
  tokens : ArrayView[@token.Token]
) -> @style.FlexDirection? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "row" {
        Some(@style.Row)
      } else if s == "row-reverse" {
        Some(@style.RowReverse)
      } else if s == "column" {
        Some(@style.Column)
      } else if s == "column-reverse" {
        Some(@style.ColumnReverse)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse flex-wrap property
fn parse_flex_wrap(tokens : ArrayView[@token.Token]) -> @style.FlexWrap? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "nowrap" {
        Some(@style.NoWrap)
      } else if s == "wrap" {
        Some(@style.FlexWrap::Wrap)
      } else if s == "wrap-reverse" {
        Some(@style.WrapReverse)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse alignment property (justify-content, align-items, etc.)
fn parse_alignment(tokens : ArrayView[@token.Token]) -> @style.Alignment? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "flex-start" || s == "start" {
        Some(@style.Alignment::Start)
      } else if s == "flex-end" || s == "end" {
        Some(@style.Alignment::End)
      } else if s == "center" {
        Some(@style.Alignment::Center)
      } else if s == "space-between" {
        Some(@style.SpaceBetween)
      } else if s == "space-around" {
        Some(@style.SpaceAround)
      } else if s == "space-evenly" {
        Some(@style.SpaceEvenly)
      } else if s == "stretch" {
        Some(@style.Alignment::Stretch)
      } else if s == "baseline" {
        Some(@style.Alignment::Baseline)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a numeric value
fn parse_number(tokens : ArrayView[@token.Token]) -> Double? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Number(value, _) => Some(value)
    _ => None
  }
}

///|
/// Parse aspect-ratio property (e.g., "16 / 9" or "1.5")
fn parse_aspect_ratio(tokens : ArrayView[@token.Token]) -> Double? {
  if tokens.length() == 0 {
    return None
  }
  let tokens = skip_whitespace(tokens)
  match tokens[0] {
    @token.Token::Number(value, _) => {
      // Check for "x / y" format
      let rest = skip_whitespace(tokens[1:])
      if rest.length() >= 2 {
        match (rest[0], skip_whitespace(rest[1:])) {
          (@token.Token::Delim('/'), rest2) =>
            if rest2.length() > 0 {
              match rest2[0] {
                @token.Token::Number(divisor, _) =>
                  if divisor != 0.0 {
                    return Some(value / divisor)
                  } else {
                    return Some(value)
                  }
                _ => return Some(value)
              }
            } else {
              return Some(value)
            }
          _ => return Some(value)
        }
      }
      Some(value)
    }
    _ => None
  }
}

///|
/// Parse grid-auto-flow property
fn parse_grid_auto_flow(tokens : ArrayView[@token.Token]) -> @style.GridAutoFlow? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "row" {
        Some(@style.GridAutoFlow::Row)
      } else if s == "column" {
        Some(@style.GridAutoFlow::Column)
      } else if s == "row dense" {
        Some(@style.RowDense)
      } else if s == "column dense" {
        Some(@style.ColumnDense)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse overflow property
fn parse_overflow(tokens : ArrayView[@token.Token]) -> @style.Overflow? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "visible" {
        Some(@style.Visible)
      } else if s == "hidden" {
        Some(@style.Hidden)
      } else if s == "scroll" {
        Some(@style.Scroll)
      } else if s == "auto" {
        Some(@style.Overflow::Auto)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Skip whitespace tokens and return remaining view
fn skip_whitespace(tokens : ArrayView[@token.Token]) -> ArrayView[@token.Token] {
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      @token.Token::Whitespace => i += 1
      _ => break
    }
  }
  tokens[i:]
}

///|
/// Extract property name and value tokens from a declaration
fn parse_declaration(
  tokens : ArrayView[@token.Token]
) -> (String, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }

  // Get property name
  let property_name = match tokens[0] {
    @token.Token::Ident(name) => name
    _ => return None
  }

  // Skip to colon
  let mut pos = 1
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::Whitespace => pos += 1
      @token.Token::Colon => {
        pos += 1
        break
      }
      _ => return None
    }
  }

  // Get value tokens (until semicolon or end)
  let value_start = pos
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::Semicolon | @token.Token::EOF => break
      _ => pos += 1
    }
  }

  let value_tokens = skip_whitespace(tokens[value_start:pos])
  Some((property_name, value_tokens))
}

///|
/// Apply a single property to a style
fn apply_property(
  style : @style.Style,
  property : String,
  value_tokens : ArrayView[@token.Token]
) -> @style.Style {
  // display
  if property == "display" {
    match parse_display(value_tokens) {
      Some(v) => return { ..style, display: v }
      None => ()
    }
  }
  // position
  if property == "position" {
    match parse_position(value_tokens) {
      Some(v) => return { ..style, position: v }
      None => ()
    }
  }
  // width
  if property == "width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, width: v }
      None => ()
    }
  }
  // height
  if property == "height" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, height: v }
      None => ()
    }
  }
  // min-width
  if property == "min-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, min_width: v }
      None => ()
    }
  }
  // min-height
  if property == "min-height" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, min_height: v }
      None => ()
    }
  }
  // max-width
  if property == "max-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, max_width: v }
      None => ()
    }
  }
  // max-height
  if property == "max-height" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, max_height: v }
      None => ()
    }
  }
  // flex-direction
  if property == "flex-direction" {
    match parse_flex_direction(value_tokens) {
      Some(v) => return { ..style, flex_direction: v }
      None => ()
    }
  }
  // flex-wrap
  if property == "flex-wrap" {
    match parse_flex_wrap(value_tokens) {
      Some(v) => return { ..style, flex_wrap: v }
      None => ()
    }
  }
  // justify-content
  if property == "justify-content" {
    match parse_alignment(value_tokens) {
      Some(v) => return { ..style, justify_content: v }
      None => ()
    }
  }
  // align-items
  if property == "align-items" {
    match parse_alignment(value_tokens) {
      Some(v) => return { ..style, align_items: v }
      None => ()
    }
  }
  // align-content
  if property == "align-content" {
    match parse_alignment(value_tokens) {
      Some(v) => return { ..style, align_content: v }
      None => ()
    }
  }
  // flex-grow
  if property == "flex-grow" {
    match parse_number(value_tokens) {
      Some(v) => return { ..style, flex_grow: v }
      None => ()
    }
  }
  // flex-shrink
  if property == "flex-shrink" {
    match parse_number(value_tokens) {
      Some(v) => return { ..style, flex_shrink: v }
      None => ()
    }
  }
  // flex-basis
  if property == "flex-basis" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, flex_basis: v }
      None => ()
    }
  }
  // margin (supports 1, 2, 3, or 4 values)
  if property == "margin" {
    let dims = parse_multi_dimensions(value_tokens, 4)
    match dims.length() {
      1 => {
        // All sides
        let v = dims[0]
        return { ..style, margin: { top: v, right: v, bottom: v, left: v } }
      }
      2 => {
        // top/bottom, left/right
        let tb = dims[0]
        let lr = dims[1]
        return { ..style, margin: { top: tb, right: lr, bottom: tb, left: lr } }
      }
      3 => {
        // top, left/right, bottom
        let t = dims[0]
        let lr = dims[1]
        let b = dims[2]
        return { ..style, margin: { top: t, right: lr, bottom: b, left: lr } }
      }
      4 => {
        // top, right, bottom, left
        return { ..style, margin: { top: dims[0], right: dims[1], bottom: dims[2], left: dims[3] } }
      }
      _ => ()
    }
  }
  // margin-left
  if property == "margin-left" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, left: v } }
      None => ()
    }
  }
  // margin-right
  if property == "margin-right" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, right: v } }
      None => ()
    }
  }
  // margin-top
  if property == "margin-top" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, top: v } }
      None => ()
    }
  }
  // margin-bottom
  if property == "margin-bottom" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, margin: { ..style.margin, bottom: v } }
      None => ()
    }
  }
  // padding (supports 1, 2, 3, or 4 values)
  if property == "padding" {
    let dims = parse_multi_dimensions(value_tokens, 4)
    match dims.length() {
      1 => {
        let v = dims[0]
        return { ..style, padding: { top: v, right: v, bottom: v, left: v } }
      }
      2 => {
        let tb = dims[0]
        let lr = dims[1]
        return { ..style, padding: { top: tb, right: lr, bottom: tb, left: lr } }
      }
      3 => {
        let t = dims[0]
        let lr = dims[1]
        let b = dims[2]
        return { ..style, padding: { top: t, right: lr, bottom: b, left: lr } }
      }
      4 => {
        return { ..style, padding: { top: dims[0], right: dims[1], bottom: dims[2], left: dims[3] } }
      }
      _ => ()
    }
  }
  // padding-left
  if property == "padding-left" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, left: v } }
      None => ()
    }
  }
  // padding-right
  if property == "padding-right" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, right: v } }
      None => ()
    }
  }
  // padding-top
  if property == "padding-top" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, top: v } }
      None => ()
    }
  }
  // padding-bottom
  if property == "padding-bottom" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, padding: { ..style.padding, bottom: v } }
      None => ()
    }
  }
  // gap
  if property == "gap" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, row_gap: v, column_gap: v }
      None => ()
    }
  }
  // row-gap
  if property == "row-gap" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, row_gap: v }
      None => ()
    }
  }
  // column-gap
  if property == "column-gap" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, column_gap: v }
      None => ()
    }
  }
  // overflow
  if property == "overflow" {
    match parse_overflow(value_tokens) {
      Some(v) => return { ..style, overflow_x: v, overflow_y: v }
      None => ()
    }
  }
  // overflow-x
  if property == "overflow-x" {
    match parse_overflow(value_tokens) {
      Some(v) => return { ..style, overflow_x: v }
      None => ()
    }
  }
  // overflow-y
  if property == "overflow-y" {
    match parse_overflow(value_tokens) {
      Some(v) => return { ..style, overflow_y: v }
      None => ()
    }
  }
  // border (single value)
  if property == "border-width" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { left: v, right: v, top: v, bottom: v } }
      None => ()
    }
  }
  // border-left-width
  if property == "border-left-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, left: v } }
      None => ()
    }
  }
  // border-right-width
  if property == "border-right-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, right: v } }
      None => ()
    }
  }
  // border-top-width
  if property == "border-top-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, top: v } }
      None => ()
    }
  }
  // border-bottom-width
  if property == "border-bottom-width" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, border: { ..style.border, bottom: v } }
      None => ()
    }
  }
  // inset (top, right, bottom, left - single value for now)
  if property == "inset" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, inset: { left: v, right: v, top: v, bottom: v } }
      None => ()
    }
  }
  // top
  if property == "top" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, top: v } }
      None => ()
    }
  }
  // right
  if property == "right" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, right: v } }
      None => ()
    }
  }
  // bottom
  if property == "bottom" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, bottom: v } }
      None => ()
    }
  }
  // left
  if property == "left" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, inset: { ..style.inset, left: v } }
      None => ()
    }
  }
  // aspect-ratio
  if property == "aspect-ratio" {
    match parse_aspect_ratio(value_tokens) {
      Some(v) => return { ..style, aspect_ratio: Some(v) }
      None => ()
    }
  }
  // grid-auto-flow
  if property == "grid-auto-flow" {
    match parse_grid_auto_flow(value_tokens) {
      Some(v) => return { ..style, grid_auto_flow: v }
      None => ()
    }
  }
  // Unknown property - ignore
  style
}

///|
/// Parse inline CSS style string and return a Style object
/// e.g., "width: 100px; height: 50px; display: flex"
pub fn parse_inline_style(css : String) -> @style.Style {
  let tokens = @token.tokenize(css)
  let mut style = @style.Style::default()
  let mut pos = 0
  while pos < tokens.length() {
    // Skip leading whitespace and semicolons
    match tokens[pos] {
      @token.Token::Whitespace | @token.Token::Semicolon => {
        pos += 1
        continue
      }
      @token.Token::EOF => break
      _ => ()
    }

    // Try to parse a declaration
    match parse_declaration(tokens[pos:]) {
      Some((property, value_tokens)) => {
        style = apply_property(style, property, value_tokens)
        // Skip to next semicolon or end
        while pos < tokens.length() {
          match tokens[pos] {
            @token.Token::Semicolon => {
              pos += 1
              break
            }
            @token.Token::EOF => break
            _ => pos += 1
          }
        }
      }
      None => pos += 1
    }
  }
  style
}
