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
