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
  inspect(body.is_some(), content="true")
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
