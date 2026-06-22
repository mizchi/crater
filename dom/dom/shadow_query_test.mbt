///|
/// Shadow-scoped pseudo matching (#286, Step 5): :host / :host() /
/// :host-context() / ::slotted(), plus combinators that cross the shadow-root
/// boundary to the host.
test "matches_shadow_scoped resolves :host and descendants" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let _ = tree.set_attribute(body, "class", "page")
  let host = tree.create_element("div")
  let _ = tree.set_attribute(host, "id", "host")
  let _ = tree.set_attribute(host, "class", "theme-dark")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let inner = tree.create_element("span")
  let _ = tree.set_attribute(inner, "class", "inside")
  let _ = tree.append_child(shadow, inner)

  fn m(node : NodeId, selector : String) -> String {
    match tree.matches_shadow_scoped(node, selector, host) {
      Ok(result) => result.to_string()
      Err(_) => "err"
    }
  }

  // :host matches the host element only.
  inspect(m(host, ":host"), content="true")
  inspect(m(inner, ":host"), content="false")

  // :host(<compound>) tests the host against the argument.
  inspect(m(host, ":host(.theme-dark)"), content="true")
  inspect(m(host, ":host(.theme-light)"), content="false")
  inspect(m(host, ":host(div#host)"), content="true")

  // :host-context(<compound>) matches when the host or a light ancestor matches.
  inspect(m(host, ":host-context(.page)"), content="true")
  inspect(m(host, ":host-context(.missing)"), content="false")

  // Combinators cross the shadow boundary from the shadow tree to the host.
  inspect(m(inner, ":host .inside"), content="true") // descendant
  inspect(m(inner, ":host > .inside"), content="true") // child
  inspect(m(inner, ":host(.theme-dark) .inside"), content="true")
  inspect(m(inner, ":host(.theme-light) .inside"), content="false")
  inspect(m(inner, ".inside"), content="true") // ordinary, no host

  // An unparseable selector is reported as an error.
  match tree.matches_shadow_scoped(host, "::::", host) {
    Ok(_) => fail("expected invalid selector error")
    Err(InvalidOperation(message=_)) => inspect(true, content="true")
    Err(err) => fail("\{err}")
  }
}

///|
test "matches_shadow_scoped resolves ::slotted" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let slot = tree.create_element("slot")
  let _ = tree.append_child(shadow, slot)

  // Light children of the host are distributed to the default slot.
  let light = tree.create_element("p")
  let _ = tree.set_attribute(light, "class", "light")
  let _ = tree.append_child(host, light)
  let other = tree.create_element("section")
  let _ = tree.append_child(host, other)

  fn m(node : NodeId, selector : String) -> String {
    match tree.matches_shadow_scoped(node, selector, host) {
      Ok(result) => result.to_string()
      Err(_) => "err"
    }
  }

  // ::slotted() matches a slotted light node that satisfies the compound.
  inspect(m(light, "::slotted(.light)"), content="true")
  inspect(m(light, "::slotted(p)"), content="true")
  inspect(m(light, "::slotted(.other)"), content="false")
  inspect(m(other, "::slotted(section)"), content="true")

  // A node that is not slotted into this host's shadow tree never matches.
  inspect(m(slot, "::slotted(slot)"), content="false")
}
