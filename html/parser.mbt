///|
/// Simple HTML Parser
/// Parses a subset of HTML for layout testing

///|
/// HTML Element node
pub(all) struct Element {
  tag : String
  id : String?
  classes : Array[String]
  style : String? // inline style attribute
  attributes : Map[String, String]
  children : Array[Node]
}

///|
/// HTML Node (Element or Text)
pub(all) enum Node {
  Element(Element)
  Text(String)
}

///|
/// Parser state
priv struct Parser {
  input : String
  mut pos : Int
  len : Int
}

///|
fn Parser::new(input : String) -> Parser {
  { input, pos: 0, len: input.length() }
}

///|
fn Parser::is_eof(self : Parser) -> Bool {
  self.pos >= self.len
}

///|
fn Parser::peek(self : Parser) -> Char? {
  if self.is_eof() {
    None
  } else {
    Some(self.input[self.pos].to_int().unsafe_to_char())
  }
}

///|
fn Parser::peek_at(self : Parser, offset : Int) -> Char? {
  let idx = self.pos + offset
  if idx >= self.len || idx < 0 {
    None
  } else {
    Some(self.input[idx].to_int().unsafe_to_char())
  }
}

///|
fn Parser::consume(self : Parser) -> Char? {
  if self.is_eof() {
    None
  } else {
    let c = self.input[self.pos].to_int().unsafe_to_char()
    self.pos += 1
    Some(c)
  }
}

///|
fn Parser::skip_whitespace(self : Parser) -> Unit {
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
fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn is_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_'
}

///|
fn Parser::consume_name(self : Parser) -> String {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    match self.peek() {
      Some(c) if is_name_char(c) => {
        buf.write_char(c)
        let _ = self.consume()
      }
      _ => break
    }
  }
  buf.to_string()
}

///|
fn Parser::consume_until(self : Parser, end_char : Char) -> String {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    match self.peek() {
      Some(c) if c == end_char => break
      Some(c) => {
        buf.write_char(c)
        let _ = self.consume()
      }
      None => break
    }
  }
  buf.to_string()
}

///|
fn Parser::consume_quoted_string(self : Parser) -> String {
  match self.peek() {
    Some('"') => {
      let _ = self.consume() // opening quote
      let s = self.consume_until('"')
      let _ = self.consume() // closing quote
      s
    }
    Some('\'') => {
      let _ = self.consume() // opening quote
      let s = self.consume_until('\'')
      let _ = self.consume() // closing quote
      s
    }
    _ => self.consume_name()
  }
}

///|
fn Parser::parse_element(self : Parser) -> Element? {
  self.skip_whitespace()

  // Expect '<'
  match self.peek() {
    Some('<') => {
      let _ = self.consume()
    }
    _ => return None
  }

  self.skip_whitespace()

  // Check for closing tag
  match self.peek() {
    Some('/') => return None // This is a closing tag
    _ => ()
  }

  // Parse tag name
  let tag = self.consume_name()
  if tag.is_empty() {
    return None
  }

  // Parse attributes
  let mut id : String? = None
  let classes : Array[String] = []
  let mut style : String? = None
  let attributes : Map[String, String] = {}

  while true {
    self.skip_whitespace()
    match self.peek() {
      Some('>') => {
        let _ = self.consume()
        break
      }
      Some('/') => {
        // Self-closing tag
        let _ = self.consume()
        self.skip_whitespace()
        match self.peek() {
          Some('>') => {
            let _ = self.consume()
          }
          _ => ()
        }
        return Some(
          { tag, id, classes, style, attributes, children: [] },
        )
      }
      Some(_) => {
        let attr_name = self.consume_name()
        if attr_name.is_empty() {
          break
        }
        self.skip_whitespace()
        // Check for '='
        let attr_value = match self.peek() {
          Some('=') => {
            let _ = self.consume()
            self.skip_whitespace()
            self.consume_quoted_string()
          }
          _ => ""
        }
        // Handle special attributes
        if attr_name == "id" {
          id = Some(attr_value)
        } else if attr_name == "class" {
          // Split by whitespace
          let class_parts = attr_value.split(" ")
          for part in class_parts {
            let s = part.to_string().trim()
            if not(s.is_empty()) {
              classes.push(s.to_string())
            }
          }
        } else if attr_name == "style" {
          style = Some(attr_value)
        } else {
          attributes.set(attr_name, attr_value)
        }
      }
      None => break
    }
  }

  // Parse children
  let children = self.parse_children(tag)

  Some({ tag, id, classes, style, attributes, children })
}

///|
fn Parser::parse_children(self : Parser, parent_tag : String) -> Array[Node] {
  let children : Array[Node] = []

  while not(self.is_eof()) {
    self.skip_whitespace()

    match self.peek() {
      Some('<') => {
        // Check if this is a closing tag
        match self.peek_at(1) {
          Some('/') => {
            // Closing tag - consume it and return
            let _ = self.consume() // <
            let _ = self.consume() // /
            self.skip_whitespace()
            let close_tag = self.consume_name()
            self.skip_whitespace()
            match self.peek() {
              Some('>') => {
                let _ = self.consume()
              }
              _ => ()
            }
            // Verify tag matches (ignore for simplicity)
            let _ = close_tag
            let _ = parent_tag
            return children
          }
          _ => {
            // Opening tag - parse child element
            match self.parse_element() {
              Some(elem) => children.push(Node::Element(elem))
              None => break
            }
          }
        }
      }
      Some(_) => {
        // Text content
        let text = self.parse_text()
        if not(text.is_empty()) {
          children.push(Node::Text(text))
        }
      }
      None => break
    }
  }

  children
}

///|
fn Parser::parse_text(self : Parser) -> String {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    match self.peek() {
      Some('<') => break
      Some(c) => {
        buf.write_char(c)
        let _ = self.consume()
      }
      None => break
    }
  }
  buf.to_string().trim().to_string()
}

///|
/// Parse HTML string into a document
pub fn parse(html : String) -> Element? {
  let parser = Parser::new(html)
  parser.skip_whitespace()
  parser.parse_element()
}

///|
/// Parse HTML with a wrapper div if needed
pub fn parse_fragment(html : String) -> Element {
  match parse(html) {
    Some(elem) => elem
    None => {
      // Wrap in a div
      { tag: "div", id: None, classes: [], style: None, attributes: {}, children: [] }
    }
  }
}
