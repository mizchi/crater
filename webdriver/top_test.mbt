///|
test "webdriver-bidi facade parses api method names" {
  inspect(parse_method("newContext"), content="Some(NewContext)")
  inspect(
    parse_method("Page.navigate"),
    content="Some(Goto(page_id=\"\", url=\"\"))",
  )
}

///|
test "webdriver-bidi facade handles cdp session queries" {
  let session = @cdp.CdpSession::new("test-session")
  let tree = session.get_tree()
  let doc = tree.get_document()
  let html = tree.create_element("html")
  let body = tree.create_element("body")
  let button = tree.create_element("button")
  let _ = tree.append_child(doc, html)
  let _ = tree.append_child(html, body)
  let _ = tree.append_child(body, button)
  let _ = tree.set_attribute(button, "id", "save")
  session.set_title("Facade Title")

  let found = handle_find_element(session, "id", "save")

  inspect(found is Ok(_), content="true")
  inspect(handle_get_title(session), content="Facade Title")
}
