///|
/// Composed shadow-scoped styling for a whole DomTree (#285, PR 6).
///
/// Walks the light DOM from the document root and folds together every shadow
/// host's contribution into one `NodeId::to_int`-keyed style map:
///
/// - each host plus its shadow-subtree elements via `compute_shadow_tree_styles`
///   (PR 3), threading inheritance across the boundary;
/// - the host's slotted light children's `::slotted(...)` contribution via
///   `compute_slotted_styles` (PR 5);
/// - nested shadow roots: a host living inside another host's shadow tree (or
///   slotted into one) is composed too, inheriting from its own computed style.
///
/// The returned map covers shadow hosts, shadow-subtree elements, and slotted
/// light nodes. Plain light nodes that are neither hosts nor slotted are absent:
/// the DomTree has no document-scope cascade, so this is the shadow-scoped
/// composition only. It is the capstone over the PR 1-5 building blocks.
pub fn compute_composed_shadow_styles(
  tree : @dom.DomTree,
  ctx : RenderContext,
) -> Map[Int, @style.Style] {
  let styles : Map[Int, @style.Style] = {}
  compose_node(tree, tree.get_document(), ctx, styles)
  styles
}

///|
/// Visit `node` in the light tree: if it is a shadow host, compose it; then
/// recurse into its light children (slotted or not) to reach hosts nested
/// deeper. A host already styled by an ancestor's slotted pass inherits from
/// that style when composing its own shadow tree.
fn compose_node(
  tree : @dom.DomTree,
  node : @dom.NodeId,
  ctx : RenderContext,
  styles : Map[Int, @style.Style],
) -> Unit {
  if tree.get_shadow_root(node) is Ok(Some(_)) {
    compose_host(tree, node, styles.get(node.to_int()), ctx, styles)
  }
  let children = match tree.get_children(node) {
    Ok(children) => children
    Err(_) => return
  }
  for child in children {
    compose_node(tree, child, ctx, styles)
  }
}

///|
/// Compose a single shadow `host`: establish the host's authoritative style,
/// style its shadow-subtree descendants and slotted light children, then descend
/// through its shadow tree to compose any nested hosts.
///
/// A host element belongs to its *outer* scope, so when an outer pass has
/// already styled it (`styles` holds an entry — e.g. a nested host matched by an
/// enclosing shadow tree, or a slotted node) that style stays authoritative and
/// the shadow subtree inherits from it. Only a top-level host with no prior
/// entry is styled here from its own `:host` rules, inheriting from
/// `host_parent_style`. (A nested host's own-shadow `:host` rules are not layered
/// on top of its outer style yet — a known gap for this composition pass.)
fn compose_host(
  tree : @dom.DomTree,
  host : @dom.NodeId,
  host_parent_style : @style.Style?,
  ctx : RenderContext,
  styles : Map[Int, @style.Style],
) -> Unit {
  let shadow_root = match tree.get_shadow_root(host) {
    Ok(Some(root)) => root
    _ => return
  }
  let rules = tree.shadow_stylesheet_rules(shadow_root)
  let host_style = match styles.get(host.to_int()) {
    Some(existing) => existing
    None => {
      let computed = compute_shadow_element_style(
        tree, host, rules, host, ctx, host_parent_style,
      )
      styles[host.to_int()] = computed
      computed
    }
  }
  style_shadow_subtree(tree, host, rules, shadow_root, host_style, ctx, styles)
  for id, style in compute_slotted_styles(tree, host, ctx, Some(host_style)) {
    styles[id] = style
  }
  compose_node(tree, shadow_root, ctx, styles)
}
