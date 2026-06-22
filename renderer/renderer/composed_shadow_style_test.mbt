///|
/// Composed shadow styling (#285, PR 6): one walk over a DomTree folds together
/// host styles, slotted contributions, and nested shadow roots into a single
/// style map. This is the composition the per-host building blocks cannot do
/// alone: `compute_shadow_tree_styles` styles one shadow tree but does not
/// descend into nested shadow roots within it.
test "compute_composed_shadow_styles composes nested shadow and slotted nodes" {
  let tree = @dom.DomTree::new()
  let doc = tree.get_document()

  // Top-level host with an open shadow root.
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow_a = tree.attach_shadow(host, "open").unwrap()
  let style_a = tree.create_element("style")
  let _ = tree.set_text_content(
    style_a, ":host { display: flex } ::slotted(.tag) { width: 3px } .mid { width: 10px }",
  )
  let _ = tree.append_child(shadow_a, style_a)
  let slot = tree.create_element("slot")
  let _ = tree.append_child(shadow_a, slot)

  // A nested host lives inside the top host's shadow tree.
  let inner = tree.create_element("div")
  let _ = tree.set_attribute(inner, "class", "mid")
  let _ = tree.append_child(shadow_a, inner)
  let shadow_b = tree.attach_shadow(inner, "open").unwrap()
  let style_b = tree.create_element("style")
  let _ = tree.set_text_content(style_b, ".deep { width: 7px }")
  let _ = tree.append_child(shadow_b, style_b)
  let deep = tree.create_element("span")
  let _ = tree.set_attribute(deep, "class", "deep")
  let _ = tree.append_child(shadow_b, deep)

  // A light child of the top host, distributed to the default slot.
  let tagged = tree.create_element("span")
  let _ = tree.set_attribute(tagged, "class", "tag")
  let _ = tree.append_child(host, tagged)
  let styles = compute_composed_shadow_styles(tree, RenderContext::default())

  // Host's :host rule reaches its computed style.
  inspect(styles.get(host.to_int()).unwrap().display, content="Flex")

  // .mid in shadow A reaches the nested host element.
  inspect(
    styles.get(inner.to_int()).unwrap().width,
    content=(
      #|Length(10)
    ),
  )

  // The nested shadow root (B) is composed: .deep reaches the deep node, which
  // the per-host building block alone would never visit.
  inspect(
    styles.get(deep.to_int()).unwrap().width,
    content=(
      #|Length(7)
    ),
  )

  // The slotted light child receives its ::slotted(.tag) contribution.
  inspect(
    styles.get(tagged.to_int()).unwrap().width,
    content=(
      #|Length(3)
    ),
  )
}
