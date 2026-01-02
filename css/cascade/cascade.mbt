///|
/// CSS Cascade Algorithm
/// Resolves multiple declarations into final cascaded values

///|
/// Cascaded values for an element
/// Maps property names to their winning declaration
pub struct CascadedValues {
  /// Map from property name to winning declaration
  values : Map[String, Declaration]
}

///|
pub fn CascadedValues::new() -> CascadedValues {
  { values: {} }
}

///|
/// Get the cascaded value for a property
pub fn CascadedValues::get(
  self : CascadedValues,
  property : String,
) -> Declaration? {
  self.values.get(property)
}

///|
/// Get the raw value string for a property
pub fn CascadedValues::get_value(
  self : CascadedValues,
  property : String,
) -> String? {
  match self.values.get(property) {
    Some(decl) =>
      match decl.value {
        Value(v) => Some(v)
        _ => None
      }
    None => None
  }
}

///|
/// Check if a property has a cascaded value
pub fn CascadedValues::has(self : CascadedValues, property : String) -> Bool {
  self.values.contains(property)
}

///|
/// Get all property names that have cascaded values
pub fn CascadedValues::properties(self : CascadedValues) -> Array[String] {
  let result : Array[String] = []
  self.values.each(fn(k, _v) { result.push(k) })
  result
}

///|
/// Cascade a list of declarations into final values
/// Declarations should be for a single element
pub fn cascade(declarations : Array[Declaration]) -> CascadedValues {
  let result = CascadedValues::new()

  // Group declarations by property
  let by_property : Map[String, Array[Declaration]] = {}
  for decl in declarations {
    match by_property.get(decl.property) {
      Some(arr) => arr.push(decl)
      None => by_property.set(decl.property, [decl])
    }
  }

  // For each property, find the winning declaration
  by_property.each(fn(property, decls) {
    let winner = find_winning_declaration(decls)
    match winner {
      Some(decl) => result.values.set(property, decl)
      None => ()
    }
  })
  result
}

///|
/// Find the winning declaration from a list of declarations for the same property
fn find_winning_declaration(declarations : Array[Declaration]) -> Declaration? {
  if declarations.is_empty() {
    return None
  }
  let mut winner = declarations[0]
  for i = 1; i < declarations.length(); i = i + 1 {
    let decl = declarations[i]
    if compare_declarations(decl, winner) > 0 {
      winner = decl
    }
  }
  Some(winner)
}

///|
/// Collect declarations from matching rules for an element
/// This is a helper to build the input for cascade()
pub(all) struct RuleMatch {
  /// The matched selector's specificity
  specificity : @selector.Specificity
  /// Declarations from the rule
  declarations : Array[Declaration]
  /// Source order of the rule
  source_order : Int
}

///|
/// Build declarations from matched rules
pub fn collect_declarations(
  matches : Array[RuleMatch],
  inline_style : Array[Declaration],
) -> Array[Declaration] {
  let result : Array[Declaration] = []

  // Add declarations from matched rules
  for rule_match in matches {
    for decl in rule_match.declarations {
      // Update specificity from the rule, keep declaration's source_order
      // (which combines rule order and declaration order for proper cascade)
      let updated : Declaration = {
        property: decl.property,
        value: decl.value,
        origin: decl.origin,
        importance: decl.importance,
        specificity: rule_match.specificity,
        source_order: decl.source_order,
      }
      result.push(updated)
    }
  }

  // Add inline style declarations (highest specificity)
  for decl in inline_style {
    // Inline styles have implicit specificity (1,0,0,0)
    // We use a very high specificity to ensure they win
    let updated : Declaration = {
      property: decl.property,
      value: decl.value,
      origin: Author,
      importance: decl.importance,
      // Inline styles beat any selector specificity
      specificity: { a: 1000, b: 0, c: 0 },
      source_order: decl.source_order,
    }
    result.push(updated)
  }
  result
}

///|
/// A CSS rule: selector + declarations
pub struct CSSRule {
  /// Selector text (for debugging)
  selector_text : String
  /// Parsed selector
  selector : @selector.ComplexSelector
  /// Declarations in this rule
  declarations : Array[Declaration]
  /// Source order
  source_order : Int
}

///|
/// A stylesheet: collection of rules
pub struct Stylesheet {
  /// Rules in source order
  rules : Array[CSSRule]
  /// Origin of this stylesheet
  origin : Origin
}

///|
pub fn Stylesheet::new(origin : Origin) -> Stylesheet {
  { rules: [], origin }
}

///|
/// Add a rule to the stylesheet
pub fn Stylesheet::add_rule(
  self : Stylesheet,
  selector_text : String,
  selector : @selector.ComplexSelector,
  declarations : Array[Declaration],
) -> Unit {
  let source_order = self.rules.length()
  let rule : CSSRule = { selector_text, selector, declarations, source_order }
  self.rules.push(rule)
}

///|
/// Match all rules against an element and return matched rules
pub fn Stylesheet::match_element(
  self : Stylesheet,
  element : @selector.Element,
) -> Array[RuleMatch] {
  let matches : Array[RuleMatch] = []
  for rule in self.rules {
    if @selector.matches_complex(element, rule.selector) {
      let specificity = @selector.complex_specificity(rule.selector)
      // Update declarations with stylesheet origin
      // Combine rule source_order with declaration source_order to preserve
      // declaration order within rules (important for vendor prefix fallbacks like
      // "display: -webkit-flex; display: flex;")
      let decls : Array[Declaration] = []
      for decl in rule.declarations {
        decls.push({
          property: decl.property,
          value: decl.value,
          origin: self.origin,
          importance: decl.importance,
          specificity,
          source_order: rule.source_order * 10000 + decl.source_order,
        })
      }
      matches.push({
        specificity,
        declarations: decls,
        source_order: rule.source_order,
      })
    }
  }
  matches
}

///|
/// Cascade styles for an element from multiple stylesheets
pub fn cascade_element(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
) -> CascadedValues {
  let all_matches : Array[RuleMatch] = []

  // Collect matches from all stylesheets
  for stylesheet in stylesheets {
    let matches = stylesheet.match_element(element)
    for m in matches {
      all_matches.push(m)
    }
  }

  // Collect all declarations
  let declarations = collect_declarations(all_matches, inline_style)

  // Cascade
  cascade(declarations)
}
