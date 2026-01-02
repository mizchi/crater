///|
/// CSS Tokenizer based on CSS Syntax Level 3
/// https://www.w3.org/TR/css-syntax-3/#tokenization

///|
/// Tokenizer state
priv struct Tokenizer {
  input : String
  mut pos : Int
  len : Int
}

///|
fn Tokenizer::new(input : String) -> Tokenizer {
  { input, pos: 0, len: input.length() }
}

///|
/// Peek current character without consuming
fn Tokenizer::peek(self : Tokenizer) -> Char? {
  if self.pos >= self.len {
    None
  } else {
    Some(self.input[self.pos].to_int().unsafe_to_char())
  }
}

///|
/// Peek character at offset from current position
fn Tokenizer::peek_at(self : Tokenizer, offset : Int) -> Char? {
  let idx = self.pos + offset
  if idx >= self.len || idx < 0 {
    None
  } else {
    Some(self.input[idx].to_int().unsafe_to_char())
  }
}

///|
/// Consume and return current character
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
/// Check if at end of input
fn Tokenizer::is_eof(self : Tokenizer) -> Bool {
  self.pos >= self.len
}

///|
/// Check if character is whitespace (space, tab, newline)
fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Check if character is a digit
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Check if character is a letter
fn is_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// Check if character is a name-start character
fn is_name_start(c : Char) -> Bool {
  is_letter(c) || c == '_' || c.to_uint() > 0x7F
}

///|
/// Check if character is a name character
fn is_name_char(c : Char) -> Bool {
  is_name_start(c) || is_digit(c) || c == '-'
}

///|
/// Consume whitespace
fn Tokenizer::consume_whitespace(self : Tokenizer) -> Unit {
  while not(self.is_eof()) {
    match self.peek() {
      Some(c) if is_whitespace(c) => {
        let _ = self.consume()

      }
      _ => break
    }
  }
}

///|
/// Consume an identifier/name
fn Tokenizer::consume_name(self : Tokenizer) -> String {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    match self.peek() {
      Some(c) if is_name_char(c) => {
        buf.write_char(c)
        let _ = self.consume()

      }
      Some('\\') => {
        // Escape sequence - simplified handling
        let _ = self.consume()
        match self.consume() {
          Some(escaped) => buf.write_char(escaped)
          None => ()
        }
      }
      _ => break
    }
  }
  buf.to_string()
}

///|
/// Consume a number
fn Tokenizer::consume_number(self : Tokenizer) -> (Double, NumType) {
  let buf = StringBuilder::new()
  let mut is_integer = true

  // Optional sign
  match self.peek() {
    Some('+') | Some('-') =>
      match self.consume() {
        Some(c) => buf.write_char(c)
        None => ()
      }
    _ => ()
  }

  // Integer part
  while not(self.is_eof()) {
    match self.peek() {
      Some(c) if is_digit(c) => {
        buf.write_char(c)
        let _ = self.consume()

      }
      _ => break
    }
  }

  // Decimal part
  match (self.peek(), self.peek_at(1)) {
    (Some('.'), Some(c)) if is_digit(c) => {
      is_integer = false
      buf.write_char('.')
      let _ = self.consume()
      while not(self.is_eof()) {
        match self.peek() {
          Some(c) if is_digit(c) => {
            buf.write_char(c)
            let _ = self.consume()

          }
          _ => break
        }
      }
    }
    _ => ()
  }

  // Exponent part
  match self.peek() {
    Some('e') | Some('E') =>
      match self.peek_at(1) {
        Some(c) if is_digit(c) || c == '+' || c == '-' => {
          is_integer = false
          match self.consume() {
            Some(e) => buf.write_char(e)
            None => ()
          }
          match self.peek() {
            Some('+') | Some('-') =>
              match self.consume() {
                Some(sign) => buf.write_char(sign)
                None => ()
              }
            _ => ()
          }
          while not(self.is_eof()) {
            match self.peek() {
              Some(c) if is_digit(c) => {
                buf.write_char(c)
                let _ = self.consume()

              }
              _ => break
            }
          }
        }
        _ => ()
      }
    _ => ()
  }
  let num_str = buf.to_string()
  let value = @strconv.parse_double(num_str) catch { _ => 0.0 }
  let num_type : NumType = if is_integer { Integer } else { NumType::Number }
  (value, num_type)
}

///|
/// Consume a string token
fn Tokenizer::consume_string(self : Tokenizer, quote : Char) -> Token {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    match self.consume() {
      Some(c) if c == quote => return Token::String(buf.to_string())
      Some('\n') | Some('\r') => return BadString
      Some('\\') =>
        match self.peek() {
          Some('\n') => {
            let _ = self.consume()
            // Line continuation
          }
          Some(c) => {
            let _ = self.consume()
            buf.write_char(c)
          }
          None => ()
        }
      Some(c) => buf.write_char(c)
      None => return Token::String(buf.to_string())
    }
  }
  Token::String(buf.to_string())
}

///|
/// Check if the next characters would start a number
fn Tokenizer::would_start_number(self : Tokenizer) -> Bool {
  match self.peek() {
    Some('+') | Some('-') =>
      match self.peek_at(1) {
        Some(c) if is_digit(c) => true
        Some('.') =>
          match self.peek_at(2) {
            Some(c) if is_digit(c) => true
            _ => false
          }
        _ => false
      }
    Some('.') =>
      match self.peek_at(1) {
        Some(c) if is_digit(c) => true
        _ => false
      }
    Some(c) if is_digit(c) => true
    _ => false
  }
}

///|
/// Check if the next characters would start an identifier
fn Tokenizer::would_start_ident(self : Tokenizer) -> Bool {
  match self.peek() {
    Some('-') =>
      match self.peek_at(1) {
        Some('-') => true
        Some(c) if is_name_start(c) => true
        Some('\\') => true
        _ => false
      }
    Some(c) if is_name_start(c) => true
    Some('\\') => true
    _ => false
  }
}

///|
/// Consume the next token
fn Tokenizer::next_token(self : Tokenizer) -> Token {
  if self.is_eof() {
    return EOF
  }
  match self.peek() {
    // Whitespace
    Some(c) if is_whitespace(c) => {
      self.consume_whitespace()
      Whitespace
    }

    // Strings
    Some('"') => {
      let _ = self.consume()
      self.consume_string('"')
    }
    Some('\'') => {
      let _ = self.consume()
      self.consume_string('\'')
    }

    // Hash
    Some('#') => {
      let _ = self.consume()
      if self.would_start_ident() ||
        (match self.peek() {
          Some(c) => is_name_char(c)
          None => false
        }) {
        let name = self.consume_name()
        let hash_type : HashType = if self.would_start_ident() {
          Id
        } else {
          Unrestricted
        }
        Hash(name, hash_type)
      } else {
        Delim('#')
      }
    }

    // Parentheses and brackets
    Some('(') => {
      let _ = self.consume()
      LeftParen
    }
    Some(')') => {
      let _ = self.consume()
      RightParen
    }
    Some('[') => {
      let _ = self.consume()
      LeftBracket
    }
    Some(']') => {
      let _ = self.consume()
      RightBracket
    }
    Some('{') => {
      let _ = self.consume()
      LeftBrace
    }
    Some('}') => {
      let _ = self.consume()
      RightBrace
    }

    // Punctuation
    Some(':') => {
      let _ = self.consume()
      Colon
    }
    Some(';') => {
      let _ = self.consume()
      Semicolon
    }
    Some(',') => {
      let _ = self.consume()
      Comma
    }

    // Numbers and signs
    Some('+') =>
      if self.would_start_number() {
        let (value, num_type) = self.consume_number()
        self.finish_numeric_token(value, num_type)
      } else {
        let _ = self.consume()
        Delim('+')
      }
    Some('-') =>
      if self.would_start_number() {
        let (value, num_type) = self.consume_number()
        self.finish_numeric_token(value, num_type)
      } else if self.would_start_ident() {
        let name = self.consume_name()
        self.finish_ident_token(name)
      } else {
        match (self.peek_at(1), self.peek_at(2)) {
          (Some('-'), Some('>')) => {
            let _ = self.consume()
            let _ = self.consume()
            let _ = self.consume()
            CDC
          }
          _ => {
            let _ = self.consume()
            Delim('-')
          }
        }
      }
    Some('.') =>
      if self.would_start_number() {
        let (value, num_type) = self.consume_number()
        self.finish_numeric_token(value, num_type)
      } else {
        let _ = self.consume()
        Delim('.')
      }

    // Numbers
    Some(c) if is_digit(c) => {
      let (value, num_type) = self.consume_number()
      self.finish_numeric_token(value, num_type)
    }

    // At-keyword
    Some('@') => {
      let _ = self.consume()
      if self.would_start_ident() {
        let name = self.consume_name()
        AtKeyword(name)
      } else {
        Delim('@')
      }
    }

    // Identifiers and functions
    Some(c) if is_name_start(c) => {
      let name = self.consume_name()
      self.finish_ident_token(name)
    }

    // Comments (simplified - skip them)
    Some('/') =>
      match self.peek_at(1) {
        Some('*') => {
          let _ = self.consume()
          let _ = self.consume()
          // Skip until */
          while not(self.is_eof()) {
            match (self.peek(), self.peek_at(1)) {
              (Some('*'), Some('/')) => {
                let _ = self.consume()
                let _ = self.consume()
                break
              }
              _ => {
                let _ = self.consume()

              }
            }
          }
          // Recursively get next token after comment
          self.next_token()
        }
        _ => {
          let _ = self.consume()
          Delim('/')
        }
      }

    // CDO <!--
    Some('<') =>
      match (self.peek_at(1), self.peek_at(2), self.peek_at(3)) {
        (Some('!'), Some('-'), Some('-')) => {
          let _ = self.consume()
          let _ = self.consume()
          let _ = self.consume()
          let _ = self.consume()
          CDO
        }
        _ => {
          let _ = self.consume()
          Delim('<')
        }
      }

    // Backslash (escape or delim)
    Some('\\') =>
      match self.peek_at(1) {
        Some('\n') => {
          let _ = self.consume()
          Delim('\\')
        }
        _ => {
          let name = self.consume_name()
          self.finish_ident_token(name)
        }
      }

    // Any other character
    Some(c) => {
      let _ = self.consume()
      Delim(c)
    }
    None => EOF
  }
}

///|
/// Finish a numeric token (check for % or dimension)
fn Tokenizer::finish_numeric_token(
  self : Tokenizer,
  value : Double,
  num_type : NumType,
) -> Token {
  match self.peek() {
    Some('%') => {
      let _ = self.consume()
      Percentage(value)
    }
    Some(c) if is_name_start(c) || c == '-' => {
      let unit = self.consume_name()
      Dimension(value, unit)
    }
    _ => Number(value, num_type)
  }
}

///|
/// Finish an identifier token (check if it's a function)
fn Tokenizer::finish_ident_token(self : Tokenizer, name : String) -> Token {
  match self.peek() {
    Some('(') => {
      let _ = self.consume()
      Function(name)
    }
    _ => Ident(name)
  }
}

///|
/// Tokenize a CSS string into a list of tokens
pub fn tokenize(input : String) -> Array[Token] {
  let tokenizer = Tokenizer::new(input)
  let tokens : Array[Token] = []
  while true {
    let token = tokenizer.next_token()
    tokens.push(token)
    match token {
      EOF => break
      _ => continue
    }
  }
  tokens
}
