///|
// CSS selector and media renderer regression tests split from renderer_test.mbt.

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
  let sidebar = node.children[0]
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
  let sidebar = node.children[0]
  inspect(sidebar.id, content="div#side")
  assert_true(sidebar.style.display != @types.Display::None)
}

///|
test "CSS class on html element affects body descendants via cascade" {
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
  let container = node.children[0]
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
  inspect(nav.style.display, content="None")
}

///|
test "Wikipedia CSS: @media print rules have media_query" {
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
  assert_true(nav.style.display != @types.Display::None)
}
