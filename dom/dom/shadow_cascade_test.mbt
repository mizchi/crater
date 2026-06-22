///|
/// Read a cascaded property as a plain string for snapshotting (`<none>` when
/// absent), keeping assertions single-line and Option-free.
fn cascaded(values : @cascade.CascadedValues, property : String) -> String {
  match values.get_value(property) {
    Some(value) => value
    None => "<none>"
  }
}

///|
/// Shadow-tree static styling (#285, PR 1): a shadow root's <style> rules are
/// matched against shadow-tree content via matches_shadow_scoped and cascaded
/// through @css.cascade_declarations.
test "shadow_cascaded_values applies :host and inner rules" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.set_attribute(host, "class", "theme")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let style = tree.create_element("style")
  let _ = tree.set_text_content(
    style, ":host { color: red } :host(.theme) { background: blue } .inner { color: green }",
  )
  let _ = tree.append_child(shadow, style)
  let inner = tree.create_element("span")
  let _ = tree.set_attribute(inner, "class", "inner")
  let _ = tree.append_child(shadow, inner)
  let rules = tree.shadow_stylesheet_rules(shadow)

  // Three rules parsed from the single <style>.
  inspect(rules.length(), content="3")

  // The host gets :host and the matching :host(.theme) declarations.
  let host_values = tree.shadow_cascaded_values(host, rules, host)
  inspect(cascaded(host_values, "color"), content="red")
  inspect(cascaded(host_values, "background"), content="blue")

  // The inner node gets .inner but not the :host rules.
  let inner_values = tree.shadow_cascaded_values(host, rules, inner)
  inspect(cascaded(inner_values, "color"), content="green")
  inspect(cascaded(inner_values, "background"), content="<none>")
}

///|
test "shadow_cascaded_values gates :host() on the host and skips bad selectors" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let style = tree.create_element("style")
  // The first selector is malformed and must be skipped, not fatal.
  let _ = tree.set_text_content(
    style, ":::: { color: black } :host(.active) { color: red }",
  )
  let _ = tree.append_child(shadow, style)

  // Host without the gating class: :host(.active) does not apply.
  let rules = tree.shadow_stylesheet_rules(shadow)
  let plain = tree.shadow_cascaded_values(host, rules, host)
  inspect(cascaded(plain, "color"), content="<none>")

  // Host with the class: the rule now applies (bad selector still skipped).
  let _ = tree.set_attribute(host, "class", "active")
  let active = tree.shadow_cascaded_values(host, rules, host)
  inspect(cascaded(active, "color"), content="red")
}

///|
test "shadow_cascaded_values resolves ::slotted against assigned light nodes" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let style = tree.create_element("style")
  let _ = tree.set_text_content(style, "::slotted(.tag) { color: purple }")
  let _ = tree.append_child(shadow, style)
  let slot = tree.create_element("slot")
  let _ = tree.append_child(shadow, slot)

  // A light child assigned to the default slot matches ::slotted(.tag).
  let slotted = tree.create_element("span")
  let _ = tree.set_attribute(slotted, "class", "tag")
  let _ = tree.append_child(host, slotted)
  let rules = tree.shadow_stylesheet_rules(shadow)
  let slotted_values = tree.shadow_cascaded_values(host, rules, slotted)
  inspect(cascaded(slotted_values, "color"), content="purple")

  // A light child without the class is slotted but does not match the compound.
  let other = tree.create_element("section")
  let _ = tree.append_child(host, other)
  let other_values = tree.shadow_cascaded_values(host, rules, other)
  inspect(cascaded(other_values, "color"), content="<none>")
}

///|
test "shadow_cascaded_values resolves specificity and source order" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let style = tree.create_element("style")
  // Same specificity, later wins; higher specificity (#id) always wins.
  let _ = tree.set_text_content(
    style, ".box { color: red } .box { color: blue } #b { color: green }",
  )
  let _ = tree.append_child(shadow, style)
  let box = tree.create_element("p")
  let _ = tree.set_attribute(box, "class", "box")
  let _ = tree.set_attribute(box, "id", "b")
  let _ = tree.append_child(shadow, box)
  let rules = tree.shadow_stylesheet_rules(shadow)
  let values = tree.shadow_cascaded_values(host, rules, box)
  inspect(cascaded(values, "color"), content="green")
}
