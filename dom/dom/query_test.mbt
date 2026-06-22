///|
/// Compound selector support for querySelector / querySelectorAll (#286).
/// Parsing and matching are delegated to `mizchi/css/selector`, so the queried
/// subtree is projected into selector elements and tested against the parsed
/// selector list.
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

  // Selector lists (comma-separated).
  inspect(q("span, input"), content="2,3")

  // Combinators (delegated to the css selector matcher).
  inspect(q("div span"), content="2") // descendant
  inspect(q("div > span"), content="2") // child
  inspect(q("span + input"), content="3") // next-sibling
  inspect(q("span ~ input"), content="3") // subsequent-sibling
  inspect(q("div > input"), content="3")

  // Attribute operators.
  inspect(q("[class~=foo]"), content="2,3")
  inspect(q("[type^=te]"), content="3")

  // Structural pseudo-classes (div and span are each a first child).
  inspect(q(":first-child"), content="1,2")
  inspect(q("input:last-child"), content="3")
  inspect(q("input:nth-child(2)"), content="3")

  // State pseudo-classes have no live state → no match (but parse cleanly).
  inspect(q("span:hover"), content="")

  // An unparseable selector is reported as an error rather than matching.
  match tree.query_selector_all(doc, "::::") {
    Ok(_) => fail("expected invalid selector error")
    Err(InvalidOperation(message=_)) => inspect(true, content="true")
    Err(err) => fail("\{err}")
  }
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
