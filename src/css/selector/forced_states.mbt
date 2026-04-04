///|
/// Forced pseudo-class states for interactive state simulation.
/// Used to evaluate CSS rules as if :hover, :focus, :active were active
/// on a target element.

///|
pub(all) struct ForcedPseudoStates {
  hover : Bool
  focus : Bool
  active : Bool
  focus_visible : Bool
  focus_within : Bool
} derive(Eq, Show)

///|
pub fn ForcedPseudoStates::none() -> ForcedPseudoStates {
  {
    hover: false,
    focus: false,
    active: false,
    focus_visible: false,
    focus_within: false,
  }
}

///|
pub fn ForcedPseudoStates::is_empty(self : ForcedPseudoStates) -> Bool {
  !self.hover &&
  !self.focus &&
  !self.active &&
  !self.focus_visible &&
  !self.focus_within
}

///|
/// Check if an element matches a pseudo-class with forced states applied.
pub fn matches_pseudo_class_with_forced_states(
  element : Element,
  pc : PseudoClass,
  forced : ForcedPseudoStates,
) -> Bool {
  match pc {
    Hover => forced.hover
    Active => forced.active
    Focus => forced.focus
    FocusVisible => forced.focus_visible
    FocusWithin => forced.focus_within
    _ => matches_pseudo_class(element, pc)
  }
}

///|
/// Check if an element matches a simple selector with forced pseudo-class states.
fn matches_simple_with_forced_states(
  element : Element,
  selector : SimpleSelector,
  forced : ForcedPseudoStates,
) -> Bool {
  match selector {
    PseudoClass(pc) =>
      matches_pseudo_class_with_forced_states(element, pc, forced)
    _ => matches_simple(element, selector)
  }
}

///|
/// Check if an element matches a compound selector with forced states.
fn matches_compound_with_forced_states(
  element : Element,
  selector : CompoundSelector,
  forced : ForcedPseudoStates,
) -> Bool {
  match selector.type_selector {
    Some(type_sel) =>
      if !matches_simple_with_forced_states(element, type_sel, forced) {
        return false
      }
    None => ()
  }
  for sub in selector.subclasses {
    if !matches_simple_with_forced_states(element, sub, forced) {
      return false
    }
  }
  true
}

///|
/// Check if an element matches a complex selector with forced states.
/// Forced states only apply to the subject element (the head/rightmost selector).
pub fn matches_complex_with_forced_states(
  element : Element,
  selector : ComplexSelector,
  forced : ForcedPseudoStates,
) -> Bool {
  // The forced states apply to the subject (head) element only
  if !matches_compound_with_forced_states(element, selector.head, forced) {
    return false
  }
  if selector.tail.is_empty() {
    return true
  }
  // For ancestor/sibling selectors, use normal (non-forced) matching
  let mut current_element = element
  for step in selector.tail {
    match step.combinator {
      Descendant => {
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
        if !found {
          return false
        }
      }
      Child =>
        match current_element.parent {
          None => return false
          Some(parent) => {
            if !matches_compound(parent, step.selector) {
              return false
            }
            current_element = parent
          }
        }
      NextSibling =>
        match current_element.prev_sibling {
          None => return false
          Some(sibling) => {
            if !matches_compound(sibling, step.selector) {
              return false
            }
            current_element = sibling
          }
        }
      SubsequentSibling => {
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
        if !found {
          return false
        }
      }
    }
  }
  true
}
