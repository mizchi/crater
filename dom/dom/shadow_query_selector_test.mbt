///|
/// Shadow-scoped querySelector (#286): querying inside a shadow root supports
/// compound selectors and combinators, resolves `:host(...)` / `:host-context`
/// through the host, scopes to the shadow tree (never crossing nested shadow
/// roots), and reports invalid input as errors.
test "shadow_query_selector handles compounds, combinators, and :host scoping" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("section")
  let _ = tree.set_attribute(host, "class", "theme")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let box = tree.create_element("div")
  let _ = tree.set_attribute(box, "class", "box")
  let _ = tree.append_child(shadow, box)
  let leaf = tree.create_element("span")
  let _ = tree.set_attribute(leaf, "class", "leaf")
  let _ = tree.append_child(box, leaf)
  let other = tree.create_element("span")
  let _ = tree.append_child(shadow, other)

  // Compound + child combinator resolves the nested leaf.
  match tree.shadow_query_selector(shadow, "div.box > span.leaf") {
    Ok(Some(n)) => inspect(n.to_int() == leaf.to_int(), content="true")
    _ => fail("expected leaf")
  }

  // :host(.theme) anchors a descendant query at the host: both shadow spans match.
  let scoped = tree
    .shadow_query_selector_all(shadow, ":host(.theme) span")
    .unwrap()
  inspect(scoped.length(), content="2")
  inspect(scoped[0].to_int() == leaf.to_int(), content="true")
  inspect(scoped[1].to_int() == other.to_int(), content="true")

  // A non-matching :host argument selects nothing.
  inspect(
    tree
    .shadow_query_selector_all(shadow, ":host(.nope) span")
    .unwrap()
    .length(),
    content="0",
  )

  // A bare :host matches nothing: the host is not a shadow-tree descendant.
  match tree.shadow_query_selector(shadow, ":host") {
    Ok(None) => inspect(true, content="true")
    _ => fail("expected None")
  }
}

///|
/// A shadow-root query stays within its own shadow tree: a nested shadow host's
/// shadow content is never visited.
test "shadow_query_selector does not cross into nested shadow roots" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()
  let inner_host = tree.create_element("div")
  let _ = tree.append_child(shadow, inner_host)
  let inner_shadow = tree.attach_shadow(inner_host, "open").unwrap()
  let deep = tree.create_element("span")
  let _ = tree.set_attribute(deep, "class", "deep")
  let _ = tree.append_child(inner_shadow, deep)

  // .deep lives in the nested shadow tree, so the outer query cannot reach it.
  inspect(
    tree.shadow_query_selector_all(shadow, ".deep").unwrap().length(),
    content="0",
  )
  // Querying the nested shadow root directly finds it.
  match tree.shadow_query_selector(inner_shadow, ".deep") {
    Ok(Some(n)) => inspect(n.to_int() == deep.to_int(), content="true")
    _ => fail("expected deep")
  }
}

///|
/// Invalid input is reported, not silently empty: a non-shadow-root scope and an
/// unparseable selector both error.
test "shadow_query_selector rejects non-shadow-root scope and invalid selector" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let host = tree.create_element("div")
  let _ = tree.append_child(doc, host)
  let shadow = tree.attach_shadow(host, "open").unwrap()

  // Scope must be a shadow root, not an ordinary element.
  match tree.shadow_query_selector_all(host, "div") {
    Err(InvalidOperation(..)) => inspect(true, content="true")
    _ => fail("expected InvalidOperation")
  }
  // Unparseable selector errors rather than matching nothing.
  match tree.shadow_query_selector_all(shadow, "div >") {
    Err(InvalidOperation(..)) => inspect(true, content="true")
    _ => fail("expected InvalidOperation")
  }
}
