///|
/// CSS Selector Parser
/// Parses CSS tokens into Selector structures

///|
/// Parser state
priv struct SelectorParser {
  tokens : Array[@token.Token]
  mut pos : Int
}

///|
fn SelectorParser::new(tokens : Array[@token.Token]) -> SelectorParser {
  { tokens, pos: 0 }
}

///|
fn SelectorParser::peek(self : SelectorParser) -> @token.Token {
  if self.pos >= self.tokens.length() {
    // Return a safe fallback - this should not happen if tokenize() adds EOF
    self.tokens[self.tokens.length() - 1]
  } else {
    self.tokens[self.pos]
  }
}

///|
fn SelectorParser::is_at_end(self : SelectorParser) -> Bool {
  self.pos >= self.tokens.length() ||
  (match self.tokens[self.pos] {
    EOF => true
    _ => false
  })
}

///|
fn SelectorParser::advance(self : SelectorParser) -> @token.Token {
  let tok = self.peek()
  self.pos = self.pos + 1
  tok
}

///|
fn SelectorParser::skip_whitespace(self : SelectorParser) -> Unit {
  while not(self.is_at_end()) {
    match self.peek() {
      Whitespace => {
        let _ = self.advance()

      }
      _ => break
    }
  }
}

///|
/// Parse a selector list (comma-separated)
pub fn parse_selector_list(tokens : Array[@token.Token]) -> SelectorList? {
  let parser = SelectorParser::new(tokens)
  parser.skip_whitespace()
  let selectors : Array[ComplexSelector] = []

  // Parse first selector
  match parser.parse_complex_selector() {
    Some(sel) => selectors.push(sel)
    None => return None
  }

  // Parse remaining selectors
  while not(parser.is_at_end()) {
    parser.skip_whitespace()
    match parser.peek() {
      Comma => {
        let _ = parser.advance()
        parser.skip_whitespace()
        match parser.parse_complex_selector() {
          Some(sel) => selectors.push(sel)
          None => return None
        }
      }
      _ => break
    }
  }
  Some(SelectorList::{ selectors, })
}

///|
/// Parse a single selector (without commas)
pub fn parse_selector(tokens : Array[@token.Token]) -> ComplexSelector? {
  let parser = SelectorParser::new(tokens)
  parser.skip_whitespace()
  parser.parse_complex_selector()
}

///|
fn SelectorParser::parse_complex_selector(
  self : SelectorParser,
) -> ComplexSelector? {
  // Parse the first compound selector
  let first = match self.parse_compound_selector() {
    None => return None
    Some(f) => f
  }
  let tail : Array[ComplexSelectorStep] = []
  let mut current = first
  while not(self.is_at_end()) {
    // Check for combinator (maybe preceded by whitespace)
    let had_whitespace = match self.peek() {
      Whitespace => {
        let _ = self.advance()
        true
      }
      _ => false
    }

    // Check for explicit combinator
    let combinator : Combinator? = match self.peek() {
      Delim('>') => {
        let _ = self.advance()
        self.skip_whitespace()
        Some(Child)
      }
      Delim('+') => {
        let _ = self.advance()
        self.skip_whitespace()
        Some(NextSibling)
      }
      Delim('~') => {
        let _ = self.advance()
        self.skip_whitespace()
        Some(SubsequentSibling)
      }
      _ =>
        if had_whitespace {
          // Descendant combinator (whitespace)
          Some(Descendant)
        } else {
          None
        }
    }
    match combinator {
      None => break
      Some(comb) =>
        // Try to parse next compound selector
        match self.parse_compound_selector() {
          None => break
          Some(next) => {
            // Build chain: push current to tail with combinator, next becomes current
            tail.push({ combinator: comb, selector: current })
            current = next
          }
        }
    }
  }

  // Reverse tail so it goes from right to left
  let reversed_tail : Array[ComplexSelectorStep] = []
  for i = tail.length() - 1; i >= 0; i = i - 1 {
    reversed_tail.push(tail[i])
  }
  Some({ head: current, tail: reversed_tail })
}

///|
fn SelectorParser::parse_compound_selector(
  self : SelectorParser,
) -> CompoundSelector? {
  let mut type_selector : SimpleSelector? = None
  let subclasses : Array[SimpleSelector] = []

  // First, try to parse type selector or universal
  match self.peek() {
    Ident(name) => {
      let _ = self.advance()
      type_selector = Some(Type(name.to_lower()))
    }
    Delim('*') => {
      let _ = self.advance()
      type_selector = Some(Universal)
    }
    _ => ()
  }

  // Parse subclass selectors
  while not(self.is_at_end()) {
    match self.peek() {
      // ID selector
      Hash(id, _) => {
        let _ = self.advance()
        subclasses.push(Id(id))
      }
      // Class selector
      Delim('.') => {
        let _ = self.advance()
        match self.peek() {
          Ident(class_name) => {
            let _ = self.advance()
            subclasses.push(Class(class_name))
          }
          _ => break
        }
      }
      // Attribute selector
      LeftBracket =>
        match self.parse_attribute_selector() {
          Some(attr) => subclasses.push(Attribute(attr))
          None => break
        }
      // Pseudo-class or pseudo-element
      Colon => {
        let _ = self.advance()
        match self.peek() {
          // Double colon - pseudo-element
          Colon => {
            let _ = self.advance()
            match self.parse_pseudo_element() {
              Some(pe) => subclasses.push(PseudoElement(pe))
              None => break
            }
          }
          // Single colon - pseudo-class (or legacy pseudo-element)
          _ =>
            match self.parse_pseudo_class() {
              Some(pc) => subclasses.push(PseudoClass(pc))
              None => break
            }
        }
      }
      _ => break
    }
  }

  // Must have at least one selector component
  if type_selector is None && subclasses.is_empty() {
    return None
  }
  Some({ type_selector, subclasses })
}

///|
fn SelectorParser::parse_attribute_selector(
  self : SelectorParser,
) -> AttributeSelector? {
  // Consume '['
  match self.peek() {
    LeftBracket => {
      let _ = self.advance()

    }
    _ => return None
  }
  self.skip_whitespace()

  // Get attribute name
  let name = match self.peek() {
    Ident(n) => {
      let _ = self.advance()
      n
    }
    _ => return None
  }
  self.skip_whitespace()

  // Check for match operator or end
  let match_type : AttributeMatch = match self.peek() {
    RightBracket => {
      let _ = self.advance()
      return Some({ name, match_type: Exists, case_insensitive: false })
    }
    Delim('=') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Exact(v)
        None => return None
      }
    }
    Delim('~') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()

        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Includes(v)
        None => return None
      }
    }
    Delim('|') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()

        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => DashMatch(v)
        None => return None
      }
    }
    Delim('^') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()

        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Prefix(v)
        None => return None
      }
    }
    Delim('$') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()

        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Suffix(v)
        None => return None
      }
    }
    Delim('*') => {
      let _ = self.advance()
      match self.peek() {
        Delim('=') => {
          let _ = self.advance()

        }
        _ => return None
      }
      self.skip_whitespace()
      match self.parse_attr_value() {
        Some(v) => Substring(v)
        None => return None
      }
    }
    _ => return None
  }
  self.skip_whitespace()

  // Check for case-insensitive flag
  let case_insensitive = match self.peek() {
    Ident(flag) =>
      if flag.to_lower() == "i" {
        let _ = self.advance()
        self.skip_whitespace()
        true
      } else if flag.to_lower() == "s" {
        let _ = self.advance()
        self.skip_whitespace()
        false
      } else {
        false
      }
    _ => false
  }

  // Consume ']'
  match self.peek() {
    RightBracket => {
      let _ = self.advance()

    }
    _ => return None
  }
  Some({ name, match_type, case_insensitive })
}

///|
fn SelectorParser::parse_attr_value(self : SelectorParser) -> String? {
  match self.peek() {
    Ident(v) => {
      let _ = self.advance()
      Some(v)
    }
    @token.Token::String(v) => {
      let _ = self.advance()
      Some(v)
    }
    _ => None
  }
}

///|
fn SelectorParser::parse_pseudo_element(
  self : SelectorParser,
) -> PseudoElement? {
  match self.peek() {
    Ident(name) => {
      let _ = self.advance()
      match name.to_lower() {
        "before" => Some(Before)
        "after" => Some(After)
        "first-line" => Some(FirstLine)
        "first-letter" => Some(FirstLetter)
        "marker" => Some(Marker)
        "placeholder" => Some(Placeholder)
        "selection" => Some(Selection)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn SelectorParser::parse_pseudo_class(self : SelectorParser) -> PseudoClass? {
  match self.peek() {
    Ident(name) => {
      let _ = self.advance()
      match name.to_lower() {
        "first-child" => Some(FirstChild)
        "last-child" => Some(LastChild)
        "only-child" => Some(OnlyChild)
        "first-of-type" => Some(FirstOfType)
        "last-of-type" => Some(LastOfType)
        "only-of-type" => Some(OnlyOfType)
        "root" => Some(Root)
        "empty" => Some(Empty)
        "hover" => Some(Hover)
        "active" => Some(Active)
        "focus" => Some(Focus)
        "focus-visible" => Some(FocusVisible)
        "focus-within" => Some(FocusWithin)
        "link" => Some(Link)
        "visited" => Some(Visited)
        "any-link" => Some(AnyLink)
        "enabled" => Some(Enabled)
        "disabled" => Some(Disabled)
        "checked" => Some(Checked)
        "indeterminate" => Some(Indeterminate)
        "required" => Some(Required)
        "optional" => Some(Optional)
        "valid" => Some(Valid)
        "invalid" => Some(Invalid)
        "read-only" => Some(ReadOnly)
        "read-write" => Some(ReadWrite)
        _ => None
      }
    }
    Function(name) => {
      let _ = self.advance() // Consume the Function token
      let name_lower = name.to_lower()
      match name_lower {
        "nth-child" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthChild(e))
                None => None
              }
            }
            _ => None
          }
        }
        "nth-last-child" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthLastChild(e))
                None => None
              }
            }
            _ => None
          }
        }
        "nth-of-type" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthOfType(e))
                None => None
              }
            }
            _ => None
          }
        }
        "nth-last-of-type" => {
          let expr = self.parse_nth_expr()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              match expr {
                Some(e) => Some(NthLastOfType(e))
                None => None
              }
            }
            _ => None
          }
        }
        "not" => {
          self.skip_whitespace()
          let selectors = self.parse_compound_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              Some(Not(selectors))
            }
            _ => None
          }
        }
        "is" => {
          self.skip_whitespace()
          let selectors = self.parse_complex_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              Some(Is(selectors))
            }
            _ => None
          }
        }
        "where" => {
          self.skip_whitespace()
          let selectors = self.parse_complex_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              Some(Where(selectors))
            }
            _ => None
          }
        }
        "has" => {
          self.skip_whitespace()
          let selectors = self.parse_relative_selector_list_until_paren()
          match self.peek() {
            RightParen => {
              let _ = self.advance()
              Some(Has(selectors))
            }
            _ => None
          }
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn SelectorParser::parse_nth_expr(self : SelectorParser) -> NthExpr? {
  self.skip_whitespace()

  // Handle keywords: odd, even
  match self.peek() {
    Ident(kw) => {
      let kw_lower = kw.to_lower()
      if kw_lower == "odd" {
        let _ = self.advance()
        return Some({ a: 2, b: 1 })
      }
      if kw_lower == "even" {
        let _ = self.advance()
        return Some({ a: 2, b: 0 })
      }
      if kw_lower == "n" {
        let _ = self.advance()
        // Just 'n' = 1n+0
        self.skip_whitespace()
        let b = self.parse_nth_b()
        return Some({ a: 1, b })
      }
      if kw_lower == "-n" {
        let _ = self.advance()
        self.skip_whitespace()
        let b = self.parse_nth_b()
        return Some({ a: -1, b })
      }
      return None
    }
    Dimension(num, unit) => {
      if unit.to_lower() == "n" {
        let _ = self.advance()
        let a = num.to_int()
        self.skip_whitespace()
        let b = self.parse_nth_b()
        return Some({ a, b })
      }
      return None
    }
    Number(num, _) => {
      let _ = self.advance()
      // Just a number = 0n+B
      return Some({ a: 0, b: num.to_int() })
    }
    Delim('+') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.peek() {
        Ident(kw) =>
          if kw.to_lower() == "n" {
            let _ = self.advance()
            self.skip_whitespace()
            let b = self.parse_nth_b()
            return Some({ a: 1, b })
          } else {
            return None
          }
        Number(num, _) => {
          let _ = self.advance()
          return Some({ a: 0, b: num.to_int() })
        }
        _ => return None
      }
    }
    Delim('-') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.peek() {
        Ident(kw) =>
          if kw.to_lower() == "n" {
            let _ = self.advance()
            self.skip_whitespace()
            let b = self.parse_nth_b()
            return Some({ a: -1, b })
          } else {
            return None
          }
        Number(num, _) => {
          let _ = self.advance()
          return Some({ a: 0, b: -num.to_int() })
        }
        _ => return None
      }
    }
    _ => return None
  }
}

///|
fn SelectorParser::parse_nth_b(self : SelectorParser) -> Int {
  match self.peek() {
    Delim('+') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.peek() {
        Number(num, _) => {
          let _ = self.advance()
          num.to_int()
        }
        _ => 0
      }
    }
    Delim('-') => {
      let _ = self.advance()
      self.skip_whitespace()
      match self.peek() {
        Number(num, _) => {
          let _ = self.advance()
          -num.to_int()
        }
        _ => 0
      }
    }
    Number(num, _) => {
      // Number might include sign
      let _ = self.advance()
      num.to_int()
    }
    _ => 0
  }
}

///|
fn SelectorParser::parse_compound_selector_list_until_paren(
  self : SelectorParser,
) -> Array[CompoundSelector] {
  let result : Array[CompoundSelector] = []
  while not(self.is_at_end()) {
    self.skip_whitespace()
    match self.peek() {
      RightParen | EOF => break
      Comma => {
        let _ = self.advance()

      }
      _ =>
        match self.parse_compound_selector() {
          Some(sel) => result.push(sel)
          None => break
        }
    }
  }
  result
}

///|
fn SelectorParser::parse_complex_selector_list_until_paren(
  self : SelectorParser,
) -> Array[ComplexSelector] {
  let result : Array[ComplexSelector] = []
  while not(self.is_at_end()) {
    self.skip_whitespace()
    match self.peek() {
      RightParen | EOF => break
      Comma => {
        let _ = self.advance()

      }
      _ =>
        match self.parse_complex_selector() {
          Some(sel) => result.push(sel)
          None => break
        }
    }
  }
  result
}

///|
fn SelectorParser::parse_relative_selector_list_until_paren(
  self : SelectorParser,
) -> Array[RelativeSelector] {
  let result : Array[RelativeSelector] = []
  while not(self.is_at_end()) {
    self.skip_whitespace()
    match self.peek() {
      RightParen | EOF => break
      Comma => {
        let _ = self.advance()

      }
      _ => {
        // Check for optional leading combinator
        let combinator : Combinator? = match self.peek() {
          Delim('>') => {
            let _ = self.advance()
            self.skip_whitespace()
            Some(Child)
          }
          Delim('+') => {
            let _ = self.advance()
            self.skip_whitespace()
            Some(NextSibling)
          }
          Delim('~') => {
            let _ = self.advance()
            self.skip_whitespace()
            Some(SubsequentSibling)
          }
          _ => None
        }
        match self.parse_complex_selector() {
          Some(sel) => result.push({ combinator, selector: sel })
          None => break
        }
      }
    }
  }
  result
}

///|
/// Convenience function to parse a selector from CSS text
pub fn parse_selector_text(css : String) -> ComplexSelector? {
  let tokens = @token.tokenize(css)
  parse_selector(tokens)
}

///|
/// Convenience function to parse a selector list from CSS text
pub fn parse_selector_list_text(css : String) -> SelectorList? {
  let tokens = @token.tokenize(css)
  parse_selector_list(tokens)
}
