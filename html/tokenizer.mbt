///|
/// HTML5 Tokenizer
/// Based on WHATWG HTML5 Parsing Specification
/// https://html.spec.whatwg.org/multipage/parsing.html

///|
/// HTML Token types
pub(all) enum Token {
  Doctype(String)
  StartTag(String, Map[String, String], Bool) // tag, attrs, self_closing
  EndTag(String)
  Character(Char)
  Comment(String)
  EOF
}

///|
/// Tokenizer state
pub(all) struct Tokenizer {
  input : String
  mut pos : Int
  len : Int
}

///|
pub fn Tokenizer::new(input : String) -> Tokenizer {
  { input, pos: 0, len: input.length() }
}

///|
fn Tokenizer::is_eof(self : Tokenizer) -> Bool {
  self.pos >= self.len
}

///|
fn Tokenizer::peek(self : Tokenizer) -> Char? {
  if self.pos >= self.len {
    None
  } else {
    Some(self.input[self.pos].to_int().unsafe_to_char())
  }
}

///|
/// Fast peek without Option wrapping - returns '\x00' for EOF
fn Tokenizer::peek_fast(self : Tokenizer) -> Char {
  if self.pos >= self.len {
    '\x00'
  } else {
    self.input[self.pos].to_int().unsafe_to_char()
  }
}

///|
fn Tokenizer::peek_at(self : Tokenizer, offset : Int) -> Char? {
  let idx = self.pos + offset
  if idx >= self.len || idx < 0 {
    None
  } else {
    Some(self.input[idx].to_int().unsafe_to_char())
  }
}

///|
fn Tokenizer::consume(self : Tokenizer) -> Char? {
  if self.pos >= self.len {
    None
  } else {
    let c = self.input[self.pos].to_int().unsafe_to_char()
    self.pos += 1
    Some(c)
  }
}

///|
/// Fast consume - advances position and returns the character (caller must check bounds)
fn Tokenizer::advance(self : Tokenizer) -> Unit {
  self.pos += 1
}

///|
fn tok_is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn is_ascii_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn tok_is_name_char(c : Char) -> Bool {
  is_ascii_alpha(c) ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':'
}

///|
fn is_unquoted_attr_end(c : Char) -> Bool {
  tok_is_whitespace(c) ||
  c == '>' ||
  c == '/' ||
  c == '=' ||
  c == '"' ||
  c == '\'' ||
  c == '<'
}

///|
fn Tokenizer::skip_whitespace(self : Tokenizer) -> Unit {
  while self.pos < self.len {
    let c = self.peek_fast()
    if tok_is_whitespace(c) {
      self.advance()
    } else {
      break
    }
  }
}

///|
/// Check for a case-insensitive match at current position
fn Tokenizer::matches_ci(self : Tokenizer, s : String) -> Bool {
  if self.pos + s.length() > self.len {
    return false
  }
  for i = 0; i < s.length(); i = i + 1 {
    let c1 = self.input[self.pos + i].to_int().unsafe_to_char()
    let c2 = s[i].to_int().unsafe_to_char()
    let c1_lower = if c1 >= 'A' && c1 <= 'Z' {
      (c1.to_int() + 32).unsafe_to_char()
    } else {
      c1
    }
    let c2_lower = if c2 >= 'A' && c2 <= 'Z' {
      (c2.to_int() + 32).unsafe_to_char()
    } else {
      c2
    }
    if c1_lower != c2_lower {
      return false
    }
  }
  true
}

///|
/// Consume characters matching a name (tag name, attribute name)
fn Tokenizer::consume_name(self : Tokenizer) -> String {
  let start = self.pos
  while self.pos < self.len {
    let c = self.peek_fast()
    if tok_is_name_char(c) {
      self.advance()
    } else {
      break
    }
  }
  self.input.substring(start=start, end=self.pos)
}

///|
/// Consume name and convert to lowercase (for tag names)
fn Tokenizer::consume_name_lower(self : Tokenizer) -> String {
  let start = self.pos
  while self.pos < self.len {
    let c = self.peek_fast()
    if tok_is_name_char(c) {
      self.advance()
    } else {
      break
    }
  }
  self.input.substring(start=start, end=self.pos).to_lower()
}

///|
/// Consume a quoted or unquoted attribute value
fn Tokenizer::consume_attribute_value(self : Tokenizer) -> String {
  self.skip_whitespace()
  if self.pos >= self.len {
    return ""
  }
  let c = self.peek_fast()
  if c == '"' {
    self.advance()
    let start = self.pos
    while self.pos < self.len {
      if self.peek_fast() == '"' {
        let end = self.pos
        self.advance()
        return self.input.substring(start=start, end=end)
      }
      self.advance()
    }
    self.input.substring(start=start, end=self.pos)
  } else if c == '\'' {
    self.advance()
    let start = self.pos
    while self.pos < self.len {
      if self.peek_fast() == '\'' {
        let end = self.pos
        self.advance()
        return self.input.substring(start=start, end=end)
      }
      self.advance()
    }
    self.input.substring(start=start, end=self.pos)
  } else {
    // Unquoted attribute value
    let start = self.pos
    while self.pos < self.len {
      let ch = self.peek_fast()
      if is_unquoted_attr_end(ch) {
        break
      }
      self.advance()
    }
    self.input.substring(start=start, end=self.pos)
  }
}

///|
/// Skip DOCTYPE declaration
fn Tokenizer::skip_doctype(self : Tokenizer) -> Token? {
  if self.matches_ci("<!doctype") {
    // Skip until >
    while self.peek() is Some(c) && c != '>' {
      let _ = self.consume()

    }
    if self.peek() is Some('>') {
      let _ = self.consume()

    }
    Some(Token::Doctype("html"))
  } else {
    None
  }
}

///|
/// Skip comment <!-- ... -->
/// Handles HTML5 abrupt closing of empty comment (<!--> and <!--->)
fn Tokenizer::skip_comment(self : Tokenizer) -> Token? {
  if self.peek() is Some('<') &&
    self.peek_at(1) is Some('!') &&
    self.peek_at(2) is Some('-') &&
    self.peek_at(3) is Some('-') {
    let _ = self.consume() // <
    let _ = self.consume() // !
    let _ = self.consume() // -
    let _ = self.consume() // -
    // HTML5: Check for abrupt closing of empty comment (<!--> or <!-->)
    if self.peek() is Some('>') {
      let _ = self.consume() // >
      return Some(Token::Comment(""))
    }
    if self.peek() is Some('-') && self.peek_at(1) is Some('>') {
      let _ = self.consume() // -
      let _ = self.consume() // >
      return Some(Token::Comment(""))
    }
    let buf = StringBuilder::new()
    while not(self.is_eof()) {
      if self.peek() is Some('-') &&
        self.peek_at(1) is Some('-') &&
        self.peek_at(2) is Some('>') {
        let _ = self.consume() // -
        let _ = self.consume() // -
        let _ = self.consume() // >
        return Some(Token::Comment(buf.to_string()))
      }
      match self.consume() {
        Some(c) => buf.write_char(c)
        None => break
      }
    }
    Some(Token::Comment(buf.to_string()))
  } else {
    None
  }
}

///|
/// Parse a start tag
fn Tokenizer::parse_start_tag(self : Tokenizer) -> Token {
  let tag = self.consume_name_lower()
  let attrs : Map[String, String] = {}
  let mut self_closing = false
  // Parse attributes
  while self.pos < self.len {
    self.skip_whitespace()
    if self.pos >= self.len {
      break
    }
    let c = self.peek_fast()
    if c == '>' {
      self.advance()
      break
    } else if c == '/' {
      self.advance()
      self.skip_whitespace()
      if self.pos < self.len && self.peek_fast() == '>' {
        self.advance()
        self_closing = true
      }
      break
    } else if tok_is_name_char(c) {
      let attr_name = self.consume_name()
      self.skip_whitespace()
      let attr_value = if self.pos < self.len && self.peek_fast() == '=' {
        self.advance()
        self.consume_attribute_value()
      } else {
        ""
      }
      attrs.set(attr_name, attr_value)
    } else {
      // Skip unknown character
      self.advance()
    }
  }
  Token::StartTag(tag, attrs, self_closing)
}

///|
/// Parse an end tag
fn Tokenizer::parse_end_tag(self : Tokenizer) -> Token {
  let tag = self.consume_name_lower()
  self.skip_whitespace()
  if self.pos < self.len && self.peek_fast() == '>' {
    self.advance()
  }
  Token::EndTag(tag)
}

///|
/// Get the next token
pub fn Tokenizer::next_token(self : Tokenizer) -> Token {
  if self.is_eof() {
    return Token::EOF
  }
  match self.peek() {
    Some('<') =>
      // Check for DOCTYPE
      if self.matches_ci("<!doctype") {
        match self.skip_doctype() {
          Some(t) => t
          None => {
            let _ = self.consume()
            Token::Character('<')
          }
        }
      } else if self.peek_at(1) is Some('!') &&
        self.peek_at(2) is Some('-') &&
        self.peek_at(3) is Some('-') {
        // Comment
        match self.skip_comment() {
          Some(t) => t
          None => {
            let _ = self.consume()
            Token::Character('<')
          }
        }
      } else if self.peek_at(1) is Some('/') {
        // End tag
        let _ = self.consume() // <
        let _ = self.consume() // /
        self.skip_whitespace()
        self.parse_end_tag()
      } else {
        match self.peek_at(1) {
          Some(c) if is_ascii_alpha(c) => {
            // Start tag
            let _ = self.consume() // <
            self.parse_start_tag()
          }
          _ =>
            // Not a valid tag, emit as character
            match self.consume() {
              Some(c) => Token::Character(c)
              None => Token::EOF
            }
        }
      }
    Some(c) => {
      let _ = self.consume()
      Token::Character(c)
    }
    None => Token::EOF
  }
}

///|
/// Collect all tokens (for debugging/testing)
pub fn Tokenizer::collect_all(self : Tokenizer) -> Array[Token] {
  let tokens : Array[Token] = []
  while true {
    let token = self.next_token()
    tokens.push(token)
    match token {
      Token::EOF => break
      _ => continue
    }
  }
  tokens
}
