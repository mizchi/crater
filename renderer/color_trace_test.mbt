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
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let bg_hex = n.style.background_color.to_hex()
    // Only show non-transparent backgrounds
    if n.style.background_color.a > 0.0 {
      println(indent + "** " + n.id + " bg=" + bg_hex + " **")
    } else {
      println(indent + n.id + " color=" + n.style.color.to_hex())
    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  println("=== Preact-like structure ===")
  show_all(node, 0)
}
