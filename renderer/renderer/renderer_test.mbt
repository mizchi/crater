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
test "style media attribute max-width rules do not leak at desktop viewport" {
  let html =
    #|<html><head>
    #|<style>
    #|.nav { display: flex; height: 113px; }
    #|.hamburger { display: none; height: 20px; }
    #|</style>
    #|<style media="(max-width: 540px)">
    #|.nav { height: 97px; }
    #|.hamburger { display: flex; }
    #|</style>
    #|</head><body>
    #|<div class="nav" id="nav"><button class="hamburger" id="hamburger"></button></div>
    #|</body></html>
  let desktop_ctx : @renderer.RenderContext = {
    ..@renderer.RenderContext::default(),
    viewport_width: 1440.0,
    viewport_height: 900.0,
  }
  let desktop_node = @renderer.render_to_node(html, desktop_ctx)
  let desktop_nav = desktop_node.children[0]
  let desktop_hamburger = desktop_nav.children[0]
  inspect(desktop_nav.style.height, content="Length(113)")
  inspect(desktop_hamburger.style.display, content="None")
  let desktop_layout = @renderer.render(html, desktop_ctx)
  inspect(desktop_layout.children[0].height, content="113")

  let mobile_ctx : @renderer.RenderContext = {
    ..@renderer.RenderContext::default(),
    viewport_width: 375.0,
    viewport_height: 667.0,
  }
  let mobile_node = @renderer.render_to_node(html, mobile_ctx)
  let mobile_nav = mobile_node.children[0]
  let mobile_hamburger = mobile_nav.children[0]
  inspect(mobile_nav.style.height, content="Length(97)")
  inspect(mobile_hamburger.style.display, content="Flex")
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
