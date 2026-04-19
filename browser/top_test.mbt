///|
test "browser facade renders text output" {
  let browser = Browser::new(640, 480)
  let html =
    #|<html>
    #|  <body>
    #|    <main>
    #|      <h1>Hello</h1>
    #|      <p>World</p>
    #|    </main>
    #|  </body>
    #|</html>
  browser.set_html_content(html)

  let rendered = browser.render_output(Text)
  assert_true(rendered.contains("Hello"))
  assert_true(rendered.contains("World"))
}

///|
test "browser facade exposes cdp session and dom serialization" {
  let session = CdpSession::new("test-session")
  session.load_html(
    "<html><body><button id=\"save\">Save</button></body></html>",
  )

  let found = session.query_selector("#save")
  inspect(found is Ok(Some(_)), content="true")
  inspect(
    serialize_dom_to_html(session.get_tree()).contains("button"),
    content="true",
  )
}
