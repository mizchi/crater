///|
/// CSS Selector Matcher
/// Determines if an element matches a given selector

///|
/// Check if an element matches a simple selector
pub fn matches_simple(element : Element, selector : SimpleSelector) -> Bool {
  match selector {
    Type(name) => element.tag_name == name
    Universal => true
    Id(id) =>
      match element.id {
        Some(elem_id) => elem_id == id
        None => false
      }
    Class(cls) => element.has_class(cls)
    Attribute(attr_sel) => matches_attribute(element, attr_sel)
    PseudoClass(pc) => matches_pseudo_class(element, pc)
    PseudoElement(_) =>
      // Pseudo-elements don't affect matching in the usual sense
      // They're handled separately during rendering
      true
  }
}

///|
/// Check if an element matches an attribute selector
fn matches_attribute(element : Element, selector : AttributeSelector) -> Bool {
  let attr_value = element.get_attribute(selector.name)
  match selector.match_type {
    Exists =>
      match attr_value {
        Some(_) => true
        None => false
      }
    Exact(value) =>
      match attr_value {
        Some(v) =>
          if selector.case_insensitive {
            v.to_lower() == value.to_lower()
          } else {
            v == value
          }
        None => false
      }
    Includes(value) =>
      match attr_value {
        Some(v) => {
          let parts = split_whitespace(v)
          for part in parts {
            let matches = if selector.case_insensitive {
              part.to_lower() == value.to_lower()
            } else {
              part == value
            }
            if matches {
              return true
            }
          }
          false
        }
        None => false
      }
    DashMatch(value) =>
      match attr_value {
        Some(v) => {
          let (check_val, check_value) = if selector.case_insensitive {
            (v.to_lower(), value.to_lower())
          } else {
            (v, value)
          }
          check_val == check_value || check_val.has_prefix(check_value + "-")
        }
        None => false
      }
    Prefix(value) =>
      match attr_value {
        Some(v) => {
          let (check_val, check_value) = if selector.case_insensitive {
            (v.to_lower(), value.to_lower())
          } else {
            (v, value)
          }
          check_val.has_prefix(check_value)
        }
        None => false
      }
    Suffix(value) =>
      match attr_value {
        Some(v) => {
          let (check_val, check_value) = if selector.case_insensitive {
            (v.to_lower(), value.to_lower())
          } else {
            (v, value)
          }
          check_val.has_suffix(check_value)
        }
        None => false
      }
    Substring(value) =>
      match attr_value {
        Some(v) => {
          let (check_val, check_value) = if selector.case_insensitive {
            (v.to_lower(), value.to_lower())
          } else {
            (v, value)
          }
          check_val.contains(check_value)
        }
        None => false
      }
  }
}

///|
/// Split string by whitespace
fn split_whitespace(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      if current.to_string().length() > 0 {
        result.push(current.to_string())
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    result.push(current.to_string())
  }
  result
}

///|
/// Check if an element matches a pseudo-class
fn matches_pseudo_class(element : Element, pc : PseudoClass) -> Bool {
  match pc {
    FirstChild => element.is_first_child()
    LastChild => element.is_last_child()
    OnlyChild => element.sibling_count == 1
    NthChild(expr) => matches_nth(element.sibling_index, expr)
    NthLastChild(expr) => {
      let from_end = element.sibling_count - element.sibling_index + 1
      matches_nth(from_end, expr)
    }
    FirstOfType =>
      // Would need to check siblings of same type
      // For now, approximate with first-child
      element.is_first_child()
    LastOfType => element.is_last_child()
    OnlyOfType => element.sibling_count == 1
    NthOfType(expr) =>
      // Would need type-specific index
      matches_nth(element.sibling_index, expr)
    NthLastOfType(expr) => {
      let from_end = element.sibling_count - element.sibling_index + 1
      matches_nth(from_end, expr)
    }
    Root =>
      match element.parent {
        None => true
        Some(_) => false
      }
    Empty => element.children.is_empty()
    Not(selectors) => {
      for sel in selectors {
        if matches_compound(element, sel) {
          return false
        }
      }
      true
    }
    Is(selectors) => {
      for sel in selectors {
        if matches_complex(element, sel) {
          return true
        }
      }
      false
    }
    Where(selectors) => {
      for sel in selectors {
        if matches_complex(element, sel) {
          return true
        }
      }
      false
    }
    Has(_) =>
      // :has() requires checking descendants/siblings
      // Complex to implement, return false for now
      false
    // User-action pseudo-classes - these depend on runtime state
    // For static matching, we return false (or could check element state)
    Hover | Active | Focus | FocusVisible | FocusWithin => false
    // Link pseudo-classes
    Link | Visited | AnyLink => element.tag_name == "a"
    // Form pseudo-classes - would need form element state
    Enabled
    | Disabled
    | Checked
    | Indeterminate
    | Required
    | Optional
    | Valid
    | Invalid
    | ReadOnly
    | ReadWrite => false
  }
}

///|
/// Check if index matches An+B expression
fn matches_nth(index : Int, expr : NthExpr) -> Bool {
  if expr.a == 0 {
    // Just check if index == b
    return index == expr.b
  }

  // Check if (index - b) is divisible by a
  let diff = index - expr.b
  if expr.a > 0 {
    // Positive a: diff must be >= 0 and divisible by a
    diff >= 0 && diff % expr.a == 0
  } else {
    // Negative a: diff must be <= 0 and divisible by |a|
    diff <= 0 && diff % expr.a == 0
  }
}

///|
/// Check if an element matches a compound selector
pub fn matches_compound(element : Element, selector : CompoundSelector) -> Bool {
  // Check type selector
  match selector.type_selector {
    Some(type_sel) => if not(matches_simple(element, type_sel)) { return false }
    None => ()
  }

  // Check all subclass selectors
  for sub in selector.subclasses {
    if not(matches_simple(element, sub)) {
      return false
    }
  }
  true
}

///|
/// Check if an element matches a complex selector
pub fn matches_complex(element : Element, selector : ComplexSelector) -> Bool {
  // First, check if the element matches the head (rightmost/subject)
  if not(matches_compound(element, selector.head)) {
    return false
  }

  // If there's no tail, we're done
  if selector.tail.is_empty() {
    return true
  }

  // Walk up the tree following the combinators
  let mut current_element = element
  for step in selector.tail {
    match step.combinator {
      Descendant => {
        // Find any ancestor that matches
        let mut found = false
        let mut ancestor = current_element.parent
        while true {
          match ancestor {
            None => break
            Some(anc) => {
              if matches_compound(anc, step.selector) {
                current_element = anc
                found = true
                break
              }
              ancestor = anc.parent
            }
          }
        }
        if not(found) {
          return false
        }
      }
      Child =>
        // Parent must match
        match current_element.parent {
          None => return false
          Some(parent) => {
            if not(matches_compound(parent, step.selector)) {
              return false
            }
            current_element = parent
          }
        }
      NextSibling =>
        // Previous sibling must match
        match current_element.prev_sibling {
          None => return false
          Some(prev) => {
            if not(matches_compound(prev, step.selector)) {
              return false
            }
            current_element = prev
          }
        }
      SubsequentSibling => {
        // Any previous sibling must match
        let mut found = false
        let mut sibling = current_element.prev_sibling
        while true {
          match sibling {
            None => break
            Some(sib) => {
              if matches_compound(sib, step.selector) {
                current_element = sib
                found = true
                break
              }
              sibling = sib.prev_sibling
            }
          }
        }
        if not(found) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Check if an element matches any selector in a list
pub fn matches_selector_list(element : Element, list : SelectorList) -> Bool {
  for sel in list.selectors {
    if matches_complex(element, sel) {
      return true
    }
  }
  false
}

///|
/// Convenience function to check if an element matches a CSS selector string
pub fn matches_selector_text(element : Element, css : String) -> Bool {
  match parse_selector_text(css) {
    Some(sel) => matches_complex(element, sel)
    None => false
  }
}
