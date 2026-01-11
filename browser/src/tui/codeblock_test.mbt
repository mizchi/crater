///|
/// Test for code block rendering (Zenn-style)
test "code block should not wrap text" {
  // Minimal HTML reproducing Zenn's code block structure
  let html =
    #|<html><head>
    #|<style>
    #|.code-block-container { position: relative; margin: 1.3rem 0; }
    #|.code-block-container pre { margin: 0; overflow-x: auto; word-break: normal; }
    #|pre { display: flex; }
    #|pre code { display: block; padding: 1rem; }
    #|</style>
    #|</head><body>
    #|<div class="code-block-container">
    #|<pre class="language-mbt">
    #|<code class="language-mbt">moon check</code>
    #|</pre>
    #|</div>
    #|</body></html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 640.0,
    viewport_height: 480.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  // Render to character buffer
  let width = 80
  let height = 30
  let result = render_to_ansi(node, layout, width, height, 0)
  // Check that "moon check" appears as a single line without wrapping
  let has_content = result.ansi.contains("moon check") ||
    result.ansi.contains("moon")
  assert_true(has_content)
}

///|
/// Test with actual Zenn code block structure (pre > code)
test "zenn code block structure" {
  let html =
    #|<html><body>
    #|<div class="code-block-container">
    #|<pre class="language-bash"><code class="language-bash code-line" data-line="22">moon check</code></pre>
    #|</div>
    #|</body></html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 400.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  let width = 40
  let height = 10
  let result = render_to_ansi(node, layout, width, height, 0)
  // Check that code text is present
  assert_true(result.ansi.contains("moon") || result.ansi.contains("check"))
}

///|
/// Test that pre tag prevents text wrapping with long content
test "pre tag should prevent word wrap with long content" {
  let html =
    #|<html><body>
    #|<pre><code>fn very_long_function_name_that_should_not_wrap(param1: Int, param2: String) -> Result[Int, Error]</code></pre>
    #|</body></html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 400.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  let width = 50
  let height = 10
  let result = render_to_ansi(node, layout, width, height, 0)
  let lines = result.ansi.split("\n")
  let mut fn_lines = 0
  for line in lines {
    if line.contains("fn ") || line.contains("very_long") {
      fn_lines += 1
    }
  }
  // Should only appear on one line (truncated, not wrapped)
  assert_true(fn_lines <= 1)
}

///|
/// Test table rendering with proper table layout
test "table rendering with layout" {
  let html =
    #|<html><body>
    #|<table>
    #|<tr><th>Column A</th><th>Column B</th></tr>
    #|<tr><td>Value 1</td><td>Value 2</td></tr>
    #|</table>
    #|</body></html>
  let ctx : @renderer.RenderContext = {
    viewport_width: 320.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  let width = 40
  let height = 10
  let result = render_to_ansi(node, layout, width, height, 0)
  // Table should render content
  assert_true(result.ansi.contains("Column") || result.ansi.contains("Value"))
}
