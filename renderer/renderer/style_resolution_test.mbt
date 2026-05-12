///|
// Stylesheet matching and style resolution tests split from renderer_test.mbt.

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

  let doc = @html.parse_document(html)
  let stylesheets : Array[@css.Stylesheet] = []
  for css in doc.stylesheets {
    let stylesheet = @css.parse_stylesheet(css)
    stylesheets.push(stylesheet)
  }

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
      for child in body_elem.children {
        match child {
          @html.Node::Element(row_elem) =>
            if row_elem.classes.length() > 0 && row_elem.classes[0] == "row" {
              let sel_elem = @css.Element::new("div").add_class("row")

              let cascaded = @css.cascade_element(sel_elem, stylesheets, [])
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
  let stylesheet = @css.parse_stylesheet(css)

  let elem = @css.Element::new("div").add_class("row")

  let matches = stylesheet.match_element(elem)
  inspect(matches.length() > 0, content="true")
  if matches.length() > 0 {
    let m = matches[0]
    let props : Array[String] = []
    for decl in m.declarations {
      match decl.value {
        @css.PropertyValue::Value(v) => props.push(decl.property + "=" + v)
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

  let cascaded = @css.cascade_element(elem, [stylesheet], [])
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

  let mut style = @style.Style::default()
  for prop in cascaded.properties() {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = @renderer.apply_css_property_debug(style, prop, value)
      None => ()
    }
  }
  inspect(style.display, content="Flex")
  inspect(style.flex_direction, content="Row")
}

///|
test "stylesheet margin-trim is applied" {
  let css = "container { display: block; margin-trim: block; }"
  let stylesheet = @css.parse_stylesheet(css)
  let elem = @css.Element::new("container")

  let cascaded = @css.cascade_element(elem, [stylesheet], [])
  inspect(
    cascaded.get_value("margin-trim"),
    content=(
      #|Some("block")
    ),
  )

  let mut style = @style.Style::default()
  for prop in cascaded.properties() {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = @renderer.apply_css_property_debug(style, prop, value)
      None => ()
    }
  }
  inspect(style.margin_trim, content="Block")
}

///|
test "render_to_node applies margin-trim from stylesheet" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>container { display: block; margin-trim: block; }</style>
    #|</head>
    #|<body><container><item></item></container></body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let container = node.children[0]
  inspect(container.id, content="container")
  inspect(container.style.margin_trim, content="Block")
}

///|
test "font-size cascading from stylesheet" {
  let css = "#div1 { font-size: 20px; width: 30px; }"
  let stylesheet = @css.parse_stylesheet(css)

  let elem = @css.Element::with_id("div", "div1")

  let matches = stylesheet.match_element(elem)
  inspect(matches.length() > 0, content="true")
  if matches.length() > 0 {
    let m = matches[0]
    let props : Array[String] = []
    for decl in m.declarations {
      match decl.value {
        @css.PropertyValue::Value(v) => props.push(decl.property + "=" + v)
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

  let cascaded = @css.cascade_element(elem, [stylesheet], [])
  inspect(
    cascaded.get_value("font-size"),
    content=(
      #|Some("20px")
    ),
  )

  let mut style = @style.Style::default()
  for prop in cascaded.properties() {
    match cascaded.get_value(prop) {
      Some(value) =>
        style = @renderer.apply_css_property_debug(style, prop, value)
      None => ()
    }
  }
  inspect(style.font_size, content="20")
}

///|
test "render_to_node resolves inline custom properties in gradient background" {
  let html =
    #|<!doctype html>
    #|<body>
    #|  <div id="hero" style="--g-angle: 135deg; --g-color-0: #c4b5fd; --g-position-0: 0%; --g-color-1: #2dd4bf; --g-position-1: 100%; width: 320px; height: 120px; background: linear-gradient(var(--g-angle), var(--g-color-0) var(--g-position-0), var(--g-color-1) var(--g-position-1));"></div>
    #|</body>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let hero = node.children[0]
  inspect(
    hero.style.background_image,
    content=(
      #|Gradient({angle_deg: 135, stops: [{color: rgb(196, 181, 253), position: 0}, {color: rgb(45, 212, 191), position: 1}]})
    ),
  )
}

///|
test "render_to_node resolves stylesheet custom properties in gradient background" {
  let html =
    #|<!doctype html>
    #|<style>
    #|  #hero {
    #|    --g-angle: 135deg;
    #|    --g-color-0: #c4b5fd;
    #|    --g-position-0: 0%;
    #|    --g-color-1: #2dd4bf;
    #|    --g-position-1: 100%;
    #|    width: 320px;
    #|    height: 120px;
    #|    background: linear-gradient(var(--g-angle), var(--g-color-0) var(--g-position-0), var(--g-color-1) var(--g-position-1));
    #|  }
    #|</style>
    #|<body><div id="hero"></div></body>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let hero = node.children[0]
  inspect(
    hero.style.background_image,
    content=(
      #|Gradient({angle_deg: 135, stops: [{color: rgb(196, 181, 253), position: 0}, {color: rgb(45, 212, 191), position: 1}]})
    ),
  )
}

///|
test "font-size with nested selectors like WPT" {
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

  let test_div = node.children[0]
  inspect(test_div.id, content="div#test")

  let div1 = test_div.children[0]
  inspect(div1.id, content="div#div1")
  inspect(div1.style.font_size, content="20")
  inspect(div1.style.line_height, content="24")

  let div2 = test_div.children[1]
  inspect(div2.id, content="div#div2")
  inspect(div2.style.font_size, content="10")
  inspect(div2.style.line_height, content="12")

  let text1 = div1.children[0]
  inspect(text1.id, content="a")
  inspect(text1.style.font_size, content="20")
  inspect(text1.style.line_height, content="24")
}
