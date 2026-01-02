///|
test "stylesheet flex-direction is applied" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>.row { display: flex; flex-direction: row; gap: 10px; }</style>
    #|<style>.box { width: 50px; height: 50px; }</style>
    #|</head>
    #|<body>
    #|<div class="row">
    #|  <div class="box">A</div>
    #|  <div class="box">B</div>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  // Check that div B has x > 0 (row direction)
  let body = layout
  let row_div = body.children[0]
  inspect(row_div.id, content="div.row")
  if row_div.children.length() >= 2 {
    let div_a = row_div.children[0]
    let div_b = row_div.children[1]
    // In row direction, B should be to the right of A with gap
    // A at x=0, B at x=50+10(gap)=60
    inspect(div_a.x, content="0")
    inspect(div_a.y, content="0")
    inspect(div_b.x, content="60")
    inspect(div_b.y, content="0")
  }
}

///|
test "debug node style from stylesheet" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>.row { display: flex; flex-direction: row; gap: 10px; }</style>
    #|</head>
    #|<body>
    #|<div class="row">
    #|  <div>A</div>
    #|</div>
    #|</body></html>

  // Parse the document
  let doc = @html.parse_document(html)
  let stylesheets : Array[@cascade.Stylesheet] = []
  for css in doc.stylesheets {
    let stylesheet = @parser.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }

  // Find body, then div.row
  fn find_body(elem : @html.Element) -> @html.Element? {
    if elem.tag == "body" {
      return Some(elem)
    }
    for child in elem.children {
      match child {
        @html.Node::Element(child_elem) =>
          match find_body(child_elem) {
            Some(body) => return Some(body)
            None => ()
          }
        _ => ()
      }
    }
    None
  }

  let body = find_body(doc.root)
  inspect(body is Some(_), content="true")
  match body {
    Some(body_elem) =>
      // Find div.row
      for child in body_elem.children {
        match child {
          @html.Node::Element(row_elem) =>
            if row_elem.classes.length() > 0 && row_elem.classes[0] == "row" {
              // Create selector element
              let sel_elem = @selector.Element::new("div").add_class("row")

              // Match against stylesheet
              let cascaded = @cascade.cascade_element(sel_elem, stylesheets, [])
              inspect(
                cascaded.get_value("display"),
                content=(
                  #|Some("flex")
                ),
              )
              inspect(
                cascaded.get_value("flex-direction"),
                content=(
                  #|Some("row")
                ),
              )
            }
          _ => ()
        }
      }
    None => ()
  }
}

///|
test "debug stylesheet cascading" {
  let css = ".row { display: flex; flex-direction: row; gap: 10px; }"
  let stylesheet = @parser.parse_stylesheet(css)

  // Create element that matches .row
  let elem = @selector.Element::new("div").add_class("row")

  // Match stylesheet
  let matches = stylesheet.match_element(elem)
  inspect(matches.length() > 0, content="true")
  if matches.length() > 0 {
    let m = matches[0]
    // Check what declarations were matched
    let props : Array[String] = []
    for decl in m.declarations {
      match decl.value {
        @cascade.Value(v) => props.push(decl.property + "=" + v)
        _ => ()
      }
    }
    inspect(
      props,
      content=(
        #|["display=flex", "flex-direction=row", "gap=10px"]
      ),
    )
  }

  // Now test compute_element_style result
  let cascaded = @cascade.cascade_element(elem, [stylesheet], [])
  inspect(
    cascaded.get_value("display"),
    content=(
      #|Some("flex")
    ),
  )
  inspect(
    cascaded.get_value("flex-direction"),
    content=(
      #|Some("row")
    ),
  )
  inspect(
    cascaded.get_value("gap"),
    content=(
      #|Some("10px")
    ),
  )

  // Test apply_css_property
  let mut style = @style.Style::default()
  for prop in cascaded.properties() {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = @renderer.apply_css_property_debug(style, prop, value)
      None => ()
    }
  }
  // Check the resulting style
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Row")
}

///|
test "font-size cascading from stylesheet" {
  let css = "#div1 { font-size: 20px; width: 30px; }"
  let stylesheet = @parser.parse_stylesheet(css)

  // Create element that matches #div1
  let elem = @selector.Element::with_id("div", "div1")

  // Match stylesheet
  let matches = stylesheet.match_element(elem)
  inspect(matches.length() > 0, content="true")
  if matches.length() > 0 {
    let m = matches[0]
    // Check what declarations were matched
    let props : Array[String] = []
    for decl in m.declarations {
      match decl.value {
        @cascade.Value(v) => props.push(decl.property + "=" + v)
        _ => ()
      }
    }
    inspect(
      props,
      content=(
        #|["font-size=20px", "width=30px"]
      ),
    )
  }

  // Check cascaded values
  let cascaded = @cascade.cascade_element(elem, [stylesheet], [])
  inspect(
    cascaded.get_value("font-size"),
    content=(
      #|Some("20px")
    ),
  )

  // Test apply_css_property
  let mut style = @style.Style::default()
  for prop in cascaded.properties() {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = @renderer.apply_css_property_debug(style, prop, value)
      None => ()
    }
  }
  // Check font_size was applied
  inspect(style.font_size, content="20")
}

///|
test "font-size inheritance in full render" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>#div1 { font-size: 20px; width: 30px; }</style>
    #|</head>
    #|<body>
    #|<div id="div1"><a>aaa</a></div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)

  // Check div#div1 has font_size = 20
  let div1 = node.children[0]
  inspect(div1.id, content="div#div1")
  inspect(div1.style.font_size, content="20")

  // Check <a> inherited font_size = 20
  let anchor = div1.children[0]
  inspect(anchor.id, content="a")
  inspect(anchor.style.font_size, content="20")

  // Check text node uses parent's font_size
  let text = anchor.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_size, content="20")
}

///|
test "font-size with nested selectors like WPT" {
  // Simulate the WPT align-self-006.html structure
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  #test { display: flex; }
    #|  #test div { align-self: baseline; }
    #|  #div1 { height: 90px; font-size: 20px; width: 30px; }
    #|  #div2 { height: 50px; font-size: 10px; width: 30px; }
    #|</style>
    #|</head>
    #|<body>
    #|  <div id="test">
    #|    <div id="div1"><a href="#">aaa</a></div>
    #|    <div id="div2"><a href="#">aaaaa</a></div>
    #|  </div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)

  // Find #test
  let test_div = node.children[0]
  inspect(test_div.id, content="div#test")

  // Check div#div1 has font_size = 20, line_height = 20
  let div1 = test_div.children[0]
  inspect(div1.id, content="div#div1")
  inspect(div1.style.font_size, content="20")
  inspect(div1.style.line_height, content="20")

  // Check div#div2 has font_size = 10, line_height = 10
  let div2 = test_div.children[1]
  inspect(div2.id, content="div#div2")
  inspect(div2.style.font_size, content="10")
  inspect(div2.style.line_height, content="10")

  // Check <a> inside div1 inherits font_size = 20, line_height = 20
  let anchor1 = div1.children[0]
  inspect(anchor1.id, content="a")
  inspect(anchor1.style.font_size, content="20")
  inspect(anchor1.style.line_height, content="20")

  // Check text node inside <a> has font_size = 20, line_height = 20
  let text1 = anchor1.children[0]
  inspect(text1.id, content="#text")
  inspect(text1.style.font_size, content="20")
  inspect(text1.style.line_height, content="20")
}
