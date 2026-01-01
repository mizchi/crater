///|
/// Specificity calculation for CSS selectors

///|
/// Calculate specificity of a simple selector
pub fn simple_specificity(sel : SimpleSelector) -> Specificity {
  match sel {
    Type(_) => { a: 0, b: 0, c: 1 }
    Universal => Specificity::zero()
    Id(_) => { a: 1, b: 0, c: 0 }
    Class(_) => { a: 0, b: 1, c: 0 }
    Attribute(_) => { a: 0, b: 1, c: 0 }
    PseudoClass(pc) => pseudo_class_specificity(pc)
    PseudoElement(_) => { a: 0, b: 0, c: 1 }
  }
}

///|
/// Calculate specificity of a pseudo-class
fn pseudo_class_specificity(pc : PseudoClass) -> Specificity {
  match pc {
    // :where() has zero specificity
    Where(_) => Specificity::zero()
    // :not() and :is() take the most specific argument
    Not(selectors) => {
      let mut max = Specificity::zero()
      for sel in selectors {
        let spec = compound_specificity(sel)
        if spec.compare_to(max) > 0 {
          max = spec
        }
      }
      max
    }
    Is(selectors) => {
      let mut max = Specificity::zero()
      for sel in selectors {
        let spec = complex_specificity(sel)
        if spec.compare_to(max) > 0 {
          max = spec
        }
      }
      max
    }
    Has(selectors) => {
      let mut max = Specificity::zero()
      for rel in selectors {
        let spec = complex_specificity(rel.selector)
        if spec.compare_to(max) > 0 {
          max = spec
        }
      }
      max
    }
    // All other pseudo-classes count as one class selector
    _ => { a: 0, b: 1, c: 0 }
  }
}

///|
/// Calculate specificity of a compound selector
pub fn compound_specificity(sel : CompoundSelector) -> Specificity {
  let mut result = Specificity::zero()

  // Add type selector specificity
  match sel.type_selector {
    Some(type_sel) => result = result.add(simple_specificity(type_sel))
    None => ()
  }

  // Add subclass specificity
  for sub in sel.subclasses {
    result = result.add(simple_specificity(sub))
  }

  result
}

///|
/// Calculate specificity of a complex selector
pub fn complex_specificity(sel : ComplexSelector) -> Specificity {
  let mut result = compound_specificity(sel.head)

  for step in sel.tail {
    result = result.add(compound_specificity(step.selector))
  }

  result
}

///|
/// Calculate specificity of a selector list (returns max)
pub fn selector_list_specificity(list : SelectorList) -> Specificity {
  let mut max = Specificity::zero()
  for sel in list.selectors {
    let spec = complex_specificity(sel)
    if spec.compare_to(max) > 0 {
      max = spec
    }
  }
  max
}
