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
/// Parse display property
fn parse_display(tokens : ArrayView[@token.Token]) -> @types.Display? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "block" {
        Some(@types.Block)
      } else if s == "inline" {
        Some(@types.Inline)
      } else if s == "inline-block" {
        Some(@types.InlineBlock)
      } else if s == "flex" {
        Some(@types.Flex)
      } else if s == "inline-flex" {
        Some(@types.InlineFlex)
      } else if s == "grid" {
        Some(@types.Grid)
      } else if s == "inline-grid" {
        Some(@types.InlineGrid)
      } else if s == "table" {
        Some(@types.Table)
      } else if s == "inline-table" {
        Some(@types.InlineTable)
      } else if s == "table-row" {
        Some(@types.TableRow)
      } else if s == "table-cell" {
        Some(@types.TableCell)
      } else if s == "table-caption" {
        Some(@types.TableCaption)
      } else if s == "table-row-group" {
        Some(@types.TableRowGroup)
      } else if s == "table-header-group" {
        Some(@types.TableHeaderGroup)
      } else if s == "table-footer-group" {
        Some(@types.TableFooterGroup)
      } else if s == "table-column" {
        Some(@types.TableColumn)
      } else if s == "table-column-group" {
        Some(@types.TableColumnGroup)
      } else if s == "none" {
        Some(@types.Display::None)
      } else if s == "contents" {
        Some(@types.Contents)
      } else {
        None
      }
    _ => None
  }
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
fn parse_float(tokens : ArrayView[@token.Token]) -> @types.Float? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "left" {
        Some(@types.Float::Left)
      } else if s == "right" {
        Some(@types.Float::Right)
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
fn parse_clear(tokens : ArrayView[@token.Token]) -> @types.Clear? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "left" {
        Some(@types.Clear::Left)
      } else if s == "right" {
        Some(@types.Clear::Right)
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
/// Parse alignment property (justify-content, align-items, etc.)
fn parse_alignment(tokens : ArrayView[@token.Token]) -> @types.Alignment? {
  if tokens.length() == 0 {
    return None
  }
  match tokens[0] {
    @token.Token::Ident(s) =>
      if s == "flex-start" {
        Some(@types.Alignment::FlexStart)
      } else if s == "start" {
        Some(@types.Alignment::Start)
      } else if s == "flex-end" {
        Some(@types.Alignment::FlexEnd)
      } else if s == "end" {
        Some(@types.Alignment::End)
      } else if s == "center" {
        Some(@types.Alignment::Center)
      } else if s == "space-between" {
        Some(@types.SpaceBetween)
      } else if s == "space-around" {
        Some(@types.SpaceAround)
      } else if s == "space-evenly" {
        Some(@types.SpaceEvenly)
      } else if s == "stretch" {
        Some(@types.Alignment::Stretch)
      } else if s == "baseline" {
        Some(@types.Alignment::Baseline)
      } else {
        None
      }
    _ => None
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
      // When only numbers are specified, basis defaults to 0
      if numbers.length() >= 1 {
        @types.Length(0.0)
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
/// Parse CSS transform from a string value
fn parse_transform_string(value : String) -> @style.Transform {
  let v = value.trim().to_lower()
  // Handle none
  if v == "none" || v.is_empty() {
    return @style.Transform::none()
  }
  let mut translate_x = @style.TranslateValue::Length(0.0)
  let mut translate_y = @style.TranslateValue::Length(0.0)
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
      _ => () // Ignore unsupported functions like rotate, scale, etc.
    }
  }
  { translate_x, translate_y }
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
    let num_str = v[:v.length() - 1].to_string() catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Percent(n / 100.0)
  } else if v.has_suffix("px") {
    let num_str = v[:v.length() - 2].to_string() catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n)
  } else if v.has_suffix("em") || v.has_suffix("rem") {
    // em/rem - convert to pixels assuming 16px base
    let suffix_len = if v.has_suffix("rem") { 3 } else { 2 }
    let num_str = v[:v.length() - suffix_len].to_string() catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    let n = @strconv.parse_double(num_str.trim()) catch {
      _ => return @style.TranslateValue::Length(0.0)
    }
    @style.TranslateValue::Length(n * 16.0)
  } else {
    // Try parsing as plain number (assumed px)
    let n = @strconv.parse_double(v) catch {
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
  if not(last.is_empty()) {
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
    match parse_float(value_tokens) {
      Some(v) => return { ..style, float: v }
      None => ()
    }
  }
  // clear
  if property == "clear" {
    match parse_clear(value_tokens) {
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
  // contain
  if property == "contain" {
    let contain = parse_contain(value_tokens)
    return { ..style, contain, }
  }
  // transform
  if property == "transform" {
    let transform = parse_transform(value_tokens)
    return { ..style, transform, }
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
