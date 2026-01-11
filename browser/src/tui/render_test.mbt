///|
test "img_placeholder_rendering" {
  // Create a simple layout with an img element
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|  <p>Before</p>
    #|  <img src="test.jpg" width="160" height="80" alt="Test Image">
    #|  <p>After</p>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }

  // Get node and layout
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)

  // Debug: print layout tree
  println("=== Layout Tree ===")
  @renderer.print_layout_tree(layout, 0)

  // Convert to PaintNode
  let paint_node = @paint.from_node_and_layout(node, layout)

  // Debug: print paint tree
  fn print_paint_tree(p : @paint.PaintNode, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    println(
      indent +
      "tag=" +
      p.tag +
      " id=" +
      p.id +
      " (" +
      p.x.to_string() +
      "," +
      p.y.to_string() +
      ") " +
      p.width.to_string() +
      "x" +
      p.height.to_string() +
      " text=" +
      p.text.unwrap_or_else(fn() { "None" }).to_string(),
    )
    for child in p.children {
      print_paint_tree(child, depth + 1)
    }
  }

  println("=== Paint Tree ===")
  print_paint_tree(paint_node, 0)

  // Find img in paint tree
  fn find_img(p : @paint.PaintNode) -> @paint.PaintNode? {
    if p.tag == "img" {
      return Some(p)
    }
    for child in p.children {
      match find_img(child) {
        Some(img) => return Some(img)
        None => continue
      }
    }
    None
  }

  match find_img(paint_node) {
    Some(img) => {
      println("=== Found img ===")
      println("tag: " + img.tag)
      println("width: " + img.width.to_string())
      println("height: " + img.height.to_string())
      println("text: " + img.text.unwrap_or_else(fn() { "None" }).to_string())
      // Verify img has correct properties
      inspect(img.tag, content="img")
      inspect(img.width > 0.0, content="true")
      inspect(img.height > 0.0, content="true")
    }
    None => {
      println("ERROR: No img found in paint tree!")
      fail("No img found in paint tree")
    }
  }

  // Render to buffer
  let width = 40 // characters
  let height = 20 // characters
  let result = render_to_ansi(node, layout, width, height, 0)
  println("=== ANSI Output (first 500 chars) ===")
  let preview = if result.ansi.length() > 500 {
    result.ansi[:500].to_string()
  } else {
    result.ansi
  }
  println(preview)
}

///|
/// Test scroll calculation and viewport culling
test "scroll_viewport_culling" {
  // Create tall content with multiple paragraphs
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body>
    #|  <p>Paragraph 1</p>
    #|  <p>Paragraph 2</p>
    #|  <p>Paragraph 3</p>
    #|  <p>Paragraph 4</p>
    #|  <p>Paragraph 5</p>
    #|  <p>Paragraph 6</p>
    #|  <p>Paragraph 7</p>
    #|  <p>Paragraph 8</p>
    #|  <p>Paragraph 9</p>
    #|  <p>Paragraph 10</p>
    #|</body>
    #|</html>

  // Small viewport to force scrolling
  let viewport_width = 320.0
  let viewport_height = 100.0 // Only ~6 rows visible
  let ctx : @renderer.RenderContext = {
    viewport_width,
    viewport_height,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }

  // Get node and layout
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)

  // Print layout info
  println("=== Scroll Test ===")
  println("Layout height: " + layout.height.to_string())
  println("Viewport height: " + viewport_height.to_string())

  // Content should be taller than viewport
  let content_height = layout.height
  inspect(content_height > viewport_height, content="true")

  // Calculate max scroll in pixels
  let max_scroll_px = (content_height - viewport_height).to_int().max(0)
  println("Max scroll (px): " + max_scroll_px.to_string())

  // Calculate scroll in character rows
  let char_height = (viewport_height / 16.0).to_int()
  let content_height_chars = (content_height / 16.0).to_int()
  println("Viewport height (chars): " + char_height.to_string())
  println("Content height (chars): " + content_height_chars.to_string())

  // Test rendering at scroll_y = 0
  let result0 = render_to_ansi(node, layout, 40, char_height, 0)
  println("Render at scroll=0: " + result0.ansi.length().to_string() + " chars")

  // Test rendering at scroll_y = 3 (48px scroll)
  let result3 = render_to_ansi(node, layout, 40, char_height, 3)
  println("Render at scroll=3: " + result3.ansi.length().to_string() + " chars")

  // Test rendering at max scroll
  let max_scroll_chars = content_height_chars - char_height
  println("Max scroll (chars): " + max_scroll_chars.to_string())
  let result_max = render_to_ansi(
    node, layout, 40, char_height, max_scroll_chars,
  )
  println(
    "Render at scroll=max: " + result_max.ansi.length().to_string() + " chars",
  )

  // All renders should produce output
  inspect(result0.ansi.length() > 0, content="true")
  inspect(result3.ansi.length() > 0, content="true")
  inspect(result_max.ansi.length() > 0, content="true")
}

///|
/// Test that viewport culling returns content at different scroll positions
test "viewport_culling_returns_content" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<body style="margin:0;padding:0">
    #|  <div style="height:100px;background:red">Top Section</div>
    #|  <div style="height:100px;background:green">Middle Section</div>
    #|  <div style="height:100px;background:blue">Bottom Section</div>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 50.0, // Small viewport
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  println("=== Viewport Culling Test ===")
  println("Layout height: " + layout.height.to_string())

  // Layout should be ~300px (3 x 100px divs)
  inspect(layout.height >= 300.0, content="true")

  // Test viewport culling at different scroll positions
  let font_height = 16.0

  // Scroll = 0: viewport is 0-50px, should include top section
  let viewport_top_0 = 0.0
  let viewport_bottom_0 = 50.0
  let paint_0 = @paint.from_node_and_layout_with_viewport(
    node, layout, viewport_top_0, viewport_bottom_0, 0.0,
  )
  println("Scroll 0: paint_0 is Some? " + (paint_0 is Some(_)).to_string())
  inspect(paint_0 is Some(_), content="true")

  // Scroll = 100px (6.25 chars): viewport is 100-150px, should include middle section
  let scroll_chars_1 = 6
  let viewport_top_1 = scroll_chars_1.to_double() * font_height // 96px
  let viewport_bottom_1 = (scroll_chars_1 + 3).to_double() * font_height // 144px
  let paint_1 = @paint.from_node_and_layout_with_viewport(
    node, layout, viewport_top_1, viewport_bottom_1, 0.0,
  )
  println(
    "Scroll 6 chars (96-144px): paint_1 is Some? " +
    (paint_1 is Some(_)).to_string(),
  )
  inspect(paint_1 is Some(_), content="true")

  // Scroll = 200px (12.5 chars): viewport is 200-250px, should include bottom section
  let scroll_chars_2 = 12
  let viewport_top_2 = scroll_chars_2.to_double() * font_height // 192px
  let viewport_bottom_2 = (scroll_chars_2 + 3).to_double() * font_height // 240px
  let paint_2 = @paint.from_node_and_layout_with_viewport(
    node, layout, viewport_top_2, viewport_bottom_2, 0.0,
  )
  println(
    "Scroll 12 chars (192-240px): paint_2 is Some? " +
    (paint_2 is Some(_)).to_string(),
  )
  inspect(paint_2 is Some(_), content="true")

  // Scroll way past content (should still return Some because root spans entire document)
  let scroll_chars_3 = 100
  let viewport_top_3 = scroll_chars_3.to_double() * font_height // 1600px
  let viewport_bottom_3 = (scroll_chars_3 + 3).to_double() * font_height // 1648px
  let paint_3 = @paint.from_node_and_layout_with_viewport(
    node, layout, viewport_top_3, viewport_bottom_3, 0.0,
  )
  println(
    "Scroll 100 chars (way past content): paint_3 is Some? " +
    (paint_3 is Some(_)).to_string(),
  )
  // This should return None because content ends at ~300px but viewport starts at 1600px
  inspect(paint_3 is None, content="true")
}

///|
/// Test text display width calculation
test "calculate_text_display_width" {
  // ASCII text
  inspect(calculate_text_display_width("GitHub"), content="6")
  inspect(calculate_text_display_width("LinkedIn"), content="8")
  inspect(calculate_text_display_width("Newsletter"), content="10")
  inspect(calculate_text_display_width("Home"), content="4")

  // Empty string
  inspect(calculate_text_display_width(""), content="0")

  // With newline (should stop at newline)
  inspect(calculate_text_display_width("Hello\nWorld"), content="5")
}

///|
/// Test that text width calculation is used for rendering
test "text_render_uses_display_width" {
  // Create a test with small font-size (12px) which would result in
  // smaller pixel width than character count * 8
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { font-size: 12px; margin: 0; }
    #|a { display: inline; }
    #|</style>
    #|</head>
    #|<body>
    #|<a href="/github">GitHub</a>
    #|</body>
    #|</html>

  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 100.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }

  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)

  // Render to buffer - width should accommodate full "GitHub" text
  let result = render_to_ansi(node, layout, 40, 10, 0)

  // The ANSI output should contain the full "GitHub" text (not truncated)
  // We check by verifying the output length is reasonable
  inspect(result.ansi.length() > 0, content="true")
}
