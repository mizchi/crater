///|
test "banner_color_computation" {
  let html =
    #|<html><body class="banner">
    #|  <div class="_banner_nxrmc_1">Test Banner</div>
    #|  <div class="content">Normal content</div>
    #|</body></html>
  let css =
    #|._banner_nxrmc_1 { background: #38235c; color: #fff; }
    #|.content { color: #333; }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  // Print computed styles for debugging
  fn show_style(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    for child in n.children {
      show_style(child, depth + 1)
    }
  }

  show_style(node, 0)
}

///|
test "code_token_color" {
  // Test that .token.tag only applies color, not background
  let html =
    #|<html><body>
    #|  <pre class="highlight">
    #|    <span class="token tag">Tag</span>
    #|    <span class="token attr-name">Attr</span>
    #|  </pre>
    #|</body></html>
  let css =
    #|:root { --color-code-tag: #ff696d; }
    #|.token.tag, .token.attr-name { color: var(--color-code-tag); }
    #|.highlight { background: #1e1e1e; color: #d4d4d4; }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  // Print all nodes with their styles
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  show_all(node, 0)
}

///|
test "css_variable_in_background" {
  // Test if CSS variable color accidentally becomes background
  let html =
    #|<html><body>
    #|  <div class="page">
    #|    <p>Content text</p>
    #|  </div>
    #|</body></html>
  let css =
    #|:root { --code-color: #ff696d; }
    #|.page { background: transparent; }
    #|.token { color: var(--code-color); }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  show_all(node, 0)
  // .page should have transparent background (not #ff696d!)
}

///|
test "nested_background_inheritance" {
  // Test that text nodes don't inherit background incorrectly
  let html =
    #|<html><body>
    #|  <div class="colored-bg">
    #|    <p>Text inside colored div</p>
    #|    <span>Span text</span>
    #|  </div>
    #|</body></html>
  let css =
    #|.colored-bg { background-color: #ff696d; color: #ffffff; }
    #|p { margin: 16px 0; }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  show_all(node, 0)
}
