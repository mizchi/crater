///|
test "trace_dark_mode_css_variables" {
  // Test that CSS variables correctly update based on color scheme
  let html =
    #|<html><body>
    #|  <h1>Title</h1>
    #|  <p>Content text here</p>
    #|</body></html>
  let css =
    #|:root {
    #|  --text-color: #333333;
    #|  --bg-color: #ffffff;
    #|}
    #|@media (prefers-color-scheme: dark) {
    #|  :root {
    #|    --text-color: #eeeeee;
    #|    --bg-color: #1a1a1a;
    #|  }
    #|}
    #|body { color: var(--text-color); background: var(--bg-color); }
    #|h1 { color: var(--text-color); }
    #|p { color: var(--text-color); }

  // Light mode
  let light_ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let light_node = render_to_node_with_external_css(html, light_ctx, [css])
  // Light mode: text should be dark (#333333), background should be white (#ffffff)
  assert_eq(light_node.style.color.to_hex(), "#333333")
  assert_eq(light_node.style.background_color.to_hex(), "#ffffff")

  // Dark mode
  let dark_ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Dark,
  }
  let dark_node = render_to_node_with_external_css(html, dark_ctx, [css])
  // Dark mode: text should be light (#eeeeee), background should be dark (#1a1a1a)
  assert_eq(dark_node.style.color.to_hex(), "#eeeeee")
  assert_eq(dark_node.style.background_color.to_hex(), "#1a1a1a")
}

///|
test "trace_preact_css" {
  // Simplified HTML that mimics preactjs.com structure
  let html =
    #|<html><body class="banner">
    #|  <div id="app">
    #|    <header class="_header_nxrmc_38">
    #|      <div class="_banner_nxrmc_1">
    #|        <a href="#">Edit this Page</a>
    #|        <span>Ukraine. Show your support</span>
    #|      </div>
    #|    </header>
    #|    <main>
    #|      <div class="_page_sqynl_1">
    #|        <h1>Signal Boosting</h1>
    #|        <p>The new release...</p>
    #|      </div>
    #|    </main>
    #|  </div>
    #|</body></html>
  // Simplified CSS based on preact's actual CSS
  let css =
    #|:root {
    #|  --color-code-tag: #ff696d;
    #|  --color-page-bg: white;
    #|}
    #|._banner_nxrmc_1 { background: #38235c; color: #fff; }
    #|._banner_nxrmc_1 a { color: #fff; }
    #|._page_sqynl_1 { background: var(--color-page-bg); }
    #|.token.tag { color: var(--color-code-tag); }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    // Only show non-transparent backgrounds
    if bg.a > 0.0 {

    } else {

    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  show_all(node, 0)
}

///|
test "trace_error_color_check" {
  // Test if error-heading color might be incorrectly used as background
  let html =
    #|<html><body>
    #|  <div class="error-section">
    #|    <h2 class="error-heading">Error Message</h2>
    #|    <p class="error-text">Something went wrong</p>
    #|  </div>
    #|  <div class="normal-section">
    #|    <h2>Normal Heading</h2>
    #|  </div>
    #|</body></html>
  let css =
    #|:root {
    #|  --color-error-bg: #ffeddb;
    #|  --color-error-heading: #f43678;
    #|  --color-text: #333;
    #|}
    #|.error-section { background: var(--color-error-bg); }
    #|.error-heading { color: var(--color-error-heading); }
    #|.error-text { color: var(--color-text); }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    let _ = n.style.color
    let _ = if bg.a > 0.0 { " bg=" + bg.to_hex() } else { "" }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  show_all(node, 0)
  // Key check: error-heading should have color=#f43678, NOT background=#f43678
  // error-section should have background=#ffeddb (not #f43678)
}

///|
test "trace_loading_bar_pseudo_element" {
  // Test that ::after pseudo-element styles are NOT applied to the actual element
  let html =
    #|<html><body>
    #|  <main>
    #|    <loading-bar></loading-bar>
    #|    <div class="content">Content here</div>
    #|  </main>
    #|</body></html>
  // CSS from preact that was causing the red background
  let css =
    #|loading-bar {
    #|  position: fixed;
    #|  top: 0;
    #|  left: 0;
    #|  right: 0;
    #|  height: 5px;
    #|}
    #|loading-bar:after {
    #|  content: "";
    #|  display: block;
    #|  height: 100%;
    #|  width: 75%;
    #|  background: #f2777a;
    #|  transform: translate(-100%);
    #|}
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 800.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    // Check for any red/pink colors
    let is_red_ish = bg.r > 200 && bg.g < 150 && bg.b < 150 && bg.a > 0.0
    let _ = if is_red_ish { " [RED! BUG!]" } else { "" }
    // Show element with background info
    if n.id.contains("loading") || bg.a > 0.0 {

    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  show_all(node, 0)
  // The loading-bar element should NOT have the #f2777a background
  // because that style is only for ::after pseudo-element which we don't render
}

///|
test "trace_gradient_fallback" {
  // Test that gradients fall back to transparent, not black
  let html =
    #|<html><body class="banner">
    #|  <header class="_jumbotron_1267f_1">
    #|    <div class="_stripes_1267f_37"></div>
    #|    <div class="_content_1267f_57">
    #|      <h1>Preact</h1>
    #|    </div>
    #|  </header>
    #|  <div class="highlight-container">
    #|    <pre class="highlight">code here</pre>
    #|  </div>
    #|</body></html>
  let css =
    #|:root {
    #|  --color-page-bg: #ffffff;
    #|  --color-code-block-bg: #1e1e1e;
    #|}
    #|body { background: var(--color-page-bg); }
    #|._jumbotron_1267f_1 { background: linear-gradient(135deg, #673ab8, #38235c); }
    #|._stripes_1267f_37 { background: repeating-linear-gradient(135deg, transparent, transparent 8px, rgba(255,255,255,0.1) 8px, rgba(255,255,255,0.1) 16px); }
    #|.highlight-container { background: var(--color-code-block-bg); }
    #|pre.highlight { background: var(--color-code-block-bg); color: #d4d4d4; }
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 800.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let _ = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    // Gradients should fall back to transparent (a=0), not black
    let is_black = bg.r == 0 && bg.g == 0 && bg.b == 0 && bg.a > 0.0
    let _ = if is_black { " [BLACK! gradient fallback bug]" } else { "" }
    if bg.a > 0.0 || n.id.contains("jumbotron") || n.id.contains("stripes") {

    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  show_all(node, 0)
  // Gradient elements should have transparent background (a=0)
  // not black background (which was the old buggy behavior)
}
