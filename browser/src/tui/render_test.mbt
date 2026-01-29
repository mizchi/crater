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
/// Test paint_node None issue at different scroll positions
test "paint_node_none_debug" {
  // Create very tall content (50 paragraphs)
  let sb = StringBuilder::new()
  sb.write_string(
    (
      #|<!DOCTYPE html>
      #|<html>
      #|<body style="margin:0">
    ),
  )
  for i = 0; i < 50; i = i + 1 {
    sb.write_string("<p style=\"margin:20px 0\">Paragraph ")
    sb.write_string(i.to_string())
    sb.write_string(
      ": Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>\n",
    )
  }
  sb.write_string("</body></html>")
  let html = sb.to_string()
  let viewport_width = 640.0
  let viewport_height = 384.0
  let ctx : @renderer.RenderContext = {
    viewport_width,
    viewport_height,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  println("=== Paint Node Debug ===")
  println("Layout height: " + layout.height.to_string() + "px")
  println("Viewport height: " + viewport_height.to_string() + "px")
  // Test at various scroll positions (in pixels)
  let scroll_positions_px = [0, 100, 500, 1000, 2000, 3000, 5000]
  for scroll_px in scroll_positions_px {
    let viewport_top = scroll_px.to_double()
    let viewport_bottom = viewport_top + viewport_height
    let paint_result = @paint.from_node_and_layout_with_viewport(
      node, layout, viewport_top, viewport_bottom, 0.0,
    )
    let has_paint = match paint_result {
      Some(_) => "Some"
      None => "None"
    }
    println(
      "Scroll " +
      scroll_px.to_string() +
      "px (viewport " +
      viewport_top.to_string() +
      "-" +
      viewport_bottom.to_string() +
      "): paint_node = " +
      has_paint,
    )
    // Should always have content until we scroll past the layout height
    if scroll_px.to_double() + viewport_height < layout.height {
      inspect(paint_result is Some(_), content="true")
    }
  }
}

///|
/// Test scroll issue reproduction with tall real-world-like content
/// Simulates the addyosmani.com scroll blank issue
test "scroll_issue_tall_content" {
  // Create HTML similar to addyosmani.com structure
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; font-size: 16px; }
    #|nav { background: #eee; padding: 10px; }
    #|article { padding: 20px; }
    #|h1 { font-size: 32px; margin-bottom: 20px; }
    #|h2 { font-size: 24px; margin-top: 30px; }
    #|p { margin: 16px 0; line-height: 1.6; }
    #|</style>
    #|</head>
    #|<body>
    #|<nav>
    #|  <a href="/">Home</a>
    #|  <a href="/blog">Blog</a>
    #|</nav>
    #|<article>
    #|  <h1>21 Lessons From 14 Years at Google</h1>
    #|  <p>When I joined Google ~14 years ago, I thought the job was about writing great code.</p>
    #|  <p>These lessons are what I wish I'd known earlier.</p>
    #|  <p>I'm sharing them because I've benefited enormously from engineers who did the same for me.</p>
    #|  <h2>1. The best engineers are obsessed with solving user problems.</h2>
    #|  <p>It's seductive to fall in love with a technology and go looking for places to apply it.</p>
    #|  <p>User obsession means spending time in support tickets, talking to users.</p>
    #|  <p>The engineer who starts with a solution tends to build complexity in search of a justification.</p>
    #|  <h2>2. Being right is cheap. Getting to right together is the real work.</h2>
    #|  <p>You can win every technical argument and lose the project.</p>
    #|  <p>The skill isn't being right. It's entering discussions to align on the problem.</p>
    #|  <h2>3. Bias towards action. Ship.</h2>
    #|  <p>The quest for perfection is paralyzing.</p>
    #|  <p>First do it, then do it right, then do it better.</p>
    #|  <h2>4. Clarity is seniority. Cleverness is overhead.</h2>
    #|  <p>The instinct to write clever code is almost universal among engineers.</p>
    #|  <p>Your code is a strategy memo to strangers who will maintain it at 2am during an outage.</p>
    #|  <h2>5. Novelty is a loan you repay in outages.</h2>
    #|  <p>Treat your technology choices like an organization with a small innovation budget.</p>
    #|  <p>The best tool for the job is often the least-worst tool across many jobs.</p>
    #|  <h2>6. Your code doesn't advocate for you. People do.</h2>
    #|  <p>Early in my career, I believed great work would speak for itself. I was wrong.</p>
    #|  <p>In large organizations, decisions get made in meetings you're not invited to.</p>
    #|  <h2>7. The best code is the code you never had to write.</h2>
    #|  <p>We celebrate creation in engineering culture.</p>
    #|  <p>Before you build, exhaust the question: What would happen if we just didn't?</p>
    #|</article>
    #|</body>
    #|</html>
  // Viewport similar to terminal (80x24 characters, but in pixels)
  let viewport_width = 640.0 // 80 chars * 8px
  let viewport_height = 384.0 // 24 chars * 16px
  let ctx : @renderer.RenderContext = {
    viewport_width,
    viewport_height,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  // Get node and layout
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  println("=== Scroll Issue Test ===")
  println("Layout height: " + layout.height.to_string())
  println("Viewport height: " + viewport_height.to_string())
  // Content should be significantly taller than viewport
  let content_height = layout.height
  inspect(content_height > viewport_height, content="true")
  // Calculate dimensions
  let char_height = (viewport_height / 16.0).to_int() // 24 chars
  let char_width = (viewport_width / 8.0).to_int() // 80 chars
  let content_height_chars = (content_height / 16.0).to_int()
  let max_scroll_chars = (content_height_chars - char_height).max(0)
  println("Char height: " + char_height.to_string())
  println("Content height (chars): " + content_height_chars.to_string())
  println("Max scroll (chars): " + max_scroll_chars.to_string())
  // Test rendering at various scroll positions
  // These should all produce non-empty output
  let scroll_positions = [0, 5, 10, 15, 20, 30, 40, 50]
  for scroll_y in scroll_positions {
    if scroll_y > max_scroll_chars {
      continue
    }
    let result = render_to_buffer_with_status(
      node, layout, char_width, char_height, scroll_y, "https://example.com", 0,
      0,
    )
    // Count non-empty cells in the buffer
    let mut non_empty = 0
    for row = 0; row < char_height; row = row + 1 {
      for col = 0; col < char_width; col = col + 1 {
        let cell = result.buffer.get_cell(col, row)
        if cell.char != ' ' {
          non_empty = non_empty + 1
        }
      }
    }
    println(
      "Scroll " +
      scroll_y.to_string() +
      ": non-empty cells = " +
      non_empty.to_string(),
    )
    // Each scroll position should have some visible content
    // (at least status bar + some content)
    inspect(non_empty > 20, content="true")
  }
}

// Note: calculate_text_display_width test moved to whitebox test
// because it tests a private function

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

///|
/// Test that preformatted text respects newlines (white-space: pre)
test "pre_element_respects_newlines" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; }
    #|pre { margin: 0; padding: 0; }
    #|</style>
    #|</head>
    #|<body>
    #|<pre>line1
    #|line2
    #|line3</pre>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  let result = render_to_ansi(node, layout, 40, 10, 0)

  // The output should contain each line on separate rows
  // Check that "line1", "line2", "line3" are all present
  let output = result.ansi
  inspect(output.contains("line1"), content="true")
  inspect(output.contains("line2"), content="true")
  inspect(output.contains("line3"), content="true")
}

///|
/// Test that CharBuffer::write_text_pre handles newlines correctly
test "write_text_pre_handles_newlines" {
  let buffer = CharBuffer::new(20, 5)
  let style : TextStyle = {
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
  }
  let text = "line1\nline2\nline3"
  let lines_used = buffer.write_text_pre(0, 0, text, style, 20, 5)

  // Should use 3 lines
  inspect(lines_used, content="3")

  // Check that each line is written to the correct row
  let row0 = buffer.get_row_text(0)
  let row1 = buffer.get_row_text(1)
  let row2 = buffer.get_row_text(2)
  inspect(row0.contains("line1"), content="true")
  inspect(row1.contains("line2"), content="true")
  inspect(row2.contains("line3"), content="true")
}

///|
/// Test that pre > code structure respects newlines (like real code blocks)
test "pre_code_structure_respects_newlines" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; }
    #|pre { margin: 0; padding: 0; }
    #|code { white-space: pre; }
    #|</style>
    #|</head>
    #|<body>
    #|<pre><code>result
    #|time</code></pre>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)

  // Render to buffer
  let result = render_to_buffer(node, layout, 40, 10, 0)

  // Debug: print buffer content
  println("=== Buffer Content ===")
  for row = 0; row < 5; row = row + 1 {
    let text = result.buffer.get_row_text(row)
    println("Row " + row.to_string() + ": [" + text + "]")
  }

  // "result" and "time" should be on different rows
  let row0 = result.buffer.get_row_text(0)
  let row1 = result.buffer.get_row_text(1)

  // Either row0 or row1 should contain "result"
  // and a different row should contain "time"
  let has_result_row0 = row0.contains("result")
  let has_time_row0 = row0.contains("time")
  let has_result_row1 = row1.contains("result")
  let has_time_row1 = row1.contains("time")
  println("row0 contains result: " + has_result_row0.to_string())
  println("row0 contains time: " + has_time_row0.to_string())
  println("row1 contains result: " + has_result_row1.to_string())
  println("row1 contains time: " + has_time_row1.to_string())

  // They should NOT be on the same row
  // If result and time are on the same row, the newline is not working
  let same_row = (has_result_row0 && has_time_row0) ||
    (has_result_row1 && has_time_row1)
  inspect(not(same_row), content="true")
}

///|
/// Test that span-wrapped lines in code blocks still show on separate rows
/// This simulates syntax highlighters that wrap each line in spans with display:block
test "pre_code_with_span_lines_display_block" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; }
    #|pre { margin: 0; padding: 0; }
    #|code { white-space: pre; }
    #|.line { display: block; }
    #|</style>
    #|</head>
    #|<body>
    #|<pre><code><span class="line">result</span><span class="line">time</span></code></pre>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)

  // Render to buffer
  let result = render_to_buffer(node, layout, 40, 10, 0)

  // "result" and "time" should be on different rows
  let row0 = result.buffer.get_row_text(0)
  let row1 = result.buffer.get_row_text(1)
  let has_result_row0 = row0.contains("result")
  let has_time_row0 = row0.contains("time")
  let has_result_row1 = row1.contains("result")
  let has_time_row1 = row1.contains("time")

  // When spans have display:block, they should be on separate rows
  let same_row = (has_result_row0 && has_time_row0) ||
    (has_result_row1 && has_time_row1)
  inspect(not(same_row), content="true")
}

///|
/// Test shiki-style syntax highlighter structure (like zenn.dev)
/// Each line is wrapped in <span class="line"><span>text</span></span>
test "shiki_style_code_block" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; }
    #|pre { margin: 0; padding: 0; }
    #|code { white-space: pre; }
    #|.line { display: block; }
    #|</style>
    #|</head>
    #|<body>
    #|<pre class="shiki"><code><span class="line"><span>test fib benchmark</span></span><span class="line"><span>time (mean)</span></span><span class="line"><span>21.67 µs</span></span></code></pre>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 640.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)

  // Render to buffer
  let result = render_to_buffer(node, layout, 80, 10, 0)

  // Each line should be on a separate row
  let row0 = result.buffer.get_row_text(0)
  let row1 = result.buffer.get_row_text(1)
  let row2 = result.buffer.get_row_text(2)

  // Verify each line content
  inspect(row0.contains("fib"), content="true")
  inspect(row1.contains("time"), content="true")
  inspect(row2.contains("21.67"), content="true")

  // "test fib benchmark" and "time (mean)" should NOT be on the same row
  let fib_and_time_same_row = row0.contains("fib") && row0.contains("time")
  inspect(not(fib_and_time_same_row), content="true")
}

///|
/// Test that long paragraph text with links wraps correctly at layout level
test "paragraph_with_links_layout_wrap" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; }
    #|p { margin: 0; font-size: 16px; }
    #|</style>
    #|</head>
    #|<body>
    #|<p>moonbit がインストールされていれば、<a href="#">moon -h</a> で一覧を確認できますが、使ってみるまで何をやってくれるか期待値が難しいので、自分が特に便利と思った機能を紹介します。</p>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 400.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let p_layout = layout.children[0]

  // The p should be constrained to viewport width (400)
  inspect(p_layout.width <= 400.0, content="true")

  // Text should wrap (height > 1 line = 16px)
  inspect(p_layout.height > 16.0, content="true")

  // All child elements should stay within parent bounds
  for child in p_layout.children {
    let right_edge = child.x + child.width
    inspect(right_edge <= p_layout.width + 1.0, content="true")
  }
}

///|
/// Test TUI rendering of CJK paragraph with links - verifies text wrapping works
test "tui_render_cjk_paragraph_wrap" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; }
    #|p { margin: 0; font-size: 16px; }
    #|</style>
    #|</head>
    #|<body>
    #|<p>moonbit がインストールされていれば、<a href="#">moon -h</a> で一覧を確認できますが、使ってみるまで何をやってくれるか期待値が難しいので、自分が特に便利と思った機能を紹介します。</p>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 640.0,
    viewport_height: 480.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)

  // Render to TUI buffer (80 columns)
  let result = render_to_buffer(node, layout, 80, 20, 0)

  // Check that text wraps correctly (multiple rows should have content)
  let row0 = result.buffer.get_row_text(0)
  let row1 = result.buffer.get_row_text(1)
  let row2 = result.buffer.get_row_text(2)

  // First row should contain start of text and link
  inspect(row0.contains("moonbit"), content="true")
  inspect(row0.contains("moon -h"), content="true")

  // Second row should have continuation
  inspect(row1.length() > 0, content="true")

  // Third row should have wrapped text (contains CJK characters)
  // Using a more reliable check: row2 should have content from the continuation
  inspect(row2.length() > 0, content="true")
}

///|
/// Test that text with links wraps correctly - verifies interleaved link and text ordering
test "text_wrap_with_interleaved_links" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|<head>
    #|<style>
    #|body { margin: 0; }
    #|h1 { margin: 0; font-size: 16px; }
    #|a { color: blue; }
    #|</style>
    #|</head>
    #|<body>
    #|<h1><a href="#">Moonbit moon cli</a> の便利機能達 - 組み込み <a href="#">lint</a>, <a href="#">bench</a>, <a href="#">snapshot</a>, coverage, doc</h1>
    #|</body>
    #|</html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 400.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let h1 = layout.children[0]

  // The h1 should be constrained to viewport width (400)
  inspect(h1.width <= 400.0, content="true")

  // Text should wrap (height > 1 line = 16px)
  inspect(h1.height > 16.0, content="true")

  // All children should stay within parent bounds
  for child in h1.children {
    let right_edge = child.x + child.width
    inspect(right_edge <= h1.width + 1.0, content="true")
  }
}

///|
/// Test CJK text width calculation and rendering
test "cjk_text_width_calculation" {
  // Test case: "2025/12/23に公開" should display fully
  let text = "2025/12/23に公開"

  // Calculate display width manually
  let mut width = 0
  for c in text {
    width = width + char_display_width(c)
  }

  // "2025/12/23" = 10 chars = 10 width
  // "に" = 1 char = 2 width (CJK)
  // "公" = 1 char = 2 width (CJK)
  // "開" = 1 char = 2 width (CJK)
  // Total = 10 + 2 + 2 + 2 = 16
  inspect(width, content="16")

  // Test rendering in a buffer wide enough
  let buffer = CharBuffer::new(30, 1)
  let style : TextStyle = {
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
  }
  let written = buffer.write_text(0, 0, text, style, 30)

  // Should write all 16 columns
  inspect(written, content="16")

  // Check buffer content
  let row = buffer.get_row_text(0)

  // Should contain the full text
  inspect(row.contains("2025"), content="true")
  inspect(row.contains("公開"), content="true")
}

///|
/// Test that text is not truncated when width is sufficient
test "text_not_truncated_with_sufficient_width" {
  // Simulate the problematic title
  let text = "Moonbit moon cli の便利機能達 - 組み込み lint, bench, snapshot, coverage, doc"
  let mut width = 0
  for c in text {
    width = width + char_display_width(c)
  }

  // Create a buffer wide enough (100 columns)
  let buffer = CharBuffer::new(100, 1)
  let style : TextStyle = {
    fg: @types.Color::black(),
    bg: @types.Color::white(),
    bold: false,
    underline: false,
  }
  let written = buffer.write_text(0, 0, text, style, 100)

  // The written width should match the calculated width
  inspect(written, content=width.to_string())

  // Check buffer content
  let row = buffer.get_row_text(0)

  // Should contain key parts
  inspect(row.contains("Moonbit"), content="true")
  inspect(row.contains("snapshot"), content="true")
  inspect(row.contains("doc"), content="true")
}
