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
/// Check if parent element is an inline context where whitespace is significant
/// This includes phrasing content containers and interactive elements
fn is_inline_context(tag : String) -> Bool {
  match tag.to_lower() {
    // Interactive elements
    "button"
    | "a"
    | "label"
    | "summary"
    // Heading elements
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    // Phrasing content containers
    | "p"
    | "span"
    | "strong"
    | "em"
    | "b"
    | "i"
    | "u"
    | "s"
    | "small"
    | "mark"
    | "abbr"
    | "cite"
    | "code"
    | "q"
    | "sub"
    | "sup"
    | "time"
    | "var"
    | "samp"
    | "kbd"
    // List items (often contain inline content)
    | "li"
    | "dt"
    | "dd"
    // Table cells
    | "td"
    | "th"
    | "caption"
    // Form elements
    | "legend"
    | "option"
    | "optgroup"
    // Other inline contexts
    | "figcaption"
    | "title"
    | "dfn"
    | "bdo"
    | "bdi" => true
    _ => false
  }
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
      decode_html_entities(s)
    }
    Some('\'') => {
      let _ = self.consume() // opening quote
      let s = self.consume_until('\'')
      let _ = self.consume() // closing quote
      decode_html_entities(s)
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
  // Preserve whitespace in inline contexts (phrasing content)
  let preserve_ws = is_inline_context(parent_tag)
  while not(self.is_eof()) {
    match self.peek() {
      // Whitespace - collect it and decide what to do
      Some(c) if is_whitespace(c) => {
        let ws_start = self.pos
        self.skip_whitespace()
        // Check what follows the whitespace
        match (self.peek(), self.peek_at(1)) {
          // Opening tag (not closing) - discard or preserve based on context
          (Some('<'), Some(c)) if c != '/' && c != '!' =>
            // In inline contexts, preserve whitespace between elements
            if preserve_ws && children.length() > 0 {
              children.push(Node::Text(" "))
            }
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
/// Decode HTML entities in text
fn decode_html_entities(text : String) -> String {
  if not(text.contains("&")) {
    return text
  }
  let buf = StringBuilder::new()
  let chars = text.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if chars[i] == '&' {
      // Try to find entity end
      let mut j = i + 1
      while j < len &&
            j - i < 12 &&
            chars[j] != ';' &&
            chars[j] != '&' &&
            chars[j] != '<' {
        j = j + 1
      }
      if j < len && chars[j] == ';' {
        // Extract entity name - use String::from_array to convert char slice to string
        let entity = String::from_array(chars[i + 1:j])
        match decode_entity(entity) {
          Some(decoded) => {
            buf.write_string(decoded)
            i = j + 1
            continue
          }
          None => ()
        }
      }
    }
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
/// Decode a single HTML entity (without & and ;)
fn decode_entity(entity : String) -> String? {
  // Numeric entities
  if entity.has_prefix("#x") || entity.has_prefix("#X") {
    // Hex numeric entity
    let hex = entity[2:].to_string() catch { _ => return None }
    match parse_hex(hex) {
      Some(code) => return Some(code.unsafe_to_char().to_string())
      None => return None
    }
  }
  if entity.has_prefix("#") {
    // Decimal numeric entity
    let num = entity[1:].to_string() catch { _ => return None }
    match parse_decimal(num) {
      Some(code) => return Some(code.unsafe_to_char().to_string())
      None => return None
    }
  }
  // Named entities (common ones)
  match entity {
    "nbsp" => Some("\u00A0")
    "amp" => Some("&")
    "lt" => Some("<")
    "gt" => Some(">")
    "quot" => Some("\"")
    "apos" => Some("'")
    "copy" => Some("\u00A9")
    "reg" => Some("\u00AE")
    "trade" => Some("\u2122")
    "mdash" => Some("\u2014")
    "ndash" => Some("\u2013")
    "lsquo" => Some("\u2018")
    "rsquo" => Some("\u2019")
    "ldquo" => Some("\u201C")
    "rdquo" => Some("\u201D")
    "hellip" => Some("\u2026")
    "bull" => Some("\u2022")
    "middot" => Some("\u00B7")
    "cent" => Some("\u00A2")
    "pound" => Some("\u00A3")
    "euro" => Some("\u20AC")
    "yen" => Some("\u00A5")
    "deg" => Some("\u00B0")
    "plusmn" => Some("\u00B1")
    "times" => Some("\u00D7")
    "divide" => Some("\u00F7")
    "frac12" => Some("\u00BD")
    "frac14" => Some("\u00BC")
    "frac34" => Some("\u00BE")
    _ => None
  }
}

///|
/// Parse hex string to int
fn parse_hex(s : String) -> Int? {
  let chars = s.to_array()
  let mut result = 0
  for c in chars {
    let digit = match c {
      '0'..='9' => c.to_int() - '0'.to_int()
      'a'..='f' => c.to_int() - 'a'.to_int() + 10
      'A'..='F' => c.to_int() - 'A'.to_int() + 10
      _ => return None
    }
    result = result * 16 + digit
  }
  Some(result)
}

///|
/// Parse decimal string to int
fn parse_decimal(s : String) -> Int? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut result = 0
  for c in chars {
    match c {
      '0'..='9' => result = result * 10 + (c.to_int() - '0'.to_int())
      _ => return None
    }
  }
  Some(result)
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
  decode_html_entities(buf.to_string())
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
/// Parse full HTML document using document parsing mode
pub fn parse_document_v2(html : String) -> Element {
  let tokenizer = Tokenizer::new(html)
  let builder = TreeBuilder::new(tokenizer)
  builder.build_document()
}

///|
/// Parse HTML and extract stylesheets
pub fn parse_document(html : String) -> Document {
  let root = parse_document_v2(html)
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

///|
/// Find substring position in string, starting from a given offset
/// Returns -1 if not found
fn find_substring(s : String, needle : String, from : Int) -> Int {
  let slen = s.length()
  let nlen = needle.length()
  if nlen == 0 || from + nlen > slen {
    return -1
  }
  for i = from; i <= slen - nlen; i = i + 1 {
    let mut matched = true
    for j = 0; j < nlen; j = j + 1 {
      if s[i + j].to_int() != needle[j].to_int() {
        matched = false
        break
      }
    }
    if matched {
      return i
    }
  }
  -1
}

///|
/// Find single character position in string
fn find_char(s : String, c : Char, from : Int) -> Int {
  let slen = s.length()
  for i = from; i < slen; i = i + 1 {
    if s[i].to_int().unsafe_to_char() == c {
      return i
    }
  }
  -1
}

///|
/// Extract stylesheet links from HTML without full DOM parsing
/// This is a lightweight alternative to parse_document for just getting CSS links
pub fn extract_stylesheet_links(html : String) -> Array[String] {
  let links : Array[String] = []
  let len = html.length()
  let mut pos = 0
  while pos < len {
    // Find <link (case insensitive - check both)
    let link_pos_lower = find_substring(html, "<link", pos)
    let link_pos_upper = find_substring(html, "<LINK", pos)
    let link_pos = if link_pos_lower < 0 {
      link_pos_upper
    } else if link_pos_upper < 0 {
      link_pos_lower
    } else if link_pos_lower < link_pos_upper {
      link_pos_lower
    } else {
      link_pos_upper
    }
    if link_pos < 0 {
      break
    }
    // Find the closing >
    let tag_end = find_char(html, '>', link_pos)
    if tag_end < 0 {
      break
    }
    // Extract the tag content
    let tag_content = html.unsafe_substring(start=link_pos, end=tag_end + 1)
    // Check if it has rel="stylesheet"
    if tag_content.contains("stylesheet") {
      // Extract href value
      match extract_href_from_tag(tag_content) {
        Some(href) => links.push(href)
        None => ()
      }
    }
    pos = tag_end + 1
  }
  links
}

///|
/// Extract href value from a tag string
fn extract_href_from_tag(tag : String) -> String? {
  // Look for href="..." or href='...'
  let href_pos = find_substring(tag, "href=", 0)
  if href_pos < 0 {
    return None
  }
  let after_href = href_pos + 5
  if after_href >= tag.length() {
    return None
  }
  let quote_char = tag[after_href].to_int().unsafe_to_char()
  if quote_char != '"' && quote_char != '\'' {
    // Unquoted href - find next whitespace or >
    let start = after_href
    let mut end = start
    while end < tag.length() {
      let c = tag[end].to_int().unsafe_to_char()
      if c == ' ' || c == '\t' || c == '>' || c == '/' {
        break
      }
      end += 1
    }
    if end > start {
      return Some(tag.unsafe_substring(start~, end~))
    }
    return None
  }
  // Quoted href
  let start = after_href + 1
  let end_quote = find_char(tag, quote_char, start)
  if end_quote < 0 {
    return None
  }
  Some(tag.unsafe_substring(start~, end=end_quote))
}

///|
/// Parse HTML fragment using TreeBuilder (HTML5 compliant)
pub fn parse_fragment_v2(html : String) -> Element {
  let tokenizer = Tokenizer::new(html)
  let builder = TreeBuilder::new(tokenizer)
  builder.build()
}

///|
/// Parse HTML with a wrapper div if needed
pub fn parse_fragment(html : String) -> Element {
  parse_fragment_v2(html)
}

///|
/// Context for assigning synthetic IDs
priv struct IdAssigner {
  mut counter : Int
}

///|
fn IdAssigner::new() -> IdAssigner {
  { counter: 0 }
}

///|
fn IdAssigner::next_id(self : IdAssigner) -> String {
  let id = "crater-e\{self.counter}"
  self.counter += 1
  id
}

///|
/// Assign synthetic IDs to elements without explicit IDs
/// Returns a new element tree with IDs assigned
fn assign_ids_element(elem : Element, assigner : IdAssigner) -> Element {
  // Assign ID if not present
  let new_id : String? = match elem.id {
    Some(id) => Some(id)
    None => Some(assigner.next_id())
  }
  // Process children recursively
  let new_children : Array[Node] = []
  for child in elem.children {
    match child {
      Node::Element(child_elem) => {
        let new_child = assign_ids_element(child_elem, assigner)
        new_children.push(Node::Element(new_child))
      }
      Node::Text(text) => new_children.push(Node::Text(text))
    }
  }
  { ..elem, id: new_id, children: new_children }
}

///|
/// Assign synthetic IDs to all elements in a document
/// This ensures every element has a unique ID for layout/AOM integration
pub fn assign_synthetic_ids(doc : Document) -> Document {
  let assigner = IdAssigner::new()
  let new_root = assign_ids_element(doc.root, assigner)
  { ..doc, root: new_root }
}
