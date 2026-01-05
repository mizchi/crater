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
/// Parsed HTML document with extracted resources
pub(all) struct Document {
  root : Element
  stylesheets : Array[String] // CSS content from <style> tags
  stylesheet_links : Array[String] // URLs from <link rel="stylesheet">
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
/// Check if a tag is a void element (no closing tag required)
fn is_void_element(tag : String) -> Bool {
  match tag.to_lower() {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" => true
    _ => false
  }
}

///|
/// Check if a tag is a raw text element (contents treated as text, not HTML)
fn is_raw_text_element(tag : String) -> Bool {
  match tag.to_lower() {
    "script" | "style" | "title" | "textarea" | "xmp" => true
    _ => false
  }
}

///|
/// Check if a tag is plaintext (consumes ALL remaining content as text)
fn is_plaintext_element(tag : String) -> Bool {
  tag.to_lower() == "plaintext"
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
/// Skip DOCTYPE declaration (<!doctype ...> or <!DOCTYPE ...>)
fn Parser::skip_doctype(self : Parser) -> Unit {
  // Check for <!doctype or <!DOCTYPE
  if self.peek() is Some('<') {
    let start_pos = self.pos
    let _ = self.consume() // <
    if self.peek() is Some('!') {
      let _ = self.consume() // !
      // Check for "doctype" (case-insensitive)
      let word = self.peek_word_lowercase()
      if word == "doctype" {
        // Skip until >
        while self.peek() is Some(c) && c != '>' {
          let _ = self.consume()

        }
        if self.peek() is Some('>') {
          let _ = self.consume()
          // >
        }
        return
      }
    }
    // Not a DOCTYPE, reset position
    self.pos = start_pos
  }
}

///|
/// Skip HTML comment <!-- ... -->
fn Parser::skip_comment(self : Parser) -> Bool {
  // Check for <!--
  if self.peek() is Some('<') &&
    self.peek_at(1) is Some('!') &&
    self.peek_at(2) is Some('-') &&
    self.peek_at(3) is Some('-') {
    // Skip <!--
    let _ = self.consume() // <
    let _ = self.consume() // !
    let _ = self.consume() // -
    let _ = self.consume() // -
    // Skip until -->
    while not(self.is_eof()) {
      if self.peek() is Some('-') &&
        self.peek_at(1) is Some('-') &&
        self.peek_at(2) is Some('>') {
        let _ = self.consume() // -
        let _ = self.consume() // -
        let _ = self.consume() // >
        return true
      }
      let _ = self.consume()

    }
    return true
  }
  false
}

///|
/// Peek at the next word (lowercase) without consuming
fn Parser::peek_word_lowercase(self : Parser) -> String {
  let buf = StringBuilder::new()
  let mut i = self.pos
  while i < self.input.length() {
    let code = self.input[i].to_int()
    let c = code.unsafe_to_char()
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      // Convert to lowercase
      if c >= 'A' && c <= 'Z' {
        buf.write_char((code + 32).unsafe_to_char())
      } else {
        buf.write_char(c)
      }
      i = i + 1
    } else {
      break
    }
  }
  buf.to_string()
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
/// Consume ALL remaining content as text (for plaintext element)
fn Parser::consume_all_remaining(self : Parser) -> String {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    match self.consume() {
      Some(c) => buf.write_char(c)
      None => break
    }
  }
  buf.to_string()
}

///|
/// Consume raw text content until the closing tag is found
fn Parser::consume_raw_text(self : Parser, tag : String) -> String {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    // Check for closing tag (case-insensitive)
    if self.peek() is Some('<') && self.peek_at(1) is Some('/') {
      // Check if this is our closing tag
      let _ = self.consume() // <
      let _ = self.consume() // /
      let close_name = self.consume_name()
      self.skip_whitespace()
      if close_name.to_lower() == tag.to_lower() {
        // Found closing tag, consume '>' and return
        if self.peek() is Some('>') {
          let _ = self.consume()

        }
        return buf.to_string()
      }
      // Not our closing tag, add the consumed characters to buffer
      buf.write_string("</")
      buf.write_string(close_name)
      // Don't add the whitespace, continue from current position
      continue
    }
    match self.consume() {
      Some(c) => buf.write_char(c)
      None => break
    }
  }
  buf.to_string()
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

  // Parse tag name (normalize to lowercase for HTML)
  let tag = self.consume_name().to_lower()
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
        return Some({ tag, id, classes, style, attributes, children: [] })
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

  // Void elements have no children and no closing tag
  if is_void_element(tag) {
    return Some({ tag, id, classes, style, attributes, children: [] })
  }

  // Raw text elements: content is treated as text until closing tag
  if is_raw_text_element(tag) {
    let text_content = self.consume_raw_text(tag)
    let children : Array[Node] = if text_content.is_empty() {
      []
    } else {
      [Node::Text(text_content)]
    }
    return Some({ tag, id, classes, style, attributes, children })
  }

  // Plaintext: ALL remaining content is text (including closing tags)
  if is_plaintext_element(tag) {
    let text_content = self.consume_all_remaining()
    let children : Array[Node] = if text_content.is_empty() {
      []
    } else {
      [Node::Text(text_content)]
    }
    return Some({ tag, id, classes, style, attributes, children })
  }

  // Parse children
  let children = self.parse_children(tag)
  Some({ tag, id, classes, style, attributes, children })
}

///|
fn Parser::parse_children(self : Parser, parent_tag : String) -> Array[Node] {
  let children : Array[Node] = []
  while not(self.is_eof()) {
    match self.peek() {
      // Whitespace - collect it and decide what to do
      Some(c) if is_whitespace(c) => {
        let ws_start = self.pos
        self.skip_whitespace()
        // Check what follows the whitespace
        match (self.peek(), self.peek_at(1)) {
          // Opening tag (not closing) - discard whitespace (structural)
          (Some('<'), Some(c)) if c != '/' && c != '!' => ()
          // Closing tag, comment, EOF, or more text - whitespace is content
          _ => {
            // Rewind and parse as text
            self.pos = ws_start
            let text = self.parse_text()
            if not(text.is_empty()) {
              children.push(Node::Text(text))
            }
          }
        }
        continue
      }
      Some('<') =>
        // Check if this is a closing tag
        match self.peek_at(1) {
          Some('/') => {
            // Closing tag - consume it and check
            let _ = self.consume() // <
            let _ = self.consume() // /
            self.skip_whitespace()
            let close_tag = self.consume_name().to_lower()
            self.skip_whitespace()
            match self.peek() {
              Some('>') => {
                let _ = self.consume()

              }
              _ => ()
            }
            // HTML5: </br> is treated as <br>
            if close_tag == "br" {
              let br_elem : Element = {
                tag: "br",
                id: None,
                classes: [],
                style: None,
                attributes: {},
                children: [],
              }
              children.push(Node::Element(br_elem))
              continue
            }
            // HTML5: </p> without matching open creates empty <p>
            if close_tag == "p" && parent_tag != "p" {
              let p_elem : Element = {
                tag: "p",
                id: None,
                classes: [],
                style: None,
                attributes: {},
                children: [],
              }
              children.push(Node::Element(p_elem))
              continue
            }
            // Normal closing tag - return if it matches parent or is structural
            if close_tag == parent_tag ||
              close_tag == "body" ||
              close_tag == "html" ||
              close_tag == "head" {
              return children
            }
            // Unmatched closing tag - ignore and continue
            continue
          }
          Some('!') => {
            // Could be a comment <!-- --> or DOCTYPE (unlikely inside body)
            if self.skip_comment() {
              continue
            }
            // Not a comment, try to parse as element
            match self.parse_element() {
              Some(elem) => children.push(Node::Element(elem))
              None => {
                // Skip this character and continue
                let _ = self.consume()

              }
            }
          }
          _ =>
            // Opening tag - parse child element
            match self.parse_element() {
              Some(elem) =>
                // Skip duplicate structural elements inside body
                // HTML5: if we see <body> inside body, use its children
                if parent_tag == "body" &&
                  (elem.tag == "body" || elem.tag == "html") {
                  // Add children of the duplicate element
                  for child in elem.children {
                    children.push(child)
                  }
                } else {
                  children.push(Node::Element(elem))
                }
              None => {
                // Skip this character and continue
                let _ = self.consume()

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
  buf.to_string()
}

///|
/// Parse HTML string into a document
pub fn parse(html : String) -> Element? {
  let parser = Parser::new(html)
  parser.skip_whitespace()
  // Skip DOCTYPE declaration if present
  parser.skip_doctype()
  parser.skip_whitespace()
  parser.parse_element()
}

///|
/// Parse all top-level elements from HTML
fn parse_all_elements(html : String) -> Array[Element] {
  let parser = Parser::new(html)
  let elements : Array[Element] = []
  while not(parser.is_eof()) {
    parser.skip_whitespace()
    // Skip DOCTYPE declaration if present
    parser.skip_doctype()
    parser.skip_whitespace()
    if parser.is_eof() {
      break
    }
    // Check for closing tag at top level
    if parser.peek() is Some('<') && parser.peek_at(1) is Some('/') {
      let _ = parser.consume() // <
      let _ = parser.consume() // /
      parser.skip_whitespace()
      let close_tag = parser.consume_name().to_lower()
      parser.skip_whitespace()
      if parser.peek() is Some('>') {
        let _ = parser.consume()

      }
      // HTML5: </br> is treated as <br>
      if close_tag == "br" {
        elements.push({
          tag: "br",
          id: None,
          classes: [],
          style: None,
          attributes: {},
          children: [],
        })
      } else if close_tag == "p" {
        // HTML5: </p> without matching open creates empty <p>
        elements.push({
          tag: "p",
          id: None,
          classes: [],
          style: None,
          attributes: {},
          children: [],
        })
      }
      // Other closing tags are ignored at top level
      continue
    }
    match parser.parse_element() {
      Some(elem) => elements.push(elem)
      None =>
        // Skip any non-element content
        match parser.consume() {
          Some(_) => ()
          None => break
        }
    }
  }
  elements
}

///|
/// Check if element should be in head
fn is_head_element(tag : String) -> Bool {
  match tag.to_lower() {
    "title" | "meta" | "link" | "style" | "base" | "script" | "noscript" => true
    _ => false
  }
}

///|
/// Parse HTML with a wrapper div if needed
pub fn parse_fragment(html : String) -> Element {
  let elements = parse_all_elements(html)
  if elements.is_empty() {
    return {
      tag: "body",
      id: None,
      classes: [],
      style: None,
      attributes: {},
      children: [],
    }
  }

  // If first element is html, return it
  if elements.length() == 1 && elements[0].tag.to_lower() == "html" {
    return elements[0]
  }

  // If first element is body, return it
  if elements.length() == 1 && elements[0].tag.to_lower() == "body" {
    return elements[0]
  }

  // Otherwise, separate head and body elements and create implicit structure
  let head_children : Array[Node] = []
  let body_children : Array[Node] = []
  for elem in elements {
    if is_head_element(elem.tag) {
      head_children.push(Node::Element(elem))
    } else if elem.tag.to_lower() == "body" {
      // If we have an explicit <body> element, use its children directly
      for child in elem.children {
        body_children.push(child)
      }
    } else {
      body_children.push(Node::Element(elem))
    }
  }

  // If we have both head and body elements, create proper html structure
  if head_children.length() > 0 && body_children.length() > 0 {
    let head_elem : Element = {
      tag: "head",
      id: None,
      classes: [],
      style: None,
      attributes: {},
      children: head_children,
    }
    let body_elem : Element = {
      tag: "body",
      id: None,
      classes: [],
      style: None,
      attributes: {},
      children: body_children,
    }
    return {
      tag: "html",
      id: None,
      classes: [],
      style: None,
      attributes: {},
      children: [Node::Element(head_elem), Node::Element(body_elem)],
    }
  }

  // If we have only body elements, return a body wrapper
  if body_children.length() > 0 {
    return {
      tag: "body",
      id: None,
      classes: [],
      style: None,
      attributes: {},
      children: body_children,
    }
  }

  // Only head elements - still wrap in body (unusual case)
  {
    tag: "body",
    id: None,
    classes: [],
    style: None,
    attributes: {},
    children: head_children,
  }
}

///|
/// Parse HTML and extract stylesheets
pub fn parse_document(html : String) -> Document {
  let root = parse_fragment(html)
  let stylesheets : Array[String] = []
  let stylesheet_links : Array[String] = []
  extract_stylesheets(root, stylesheets, stylesheet_links)
  { root, stylesheets, stylesheet_links }
}

///|
/// Recursively extract stylesheets from element tree
fn extract_stylesheets(
  elem : Element,
  stylesheets : Array[String],
  links : Array[String],
) -> Unit {
  // Handle <style> tags - extract text content
  if elem.tag == "style" {
    let css = extract_text_content(elem)
    if not(css.is_empty()) {
      stylesheets.push(css)
    }
  }
  // Handle <link rel="stylesheet"> tags
  if elem.tag == "link" {
    let rel = elem.attributes.get("rel")
    match rel {
      Some(r) if r == "stylesheet" =>
        match elem.attributes.get("href") {
          Some(href) => links.push(href)
          None => ()
        }
      _ => ()
    }
  }
  // Recurse into children
  for child in elem.children {
    match child {
      Node::Element(child_elem) =>
        extract_stylesheets(child_elem, stylesheets, links)
      Node::Text(_) => ()
    }
  }
}

///|
/// Extract all text content from an element
fn extract_text_content(elem : Element) -> String {
  let buf = StringBuilder::new()
  for child in elem.children {
    match child {
      Node::Text(text) => buf.write_string(text)
      Node::Element(child_elem) =>
        buf.write_string(extract_text_content(child_elem))
    }
  }
  buf.to_string()
}
