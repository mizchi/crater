///|
/// CDP DOM Domain Tests
///
/// Tests for DOM domain operations.
/// Pattern inspired by lightpanda-browser dom.zig tests.

///|
test "DOM.getDocument returns root node" {
  let ctx = TestContext::new()
  let dom = ctx.dom()
  let result = dom.get_document(Some(1))
  inspect(result.is_ok(), content="true")
  let doc = result.unwrap()
  inspect(doc.node_type, content="9") // Document type
  inspect(doc.node_name, content="#DOCUMENT")
}

///|
test "DOM.getDocument with depth" {
  let ctx = TestContext::with_html("<p>hello</p>")
  let dom = ctx.dom()
  // Depth 0 - just root
  let result0 = dom.get_document(Some(0))
  inspect(result0.is_ok(), content="true")
  // Depth 3 - includes children
  let result3 = dom.get_document(Some(3))
  inspect(result3.is_ok(), content="true")
  let doc = result3.unwrap()
  inspect(doc.children.is_empty(), content="false")
}

///|
test "DOM.querySelector finds element by tag" {
  let ctx = TestContext::with_html("<p>1</p><p>2</p>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let result = dom.query_selector(doc_id, "p")
  inspect(result.is_ok(), content="true")
  inspect(result.unwrap().is_empty(), content="false")
}

///|
test "DOM.querySelector finds element by id" {
  let ctx = TestContext::with_html("<div id=\"foo\">content</div>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let result = dom.query_selector(doc_id, "#foo")
  inspect(result.is_ok(), content="true")
  inspect(result.unwrap().is_empty(), content="false")
}

///|
test "DOM.querySelector finds element by class" {
  let ctx = TestContext::with_html("<div class=\"bar\">content</div>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let result = dom.query_selector(doc_id, ".bar")
  inspect(result.is_ok(), content="true")
  inspect(result.unwrap().is_empty(), content="false")
}

///|
test "DOM.querySelector returns None for no match" {
  let ctx = TestContext::with_html("<p>text</p>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let result = dom.query_selector(doc_id, "#nonexistent")
  inspect(result.is_ok(), content="true")
  inspect(result.unwrap().is_empty(), content="true")
}

///|
test "DOM.querySelectorAll finds all elements" {
  let ctx = TestContext::with_html("<p>1</p><p>2</p><p>3</p>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let result = dom.query_selector_all(doc_id, "p")
  inspect(result.is_ok(), content="true")
  inspect(result.unwrap().length(), content="3")
}

///|
test "DOM.querySelectorAll returns empty for no match" {
  let ctx = TestContext::with_html("<p>text</p>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let result = dom.query_selector_all(doc_id, "div")
  inspect(result.is_ok(), content="true")
  inspect(result.unwrap().length(), content="0")
}

///|
test "DOM.getAttributes returns element attributes" {
  let ctx = TestContext::with_html(
    "<div id=\"test\" class=\"foo bar\">content</div>",
  )
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  // Find the div
  let div_result = dom.query_selector(doc_id, "#test")
  let div_id = div_result.unwrap().unwrap()
  // Get attributes
  let attrs = dom.get_attributes(div_id)
  inspect(attrs.is_ok(), content="true")
  let attr_list = attrs.unwrap()
  // CDP returns [name, value, name, value, ...]
  inspect(attr_list.length() >= 4, content="true") // at least id and class
}

///|
test "DOM.setAttributeValue sets attribute" {
  let ctx = TestContext::with_html("<div id=\"test\">content</div>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let div_result = dom.query_selector(doc_id, "#test")
  let div_id = div_result.unwrap().unwrap()
  // Set new attribute
  let result = dom.set_attribute_value(div_id, "data-value", "123")
  inspect(result.is_ok(), content="true")
  // Verify attribute was set
  let tree = ctx.tree()
  let attr = tree.get_attribute(@dom.NodeId::from_int(div_id), "data-value")
  inspect(attr.unwrap(), content="Some(\"123\")")
}

///|
test "DOM.removeAttribute removes attribute" {
  let ctx = TestContext::with_html(
    "<div id=\"test\" data-remove=\"yes\">content</div>",
  )
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let div_result = dom.query_selector(doc_id, "#test")
  let div_id = div_result.unwrap().unwrap()
  // Remove attribute
  let result = dom.remove_attribute(div_id, "data-remove")
  inspect(result.is_ok(), content="true")
  // Verify attribute was removed
  let tree = ctx.tree()
  let attr = tree.get_attribute(@dom.NodeId::from_int(div_id), "data-remove")
  inspect(attr.unwrap(), content="None")
}

///|
test "DOM.getBoxModel returns box model" {
  let ctx = TestContext::with_html("<div id=\"box\">content</div>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let div_result = dom.query_selector(doc_id, "#box")
  let div_id = div_result.unwrap().unwrap()
  // Get box model (no layout computed, returns zeros)
  let result = dom.get_box_model(div_id)
  inspect(result.is_ok(), content="true")
  let box = result.unwrap()
  inspect(box.width, content="0")
  inspect(box.height, content="0")
}

///|
test "DOM.getBoxModel with cached rect" {
  let ctx = TestContext::with_html("<div id=\"box\">content</div>")
  let dom = ctx.dom()
  let tree = ctx.tree()
  let doc_id = ctx.doc_id()
  let div_result = dom.query_selector(doc_id, "#box")
  let div_id = div_result.unwrap().unwrap()
  // Set cached rect (simulating layout)
  tree.set_cached_rect(
    @dom.NodeId::from_int(div_id),
    @dom.Rect::new(10.0, 20.0, 100.0, 50.0),
  )
  // Get box model
  let result = dom.get_box_model(div_id)
  inspect(result.is_ok(), content="true")
  let box = result.unwrap()
  inspect(box.width, content="100")
  inspect(box.height, content="50")
}

///|
test "DOM.getOuterHTML returns HTML string" {
  let ctx = TestContext::with_html("<div id=\"test\">hello</div>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let div_result = dom.query_selector(doc_id, "#test")
  let div_id = div_result.unwrap().unwrap()
  let result = dom.get_outer_html(div_id)
  inspect(result.is_ok(), content="true")
  let html = result.unwrap()
  inspect(html.contains("div"), content="true")
  inspect(html.contains("hello"), content="true")
}

///|
test "DOM.setNodeValue sets text content" {
  let ctx = TestContext::with_html("<p id=\"text\">old</p>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let p_result = dom.query_selector(doc_id, "#text")
  let p_id = p_result.unwrap().unwrap()
  // Set new content
  let result = dom.set_node_value(p_id, "new content")
  inspect(result.is_ok(), content="true")
  // Verify content changed
  let tree = ctx.tree()
  let text = tree.get_text_content(@dom.NodeId::from_int(p_id))
  inspect(text.unwrap(), content="new content")
}

///|
test "DOM.removeNode removes element from tree" {
  let ctx = TestContext::with_html("<div><p id=\"remove\">delete me</p></div>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let p_result = dom.query_selector(doc_id, "#remove")
  let p_id = p_result.unwrap().unwrap()
  // Remove node
  let result = dom.remove_node(p_id)
  inspect(result.is_ok(), content="true")
  // Verify node is no longer findable
  let check = dom.query_selector(doc_id, "#remove")
  inspect(check.unwrap().is_empty(), content="true")
}

///|
test "DOM.requestChildNodes returns children" {
  let ctx = TestContext::with_html("<div><p>1</p><p>2</p></div>")
  let dom = ctx.dom()
  let doc_id = ctx.doc_id()
  let div_result = dom.query_selector(doc_id, "div")
  let div_id = div_result.unwrap().unwrap()
  // Request children
  let result = dom.request_child_nodes(div_id, Some(1))
  inspect(result.is_ok(), content="true")
  let children = result.unwrap()
  inspect(children.length(), content="2")
}

///|
test "DOM operations on invalid node return error" {
  let ctx = TestContext::new()
  let dom = ctx.dom()
  // Try to get attributes of non-existent node
  let result = dom.get_attributes(99999)
  inspect(result.is_err(), content="true")
}
