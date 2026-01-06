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

///|
test "trace_preact_full_css" {
  // Test with more realistic preact CSS including error colors
  let html =
    #|<html><body class="banner">
    #|  <div id="app">
    #|    <header class="_header_nxrmc_38">
    #|      <div class="_banner_nxrmc_1">Banner text</div>
    #|    </header>
    #|    <main>
    #|      <div class="_page_sqynl_1">
    #|        <h1>Title</h1>
    #|      </div>
    #|    </main>
    #|  </div>
    #|</body></html>
  // CSS with error colors that might be causing issues
  let css =
    #|:root {
    #|  --color-page-bg: white;
    #|  --color-error-bg: #ffeddb;
    #|  --color-error-heading: #f43678;
    #|  --color-brand: #673ab8;
    #|}
    #|._header_nxrmc_38 { background: var(--color-brand); }
    #|._banner_nxrmc_1 { background: #38235c; color: #fff; }
    #|._page_sqynl_1 { background: var(--color-page-bg); }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 450.0,
    root_font_size: 16.0,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    if bg.a > 0.0 {
      println(
        indent +
        "** " +
        n.id +
        " bg=" +
        bg.to_hex() +
        " r=" +
        bg.r.to_string() +
        " **",
      )
    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  println("=== Full preact CSS test ===")
  show_all(node, 0)
}

///|
test "trace_error_color_check" {
  // Test if error-heading color might be incorrectly used as background
  // This specifically checks if #f43678 could somehow become a background color
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
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    let fg = n.style.color
    // Show all nodes with their colors
    let bg_str = if bg.a > 0.0 { " bg=" + bg.to_hex() } else { "" }
    println(indent + n.id + " color=" + fg.to_hex() + bg_str)
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  println("=== Error color check ===")
  show_all(node, 0)
  // Key check: error-heading should have color=#f43678, NOT background=#f43678
  // error-section should have background=#ffeddb (not #f43678)
}

///|
test "trace_complex_preact_css" {
  // More comprehensive test mimicking preact's actual CSS structure
  let html =
    #|<html><body>
    #|  <div id="__next">
    #|    <header class="_header_nxrmc_38">
    #|      <nav class="_nav_nxrmc_100">
    #|        <a href="#">Link 1</a>
    #|        <a href="#">Link 2</a>
    #|      </nav>
    #|    </header>
    #|    <main class="_main_sqynl_1">
    #|      <section class="_hero_abc_1">
    #|        <h1>Preact</h1>
    #|        <p>Fast 3kB alternative</p>
    #|      </section>
    #|      <section class="_features_def_1">
    #|        <div class="_feature_card">
    #|          <h3>Feature 1</h3>
    #|        </div>
    #|      </section>
    #|    </main>
    #|  </div>
    #|</body></html>
  // CSS that mimics preact's structure with multiple variables
  let css =
    #|:root {
    #|  --color-brand: #673ab8;
    #|  --color-page-bg: #ffffff;
    #|  --color-text: #333333;
    #|  --color-heading: #1a1a1a;
    #|  --color-link: #673ab8;
    #|  --color-code-tag: #ff696d;
    #|  --color-error-heading: #f43678;
    #|  --color-error-bg: #ffeddb;
    #|}
    #|body { background: var(--color-page-bg); color: var(--color-text); }
    #|._header_nxrmc_38 { background: var(--color-brand); }
    #|._nav_nxrmc_100 a { color: white; }
    #|._main_sqynl_1 { background: var(--color-page-bg); }
    #|._hero_abc_1 h1 { color: var(--color-heading); }
    #|._feature_card { background: #f5f5f5; }
  let ctx : RenderContext = {
    viewport_width: 375.0,
    viewport_height: 800.0,
    root_font_size: 16.0,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    let fg = n.style.color
    // Only show nodes with background colors or specific classes
    let bg_str = if bg.a > 0.0 { " bg=" + bg.to_hex() } else { "" }
    // Check for any red/pink colors (#f4, #ff6, etc)
    let is_red_ish = bg.r > 200 && bg.g < 150 && bg.b < 150 && bg.a > 0.0
    let warning = if is_red_ish { " [RED BACKGROUND!]" } else { "" }
    if bg.a > 0.0 || is_red_ish {
      println(indent + n.id + " color=" + fg.to_hex() + bg_str + warning)
    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  println("=== Complex preact CSS test ===")
  show_all(node, 0)
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
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    // Check for any red/pink colors
    let is_red_ish = bg.r > 200 && bg.g < 150 && bg.b < 150 && bg.a > 0.0
    let warning = if is_red_ish { " [RED! BUG!]" } else { "" }
    // Show element with background info
    if n.id.contains("loading") || bg.a > 0.0 {
      println(
        indent +
        n.id +
        " bg=" +
        bg.to_hex() +
        " (a=" +
        bg.a.to_string() +
        ")" +
        warning,
      )
    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  println("=== Loading bar pseudo-element test ===")
  show_all(node, 0)
  // The loading-bar element should NOT have the #f2777a background
  // because that style is only for ::after pseudo-element which we don't render
}

///|
test "trace_preact_actual_structure" {
  // Test with the actual structure from preactjs.com debug output
  let html =
    #|<html><body class="banner">
    #|  <div id="app">
    #|    <header class="_header_nxrmc_38">
    #|      <div class="_banner_nxrmc_1"></div>
    #|      <div class="_outer_nxrmc_24">
    #|        <div class="_inner_nxrmc_301">
    #|          <nav>Navigation</nav>
    #|        </div>
    #|      </div>
    #|    </header>
    #|    <main>
    #|      <loading-bar></loading-bar>
    #|      <div class="_page_sqynl_1">
    #|        <div class="_outer_sqynl_111">
    #|          <div class="_inner_sqynl_59">
    #|            <content-region>
    #|              <div class="markup">
    #|                <header class="_jumbotron_1267f_1">
    #|                  <div class="_stripes_1267f_37"></div>
    #|                  <div class="_content_1267f_57">
    #|                    <h1>Preact</h1>
    #|                  </div>
    #|                </header>
    #|                <div class="highlight-container">
    #|                  <pre class="highlight">code here</pre>
    #|                </div>
    #|              </div>
    #|            </content-region>
    #|          </div>
    #|        </div>
    #|      </div>
    #|    </main>
    #|  </div>
    #|</body></html>
  // Simulated preact CSS (based on actual variable names)
  let css =
    #|:root {
    #|  --color-brand: #673ab8;
    #|  --color-brand-light: #9c6fd6;
    #|  --color-page-bg: #ffffff;
    #|  --color-text: #434343;
    #|  --color-heading: #1a1a1a;
    #|  --color-code-inline-bg: #e4e2f2;
    #|  --color-code-block-bg: #1e1e1e;
    #|  --color-code-tag: #ff696d;
    #|  --color-code-keyword: #c586c0;
    #|  --color-error-heading: #f43678;
    #|  --color-error-bg: #ffeddb;
    #|}
    #|body { background: var(--color-page-bg); color: var(--color-text); }
    #|._header_nxrmc_38 { background: var(--color-brand); }
    #|._banner_nxrmc_1 { background: #38235c; color: #fff; }
    #|._page_sqynl_1 { background: var(--color-page-bg); }
    #|._jumbotron_1267f_1 { background: linear-gradient(135deg, #673ab8, #38235c); }
    #|._stripes_1267f_37 { background: repeating-linear-gradient(135deg, transparent, transparent 8px, rgba(255,255,255,0.1) 8px, rgba(255,255,255,0.1) 16px); }
    #|.highlight-container { background: var(--color-code-block-bg); }
    #|pre.highlight { background: var(--color-code-block-bg); color: #d4d4d4; }
  let ctx : RenderContext = {
    viewport_width: 640.0,
    viewport_height: 800.0,
    root_font_size: 16.0,
  }
  let node = render_to_node_with_external_css(html, ctx, [css])
  fn show_all(n : @node.Node, depth : Int) -> Unit {
    let indent = String::make(depth * 2, ' ')
    let bg = n.style.background_color
    let fg = n.style.color
    // Check for any red/pink colors
    let is_red_ish = bg.r > 200 && bg.g < 150 && bg.b < 150 && bg.a > 0.0
    let warning = if is_red_ish { " [RED!]" } else { "" }
    // Show all with background or if red
    if bg.a > 0.0 {
      println(
        indent +
        n.id +
        " bg=" +
        bg.to_hex() +
        " (r=" +
        bg.r.to_string() +
        ",g=" +
        bg.g.to_string() +
        ",b=" +
        bg.b.to_string() +
        ")" +
        warning,
      )
    }
    for child in n.children {
      show_all(child, depth + 1)
    }
  }

  println("=== Preact actual structure ===")
  show_all(node, 0)
}
