///|
/// Shadow-tree static styling (#285, PR 3): a shadow root's <style> rules
/// produce a concrete @style.Style for shadow-tree nodes through the same
/// post-cascade pipeline the document path uses.
test "compute_shadow_element_style applies :host and inner rules to Style" {
  let tree = @dom.DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let style = tree.create_element("style")
  let _ = tree.set_text_content(
    style, ":host { display: flex } .inner { width: 50px }",
  )
  let _ = tree.append_child(shadow, style)
  let inner = tree.create_element("span")
  let _ = tree.set_attribute(inner, "class", "inner")
  let _ = tree.append_child(shadow, inner)
  let rules = tree.shadow_stylesheet_rules(shadow)
  let ctx = RenderContext::default()

  // :host { display: flex } reaches the host's computed Style.
  let host_style = compute_shadow_element_style(
    tree,
    host,
    rules,
    host,
    ctx,
    None,
  )
  inspect(host_style.display, content="Flex")

  // .inner { width: 50px } reaches the inner node; :host does not.
  let inner_style = compute_shadow_element_style(
    tree,
    host,
    rules,
    inner,
    ctx,
    None,
  )
  inspect(
    inner_style.width,
    content=(
      #|Length(50)
    ),
  )
  inspect(
    inner_style.display,
    content=(
      #|Inline
    ),
  )
}

///|
test "compute_shadow_tree_styles threads inheritance across the boundary" {
  let tree = @dom.DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let style = tree.create_element("style")
  // color on :host should inherit into shadow descendants; font-size set on the
  // wrapper inherits into its child.
  let _ = tree.set_text_content(
    style, ":host { color: rgb(10, 20, 30) } .wrap { font-size: 20px }",
  )
  let _ = tree.append_child(shadow, style)
  let wrap = tree.create_element("div")
  let _ = tree.set_attribute(wrap, "class", "wrap")
  let _ = tree.append_child(shadow, wrap)
  let leaf = tree.create_element("span")
  let _ = tree.append_child(wrap, leaf)
  let styles = compute_shadow_tree_styles(
    tree,
    host,
    RenderContext::default(),
    None,
  )

  // Host, wrapper, and leaf are all styled.
  inspect(styles.size(), content="3")

  // font-size: 20px on .wrap inherits into its leaf child.
  let wrap_style = styles.get(wrap.to_int()).unwrap()
  let leaf_style = styles.get(leaf.to_int()).unwrap()
  inspect(wrap_style.font_size, content="20")
  inspect(leaf_style.font_size, content="20")

  // :host color inherits across the boundary down to the leaf.
  let host_style = styles.get(host.to_int()).unwrap()
  inspect(host_style.color == leaf_style.color, content="true")
}
