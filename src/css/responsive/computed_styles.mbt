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
  let stylesheets : Array[@cascade.Stylesheet] = []
  for css_text in doc.stylesheets {
    stylesheets.push(@parser.parse_stylesheet(css_text))
  }
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
  let media_env = Some(@media.MediaEnvironment::new(1280.0, 900.0))
  // Normal cascade (no forced states)
  let normal_cascaded = @cascade.cascade_element_with_media(
    element,
    stylesheets,
    [],
    media_env,
  )
  // Forced cascade (with pseudo-class states)
  let forced_cascaded = @cascade.cascade_element_with_forced_states(
    element,
    stylesheets,
    [],
    media_env,
    forced_states,
  )
  // Collect properties to compare
  let props_to_check : Array[String] = if properties.is_empty() {
    // Use union of all properties from both cascades
    let all_props : Map[String, Bool] = {}
    normal_cascaded.each(fn(prop, _) { all_props.set(prop, true) })
    forced_cascaded.each(fn(prop, _) { all_props.set(prop, true) })
    let props : Array[String] = []
    all_props.each(fn(prop, _) { props.push(prop) })
    props
  } else {
    properties
  }
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
