///|
/// Streaming HTML5 Tree Builder
/// Builds DOM tree incrementally from HTML chunks

///|
/// Streaming tree builder that processes HTML incrementally
pub(all) struct StreamingTreeBuilder {
  tokenizer : StreamingTokenizer
  mut insertion_mode : InsertionMode
  mut original_insertion_mode : InsertionMode?
  open_elements : Array[Element]
  active_formatting : Array[FormattingElement]
  mut foster_parenting : Bool
  mut frameset_ok : Bool
  mut head_element : Element?
  mut pending_table_chars : Array[Char]
  pending_text : StringBuilder
  pending_tokens : Array[Token]
  // Root element
  mut root : Element?
}

///|
pub fn StreamingTreeBuilder::new() -> StreamingTreeBuilder {
  {
    tokenizer: StreamingTokenizer::new(),
    insertion_mode: InsertionMode::Initial,
    original_insertion_mode: None,
    open_elements: [],
    active_formatting: [],
    foster_parenting: false,
    frameset_ok: true,
    head_element: None,
    pending_table_chars: [],
    pending_text: StringBuilder::new(),
    pending_tokens: [],
    root: None,
  }
}

///|
/// Feed a chunk of HTML
pub fn StreamingTreeBuilder::feed(
  self : StreamingTreeBuilder,
  chunk : String,
) -> Unit {
  self.tokenizer.feed(chunk)
  self.process_available_tokens()
  // Compact tokenizer buffer periodically to free memory
  self.tokenizer.compact()
}

///|
/// Signal end of input and get the result
pub fn StreamingTreeBuilder::finish(self : StreamingTreeBuilder) -> Element {
  self.tokenizer.finish()
  self.process_available_tokens()
  self.flush_pending_text()
  match self.root {
    Some(elem) => elem
    None => {
      let html = stb_create_element("html", {})
      let body = stb_create_element("body", {})
      html.children.push(Node::Element(body))
      html
    }
  }
}

///|
/// Process all available tokens from the tokenizer
fn StreamingTreeBuilder::process_available_tokens(
  self : StreamingTreeBuilder,
) -> Unit {
  while true {
    match self.tokenizer.next_token() {
      Some(Token::EOF) => break
      Some(token) => {
        self.process_token_single(token)
        // Process requeued tokens
        while not(self.pending_tokens.is_empty()) {
          let next = self.pending_tokens.remove(0)
          self.process_token_single(next)
        }
      }
      None => break // Need more data
    }
  }
}

///|
fn stb_create_element(tag : String, attrs : Map[String, String]) -> Element {
  let id = attrs.get("id")
  let classes = match attrs.get("class") {
    Some(class_str) => {
      let parts : Array[String] = []
      for part in class_str.split(" ") {
        let s = part.to_string().trim()
        if not(s.is_empty()) {
          parts.push(s.to_string())
        }
      }
      parts
    }
    None => []
  }
  let style = attrs.get("style")
  { tag, id, classes, style, attributes: attrs, children: [] }
}

///|
fn StreamingTreeBuilder::current_node(self : StreamingTreeBuilder) -> Element? {
  if self.open_elements.is_empty() {
    None
  } else {
    Some(self.open_elements[self.open_elements.length() - 1])
  }
}

///|
fn StreamingTreeBuilder::reprocess_token(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  self.pending_tokens.push(token)
}

///|
fn StreamingTreeBuilder::insert_element(
  self : StreamingTreeBuilder,
  element : Element,
) -> Unit {
  self.flush_pending_text()
  match self.current_node() {
    Some(current) => current.children.push(Node::Element(element))
    None => ()
  }
  self.open_elements.push(element)
}

///|
fn StreamingTreeBuilder::insert_character(
  self : StreamingTreeBuilder,
  c : Char,
) -> Unit {
  self.pending_text.write_char(c)
}

///|
fn StreamingTreeBuilder::insert_characters(
  self : StreamingTreeBuilder,
  s : String,
) -> Unit {
  self.pending_text.write_string(s)
}

///|
fn StreamingTreeBuilder::flush_pending_text(
  self : StreamingTreeBuilder,
) -> Unit {
  if self.pending_text.is_empty() {
    return
  }
  let raw_text = self.pending_text.to_string()
  self.pending_text.reset()
  let text = decode_html_entities(raw_text)
  match self.current_node() {
    Some(current) => {
      let len = current.children.length()
      if len > 0 {
        match current.children[len - 1] {
          Node::Text(existing) => {
            current.children[len - 1] = Node::Text(existing + text)
            return
          }
          _ => ()
        }
      }
      if stb_is_whitespace_only(text) {
        return
      }
      current.children.push(Node::Text(text))
    }
    None => ()
  }
}

///|
fn stb_is_whitespace_only(s : String) -> Bool {
  for c in s {
    if not(stb_is_whitespace(c)) {
      return false
    }
  }
  true
}

///|
fn stb_is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn StreamingTreeBuilder::pop_until(
  self : StreamingTreeBuilder,
  tag : String,
) -> Unit {
  self.flush_pending_text()
  while not(self.open_elements.is_empty()) {
    let elem = self.open_elements.pop()
    match elem {
      Some(e) if e.tag == tag => break
      _ => ()
    }
  }
}

///|
fn StreamingTreeBuilder::has_element_in_scope(
  self : StreamingTreeBuilder,
  tag : String,
) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    if elem.tag == tag {
      return true
    }
    if stb_is_scope_boundary(elem.tag) {
      return false
    }
  }
  false
}

///|
fn stb_is_scope_boundary(tag : String) -> Bool {
  match tag {
    "applet"
    | "caption"
    | "html"
    | "table"
    | "td"
    | "th"
    | "marquee"
    | "object"
    | "template" => true
    _ => false
  }
}

///|
fn StreamingTreeBuilder::generate_implied_end_tags(
  self : StreamingTreeBuilder,
) -> Unit {
  while not(self.open_elements.is_empty()) {
    match self.current_node() {
      Some(e) =>
        match e.tag {
          "dd"
          | "dt"
          | "li"
          | "optgroup"
          | "option"
          | "p"
          | "rb"
          | "rp"
          | "rt"
          | "rtc" => {
            let _ = self.open_elements.pop()

          }
          _ => break
        }
      None => break
    }
  }
}

///|
fn StreamingTreeBuilder::generate_implied_end_tags_except(
  self : StreamingTreeBuilder,
  except : String,
) -> Unit {
  while not(self.open_elements.is_empty()) {
    match self.current_node() {
      Some(e) if e.tag == except => break
      Some(e) =>
        match e.tag {
          "dd"
          | "dt"
          | "li"
          | "optgroup"
          | "option"
          | "p"
          | "rb"
          | "rp"
          | "rt"
          | "rtc" => {
            let _ = self.open_elements.pop()

          }
          _ => break
        }
      None => break
    }
  }
}

///|
fn stb_is_void_element(tag : String) -> Bool {
  match tag {
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
/// Process a single token
fn StreamingTreeBuilder::process_token_single(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match self.insertion_mode {
    InsertionMode::Initial => self.stb_handle_initial(token)
    InsertionMode::BeforeHtml => self.stb_handle_before_html(token)
    InsertionMode::BeforeHead => self.stb_handle_before_head(token)
    InsertionMode::InHead => self.stb_handle_in_head(token)
    InsertionMode::AfterHead => self.stb_handle_after_head(token)
    InsertionMode::InBody => self.stb_handle_in_body(token)
    InsertionMode::Text => self.stb_handle_text(token)
    InsertionMode::AfterBody => self.stb_handle_after_body(token)
    _ => self.stb_handle_in_body(token)
  }
}

///|
fn StreamingTreeBuilder::stb_handle_initial(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Doctype(_) => self.insertion_mode = InsertionMode::BeforeHtml
    Token::Character(c) if stb_is_whitespace(c) => ()
    Token::Characters(s) if stb_is_whitespace_only(s) => ()
    _ => {
      self.insertion_mode = InsertionMode::BeforeHtml
      self.reprocess_token(token)
    }
  }
}

///|
fn StreamingTreeBuilder::stb_handle_before_html(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Doctype(_) => ()
    Token::Character(c) if stb_is_whitespace(c) => ()
    Token::Characters(s) if stb_is_whitespace_only(s) => ()
    Token::StartTag(tag, attrs, _) if tag == "html" => {
      let elem = stb_create_element(tag, attrs)
      self.open_elements.push(elem)
      self.root = Some(elem)
      self.insertion_mode = InsertionMode::BeforeHead
    }
    _ => {
      let elem = stb_create_element("html", {})
      self.open_elements.push(elem)
      self.root = Some(elem)
      self.insertion_mode = InsertionMode::BeforeHead
      self.reprocess_token(token)
    }
  }
}

///|
fn StreamingTreeBuilder::stb_handle_before_head(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Character(c) if stb_is_whitespace(c) => ()
    Token::Characters(s) if stb_is_whitespace_only(s) => ()
    Token::StartTag(tag, attrs, _) if tag == "head" => {
      let elem = stb_create_element(tag, attrs)
      self.insert_element(elem)
      self.head_element = Some(elem)
      self.insertion_mode = InsertionMode::InHead
    }
    _ => {
      let elem = stb_create_element("head", {})
      self.insert_element(elem)
      self.head_element = Some(elem)
      self.insertion_mode = InsertionMode::InHead
      self.reprocess_token(token)
    }
  }
}

///|
fn StreamingTreeBuilder::stb_handle_in_head(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Character(c) if stb_is_whitespace(c) => self.insert_character(c)
    Token::Characters(s) if stb_is_whitespace_only(s) =>
      self.insert_characters(s)
    Token::StartTag(tag, attrs, _) =>
      match tag {
        "title" | "style" | "script" => {
          let elem = stb_create_element(tag, attrs)
          self.insert_element(elem)
          self.original_insertion_mode = Some(self.insertion_mode)
          self.insertion_mode = InsertionMode::Text
        }
        "base" | "basefont" | "bgsound" | "link" | "meta" => {
          let elem = stb_create_element(tag, attrs)
          self.insert_element(elem)
          let _ = self.open_elements.pop()

        }
        "head" => ()
        _ => {
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::AfterHead
          self.reprocess_token(token)
        }
      }
    Token::EndTag(tag) =>
      match tag {
        "head" => {
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::AfterHead
        }
        _ => ()
      }
    _ => {
      let _ = self.open_elements.pop()
      self.insertion_mode = InsertionMode::AfterHead
      self.reprocess_token(token)
    }
  }
}

///|
fn StreamingTreeBuilder::stb_handle_after_head(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Character(c) if stb_is_whitespace(c) => self.insert_character(c)
    Token::Characters(s) if stb_is_whitespace_only(s) =>
      self.insert_characters(s)
    Token::StartTag(tag, attrs, _) if tag == "body" => {
      let elem = stb_create_element(tag, attrs)
      self.insert_element(elem)
      self.insertion_mode = InsertionMode::InBody
    }
    _ => {
      let elem = stb_create_element("body", {})
      self.insert_element(elem)
      self.insertion_mode = InsertionMode::InBody
      self.reprocess_token(token)
    }
  }
}

///|
fn StreamingTreeBuilder::stb_handle_in_body(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Character(c) => self.insert_character(c)
    Token::Characters(s) => self.insert_characters(s)
    Token::Comment(_) => ()
    Token::Doctype(_) => ()
    Token::StartTag(tag, attrs, self_closing) =>
      // Simplified: just create elements
      if stb_is_void_element(tag) || self_closing {
        let elem = stb_create_element(tag, attrs)
        self.insert_element(elem)
        let _ = self.open_elements.pop()

      } else {
        let elem = stb_create_element(tag, attrs)
        self.insert_element(elem)
      }
    Token::EndTag(tag) => {
      self.flush_pending_text()
      match tag {
        // Special handling for p element (uses generate_implied_end_tags_except)
        "p" =>
          if self.has_element_in_scope("p") {
            self.generate_implied_end_tags_except("p")
            self.pop_until("p")
          }
        // Tags that need generate_implied_end_tags_except
        "li" =>
          if self.has_element_in_scope("li") {
            self.generate_implied_end_tags_except("li")
            self.pop_until("li")
          }
        "dd" | "dt" =>
          if self.has_element_in_scope(tag) {
            self.generate_implied_end_tags_except(tag)
            self.pop_until(tag)
          }
        // Body end tag changes mode
        "body" =>
          if self.has_element_in_scope("body") {
            self.insertion_mode = InsertionMode::AfterBody
          }
        // All other end tags
        _ =>
          if self.has_element_in_scope(tag) {
            self.generate_implied_end_tags()
            self.pop_until(tag)
          }
      }
    }
    Token::EOF => ()
  }
}

///|
fn StreamingTreeBuilder::stb_handle_text(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Character(c) => self.insert_character(c)
    Token::Characters(s) => self.insert_characters(s)
    Token::EOF | Token::EndTag(_) => {
      self.flush_pending_text()
      let _ = self.open_elements.pop()
      match self.original_insertion_mode {
        Some(mode) => self.insertion_mode = mode
        None => self.insertion_mode = InsertionMode::InBody
      }
    }
    _ => ()
  }
}

///|
fn StreamingTreeBuilder::stb_handle_after_body(
  self : StreamingTreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Character(c) if stb_is_whitespace(c) =>
      self.stb_handle_in_body(Token::Character(c))
    Token::Characters(s) if stb_is_whitespace_only(s) =>
      self.stb_handle_in_body(Token::Characters(s))
    Token::EndTag(tag) if tag == "html" =>
      self.insertion_mode = InsertionMode::AfterAfterBody
    Token::EOF => ()
    _ => {
      self.insertion_mode = InsertionMode::InBody
      self.reprocess_token(token)
    }
  }
}

///|
/// Parse HTML document using streaming
pub fn parse_document_streaming(html : String, chunk_size : Int) -> Document {
  let builder = StreamingTreeBuilder::new()
  let len = html.length()
  let mut offset = 0
  while offset < len {
    let end = if offset + chunk_size > len { len } else { offset + chunk_size }
    let chunk = html.unsafe_substring(start=offset, end~)
    builder.feed(chunk)
    offset = end
  }
  let root = builder.finish()
  { root, stylesheets: [], stylesheet_links: [] }
}
