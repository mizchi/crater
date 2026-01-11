///|
test "inline_block_rendering" {
  let html =
    #|<html><body>
    #|<div class="blogMeta">
    #|  <time class="time" datetime="2022-09-23T15:00:00.000Z">2022/9/24</time>, written by
    #|  <address class="authors"><span><a href="#">Joachim Viide</a></span></address>
    #|</div>
    #|</body></html>
  let css =
    #|.authors { display: inline-block; }
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 400.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let display = n.style.display.to_string()
    let text_content = n.text.unwrap_or("")
    let text_str = if text_content.length() > 0 {
      " \"" + text_content + "\""
    } else {
      ""
    }
    println(indent + n.id + " [" + display + "]" + text_str)
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  println("=== Node tree ===")
  show_all(node, 0)
  // Verify structure
  guard node.id == "body" else { fail("Expected body") }
  let blogMeta = node.children[0]
  guard blogMeta.id == "div.blogMeta" else { fail("Expected div.blogMeta") }
  // Should have 2 children: text and address
  guard blogMeta.children.length() == 2 else {
    fail("Expected 2 children, got \{blogMeta.children.length()}")
  }
  // First child is inline text
  let text_node = blogMeta.children[0]
  guard text_node.style.display == @style.Inline else {
    fail("Text should be Inline")
  }
  guard text_node.text.unwrap_or("") == "2022/9/24, written by" else {
    fail("Unexpected text content")
  }
  // Second child is inline-block address
  let address_node = blogMeta.children[1]
  guard address_node.style.display == @style.InlineBlock else {
    fail("Address should be InlineBlock")
  }
}

///|
test "inline_block_layout" {
  let html =
    #|<html><body>
    #|<div class="container">
    #|  <time>2022/9/24</time>, written by
    #|  <address class="author">Author Name</address>
    #|</div>
    #|</body></html>
  let css =
    #|.container { width: 400px; }
    #|.author { display: inline-block; }
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 400.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = render_with_external_css(html, ctx, [css])
  println("=== Layout ===")
  fn show_layout(l : @node.Layout, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    println(indent + l.id + " x=\{l.x} y=\{l.y} w=\{l.width} h=\{l.height}")
    for child in l.children {
      show_layout(child, depth + 1)
    }
  }

  show_layout(layout, 0)
  // Container should have single line height (text + inline-block on same line)
  let container = layout.children[0]
  guard container.id == "div.container" else { fail("Expected container") }
  // Verify that text and address are on the same line
  guard container.children.length() == 2 else { fail("Expected 2 children") }
  let text_layout = container.children[0]
  let address_layout = container.children[1]
  // Both should start near y=0 (on same baseline)
  guard text_layout.y < 10.0 && address_layout.y < 10.0 else {
    fail("Text and address should be on same line")
  }
  // Address should start after text (x > 0)
  guard address_layout.x > 0.0 else { fail("Address should follow text") }
}
