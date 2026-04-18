///|
/// Computed style diff API for forced pseudo-class states.
/// Compares normal vs forced-state styles for a target element.

///|
pub struct StylePropertyDiff {
  property : String
  normal : String
  forced : String
} derive(Eq, Debug)

///|
pub struct ComputedStylesWithStateResult {
  normal : Map[String, String]
  forced : Map[String, String]
  diff : Array[StylePropertyDiff]
} derive(Debug)

///|
pub struct CssRuleUsage {
  selector : String
  matched : Bool
  elements : Int
  overridden : Bool
  overridden_by : String?
  no_effect : Bool
  no_effect_reason : String?
} derive(Eq, Debug)

///|
pub impl Show for StylePropertyDiff with output(self, logger) {
  logger.write_string("{property: ")
  logger.write_string(self.property.to_string())
  logger.write_string(", normal: ")
  logger.write_string(self.normal.to_string())
  logger.write_string(", forced: ")
  logger.write_string(self.forced.to_string())
  logger.write_string("}")
}

///|
pub impl Show for ComputedStylesWithStateResult with output(self, logger) {
  logger.write_string("{normal: ")
  logger.write_string(self.normal.to_string())
  logger.write_string(", forced: ")
  logger.write_string(self.forced.to_string())
  logger.write_string(", diff: ")
  logger.write_string(self.diff.to_string())
  logger.write_string("}")
}

///|
pub impl Show for CssRuleUsage with output(self, logger) {
  logger.write_string("{selector: ")
  logger.write_string(self.selector.to_string())
  logger.write_string(", matched: ")
  logger.write_string(self.matched.to_string())
  logger.write_string(", elements: ")
  logger.write_string(self.elements.to_string())
  logger.write_string(", overridden: ")
  logger.write_string(self.overridden.to_string())
  logger.write_string(", overridden_by: ")
  match self.overridden_by {
    Some(value) => logger.write_string(value.to_string())
    None => logger.write_string("None")
  }
  logger.write_string(", no_effect: ")
  logger.write_string(self.no_effect.to_string())
  logger.write_string(", no_effect_reason: ")
  match self.no_effect_reason {
    Some(value) => logger.write_string(value.to_string())
    None => logger.write_string("None")
  }
  logger.write_string("}")
}

///|
/// Discover computed style differences when forcing pseudo-class states
/// on elements matching a CSS selector.
///
/// - `html`: HTML document string
/// - `target_selector`: CSS selector to identify the target element (e.g. ".btn")
/// - `forced_states`: which pseudo-class states to force (hover, focus, etc.)
/// - `properties`: which CSS properties to compare (empty = all properties)
pub fn discover_computed_styles_with_state(
  html : String,
  target_selector : String,
  forced_states : @selector.ForcedPseudoStates,
  properties : Array[String],
) -> ComputedStylesWithStateResult {
  let doc = @html.parse_document(html)
  let stylesheets = parse_document_stylesheets(doc)
  // Find the target element in the DOM
  let target_sel = @selector.parse_selector_text(target_selector)
  let elements = collect_matching_elements(doc, target_sel)
  let normal_values : Map[String, String] = {}
  let forced_values : Map[String, String] = {}
  let diff : Array[StylePropertyDiff] = []
  if elements.is_empty() {
    return { normal: normal_values, forced: forced_values, diff }
  }
  let element = elements[0]
  let inline_style = parse_inline_declarations(
    selector_element_attribute_value(element, "style").unwrap_or(""),
  )
  let media_env = Some(@media.MediaEnvironment::new(1280.0, 900.0))
  // Normal cascade (no forced states)
  let normal_cascaded = @cascade.cascade_element_with_media(
    element, stylesheets, inline_style, media_env,
  )
  // Forced cascade (with pseudo-class states)
  let forced_cascaded = @cascade.cascade_element_with_forced_states(
    element, stylesheets, inline_style, media_env, forced_states,
  )
  // Collect properties to compare
  let props_to_check = resolve_properties_to_check_from_cascades(
    normal_cascaded, forced_cascaded, properties,
  )
  for prop in props_to_check {
    let normal_val = normal_cascaded.get_value(prop).unwrap_or("")
    let forced_val = forced_cascaded.get_value(prop).unwrap_or("")
    normal_values.set(prop, normal_val)
    forced_values.set(prop, forced_val)
    if normal_val != forced_val {
      diff.push({ property: prop, normal: normal_val, forced: forced_val })
    }
  }
  { normal: normal_values, forced: forced_values, diff }
}

///|
/// Convenience wrapper that accepts forced state names as strings.
pub fn discover_computed_styles_with_state_names(
  html : String,
  target_selector : String,
  forced_state_names : Array[String],
  properties : Array[String],
) -> ComputedStylesWithStateResult {
  let forced = forced_states_from_names(forced_state_names)
  discover_computed_styles_with_state(html, target_selector, forced, properties)
}

///|
pub fn discover_all_computed_styles(
  html : String,
  properties : Array[String],
) -> Map[String, Map[String, String]] {
  let doc = @html.parse_document(html)
  let stylesheets = parse_document_stylesheets(doc)
  let elements = collect_document_elements(doc)
  let media_env = Some(@media.MediaEnvironment::new(1280.0, 900.0))
  let result : Map[String, Map[String, String]] = {}
  for element in elements {
    result.set(
      selector_element_to_unique_selector(element),
      compute_normal_styles_for_element(
        element, stylesheets, media_env, properties,
      ),
    )
  }
  result
}

///|
/// Discover whether stylesheet rules match any elements and whether they still
/// win the cascade for at least one matched declaration.
pub fn discover_css_rule_usage(html : String) -> Array[CssRuleUsage] {
  let doc = @html.parse_document(html)
  let stylesheets = parse_document_stylesheets(doc)
  let resolved_rules = build_resolved_rule_entries(stylesheets)
  let matched_counts : Map[Int, Int] = {}
  let winning_rules : Map[Int, Bool] = {}
  let visual_effect_rules : Map[Int, Bool] = {}
  let overridden_by : Map[Int, String] = {}
  let no_effect_reason : Map[Int, String] = {}
  let elements = collect_document_elements(doc)
  let media_env = Some(@media.MediaEnvironment::new(1280.0, 900.0))
  let resolved_value_cache : Map[String, String] = {}
  for element in elements {
    let inline_style = parse_inline_declarations(
      selector_element_attribute_value(element, "style").unwrap_or(""),
    )
    let collected = collect_property_candidates_for_element(
      element, resolved_rules, inline_style, media_env,
    )
    for i in collected.matched_rule_indices {
      matched_counts[i] = matched_counts.get(i).unwrap_or(0) + 1
    }
    collected.by_property.each(fn(property, candidates) {
      let (winner, fallback) = select_top_two_property_candidates(candidates)
      match winner {
        Some(winner_candidate) => {
          for candidate in candidates {
            match candidate.rule_index {
              Some(candidate_rule_index) => {
                let candidate_loses = match winner_candidate.rule_index {
                  Some(winner_rule_index) =>
                    candidate_rule_index != winner_rule_index
                  None => true
                }
                if candidate_loses &&
                  !overridden_by.contains(candidate_rule_index) {
                  overridden_by[candidate_rule_index] = winner_candidate.source_label
                }
              }
              None => ()
            }
          }
          match winner_candidate.rule_index {
            Some(rule_index) => {
              winning_rules[rule_index] = true
              let winner_value = resolve_candidate_value_for_element(
                winner_candidate,
                property,
                element.parent,
                resolved_rules,
                media_env,
                resolved_value_cache,
              )
              let (fallback_value, fallback_reason) = match fallback {
                Some(fallback_candidate) =>
                  (
                    resolve_candidate_value_for_element(
                      fallback_candidate,
                      property,
                      element.parent,
                      resolved_rules,
                      media_env,
                      resolved_value_cache,
                    ),
                    Some("same_as_fallback"),
                  )
                None =>
                  (
                    resolve_property_without_local_declaration(
                      property,
                      element.parent,
                      resolved_rules,
                      media_env,
                      resolved_value_cache,
                    ),
                    Some(
                      if @computed.is_inherited(property) {
                        "same_as_inherited"
                      } else {
                        "same_as_initial"
                      },
                    ),
                  )
              }
              if winner_value != fallback_value {
                visual_effect_rules[rule_index] = true
              } else if !visual_effect_rules.get(rule_index).unwrap_or(false) {
                match (no_effect_reason.get(rule_index), fallback_reason) {
                  (None, Some(reason)) => no_effect_reason[rule_index] = reason
                  _ => ()
                }
              }
            }
            None => ()
          }
        }
        None => ()
      }
    })
  }
  let result : Array[CssRuleUsage] = []
  for i, rule in resolved_rules {
    let elements = matched_counts.get(i).unwrap_or(0)
    let matched = elements > 0
    let wins_any = winning_rules.get(i).unwrap_or(false)
    let overridden = matched && !wins_any
    let no_effect = matched &&
      wins_any &&
      !visual_effect_rules.get(i).unwrap_or(false)
    result.push({
      selector: rule.selector_text,
      matched,
      elements,
      overridden,
      overridden_by: if overridden {
        overridden_by.get(i)
      } else {
        None
      },
      no_effect,
      no_effect_reason: if no_effect {
        no_effect_reason.get(i)
      } else {
        None
      },
    })
  }
  result
}

///|
fn collect_property_candidates_for_element(
  element : @selector.Element,
  resolved_rules : Array[ResolvedRuleEntry],
  inline_style : Array[@cascade.Declaration],
  media_env : @media.MediaEnvironment?,
) -> PropertyCandidateCollection {
  let by_property : Map[String, Array[PropertyCandidate]] = {}
  let matched_rule_indices : Array[Int] = []
  for i, rule in resolved_rules {
    if !resolved_rule_matches_element(rule, element, media_env) {
      continue
    }
    matched_rule_indices.push(i)
    for decl in rule.declarations {
      push_property_candidate(by_property, decl.property, {
        rule_index: Some(i),
        source_label: rule.selector_text,
        declaration: decl,
      })
    }
  }
  for decl in inline_style {
    push_property_candidate(by_property, decl.property, {
      rule_index: None,
      source_label: "<inline style>",
      declaration: decl,
    })
  }
  { by_property, matched_rule_indices }
}

///|
fn push_property_candidate(
  by_property : Map[String, Array[PropertyCandidate]],
  property : String,
  candidate : PropertyCandidate,
) -> Unit {
  match by_property.get(property) {
    Some(candidates) => candidates.push(candidate)
    None => by_property[property] = [candidate]
  }
}

///|
fn select_top_two_property_candidates(
  candidates : Array[PropertyCandidate],
) -> (PropertyCandidate?, PropertyCandidate?) {
  let mut first : PropertyCandidate? = None
  let mut second : PropertyCandidate? = None
  for candidate in candidates {
    match first {
      Some(current_first) =>
        if compare_declaration_precedence(
            candidate.declaration,
            current_first.declaration,
          ) >
          0 {
          second = first
          first = Some(candidate)
        } else {
          match second {
            Some(current_second) =>
              if compare_declaration_precedence(
                  candidate.declaration,
                  current_second.declaration,
                ) >
                0 {
                second = Some(candidate)
              }
            None => second = Some(candidate)
          }
        }
      None => first = Some(candidate)
    }
  }
  (first, second)
}

///|
fn resolve_candidate_value_for_element(
  candidate : PropertyCandidate,
  property : String,
  parent : @selector.Element?,
  resolved_rules : Array[ResolvedRuleEntry],
  media_env : @media.MediaEnvironment?,
  resolved_value_cache : Map[String, String],
) -> String {
  resolve_property_value_for_element(
    property,
    candidate.declaration.value,
    parent,
    resolved_rules,
    media_env,
    resolved_value_cache,
  )
}

///|
fn resolve_property_value_for_element(
  property : String,
  value : @cascade.PropertyValue,
  parent : @selector.Element?,
  resolved_rules : Array[ResolvedRuleEntry],
  media_env : @media.MediaEnvironment?,
  resolved_value_cache : Map[String, String],
) -> String {
  match value {
    @cascade.PropertyValue::Value(text) => text
    @cascade.PropertyValue::Inherit =>
      resolve_inherited_value_from_parent(
        property, parent, resolved_rules, media_env, resolved_value_cache,
      )
    @cascade.PropertyValue::Initial => @computed.initial_value(property)
    @cascade.PropertyValue::Unset =>
      if @computed.is_inherited(property) {
        resolve_inherited_value_from_parent(
          property, parent, resolved_rules, media_env, resolved_value_cache,
        )
      } else {
        @computed.initial_value(property)
      }
    @cascade.PropertyValue::Revert | @cascade.PropertyValue::RevertLayer =>
      @computed.initial_value(property)
  }
}

///|
fn resolve_property_without_local_declaration(
  property : String,
  parent : @selector.Element?,
  resolved_rules : Array[ResolvedRuleEntry],
  media_env : @media.MediaEnvironment?,
  resolved_value_cache : Map[String, String],
) -> String {
  if @computed.is_inherited(property) {
    resolve_inherited_value_from_parent(
      property, parent, resolved_rules, media_env, resolved_value_cache,
    )
  } else {
    @computed.initial_value(property)
  }
}

///|
fn resolve_inherited_value_from_parent(
  property : String,
  parent : @selector.Element?,
  resolved_rules : Array[ResolvedRuleEntry],
  media_env : @media.MediaEnvironment?,
  resolved_value_cache : Map[String, String],
) -> String {
  match parent {
    Some(parent_element) =>
      resolve_effective_value_for_element_property(
        parent_element, property, resolved_rules, media_env, resolved_value_cache,
      )
    None => @computed.initial_value(property)
  }
}

///|
fn resolve_effective_value_for_element_property(
  element : @selector.Element,
  property : String,
  resolved_rules : Array[ResolvedRuleEntry],
  media_env : @media.MediaEnvironment?,
  resolved_value_cache : Map[String, String],
) -> String {
  let cache_key = selector_element_to_unique_selector(element) + "::" + property
  match resolved_value_cache.get(cache_key) {
    Some(value) => value
    None => {
      let inline_style = parse_inline_declarations(
        selector_element_attribute_value(element, "style").unwrap_or(""),
      )
      let collected = collect_property_candidates_for_element(
        element, resolved_rules, inline_style, media_env,
      )
      let value = match collected.by_property.get(property) {
        Some(candidates) =>
          match select_top_two_property_candidates(candidates) {
            (Some(winner), _) =>
              resolve_candidate_value_for_element(
                winner,
                property,
                element.parent,
                resolved_rules,
                media_env,
                resolved_value_cache,
              )
            _ =>
              resolve_property_without_local_declaration(
                property,
                element.parent,
                resolved_rules,
                media_env,
                resolved_value_cache,
              )
          }
        None =>
          resolve_property_without_local_declaration(
            property,
            element.parent,
            resolved_rules,
            media_env,
            resolved_value_cache,
          )
      }
      resolved_value_cache[cache_key] = value
      value
    }
  }
}

///|
fn compare_declaration_precedence(
  lhs : @cascade.Declaration,
  rhs : @cascade.Declaration,
) -> Int {
  let lhs_rank = cascade_precedence_rank(lhs.origin, lhs.importance)
  let rhs_rank = cascade_precedence_rank(rhs.origin, rhs.importance)
  if lhs_rank != rhs_rank {
    return lhs_rank - rhs_rank
  }
  let specificity_cmp = lhs.specificity.compare_to(rhs.specificity)
  if specificity_cmp != 0 {
    return specificity_cmp
  }
  lhs.source_order - rhs.source_order
}

///|
fn cascade_precedence_rank(
  origin : @cascade.Origin,
  importance : @cascade.Importance,
) -> Int {
  match (origin, importance) {
    (@cascade.Origin::UserAgent, @cascade.Importance::Normal) => 1
    (@cascade.Origin::User, @cascade.Importance::Normal) => 2
    (@cascade.Origin::Author, @cascade.Importance::Normal) => 3
    (@cascade.Origin::Author, @cascade.Importance::Important) => 4
    (@cascade.Origin::User, @cascade.Importance::Important) => 5
    (@cascade.Origin::UserAgent, @cascade.Importance::Important) => 6
  }
}

///|
/// Discover the winning selector source for each cascaded property on each
/// element. Keys are unique element selectors and values are property ->
/// selector text (or `<inline style>`).
pub fn discover_css_effective_property_sources(
  html : String,
) -> Map[String, Map[String, String]] {
  let doc = @html.parse_document(html)
  let stylesheets = parse_document_stylesheets(doc)
  let resolved_rules = build_resolved_rule_entries(stylesheets)
  let source_lookup = build_resolved_rule_source_lookup(resolved_rules)
  let elements = collect_document_elements(doc)
  let media_env = Some(@media.MediaEnvironment::new(1280.0, 900.0))
  let result : Map[String, Map[String, String]] = {}
  for element in elements {
    let inline_style = parse_inline_declarations(
      selector_element_attribute_value(element, "style").unwrap_or(""),
    )
    let cascaded = @cascade.cascade_element_with_media(
      element, stylesheets, inline_style, media_env,
    )
    let sources : Map[String, String] = {}
    cascaded.each(fn(property, declaration) {
      match declaration_source_label(declaration, source_lookup) {
        Some(label) => sources[property] = label
        None => ()
      }
    })
    if !sources.is_empty() {
      result[selector_element_to_unique_selector(element)] = sources
    }
  }
  result
}

///|
fn forced_states_from_names(
  names : Array[String],
) -> @selector.ForcedPseudoStates {
  let mut hover = false
  let mut focus = false
  let mut active = false
  let mut focus_visible = false
  let mut focus_within = false
  for name in names {
    match name {
      "hover" => hover = true
      "focus" => focus = true
      "active" => active = true
      "focus-visible" => focus_visible = true
      "focus-within" => focus_within = true
      _ => ()
    }
  }
  { hover, focus, active, focus_visible, focus_within }
}

///|
fn parse_document_stylesheets(
  doc : @html.Document,
) -> Array[@cascade.Stylesheet] {
  let stylesheets : Array[@cascade.Stylesheet] = []
  for css_text in doc.stylesheets {
    stylesheets.push(@parser.parse_stylesheet(css_text))
  }
  stylesheets
}

///|
fn compute_normal_styles_for_element(
  element : @selector.Element,
  stylesheets : Array[@cascade.Stylesheet],
  media_env : @media.MediaEnvironment?,
  properties : Array[String],
) -> Map[String, String] {
  let inline_style = parse_inline_declarations(
    selector_element_attribute_value(element, "style").unwrap_or(""),
  )
  let cascaded = @cascade.cascade_element_with_media(
    element, stylesheets, inline_style, media_env,
  )
  let props_to_check = resolve_properties_to_check_from_cascaded(
    cascaded, properties,
  )
  let styles : Map[String, String] = {}
  for prop in props_to_check {
    styles.set(prop, cascaded.get_value(prop).unwrap_or(""))
  }
  styles
}

///|
fn resolve_properties_to_check_from_cascades(
  normal_cascaded : @cascade.CascadedValues,
  forced_cascaded : @cascade.CascadedValues,
  properties : Array[String],
) -> Array[String] {
  if !properties.is_empty() {
    return properties
  }
  let all_props : Map[String, Bool] = {}
  normal_cascaded.each(fn(prop, _) { all_props.set(prop, true) })
  forced_cascaded.each(fn(prop, _) { all_props.set(prop, true) })
  let props : Array[String] = []
  all_props.each(fn(prop, _) { props.push(prop) })
  props
}

///|
fn resolve_properties_to_check_from_cascaded(
  cascaded : @cascade.CascadedValues,
  properties : Array[String],
) -> Array[String] {
  if !properties.is_empty() {
    return properties
  }
  let props : Array[String] = []
  cascaded.each(fn(prop, _) { props.push(prop) })
  props
}

///|
/// Collect elements from the document that match the given selector.
fn collect_matching_elements(
  doc : @html.Document,
  selector : @selector.ComplexSelector?,
) -> Array[@selector.Element] {
  let results : Array[@selector.Element] = []
  match selector {
    None => results
    Some(sel) => {
      collect_matching_from_element(doc.root, sel, None, results)
      results
    }
  }
}

///|
fn collect_document_elements(doc : @html.Document) -> Array[@selector.Element] {
  let results : Array[@selector.Element] = []
  collect_document_elements_from_element(doc.root, None, 1, 1, results)
  results
}

///|
fn collect_document_elements_from_element(
  el : @html.Element,
  parent : @selector.Element?,
  sibling_index : Int,
  sibling_count : Int,
  results : Array[@selector.Element],
) -> Unit {
  let sel_element = {
    ..html_element_to_selector_element(el, parent),
    sibling_index,
    sibling_count,
  }
  results.push(sel_element)
  let element_children : Array[@html.Element] = []
  for child in el.children {
    match child {
      @html.Node::Element(child_el) => element_children.push(child_el)
      _ => ()
    }
  }
  let child_count = element_children.length()
  for i, child_el in element_children {
    collect_document_elements_from_element(
      child_el,
      Some(sel_element),
      i + 1,
      child_count,
      results,
    )
  }
}

///|
fn collect_matching_from_element(
  el : @html.Element,
  selector : @selector.ComplexSelector,
  parent : @selector.Element?,
  results : Array[@selector.Element],
) -> Unit {
  let sel_element = html_element_to_selector_element(el, parent)
  if @selector.matches_complex(sel_element, selector) {
    results.push(sel_element)
  }
  for i, child in el.children {
    match child {
      @html.Node::Element(child_el) => {
        let child_sel = {
          ..html_element_to_selector_element(child_el, Some(sel_element)),
          sibling_index: i + 1,
          sibling_count: el.children.length(),
        }
        if @selector.matches_complex(child_sel, selector) {
          results.push(child_sel)
        }
        collect_matching_from_element(
          child_el,
          selector,
          Some(sel_element),
          results,
        )
      }
      _ => ()
    }
  }
}

///|
fn selector_element_to_unique_selector(el : @selector.Element) -> String {
  let reversed_segments : Array[String] = []
  let mut current : @selector.Element? = Some(el)
  let mut keep_running = true
  while keep_running {
    match current {
      Some(element) => {
        reversed_segments.push(
          selector_element_to_unique_selector_segment(element),
        )
        current = match element.id {
          Some(id) if !id.is_empty() => None
          _ => element.parent
        }
      }
      None => keep_running = false
    }
  }
  let segments : Array[String] = []
  let mut idx = reversed_segments.length()
  while idx > 0 {
    idx = idx - 1
    segments.push(reversed_segments[idx])
  }
  segments.join(" > ")
}

///|
fn selector_element_to_unique_selector_segment(
  el : @selector.Element,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(el.tag_name.to_lower())
  match el.id {
    Some(id) if !id.is_empty() => {
      buf.write_string("#")
      buf.write_string(id)
      return buf.to_string()
    }
    _ => ()
  }
  for cls in el.classes {
    if !cls.is_empty() {
      buf.write_string(".")
      buf.write_string(cls)
    }
  }
  if el.sibling_count > 1 {
    buf.write_string(":nth-child(")
    buf.write_string(el.sibling_index.to_string())
    buf.write_string(")")
  }
  buf.to_string()
}

///|
fn html_element_to_selector_element(
  el : @html.Element,
  parent : @selector.Element?,
) -> @selector.Element {
  let classes = el.classes.copy()
  let id = el.id
  let attributes : Array[@selector.Attribute] = []
  el.attributes.each(fn(name, value) {
    attributes.push(@selector.Attribute::{ name, value })
  })
  {
    tag_name: el.tag,
    id,
    classes,
    attributes,
    parent,
    prev_sibling: None,
    next_sibling: None,
    children: [],
    sibling_index: 1,
    sibling_count: 1,
  }
}

///|
fn selector_element_attribute_value(
  el : @selector.Element,
  name : String,
) -> String? {
  for attr in el.attributes {
    if attr.name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
fn parse_inline_declarations(
  inline_css : String,
) -> Array[@cascade.Declaration] {
  let declarations : Array[@cascade.Declaration] = []
  let pairs = inline_css.split(";")
  let mut order = 0
  for pair in pairs {
    let pair_str = pair.to_string().trim().to_string()
    if pair_str.is_empty() {
      continue
    }
    let mut colon_pos = -1
    for i in 0..<pair_str.length() {
      if pair_str[i].to_int().unsafe_to_char() == ':' {
        colon_pos = i
        break
      }
    }
    if colon_pos <= 0 {
      continue
    }
    let property = pair_str.unsafe_substring(start=0, end=colon_pos).trim()
    let raw_value = pair_str
      .unsafe_substring(start=colon_pos + 1, end=pair_str.length())
      .trim()
      .to_string()
    if property.is_empty() || raw_value.is_empty() {
      continue
    }
    let (value, importance) = if raw_value.has_suffix("!important") {
      (
        raw_value[:raw_value.length() - "!important".length()]
        .to_string()
        .trim()
        .to_string(),
        @cascade.Importance::Important,
      )
    } else {
      (raw_value.to_string(), @cascade.Importance::Normal)
    }
    declarations.push(
      @cascade.Declaration::with_metadata(
        property.to_string(),
        @cascade.PropertyValue::Value(value),
        @cascade.Origin::Author,
        importance,
        { a: 1000, b: 0, c: 0 },
        order,
      ),
    )
    order += 1
  }
  declarations
}

///|
priv struct ResolvedRuleEntry {
  selector_text : String
  selector : @selector.ComplexSelector
  declarations : Array[@cascade.Declaration]
  media_query : @media.MediaQueryList?
}

///|
priv struct PropertyCandidate {
  rule_index : Int?
  source_label : String
  declaration : @cascade.Declaration
}

///|
priv struct PropertyCandidateCollection {
  by_property : Map[String, Array[PropertyCandidate]]
  matched_rule_indices : Array[Int]
}

///|
fn build_resolved_rule_entries(
  stylesheets : Array[@cascade.Stylesheet],
) -> Array[ResolvedRuleEntry] {
  let result : Array[ResolvedRuleEntry] = []
  let mut source_order_offset = 0
  for stylesheet in stylesheets {
    let mut max_source_order_in_sheet = source_order_offset - 1
    for rule in stylesheet.rules {
      let specificity = @selector.complex_specificity(rule.selector)
      let declarations : Array[@cascade.Declaration] = []
      for decl in rule.declarations {
        let adjusted_source_order = source_order_offset +
          rule.source_order * 10000 +
          decl.source_order
        if adjusted_source_order > max_source_order_in_sheet {
          max_source_order_in_sheet = adjusted_source_order
        }
        declarations.push({
          property: decl.property,
          value: decl.value,
          origin: stylesheet.origin,
          importance: decl.importance,
          specificity,
          source_order: adjusted_source_order,
        })
      }
      result.push({
        selector_text: rule.selector_text,
        selector: rule.selector,
        declarations,
        media_query: rule.media_query,
      })
    }
    if max_source_order_in_sheet >= source_order_offset {
      source_order_offset = max_source_order_in_sheet + 1
    }
  }
  result
}

///|
fn build_resolved_rule_source_lookup(
  rules : Array[ResolvedRuleEntry],
) -> Map[Int, String] {
  let lookup : Map[Int, String] = {}
  for rule in rules {
    for decl in rule.declarations {
      lookup[decl.source_order] = rule.selector_text
    }
  }
  lookup
}

///|
fn resolved_rule_matches_element(
  rule : ResolvedRuleEntry,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
) -> Bool {
  let media_matches = match (rule.media_query, media_env) {
    (Some(mq), Some(env)) => mq.evaluate(env)
    (Some(_), None) => true
    (None, _) => true
  }
  media_matches && @selector.matches_complex(element, rule.selector)
}

///|
fn origins_are_equal(lhs : @cascade.Origin, rhs : @cascade.Origin) -> Bool {
  match (lhs, rhs) {
    (@cascade.Origin::UserAgent, @cascade.Origin::UserAgent) => true
    (@cascade.Origin::User, @cascade.Origin::User) => true
    (@cascade.Origin::Author, @cascade.Origin::Author) => true
    _ => false
  }
}

///|
fn declaration_source_label(
  declaration : @cascade.Declaration,
  source_lookup : Map[Int, String],
) -> String? {
  if declaration_is_inline_source(declaration) {
    return Some("<inline style>")
  }
  source_lookup.get(declaration.source_order)
}

///|
fn declaration_is_inline_source(declaration : @cascade.Declaration) -> Bool {
  origins_are_equal(declaration.origin, @cascade.Origin::Author) &&
  declaration.specificity.a == 1000 &&
  declaration.specificity.b == 0 &&
  declaration.specificity.c == 0
}
