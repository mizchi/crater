///|
/// Shadow-tree static styling (#285, PR 3).
///
/// Compute a concrete `@style.Style` for a node that lives inside a shadow tree
/// (the host, a slotted light node, or an inner shadow node) by running that
/// shadow root's `<style>` rules through `DomTree::shadow_cascaded_values`
/// (PR 1, shadow-scoped matching) and folding the result through the renderer's
/// shared post-cascade pipeline `apply_cascaded_to_style` (PR 2).
///
/// `rules` is the shadow root's parsed stylesheet, obtained once via
/// `DomTree::shadow_stylesheet_rules`, so a caller styling many nodes does not
/// re-parse `<style>` per node. `parent_style` carries inherited context across
/// the shadow boundary (the host's style for top-level shadow nodes).
///
/// This is a building block; the composed-tree render entry (PR 4) walks the
/// DomTree and calls it for shadow-scoped nodes.
pub fn compute_shadow_element_style(
  tree : @dom.DomTree,
  host : @dom.NodeId,
  rules : Array[@css.CSSRule],
  target : @dom.NodeId,
  ctx : RenderContext,
  parent_style : @style.Style?,
) -> @style.Style {
  let selector_elem = match tree.node_to_selector_element(target) {
    Some(elem) => elem
    None => @css.Element::new("span")
  }
  let cascaded = Some(tree.shadow_cascaded_values(host, rules, target))
  let css_vars : Map[String, String] = {}
  apply_cascaded_to_style(
    cascaded,
    selector_elem,
    None,
    false,
    ctx,
    parent_style,
    css_vars,
  )
}
