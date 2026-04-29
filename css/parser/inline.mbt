///|
/// Inline style parser - parses CSS property declarations
/// e.g., "width: 100px; height: 50px; display: flex"

// Default viewport size for inline parser vh/vw resolution
let default_viewport_width : Double = 1000.0

///|
let default_viewport_height : Double = 1000.0

///|
/// Parse a calc() expression and try to simplify it to a Dimension
/// Returns Some(dimension) if simplification is possible, None otherwise
fn parse_calc_expression(
  tokens : ArrayView[@token.Token],
) -> (@types.Dimension, ArrayView[@token.Token])? {
  // Skip the Function("calc") token - we're already past it
  // Parse tokens until RightParen, collecting values and operators
  let mut remaining = tokens
  let mut result_px : Double = 0.0
  let mut result_pct : Double = 0.0
  let mut current_op : Char = '+'
  while remaining.length() > 0 {
    remaining = skip_whitespace(remaining)
    if remaining.length() == 0 {
      break
    }
    match remaining[0] {
      @token.Token::RightParen => {
        // End of calc expression
        let next_tokens = remaining[1:]
        // Determine final dimension type
        if result_pct.abs() < 0.0001 {
          // Pure length
          return Some((@types.Length(result_px), next_tokens))
        } else if result_px.abs() < 0.0001 {
          // Pure percentage
          return Some((@types.Percent(result_pct / 100.0), next_tokens))
        } else {
          // Mixed - cannot simplify (return None to fall back to Auto)
          return None
        }
      }
      @token.Token::Dimension(value, unit) => {
        if unit == "px" {
          match current_op {
            '+' => result_px = result_px + value
            '-' => result_px = result_px - value
            '*' => result_px = result_px * value
            '/' => result_px = result_px / value
            _ => ()
          }
        } else if unit == "%" {
          match current_op {
            '+' => result_pct = result_pct + value
            '-' => result_pct = result_pct - value
            '*' => result_pct = result_pct * value
            '/' => result_pct = result_pct / value
            _ => ()
          }
        }
        remaining = remaining[1:]
      }
      @token.Token::Percentage(value) => {
        match current_op {
          '+' => result_pct = result_pct + value
          '-' => result_pct = result_pct - value
          '*' => result_pct = result_pct * value
          '/' => result_pct = result_pct / value
          _ => ()
        }
        remaining = remaining[1:]
      }
      @token.Token::Number(value, _) =>
        // Unitless number - treat as px if 0, otherwise ignore
        if value == 0.0 {
          // 0 has no effect
          remaining = remaining[1:]
        } else {
          // Non-zero unitless number in calc - skip for now
          remaining = remaining[1:]
        }
      @token.Token::Delim(c) =>
        if c == '+' || c == '-' || c == '*' || c == '/' {
          current_op = c
          remaining = remaining[1:]
        } else {
          remaining = remaining[1:]
        }
      _ => remaining = remaining[1:]
    }
  }
  None
}

///|
/// Parse a dimension value (length, percent, auto)
/// vh/vw are converted to Length using default viewport (1000x1000)
fn parse_dimension(tokens : ArrayView[@token.Token]) -> @types.Dimension? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Function(name) =>
      if name == "calc" {
        // Try to parse and simplify calc expression
        match parse_calc_expression(tokens[1:]) {
          Some((dim, _)) => return Some(dim)
          None => return Some(@types.Auto) // Fallback for complex calc
        }
      } else {
        None
      }
    @token.Token::Dimension(value, unit) =>
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
    @token.Token::Percentage(value) => Some(@types.Percent(value / 100.0))
    @token.Token::Number(value, _) =>
      // Unitless 0 is valid
      if value == 0.0 {
        Some(@types.Length(0.0))
      } else {
        None
      }
    @token.Token::Ident(s) =>
      if s == "auto" {
        Some(@types.Auto)
      } else if s == "min-content" {
        Some(@types.MinContent)
      } else if s == "max-content" {
        Some(@types.MaxContent)
      } else if s == "fit-content" {
        // fit-content without argument is equivalent to fit-content(max-content)
        // Using infinity to represent unbounded
        Some(@types.FitContent(1.0e10))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse multiple dimension values (for shorthand properties like margin, padding)
fn parse_multi_dimensions(
  tokens : ArrayView[@token.Token],
  max_count : Int,
) -> Array[@types.Dimension] {
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
fn parse_display_keyword(keyword : String) -> @types.Display? {
  if keyword == "block" {
    Some(@types.Block)
  } else if keyword == "inline" {
    Some(@types.Inline)
  } else if keyword == "inline-block" {
    Some(@types.InlineBlock)
  } else if keyword == "flex" {
    Some(@types.Flex)
  } else if keyword == "inline-flex" {
    Some(@types.InlineFlex)
  } else if keyword == "grid" {
    Some(@types.Grid)
  } else if keyword == "inline-grid" {
    Some(@types.InlineGrid)
  } else if keyword == "table" {
    Some(@types.Table)
  } else if keyword == "inline-table" {
    Some(@types.InlineTable)
  } else if keyword == "table-row" {
    Some(@types.TableRow)
  } else if keyword == "table-cell" {
    Some(@types.TableCell)
  } else if keyword == "table-caption" {
    Some(@types.TableCaption)
  } else if keyword == "table-row-group" {
    Some(@types.TableRowGroup)
  } else if keyword == "table-header-group" {
    Some(@types.TableHeaderGroup)
  } else if keyword == "table-footer-group" {
    Some(@types.TableFooterGroup)
  } else if keyword == "table-column" {
    Some(@types.TableColumn)
  } else if keyword == "table-column-group" {
    Some(@types.TableColumnGroup)
  } else if keyword == "none" {
    Some(@types.Display::None)
  } else if keyword == "contents" {
    Some(@types.Contents)
  } else if keyword == "flow-root" {
    Some(@types.FlowRoot)
  } else if keyword == "math" {
    Some(@types.Inline)
  } else {
    None
  }
}

///|
/// Parse display property
fn parse_display(tokens : ArrayView[@token.Token]) -> @types.Display? {
  if tokens.length() == 0 {
    return None
  }
  let keywords : Array[String] = []
  for token in tokens {
    match token {
      @token.Token::Ident(s) => keywords.push(s)
      @token.Token::Whitespace => ()
      _ => return None
    }
  }
  if keywords.length() == 0 {
    return None
  }
  if keywords.length() == 2 {
    let first = keywords[0]
    let second = keywords[1]
    if (first == "math" && second == "inline") ||
      (first == "inline" && second == "math") {
      return Some(@types.Inline)
    }
    if (first == "math" && second == "block") ||
      (first == "block" && second == "math") {
      return Some(@types.Block)
    }
    if (first == "flow-root" && second == "list-item") ||
      (first == "list-item" && second == "flow-root") {
      return Some(@types.FlowRoot)
    }
  }
  if keywords.length() != 1 {
    return None
  }
  parse_display_keyword(keywords[0])
}

///|
/// Parse position property
fn parse_position(tokens : ArrayView[@token.Token]) -> @types.Position? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "relative" {
        Some(@types.Relative)
      } else if s == "absolute" {
        Some(@types.Absolute)
      } else if s == "fixed" {
        Some(@types.Fixed)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse float property
fn parse_float(
  tokens : ArrayView[@token.Token],
  direction : @style.Direction,
) -> @types.Float? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "left" {
        Some(@types.Float::Left)
      } else if s == "right" {
        Some(@types.Float::Right)
      } else if s == "inline-start" {
        Some(
          if direction.is_rtl() {
            @types.Float::Right
          } else {
            @types.Float::Left
          },
        )
      } else if s == "inline-end" {
        Some(
          if direction.is_rtl() {
            @types.Float::Left
          } else {
            @types.Float::Right
          },
        )
      } else if s == "none" {
        Some(@types.Float::None)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse clear property
fn parse_clear(
  tokens : ArrayView[@token.Token],
  direction : @style.Direction,
) -> @types.Clear? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "left" {
        Some(@types.Clear::Left)
      } else if s == "right" {
        Some(@types.Clear::Right)
      } else if s == "inline-start" {
        Some(
          if direction.is_rtl() {
            @types.Clear::Right
          } else {
            @types.Clear::Left
          },
        )
      } else if s == "inline-end" {
        Some(
          if direction.is_rtl() {
            @types.Clear::Left
          } else {
            @types.Clear::Right
          },
        )
      } else if s == "both" {
        Some(@types.Clear::Both)
      } else if s == "none" {
        Some(@types.Clear::None)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse flex-direction property
fn parse_flex_direction(
  tokens : ArrayView[@token.Token],
) -> @types.FlexDirection? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "row" {
        Some(@types.Row)
      } else if s == "row-reverse" {
        Some(@types.RowReverse)
      } else if s == "column" {
        Some(@types.Column)
      } else if s == "column-reverse" {
        Some(@types.ColumnReverse)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse flex-wrap property
fn parse_flex_wrap(tokens : ArrayView[@token.Token]) -> @types.FlexWrap? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "nowrap" {
        Some(@types.NoWrap)
      } else if s == "wrap" {
        Some(@types.FlexWrap::Wrap)
      } else if s == "wrap-reverse" {
        Some(@types.WrapReverse)
      } else {
        None
      }
    _ => None
  }
}

///|
fn parse_alignment_keyword(value : String) -> @types.Alignment? {
  if value == "flex-start" {
    Some(@types.Alignment::FlexStart)
  } else if value == "start" {
    Some(@types.Alignment::Start)
  } else if value == "flex-end" {
    Some(@types.Alignment::FlexEnd)
  } else if value == "end" {
    Some(@types.Alignment::End)
  } else if value == "left" {
    Some(@types.Alignment::Left)
  } else if value == "right" {
    Some(@types.Alignment::Right)
  } else if value == "center" {
    Some(@types.Alignment::Center)
  } else if value == "space-between" {
    Some(@types.SpaceBetween)
  } else if value == "space-around" {
    Some(@types.SpaceAround)
  } else if value == "space-evenly" {
    Some(@types.SpaceEvenly)
  } else if value == "stretch" {
    Some(@types.Alignment::Stretch)
  } else if value == "baseline" || value == "first baseline" {
    Some(@types.Alignment::Baseline)
  } else if value == "last baseline" {
    Some(@types.Alignment::End)
  } else {
    None
  }
}

///|
fn collect_alignment_parts(tokens : ArrayView[@token.Token]) -> Array[String] {
  let parts : Array[String] = []
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      @token.Token::Ident(s) => parts.push(s)
      _ => ()
    }
  }
  parts
}

///|
fn parse_alignment_segment_with_overflow(
  parts : Array[String],
  start : Int,
) -> ((@types.Alignment, Bool), Int)? {
  if start >= parts.length() {
    return None
  }

  let mut idx = start
  let mut is_safe = false
  let mut is_unsafe = false
  if parts[idx] == "safe" {
    is_safe = true
    idx = idx + 1
  } else if parts[idx] == "unsafe" {
    is_unsafe = true
    idx = idx + 1
  }
  if idx >= parts.length() {
    return None
  }

  let keyword = if idx + 1 < parts.length() &&
    parts[idx + 1] == "baseline" &&
    (parts[idx] == "first" || parts[idx] == "last") {
    parts[idx] + " baseline"
  } else {
    parts[idx]
  }
  let next_index = if keyword == parts[idx] { idx + 1 } else { idx + 2 }

  match parse_alignment_keyword(keyword) {
    Some(parsed) => {
      let alignment = if is_safe {
        match parsed {
          @types.Alignment::Center
          | @types.Alignment::End
          | @types.Alignment::FlexEnd => @types.Alignment::Start
          _ => parsed
        }
      } else {
        parsed
      }
      Some(((alignment, is_unsafe), next_index))
    }
    None => None
  }
}

///|
fn parse_alignment_segment(
  parts : Array[String],
  start : Int,
) -> (@types.Alignment, Int)? {
  match parse_alignment_segment_with_overflow(parts, start) {
    Some(((alignment, _), next_index)) => Some((alignment, next_index))
    None => None
  }
}

///|
fn parse_alignment_with_overflow(
  tokens : ArrayView[@token.Token],
) -> (@types.Alignment, Bool)? {
  let parts = collect_alignment_parts(tokens)
  match parse_alignment_segment_with_overflow(parts, 0) {
    Some(((alignment, is_unsafe), _)) => Some((alignment, is_unsafe))
    None => None
  }
}

///|
/// Parse alignment property (justify-content, align-items, etc.)
fn parse_alignment(tokens : ArrayView[@token.Token]) -> @types.Alignment? {
  let parts = collect_alignment_parts(tokens)
  match parse_alignment_segment(parts, 0) {
    Some((alignment, _)) => Some(alignment)
    None => None
  }
}

///|
fn parse_place_content_with_overflow(
  tokens : ArrayView[@token.Token],
) -> ((@types.Alignment, Bool), (@types.Alignment, Bool))? {
  let parts = collect_alignment_parts(tokens)
  match parse_alignment_segment_with_overflow(parts, 0) {
    Some((align_content, next_index)) =>
      if next_index >= parts.length() {
        Some((align_content, align_content))
      } else {
        match parse_alignment_segment_with_overflow(parts, next_index) {
          Some((justify_content, _)) => Some((align_content, justify_content))
          None => Some((align_content, align_content))
        }
      }
    None => None
  }
}

///|
/// Parse self-alignment property (align-self, justify-self)
fn parse_self_alignment(tokens : ArrayView[@token.Token]) -> @types.AlignSelf? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "auto" {
        Some(@types.AlignSelf::Auto)
      } else if s == "flex-start" || s == "start" {
        Some(@types.AlignSelf::Start)
      } else if s == "flex-end" || s == "end" {
        Some(@types.AlignSelf::End)
      } else if s == "center" {
        Some(@types.AlignSelf::Center)
      } else if s == "stretch" {
        Some(@types.AlignSelf::Stretch)
      } else if s == "baseline" {
        Some(@types.AlignSelf::Baseline)
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
/// Parse an integer value
fn parse_integer(tokens : ArrayView[@token.Token]) -> Int? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Number(value, _) => Some(value.to_int())
    _ => None
  }
}

///|
/// Parse flex shorthand property
/// flex: none | auto | <flex-grow> [<flex-shrink>] [<flex-basis>]
/// The values can appear in any order, with these rules:
/// - Numbers are flex-grow (first) and flex-shrink (second)
/// - Dimensions/percentages/keywords are flex-basis
fn parse_flex_shorthand(
  tokens : ArrayView[@token.Token],
) -> (Double, Double, @types.Dimension)? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }

  // Check for keyword values
  match tokens[0] {
    @token.Token::Ident(s) => {
      if s == "none" {
        // flex: none = 0 0 auto
        return Some((0.0, 0.0, @types.Auto))
      }
      if s == "auto" {
        // flex: auto = 1 1 auto
        return Some((1.0, 1.0, @types.Auto))
      }
      if s == "initial" {
        // flex: initial = 0 1 auto
        return Some((0.0, 1.0, @types.Auto))
      }
    }
    _ => ()
  }

  // CSS flex shorthand order: <flex-grow> [<flex-shrink>] [<flex-basis>]
  // Numbers must come first, then optionally a basis value.
  // Invalid orderings like "1 0% 1" (basis in middle) must return None.
  let numbers : Array[Double] = []
  let mut basis : @types.Dimension? = None
  let mut tokens_view = tokens
  let mut seen_basis = false

  // First, parse all leading numbers (grow and optionally shrink)
  while tokens_view.length() > 0 {
    tokens_view = skip_whitespace(tokens_view)
    if tokens_view.length() == 0 {
      break
    }
    match tokens_view[0] {
      @token.Token::Number(v, _) => {
        if seen_basis {
          // Number after basis is invalid (e.g., "1 0% 1")
          return None
        }
        numbers.push(v)
        tokens_view = tokens_view[1:]
      }
      @token.Token::Dimension(_, _) | @token.Token::Percentage(_) => {
        // This is flex-basis
        if seen_basis {
          // Second basis value is invalid
          return None
        }
        match parse_dimension(tokens_view) {
          Some(dim) => {
            basis = Some(dim)
            seen_basis = true
            tokens_view = tokens_view[1:]
          }
          None => break
        }
      }
      @token.Token::Ident(s) =>
        // Could be flex-basis keyword (auto, content, etc.)
        if s == "auto" || s == "content" {
          if seen_basis {
            return None
          }
          basis = Some(@types.Auto)
          seen_basis = true
          tokens_view = tokens_view[1:]
        } else {
          break
        }
      _ => break
    }
  }

  // Check for trailing tokens (anything after basis is invalid)
  tokens_view = skip_whitespace(tokens_view)
  if tokens_view.length() > 0 {
    // Still have tokens left - could be invalid like "1 0% 1"
    match tokens_view[0] {
      @token.Token::Number(_, _) =>
        // Number after basis is invalid
        if seen_basis {
          return None
        }
      _ => ()
    }
  }

  // Determine values based on what we found
  let grow = if numbers.length() >= 1 { numbers[0] } else { 1.0 }
  let shrink = if numbers.length() >= 2 { numbers[1] } else { 1.0 }
  let final_basis = match basis {
    Some(b) => b
    None =>
      // CSS spec: when only numbers are specified, basis defaults to 0%.
      if numbers.length() >= 1 {
        @types.Percent(0.0)
      } else {
        @types.Auto
      }
  }
  if numbers.length() == 0 && basis is None {
    return None
  }
  Some((grow, shrink, final_basis))
}

///|
/// Parse flex-flow shorthand property
/// flex-flow: <flex-direction> || <flex-wrap>
fn parse_flex_flow_shorthand(
  tokens : ArrayView[@token.Token],
) -> (@types.FlexDirection, @types.FlexWrap)? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  let mut direction : @types.FlexDirection? = None
  let mut wrap : @types.FlexWrap? = None

  // Parse up to 2 tokens
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      @token.Token::Ident(s) =>
        // Check if it's a flex-direction value
        if s == "row" {
          direction = Some(@types.FlexDirection::Row)
        } else if s == "row-reverse" {
          direction = Some(@types.FlexDirection::RowReverse)
        } else if s == "column" {
          direction = Some(@types.FlexDirection::Column)
        } else if s == "column-reverse" {
          direction = Some(@types.FlexDirection::ColumnReverse)
          // Check if it's a flex-wrap value
        } else if s == "nowrap" {
          wrap = Some(@types.FlexWrap::NoWrap)
        } else if s == "wrap" {
          wrap = Some(@types.FlexWrap::Wrap)
        } else if s == "wrap-reverse" {
          wrap = Some(@types.FlexWrap::WrapReverse)
        }
      @token.Token::Whitespace => ()
      _ => ()
    }
    i += 1
  }

  // If we found at least one value, return with defaults for the other
  if direction is Some(_) || wrap is Some(_) {
    Some(
      (
        direction.unwrap_or(@types.FlexDirection::Row),
        wrap.unwrap_or(@types.FlexWrap::NoWrap),
      ),
    )
  } else {
    None
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
fn parse_grid_auto_flow(
  tokens : ArrayView[@token.Token],
) -> @types.GridAutoFlow? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "row" {
        Some(@types.GridAutoFlow::Row)
      } else if s == "column" {
        Some(@types.GridAutoFlow::Column)
      } else if s == "row dense" {
        Some(@types.RowDense)
      } else if s == "column dense" {
        Some(@types.ColumnDense)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a single track value for MinTrackSizing
fn parse_min_track_sizing(
  tokens : ArrayView[@token.Token],
) -> (@types.MinTrackSizing, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Dimension(value, unit) =>
      if unit == "px" {
        Some((@types.MinTrackSizing::Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((@types.MinTrackSizing::Percent(value / 100.0), tokens[1:]))
      } else {
        Some((@types.MinTrackSizing::Length(value), tokens[1:]))
      }
    @token.Token::Percentage(value) =>
      Some((@types.MinTrackSizing::Percent(value / 100.0), tokens[1:]))
    @token.Token::Number(value, _) =>
      if value == 0.0 {
        Some((@types.MinTrackSizing::Length(0.0), tokens[1:]))
      } else {
        None
      }
    @token.Token::Ident(s) =>
      if s == "auto" {
        Some((@types.MinTrackSizing::Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((@types.MinTrackSizing::MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((@types.MinTrackSizing::MaxContent, tokens[1:]))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a single track value for MaxTrackSizing
fn parse_max_track_sizing(
  tokens : ArrayView[@token.Token],
) -> (@types.MaxTrackSizing, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Dimension(value, unit) =>
      if unit == "px" {
        Some((@types.MaxTrackSizing::Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((@types.MaxTrackSizing::Percent(value / 100.0), tokens[1:]))
      } else if unit == "fr" {
        Some((@types.MaxTrackSizing::Fr(value), tokens[1:]))
      } else {
        Some((@types.MaxTrackSizing::Length(value), tokens[1:]))
      }
    @token.Token::Percentage(value) =>
      Some((@types.MaxTrackSizing::Percent(value / 100.0), tokens[1:]))
    @token.Token::Number(value, _) =>
      if value == 0.0 {
        Some((@types.MaxTrackSizing::Length(0.0), tokens[1:]))
      } else {
        None
      }
    @token.Token::Ident(s) =>
      if s == "auto" {
        Some((@types.MaxTrackSizing::Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((@types.MaxTrackSizing::MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((@types.MaxTrackSizing::MaxContent, tokens[1:]))
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a single track sizing value (without repeat)
fn parse_single_track_sizing(
  tokens : ArrayView[@token.Token],
) -> (@types.SingleTrackSizing, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Dimension(value, unit) =>
      if unit == "px" {
        Some((@types.SingleTrackSizing::Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((@types.SingleTrackSizing::Percent(value / 100.0), tokens[1:]))
      } else if unit == "fr" {
        Some((@types.SingleTrackSizing::Fr(value), tokens[1:]))
      } else {
        Some((@types.SingleTrackSizing::Length(value), tokens[1:]))
      }
    @token.Token::Percentage(value) =>
      Some((@types.SingleTrackSizing::Percent(value / 100.0), tokens[1:]))
    @token.Token::Number(value, _) =>
      if value == 0.0 {
        Some((@types.SingleTrackSizing::Length(0.0), tokens[1:]))
      } else {
        None
      }
    @token.Token::Ident(s) =>
      if s == "auto" {
        Some((@types.SingleTrackSizing::Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((@types.SingleTrackSizing::MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((@types.SingleTrackSizing::MaxContent, tokens[1:]))
      } else {
        None
      }
    @token.Token::Function(name) =>
      if name == "minmax" {
        // Parse minmax(min, max)
        let rest = tokens[1:] // skip Function token (already consumed '(')
        match parse_min_track_sizing(rest) {
          Some((min_val, rest2)) => {
            // Skip whitespace and comma
            let rest3 = skip_whitespace(rest2)
            if rest3.length() == 0 {
              return None
            }
            let rest4 = match rest3[0] {
              @token.Token::Comma => rest3[1:]
              _ => rest3
            }
            match parse_max_track_sizing(rest4) {
              Some((max_val, rest5)) => {
                // Skip to closing paren
                let rest6 = skip_whitespace(rest5)
                if rest6.length() > 0 {
                  match rest6[0] {
                    @token.Token::RightParen => {
                      let next_tokens = rest6[1:]
                      Some(
                        (
                          @types.SingleTrackSizing::MinMax(min_val, max_val),
                          next_tokens,
                        ),
                      )
                    }
                    _ => None
                  }
                } else {
                  None
                }
              }
              None => None
            }
          }
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse a track sizing function (including repeat)
fn parse_track_sizing_function(
  tokens : ArrayView[@token.Token],
) -> (@types.TrackSizingFunction, ArrayView[@token.Token])? {
  let tokens = skip_whitespace(tokens)
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Function(name) =>
      if name == "repeat" {
        // Parse repeat(count, tracks...)
        let rest = tokens[1:]
        let rest = skip_whitespace(rest)
        if rest.length() == 0 {
          return None
        }
        // Parse repeat count
        let (count, rest2) : (@types.RepeatCount, ArrayView[@token.Token]) = match
          rest[0] {
          @token.Token::Number(value, _) =>
            (@types.RepeatCount::Count(value.to_int()), rest[1:])
          @token.Token::Ident(s) =>
            if s == "auto-fill" {
              (@types.RepeatCount::AutoFill, rest[1:])
            } else if s == "auto-fit" {
              (@types.RepeatCount::AutoFit, rest[1:])
            } else {
              return None
            }
          _ => return None
        }
        // Skip comma
        let rest3 = skip_whitespace(rest2)
        if rest3.length() == 0 {
          return None
        }
        let rest4 = match rest3[0] {
          @token.Token::Comma => rest3[1:]
          _ => rest3
        }
        // Parse track list until closing paren
        let tracks : Array[@types.SingleTrackSizing] = []
        let mut remaining = rest4
        while remaining.length() > 0 {
          remaining = skip_whitespace(remaining)
          if remaining.length() == 0 {
            break
          }
          match remaining[0] {
            @token.Token::RightParen => {
              remaining = remaining[1:]
              break
            }
            _ =>
              match parse_single_track_sizing(remaining) {
                Some((track, rest)) => {
                  tracks.push(track)
                  remaining = rest
                }
                None => break
              }
          }
        }
        if tracks.length() > 0 {
          Some((@types.TrackSizingFunction::Repeat(count, tracks), remaining))
        } else {
          None
        }
      } else if name == "minmax" {
        // minmax is also valid as TrackSizingFunction
        match parse_single_track_sizing(tokens) {
          Some((@types.SingleTrackSizing::MinMax(min_val, max_val), rest)) =>
            Some((@types.TrackSizingFunction::MinMax(min_val, max_val), rest))
          _ => None
        }
      } else {
        None
      }
    @token.Token::Dimension(value, unit) =>
      if unit == "px" {
        Some((@types.TrackSizingFunction::Length(value), tokens[1:]))
      } else if unit == "%" {
        Some((@types.TrackSizingFunction::Percent(value / 100.0), tokens[1:]))
      } else if unit == "fr" {
        Some((@types.TrackSizingFunction::Fr(value), tokens[1:]))
      } else {
        Some((@types.TrackSizingFunction::Length(value), tokens[1:]))
      }
    @token.Token::Percentage(value) =>
      Some((@types.TrackSizingFunction::Percent(value / 100.0), tokens[1:]))
    @token.Token::Number(value, _) =>
      if value == 0.0 {
        Some((@types.TrackSizingFunction::Length(0.0), tokens[1:]))
      } else {
        None
      }
    @token.Token::Ident(s) =>
      if s == "auto" {
        Some((@types.TrackSizingFunction::Auto, tokens[1:]))
      } else if s == "min-content" {
        Some((@types.TrackSizingFunction::MinContent, tokens[1:]))
      } else if s == "max-content" {
        Some((@types.TrackSizingFunction::MaxContent, tokens[1:]))
      } else if s == "none" {
        // none means empty template
        None
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse grid-template-columns or grid-template-rows value
fn parse_grid_template_tracks(
  tokens : ArrayView[@token.Token],
) -> Array[@types.TrackSizingFunction] {
  let result : Array[@types.TrackSizingFunction] = []
  let mut remaining = tokens
  while remaining.length() > 0 {
    remaining = skip_whitespace(remaining)
    if remaining.length() == 0 {
      break
    }
    match remaining[0] {
      @token.Token::Semicolon | @token.Token::EOF => break
      @token.Token::Ident(s) =>
        if s == "none" {
          // none means empty template
          return []
        } else {
          match parse_track_sizing_function(remaining) {
            Some((track, rest)) => {
              result.push(track)
              remaining = rest
            }
            None => break
          }
        }
      _ =>
        match parse_track_sizing_function(remaining) {
          Some((track, rest)) => {
            result.push(track)
            remaining = rest
          }
          None => break
        }
    }
  }
  result
}

///|
/// Parse grid-template shorthand: `<rows> / <columns>`
fn parse_grid_template_shorthand(
  tokens : ArrayView[@token.Token],
) -> (Array[@types.TrackSizingFunction], Array[@types.TrackSizingFunction])? {
  let mut slash_index = -1
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      @token.Token::Delim('/') => {
        slash_index = i
        break
      }
      _ => ()
    }
  }
  if slash_index < 0 {
    return None
  }
  let rows = parse_grid_template_tracks(tokens[:slash_index])
  let cols = parse_grid_template_tracks(tokens[slash_index + 1:])
  Some((rows, cols))
}

///|
/// Parse grid-template-columns or grid-template-rows from a raw string
pub fn parse_grid_template_tracks_from_string(
  value : String,
) -> Array[@types.TrackSizingFunction] {
  let tokens = @token.tokenize(value)
  parse_grid_template_tracks(tokens[:])
}

///|
/// Parse overflow property
fn parse_overflow(tokens : ArrayView[@token.Token]) -> @types.Overflow? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "visible" {
        Some(@types.Visible)
      } else if s == "hidden" {
        Some(@types.Hidden)
      } else if s == "clip" {
        Some(@types.Clip)
      } else if s == "scroll" {
        Some(@types.Scroll)
      } else if s == "auto" {
        Some(@types.Overflow::Auto)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse clip property (legacy, for accessibility patterns)
fn parse_clip(tokens : ArrayView[@token.Token]) -> @types.ClipRect {
  if tokens.length() == 0 {
    return @types.ClipRect::Auto
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "auto" || s == "initial" || s == "unset" {
        @types.ClipRect::Auto
      } else {
        @types.ClipRect::Auto
      }
    @token.Token::Function(name) =>
      if name == "rect" {
        // Parse rect(top, right, bottom, left)
        // tokens[1:] contains the arguments
        let args = tokens[1:]
        let values : Array[Double] = []
        for token in args {
          match token {
            @token.Token::Dimension(v, _) => values.push(v)
            @token.Token::Number(v, _) => values.push(v)
            @token.Token::Ident(s) =>
              if s == "auto" {
                values.push(0.0) // auto in rect is treated as 0
              }
            _ => ()
          }
          if values.length() >= 4 {
            break
          }
        }
        if values.length() >= 4 {
          @types.ClipRect::Rect(
            top=values[0],
            right=values[1],
            bottom=values[2],
            left=values[3],
          )
        } else {
          @types.ClipRect::Auto
        }
      } else {
        @types.ClipRect::Auto
      }
    _ => @types.ClipRect::Auto
  }
}

///|
/// Parse clip-path property subset for paint and hit testing.
fn parse_clip_path(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return @style.ClipPath::None
  }
  match remaining[0] {
    @token.Token::Ident(s) =>
      if s == "none" || s == "initial" || s == "unset" {
        @style.ClipPath::None
      } else {
        @style.ClipPath::None
      }
    @token.Token::Function(name) =>
      if name == "inset" {
        parse_clip_path_inset(remaining[1:])
      } else if name == "rect" {
        parse_clip_path_rect(remaining[1:])
      } else if name == "xywh" {
        parse_clip_path_xywh(remaining[1:])
      } else if name == "circle" {
        parse_clip_path_circle(remaining[1:])
      } else if name == "ellipse" {
        parse_clip_path_ellipse(remaining[1:])
      } else if name == "polygon" {
        parse_clip_path_polygon(remaining[1:])
      } else if name == "path" {
        parse_clip_path_path(remaining[1:])
      } else {
        @style.ClipPath::None
      }
    _ => @style.ClipPath::None
  }
}

///|
fn parse_clip_path_inset(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  let values : Array[Double] = []
  for token in tokens {
    match token {
      @token.Token::Dimension(v, unit) =>
        if unit == "%" {
          values.push(-(v / 100.0))
        } else {
          values.push(v)
        }
      @token.Token::Percentage(v) => values.push(-(v / 100.0))
      @token.Token::Number(v, _) => values.push(v)
      @token.Token::Ident(s) => if s == "round" { break }
      @token.Token::RightParen | @token.Token::Semicolon | @token.Token::EOF =>
        break
      _ => ()
    }
    if values.length() >= 4 {
      break
    }
  }
  match values.length() {
    0 => @style.ClipPath::None
    1 => {
      let v = values[0]
      @style.ClipPath::Inset(v, v, v, v)
    }
    2 => {
      let vertical = values[0]
      let horizontal = values[1]
      @style.ClipPath::Inset(vertical, horizontal, vertical, horizontal)
    }
    3 => @style.ClipPath::Inset(values[0], values[1], values[2], values[1])
    _ => @style.ClipPath::Inset(values[0], values[1], values[2], values[3])
  }
}

///|
fn parse_clip_path_rect(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  let values : Array[Double] = []
  for token in tokens {
    match token {
      @token.Token::RightParen | @token.Token::Semicolon | @token.Token::EOF =>
        break
      @token.Token::Whitespace => ()
      _ =>
        match parse_clip_path_shape_token(token) {
          Some(v) => values.push(v)
          None => ()
        }
    }
    if values.length() >= 4 {
      break
    }
  }
  if values.length() < 4 {
    @style.ClipPath::None
  } else {
    @style.ClipPath::Rect(values[0], values[1], values[2], values[3])
  }
}

///|
fn parse_clip_path_xywh(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  let values : Array[Double] = []
  for token in tokens {
    match token {
      @token.Token::Ident(s) => if s == "round" { break }
      @token.Token::RightParen | @token.Token::Semicolon | @token.Token::EOF =>
        break
      @token.Token::Whitespace => ()
      _ =>
        match parse_clip_path_shape_token(token) {
          Some(v) => values.push(v)
          None => ()
        }
    }
    if values.length() >= 4 {
      break
    }
  }
  if values.length() < 4 {
    @style.ClipPath::None
  } else {
    @style.ClipPath::Xywh(values[0], values[1], values[2], values[3])
  }
}

///|
fn parse_clip_path_circle(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  let mut radius = -0.5
  let mut center_x = -0.5
  let mut center_y = -0.5
  let center_values : Array[Double] = []
  let mut seen_at = false
  let mut radius_set = false
  for token in tokens {
    match token {
      @token.Token::Ident(s) =>
        if s == "at" {
          seen_at = true
        } else {
          return @style.ClipPath::None
        }
      @token.Token::RightParen | @token.Token::Semicolon | @token.Token::EOF =>
        break
      @token.Token::Whitespace => ()
      _ =>
        match parse_clip_path_shape_token(token) {
          Some(v) =>
            if seen_at {
              center_values.push(v)
            } else if !radius_set {
              radius = v
              radius_set = true
            }
          None => ()
        }
    }
  }
  if seen_at {
    if center_values.length() < 2 {
      return @style.ClipPath::None
    }
    center_x = center_values[0]
    center_y = center_values[1]
  }
  @style.ClipPath::Circle(radius, center_x, center_y)
}

///|
fn parse_clip_path_ellipse(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  let mut radius_x = -0.5
  let mut radius_y = -0.5
  let mut center_x = -0.5
  let mut center_y = -0.5
  let radii : Array[Double] = []
  let center_values : Array[Double] = []
  let mut seen_at = false
  for token in tokens {
    match token {
      @token.Token::Ident(s) =>
        if s == "at" {
          seen_at = true
        } else {
          return @style.ClipPath::None
        }
      @token.Token::RightParen | @token.Token::Semicolon | @token.Token::EOF =>
        break
      @token.Token::Whitespace => ()
      _ =>
        match parse_clip_path_shape_token(token) {
          Some(v) => if seen_at { center_values.push(v) } else { radii.push(v) }
          None => ()
        }
    }
  }
  if radii.length() == 0 {
    ()
  } else if radii.length() >= 2 {
    radius_x = radii[0]
    radius_y = radii[1]
  } else {
    return @style.ClipPath::None
  }
  if seen_at {
    if center_values.length() < 2 {
      return @style.ClipPath::None
    }
    center_x = center_values[0]
    center_y = center_values[1]
  }
  @style.ClipPath::Ellipse(radius_x, radius_y, center_x, center_y)
}

///|
fn parse_clip_path_polygon(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  let values : Array[Double] = []
  for token in tokens {
    match token {
      @token.Token::Ident(s) =>
        if s == "evenodd" || s == "nonzero" {
          ()
        } else {
          return @style.ClipPath::None
        }
      @token.Token::RightParen | @token.Token::Semicolon | @token.Token::EOF =>
        break
      @token.Token::Whitespace => ()
      _ =>
        match parse_clip_path_shape_token(token) {
          Some(v) => values.push(v)
          None => ()
        }
    }
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
fn parse_clip_path_path(tokens : ArrayView[@token.Token]) -> @style.ClipPath {
  for token in tokens {
    match token {
      @token.Token::String(path_data) =>
        return parse_clip_path_path_data(path_data)
      @token.Token::RightParen | @token.Token::Semicolon | @token.Token::EOF =>
        break
      _ => ()
    }
  }
  @style.ClipPath::None
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
fn parse_clip_path_shape_token(token : @token.Token) -> Double? {
  match token {
    @token.Token::Dimension(v, unit) =>
      if unit == "%" {
        Some(-(v / 100.0))
      } else {
        Some(v)
      }
    @token.Token::Percentage(v) => Some(-(v / 100.0))
    @token.Token::Number(v, _) => Some(v)
    _ => None
  }
}

///|
/// Parse box-sizing property
fn parse_box_sizing(tokens : ArrayView[@token.Token]) -> @types.BoxSizing? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "content-box" {
        Some(@types.ContentBox)
      } else if s == "border-box" {
        Some(@types.BorderBox)
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
/// Parse CSS contain property
/// Supports: none, strict, content, size, inline-size, layout, paint, style
/// Multiple keywords can be combined (e.g., "layout paint")
fn parse_contain(tokens : ArrayView[@token.Token]) -> @style.Contain {
  let mut result = @style.Contain::none()
  let mut remaining = skip_whitespace(tokens)
  while remaining.length() > 0 {
    match remaining[0] {
      @token.Token::Ident(s) => {
        if s == "none" {
          return @style.Contain::none()
        } else if s == "strict" {
          return @style.Contain::strict()
        } else if s == "content" {
          return @style.Contain::content()
        } else if s == "size" {
          result = { ..result, size: true }
        } else if s == "inline-size" {
          result = { ..result, inline_size: true }
        } else if s == "layout" {
          result = { ..result, layout: true }
        } else if s == "paint" {
          result = { ..result, paint: true }
        } else if s == "style" {
          result = { ..result, style: true }
        }
        remaining = skip_whitespace(remaining[1:])
      }
      @token.Token::Whitespace => remaining = skip_whitespace(remaining[1:])
      _ => break
    }
  }
  result
}

///|
fn merge_contain(
  base : @style.Contain,
  extra : @style.Contain,
) -> @style.Contain {
  let merged : @style.Contain = {
    size: base.size || extra.size,
    inline_size: base.inline_size || extra.inline_size,
    layout: base.layout || extra.layout,
    paint: base.paint || extra.paint,
    style: base.style || extra.style,
  }
  if merged.size {
    { ..merged, inline_size: false }
  } else {
    merged
  }
}

///|
/// Parse CSS container-type property into implied containment bits.
/// Supported: normal | size | inline-size
fn parse_container_type(tokens : ArrayView[@token.Token]) -> @style.Contain? {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return None
  }
  match remaining[0] {
    @token.Token::Ident(s) =>
      if s == "normal" {
        Some(@style.Contain::none())
      } else if s == "size" {
        Some({ ..@style.Contain::none(), size: true, style: true })
      } else if s == "inline-size" {
        Some({ ..@style.Contain::none(), inline_size: true, style: true })
      } else {
        None
      }
    _ => None
  }
}

///|
/// Parse contain-intrinsic-inline-size / contain-intrinsic-block-size.
/// Returns a content-box fallback length in px, or None for none/auto.
fn parse_contain_intrinsic_axis(tokens : ArrayView[@token.Token]) -> Double? {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return None
  }
  match remaining[0] {
    @token.Token::Ident(s) =>
      if s == "none" || s == "auto" {
        None
      } else {
        match parse_dimension(remaining) {
          Some(@types.Length(v)) => if v > 0.0 { Some(v) } else { Some(0.0) }
          _ => None
        }
      }
    _ =>
      match parse_dimension(remaining) {
        Some(@types.Length(v)) => if v > 0.0 { Some(v) } else { Some(0.0) }
        _ => None
      }
  }
}

///|
/// Parse contain-intrinsic-size shorthand.
/// One value applies to both inline/block axes; two values map to inline then block.
fn parse_contain_intrinsic_size(
  tokens : ArrayView[@token.Token],
) -> (Double?, Double?)? {
  let mut remaining = skip_whitespace(tokens)
  let axis_values : Array[Double?] = []
  while remaining.length() > 0 {
    match remaining[0] {
      @token.Token::Whitespace => remaining = skip_whitespace(remaining[1:])
      @token.Token::Ident(s) =>
        if s == "auto" {
          remaining = skip_whitespace(remaining[1:])
        } else if s == "none" {
          axis_values.push(None)
          remaining = skip_whitespace(remaining[1:])
        } else {
          match parse_dimension(remaining) {
            Some(@types.Length(v)) =>
              axis_values.push(Some(if v > 0.0 { v } else { 0.0 }))
            _ => ()
          }
          remaining = skip_whitespace(remaining[1:])
        }
      _ => {
        match parse_dimension(remaining) {
          Some(@types.Length(v)) =>
            axis_values.push(Some(if v > 0.0 { v } else { 0.0 }))
          _ => ()
        }
        remaining = skip_whitespace(remaining[1:])
      }
    }
  }
  if axis_values.length() == 0 {
    None
  } else if axis_values.length() == 1 {
    Some((axis_values[0], axis_values[0]))
  } else {
    Some((axis_values[0], axis_values[1]))
  }
}

///|
/// Parse CSS transform property
/// Supports: translate(x, y), translateX(x), translateY(y), translate3d(x, y, z), none
fn parse_transform(tokens : ArrayView[@token.Token]) -> @style.Transform {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return @style.Transform::none()
  }
  // Check for "none"
  match remaining[0] {
    @token.Token::Ident(s) => if s == "none" { return @style.Transform::none() }
    _ => ()
  }
  // Reconstruct the value as string for parsing with the full transform parser
  // Since transform values like "translate(10px, 20px)" are complex,
  // we build the string and reuse the computed transform parser
  let sb = StringBuilder::new()
  for i = 0; i < remaining.length(); i = i + 1 {
    match remaining[i] {
      @token.Token::Ident(s) => sb.write_string(s)
      @token.Token::Function(name) => {
        sb.write_string(name)
        sb.write_char('(')
      }
      @token.Token::Dimension(value, unit) => {
        sb.write_string(value.to_string())
        sb.write_string(unit)
      }
      @token.Token::Percentage(value) => {
        sb.write_string(value.to_string())
        sb.write_char('%')
      }
      @token.Token::Number(value, _) => sb.write_string(value.to_string())
      @token.Token::Comma => sb.write_char(',')
      @token.Token::RightParen => sb.write_char(')')
      @token.Token::LeftParen => sb.write_char('(')
      @token.Token::Whitespace => sb.write_char(' ')
      _ => ()
    }
  }
  let value_str = sb.to_string()
  // Parse the reconstructed string
  parse_transform_string(value_str)
}

///|
fn parse_pointer_events(
  tokens : ArrayView[@token.Token],
) -> @style.PointerEvents {
  let remaining = skip_whitespace(tokens)
  if remaining.length() == 0 {
    return @style.PointerEvents::Auto
  }
  match remaining[0] {
    @token.Token::Ident(s) =>
      if s == "none" {
        @style.PointerEvents::None
      } else {
        @style.PointerEvents::Auto
      }
    _ => @style.PointerEvents::Auto
  }
}

///|
/// Parse CSS transform from a string value
fn parse_transform_string(value : String) -> @style.Transform {
  let v = value.trim().to_lower()
  // Handle none
  if v == "none" || v.is_empty() {
    return @style.Transform::none()
  }
  let mut translate_x = @style.TranslateValue::Length(0.0)
  let mut translate_y = @style.TranslateValue::Length(0.0)
  let mut scale_x = 1.0
  let mut scale_y = 1.0
  let mut rotate_degrees = 0.0
  let mut skew_x_degrees = 0.0
  let mut skew_y_degrees = 0.0
  let mut has_matrix = false
  let mut matrix_a = 1.0
  let mut matrix_b = 0.0
  let mut matrix_c = 0.0
  let mut matrix_d = 1.0
  let mut matrix_e = 0.0
  let mut matrix_f = 0.0
  // Parse transform functions
  let chars = v.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    // Skip whitespace
    while i < len && (chars[i] == ' ' || chars[i] == '\t') {
      i = i + 1
    }
    if i >= len {
      break
    }
    // Find function name
    let func_start = i
    while i < len && chars[i] != '(' {
      i = i + 1
    }
    if i >= len {
      break
    }
    let func_name = transform_chars_to_string(chars[func_start:i])
    i = i + 1 // Skip '('
    // Find function arguments (handle nested parens)
    let args_start = i
    let mut paren_depth = 1
    while i < len && paren_depth > 0 {
      if chars[i] == '(' {
        paren_depth = paren_depth + 1
      } else if chars[i] == ')' {
        paren_depth = paren_depth - 1
      }
      i = i + 1
    }
    let args_str = transform_chars_to_string(chars[args_start:i - 1])
    // Parse transform function
    match func_name.trim() {
      "translate" => {
        // translate(x) or translate(x, y)
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          translate_x = parse_translate_value(args[0])
        }
        if args.length() >= 2 {
          translate_y = parse_translate_value(args[1])
        }
      }
      "translatex" => translate_x = parse_translate_value(args_str)
      "translatey" => translate_y = parse_translate_value(args_str)
      "translate3d" => {
        // translate3d(x, y, z) - we only use x and y
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          translate_x = parse_translate_value(args[0])
        }
        if args.length() >= 2 {
          translate_y = parse_translate_value(args[1])
        }
      }
      "scale" => {
        // scale(x) or scale(x, y)
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          let sx = parse_scale_value(args[0])
          scale_x = scale_x * sx
          scale_y = scale_y * sx
        }
        if args.length() >= 2 {
          scale_y = parse_scale_value(args[1])
        }
      }
      "scalex" => scale_x = scale_x * parse_scale_value(args_str)
      "scaley" => scale_y = scale_y * parse_scale_value(args_str)
      "scale3d" => {
        // scale3d(x, y, z) - we only use x and y
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          scale_x = scale_x * parse_scale_value(args[0])
        }
        if args.length() >= 2 {
          scale_y = scale_y * parse_scale_value(args[1])
        }
      }
      "rotate" =>
        rotate_degrees = rotate_degrees + parse_rotate_degrees(args_str)
      "skewx" => skew_x_degrees += parse_rotate_degrees(args_str)
      "skewy" => skew_y_degrees += parse_rotate_degrees(args_str)
      "skew" => {
        let args = split_transform_args(args_str)
        if args.length() >= 1 {
          skew_x_degrees += parse_rotate_degrees(args[0])
        }
        if args.length() >= 2 {
          skew_y_degrees += parse_rotate_degrees(args[1])
        }
      }
      "matrix" => {
        let args = split_transform_args(args_str)
        if args.length() >= 6 {
          has_matrix = true
          matrix_a = parse_scale_value(args[0])
          matrix_b = parse_scale_value(args[1])
          matrix_c = parse_scale_value(args[2])
          matrix_d = parse_scale_value(args[3])
          matrix_e = parse_scale_value(args[4])
          matrix_f = parse_scale_value(args[5])
        }
      }
      "matrix3d" => {
        let args = split_transform_args(args_str)
        if args.length() >= 16 {
          has_matrix = true
          matrix_a = parse_scale_value(args[0])
          matrix_b = parse_scale_value(args[1])
          matrix_c = parse_scale_value(args[4])
          matrix_d = parse_scale_value(args[5])
          matrix_e = parse_scale_value(args[12])
          matrix_f = parse_scale_value(args[13])
        }
      }
      _ => () // Ignore unsupported functions like matrix/perspective.
    }
  }
  {
    translate_x,
    translate_y,
    scale_x,
    scale_y,
    rotate_degrees,
    skew_x_degrees,
    skew_y_degrees,
    has_matrix,
    matrix_a,
    matrix_b,
    matrix_c,
    matrix_d,
    matrix_e,
    matrix_f,
  }
}

///|
fn parse_rotate_degrees(value : String) -> Double {
  let v = value.trim().to_string()
  if v.is_empty() {
    return 0.0
  }
  if v.has_suffix("deg") {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 3)
    return @string.parse_double(num_str.trim()) catch { _ => 0.0 }
  }
  if v.has_suffix("turn") {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 4)
    let turns = @string.parse_double(num_str.trim()) catch { _ => return 0.0 }
    return turns * 360.0
  }
  if v.has_suffix("rad") {
    let num_str = v.unsafe_substring(start=0, end=v.length() - 3)
    let radians = @string.parse_double(num_str.trim()) catch { _ => return 0.0 }
    return radians * 57.29577951308232
  }
  @string.parse_double(v) catch {
    _ => 0.0
  }
}

///|
/// Parse a scale value (number, no unit)
fn parse_scale_value(value : String) -> Double {
  let v = value.trim()
  if v.is_empty() {
    return 1.0
  }
  @string.parse_double(v) catch {
    _ => 1.0
  }
}

///|
/// Parse a single translate value (can be length or percentage)
fn parse_translate_value(value : String) -> @style.TranslateValue {
  let v = value.trim()
  if v.is_empty() {
    return @style.TranslateValue::Length(0.0)
  }
  // Check for percentage
  if v.has_suffix("%") {
    let num_str = v[:v.length() - 1].to_string()
    let n = @string.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Percent(n / 100.0)
  } else if v.has_suffix("px") {
    let num_str = v[:v.length() - 2].to_string()
    let n = @string.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n)
  } else if v.has_suffix("em") || v.has_suffix("rem") {
    // em/rem - convert to pixels assuming 16px base
    let suffix_len = if v.has_suffix("rem") { 3 } else { 2 }
    let num_str = v[:v.length() - suffix_len].to_string()
    let n = @string.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n * 16.0)
  } else {
    // Try parsing as plain number (assumed px)
    let n = @string.parse_double(v) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n)
  }
}

///|
/// Split string by comma (for transform arguments) - local version
fn split_transform_args(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ',' {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let last = current.to_string()
  if !last.is_empty() {
    result.push(last)
  }
  result
}

///|
/// Convert char array slice to string
fn transform_chars_to_string(chars : ArrayView[Char]) -> String {
  let sb = StringBuilder::new()
  for c in chars {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// Extract property name and value tokens from a declaration
fn parse_declaration(
  tokens : ArrayView[@token.Token],
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
  value_tokens : ArrayView[@token.Token],
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
  // float
  if property == "float" {
    match parse_float(value_tokens, style.direction) {
      Some(v) => return { ..style, float: v }
      None => ()
    }
  }
  // clear
  if property == "clear" {
    match parse_clear(value_tokens, style.direction) {
      Some(v) => return { ..style, clear: v }
      None => ()
    }
  }
  // box-sizing
  if property == "box-sizing" {
    match parse_box_sizing(value_tokens) {
      Some(v) => return { ..style, box_sizing: v }
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
    match parse_alignment_with_overflow(value_tokens) {
      Some((v, is_unsafe)) =>
        return {
          ..style,
          justify_content: v,
          justify_content_unsafe: is_unsafe,
        }
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
    match parse_alignment_with_overflow(value_tokens) {
      Some((v, is_unsafe)) =>
        return { ..style, align_content: v, align_content_unsafe: is_unsafe }
      None => ()
    }
  }
  // place-content
  if property == "place-content" {
    match parse_place_content_with_overflow(value_tokens) {
      Some(
        (
          (align_content, align_content_unsafe),
          (justify_content, justify_content_unsafe),
        )
      ) =>
        return {
          ..style,
          align_content,
          align_content_unsafe,
          justify_content,
          justify_content_unsafe,
        }
      None => ()
    }
  }
  // align-self
  if property == "align-self" {
    match parse_self_alignment(value_tokens) {
      Some(v) => return { ..style, align_self: v }
      None => ()
    }
  }
  // justify-self
  if property == "justify-self" {
    match parse_self_alignment(value_tokens) {
      Some(v) => return { ..style, justify_self: v }
      None => ()
    }
  }
  // justify-items
  if property == "justify-items" {
    match parse_alignment(value_tokens) {
      Some(v) => return { ..style, justify_items: v }
      None => ()
    }
  }
  // flex-grow (must be non-negative)
  if property == "flex-grow" {
    match parse_number(value_tokens) {
      Some(v) if v >= 0.0 => return { ..style, flex_grow: v }
      _ => ()
    }
  }
  // flex-shrink (must be non-negative)
  if property == "flex-shrink" {
    match parse_number(value_tokens) {
      Some(v) if v >= 0.0 => return { ..style, flex_shrink: v }
      _ => ()
    }
  }
  // flex-basis
  if property == "flex-basis" {
    match parse_dimension(value_tokens) {
      Some(v) => return { ..style, flex_basis: v }
      None => ()
    }
  }
  // flex shorthand
  if property == "flex" {
    match parse_flex_shorthand(value_tokens) {
      Some((grow, shrink, basis)) =>
        return {
          ..style,
          flex_grow: grow,
          flex_shrink: shrink,
          flex_basis: basis,
        }
      None => ()
    }
  }
  // flex-flow shorthand
  if property == "flex-flow" {
    match parse_flex_flow_shorthand(value_tokens) {
      Some((direction, wrap)) =>
        return { ..style, flex_direction: direction, flex_wrap: wrap }
      None => ()
    }
  }
  // order
  if property == "order" {
    match parse_integer(value_tokens) {
      Some(v) => return { ..style, order: v }
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
      4 =>
        // top, right, bottom, left
        return {
          ..style,
          margin: {
            top: dims[0],
            right: dims[1],
            bottom: dims[2],
            left: dims[3],
          },
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
        return {
          ..style,
          padding: { top: tb, right: lr, bottom: tb, left: lr },
        }
      }
      3 => {
        let t = dims[0]
        let lr = dims[1]
        let b = dims[2]
        return { ..style, padding: { top: t, right: lr, bottom: b, left: lr } }
      }
      4 =>
        return {
          ..style,
          padding: {
            top: dims[0],
            right: dims[1],
            bottom: dims[2],
            left: dims[3],
          },
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
  // padding-block (logical property: sets top and bottom for horizontal writing mode)
  if property == "padding-block" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, padding: { ..style.padding, top: v, bottom: v } }
      None => ()
    }
  }
  // padding-inline (logical property: sets left and right for horizontal writing mode)
  if property == "padding-inline" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, padding: { ..style.padding, left: v, right: v } }
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
  // clip (legacy, for accessibility)
  if property == "clip" {
    return { ..style, clip: parse_clip(value_tokens) }
  }
  // clip-path (paint/hit-test subset)
  if property == "clip-path" {
    return { ..style, clip_path: parse_clip_path(value_tokens) }
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
  // border-block (logical property: sets top and bottom border width)
  // Shorthand can be: border-block: 10px | border-block: 10px solid | border-block: 10px solid green
  if property == "border-block" {
    // Parse first token as dimension (width)
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, top: v, bottom: v } }
      None => ()
    }
  }
  // border-block-width
  if property == "border-block-width" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, top: v, bottom: v } }
      None => ()
    }
  }
  // border-inline (logical property: sets left and right border width)
  if property == "border-inline" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, left: v, right: v } }
      None => ()
    }
  }
  // border-inline-width
  if property == "border-inline-width" {
    match parse_dimension(value_tokens) {
      Some(v) =>
        return { ..style, border: { ..style.border, left: v, right: v } }
      None => ()
    }
  }
  // inset (supports 1, 2, 3, or 4 values like margin/padding)
  if property == "inset" {
    let dims = parse_multi_dimensions(value_tokens, 4)
    match dims.length() {
      1 => {
        let v = dims[0]
        return { ..style, inset: { top: v, right: v, bottom: v, left: v } }
      }
      2 => {
        let tb = dims[0]
        let lr = dims[1]
        return { ..style, inset: { top: tb, right: lr, bottom: tb, left: lr } }
      }
      3 => {
        let t = dims[0]
        let lr = dims[1]
        let b = dims[2]
        return { ..style, inset: { top: t, right: lr, bottom: b, left: lr } }
      }
      4 =>
        return {
          ..style,
          inset: {
            top: dims[0],
            right: dims[1],
            bottom: dims[2],
            left: dims[3],
          },
        }
      _ => ()
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
  // grid-template-columns
  if property == "grid-template-columns" {
    let tracks = parse_grid_template_tracks(value_tokens)
    return { ..style, grid_template_columns: tracks }
  }
  // grid-template-rows
  if property == "grid-template-rows" {
    let tracks = parse_grid_template_tracks(value_tokens)
    return { ..style, grid_template_rows: tracks }
  }
  // grid-template shorthand: <rows> / <columns>
  if property == "grid-template" {
    match parse_grid_template_shorthand(value_tokens) {
      Some((rows, cols)) =>
        return {
          ..style,
          grid_template_rows: rows,
          grid_template_columns: cols,
        }
      None => ()
    }
  }
  // grid shorthand (partial): support template syntax `<rows> / <columns>`
  if property == "grid" {
    match parse_grid_template_shorthand(value_tokens) {
      Some((rows, cols)) =>
        return {
          ..style,
          grid_template_rows: rows,
          grid_template_columns: cols,
        }
      None => ()
    }
  }
  // contain
  if property == "contain" {
    let contain = parse_contain(value_tokens)
    return { ..style, contain, }
  }
  // container-type
  if property == "container-type" {
    match parse_container_type(value_tokens) {
      Some(implied) =>
        if implied.has_containment() {
          return { ..style, contain: merge_contain(style.contain, implied) }
        } else {
          return style
        }
      None => ()
    }
  }
  // contain-intrinsic-inline-size
  if property == "contain-intrinsic-inline-size" {
    let contain_intrinsic_inline_size = parse_contain_intrinsic_axis(
      value_tokens,
    )
    return { ..style, contain_intrinsic_inline_size, }
  }
  // contain-intrinsic-block-size
  if property == "contain-intrinsic-block-size" {
    let contain_intrinsic_block_size = parse_contain_intrinsic_axis(
      value_tokens,
    )
    return { ..style, contain_intrinsic_block_size, }
  }
  // contain-intrinsic-size
  if property == "contain-intrinsic-size" {
    match parse_contain_intrinsic_size(value_tokens) {
      Some((contain_intrinsic_inline_size, contain_intrinsic_block_size)) =>
        return {
          ..style,
          contain_intrinsic_inline_size,
          contain_intrinsic_block_size,
        }
      None => ()
    }
  }
  // transform
  if property == "transform" {
    let transform = parse_transform(value_tokens)
    return { ..style, transform, }
  }
  // pointer-events
  if property == "pointer-events" {
    let pointer_events = parse_pointer_events(value_tokens)
    return { ..style, pointer_events, }
  }
  // Unknown property - ignore
  style
}

///|
fn seed_direction(tokens : Array[@token.Token]) -> @style.Direction {
  let mut direction = @style.Direction::Ltr
  let mut pos = 0
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::Whitespace | @token.Token::Semicolon => {
        pos += 1
        continue
      }
      @token.Token::EOF => break
      _ => ()
    }

    match parse_declaration(tokens[pos:]) {
      Some((property, value_tokens)) => {
        if property == "direction" {
          match value_tokens.length() {
            0 => ()
            _ =>
              match value_tokens[0] {
                @token.Token::Ident(s) =>
                  if s == "rtl" {
                    direction = @style.Direction::Rtl
                  } else if s == "ltr" {
                    direction = @style.Direction::Ltr
                  }
                _ => ()
              }
          }
        }
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
  direction
}

///|
/// Parse inline CSS style string and return a Style object
/// e.g., "width: 100px; height: 50px; display: flex"
pub fn parse_inline_style(css : String) -> @style.Style {
  let tokens = @token.tokenize(css)
  let mut style = {
    ..@style.Style::default(),
    direction: seed_direction(tokens),
  }
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
  // Convert content-box dimensions to border-box dimensions
  // The layout engine always works with outer (border-box) dimensions
  // For content-box (CSS default), width/height specify content area only,
  // so we need to add padding and border to get the outer dimensions
  adjust_for_box_sizing(style)
}

///|
/// Adjust dimensions for box-sizing: content-box
/// When box-sizing is content-box (default), specified width/height are content dimensions.
/// The layout engine expects outer dimensions (border-box), so we adjust here.
fn adjust_for_box_sizing(style : @style.Style) -> @style.Style {
  match style.box_sizing {
    @types.BorderBox => style // No adjustment needed
    @types.ContentBox => {
      // Calculate padding and border sums
      let padding_h = resolve_dimension_to_px(style.padding.left) +
        resolve_dimension_to_px(style.padding.right)
      let padding_v = resolve_dimension_to_px(style.padding.top) +
        resolve_dimension_to_px(style.padding.bottom)
      let border_h = resolve_dimension_to_px(style.border.left) +
        resolve_dimension_to_px(style.border.right)
      let border_v = resolve_dimension_to_px(style.border.top) +
        resolve_dimension_to_px(style.border.bottom)

      // Adjust width and height to include padding+border
      let adjusted_width = match style.width {
        @types.Dimension::Length(w) =>
          @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_height = match style.height {
        @types.Dimension::Length(h) =>
          @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      // Adjust min/max constraints too
      let adjusted_min_width = match style.min_width {
        @types.Dimension::Length(w) =>
          @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_min_height = match style.min_height {
        @types.Dimension::Length(h) =>
          @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      let adjusted_max_width = match style.max_width {
        @types.Dimension::Length(w) =>
          @types.Dimension::Length(w + padding_h + border_h)
        other => other
      }
      let adjusted_max_height = match style.max_height {
        @types.Dimension::Length(h) =>
          @types.Dimension::Length(h + padding_v + border_v)
        other => other
      }
      {
        ..style,
        width: adjusted_width,
        height: adjusted_height,
        min_width: adjusted_min_width,
        min_height: adjusted_min_height,
        max_width: adjusted_max_width,
        max_height: adjusted_max_height,
        // Mark as adjusted (now using border-box semantics internally)
        box_sizing: @types.BorderBox,
      }
    }
  }
}

///|
/// Helper to resolve a dimension to pixels (for padding/border calculation)
fn resolve_dimension_to_px(dim : @types.Dimension) -> Double {
  match dim {
    @types.Length(v) => v
    @types.Percent(_) => 0.0 // Percentages are resolved later
    @types.Auto => 0.0
    @types.MinContent => 0.0 // Intrinsic sizing resolved during layout
    @types.MaxContent => 0.0
    @types.FitContent(_) => 0.0
  }
}
