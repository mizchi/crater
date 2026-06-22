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
