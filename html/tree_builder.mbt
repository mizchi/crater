///|
/// HTML5 Tree Construction Algorithm
/// Based on WHATWG HTML5 Parsing Specification

///|
/// Insertion mode for tree construction
pub(all) enum InsertionMode {
  Initial
  BeforeHtml
  BeforeHead
  InHead
  InHeadNoscript
  AfterHead
  InBody
  Text
  InTable
  InTableText
  InCaption
  InColumnGroup
  InTableBody
  InRow
  InCell
  InSelect
  InSelectInTable
  AfterBody
  InFrameset
  AfterFrameset
  AfterAfterBody
  AfterAfterFrameset
}

///|
/// Formatting element marker or element
pub(all) enum FormattingElement {
  Element(Element)
  Marker
}

///|
/// Tree Builder state machine
pub(all) struct TreeBuilder {
  tokenizer : Tokenizer
  mut insertion_mode : InsertionMode
  mut original_insertion_mode : InsertionMode?
  open_elements : Array[Element]
  active_formatting : Array[FormattingElement]
  mut foster_parenting : Bool
  mut frameset_ok : Bool
  mut head_element : Element?
  mut pending_table_chars : Array[Char]
}

///|
pub fn TreeBuilder::new(tokenizer : Tokenizer) -> TreeBuilder {
  {
    tokenizer,
    insertion_mode: InsertionMode::Initial,
    original_insertion_mode: None,
    open_elements: [],
    active_formatting: [],
    foster_parenting: false,
    frameset_ok: true,
    head_element: None,
    pending_table_chars: [],
  }
}

///|
/// Get current element (top of stack)
fn TreeBuilder::current_node(self : TreeBuilder) -> Element? {
  if self.open_elements.is_empty() {
    None
  } else {
    Some(self.open_elements[self.open_elements.length() - 1])
  }
}

///|
/// Check if tag is in scope
fn TreeBuilder::has_element_in_scope(self : TreeBuilder, tag : String) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    if elem.tag == tag {
      return true
    }
    // Scope boundary elements
    if is_scope_boundary(elem.tag) {
      return false
    }
  }
  false
}

///|
/// Check if tag is in table scope
fn TreeBuilder::has_element_in_table_scope(
  self : TreeBuilder,
  tag : String,
) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    if elem.tag == tag {
      return true
    }
    // Table scope boundary
    if elem.tag == "html" || elem.tag == "table" || elem.tag == "template" {
      return false
    }
  }
  false
}

///|
/// Scope boundary elements
fn is_scope_boundary(tag : String) -> Bool {
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
/// Create element from tag name and attributes
fn create_element(tag : String, attrs : Map[String, String]) -> Element {
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
/// Insert element at appropriate place
fn TreeBuilder::insert_element(self : TreeBuilder, element : Element) -> Unit {
  if self.foster_parenting && is_table_context(self.current_node()) {
    self.foster_parent_element(element)
  } else {
    match self.current_node() {
      Some(current) => current.children.push(Node::Element(element))
      None => ()
    }
  }
  self.open_elements.push(element)
}

///|
/// Insert element directly into head (for head elements in body mode)
fn TreeBuilder::insert_element_to_head(
  self : TreeBuilder,
  element : Element,
) -> Unit {
  match self.head_element {
    Some(head) => {
      head.children.push(Node::Element(element))
      self.open_elements.push(element)
    }
    None =>
      // Fallback: insert into current element
      self.insert_element(element)
  }
}

///|
/// Insert character at appropriate place
fn TreeBuilder::insert_character(self : TreeBuilder, c : Char) -> Unit {
  if self.foster_parenting && is_table_context(self.current_node()) {
    self.foster_parent_character(c)
  } else {
    match self.current_node() {
      Some(current) => {
        // Try to append to last text node
        let len = current.children.length()
        if len > 0 {
          match current.children[len - 1] {
            Node::Text(existing) => {
              current.children[len - 1] = Node::Text(existing + c.to_string())
              return
            }
            _ => ()
          }
        }
        current.children.push(Node::Text(c.to_string()))
      }
      None => ()
    }
  }
}

///|
/// Check if element is table context for foster parenting
fn is_table_context(elem : Element?) -> Bool {
  match elem {
    Some(e) =>
      match e.tag {
        "table" | "tbody" | "tfoot" | "thead" | "tr" => true
        _ => false
      }
    None => false
  }
}

///|
/// Foster parent an element (insert before table)
fn TreeBuilder::foster_parent_element(
  self : TreeBuilder,
  element : Element,
) -> Unit {
  // Find the table in the stack
  let mut table_idx = -1
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    if self.open_elements[i].tag == "table" {
      table_idx = i
      break
    }
  }
  if table_idx > 0 {
    // Insert before the table in its parent
    let parent = self.open_elements[table_idx - 1]
    // Find position of table in parent's children
    let mut table_pos = -1
    for i = 0; i < parent.children.length(); i = i + 1 {
      match parent.children[i] {
        Node::Element(e) if e.tag == "table" => {
          table_pos = i
          break
        }
        _ => ()
      }
    }
    if table_pos >= 0 {
      // Insert before table
      parent.children.insert(table_pos, Node::Element(element))
    } else {
      // Table not found in parent, append
      parent.children.push(Node::Element(element))
    }
  } else if table_idx == 0 {
    // Table is at root, just add element before it in open_elements
    // This is an edge case - shouldn't normally happen
    ()
  }
}

///|
/// Foster parent a character
fn TreeBuilder::foster_parent_character(self : TreeBuilder, c : Char) -> Unit {
  // Find the table in the stack
  let mut table_idx = -1
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    if self.open_elements[i].tag == "table" {
      table_idx = i
      break
    }
  }
  if table_idx > 0 {
    let parent = self.open_elements[table_idx - 1]
    // Find position of table in parent's children
    let mut table_pos = -1
    for i = 0; i < parent.children.length(); i = i + 1 {
      match parent.children[i] {
        Node::Element(e) if e.tag == "table" => {
          table_pos = i
          break
        }
        _ => ()
      }
    }
    if table_pos >= 0 {
      // Check if there's a text node just before the table
      if table_pos > 0 {
        match parent.children[table_pos - 1] {
          Node::Text(existing) => {
            parent.children[table_pos - 1] = Node::Text(
              existing + c.to_string(),
            )
            return
          }
          _ => ()
        }
      }
      // Insert new text node before table
      parent.children.insert(table_pos, Node::Text(c.to_string()))
    } else {
      // Append to parent
      parent.children.push(Node::Text(c.to_string()))
    }
  }
}

///|
/// Pop elements until we hit a specific tag
fn TreeBuilder::pop_until(self : TreeBuilder, tag : String) -> Unit {
  while not(self.open_elements.is_empty()) {
    let elem = self.open_elements.pop()
    match elem {
      Some(e) if e.tag == tag => break
      _ => ()
    }
  }
}

///|
/// Pop elements until we hit one of the specified tags
fn TreeBuilder::pop_until_one_of(
  self : TreeBuilder,
  tags : Array[String],
) -> Unit {
  while not(self.open_elements.is_empty()) {
    match self.current_node() {
      Some(e) => {
        for tag in tags {
          if e.tag == tag {
            return
          }
        }
        let _ = self.open_elements.pop()

      }
      None => break
    }
  }
}

///|
/// Generate implied end tags
fn TreeBuilder::generate_implied_end_tags(self : TreeBuilder) -> Unit {
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
/// Generate implied end tags except for a specific tag
fn TreeBuilder::generate_implied_end_tags_except(
  self : TreeBuilder,
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
/// Check if tag is formatting element
fn is_formatting_element(tag : String) -> Bool {
  match tag {
    "a"
    | "b"
    | "big"
    | "code"
    | "em"
    | "font"
    | "i"
    | "nobr"
    | "s"
    | "small"
    | "strike"
    | "strong"
    | "tt"
    | "u" => true
    _ => false
  }
}

///|
/// Check if tag is special element
fn is_special_element(tag : String) -> Bool {
  match tag {
    "address"
    | "applet"
    | "area"
    | "article"
    | "aside"
    | "base"
    | "basefont"
    | "bgsound"
    | "blockquote"
    | "body"
    | "br"
    | "button"
    | "caption"
    | "center"
    | "col"
    | "colgroup"
    | "dd"
    | "details"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "embed"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "frame"
    | "frameset"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "header"
    | "hgroup"
    | "hr"
    | "html"
    | "iframe"
    | "img"
    | "input"
    | "keygen"
    | "li"
    | "link"
    | "listing"
    | "main"
    | "marquee"
    | "menu"
    | "meta"
    | "nav"
    | "noembed"
    | "noframes"
    | "noscript"
    | "object"
    | "ol"
    | "p"
    | "param"
    | "plaintext"
    | "pre"
    | "script"
    | "section"
    | "select"
    | "source"
    | "style"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "template"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "title"
    | "tr"
    | "track"
    | "ul"
    | "wbr"
    | "xmp" => true
    _ => false
  }
}

///|
/// Check if tag is void element (for tree builder)
fn tb_is_void_element(tag : String) -> Bool {
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
/// Check if tag is raw text element (for tree builder)
fn tb_is_raw_text_element(tag : String) -> Bool {
  match tag {
    "script" | "style" => true
    _ => false
  }
}

///|
/// Check if tag is escapable raw text element
fn tb_is_escapable_raw_text_element(tag : String) -> Bool {
  match tag {
    "textarea" | "title" => true
    _ => false
  }
}

///|
/// Check if tag is head element (for tree builder)
fn tb_is_head_element(tag : String) -> Bool {
  match tag {
    "base"
    | "basefont"
    | "bgsound"
    | "link"
    | "meta"
    | "noframes"
    | "script"
    | "style"
    | "template"
    | "title" => true
    _ => false
  }
}

///|
/// Run the tree construction algorithm for fragment parsing
/// Starts in InBody mode with pre-created html/head/body structure
pub fn TreeBuilder::build(self : TreeBuilder) -> Element {
  // Create initial document structure
  let html_elem = create_element("html", {})
  let head_elem = create_element("head", {})
  let body_elem = create_element("body", {})
  html_elem.children.push(Node::Element(head_elem))
  html_elem.children.push(Node::Element(body_elem))
  self.open_elements.push(html_elem)
  self.open_elements.push(body_elem)
  self.head_element = Some(head_elem)
  self.insertion_mode = InsertionMode::InBody

  // Process tokens
  while true {
    let token = self.tokenizer.next_token()
    match token {
      Token::EOF => break
      _ => self.process_token(token)
    }
  }
  html_elem
}

///|
/// Run the tree construction algorithm for full document parsing
/// Starts in Initial mode and builds structure from tokens
pub fn TreeBuilder::build_document(self : TreeBuilder) -> Element {
  self.insertion_mode = InsertionMode::Initial

  // Process tokens
  while true {
    let token = self.tokenizer.next_token()
    match token {
      Token::EOF => break
      _ => self.process_token(token)
    }
  }

  // Return html element (first in open_elements or create one)
  match self.open_elements.get(0) {
    Some(elem) => elem
    None => {
      // Fallback: create minimal structure
      let html = create_element("html", {})
      let body = create_element("body", {})
      html.children.push(Node::Element(body))
      html
    }
  }
}

///|
/// Process a single token
fn TreeBuilder::process_token(self : TreeBuilder, token : Token) -> Unit {
  match self.insertion_mode {
    InsertionMode::Initial => self.handle_initial(token)
    InsertionMode::BeforeHtml => self.handle_before_html(token)
    InsertionMode::BeforeHead => self.handle_before_head(token)
    InsertionMode::InHead => self.handle_in_head(token)
    InsertionMode::AfterHead => self.handle_after_head(token)
    InsertionMode::InBody => self.handle_in_body(token)
    InsertionMode::Text => self.handle_text(token)
    InsertionMode::InTable => self.handle_in_table(token)
    InsertionMode::InTableText => self.handle_in_table_text(token)
    InsertionMode::InTableBody => self.handle_in_table_body(token)
    InsertionMode::InRow => self.handle_in_row(token)
    InsertionMode::InCell => self.handle_in_cell(token)
    InsertionMode::InCaption => self.handle_in_caption(token)
    InsertionMode::InColumnGroup => self.handle_in_column_group(token)
    InsertionMode::AfterBody => self.handle_after_body(token)
    _ => self.handle_in_body(token) // Fallback for unimplemented modes
  }
}

///|
/// Handle text insertion mode (for script/style content)
fn TreeBuilder::handle_text(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(c) => self.insert_character(c)
    Token::EOF => {
      // Parse error - pop and switch back
      let _ = self.open_elements.pop()
      match self.original_insertion_mode {
        Some(mode) => self.insertion_mode = mode
        None => self.insertion_mode = InsertionMode::InBody
      }
    }
    Token::EndTag(_) => {
      // Pop current element and switch back to original mode
      let _ = self.open_elements.pop()
      match self.original_insertion_mode {
        Some(mode) => self.insertion_mode = mode
        None => self.insertion_mode = InsertionMode::InBody
      }
    }
    _ => ()
  }
}
