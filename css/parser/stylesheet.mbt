///|
/// CSS Stylesheet Parser
/// Parses full stylesheets with selectors and declaration blocks

///|
/// Parse a full stylesheet from CSS text
pub fn parse_stylesheet(css : String) -> @cascade.Stylesheet {
  let stylesheet = @cascade.Stylesheet::new(@cascade.Author)
  let tokens = @token.tokenize(css)
  let mut pos = 0
  while pos < tokens.length() {
    // Skip whitespace
    pos = skip_ws(tokens, pos)
    if pos >= tokens.length() {
      break
    }
    match tokens[pos] {
      @token.Token::EOF => break
      @token.Token::AtKeyword(_) =>
        // Skip @-rules for now (e.g., @media, @import)
        pos = skip_at_rule(tokens, pos)
      _ =>
        // Try to parse a style rule
        match parse_style_rule(tokens, pos) {
          Some((selectors, declarations, new_pos)) => {
            // Add rules for each selector
            for item in selectors {
              let selector_text = item.0
              let selector = item.1
              stylesheet.add_rule(selector_text, selector, declarations.copy())
            }
            pos = new_pos
          }
          None => pos = pos + 1
        }
    }
  }
  stylesheet
}

///|
/// Skip whitespace tokens
fn skip_ws(tokens : Array[@token.Token], pos : Int) -> Int {
  let mut p = pos
  while p < tokens.length() {
    match tokens[p] {
      @token.Token::Whitespace => p = p + 1
      _ => break
    }
  }
  p
}

///|
/// Skip an @-rule (until semicolon or matching braces)
fn skip_at_rule(tokens : Array[@token.Token], start : Int) -> Int {
  let mut pos = start + 1
  let mut brace_depth = 0
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::LeftBrace => {
        brace_depth = brace_depth + 1
        pos = pos + 1
      }
      @token.Token::RightBrace => {
        brace_depth = brace_depth - 1
        pos = pos + 1
        if brace_depth <= 0 {
          break
        }
      }
      @token.Token::Semicolon => {
        if brace_depth == 0 {
          pos = pos + 1
          break
        }
        pos = pos + 1
      }
      @token.Token::EOF => break
      _ => pos = pos + 1
    }
  }
  pos
}

///|
/// Parse a style rule: selector { declarations }
fn parse_style_rule(
  tokens : Array[@token.Token],
  start : Int,
) -> (
  Array[(String, @selector.ComplexSelector)],
  Array[@cascade.Declaration],
  Int,
)? {
  let mut pos = start

  // Collect selector tokens until '{'
  let selector_start = pos
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::LeftBrace => break
      @token.Token::EOF => return None
      _ => pos = pos + 1
    }
  }
  if pos >= tokens.length() {
    return None
  }

  // Extract selector text
  let selector_text = tokens_to_string(tokens, selector_start, pos)

  // Parse selectors (comma-separated)
  let selectors = parse_selector_list_text(selector_text)
  if selectors.is_empty() {
    return None
  }

  // Skip '{'
  pos = pos + 1

  // Parse declarations until '}'
  let declarations : Array[@cascade.Declaration] = []
  let mut decl_order = 0
  while pos < tokens.length() {
    pos = skip_ws(tokens, pos)
    match tokens[pos] {
      @token.Token::RightBrace => {
        pos = pos + 1
        break
      }
      @token.Token::EOF => break
      _ =>
        // Parse declaration
        match parse_rule_declaration(tokens, pos) {
          Some((property, value, importance, new_pos)) => {
            let decl : @cascade.Declaration = {
              property,
              value: @cascade.Value(value),
              origin: @cascade.Author,
              importance,
              specificity: { a: 0, b: 0, c: 0 }, // Will be set during cascade
              source_order: decl_order,
            }
            declarations.push(decl)
            decl_order = decl_order + 1
            pos = new_pos
          }
          None => pos = pos + 1
        }
    }
  }
  Some((selectors, declarations, pos))
}

///|
/// Parse a declaration within a rule block
fn parse_rule_declaration(
  tokens : Array[@token.Token],
  start : Int,
) -> (String, String, @cascade.Importance, Int)? {
  let mut pos = skip_ws(tokens, start)

  // Get property name
  let property = match tokens[pos] {
    @token.Token::Ident(name) => name
    _ => return None
  }
  pos = pos + 1
  pos = skip_ws(tokens, pos)

  // Expect colon
  match tokens[pos] {
    @token.Token::Colon => pos = pos + 1
    _ => return None
  }
  pos = skip_ws(tokens, pos)

  // Collect value tokens until ';' or '}'
  let value_start = pos
  let mut has_important = false
  while pos < tokens.length() {
    match tokens[pos] {
      @token.Token::Semicolon | @token.Token::RightBrace => break
      @token.Token::EOF => break
      @token.Token::Delim('!') => {
        // Check for !important
        let next_pos = skip_ws(tokens, pos + 1)
        match tokens[next_pos] {
          @token.Token::Ident(s) if s.to_lower() == "important" => {
            has_important = true
            pos = next_pos + 1
            continue
          }
          _ => pos = pos + 1
        }
      }
      _ => pos = pos + 1
    }
  }

  // Extract value (excluding !important)
  let value_end = if has_important {
    // Find where !important starts
    let mut end = value_start
    while end < pos {
      match tokens[end] {
        @token.Token::Delim('!') => break
        _ => end = end + 1
      }
    }
    end
  } else {
    pos
  }
  let value = tokens_to_string(tokens, value_start, value_end)
    .trim()
    .to_string()

  // Skip semicolon if present
  if pos < tokens.length() {
    match tokens[pos] {
      @token.Token::Semicolon => pos = pos + 1
      _ => ()
    }
  }
  let importance = if has_important {
    @cascade.Important
  } else {
    @cascade.Normal
  }
  Some((property, value, importance, pos))
}

///|
/// Convert token range to string
fn tokens_to_string(
  tokens : Array[@token.Token],
  start : Int,
  end : Int,
) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    match tokens[i] {
      @token.Token::Ident(s) => buf.write_string(s)
      @token.Token::Hash(s, _) => {
        buf.write_char('#')
        buf.write_string(s)
      }
      @token.Token::Delim(c) => buf.write_char(c)
      @token.Token::Colon => buf.write_char(':')
      @token.Token::Comma => buf.write_char(',')
      @token.Token::Whitespace => buf.write_char(' ')
      @token.Token::Dimension(n, u) => {
        buf.write_string(n.to_string())
        buf.write_string(u)
      }
      @token.Token::Number(n, _) => buf.write_string(n.to_string())
      @token.Token::Percentage(n) => {
        buf.write_string(n.to_string())
        buf.write_char('%')
      }
      @token.Token::String(s) => {
        buf.write_char('"')
        buf.write_string(s)
        buf.write_char('"')
      }
      @token.Token::LeftParen => buf.write_char('(')
      @token.Token::RightParen => buf.write_char(')')
      @token.Token::LeftBracket => buf.write_char('[')
      @token.Token::RightBracket => buf.write_char(']')
      @token.Token::Function(name) => {
        buf.write_string(name)
        buf.write_char('(')
      }
      _ => ()
    }
  }
  buf.to_string()
}

///|
/// Parse comma-separated selector list
fn parse_selector_list_text(
  css : String,
) -> Array[(String, @selector.ComplexSelector)] {
  let result : Array[(String, @selector.ComplexSelector)] = []
  let parts = split_by_comma(css)
  for part in parts {
    let trimmed = part.trim().to_string()
    if not(trimmed.is_empty()) {
      match @selector.parse_selector_text(trimmed) {
        Some(sel) => result.push((trimmed, sel))
        None => ()
      }
    }
  }
  result
}

///|
/// Split string by comma
fn split_by_comma(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    if c == ',' {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    result.push(current.to_string())
  }
  result
}
