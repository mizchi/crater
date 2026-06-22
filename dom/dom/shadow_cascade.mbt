///|
/// Shadow-tree static styling (#285, PR 1).
///
/// A parallel cascade that applies a shadow root's own `<style>` rules to
/// shadow-tree content using `DomTree::matches_shadow_scoped` (the matcher
/// added in #286 for `:host` / `:host()` / `:host-context()` / `::slotted()`).
///
/// This bypasses `@css.cascade_element_indexed` — which cannot resolve the
/// shadow-scoping pseudos — and instead routes each rule's selector through the
/// DOM-aware matcher, then feeds the matched declarations into the shared
/// `@css.cascade_declarations`. The resulting `@cascade.CascadedValues` is the
/// same type the renderer's document path already consumes, so a later slice
/// can merge it into `@style.Style` with no new layout plumbing.
///
/// These functions are pure over the `DomTree`; the renderer is not yet wired
/// to call them.

///|
/// Parse every `<style>` element in the shadow tree rooted at `shadow_root`
/// into a flat list of rules, in document order. Nested elements are descended,
/// but nested shadow roots are not (their styles belong to their own tree).
pub fn DomTree::shadow_stylesheet_rules(
  self : DomTree,
  shadow_root : NodeId,
) -> Array[@cascade.CSSRule] {
  let rules : Array[@cascade.CSSRule] = []
  self.collect_style_rules_into(shadow_root, rules)
  rules
}

///|
fn DomTree::collect_style_rules_into(
  self : DomTree,
  node : NodeId,
  out : Array[@cascade.CSSRule],
) -> Unit {
  let children = match self.get_children(node) {
    Ok(children) => children
    Err(_) => return
  }
  for child in children {
    let tag = match self.get_tag_name(child) {
      Ok(tag) => tag.to_lower()
      Err(_) => ""
    }
    if tag == "style" {
      let css = match self.get_text_content(child) {
        Ok(text) => text
        Err(_) => ""
      }
      for rule in @css.parse_stylesheet(css).rules {
        out.push(rule)
      }
    } else {
      self.collect_style_rules_into(child, out)
    }
  }
}

///|
/// Declarations from `rules` that apply to `target` when the rules are authored
/// inside the shadow tree whose host is `host`, stamped with the matched
/// selector's specificity and document source order so `@css.cascade_declarations`
/// resolves the winner exactly like the document cascade
/// (`@cascade.cascade_rule_into`). A rule whose selector fails to parse or does
/// not match is skipped, so one malformed selector cannot abort styling.
pub fn DomTree::collect_shadow_matched_declarations(
  self : DomTree,
  host : NodeId,
  rules : Array[@cascade.CSSRule],
  target : NodeId,
) -> Array[@cascade.Declaration] {
  let declarations : Array[@cascade.Declaration] = []
  let mut order = 0
  for rule in rules {
    match self.best_shadow_match_specificity(rule.selector_text, target, host) {
      Some(specificity) =>
        for decl in rule.declarations {
          declarations.push(
            @cascade.Declaration::with_metadata(
              decl.property,
              decl.value,
              decl.origin,
              decl.importance,
              specificity,
              order,
            ),
          )
          order = order + 1
        }
      None => ()
    }
  }
  declarations
}

///|
/// The highest specificity among the complex selectors in `selector_text` that
/// match `target` in the shadow tree hosted by `host`, or `None` when none
/// match (or the selector text does not parse).
fn DomTree::best_shadow_match_specificity(
  self : DomTree,
  selector_text : String,
  target : NodeId,
  host : NodeId,
) -> @selector.Specificity? {
  let list = match @selector.parse_selector_list_text(selector_text) {
    Some(list) => list
    None => return None
  }
  let mut best : @selector.Specificity? = None
  for cs in list.selectors {
    if self.complex_matches_scoped(target, cs, host) {
      let specificity = @selector.complex_specificity(cs)
      best = match best {
        Some(current) =>
          if specificity.compare_to(current) > 0 {
            Some(specificity)
          } else {
            Some(current)
          }
        None => Some(specificity)
      }
    }
  }
  best
}

///|
/// Cascade the shadow rules that apply to `target` (host is `host`) into the
/// winning `@cascade.CascadedValues`, resolving specificity / source order via
/// the shared `@css.cascade_declarations`.
pub fn DomTree::shadow_cascaded_values(
  self : DomTree,
  host : NodeId,
  rules : Array[@cascade.CSSRule],
  target : NodeId,
) -> @cascade.CascadedValues {
  @css.cascade_declarations(
    self.collect_shadow_matched_declarations(host, rules, target),
  )
}
