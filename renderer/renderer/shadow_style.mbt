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

///|
/// Compute `@style.Style` for the shadow host and every element in its shadow
/// tree, keyed by node id (`NodeId::to_int`). The host is styled by its `:host`
/// rules and inherits from `host_parent_style` (its light-DOM context); each
/// shadow node inherits from its parent's computed style, threading inheritance
/// across the shadow boundary (host -> top-level shadow nodes -> descendants).
///
/// `<style>` elements and non-element nodes are skipped. Returns an empty map
/// when `host` has no shadow root. Slotted light nodes are styled from the light
/// tree, not here.
pub fn compute_shadow_tree_styles(
  tree : @dom.DomTree,
  host : @dom.NodeId,
  ctx : RenderContext,
  host_parent_style : @style.Style?,
) -> Map[Int, @style.Style] {
  let styles : Map[Int, @style.Style] = {}
  let shadow_root = match tree.get_shadow_root(host) {
    Ok(Some(root)) => root
    _ => return styles
  }
  let rules = tree.shadow_stylesheet_rules(shadow_root)
  let host_style = compute_shadow_element_style(
    tree, host, rules, host, ctx, host_parent_style,
  )
  styles[host.to_int()] = host_style
  style_shadow_subtree(tree, host, rules, shadow_root, host_style, ctx, styles)
  styles
}

///|
/// Recursively style the element children of `parent_node`, each inheriting
/// from `parent_style`, accumulating into `styles`.
fn style_shadow_subtree(
  tree : @dom.DomTree,
  host : @dom.NodeId,
  rules : Array[@css.CSSRule],
  parent_node : @dom.NodeId,
  parent_style : @style.Style,
  ctx : RenderContext,
  styles : Map[Int, @style.Style],
) -> Unit {
  let children = match tree.get_children(parent_node) {
    Ok(children) => children
    Err(_) => return
  }
  for child in children {
    let tag = match tree.get_tag_name(child) {
      Ok(tag) => tag.to_lower()
      Err(_) => ""
    }
    if tag == "style" {
      continue
    }
    guard tree.node_to_selector_element(child) is Some(_) else { continue }
    let child_style = compute_shadow_element_style(
      tree,
      host,
      rules,
      child,
      ctx,
      Some(parent_style),
    )
    styles[child.to_int()] = child_style
    style_shadow_subtree(tree, host, rules, child, child_style, ctx, styles)
  }
}

///|
/// Compute the shadow-scoped `@style.Style` contribution for the host's slotted
/// light children, keyed by node id. A light child assigned to a slot in the
/// host's shadow tree is matched against that shadow's `::slotted(...)` rules
/// (via `compute_shadow_element_style`, PR 3) and inherits from `host_style`
/// (its light-DOM parent context).
///
/// Only element light children that are actually assigned to a slot are
/// included; non-slotted children and non-elements are skipped. This is the
/// shadow-side contribution only — a slotted node's document/light styles come
/// from the light tree and are merged by the (deferred) composed-tree walk.
/// Returns an empty map when `host` has no shadow root.
pub fn compute_slotted_styles(
  tree : @dom.DomTree,
  host : @dom.NodeId,
  ctx : RenderContext,
  host_style : @style.Style?,
) -> Map[Int, @style.Style] {
  let styles : Map[Int, @style.Style] = {}
  let shadow_root = match tree.get_shadow_root(host) {
    Ok(Some(root)) => root
    _ => return styles
  }
  let rules = tree.shadow_stylesheet_rules(shadow_root)
  let light_children = match tree.get_children(host) {
    Ok(children) => children
    Err(_) => return styles
  }
  for child in light_children {
    guard tree.node_to_selector_element(child) is Some(_) else { continue }
    guard tree.assigned_slot(child) is Some(_) else { continue }
    let child_style = compute_shadow_element_style(
      tree, host, rules, child, ctx, host_style,
    )
    styles[child.to_int()] = child_style
  }
  styles
}
