///|
test "Input.dispatchMouseEvent focuses deepest hit element" {
  let ctx = TestContext::with_html(
    "<div id=\"outer\"><input id=\"field\" type=\"text\"></input></div>",
  )
  let dom = ctx.dom()
  let tree = ctx.tree()
  let input = ctx.input()
  let doc_id = ctx.doc_id()
  let outer_id = dom.query_selector(doc_id, "#outer").unwrap().unwrap()
  let field_id = dom.query_selector(doc_id, "#field").unwrap().unwrap()
  tree.set_cached_rect(
    @dom.NodeId::from_int(outer_id),
    @dom.Rect::new(0.0, 0.0, 200.0, 120.0),
  )
  tree.set_cached_rect(
    @dom.NodeId::from_int(field_id),
    @dom.Rect::new(24.0, 16.0, 120.0, 32.0),
  )

  let _ = input.dispatch_mouse_event("mousePressed", 40.0, 24.0, "left", 1)
  let _ = input.dispatch_mouse_event("mouseReleased", 40.0, 24.0, "left", 1)

  match tree.get_focus() {
    Some(node) =>
      inspect(
        tree.get_attribute(node, "id").unwrap(),
        content="Some(\"field\")",
      )
    None => inspect(false, content="focus should be set")
  }
}

///|
test "Input.insertText uses focus from mouse hit testing" {
  let ctx = TestContext::with_html("<input id=\"field\" type=\"text\"></input>")
  let dom = ctx.dom()
  let tree = ctx.tree()
  let input = ctx.input()
  let doc_id = ctx.doc_id()
  let field_id = dom.query_selector(doc_id, "#field").unwrap().unwrap()
  tree.set_cached_rect(
    @dom.NodeId::from_int(field_id),
    @dom.Rect::new(8.0, 8.0, 160.0, 32.0),
  )

  let _ = input.dispatch_mouse_event("mousePressed", 20.0, 20.0, "left", 1)
  let _ = input.dispatch_mouse_event("mouseReleased", 20.0, 20.0, "left", 1)
  let _ = input.insert_text("Hello CDP")

  inspect(
    tree.get_attribute(@dom.NodeId::from_int(field_id), "value").unwrap(),
    content="Some(\"Hello CDP\")",
  )
}
