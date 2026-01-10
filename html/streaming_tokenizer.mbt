///|
/// Streaming HTML5 Tokenizer
/// Processes HTML in chunks to reduce memory usage

///|
/// Streaming tokenizer that processes HTML incrementally
pub(all) struct StreamingTokenizer {
  buffer : StringBuilder
  /// Cached string from buffer (invalidated on feed/compact)
  mut cached_str : String
  /// Whether cached_str is valid
  mut cache_valid : Bool
  mut pos : Int
  mut finished : Bool
}

///|
pub fn StreamingTokenizer::new() -> StreamingTokenizer {
  {
    buffer: StringBuilder::new(),
    cached_str: "",
    cache_valid: true,
    pos: 0,
    finished: false,
  }
}

///|
/// Get the current string, using cache when possible
fn StreamingTokenizer::get_string(self : StreamingTokenizer) -> String {
  if not(self.cache_valid) {
    self.cached_str = self.buffer.to_string()
    self.cache_valid = true
  }
  self.cached_str
}

///|
/// Add a chunk of HTML to the buffer
pub fn StreamingTokenizer::feed(
  self : StreamingTokenizer,
  chunk : String,
) -> Unit {
  self.buffer.write_string(chunk)
  self.cache_valid = false
}

///|
/// Signal that no more input will be provided
pub fn StreamingTokenizer::finish(self : StreamingTokenizer) -> Unit {
  self.finished = true
}

///|
/// Peek at character at current position
fn StreamingTokenizer::peek(self : StreamingTokenizer) -> Char? {
  let s = self.get_string()
  if self.pos >= s.length() {
    None
  } else {
    Some(s[self.pos].to_int().unsafe_to_char())
  }
}

///|
/// Fast peek - returns '\x00' for EOF/need more data
fn StreamingTokenizer::peek_fast(self : StreamingTokenizer) -> Char {
  let s = self.get_string()
  if self.pos >= s.length() {
    '\u0000'
  } else {
    s[self.pos].to_int().unsafe_to_char()
  }
}

///|
/// Peek at offset from current position
fn StreamingTokenizer::peek_at(
  self : StreamingTokenizer,
  offset : Int,
) -> Char? {
  let s = self.get_string()
  let idx = self.pos + offset
  if idx >= s.length() || idx < 0 {
    None
  } else {
    Some(s[idx].to_int().unsafe_to_char())
  }
}

///|
/// Advance position by 1
fn StreamingTokenizer::advance(self : StreamingTokenizer) -> Unit {
  self.pos += 1
}

///|
/// Check if at end of available data
fn StreamingTokenizer::is_at_end(self : StreamingTokenizer) -> Bool {
  self.pos >= self.get_string().length()
}

///|
fn stok_is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn stok_is_ascii_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn stok_is_name_char(c : Char) -> Bool {
  stok_is_ascii_alpha(c) ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':'
}

///|
fn stok_is_unquoted_attr_end(c : Char) -> Bool {
  stok_is_whitespace(c) ||
  c == '>' ||
  c == '/' ||
  c == '=' ||
  c == '"' ||
  c == '\'' ||
  c == '<'
}

///|
/// Skip whitespace using cached string
fn StreamingTokenizer::skip_whitespace_with_str(
  self : StreamingTokenizer,
  s : String,
) -> Unit {
  while self.pos < s.length() {
    let c = s[self.pos].to_int().unsafe_to_char()
    if stok_is_whitespace(c) {
      self.pos += 1
    } else {
      break
    }
  }
}

///|
/// Check for case-insensitive match using cached string
fn StreamingTokenizer::matches_ci_with_str(
  self : StreamingTokenizer,
  s : String,
  target : String,
) -> Bool {
  let slen = target.length()
  if self.pos + slen > s.length() {
    return false
  }
  for i = 0; i < slen; i = i + 1 {
    let c1 = s[self.pos + i].to_int()
    let c2 = target[i].to_int()
    let c1_lower = if c1 >= 65 && c1 <= 90 { c1 + 32 } else { c1 }
    let c2_lower = if c2 >= 65 && c2 <= 90 { c2 + 32 } else { c2 }
    if c1_lower != c2_lower {
      return false
    }
  }
  true
}

///|
/// Consume a tag/attribute name using cached string
fn StreamingTokenizer::consume_name_with_str(
  self : StreamingTokenizer,
  s : String,
) -> String {
  let start = self.pos
  while self.pos < s.length() {
    let c = s[self.pos].to_int().unsafe_to_char()
    if stok_is_name_char(c) {
      self.pos += 1
    } else {
      break
    }
  }
  s.unsafe_substring(start~, end=self.pos)
}

///|
/// Consume attribute value (quoted or unquoted) using cached string
fn StreamingTokenizer::consume_attribute_value_with_str(
  self : StreamingTokenizer,
  s : String,
) -> String {
  self.skip_whitespace_with_str(s)
  if self.pos >= s.length() {
    return ""
  }
  let c = s[self.pos].to_int().unsafe_to_char()
  if c == '"' {
    self.pos += 1
    let start = self.pos
    while self.pos < s.length() {
      if s[self.pos].to_int().unsafe_to_char() == '"' {
        let end = self.pos
        self.pos += 1
        return decode_html_entities(s.unsafe_substring(start~, end~))
      }
      self.pos += 1
    }
    decode_html_entities(s.unsafe_substring(start~, end=self.pos))
  } else if c == '\'' {
    self.pos += 1
    let start = self.pos
    while self.pos < s.length() {
      if s[self.pos].to_int().unsafe_to_char() == '\'' {
        let end = self.pos
        self.pos += 1
        return decode_html_entities(s.unsafe_substring(start~, end~))
      }
      self.pos += 1
    }
    decode_html_entities(s.unsafe_substring(start~, end=self.pos))
  } else {
    // Unquoted
    let start = self.pos
    while self.pos < s.length() {
      let ch = s[self.pos].to_int().unsafe_to_char()
      if stok_is_unquoted_attr_end(ch) {
        break
      }
      self.pos += 1
    }
    decode_html_entities(s.unsafe_substring(start~, end=self.pos))
  }
}

///|
/// Try to skip DOCTYPE using cached string
fn StreamingTokenizer::try_skip_doctype_with_str(
  self : StreamingTokenizer,
  s : String,
) -> Token?? {
  if not(self.matches_ci_with_str(s, "<!doctype")) {
    return Some(None)
  }
  // Find closing >
  let mut i = self.pos + 9
  while i < s.length() {
    if s[i].to_int().unsafe_to_char() == '>' {
      self.pos = i + 1
      return Some(Some(Token::Doctype("html")))
    }
    i += 1
  }
  // Need more data
  if self.finished {
    self.pos = s.length()
    Some(Some(Token::Doctype("html")))
  } else {
    None
  }
}

///|
/// Try to skip comment using cached string
fn StreamingTokenizer::try_skip_comment_with_str(
  self : StreamingTokenizer,
  s : String,
) -> Token?? {
  // Check for "<!--"
  if self.pos + 4 > s.length() {
    return if self.finished { Some(None) } else { None }
  }
  if s[self.pos].to_int().unsafe_to_char() != '<' {
    return Some(None)
  }
  if s[self.pos + 1].to_int().unsafe_to_char() != '!' ||
    s[self.pos + 2].to_int().unsafe_to_char() != '-' ||
    s[self.pos + 3].to_int().unsafe_to_char() != '-' {
    return Some(None)
  }
  self.pos += 4
  // Check for abrupt closing
  if self.pos < s.length() && s[self.pos].to_int().unsafe_to_char() == '>' {
    self.pos += 1
    return Some(Some(Token::Comment("")))
  }
  if self.pos + 1 < s.length() &&
    s[self.pos].to_int().unsafe_to_char() == '-' &&
    s[self.pos + 1].to_int().unsafe_to_char() == '>' {
    self.pos += 2
    return Some(Some(Token::Comment("")))
  }
  // Find end "-->"
  let start = self.pos
  while self.pos + 2 < s.length() {
    if s[self.pos].to_int().unsafe_to_char() == '-' &&
      s[self.pos + 1].to_int().unsafe_to_char() == '-' &&
      s[self.pos + 2].to_int().unsafe_to_char() == '>' {
      let content = s.unsafe_substring(start~, end=self.pos)
      self.pos += 3
      return Some(Some(Token::Comment(content)))
    }
    self.pos += 1
  }
  // Need more data or finished
  if self.finished {
    let content = s.unsafe_substring(start~, end=s.length())
    self.pos = s.length()
    Some(Some(Token::Comment(content)))
  } else {
    // Reset position and wait for more data
    self.pos = start - 4
    None
  }
}

///|
/// Parse start tag using cached string
fn StreamingTokenizer::parse_start_tag_with_str(
  self : StreamingTokenizer,
  s : String,
) -> Token {
  let tag = self.consume_name_with_str(s).to_lower()
  let attrs : Map[String, String] = {}
  let mut self_closing = false
  while self.pos < s.length() {
    self.skip_whitespace_with_str(s)
    if self.pos >= s.length() {
      break
    }
    let c = s[self.pos].to_int().unsafe_to_char()
    if c == '>' {
      self.pos += 1
      break
    } else if c == '/' {
      self.pos += 1
      self.skip_whitespace_with_str(s)
      if self.pos < s.length() && s[self.pos].to_int().unsafe_to_char() == '>' {
        self.pos += 1
        self_closing = true
      }
      break
    } else if stok_is_name_char(c) {
      let attr_name = self.consume_name_with_str(s)
      self.skip_whitespace_with_str(s)
      let attr_value = if self.pos < s.length() &&
        s[self.pos].to_int().unsafe_to_char() == '=' {
        self.pos += 1
        self.consume_attribute_value_with_str(s)
      } else {
        ""
      }
      attrs.set(attr_name, attr_value)
    } else {
      self.pos += 1
    }
  }
  Token::StartTag(tag, attrs, self_closing)
}

///|
/// Parse end tag using cached string
fn StreamingTokenizer::parse_end_tag_with_str(
  self : StreamingTokenizer,
  s : String,
) -> Token {
  let tag = self.consume_name_with_str(s).to_lower()
  self.skip_whitespace_with_str(s)
  if self.pos < s.length() && s[self.pos].to_int().unsafe_to_char() == '>' {
    self.pos += 1
  }
  Token::EndTag(tag)
}

///|
/// Get the next token, or None if more data is needed
pub fn StreamingTokenizer::next_token(self : StreamingTokenizer) -> Token? {
  // Get cached string once for this token
  let s = self.get_string()
  let slen = s.length()
  if self.pos >= slen {
    return if self.finished { Some(Token::EOF) } else { None }
  }
  let c = s[self.pos].to_int().unsafe_to_char()
  if c == '<' {
    // Check for DOCTYPE
    if self.matches_ci_with_str(s, "<!doctype") {
      match self.try_skip_doctype_with_str(s) {
        Some(Some(t)) => Some(t)
        Some(None) => {
          self.pos += 1
          Some(Token::Character('<'))
        }
        None => None // Need more data
      }
    } else if self.pos + 3 < slen &&
      s[self.pos + 1].to_int().unsafe_to_char() == '!' &&
      s[self.pos + 2].to_int().unsafe_to_char() == '-' &&
      s[self.pos + 3].to_int().unsafe_to_char() == '-' {
      match self.try_skip_comment_with_str(s) {
        Some(Some(t)) => Some(t)
        Some(None) => {
          self.pos += 1
          Some(Token::Character('<'))
        }
        None => None
      }
    } else if self.pos + 1 < slen &&
      s[self.pos + 1].to_int().unsafe_to_char() == '/' {
      // End tag
      if self.pos + 2 >= slen && not(self.finished) {
        return None
      }
      self.pos += 2 // Skip </
      self.skip_whitespace_with_str(s)
      Some(self.parse_end_tag_with_str(s))
    } else if self.pos + 1 < slen {
      let next_c = s[self.pos + 1].to_int().unsafe_to_char()
      if stok_is_ascii_alpha(next_c) {
        // Need to ensure we have the complete tag
        let mut found_end = false
        for i = self.pos; i < slen; i = i + 1 {
          if s[i].to_int().unsafe_to_char() == '>' {
            found_end = true
            break
          }
        }
        if not(found_end) && not(self.finished) {
          return None
        }
        self.pos += 1 // Skip <
        Some(self.parse_start_tag_with_str(s))
      } else {
        self.pos += 1
        Some(Token::Character('<'))
      }
    } else if self.finished {
      self.pos += 1
      Some(Token::Character('<'))
    } else {
      None
    }
  } else {
    // Collect text until < or end
    let start = self.pos
    while self.pos < slen {
      if s[self.pos].to_int().unsafe_to_char() == '<' {
        break
      }
      self.pos += 1
    }
    // If we consumed nothing and need more data
    if self.pos == start && not(self.finished) {
      return None
    }
    let text = s.unsafe_substring(start~, end=self.pos)
    if text.length() == 1 {
      Some(Token::Character(text[0].to_int().unsafe_to_char()))
    } else if text.length() > 0 {
      Some(Token::Characters(text))
    } else {
      None
    }
  }
}

///|
/// Compact the buffer by removing already-processed data
/// Call this periodically to free memory
pub fn StreamingTokenizer::compact(self : StreamingTokenizer) -> Unit {
  if self.pos > 0 {
    let s = self.get_string()
    let remaining = s.unsafe_substring(start=self.pos, end=s.length())
    self.buffer.reset()
    self.buffer.write_string(remaining)
    self.pos = 0
    self.cache_valid = false
  }
}
