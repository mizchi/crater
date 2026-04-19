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
/// Iterate cascaded declarations without allocating an intermediate key array.
pub fn CascadedValues::each(
  self : CascadedValues,
  f : (String, Declaration) -> Unit,
) -> Unit {
  self.values.each(f)
}

///|
/// Cascade a list of declarations into final values
/// Declarations should be for a single element
pub fn cascade(declarations : Array[Declaration]) -> CascadedValues {
  let result = CascadedValues::new()
  for decl in declarations {
    accumulate_cascaded_declaration(result, decl)
  }
  result
}

///|
fn accumulate_cascaded_declaration(
  result : CascadedValues,
  decl : Declaration,
) -> Unit {
  match result.values.get(decl.property) {
    Some(current) =>
      if compare_declarations(decl, current) > 0 {
        result.values.set(decl.property, decl)
      }
    None => result.values.set(decl.property, decl)
  }
}

///|
fn accumulate_inline_declaration(
  result : CascadedValues,
  decl : Declaration,
) -> Unit {
  accumulate_cascaded_declaration(result, {
    property: decl.property,
    value: decl.value,
    origin: Author,
    importance: decl.importance,
    specificity: { a: 1000, b: 0, c: 0 },
    source_order: decl.source_order,
  })
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
  /// Media query (if this rule is inside @media)
  media_query : @media.MediaQueryList?
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
  let rule : CSSRule = {
    selector_text,
    selector,
    declarations,
    source_order,
    media_query: None,
  }
  self.rules.push(rule)
}

///|
/// Add a rule with a media query to the stylesheet
pub fn Stylesheet::add_rule_with_media(
  self : Stylesheet,
  selector_text : String,
  selector : @selector.ComplexSelector,
  declarations : Array[Declaration],
  media_query : @media.MediaQueryList,
) -> Unit {
  let source_order = self.rules.length()
  let rule : CSSRule = {
    selector_text,
    selector,
    declarations,
    source_order,
    media_query: Some(media_query),
  }
  self.rules.push(rule)
}

///|
/// Match all rules against an element and return matched rules
pub fn Stylesheet::match_element(
  self : Stylesheet,
  element : @selector.Element,
) -> Array[RuleMatch] {
  self.match_element_with_media(element, None)
}

///|
/// Match all rules against an element with media query evaluation
pub fn Stylesheet::match_element_with_media(
  self : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
) -> Array[RuleMatch] {
  let matches : Array[RuleMatch] = []
  for rule in self.rules {
    // Check media query if present and environment provided
    let media_matches = match (rule.media_query, media_env) {
      (Some(mq), Some(env)) => mq.evaluate(env)
      (Some(_), None) => true // No env = match all media queries
      (None, _) => true // No media query = always matches
    }
    if !media_matches {
      continue
    }
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
fn cascade_stylesheet_matches_into(
  result : CascadedValues,
  stylesheet : Stylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
  source_order_offset : Int,
) -> Int {
  let mut max_source_order_in_sheet = source_order_offset - 1
  for rule in stylesheet.rules {
    let media_matches = match (rule.media_query, media_env) {
      (Some(mq), Some(env)) => mq.evaluate(env)
      (Some(_), None) => true
      (None, _) => true
    }
    if !media_matches {
      continue
    }
    if @selector.matches_complex(element, rule.selector) {
      let specificity = @selector.complex_specificity(rule.selector)
      for decl in rule.declarations {
        let adjusted_source_order = source_order_offset +
          rule.source_order * 10000 +
          decl.source_order
        if adjusted_source_order > max_source_order_in_sheet {
          max_source_order_in_sheet = adjusted_source_order
        }
        accumulate_cascaded_declaration(result, {
          property: decl.property,
          value: decl.value,
          origin: stylesheet.origin,
          importance: decl.importance,
          specificity,
          source_order: adjusted_source_order,
        })
      }
    }
  }
  max_source_order_in_sheet
}

///|
/// Cascade styles for an element from multiple stylesheets
pub fn cascade_element(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
) -> CascadedValues {
  cascade_element_with_media(element, stylesheets, inline_style, None)
}

///|
/// Cascade styles for an element with media query evaluation
pub fn cascade_element_with_media(
  element : @selector.Element,
  stylesheets : Array[Stylesheet],
  inline_style : Array[Declaration],
  media_env : @media.MediaEnvironment?,
) -> CascadedValues {
  let result = CascadedValues::new()
  let mut source_order_offset = 0

  // Collect matches from all stylesheets
  for stylesheet in stylesheets {
    let max_source_order_in_sheet = cascade_stylesheet_matches_into(
      result, stylesheet, element, media_env, source_order_offset,
    )
    if max_source_order_in_sheet >= source_order_offset {
      source_order_offset = max_source_order_in_sheet + 1
    }
  }

  for decl in inline_style {
    accumulate_inline_declaration(result, decl)
  }
  result
}
