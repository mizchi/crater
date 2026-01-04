///|
/// CSS Media Query Parser
/// Parses media query strings like "@media screen and (min-width: 768px)"

///|
/// Parse a media query list from a string
/// e.g., "screen and (min-width: 768px), print"
pub fn parse_media_query_list(input : String) -> MediaQueryList {
  let queries : Array[MediaQuery] = []
  let parts = split_media_queries(input)
  for part in parts {
    let trimmed = part.trim().to_string()
    if not(trimmed.is_empty()) {
      match parse_single_media_query(trimmed) {
        Some(query) => queries.push(query)
        None => ()
      }
    }
  }
  { queries, }
}

///|
/// Split media queries by comma (top-level only, not inside parentheses)
fn split_media_queries(input : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut paren_depth = 0
  for i = 0; i < input.length(); i = i + 1 {
    let c = input[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
      current.write_char(c)
    } else if c == ')' {
      paren_depth -= 1
      current.write_char(c)
    } else if c == ',' && paren_depth == 0 {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  let final_str = current.to_string()
  if not(final_str.is_empty()) {
    result.push(final_str)
  }
  result
}

///|
/// Parse a single media query
/// e.g., "screen and (min-width: 768px)"
fn parse_single_media_query(input : String) -> MediaQuery? {
  let input = input.trim().to_string()
  if input.is_empty() {
    return None
  }
  let tokens = tokenize_media_query(input)
  if tokens.is_empty() {
    return None
  }
  let mut pos = 0
  let mut negated = false
  let mut only = false
  let mut media_type : MediaType? = None
  let conditions : Array[MediaFeature] = []

  // Check for "not" or "only" prefix
  if pos < tokens.length() {
    let token = tokens[pos].to_lower()
    if token == "not" {
      negated = true
      pos += 1
    } else if token == "only" {
      only = true
      pos += 1
    }
  }

  // Check for media type
  if pos < tokens.length() {
    let token = tokens[pos].to_lower()
    match parse_media_type(token) {
      Some(mt) => {
        media_type = Some(mt)
        pos += 1
      }
      None => ()
    }
  }

  // Parse remaining conditions (and (...))
  while pos < tokens.length() {
    let token = tokens[pos].to_lower()
    if token == "and" {
      pos += 1
      continue
    }
    if token.has_prefix("(") && token.has_suffix(")") {
      // Extract content inside parentheses
      let content = token[1:token.length() - 1].to_string() catch { _ => "" }
      match parse_media_feature(content) {
        Some(feature) => conditions.push(feature)
        None => ()
      }
    }
    pos += 1
  }
  Some({ negated, only, media_type, conditions })
}

///|
/// Tokenize media query string into tokens
fn tokenize_media_query(input : String) -> Array[String] {
  let tokens : Array[String] = []
  let current = StringBuilder::new()
  let mut in_paren = false
  let mut paren_depth = 0
  for i = 0; i < input.length(); i = i + 1 {
    let c = input[i].to_int().unsafe_to_char()
    if c == '(' {
      if paren_depth == 0 {
        // Push any preceding token
        let s = current.to_string().trim().to_string()
        if not(s.is_empty()) {
          tokens.push(s)
        }
        current.reset()
        in_paren = true
      }
      paren_depth += 1
      current.write_char(c)
    } else if c == ')' {
      paren_depth -= 1
      current.write_char(c)
      if paren_depth == 0 {
        in_paren = false
        let s = current.to_string().trim().to_string()
        if not(s.is_empty()) {
          tokens.push(s)
        }
        current.reset()
      }
    } else if c == ' ' || c == '\t' || c == '\n' {
      if in_paren {
        current.write_char(c)
      } else {
        let s = current.to_string().trim().to_string()
        if not(s.is_empty()) {
          tokens.push(s)
        }
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  let final_str = current.to_string().trim().to_string()
  if not(final_str.is_empty()) {
    tokens.push(final_str)
  }
  tokens
}

///|
/// Parse media type from string
fn parse_media_type(s : String) -> MediaType? {
  match s {
    "all" => Some(All)
    "screen" => Some(Screen)
    "print" => Some(Print)
    "speech" => Some(Speech)
    _ => None
  }
}

///|
/// Parse a media feature from the content inside parentheses
/// e.g., "min-width: 768px" or "color" or "width >= 768px"
fn parse_media_feature(content : String) -> MediaFeature? {
  let content = content.trim().to_string()
  if content.is_empty() {
    return None
  }

  // Check for range syntax (e.g., "width >= 768px")
  match parse_range_feature(content) {
    Some(feature) => return Some(feature)
    None => ()
  }

  // Check for colon (property: value)
  let colon_pos = find_char(content, ':')
  if colon_pos >= 0 {
    let name = content[0:colon_pos].to_string() catch { _ => "" }
    let value = content[colon_pos + 1:].to_string() catch { _ => "" }
    return parse_feature_with_value(
      name.trim().to_string(),
      value.trim().to_string(),
    )
  }

  // Boolean feature (no value)
  parse_boolean_feature(content)
}

///|
/// Parse range syntax feature (CSS Media Queries Level 4)
fn parse_range_feature(content : String) -> MediaFeature? {
  // Check for comparison operators
  let ops = [">=", "<=", ">", "<", "="]
  for op in ops {
    let op_pos = find_substring(content, op)
    if op_pos >= 0 {
      let name = content[0:op_pos].to_string() catch { _ => "" }
      let value_str = content[op_pos + op.length():].to_string() catch {
        _ => ""
      }
      match parse_media_value(value_str.trim().to_string()) {
        Some(value) => {
          let range_op = match op {
            ">=" => Ge
            "<=" => Le
            ">" => Gt
            "<" => Lt
            "=" => Eq
            _ => return None
          }
          match name.trim().to_string().to_lower() {
            "width" => return Some(WidthRange(range_op, value))
            "height" => return Some(HeightRange(range_op, value))
            _ => return Some(Custom(name.trim().to_string(), Some(value)))
          }
        }
        None => ()
      }
    }
  }
  None
}

///|
/// Parse a feature with a value (name: value)
fn parse_feature_with_value(name : String, value_str : String) -> MediaFeature? {
  let name_lower = name.to_lower()
  match parse_media_value(value_str) {
    Some(value) =>
      match name_lower {
        "min-width" => Some(MinWidth(value))
        "max-width" => Some(MaxWidth(value))
        "width" => Some(Width(Some(value)))
        "min-height" => Some(MinHeight(value))
        "max-height" => Some(MaxHeight(value))
        "height" => Some(Height(Some(value)))
        "min-aspect-ratio" => Some(MinAspectRatio(value))
        "max-aspect-ratio" => Some(MaxAspectRatio(value))
        "aspect-ratio" => Some(AspectRatio(Some(value)))
        "min-resolution" => Some(MinResolution(value))
        "max-resolution" => Some(MaxResolution(value))
        "resolution" => Some(Resolution(Some(value)))
        "orientation" =>
          match value {
            Ident(s) => Some(Orientation(s))
            _ => Some(Custom(name, Some(value)))
          }
        "display-mode" =>
          match value {
            Ident(s) => Some(DisplayMode(s))
            _ => Some(Custom(name, Some(value)))
          }
        "prefers-color-scheme" =>
          match value {
            Ident(s) => Some(PrefersColorScheme(s))
            _ => Some(Custom(name, Some(value)))
          }
        "prefers-reduced-motion" =>
          match value {
            Ident(s) => Some(PrefersReducedMotion(s))
            _ => Some(Custom(name, Some(value)))
          }
        _ => Some(Custom(name, Some(value)))
      }
    None => Some(Custom(name, None))
  }
}

///|
/// Parse a boolean feature (no value)
fn parse_boolean_feature(name : String) -> MediaFeature? {
  let name_lower = name.to_lower()
  match name_lower {
    "color" => Some(Color)
    "color-gamut" => Some(ColorGamut)
    "color-index" => Some(ColorIndex)
    "grid" => Some(Grid)
    "hover" => Some(Hover)
    "monochrome" => Some(Monochrome)
    "pointer" => Some(Pointer)
    "scripting" => Some(Scripting)
    "update" => Some(Update)
    "width" => Some(Width(None))
    "height" => Some(Height(None))
    "aspect-ratio" => Some(AspectRatio(None))
    "resolution" => Some(Resolution(None))
    _ => Some(Custom(name, None))
  }
}

///|
/// Parse a media value
fn parse_media_value(s : String) -> MediaValue? {
  let s = s.trim().to_string()
  if s.is_empty() {
    return None
  }

  // Check for ratio (e.g., "16/9")
  let slash_pos = find_char(s, '/')
  if slash_pos > 0 {
    let left = s[0:slash_pos].to_string() catch { _ => "" }
    let right = s[slash_pos + 1:].to_string() catch { _ => "" }
    match
      (parse_int(left.trim().to_string()), parse_int(right.trim().to_string())) {
      (Some(l), Some(r)) => return Some(Ratio(l, r))
      _ => ()
    }
  }

  // Check for dimension (e.g., "768px", "2dppx")
  match parse_dimension_value(s) {
    Some((value, unit)) => return Some(Dimension(value, unit))
    None => ()
  }

  // Check for number
  match parse_number_value(s) {
    Some(n) => return Some(Number(n))
    None => ()
  }

  // Otherwise, it's an identifier
  Some(Ident(s))
}

///|
/// Parse a dimension value (number + unit)
fn parse_dimension_value(s : String) -> (Double, String)? {
  let mut num_end = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    if (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '+' {
      num_end = i + 1
    } else {
      break
    }
  }
  if num_end > 0 && num_end < s.length() {
    let num_str = s[0:num_end].to_string() catch { _ => return None }
    let unit = s[num_end:].to_string() catch { _ => return None }
    try {
      let value = @strconv.parse_double(num_str)
      Some((value, unit))
    } catch {
      _ => None
    }
  } else {
    None
  }
}

///|
/// Parse a number value
fn parse_number_value(s : String) -> Double? {
  Some(@strconv.parse_double(s)) catch {
    _ => None
  }
}

///|
/// Parse an integer value
fn parse_int(s : String) -> Int? {
  Some(@strconv.parse_int(s)) catch {
    _ => None
  }
}

///|
/// Find the position of a character in a string
fn find_char(s : String, c : Char) -> Int {
  for i = 0; i < s.length(); i = i + 1 {
    if s[i].to_int().unsafe_to_char() == c {
      return i
    }
  }
  -1
}

///|
/// Find the position of a substring
fn find_substring(s : String, sub : String) -> Int {
  if sub.length() > s.length() {
    return -1
  }
  for i = 0; i <= s.length() - sub.length(); i = i + 1 {
    let mut found = true
    for j = 0; j < sub.length(); j = j + 1 {
      if s[i + j] != sub[j] {
        found = false
        break
      }
    }
    if found {
      return i
    }
  }
  -1
}
