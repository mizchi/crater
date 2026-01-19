///|
test "inline_block_wide_viewport_layout" {
  // Wide viewport - text and address should be on same line
  let html =
    #|<html><body>
    #|<div class="blogMeta">
    #|  <time class="time">2022/9/24</time>, written by
    #|  <address class="authors">Joachim Viide</address>
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
  let layout = render_with_external_css(html, ctx, [css])
  let container = layout.children[0]
  guard container.children.length() == 2 else { fail("Expected 2 children") }
  let text_layout = container.children[0]
  let address_layout = container.children[1]
  // Text and address should be on the same TUI row
  let text_row = (text_layout.y / 16.0).to_int()
  let address_row = (address_layout.y / 16.0).to_int()
  inspect(text_row, content="0")
  inspect(address_row, content="0")
  // Address should start after text (x >= text.x + text.width)
  guard address_layout.x >= text_layout.x + text_layout.width else {
    fail("Address should follow text horizontally")
  }
  // Text content should be first
  guard text_layout.text == Some("2022/9/24, written by") else {
    fail("Text content mismatch")
  }
}

///|
test "inline_block_narrow_viewport_wraps" {
  // Narrow viewport - address should wrap to new line
  let html =
    #|<html><body>
    #|<div class="blogMeta">
    #|  <time class="time">2022/9/24</time>, written by
    #|  <address class="authors">Joachim Viide</address>
    #|</div>
    #|</body></html>
  let css =
    #|.authors { display: inline-block; }
  let ctx : RenderContext = {
    viewport_width: 200.0,
    viewport_height: 400.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = render_with_external_css(html, ctx, [css])
  let container = layout.children[0]
  let text_layout = container.children[0]
  let address_layout = container.children[1]
  // Text should be on row 0
  let text_row = (text_layout.y / 16.0).to_int()
  inspect(text_row, content="0")
  // Address should be on row 1 (wrapped to new line)
  let address_row = (address_layout.y / 16.0).to_int()
  inspect(address_row, content="1")
  // Address should be at x=0 (start of new line)
  inspect(address_layout.x.to_int(), content="0")
}

///|
test "inline_block_very_narrow_text_wraps" {
  // Very narrow viewport - text itself wraps, then address
  let html =
    #|<html><body>
    #|<div class="blogMeta">
    #|  <time class="time">2022/9/24</time>, written by
    #|  <address class="authors">Joachim Viide</address>
    #|</div>
    #|</body></html>
  let css =
    #|.authors { display: inline-block; }
  let ctx : RenderContext = {
    viewport_width: 120.0, // 15 columns
    viewport_height: 400.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = render_with_external_css(html, ctx, [css])
  let container = layout.children[0]
  let text_layout = container.children[0]
  let address_layout = container.children[1]
  // Text should start at row 0 and wrap (height > 16)
  let text_row = (text_layout.y / 16.0).to_int()
  inspect(text_row, content="0")
  guard text_layout.height > 16.0 else { fail("Text should wrap") }
  // Address should be after text (row 2 since text takes 2 rows)
  let address_row = (address_layout.y / 16.0).to_int()
  inspect(address_row, content="2")
}

///|
test "preactjs_actual_css_both_inline_block" {
  // Reproduce preactjs.com's actual CSS where BOTH time and address are inline-block
  let html =
    #|<html><body>
    #|<div class="blogMeta">
    #|  <time class="time">9/24/2022</time>, written by
    #|  <address class="authors"><span><a href="#">Joachim Viide</a></span></address>
    #|</div>
    #|</body></html>
  let css =
    #|.time { font-size: 1rem; display: inline-block; }
    #|.authors { display: inline-block; }
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 400.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  let layout = render_with_external_css(html, ctx, [css])
  println("=== Preactjs actual CSS test ===")
  fn show_layout(l : @node.Layout, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let text_str = match l.text {
      Some(t) => " \"" + t + "\""
      None => ""
    }
    let row = (l.y / 16.0).to_int()
    let col = (l.x / 8.0).to_int()
    println(
      indent +
      l.id +
      " (col=" +
      col.to_string() +
      " row=" +
      row.to_string() +
      " x=" +
      l.x.to_string() +
      " y=" +
      l.y.to_string() +
      ")" +
      text_str,
    )
    for child in l.children {
      show_layout(child, depth + 1)
    }
  }

  show_layout(layout, 0)
  println("\n=== Node display types ===")
  fn show_node(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    println(indent + n.id + " [" + n.style.display.to_string() + "]")
    for child in n.children {
      show_node(child, depth + 1)
    }
  }

  show_node(node, 0)
  // Verify the structure
  let container = layout.children[0]
  guard container.children.length() >= 2 else {
    fail(
      "Expected at least 2 children, got " +
      container.children.length().to_string(),
    )
  }
  // Find time and address elements
  println("\nChildren analysis:")
  for i, child in container.children {
    let row = (child.y / 16.0).to_int()
    let col = (child.x / 8.0).to_int()
    println(
      "  [" +
      i.to_string() +
      "] " +
      child.id +
      " at (col=" +
      col.to_string() +
      ", row=" +
      row.to_string() +
      ")",
    )
  }
}
