// =============================================================================
// Selector Index for Fast CSS Matching
// =============================================================================
// Indexes rules by their rightmost selector (head) for O(1) candidate lookup

///|
/// Index for fast rule lookup
/// Rules are indexed by the rightmost compound selector's:
/// - ID selectors
/// - Class selectors
/// - Tag name
/// - Universal selectors (matched against all elements)
pub(all) struct SelectorIndex {
  /// Rules indexed by ID (rightmost ID in head)
  by_id : Map[String, Array[Int]]
  /// Rules indexed by class (rightmost class in head)
  by_class : Map[String, Array[Int]]
  /// Rules indexed by tag name (rightmost type in head)
  by_tag : Map[String, Array[Int]]
  /// Rules with universal selector (*) or no specific key
  universal : Array[Int]
}

///|
pub fn SelectorIndex::new() -> SelectorIndex {
  { by_id: {}, by_class: {}, by_tag: {}, universal: [] }
}

///|
/// Extract indexing key from a CompoundSelector's head
/// Returns (id, classes, tag) where any can be None/empty
fn extract_index_keys(
  selector : @selector.CompoundSelector,
) -> (String?, Array[String], String?) {
  let mut id : String? = None
  let classes : Array[String] = []
  let mut tag : String? = None
  // Check type selector
  match selector.type_selector {
    Some(@selector.Type(name)) => tag = Some(name.to_lower())
    Some(@selector.Universal) => () // Universal doesn't narrow down
    Some(_) => () // Other selector types (shouldn't be in type_selector position)
    None => ()
  }
  // Check subclasses
  for sub in selector.subclasses {
    match sub {
      @selector.Id(name) => if id is None { id = Some(name) }
      @selector.Class(name) => classes.push(name)
      _ => ()
    }
  }
  (id, classes, tag)
}

///|
/// Build index for a stylesheet
pub fn SelectorIndex::from_stylesheet(stylesheet : Stylesheet) -> SelectorIndex {
  let index = SelectorIndex::new()
  for i, rule in stylesheet.rules {
    // Extract keys from the head (rightmost compound selector)
    let (id, classes, tag) = extract_index_keys(rule.selector.head)
    // Index by the most specific key (ID > class > tag > universal)
    // We add to ALL matching indices for better recall
    let mut indexed = false
    // Add to ID index if present
    match id {
      Some(id_val) => {
        match index.by_id.get(id_val) {
          Some(arr) => arr.push(i)
          None => index.by_id.set(id_val, [i])
        }
        indexed = true
      }
      None => ()
    }
    // Add to class indices
    for cls in classes {
      match index.by_class.get(cls) {
        Some(arr) => arr.push(i)
        None => index.by_class.set(cls, [i])
      }
      indexed = true
    }
    // Add to tag index
    match tag {
      Some(tag_val) => {
        match index.by_tag.get(tag_val) {
          Some(arr) => arr.push(i)
          None => index.by_tag.set(tag_val, [i])
        }
        indexed = true
      }
      None => ()
    }
    // If no specific key, add to universal
    if not(indexed) {
      index.universal.push(i)
    }
  }
  index
}

///|
/// Get candidate rule indices for an element
/// Returns indices of rules that might match (need full selector check)
pub fn SelectorIndex::get_candidates(
  self : SelectorIndex,
  element : @selector.Element,
) -> Array[Int] {
  // Use a set to avoid duplicates
  let seen : Map[Int, Bool] = {}
  let candidates : Array[Int] = []
  // Check ID index
  match element.id {
    Some(id) =>
      match self.by_id.get(id) {
        Some(arr) =>
          for i in arr {
            if not(seen.contains(i)) {
              seen.set(i, true)
              candidates.push(i)
            }
          }
        None => ()
      }
    None => ()
  }
  // Check class indices
  for cls in element.classes {
    match self.by_class.get(cls) {
      Some(arr) =>
        for i in arr {
          if not(seen.contains(i)) {
            seen.set(i, true)
            candidates.push(i)
          }
        }
      None => ()
    }
  }
  // Check tag index
  let tag = element.tag_name.to_lower()
  match self.by_tag.get(tag) {
    Some(arr) =>
      for i in arr {
        if not(seen.contains(i)) {
          seen.set(i, true)
          candidates.push(i)
        }
      }
    None => ()
  }
  // Always include universal rules
  for i in self.universal {
    if not(seen.contains(i)) {
      seen.set(i, true)
      candidates.push(i)
    }
  }
  candidates
}

///|
/// Indexed stylesheet for fast matching
pub struct IndexedStylesheet {
  /// The underlying stylesheet
  stylesheet : Stylesheet
  /// Selector index for fast lookup
  index : SelectorIndex
}

///|
pub fn IndexedStylesheet::new(stylesheet : Stylesheet) -> IndexedStylesheet {
  let index = SelectorIndex::from_stylesheet(stylesheet)
  { stylesheet, index }
}

///|
/// Match all rules against an element using the index
pub fn IndexedStylesheet::match_element(
  self : IndexedStylesheet,
  element : @selector.Element,
) -> Array[RuleMatch] {
  self.match_element_with_media(element, None)
}

///|
/// Match all rules against an element with media query evaluation using the index
pub fn IndexedStylesheet::match_element_with_media(
  self : IndexedStylesheet,
  element : @selector.Element,
  media_env : @media.MediaEnvironment?,
) -> Array[RuleMatch] {
  let matches : Array[RuleMatch] = []
  // Get candidate rule indices from index
  let candidates = self.index.get_candidates(element)
  // Only check candidate rules (not all rules)
  for rule_idx in candidates {
    let rule = self.stylesheet.rules[rule_idx]
    // Check media query if present
    let media_matches = match (rule.media_query, media_env) {
      (Some(mq), Some(env)) => mq.evaluate(env)
      (Some(_), None) => true
      (None, _) => true
    }
    if not(media_matches) {
      continue
    }
    // Full selector match
    if @selector.matches_complex(element, rule.selector) {
      let specificity = @selector.complex_specificity(rule.selector)
      let decls : Array[Declaration] = []
      for decl in rule.declarations {
        decls.push({
          property: decl.property,
          value: decl.value,
          origin: self.stylesheet.origin,
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
/// Cascade styles using indexed stylesheets for better performance
pub fn cascade_element_indexed(
  element : @selector.Element,
  stylesheets : Array[IndexedStylesheet],
  inline_style : Array[Declaration],
  media_env : @media.MediaEnvironment?,
) -> CascadedValues {
  let all_matches : Array[RuleMatch] = []
  for stylesheet in stylesheets {
    let matches = stylesheet.match_element_with_media(element, media_env)
    for m in matches {
      all_matches.push(m)
    }
  }
  let declarations = collect_declarations(all_matches, inline_style)
  cascade(declarations)
}
