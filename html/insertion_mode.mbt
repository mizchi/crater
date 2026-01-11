///|
/// Insertion Mode Handlers for HTML5 Tree Construction
/// Based on WHATWG HTML5 Parsing Specification

///|
/// Handle initial insertion mode
fn TreeBuilder::handle_initial(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Doctype(_) => self.insertion_mode = InsertionMode::BeforeHtml
    Token::Character(c) if tok_is_whitespace(c) => () // Ignore whitespace
    Token::Characters(s) if is_whitespace_only(s) => () // Ignore whitespace
    _ => {
      self.insertion_mode = InsertionMode::BeforeHtml
      self.reprocess_token(token)
    }
  }
}

///|
/// Handle before html insertion mode
fn TreeBuilder::handle_before_html(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Doctype(_) => () // Ignore
    Token::Character(c) if tok_is_whitespace(c) => () // Ignore whitespace
    Token::Characters(s) if is_whitespace_only(s) => () // Ignore whitespace
    Token::StartTag(tag, attrs, _) if tag == "html" => {
      let elem = create_element(tag, attrs)
      self.open_elements.push(elem)
      self.insertion_mode = InsertionMode::BeforeHead
    }
    _ => {
      let elem = create_element("html", {})
      self.open_elements.push(elem)
      self.insertion_mode = InsertionMode::BeforeHead
      self.reprocess_token(token)
    }
  }
}

///|
/// Handle before head insertion mode
fn TreeBuilder::handle_before_head(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(c) if tok_is_whitespace(c) => () // Ignore whitespace
    Token::Characters(s) if is_whitespace_only(s) => () // Ignore whitespace
    Token::StartTag(tag, attrs, _) if tag == "head" => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.head_element = Some(elem)
      self.insertion_mode = InsertionMode::InHead
    }
    Token::EndTag(tag) if tag == "head" ||
      tag == "body" ||
      tag == "html" ||
      tag == "br" => {
      let elem = create_element("head", {})
      self.insert_element(elem)
      self.head_element = Some(elem)
      self.insertion_mode = InsertionMode::InHead
      self.reprocess_token(token)
    }
    Token::EndTag(_) => () // Parse error, ignore
    _ => {
      let elem = create_element("head", {})
      self.insert_element(elem)
      self.head_element = Some(elem)
      self.insertion_mode = InsertionMode::InHead
      self.reprocess_token(token)
    }
  }
}

///|
/// Handle in head insertion mode
fn TreeBuilder::handle_in_head(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(c) if tok_is_whitespace(c) => self.insert_character(c)
    Token::Characters(s) if is_whitespace_only(s) => self.insert_characters(s)
    Token::StartTag(tag, attrs, self_closing) =>
      match tag {
        "html" => self.handle_in_body(Token::StartTag(tag, attrs, self_closing))
        "base" | "basefont" | "bgsound" | "link" | "meta" => {
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          let _ = self.open_elements.pop()
          // Void element
        }
        "title" => {
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          self.original_insertion_mode = Some(self.insertion_mode)
          self.insertion_mode = InsertionMode::Text
        }
        "style" | "script" => {
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          self.original_insertion_mode = Some(self.insertion_mode)
          self.insertion_mode = InsertionMode::Text
        }
        "template" => {
          // Template requires special handling - for now, create element and skip its content
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          // Switch to RCDATA-like mode to skip content until </template>
          self.original_insertion_mode = Some(self.insertion_mode)
          self.insertion_mode = InsertionMode::Text
        }
        "head" => () // Parse error, ignore
        _ => {
          // Pop head and switch to after head
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::AfterHead
          self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
        }
      }
    Token::EndTag(tag) =>
      match tag {
        "head" => {
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::AfterHead
        }
        "body" | "html" | "br" => {
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::AfterHead
          self.reprocess_token(Token::EndTag(tag))
        }
        _ => () // Parse error, ignore
      }
    _ => {
      let _ = self.open_elements.pop()
      self.insertion_mode = InsertionMode::AfterHead
      self.reprocess_token(token)
    }
  }
}

///|
/// Handle after head insertion mode
fn TreeBuilder::handle_after_head(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(c) if tok_is_whitespace(c) => self.insert_character(c)
    Token::Characters(s) if is_whitespace_only(s) => self.insert_characters(s)
    Token::StartTag(tag, attrs, _) if tag == "body" => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.insertion_mode = InsertionMode::InBody
    }
    Token::StartTag(tag, _, _) if tag == "head" => () // Parse error, ignore
    Token::EndTag(tag) if tag != "body" && tag != "html" && tag != "br" => () // Parse error, ignore
    _ => {
      let elem = create_element("body", {})
      self.insert_element(elem)
      self.insertion_mode = InsertionMode::InBody
      self.reprocess_token(token)
    }
  }
}

///|
/// Handle in body insertion mode - this is the main handler
fn TreeBuilder::handle_in_body(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(c) => self.insert_character(c)
    Token::Characters(s) => self.insert_characters(s)
    Token::Comment(_) => () // Ignore comments for now
    Token::Doctype(_) => () // Parse error, ignore
    Token::StartTag(tag, attrs, self_closing) =>
      self.handle_in_body_start_tag(tag, attrs, self_closing)
    Token::EndTag(tag) => self.handle_in_body_end_tag(tag)
    Token::EOF => ()
  }
}

///|
/// Handle start tags in body
fn TreeBuilder::handle_in_body_start_tag(
  self : TreeBuilder,
  tag : String,
  attrs : Map[String, String],
  self_closing : Bool,
) -> Unit {
  match tag {
    "html" =>
      // Merge attributes to first html element
      ()
    "head" =>
      // Parse error, ignore - we already have a head
      ()
    "base"
    | "basefont"
    | "bgsound"
    | "link"
    | "meta"
    | "noframes"
    | "script"
    | "style"
    | "template"
    | "title" => self.handle_in_head(Token::StartTag(tag, attrs, self_closing))
    "body" =>
      // Merge attributes if already have body
      ()
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "center"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "header"
    | "hgroup"
    | "main"
    | "menu"
    | "nav"
    | "ol"
    | "p"
    | "section"
    | "summary"
    | "ul" => {
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      // If current is heading, pop it (implicit close)
      match self.current_node() {
        Some(e) if e.tag == "h1" ||
          e.tag == "h2" ||
          e.tag == "h3" ||
          e.tag == "h4" ||
          e.tag == "h5" ||
          e.tag == "h6" => {
          let _ = self.open_elements.pop()

        }
        _ => ()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "pre" | "listing" => {
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "form" => {
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "li" => {
      self.frameset_ok = false
      self.close_li_if_needed()
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "dd" | "dt" => {
      self.frameset_ok = false
      self.close_dd_dt_if_needed()
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "plaintext" => {
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "button" => {
      if self.has_element_in_scope("button") {
        self.generate_implied_end_tags()
        self.pop_until("button")
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "a" => {
      // Check for active anchor and close if needed
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.active_formatting.push(FormattingElement::Element(elem))
    }
    "b"
    | "big"
    | "code"
    | "em"
    | "font"
    | "i"
    | "s"
    | "small"
    | "strike"
    | "strong"
    | "tt"
    | "u" => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.active_formatting.push(FormattingElement::Element(elem))
    }
    "nobr" => {
      if self.has_element_in_scope("nobr") {
        // Run adoption agency
        self.pop_until("nobr")
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.active_formatting.push(FormattingElement::Element(elem))
    }
    "table" => {
      if self.has_element_in_button_scope("p") {
        self.close_p_element()
      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.frameset_ok = false
      self.insertion_mode = InsertionMode::InTable
    }
    "area"
    | "br"
    | "embed"
    | "img"
    | "keygen"
    | "wbr"
    | "input"
    | "param"
    | "source"
    | "track"
    | "hr" => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      let _ = self.open_elements.pop()
      // Void element
    }
    "image" => {
      // Treated as <img>
      let elem = create_element("img", attrs)
      self.insert_element(elem)
      let _ = self.open_elements.pop()

    }
    "textarea" => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.original_insertion_mode = Some(self.insertion_mode)
      self.insertion_mode = InsertionMode::Text
    }
    "select" => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      self.insertion_mode = InsertionMode::InSelect
    }
    "optgroup" | "option" => {
      if self.current_node() is Some(e) && e.tag == "option" {
        let _ = self.open_elements.pop()

      }
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
    }
    "caption"
    | "col"
    | "colgroup"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" =>
      // These are table-only elements, ignore if not in table context
      ()
    _ => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      if self_closing {
        let _ = self.open_elements.pop()

      }
    }
  }
}

///|
/// Handle end tags in body
fn TreeBuilder::handle_in_body_end_tag(
  self : TreeBuilder,
  tag : String,
) -> Unit {
  // Flush any pending text before processing end tag
  // This ensures text content is added to the current element before it's popped
  self.flush_pending_text()
  match tag {
    "body" => {
      if not(self.has_element_in_scope("body")) {
        return // Parse error, ignore
      }
      self.insertion_mode = InsertionMode::AfterBody
    }
    "html" => {
      if not(self.has_element_in_scope("body")) {
        return // Parse error, ignore
      }
      self.insertion_mode = InsertionMode::AfterBody
      self.reprocess_token(Token::EndTag("html"))
    }
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "button"
    | "center"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "header"
    | "hgroup"
    | "listing"
    | "main"
    | "menu"
    | "nav"
    | "ol"
    | "pre"
    | "section"
    | "summary"
    | "ul" => {
      if not(self.has_element_in_scope(tag)) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags()
      self.pop_until(tag)
    }
    "form" => {
      self.generate_implied_end_tags()
      self.pop_until("form")
    }
    "p" => {
      if not(self.has_element_in_button_scope("p")) {
        // Create an implicit p element
        let elem = create_element("p", {})
        self.insert_element(elem)
      }
      self.close_p_element()
    }
    "li" => {
      if not(self.has_element_in_list_scope("li")) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags_except("li")
      self.pop_until("li")
    }
    "dd" | "dt" => {
      if not(self.has_element_in_scope(tag)) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags_except(tag)
      self.pop_until(tag)
    }
    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
      if not(self.has_heading_in_scope()) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags()
      // Pop until any heading
      while not(self.open_elements.is_empty()) {
        match self.current_node() {
          Some(e) if e.tag == "h1" ||
            e.tag == "h2" ||
            e.tag == "h3" ||
            e.tag == "h4" ||
            e.tag == "h5" ||
            e.tag == "h6" => {
            let _ = self.open_elements.pop()
            break
          }
          _ => {
            let _ = self.open_elements.pop()

          }
        }
      }
    }
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
    | "u" =>
      // Simple close - full adoption agency needed for complete spec
      if self.has_element_in_scope(tag) {
        self.generate_implied_end_tags()
        self.pop_until(tag)
        self.remove_from_active_formatting(tag)
      }
    "br" => {
      // </br> is treated as <br>
      let elem = create_element("br", {})
      self.insert_element(elem)
      let _ = self.open_elements.pop()

    }
    _ =>
      // Any other end tag
      self.any_other_end_tag(tag)
  }
}

///|
/// Handle any other end tag in body
fn TreeBuilder::any_other_end_tag(self : TreeBuilder, tag : String) -> Unit {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let node = self.open_elements[i]
    if node.tag == tag {
      self.generate_implied_end_tags_except(tag)
      // Pop until this node
      while self.open_elements.length() > i + 1 {
        let _ = self.open_elements.pop()

      }
      let _ = self.open_elements.pop() // Pop the matched node
      return
    }
    if is_special_element(node.tag) {
      return // Parse error, ignore
    }
  }
}

///|
/// Handle in table insertion mode
fn TreeBuilder::handle_in_table(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(_) | Token::Characters(_) => {
      // Enable foster parenting for text in table
      self.pending_table_chars = []
      self.original_insertion_mode = Some(self.insertion_mode)
      self.insertion_mode = InsertionMode::InTableText
      self.reprocess_token(token)
    }
    Token::Comment(_) => () // Ignore for now
    Token::Doctype(_) => () // Parse error, ignore
    Token::StartTag(tag, attrs, self_closing) =>
      match tag {
        "caption" => {
          self.clear_stack_to_table_context()
          self.active_formatting.push(FormattingElement::Marker)
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InCaption
        }
        "colgroup" => {
          self.clear_stack_to_table_context()
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InColumnGroup
        }
        "col" => {
          self.clear_stack_to_table_context()
          let elem = create_element("colgroup", {})
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InColumnGroup
          self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
        }
        "tbody" | "tfoot" | "thead" => {
          self.clear_stack_to_table_context()
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InTableBody
        }
        "td" | "th" | "tr" => {
          self.clear_stack_to_table_context()
          let elem = create_element("tbody", {})
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InTableBody
          self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
        }
        "table" =>
          // Close current table and reprocess
          if self.has_element_in_table_scope("table") {
            self.pop_until("table")
            self.reset_insertion_mode()
            self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
          }
        "style" | "script" | "template" =>
          self.handle_in_head(Token::StartTag(tag, attrs, self_closing))
        "input" =>
          // Check if type is hidden
          match attrs.get("type") {
            Some(t) if t.to_lower() == "hidden" => {
              let elem = create_element(tag, attrs)
              self.insert_element(elem)
              let _ = self.open_elements.pop()

            }
            _ => {
              // Foster parent
              self.foster_parenting = true
              self.handle_in_body(Token::StartTag(tag, attrs, self_closing))
              self.foster_parenting = false
            }
          }
        "form" => () // Parse error, ignore
        _ => {
          // Foster parent
          self.foster_parenting = true
          self.handle_in_body(Token::StartTag(tag, attrs, self_closing))
          self.foster_parenting = false
        }
      }
    Token::EndTag(tag) =>
      match tag {
        "table" => {
          if not(self.has_element_in_table_scope("table")) {
            return // Parse error, ignore
          }
          self.pop_until("table")
          self.reset_insertion_mode()
        }
        "body"
        | "caption"
        | "col"
        | "colgroup"
        | "html"
        | "tbody"
        | "td"
        | "tfoot"
        | "th"
        | "thead"
        | "tr" => () // Parse error, ignore
        "template" => self.handle_in_head(Token::EndTag(tag))
        _ => {
          // Foster parent
          self.foster_parenting = true
          self.handle_in_body(Token::EndTag(tag))
          self.foster_parenting = false
        }
      }
    Token::EOF => self.handle_in_body(token)
  }
}

///|
/// Handle in table text
fn TreeBuilder::handle_in_table_text(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(c) => self.pending_table_chars.push(c)
    Token::Characters(s) =>
      for c in s {
        self.pending_table_chars.push(c)
      }
    _ => {
      // Flush pending table characters
      let mut has_non_space = false
      for c in self.pending_table_chars {
        if not(tok_is_whitespace(c)) {
          has_non_space = true
          break
        }
      }
      if has_non_space {
        // Foster parent all pending chars
        self.foster_parenting = true
        for c in self.pending_table_chars {
          self.insert_character(c)
        }
        self.foster_parenting = false
      } else {
        // Insert as regular characters
        for c in self.pending_table_chars {
          self.insert_character(c)
        }
      }
      self.pending_table_chars = []
      match self.original_insertion_mode {
        Some(mode) => self.insertion_mode = mode
        None => self.insertion_mode = InsertionMode::InTable
      }
      self.reprocess_token(token)
    }
  }
}

///|
/// Handle in table body
fn TreeBuilder::handle_in_table_body(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::StartTag(tag, attrs, self_closing) =>
      match tag {
        "tr" => {
          self.clear_stack_to_table_body_context()
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InRow
        }
        "th" | "td" => {
          self.clear_stack_to_table_body_context()
          let elem = create_element("tr", {})
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InRow
          self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
        }
        "caption" | "col" | "colgroup" | "tbody" | "tfoot" | "thead" => {
          if not(self.has_element_in_table_scope("tbody")) &&
            not(self.has_element_in_table_scope("thead")) &&
            not(self.has_element_in_table_scope("tfoot")) {
            return // Parse error, ignore
          }
          self.clear_stack_to_table_body_context()
          let _ = self.open_elements.pop() // Pop tbody/thead/tfoot
          self.insertion_mode = InsertionMode::InTable
          self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
        }
        _ => self.handle_in_table(Token::StartTag(tag, attrs, self_closing))
      }
    Token::EndTag(tag) =>
      match tag {
        "tbody" | "tfoot" | "thead" => {
          if not(self.has_element_in_table_scope(tag)) {
            return // Parse error, ignore
          }
          self.clear_stack_to_table_body_context()
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::InTable
        }
        "table" => {
          if not(self.has_element_in_table_scope("tbody")) &&
            not(self.has_element_in_table_scope("thead")) &&
            not(self.has_element_in_table_scope("tfoot")) {
            return // Parse error, ignore
          }
          self.clear_stack_to_table_body_context()
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::InTable
          self.reprocess_token(Token::EndTag(tag))
        }
        "body" | "caption" | "col" | "colgroup" | "html" | "td" | "th" | "tr" =>
          () // Parse error, ignore
        _ => self.handle_in_table(Token::EndTag(tag))
      }
    _ => self.handle_in_table(token)
  }
}

///|
/// Handle in row
fn TreeBuilder::handle_in_row(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::StartTag(tag, attrs, self_closing) =>
      match tag {
        "th" | "td" => {
          self.clear_stack_to_table_row_context()
          let elem = create_element(tag, attrs)
          self.insert_element(elem)
          self.insertion_mode = InsertionMode::InCell
          self.active_formatting.push(FormattingElement::Marker)
        }
        "caption" | "col" | "colgroup" | "tbody" | "tfoot" | "thead" | "tr" => {
          if not(self.has_element_in_table_scope("tr")) {
            return // Parse error, ignore
          }
          self.clear_stack_to_table_row_context()
          let _ = self.open_elements.pop() // Pop tr
          self.insertion_mode = InsertionMode::InTableBody
          self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
        }
        _ => self.handle_in_table(Token::StartTag(tag, attrs, self_closing))
      }
    Token::EndTag(tag) =>
      match tag {
        "tr" => {
          if not(self.has_element_in_table_scope("tr")) {
            return // Parse error, ignore
          }
          self.clear_stack_to_table_row_context()
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::InTableBody
        }
        "table" => {
          if not(self.has_element_in_table_scope("tr")) {
            return // Parse error, ignore
          }
          self.clear_stack_to_table_row_context()
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::InTableBody
          self.reprocess_token(Token::EndTag(tag))
        }
        "tbody" | "tfoot" | "thead" => {
          if not(self.has_element_in_table_scope(tag)) {
            return // Parse error, ignore
          }
          if not(self.has_element_in_table_scope("tr")) {
            return // Ignore
          }
          self.clear_stack_to_table_row_context()
          let _ = self.open_elements.pop()
          self.insertion_mode = InsertionMode::InTableBody
          self.reprocess_token(Token::EndTag(tag))
        }
        "body" | "caption" | "col" | "colgroup" | "html" | "td" | "th" => () // Parse error, ignore
        _ => self.handle_in_table(Token::EndTag(tag))
      }
    _ => self.handle_in_table(token)
  }
}

///|
fn is_cell_closing_start_tag(tag : String) -> Bool {
  match tag {
    "caption"
    | "col"
    | "colgroup"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn is_cell_ignored_end_tag(tag : String) -> Bool {
  match tag {
    "body" | "caption" | "col" | "colgroup" | "html" => true
    _ => false
  }
}

///|
fn is_cell_scope_end_tag(tag : String) -> Bool {
  match tag {
    "table" | "tbody" | "tfoot" | "thead" | "tr" => true
    _ => false
  }
}

///|
/// Handle in cell
fn TreeBuilder::handle_in_cell(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::EndTag(tag) if tag == "td" || tag == "th" => {
      if not(self.has_element_in_table_scope(tag)) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags()
      self.pop_until(tag)
      self.clear_active_formatting_to_marker()
      self.insertion_mode = InsertionMode::InRow
    }
    Token::StartTag(tag, attrs, self_closing) if is_cell_closing_start_tag(tag) => {
      if not(self.has_element_in_table_scope("td")) &&
        not(self.has_element_in_table_scope("th")) {
        return // Parse error, ignore
      }
      self.close_cell()
      self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
    }
    Token::EndTag(tag) if is_cell_ignored_end_tag(tag) => () // Parse error, ignore
    Token::EndTag(tag) if is_cell_scope_end_tag(tag) => {
      if not(self.has_element_in_table_scope(tag)) {
        return // Parse error, ignore
      }
      self.close_cell()
      self.reprocess_token(Token::EndTag(tag))
    }
    _ => self.handle_in_body(token)
  }
}

///|
fn is_caption_closing_start_tag(tag : String) -> Bool {
  match tag {
    "caption"
    | "col"
    | "colgroup"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn is_caption_ignored_end_tag(tag : String) -> Bool {
  match tag {
    "body"
    | "col"
    | "colgroup"
    | "html"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
/// Handle in caption
fn TreeBuilder::handle_in_caption(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::EndTag(tag) if tag == "caption" => {
      if not(self.has_element_in_table_scope("caption")) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags()
      self.pop_until("caption")
      self.clear_active_formatting_to_marker()
      self.insertion_mode = InsertionMode::InTable
    }
    Token::StartTag(tag, attrs, self_closing) if is_caption_closing_start_tag(
        tag,
      ) => {
      if not(self.has_element_in_table_scope("caption")) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags()
      self.pop_until("caption")
      self.clear_active_formatting_to_marker()
      self.insertion_mode = InsertionMode::InTable
      self.reprocess_token(Token::StartTag(tag, attrs, self_closing))
    }
    Token::EndTag(tag) if tag == "table" => {
      if not(self.has_element_in_table_scope("caption")) {
        return // Parse error, ignore
      }
      self.generate_implied_end_tags()
      self.pop_until("caption")
      self.clear_active_formatting_to_marker()
      self.insertion_mode = InsertionMode::InTable
      self.reprocess_token(Token::EndTag(tag))
    }
    Token::EndTag(tag) if is_caption_ignored_end_tag(tag) => () // Parse error, ignore
    _ => self.handle_in_body(token)
  }
}

///|
/// Handle in column group
fn TreeBuilder::handle_in_column_group(
  self : TreeBuilder,
  token : Token,
) -> Unit {
  match token {
    Token::Character(c) if tok_is_whitespace(c) => self.insert_character(c)
    Token::Characters(s) if is_whitespace_only(s) => self.insert_characters(s)
    Token::Comment(_) => () // Ignore
    Token::Doctype(_) => () // Parse error, ignore
    Token::StartTag(tag, attrs, _) if tag == "html" =>
      self.handle_in_body(Token::StartTag(tag, attrs, false))
    Token::StartTag(tag, attrs, _) if tag == "col" => {
      let elem = create_element(tag, attrs)
      self.insert_element(elem)
      let _ = self.open_elements.pop()
      // Void element
    }
    Token::StartTag(tag, attrs, self_closing) if tag == "template" =>
      self.handle_in_head(Token::StartTag(tag, attrs, self_closing))
    Token::EndTag(tag) if tag == "colgroup" => {
      match self.current_node() {
        Some(e) if e.tag != "colgroup" => return // Parse error, ignore
        _ => ()
      }
      let _ = self.open_elements.pop()
      self.insertion_mode = InsertionMode::InTable
    }
    Token::EndTag(tag) if tag == "col" => () // Parse error, ignore
    Token::EndTag(tag) if tag == "template" =>
      self.handle_in_head(Token::EndTag(tag))
    Token::EOF => self.handle_in_body(token)
    _ => {
      match self.current_node() {
        Some(e) if e.tag != "colgroup" => return // Parse error, ignore
        _ => ()
      }
      let _ = self.open_elements.pop()
      self.insertion_mode = InsertionMode::InTable
      self.reprocess_token(token)
    }
  }
}

///|
/// Handle after body
fn TreeBuilder::handle_after_body(self : TreeBuilder, token : Token) -> Unit {
  match token {
    Token::Character(c) if tok_is_whitespace(c) =>
      self.handle_in_body(Token::Character(c))
    Token::Characters(s) if is_whitespace_only(s) =>
      self.handle_in_body(Token::Characters(s))
    Token::Comment(_) => () // Ignore
    Token::Doctype(_) => () // Parse error, ignore
    Token::StartTag(tag, _, _) if tag == "html" => self.handle_in_body(token)
    Token::EndTag(tag) if tag == "html" =>
      self.insertion_mode = InsertionMode::AfterAfterBody
    Token::EOF => () // Stop
    _ => {
      self.insertion_mode = InsertionMode::InBody
      self.reprocess_token(token)
    }
  }
}

///|
/// Helper: check if p is in button scope
fn TreeBuilder::has_element_in_button_scope(
  self : TreeBuilder,
  tag : String,
) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    if elem.tag == tag {
      return true
    }
    if is_scope_boundary(elem.tag) || elem.tag == "button" {
      return false
    }
  }
  false
}

///|
/// Helper: check if element is in list scope
fn TreeBuilder::has_element_in_list_scope(
  self : TreeBuilder,
  tag : String,
) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    if elem.tag == tag {
      return true
    }
    if is_scope_boundary(elem.tag) || elem.tag == "ol" || elem.tag == "ul" {
      return false
    }
  }
  false
}

///|
/// Helper: check if any heading is in scope
fn TreeBuilder::has_heading_in_scope(self : TreeBuilder) -> Bool {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    match elem.tag {
      "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => return true
      _ => ()
    }
    if is_scope_boundary(elem.tag) {
      return false
    }
  }
  false
}

///|
/// Helper: close p element
fn TreeBuilder::close_p_element(self : TreeBuilder) -> Unit {
  self.generate_implied_end_tags_except("p")
  self.pop_until("p")
}

///|
/// Helper: close li if needed
fn TreeBuilder::close_li_if_needed(self : TreeBuilder) -> Unit {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    if elem.tag == "li" {
      self.generate_implied_end_tags_except("li")
      self.pop_until("li")
      return
    }
    if is_special_element(elem.tag) &&
      elem.tag != "address" &&
      elem.tag != "div" &&
      elem.tag != "p" {
      return
    }
  }
}

///|
/// Helper: close dd/dt if needed
fn TreeBuilder::close_dd_dt_if_needed(self : TreeBuilder) -> Unit {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let elem = self.open_elements[i]
    if elem.tag == "dd" || elem.tag == "dt" {
      self.generate_implied_end_tags_except(elem.tag)
      self.pop_until(elem.tag)
      return
    }
    if is_special_element(elem.tag) &&
      elem.tag != "address" &&
      elem.tag != "div" &&
      elem.tag != "p" {
      return
    }
  }
}

///|
/// Helper: remove element from active formatting
fn TreeBuilder::remove_from_active_formatting(
  self : TreeBuilder,
  tag : String,
) -> Unit {
  for i = self.active_formatting.length() - 1; i >= 0; i = i - 1 {
    match self.active_formatting[i] {
      FormattingElement::Element(e) if e.tag == tag => {
        let _ = self.active_formatting.remove(i)
        return
      }
      _ => ()
    }
  }
}

///|
/// Helper: clear stack to table context
fn TreeBuilder::clear_stack_to_table_context(self : TreeBuilder) -> Unit {
  while not(self.open_elements.is_empty()) {
    match self.current_node() {
      Some(e) if e.tag == "table" || e.tag == "template" || e.tag == "html" =>
        return
      _ => {
        let _ = self.open_elements.pop()

      }
    }
  }
}

///|
fn is_table_body_context(tag : String) -> Bool {
  match tag {
    "tbody" | "tfoot" | "thead" | "template" | "html" => true
    _ => false
  }
}

///|
/// Helper: clear stack to table body context
fn TreeBuilder::clear_stack_to_table_body_context(self : TreeBuilder) -> Unit {
  while not(self.open_elements.is_empty()) {
    match self.current_node() {
      Some(e) if is_table_body_context(e.tag) => return
      _ => {
        let _ = self.open_elements.pop()

      }
    }
  }
}

///|
/// Helper: clear stack to table row context
fn TreeBuilder::clear_stack_to_table_row_context(self : TreeBuilder) -> Unit {
  while not(self.open_elements.is_empty()) {
    match self.current_node() {
      Some(e) if e.tag == "tr" || e.tag == "template" || e.tag == "html" =>
        return
      _ => {
        let _ = self.open_elements.pop()

      }
    }
  }
}

///|
/// Helper: clear active formatting to marker
fn TreeBuilder::clear_active_formatting_to_marker(self : TreeBuilder) -> Unit {
  while not(self.active_formatting.is_empty()) {
    match self.active_formatting.pop() {
      Some(FormattingElement::Marker) => return
      _ => ()
    }
  }
}

///|
/// Helper: close cell
fn TreeBuilder::close_cell(self : TreeBuilder) -> Unit {
  self.generate_implied_end_tags()
  // Pop until td or th
  while not(self.open_elements.is_empty()) {
    match self.current_node() {
      Some(e) if e.tag == "td" || e.tag == "th" => {
        let _ = self.open_elements.pop()
        break
      }
      _ => {
        let _ = self.open_elements.pop()

      }
    }
  }
  self.clear_active_formatting_to_marker()
  self.insertion_mode = InsertionMode::InRow
}

///|
/// Helper: reset insertion mode appropriately
fn TreeBuilder::reset_insertion_mode(self : TreeBuilder) -> Unit {
  for i = self.open_elements.length() - 1; i >= 0; i = i - 1 {
    let node = self.open_elements[i]
    let last = i == 0
    match node.tag {
      "select" => {
        self.insertion_mode = InsertionMode::InSelect
        return
      }
      "td" | "th" if not(last) => {
        self.insertion_mode = InsertionMode::InCell
        return
      }
      "tr" => {
        self.insertion_mode = InsertionMode::InRow
        return
      }
      "tbody" | "thead" | "tfoot" => {
        self.insertion_mode = InsertionMode::InTableBody
        return
      }
      "caption" => {
        self.insertion_mode = InsertionMode::InCaption
        return
      }
      "colgroup" => {
        self.insertion_mode = InsertionMode::InColumnGroup
        return
      }
      "table" => {
        self.insertion_mode = InsertionMode::InTable
        return
      }
      "head" | "body" => {
        self.insertion_mode = InsertionMode::InBody
        return
      }
      "frameset" => {
        self.insertion_mode = InsertionMode::InFrameset
        return
      }
      "html" => {
        self.insertion_mode = InsertionMode::BeforeHead
        return
      }
      _ => ()
    }
    if last {
      self.insertion_mode = InsertionMode::InBody
      return
    }
  }
}
