///|
test "webdriver-bidi facade parses api method names" {
  match parse_method("newContext") {
    Some(ApiMethod::NewContext) => ()
    _ => fail("expected newContext to parse as NewContext")
  }
  match parse_method("Page.navigate") {
    Some(ApiMethod::Goto(page_id~, url~)) => {
      inspect(page_id, content="")
      inspect(url, content="")
    }
    _ => fail("expected Page.navigate to parse as Goto")
  }
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
