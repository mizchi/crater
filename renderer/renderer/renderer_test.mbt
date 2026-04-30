///|
#cfg(target="js")
extern "js" fn set_builtin_text_advance_ratio_override_for_test(
  ratio : Double,
) -> Unit =
  #|(ratio) => {
  #|  globalThis.__craterBuiltinTextAdvanceRatio = ratio;
  #|}

///|
#cfg(not(target="js"))
fn set_builtin_text_advance_ratio_override_for_test(ratio : Double) -> Unit {
  @renderer.set_builtin_text_advance_ratio_override_for_test(ratio)
}

///|
#cfg(target="js")
extern "js" fn clear_builtin_text_advance_ratio_override_for_test() -> Unit =
  #|() => {
  #|  delete globalThis.__craterBuiltinTextAdvanceRatio;
  #|}

///|
#cfg(not(target="js"))
fn clear_builtin_text_advance_ratio_override_for_test() -> Unit {
  @renderer.clear_builtin_text_advance_ratio_override_for_test()
}

///|
test "position relative with negative offset" {
  let html =
    #|<div style="width: 100px; height: 100px;">
    #|  <div style="position: relative; top: -20px; left: -40px; width: 50px; height: 50px;"></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)
  let outer = layout.children[0]
  let inner = outer.children[0]
  inspect(inner.x, content="-40")
  inspect(inner.y, content="-20")
}

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
test "layout_to_json serializes box model fields without changing schema" {
  let child : @types.Layout = {
    id: "child",
    x: 5.0,
    y: 6.0,
    width: 7.0,
    height: 8.0,
    margin: @types.Rect::all(0.0),
    padding: @types.Rect::all(1.0),
    border: @types.Rect::all(2.0),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 7.0,
    scroll_height: 8.0,
    children: [],
    text: None,
  }
  let layout : @types.Layout = {
    id: "root",
    x: 1.0,
    y: 2.0,
    width: 3.0,
    height: 4.0,
    margin: @types.Rect::all(0.0),
    padding: @types.Rect::all(0.0),
    border: @types.Rect::all(0.0),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 3.0,
    scroll_height: 4.0,
    children: [child],
    text: None,
  }
  assert_eq(
    @renderer.layout_to_json(layout),
    "{\"id\":\"root\",\"x\":1,\"y\":2,\"width\":3,\"height\":4,\"margin\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"padding\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"border\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"children\":[{\"id\":\"child\",\"x\":5,\"y\":6,\"width\":7,\"height\":8,\"margin\":{\"top\":0,\"right\":0,\"bottom\":0,\"left\":0},\"padding\":{\"top\":1,\"right\":1,\"bottom\":1,\"left\":1},\"border\":{\"top\":2,\"right\":2,\"bottom\":2,\"left\":2},\"children\":[]}]}",
  )
}

///|
test "render_to_node_and_layout_with_external_css is stable across repeated calls" {
  let html =
    #|<div id="target" class="card"><span>hello</span></div>
  let ctx = @renderer.RenderContext::default()
  let external_css = [
    ".card { display: flex; gap: 8px; padding: 12px; border: 1px solid black; }",
    "#target span { display: inline-block; width: 40px; height: 20px; }",
  ]
  let (_, layout1) = @renderer.render_to_node_and_layout_with_external_css(
    html, ctx, external_css,
  )
  let (_, layout2) = @renderer.render_to_node_and_layout_with_external_css(
    html, ctx, external_css,
  )
  assert_eq(
    @renderer.layout_to_json(layout1),
    @renderer.layout_to_json(layout2),
  )
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
  let stylesheets : Array[@css.Stylesheet] = []
  for css in doc.stylesheets {
    let stylesheet = @css.parse_stylesheet(css)
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
              let sel_elem = @css.Element::new("div").add_class("row")

              // Match against stylesheet
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

  // Create element that matches .row
  let elem = @css.Element::new("div").add_class("row")

  // Match stylesheet
  let matches = stylesheet.match_element(elem)
  inspect(matches.length() > 0, content="true")
  if matches.length() > 0 {
    let m = matches[0]
    // Check what declarations were matched
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

  // Now test compute_element_style result
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

  // Create element that matches #div1
  let elem = @css.Element::with_id("div", "div1")

  // Match stylesheet
  let matches = stylesheet.match_element(elem)
  inspect(matches.length() > 0, content="true")
  if matches.length() > 0 {
    let m = matches[0]
    // Check what declarations were matched
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

  // Check cascaded values
  let cascaded = @css.cascade_element(elem, [stylesheet], [])
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

  // Text inside <a> is now collected to parent div (inline element text collection)
  let text = div1.children[0]
  inspect(text.id, content="a")
  inspect(text.style.font_size, content="20")
}

///|
test "font shorthand inherits line-height to descendant text nodes" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>body { font: 10px/1 monospace; }</style>
    #|</head>
    #|<body>
    #|<div id="outer"><span id="inner">X X</span></div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let inner = outer.children[0]
  inspect(inner.id, content="span#inner")
  inspect(inner.style.font_size, content="10")
  inspect(inner.style.line_height, content="10")
  let text = inner.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_size, content="10")
  inspect(text.style.line_height, content="10")
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "font-family and spacing inherit to descendant text nodes" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>body { font-family: serif; letter-spacing: 2px; word-spacing: 3px; }</style>
    #|</head>
    #|<body>
    #|<div id="outer"><span id="inner">hello world</span></div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_family, content="serif")
  inspect(outer.style.letter_spacing, content="2")
  inspect(outer.style.word_spacing, content="3")
  let inner = outer.children[0]
  inspect(inner.id, content="span#inner")
  inspect(inner.style.font_family, content="serif")
  inspect(inner.style.letter_spacing, content="2")
  inspect(inner.style.word_spacing, content="3")
  let text = inner.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_family, content="serif")
  inspect(text.style.letter_spacing, content="2")
  inspect(text.style.word_spacing, content="3")
}

///|
test "body defaults descendant text nodes to serif font-family" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="outer">hello world</div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(node.id, content="body")
  inspect(node.style.font_family, content="serif")
  inspect(node.style.margin.top, content="Length(8)")
  inspect(node.style.margin.left, content="Length(8)")
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_family, content="serif")
  let text = outer.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_family, content="serif")
}

///|
test "implicit body font shorthand reaches descendant text measure" {
  let html =
    #|<!doctype html>
    #|<style>body { font: 10px/1 monospace; }</style>
    #|<div id="outer">X X</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  inspect(text.id, content="#text")
  inspect(text.style.font_size, content="10")
  inspect(text.style.line_height, content="10")
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "body font shorthand survives preceding grid declarations" {
  let html =
    #|<!doctype html>
    #|<style>
    #|body {
    #|  display: grid;
    #|  grid-template-columns: repeat(auto-fill, 50px 50px 50px);
    #|  grid-auto-rows: 50px;
    #|  font: 10px/1 monospace;
    #|}
    #|</style>
    #|<div id="outer">X X</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(node.id, content="body")
  inspect(node.style.font_size, content="10")
  inspect(node.style.line_height, content="10")
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "body font shorthand survives string @import prelude" {
  let html =
    #|<!doctype html>
    #|<style>
    #|@import "/fonts/ahem.css"; /* optional */
    #|body {
    #|  font: 10px/1 monospace;
    #|}
    #|</style>
    #|<div id="outer">X X</div>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let outer = node.children[0]
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "later body font style overrides earlier reset style" {
  let html =
    #|<!doctype html>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|</style>
    #|<style>
    #|@import "/fonts/ahem.css"; /* optional */
    #|body {
    #|  display: grid;
    #|  grid-template-columns: repeat(auto-fill, 50px 50px 50px);
    #|  grid-auto-rows: 50px;
    #|  font: 10px/1 monospace;
    #|}
    #|</style>
    #|<div id="outer">X X</div>
  let doc = @html.parse_document(html)
  inspect(doc.stylesheets.length(), content="2")
  inspect(doc.stylesheets[0].contains("font-size: 16px"), content="true")
  inspect(doc.stylesheets[1].contains("font: 10px/1 monospace"), content="true")
  let cascaded = @css.cascade_element_indexed(
    @css.Element::new("body"),
    [
      @css.IndexedStylesheet::new(@css.parse_stylesheet(doc.stylesheets[0])),
      @css.IndexedStylesheet::new(@css.parse_stylesheet(doc.stylesheets[1])),
    ],
    [],
    None,
  )
  let body_style = @css.compute_style(cascaded, @css.ComputeContext::new())
  inspect(body_style.font_size, content="10")
  inspect(body_style.line_height, content="10")
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(node.id, content="body")
  inspect(node.style.font_size, content="10")
  inspect(node.style.line_height, content="10")
  let outer = node.children[0]
  inspect(outer.id, content="div#outer")
  inspect(outer.style.font_size, content="10")
  inspect(outer.style.line_height, content="10")
  let text = outer.children[0]
  let intrinsic = match text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    intrinsic.max_width,
    content=(
      #|15
    ),
  )
  inspect(intrinsic.max_height, content="10")
}

///|
test "later font shorthand overrides earlier reset longhands in computed style" {
  let reset = @css.parse_stylesheet(
    "body { font-size: 16px; line-height: 1.2; }",
  )
  let authored = @css.parse_stylesheet("body { font: 10px/1 monospace; }")
  let body = @css.Element::new("body")
  let cascaded = @css.cascade_element_indexed(
    body,
    [@css.IndexedStylesheet::new(reset), @css.IndexedStylesheet::new(authored)],
    [],
    None,
  )
  inspect(cascaded.get_value("font"), content="Some(\"10px/1 monospace\")")
  let style = @css.compute_style(cascaded, @css.ComputeContext::new())
  inspect(style.font_size, content="10")
  inspect(style.line_height, content="10")
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

  // Check div#div1 has font_size = 20, normal line-height = 1.2
  let div1 = test_div.children[0]
  inspect(div1.id, content="div#div1")
  inspect(div1.style.font_size, content="20")
  inspect(div1.style.line_height, content="24")

  // Check div#div2 has font_size = 10, normal line-height = 1.2
  let div2 = test_div.children[1]
  inspect(div2.id, content="div#div2")
  inspect(div2.style.font_size, content="10")
  inspect(div2.style.line_height, content="12")

  // Text inside <a> is now collected to parent div (inline element text collection)
  // div1 should have a #text child with the text from <a>
  let text1 = div1.children[0]
  inspect(text1.id, content="a")
  inspect(text1.style.font_size, content="20")
  inspect(text1.style.line_height, content="24")
}

///|
test "fieldset_columns_shorthand_applies_in_wpt_like_case" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  #container {
    #|    overflow: hidden;
    #|    columns: 3;
    #|    column-fill: auto;
    #|    gap: 0;
    #|    height: 50px;
    #|    margin: 0;
    #|    border: 15px solid green;
    #|    padding: 0;
    #|    scroll-marker-group: before;
    #|    background: red;
    #|  }
    #|</style>
    #|</head>
    #|<body>
    #|<div style="width:100px; height:100px; background:red;">
    #|  <fieldset id="container">
    #|    <legend style="width:50px; height:15px; background:green;"></legend>
    #|    <div style="height:210px; background:green;"></div>
    #|  </fieldset>
    #|</div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let wrapper = node.children[0]
  let container = wrapper.children[0]
  inspect(container.id, content="fieldset#container")
  inspect(container.style.column_count, content="Some(3)")
  inspect(container.style.box_sizing, content="BorderBox")
  inspect(container.style.height, content="Length(80)")
  inspect(container.style.column_gap, content="Length(0)")
  inspect(container.style.column_gap_is_normal, content="false")
}

///|
test "html_columns_propagate_to_body_root_style" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  html {
    #|    columns: 3;
    #|    max-height: 600px;
    #|  }
    #|  body { margin: 0; }
    #|</style>
    #|</head>
    #|<body>
    #|  <div style="height: 100px"></div>
    #|</body></html>
  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  inspect(root.id, content="body")
  inspect(root.style.column_count, content="Some(3)")
  inspect(root.style.column_gap_is_normal, content="true")
}

///|
test "html_max_width_constrains_body_layout_width" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  html { max-width: 780px; }
    #|  body { margin: 0; }
    #|  #box { height: 10px; }
    #|</style>
    #|</head>
    #|<body>
    #|  <div id="box"></div>
    #|</body></html>
  let ctx = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @renderer.render(html, ctx)
  inspect(layout.width, content="780")
  inspect(layout.children[0].width, content="780")
}

///|
test "align_self_static_position_005_inline_span_stays_inline" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|.container {
    #|  position: relative;
    #|  border: 1px solid;
    #|}
    #|
    #|.abs {
    #|  position: absolute;
    #|  background: purple;
    #|  align-self: end;
    #|  opacity: 0.5;
    #|}
    #|</style>
    #|<div class="container">
    #|  <span style="font: 20px/1 Ahem;">hello
    #|    <span class="abs">hello</span>
    #|    <span style="vertical-align: top; font-size: 50px;">world</span>
    #|  </span>
    #|</div>
  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let container = root.children[0]
  inspect(container.id, content="div.container")
  let inline_span = container.children[0]
  inspect(inline_span.id, content="span")
  inspect(inline_span.style.display, content="Inline")
  let mut has_abs = false
  for child in inline_span.children {
    if child.id == "span.abs" {
      inspect(child.style.position, content="Absolute")
      has_abs = true
    }
  }
  inspect(has_abs, content="true")
}

///|
test "fieldset_columns_shorthand_survives_following_column_scroll_marker_rule" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  #container {
    #|    overflow: hidden;
    #|    columns: 3;
    #|    column-fill: auto;
    #|    gap: 0;
    #|    height: 50px;
    #|    margin: 0;
    #|    border: 15px solid green;
    #|    padding: 0;
    #|    scroll-marker-group: before;
    #|    background: red;
    #|  }
    #|  #container::scroll-marker-group {
    #|    display: flex;
    #|    height: 20px;
    #|    background: red;
    #|  }
    #|  #container::column::scroll-marker {
    #|    display: flex;
    #|    width: 20px;
    #|    height: 100%;
    #|    background: green;
    #|    content: "";
    #|  }
    #|</style>
    #|</head>
    #|<body>
    #|<div style="width:100px; height:100px; background:red;">
    #|  <fieldset id="container">
    #|    <legend style="width:50px; height:15px; background:green;"></legend>
    #|    <div style="height:210px; background:green;"></div>
    #|  </fieldset>
    #|</div>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let wrapper = node.children[0]
  let container = wrapper.children[0]
  inspect(container.id, content="fieldset#container")
  inspect(container.style.column_count, content="Some(3)")
  inspect(container.style.box_sizing, content="BorderBox")
  inspect(container.style.height, content="Length(80)")
  inspect(container.style.column_gap, content="Length(0)")
  inspect(container.style.column_gap_is_normal, content="false")
}

///|
test "br element preserved as separate node with line-height" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test" style="font: 20px/1 Ahem">line1<br>line2</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)

  // Check div#test
  let test_div = node.children[0]
  inspect(test_div.id, content="div#test")

  // Should have 3 children: text1, br, text2
  inspect(test_div.children.length(), content="3")
  let text1 = test_div.children[0]
  inspect(text1.id, content="#text")
  inspect(text1.style.font_size, content="20")
  let br = test_div.children[1]
  inspect(br.id, content="br")
  inspect(br.style.line_height, content="20")

  // Verify br has MeasureFunc (should have height via measure)
  inspect(br.measure is None, content="false")
  let text2 = test_div.children[2]
  inspect(text2.id, content="#text")
}

///|
test "br element has line-height for layout height" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<p id="test" style="font: 16px/1.2 Arial">Hello<br>World</p>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  // Check p#test
  let test_p = layout.children[0]
  inspect(test_p.id, content="p#test")

  // p should have 3 children: text, br, text
  inspect(test_p.children.length(), content="3")

  // Check br has height = line_height (16 * 1.2 = 19.2)
  let br = test_p.children[1]
  inspect(br.id, content="br")
  // height should be approximately 19.2 (16 * 1.2)
  inspect(
    br.height,
    content=(
      #|16.32
    ),
  )
}

///|
test "custom text metrics provider overrides text measurement" {
  @renderer.clear_text_metrics_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test">abc</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_text = default_node.children[0].children[0]
  inspect(default_text.id, content="#text")
  let default_intrinsic = match default_text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    default_intrinsic.max_width == 24.0,
    content=(
      #|true
    ),
  )

  let provider = @renderer.TextMetricsProvider::new(fn(
    _text : String,
    _font_size : Double,
    _line_height : Double,
    _white_space : @style.WhiteSpace,
    _writing_mode : @style.WritingMode,
    _font_weight : Double,
    _font_family : String,
  ) -> @types.MeasureFunc {
    {
      func: fn(
        _available_width : Double,
        _available_height : Double,
      ) -> @types.IntrinsicSize {
        {
          min_width: 123.0,
          max_width: 123.0,
          min_height: 45.0,
          max_height: 45.0,
        }
      },
    }
  })
  @renderer.set_text_metrics_provider(provider)

  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_text = overridden_node.children[0].children[0]
  let overridden_intrinsic = match overridden_text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(overridden_intrinsic.max_width, content="123")
  inspect(overridden_intrinsic.max_height, content="45")
  @renderer.clear_text_metrics_provider()
}

///|
test "clear text metrics provider restores default text measurement" {
  @renderer.clear_text_metrics_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test">abc</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()

  let provider = @renderer.TextMetricsProvider::new(fn(
    _text : String,
    _font_size : Double,
    _line_height : Double,
    _white_space : @style.WhiteSpace,
    _writing_mode : @style.WritingMode,
    _font_weight : Double,
    _font_family : String,
  ) -> @types.MeasureFunc {
    {
      func: fn(
        _available_width : Double,
        _available_height : Double,
      ) -> @types.IntrinsicSize {
        {
          min_width: 321.0,
          max_width: 321.0,
          min_height: 65.0,
          max_height: 65.0,
        }
      },
    }
  })
  @renderer.set_text_metrics_provider(provider)
  @renderer.clear_text_metrics_provider()

  let restored_node = @renderer.render_to_node(html, ctx)
  let restored_text = restored_node.children[0].children[0]
  let restored_intrinsic = match restored_text.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    restored_intrinsic.max_width == 24.0,
    content=(
      #|true
    ),
  )
}

///|
test "text metrics provider affects default text input intrinsic width" {
  @renderer.clear_text_metrics_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<input id="target" type="text">
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_input = default_node.children[0]
  inspect(default_input.id, content="input#target")
  let default_intrinsic = match default_input.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(
    default_intrinsic.max_width,
    content=(
      #|143
    ),
  )

  let provider = @renderer.TextMetricsProvider::new(fn(
    _text : String,
    _font_size : Double,
    _line_height : Double,
    _white_space : @style.WhiteSpace,
    _writing_mode : @style.WritingMode,
    _font_weight : Double,
    _font_family : String,
  ) -> @types.MeasureFunc {
    {
      func: fn(
        _available_width : Double,
        _available_height : Double,
      ) -> @types.IntrinsicSize {
        { min_width: 6.0, max_width: 6.0, min_height: 16.0, max_height: 16.0 }
      },
    }
  })
  @renderer.set_text_metrics_provider(provider)

  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_input = overridden_node.children[0]
  let overridden_intrinsic = match overridden_input.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(overridden_intrinsic.max_width, content="133")
  @renderer.clear_text_metrics_provider()
}

///|
test "builtin text advance ratio override affects boundary whitespace text width" {
  @renderer.clear_text_metrics_provider()
  clear_builtin_text_advance_ratio_override_for_test()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<table><tr><td>
    #|  <div style="height: 10px;"></div>
    #|  Can you see this text?
    #|</td></tr></table>
    #|</body></html>
  fn find_text_measure_with_phrase(
    node : @node.Node,
    phrase : String,
  ) -> @types.MeasureFunc? {
    match node.text {
      Some(text) => if text.contains(phrase) { return node.measure }
      None => ()
    }
    for child in node.children {
      match find_text_measure_with_phrase(child, phrase) {
        Some(measure) => return Some(measure)
        None => ()
      }
    }
    None
  }
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_measure = match
    find_text_measure_with_phrase(default_node, "Can you see this text?") {
    Some(measure) => measure
    None => abort("expected text measure")
  }
  let default_intrinsic = (default_measure.func)(9999.0, 9999.0)
  inspect(
    default_intrinsic.max_width,
    content=(
      #|176
    ),
  )

  set_builtin_text_advance_ratio_override_for_test(0.4)
  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_measure = match
    find_text_measure_with_phrase(overridden_node, "Can you see this text?") {
    Some(measure) => measure
    None => abort("expected overridden text measure")
  }
  let overridden_intrinsic = (overridden_measure.func)(9999.0, 9999.0)
  inspect(overridden_intrinsic.max_width, content="140.8")
  clear_builtin_text_advance_ratio_override_for_test()
}

///|
test "custom image intrinsic size provider overrides unresolved src size" {
  @renderer.clear_image_intrinsic_size_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<img id="target" src="https://example.com/a.png">
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let default_node = @renderer.render_to_node(html, ctx)
  let default_img = default_node.children[0]
  inspect(default_img.id, content="img#target")
  let default_intrinsic = match default_img.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(default_intrinsic.max_width == 0.0, content="true")
  inspect(default_intrinsic.max_height == 0.0, content="true")

  let provider = @renderer.ImageIntrinsicSizeProvider::new(fn(
    src : String,
  ) -> (Double, Double)? {
    if src.contains("example.com") {
      Some((77.0, 33.0))
    } else {
      None
    }
  })
  @renderer.set_image_intrinsic_size_provider(provider)

  let overridden_node = @renderer.render_to_node(html, ctx)
  let overridden_img = overridden_node.children[0]
  let overridden_intrinsic = match overridden_img.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(overridden_intrinsic.max_width, content="77")
  inspect(overridden_intrinsic.max_height, content="33")
  @renderer.clear_image_intrinsic_size_provider()
}

///|
test "clear image intrinsic size provider restores default unresolved src size" {
  @renderer.clear_image_intrinsic_size_provider()
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<img id="target" src="https://example.com/a.png">
    #|</body></html>
  let ctx = @renderer.RenderContext::default()

  let provider = @renderer.ImageIntrinsicSizeProvider::new(fn(
    _src : String,
  ) -> (Double, Double)? {
    Some((91.0, 52.0))
  })
  @renderer.set_image_intrinsic_size_provider(provider)
  @renderer.clear_image_intrinsic_size_provider()

  let restored_node = @renderer.render_to_node(html, ctx)
  let restored_img = restored_node.children[0]
  let restored_intrinsic = match restored_img.measure {
    Some(measure) => (measure.func)(9999.0, 9999.0)
    None => @types.IntrinsicSize::default()
  }
  inspect(restored_intrinsic.max_width == 0.0, content="true")
  inspect(restored_intrinsic.max_height == 0.0, content="true")
}

///|
test "inline style min-height does not set height" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="target" style="display:flex; min-height:200px;">
    #|  <div id="item" style="width:100px; min-height:100px;"></div>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let target = node.children[0]
  let item = target.children[0]
  inspect(target.style.align_items, content="Stretch")
  inspect(target.style.height, content="Auto")
  inspect(target.style.min_height, content="Length(200)")
  inspect(item.style.height, content="Auto")
  inspect(item.style.min_height, content="Length(100)")
}

///|
test "repeated inline styles do not reuse default cache across inherited font sizes" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="outer-default">
    #|  <span id="default-child" style="line-height: 1em"></span>
    #|</div>
    #|<div id="outer-large" style="font-size: 32px; line-height: 1em">
    #|  <span id="large-child" style="line-height: 1em"></span>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let default_child = node.children[0].children[0]
  let large_outer = node.children[1]
  let large_child = large_outer.children[0]
  inspect(default_child.style.line_height, content="16")
  inspect(large_outer.style.font_size, content="32")
  inspect(large_child.style.line_height, content="32")
}

///|
test "anchor remains inline inside fixed-height flex item" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<style>
    #|#test { display: flex; }
    #|#test div { align-self: baseline; }
    #|#div1 { height: 90px; font-size: 20px; width: 30px; }
    #|</style>
    #|<div id="test"><div id="div1"><a href="#">aaa</a></div></div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let target = node.children[0]
  let div1 = target.children[0]
  let anchor = div1.children[0]
  inspect(target.style.display, content="Flex")
  inspect(div1.style.display, content="Block")
  inspect(div1.style.zoom, content="1")
  inspect(anchor.id, content="a")
  inspect(anchor.style.display, content="Inline")
}

///|
test "wpt_baseline_row_horz_text_nodes_keep_single_line_metrics" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|body { margin: 0; font-family: monospace; font-size: 16px; line-height: 1.2; }
    #|#target {
    #|  display: flex;
    #|  align-items: baseline;
    #|  inline-size: min-content;
    #|  block-size: 100px;
    #|  border: solid 3px;
    #|}
    #|#target > div {
    #|  margin: 5px 7px 9px 11px;
    #|}
    #|#target > :nth-child(1) {
    #|  background: lime;
    #|  font: 30px/1 Ahem;
    #|}
    #|#target > :nth-child(2) {
    #|  background: hotpink;
    #|  font: 20px/1 Ahem;
    #|}
    #|#target > :nth-child(3) {
    #|  background: cyan;
    #|  writing-mode: vertical-rl;
    #|  font: 16px/1 Ahem;
    #|  width: 40px;
    #|  height: 40px;
    #|}
    #|</style>
    #|</head><body>
    #|<div id="target">
    #|  <div>line1<br>line2</div>
    #|  <div>line1<br>line2</div>
    #|  <div></div>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let target = node.children[0]
  let first = target.children[0]
  let text1 = first.children[0]
  let text2 = first.children[2]
  inspect(first.style.width, content="Auto")
  inspect(first.style.font_size, content="30")
  inspect(text1.style.font_size, content="30")
  inspect(text1.style.line_height, content="30")
  inspect(text1.text, content="Some(\"line1\")")
  inspect(text2.text, content="Some(\"line2\")")

  let layout = @renderer.render(html, ctx)
  let target_layout = layout.children[0]
  let first_layout = target_layout.children[0]
  inspect(
    first_layout.height,
    content=(
      #|60
    ),
  )
  inspect(
    first_layout.children[0].height,
    content=(
      #|30
    ),
  )
  inspect(first_layout.children[1].y, content="0")
  inspect(
    first_layout.children[2].y,
    content=(
      #|30
    ),
  )
}

///|
test "logical properties inline-size and block-size" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test" style="inline-size: 200px; block-size: 100px"></div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)
  let test_div = layout.children[0]
  inspect(test_div.id, content="div#test")
  inspect(test_div.width, content="200")
  inspect(test_div.height, content="100")
}

///|
test "visually hidden element should be skipped" {
  let html = "<div><a class=\"mw-jump-link\" style=\"display:block;position:absolute;clip:rect(1px,1px,1px,1px);width:1px;height:1px;overflow:hidden\">Jump to content</a><p>Visible content</p></div>"
  let ctx : RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = render_to_node(html, ctx)

  // Check the a element style (path: body -> div -> a)
  let div_node = node.children[0]
  let a_node = div_node.children[0]
  inspect(a_node.id, content="a.mw-jump-link")
  inspect(a_node.style.display, content="Block")
  inspect(a_node.style.clip, content="rect(1, 1, 1, 1)")
  inspect(a_node.style.overflow_x, content="Hidden")
  inspect(a_node.style.width, content="Length(1)")
  inspect(a_node.style.height, content="Length(1)")
}

///|
test "debug_text_wrapping_in_narrow_container" {
  // Simple test: long text in a narrow container should wrap and have correct height
  let html =
    #|<div style="width: 100px">
    #|This is a long text that should wrap within the container width
    #|</div>
  let ctx : RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render(html, ctx)
  let container = layout.children[0]
  // Container width should be 100px
  inspect(container.width, content="100")
  // Check text child
  inspect(container.children.length() > 0, content="true")
  if container.children.length() > 0 {
    let text_layout = container.children[0]
    // Text width should be constrained to container width
    inspect(text_layout.width <= 100.0, content="true")
    // Text height should be multiple lines (text is about 60 chars, container is ~12 chars wide)
    // Expecting at least 5 lines * ~19.2 line height = ~96 height
    inspect(text_layout.height > 50.0, content="true")
  }
}

///|
test "debug_mixed_inline_block_content" {
  // Wikipedia-like structure: text mixed with block elements
  let html =
    #|<div style="width: 300px">
    #|<p>This is paragraph one with some long text content.</p>
    #|<p>This is paragraph two with more long text content that needs to wrap.</p>
    #|</div>
  let ctx : RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render(html, ctx)
  let container = layout.children[0]
  inspect(container.width, content="300")
  // Should have 2 children (p elements)
  inspect(container.children.length(), content="2")
  if container.children.length() >= 2 {
    let p1 = container.children[0]
    let p2 = container.children[1]
    // p2 should be below p1 (y > 0)
    inspect(p2.y > p1.y, content="true")
    // CRITICAL: p2 should start after p1 ends (no overlap)
    // p2.y should be >= p1.y + p1.height (accounting for margins)
    let p1_bottom = p1.y + p1.height
    let overlap = p1_bottom > p2.y
    inspect(overlap, content="false")
  }
}

///|
test "debug_heading_text_rendering" {
  let html = "<h1>Signal Boosting</h1>"

  // First check HTML parser output
  let doc = @html.parse_document(html)
  fn find_h1(elem : @html.Element) -> @html.Element? {
    if elem.tag == "h1" {
      return Some(elem)
    }
    for child in elem.children {
      match child {
        @html.Node::Element(child_elem) =>
          match find_h1(child_elem) {
            Some(h1) => return Some(h1)
            None => ()
          }
        @html.Node::Text(_) => ()
      }
    }
    None
  }

  match find_h1(doc.root) {
    Some(h1) => {
      inspect(h1.tag, content="h1")
      inspect(h1.children.length(), content="1")
      if h1.children.length() > 0 {
        match h1.children[0] {
          @html.Node::Text(text) => inspect(text, content="Signal Boosting")
          @html.Node::Element(e) => inspect(e.tag, content="")
        }
      }
    }
    None => inspect("h1 not found", content="")
  }

  // Now check render output
  let ctx : RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = render_to_node(html, ctx)
  // Find h1 in children
  let mut h1_found = false
  for child in node.children {
    if child.id == "h1" {
      h1_found = true
      // Check h1 has children
      inspect(child.children.length(), content="1")
    }
  }
  inspect(h1_found, content="true")
}

///|
test "debug_h2_with_anchor" {
  let html = "<h2><a href=\"#\">Link Text in H2</a></h2>"
  let ctx : RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = render_to_node(html, ctx)
  // h2 should be the first child of body
  let h2 = node.children[0]
  inspect(h2.id, content="h2")
  // h2 should have a #text child (anchor text is collected as inline)
  inspect(h2.children.length(), content="1")
  if h2.children.length() > 0 {
    let text = h2.children[0]
    inspect(text.id, content="a")
  }
}

///|
test "debug_inline_text_with_block_sibling" {
  // Test case: raw text followed by block element (Anonymous Block Boxes)
  let html =
    #|<div style="width: 200px">
    #|Welcome to the site
    #|<p style="margin: 0">This is a paragraph</p>
    #|More text after the paragraph
    #|</div>
  let ctx : RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render(html, ctx)
  let container = layout.children[0]
  inspect(container.width, content="200")
  // Check that children don't overlap
  for i = 0; i < container.children.length() - 1; i = i + 1 {
    let child = container.children[i]
    let next = container.children[i + 1]
    let child_bottom = child.y + child.height
    let overlap = child_bottom > next.y
    // Each pair should not overlap
    assert_true(
      !overlap,
      msg="Children " +
        i.to_string() +
        " and " +
        (i + 1).to_string() +
        " overlap: " +
        child_bottom.to_string() +
        " > " +
        next.y.to_string(),
    )
  }
}

///|
test "img_alt_text_propagation" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|  <h1>Test</h1>
    #|  <img src="test.jpg" width="200" height="100" alt="Alt text here">
    #|  <p>After</p>
    #|</body>
    #|</html>
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 400.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = render_to_node(html, ctx)
  let layout = render(html, ctx)
  // Debug: print all node IDs
  fn print_nodes(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    let _ = match n.text {
      Some(t) => " text=\"" + t + "\""
      None => ""
    }
    for child in n.children {
      print_nodes(child, depth + 1)
    }
  }

  print_nodes(node, 0)
  // Find img node
  fn find_img_node(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("img") {
      return Some(n)
    }
    for child in n.children {
      match find_img_node(child) {
        Some(img) => return Some(img)
        None => continue
      }
    }
    None
  }

  fn find_img_layout(l : @types.Layout) -> @types.Layout? {
    if l.id.has_prefix("img") {
      return Some(l)
    }
    for child in l.children {
      match find_img_layout(child) {
        Some(img) => return Some(img)
        None => continue
      }
    }
    None
  }
  // Check node has alt text
  match find_img_node(node) {
    Some(img) => {
      inspect(img.id, content="img")
      inspect(img.text, content="Some(\"Alt text here\")")
    }
    None => fail("No img node found!")
  }
  // Check layout has text
  match find_img_layout(layout) {
    Some(img) => {
      inspect(img.id, content="img")
      inspect(img.text, content="Some(\"Alt text here\")")
      inspect(img.width > 0.0, content="true")
      inspect(img.height > 0.0, content="true")
    }
    None => fail("No img layout found!")
  }
}

///|
test "img without src and percent max-size stays zero-sized in grid item" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head><style>body { margin: 0; }</style></head>
    #|<body>
    #|  <div style="display: grid; width: 100px;">
    #|    <div style="display: grid; margin: auto;">
    #|      <img style="max-width: 100%; max-height: 100%;">
    #|    </div>
    #|  </div>
    #|</body>
    #|</html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let outer_node = node.children[0]
  let inner_node = outer_node.children[0]
  let img_node = inner_node.children[0]
  inspect(inner_node.style.margin.left, content="Auto")
  inspect(inner_node.style.margin.right, content="Auto")
  inspect(img_node.style.display, content="Inline")
  inspect(img_node.style.max_width, content="Percent(1)")
  inspect(img_node.style.max_height, content="Percent(1)")
  inspect(
    match img_node.measure {
      Some(_) => true
      None => false
    },
    content="true",
  )

  let layout = @renderer.render(html, ctx)
  let outer = layout.children[0]
  let inner = outer.children[0]
  let img = inner.children[0]
  inspect(outer.width, content="100")
  inspect(img.width, content="0")
  inspect(inner.width, content="0")
}

///|
/// Test tall content for scrollability (simulates Zenn article structure)
test "tall_content_scrollability" {
  // Simulate Zenn article structure with multiple sections
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; padding: 16px; }
    #|h1 { font-size: 32px; margin: 16px 0; }
    #|h2 { font-size: 24px; margin: 12px 0; }
    #|p { font-size: 16px; line-height: 1.6; margin: 12px 0; }
    #|pre { background: #f5f5f5; padding: 16px; margin: 16px 0; }
    #|code { font-size: 14px; }
    #|</style>
    #|</head>
    #|<body>
    #|<article>
    #|  <h1>MoonBit Useful Tips</h1>
    #|  <p>This is the introduction paragraph with some content about MoonBit programming language and its features.</p>
    #|
    #|  <h2>Section 1: Getting Started</h2>
    #|  <p>First paragraph of section one with detailed explanation of the topic. This text should be long enough to wrap multiple lines in a narrow viewport.</p>
    #|  <pre><code>fn main() {
    #|      #|}</code></pre>
    #|  <p>Additional explanation after the code block explaining what the code does and how it works in practice.</p>
    #|
    #|  <h2>Section 2: Advanced Features</h2>
    #|  <p>Second section with more advanced content. This paragraph contains detailed technical information.</p>
    #|  <pre><code>struct Point {
    #|  x: Int
    #|  y: Int
    #|}
    #|
    #|fn Point::new(x: Int, y: Int) -> Point {
    #|  { x, y }
    #|}</code></pre>
    #|  <p>Explanation of structs and methods in MoonBit with examples and best practices.</p>
    #|
    #|  <h2>Section 3: Pattern Matching</h2>
    #|  <p>Pattern matching is a powerful feature in MoonBit that allows you to match values against patterns.</p>
    #|  <pre><code>fn describe(opt: Int?) -> String {
    #|  match opt {
    #|    Some(n) => "Has value: " + n.to_string()
    #|    None => "No value"
    #|  }
    #|}</code></pre>
    #|  <p>More details about pattern matching and its various use cases in real applications.</p>
    #|
    #|  <h2>Section 4: Error Handling</h2>
    #|  <p>Error handling in MoonBit uses Result types for explicit error management.</p>
    #|  <p>This approach ensures that errors are handled at compile time rather than runtime.</p>
    #|
    #|  <h2>Conclusion</h2>
    #|  <p>MoonBit provides a modern approach to systems programming with safety and performance.</p>
    #|  <p>Thank you for reading this article. Feel free to explore more resources.</p>
    #|</article>
    #|</body>
    #|</html>

  // Small viewport to simulate scrollable content
  let viewport_width = 320.0
  let viewport_height = 200.0 // Only shows part of the content
  let ctx : RenderContext = {
    viewport_width,
    viewport_height,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render(html, ctx)

  // Debug output

  // CRITICAL: Content height must be greater than viewport height for scrolling
  inspect(layout.height > viewport_height, content="true")

  // Content should be significantly taller (at least 3x viewport height for this article)
  let min_expected_height = viewport_height * 2.0
  inspect(layout.height > min_expected_height, content="true")

  // Verify scrollable area calculation
  let scrollable_height = layout.height - viewport_height
  inspect(scrollable_height > 0.0, content="true")

  // Test max scroll in character units (16px per char)
  let font_height = 16.0
  let max_scroll_chars = ((layout.height - viewport_height) / font_height).to_int()
  inspect(max_scroll_chars > 0, content="true")
}

///|
test "link default color is blue" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<a href="https://example.com">Link text</a>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  // Find the <a> element which should be preserved with blue color
  fn find_link_node(n : @node.Node) -> @node.Node? {
    if n.id.has_prefix("a") {
      return Some(n)
    }
    for child in n.children {
      match find_link_node(child) {
        Some(a) => return Some(a)
        None => continue
      }
    }
    None
  }

  match find_link_node(node) {
    Some(link) => {
      // <a> element should have blue color (#0000EE = rgb(0, 0, 238))
      inspect(link.style.color.r, content="0")
      inspect(link.style.color.g, content="0")
      inspect(link.style.color.b, content="238")
      // Text inside <a> should also have blue color (inherited)
      if link.children.length() > 0 {
        let text = link.children[0]
        inspect(text.id, content="#text")
        inspect(text.style.color.r, content="0")
        inspect(text.style.color.g, content="0")
        inspect(text.style.color.b, content="238")
      }
    }
    None => fail("No link node found!")
  }
}

///|
test "ua_list_defaults_use_block_margin_and_inline_start_padding" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<ol><li></li></ol>
    #|</body></html>
  let node = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let ol = node.children[0]
  let li = ol.children[0]
  inspect(ol.id, content="ol")
  inspect(ol.style.margin.top, content="Length(16)")
  inspect(ol.style.margin.bottom, content="Length(16)")
  inspect(ol.style.margin.left, content="Length(0)")
  inspect(ol.style.padding.left, content="Length(40)")
  inspect(ol.style.padding.bottom, content="Length(0)")
  inspect(li.id, content="li")
  inspect(li.style.min_height, content="Length(19.2)")
}

///|
test "display_contents keeps inline parent shrink-to-fit and preserves child span" {
  let html =
    #|<!DOCTYPE html>
    #|<meta charset="utf-8">
    #|<style>
    #|#contents {
    #|  display: contents;
    #|}
    #|</style>
    #|<p>You should see the word PASS and no red below.</p>
    #|<span>
    #|  P<div id="contents">A<span>S</span></div>S
    #|</span>
  let ctx = @renderer.RenderContext::default()
  let node_tree = @renderer.render_to_node(html, ctx)
  let span_node = node_tree.children[1]
  inspect(span_node.id, content="span")
  inspect(span_node.children.length(), content="3")
  inspect(span_node.children[1].id, content="div#contents")
  inspect(
    span_node.children[1].children.length(),
    content=(
      #|1
    ),
  )
  inspect(
    span_node.children[1].children[0].id,
    content=(
      #|#text
    ),
  )

  let layout = @renderer.render(html, ctx)

  let inline_parent = layout.children[1]
  inspect(inline_parent.id, content="span")
  inspect(inline_parent.width < 200.0, content="true")

  fn find_child(
    children : Array[@types.Layout],
    id : String,
  ) -> @types.Layout? {
    for child in children {
      if child.id == id {
        return Some(child)
      }
    }
    None
  }

  match find_child(inline_parent.children, "div#contents") {
    Some(contents_layout) => {
      inspect(contents_layout.width, content="0")
      inspect(contents_layout.height, content="0")
      inspect(
        contents_layout.children.length(),
        content=(
          #|1
        ),
      )
      inspect(contents_layout.children[0].id, content="#text")
    }
    None => fail("div#contents layout not found")
  }
}

///|
test "display_contents text contributes to flex item intrinsic width" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|  .flex { display: flex; }
    #|  .inline { display: inline; }
    #|  .contents { display: contents; }
    #|</style>
    #|<div class="flex">
    #|  <div class="inline"><div class="contents">4</div></div>
    #|  <div><div class="contents">5a</div></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)

  let flex = layout.children[0]
  inspect(flex.id, content="div.flex")
  inspect(flex.children.length(), content="2")
  inspect(flex.children[0].id, content="div.inline")
  inspect(flex.children[1].id, content="div")
  inspect(flex.children[0].width, content="8")
  inspect(flex.children[1].width, content="16")
}

///|
test "shared node_and_layout render matches separate passes" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  :root { writing-mode: horizontal-tb; }
    #|  body { margin: 8px; }
    #|  .row { display: flex; gap: 12px; }
    #|  .card { width: 80px; height: 32px; background: #eee; }
    #|</style>
    #|</head><body>
    #|  <div class="row"><div class="card">A</div><div class="card">B</div></div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let separate_node = @renderer.render_to_node(html, ctx)
  let separate_layout = @renderer.render(html, ctx)
  let (shared_node, shared_layout) = @renderer.render_to_node_and_layout(
    html, ctx,
  )

  inspect(shared_node.id, content="body")
  inspect(shared_node.id == separate_node.id, content="true")
  inspect(shared_node.children.length(), content="1")
  inspect(
    shared_node.children.length() == separate_node.children.length(),
    content="true",
  )
  inspect(shared_node.children[0].id, content="div.row")
  inspect(shared_node.children[0].children.length(), content="2")
  inspect(shared_node.children[0].children[1].style.width, content="Length(80)")

  inspect(shared_layout.id, content="body")
  inspect(shared_layout.id == separate_layout.id, content="true")
  inspect(shared_layout.width == separate_layout.width, content="true")
  inspect(shared_layout.height == separate_layout.height, content="true")
  inspect(shared_layout.children.length(), content="1")
  inspect(
    shared_layout.children[0].children[1].x ==
    separate_layout.children[0].children[1].x,
    content="true",
  )
  inspect(shared_layout.children[0].children[1].x, content="92")
}

///|
test "CSS :not() hides sidebar when body lacks class" {
  let html =
    #|<html><head><style>
    #|.sidebar { display: block; }
    #|body:not(.sidebar-pinned) .sidebar { display: none; }
    #|</style></head>
    #|<body class="skin-vector">
    #|<div class="sidebar" id="side">Sidebar</div>
    #|<div id="main">Main content</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  // sidebar should be display:none because body doesn't have .sidebar-pinned
  let sidebar = node.children[0] // first child is sidebar div
  inspect(sidebar.id, content="div#side")
  inspect(sidebar.style.display, content="None")
}

///|
test "CSS :not() does NOT hide sidebar when body has class" {
  let html =
    #|<html><head><style>
    #|.sidebar { display: block; }
    #|body:not(.sidebar-pinned) .sidebar { display: none; }
    #|</style></head>
    #|<body class="skin-vector sidebar-pinned">
    #|<div class="sidebar" id="side">Sidebar</div>
    #|<div id="main">Main content</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  // sidebar should NOT be display:none because body HAS .sidebar-pinned
  let sidebar = node.children[0]
  inspect(sidebar.id, content="div#side")
  // Should be block (not None)
  assert_true(sidebar.style.display != @types.Display::None)
}

///|
test "CSS class on html element affects body descendants via cascade" {
  // Wikipedia pattern: <html class="feature-disabled"> ... <body> ... <div class="sidebar">
  let html =
    #|<html class="feature-main-menu-pinned-disabled"><head><style>
    #|.sidebar { display: block; }
    #|.feature-main-menu-pinned-disabled .sidebar { display: none; }
    #|</style></head>
    #|<body>
    #|<div class="sidebar" id="side">Sidebar</div>
    #|<div id="main">Main content</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  // sidebar should be display:none because html has .feature-main-menu-pinned-disabled
  let sidebar = node.children[0]
  inspect(sidebar.style.display, content="None")
}

///|
test "CSS @media print rules do not apply in screen context" {
  let html =
    #|<html><head><style>
    #|nav { display: block; }
    #|@media print { nav, .toolbar { display: none !important; } }
    #|</style></head>
    #|<body>
    #|<nav id="menu">Menu</nav>
    #|<div class="toolbar" id="bar">Toolbar</div>
    #|<div id="main">Content</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let nav = node.children[0]
  inspect(nav.id, content="nav#menu")
  // nav should NOT be hidden (we're in screen, not print)
  assert_true(nav.style.display != @types.Display::None)
}

///|
test "CSS descendant selector from html class hides nested element" {
  let html =
    #|<html class="feature-pinned-disabled"><head><style>
    #|.menu-landmark { display: block; }
    #|.feature-pinned-disabled .menu-container .menu-landmark { display: none; }
    #|</style></head>
    #|<body>
    #|<div class="menu-container">
    #|<nav class="menu-landmark" id="menu">Menu</nav>
    #|</div>
    #|<div id="main">Content</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  // menu-container is first child
  let container = node.children[0]
  // menu-landmark inside container should be display:none
  let menu = container.children[0]
  inspect(menu.id, content="nav#menu")
  inspect(menu.style.display, content="None")
}

///|
test "CSS 3-level descendant from html class - Wikipedia sidebar pattern" {
  let html =
    #|<html class="vector-feature-main-menu-pinned-disabled"><head><style>
    #|.vector-main-menu-landmark { display: block; }
    #|.vector-feature-main-menu-pinned-disabled .vector-main-menu-container .vector-main-menu-landmark { display: none; }
    #|</style></head>
    #|<body>
    #|<div class="vector-column-start">
    #|<div class="vector-main-menu-container">
    #|<nav class="vector-main-menu-landmark" id="mw-panel">Menu</nav>
    #|</div>
    #|</div>
    #|<div id="main">Content</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let column = node.children[0]
  let container = column.children[0]
  let nav = container.children[0]
  inspect(nav.id, content="nav#mw-panel")
  // Should be display:none due to .vector-feature-main-menu-pinned-disabled ancestor
  inspect(nav.style.display, content="None")
}

///|
test "Wikipedia CSS: @media print rules have media_query" {
  // Simplified Wikipedia CSS with @media print containing nav{display:none}
  let html =
    #|<html><head><style>
    #|nav { display: block; }
    #|@media print{.toc,body{font-family:serif}#footer-info{display:block}.vector-page-toolbar,.vector-header-start > *:not(.mw-logo),nav,#footer{display:none !important}}
    #|</style></head>
    #|<body>
    #|<nav id="menu">Menu</nav>
    #|<div id="main">Content</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let nav = node.children[0]
  inspect(nav.id, content="nav#menu")
  // nav should be block (NOT none) because we're in screen, not print
  assert_true(nav.style.display != @types.Display::None)
}

///|
test "Wikipedia actual @media print block does not leak to screen" {
  let css = "nav { display: block; } @media print{.toc,body{padding:10px;font-family:'Linux Libertine','Georgia','Times','Source Serif 4',serif}.printfooter,.mw-footer,.thumb,figure,table,ol,dl,ul,.mw-heading3,h3,.mw-heading4,h4,.mw-heading5,h5,.mw-heading6,h6{font-family:sans-serif}img{font-family:'Linux Libertine','Georgia','Times','Source Serif 4',serif}.mw-body a:not(.image){border-bottom:1px solid #aaa}.firstHeading{font-size:25pt;line-height:28pt;margin-bottom:20px;padding-bottom:5px}.firstHeading,.mw-heading2,:not(.mw-heading2) h2{overflow:hidden;border-bottom:2px solid var(--color-emphasized,#101418)}.mw-heading3,h3,.mw-heading4,h4,.mw-heading5,h5,.mw-heading6,h6{margin:30px 0 0}.mw-heading2,h2,.mw-heading3,h3,.mw-heading4,h4,.mw-heading5,h5,.mw-heading6,h6{padding:0;position:relative}.mw-heading2,h2{font-size:18pt;line-height:24pt;margin-bottom:0.25em}.mw-heading3,h3{font-size:14pt;line-height:20pt}.mw-heading4,h4,.mw-heading5,h5,.mw-heading6,h6{font-size:12pt;line-height:16pt}p{font-size:12pt;line-height:16pt;margin-top:5px;text-align:justify}p::before{content:'';display:block;width:120pt;overflow:hidden;page-break-after:avoid}blockquote{border-left:2px solid var(--color-emphasized,#101418);padding-left:20px}ol,ul{margin:10px 0 0 1.6em;padding:0}ol li,ul li{padding:2px 0;font-size:12pt}table ol li,table ul li{font-size:inherit}.toc{page-break-before:avoid;page-break-after:avoid;background:none;border:0;display:table}.toc a{border:0;font-weight:normal}.toc > ul > li{margin-bottom:4px;font-weight:bold}.toc ul{margin:0;list-style:none}.toc ul ul{padding-left:30px}.toc li.toclevel-1 > a{font-size:12pt;font-weight:bold}#mw-navigation,.noprint,.mw-jump-link,.mw-portlet-lang,.toc .tocnumber{display:none}.printfooter{margin-top:10px;border-top:3px solid var(--color-emphasized,#101418);padding-top:10px;font-size:10pt;clear:both}.mw-footer{margin-top:12px;border-top:1px solid #eee;padding-top:5px}#footer-info{margin:0;padding:0}#footer-info li{color:#999;list-style:none;display:block;padding-bottom:10px;font-size:10pt}#footer-info li a{color:#999 !important}#footer-info-lastmod{color:var(--color-emphasized,#101418);font-size:12pt;font-weight:bold}.vector-page-toolbar,.vector-header-start > *:not(.mw-logo),.vector-header-end,#mw-panel-toc,#vector-sticky-header,#p-lang-btn,.vector-menu-checkbox,nav,#vector-page-titlebar-toc,#footer{display:none !important}}"
  let html = "<html><head><style>" +
    css +
    "</style></head><body><nav id=\"menu\">Menu</nav></body></html>"
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let nav = node.children[0]
  inspect(nav.id, content="nav#menu")
  // nav should NOT be display:none (print rules should not apply)
  assert_true(nav.style.display != @types.Display::None)
}

///|
test "table width=85% constrains content within 85% of viewport" {
  let html =
    #|<html><body>
    #|<style>body { margin: 0; }</style>
    #|<center>
    #|<table width="85%" bgcolor="#f6f6ef">
    #|<tr><td>
    #|<table width="100%"><tr>
    #|<td>Hacker News new| past| comments| ask| show| jobs| submit</td>
    #|<td style="text-align:right">login</td>
    #|</tr></table>
    #|</td></tr>
    #|<tr><td>Long article title that should wrap within 85% of 800px viewport width</td></tr>
    #|</table>
    #|</center>
    #|</body></html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let (node, layout) = @renderer.render_to_node_and_layout(html, ctx)
  // Check center element
  let center_node = node.children[0]
  inspect(center_node.id, content="center")
  inspect(center_node.style.display, content="Block")
  // The table inside center
  let table_node = center_node.children[0]
  inspect(table_node.style.display, content="Table")
  inspect(
    table_node.style.width,
    content=(
      #|Percent(0.85)
    ),
  )
  // Layout: table should be ~680px (85% of 800)
  let center_layout = layout.children[0]
  let table_layout = center_layout.children[0]
  inspect(
    table_layout.width,
    content=(
      #|680
    ),
  )
}
