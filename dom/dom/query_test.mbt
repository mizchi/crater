///|
/// Compound selector support for querySelector / querySelectorAll (#286).
/// The matcher handles a type/universal selector combined with #id, .class and
/// [attr] simple selectors; combinators and pseudo-classes are intentionally
/// not matched yet.
test "query_selector_all matches compound selectors" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let root = tree.create_element("div")
  let _ = tree.append_child(doc, root)
  let a = tree.create_element("span")
  let _ = tree.set_attribute(a, "class", "foo bar")
  let _ = tree.set_attribute(a, "id", "x")
  let _ = tree.append_child(root, a)
  let b = tree.create_element("input")
  let _ = tree.set_attribute(b, "type", "text")
  let _ = tree.set_attribute(b, "class", "foo")
  let _ = tree.append_child(root, b)

  // Helper: matching node ids in document order, comma-joined.
  fn q(selector : String) -> String {
    match tree.query_selector_all(doc, selector) {
      Ok(nodes) => {
        let parts = nodes.map(fn(n) { n.to_int().to_string() })
        parts.join(",")
      }
      Err(_) => "err"
    }
  }

  // Single simple selectors.
  inspect(q("span"), content="2")
  inspect(q("#x"), content="2")
  inspect(q(".foo"), content="2,3")
  inspect(q(".bar"), content="2")
  inspect(q("[type]"), content="3")
  inspect(q("input[type=text]"), content="3")

  // Compound (all simple selectors must match the same element).
  inspect(q("span.foo"), content="2")
  inspect(q("span.foo.bar"), content="2")
  inspect(q("span.foo#x"), content="2")
  inspect(q("input[type=text].foo"), content="3")
  // A compound that cannot be satisfied by one element.
  inspect(q("input.bar"), content="")

  // Universal matches every element (div, span, input), not the document.
  inspect(q("*"), content="1,2,3")

  // Class matching is whitespace-delimited, not substring.
  inspect(q(".foob"), content="")
  inspect(q(".fo"), content="")

  // Combinators and pseudo-classes are not handled yet → no match (no
  // mis-parse).
  inspect(q("div span"), content="")
  inspect(q("div > span"), content="")
  inspect(q("span:hover"), content="")
}

///|
test "query_selector returns first match in document order" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let root = tree.create_element("ul")
  let _ = tree.append_child(doc, root)
  let li1 = tree.create_element("li")
  let _ = tree.set_attribute(li1, "class", "item")
  let _ = tree.append_child(root, li1)
  let li2 = tree.create_element("li")
  let _ = tree.set_attribute(li2, "class", "item active")
  let _ = tree.append_child(root, li2)

  match tree.query_selector(doc, "li.item") {
    Ok(Some(node)) => inspect(node.to_int() == li1.to_int(), content="true")
    Ok(None) => fail("expected first li")
    Err(err) => fail("\{err}")
  }
  match tree.query_selector(doc, "li.active") {
    Ok(Some(node)) => inspect(node.to_int() == li2.to_int(), content="true")
    Ok(None) => fail("expected active li")
    Err(err) => fail("\{err}")
  }
  match tree.query_selector(doc, "li.missing") {
    Ok(result) => inspect(result is None, content="true")
    Err(err) => fail("\{err}")
  }
}
