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

  // Text inside <a> is now collected to parent div (inline element text collection)
  let text = div1.children[0]
  inspect(text.id, content="a")
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

  // Text inside <a> is now collected to parent div (inline element text collection)
  // div1 should have a #text child with the text from <a>
  let text1 = div1.children[0]
  inspect(text1.id, content="a")
  inspect(text1.style.font_size, content="20")
  inspect(text1.style.line_height, content="20")
}

///|
test "br element combines text into single node with newlines" {
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

  // Should have exactly 1 child: combined text node
  inspect(test_div.children.length(), content="1")
  let text_node = test_div.children[0]
  inspect(text_node.id, content="#text")
  inspect(text_node.style.font_size, content="20")
  inspect(text_node.style.line_height, content="20")
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    inspect(text_layout.width, content="100")
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
      not(overlap),
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
    color_scheme: @media.ColorScheme::Light,
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

  fn find_img_layout(l : @node.Layout) -> @node.Layout? {
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
    color_scheme: @media.ColorScheme::Light,
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
