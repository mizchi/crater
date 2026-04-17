///|
test "DomTree tracks shadow roots separately from light DOM" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let host = tree.create_element("div")
  let _ = tree.set_attribute(host, "id", "host")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let inner = tree.create_element("span")
  let _ = tree.set_attribute(inner, "class", "inside")
  let _ = tree.append_child(shadow, inner)

  match tree.get_node_info(shadow) {
    Ok(info) => inspect(info.node_type, content="ShadowRoot")
    Err(err) => fail("\{err}")
  }
  match tree.get_shadow_root(host) {
    Ok(Some(root)) => inspect(root.to_int(), content="4")
    Ok(None) => fail("expected shadow root")
    Err(err) => fail("\{err}")
  }
  match tree.get_host(shadow) {
    Ok(Some(actual_host)) => inspect(actual_host.to_int(), content="3")
    Ok(None) => fail("expected host")
    Err(err) => fail("\{err}")
  }
  match tree.get_parent(shadow) {
    Ok(parent) => inspect(parent == None, content="true")
    Err(err) => fail("\{err}")
  }
  match tree.get_root_node(inner, composed=false) {
    Ok(root) => inspect(root.to_int(), content="4")
    Err(err) => fail("\{err}")
  }
  match tree.get_root_node(inner, composed=true) {
    Ok(root) => inspect(root.to_int(), content="0")
    Err(err) => fail("\{err}")
  }
  match tree.query_selector(doc, ".inside") {
    Ok(result) => inspect(result == None, content="true")
    Err(err) => fail("\{err}")
  }
  match tree.query_selector(shadow, ".inside") {
    Ok(Some(node)) => inspect(node.to_int(), content="5")
    Ok(None) => fail("expected shadow child")
    Err(err) => fail("\{err}")
  }
}

///|
test "DomTree get_composed_children uses shadow tree and slot assignment" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let host = tree.create_element("div")
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let wrapper = tree.create_element("section")
  let default_slot = tree.create_element("slot")
  let named_slot = tree.create_element("slot")
  let plain = tree.create_element("span")
  let plain_text = tree.create_text("plain")
  let named = tree.create_element("em")
  let named_text = tree.create_text("named")

  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, host)
  let _ = tree.append_child(shadow, wrapper)
  let _ = tree.append_child(wrapper, default_slot)
  let _ = tree.set_attribute(named_slot, "name", "label")
  let _ = tree.append_child(wrapper, named_slot)
  let _ = tree.append_child(plain, plain_text)
  let _ = tree.append_child(host, plain)
  let _ = tree.append_child(named, named_text)
  let _ = tree.set_attribute(named, "slot", "label")
  let _ = tree.append_child(host, named)

  let host_children = tree.get_composed_children(host)
  inspect(host_children.length(), content="1")
  inspect(host_children[0].to_int(), content="5")

  let default_children = tree.get_composed_children(
    default_slot,
    shadow_host=Some(host),
  )
  inspect(default_children.length(), content="1")
  inspect(default_children[0].to_int(), content="8")

  let named_children = tree.get_composed_children(
    named_slot,
    shadow_host=Some(host),
  )
  inspect(named_children.length(), content="1")
  inspect(named_children[0].to_int(), content="10")
}

///|
test "DomTree get_composed_children falls back through nested slots" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let host = tree.create_element("div")
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let outer = tree.create_element("slot")
  let inner = tree.create_element("slot")
  let fallback = tree.create_element("span")
  let fallback_text = tree.create_text("fallback")

  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, host)
  let _ = tree.append_child(shadow, outer)
  let _ = tree.set_attribute(inner, "name", "inner")
  let _ = tree.append_child(outer, inner)
  let _ = tree.append_child(fallback, fallback_text)
  let _ = tree.append_child(inner, fallback)

  let outer_children = tree.get_composed_children(outer, shadow_host=Some(host))
  inspect(outer_children.length(), content="1")
  inspect(outer_children[0].to_int(), content="6")

  let inner_children = tree.get_composed_children(inner, shadow_host=Some(host))
  inspect(inner_children.length(), content="1")
  inspect(inner_children[0].to_int(), content="7")
}
