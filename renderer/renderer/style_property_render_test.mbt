///|
// Style property renderer regression tests split from renderer_test.mbt.

///|
test "html_max_width_constrains_body_layout_width" {
  let html =
    #|<!doctype html>
    #|<html><head>
    #|<style>
    #|  html { max-width: 780px; }
    #|  body { margin: 0; }
    #|  #box { height: 10px; }
    #|</style>
    #|</head>
    #|<body>
    #|  <div id="box"></div>
    #|</body></html>
  let ctx = {
    ..@renderer.RenderContext::default(),
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  let layout = @renderer.render(html, ctx)
  inspect(layout.width, content="780")
  inspect(layout.children[0].width, content="780")
}

///|
test "inline style min-height does not set height" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="target" style="display:flex; min-height:200px;">
    #|  <div id="item" style="width:100px; min-height:100px;"></div>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let target = node.children[0]
  let item = target.children[0]
  inspect(target.style.align_items, content="Stretch")
  inspect(target.style.height, content="Auto")
  inspect(target.style.min_height, content="Length(200)")
  inspect(item.style.height, content="Auto")
  inspect(item.style.min_height, content="Length(100)")
}

///|
test "repeated inline styles do not reuse default cache across inherited font sizes" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="outer-default">
    #|  <span id="default-child" style="line-height: 1em"></span>
    #|</div>
    #|<div id="outer-large" style="font-size: 32px; line-height: 1em">
    #|  <span id="large-child" style="line-height: 1em"></span>
    #|</div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let node = @renderer.render_to_node(html, ctx)
  let default_child = node.children[0].children[0]
  let large_outer = node.children[1]
  let large_child = large_outer.children[0]
  inspect(default_child.style.line_height, content="16")
  inspect(large_outer.style.font_size, content="32")
  inspect(large_child.style.line_height, content="32")
}

///|
test "logical properties inline-size and block-size" {
  let html =
    #|<!doctype html>
    #|<html><body>
    #|<div id="test" style="inline-size: 200px; block-size: 100px"></div>
    #|</body></html>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)
  let test_div = layout.children[0]
  inspect(test_div.id, content="div#test")
  inspect(test_div.width, content="200")
  inspect(test_div.height, content="100")
}

///|
test "visually hidden element should be skipped" {
  let html = "<div><a class=\"mw-jump-link\" style=\"display:block;position:absolute;clip:rect(1px,1px,1px,1px);width:1px;height:1px;overflow:hidden\">Jump to content</a><p>Visible content</p></div>"
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let node = @renderer.render_to_node(html, ctx)

  let div_node = node.children[0]
  let a_node = div_node.children[0]
  inspect(a_node.id, content="a.mw-jump-link")
  inspect(a_node.style.display, content="Block")
  inspect(a_node.style.clip, content="rect(1, 1, 1, 1)")
  inspect(a_node.style.overflow_x, content="Hidden")
  inspect(a_node.style.width, content="Length(1)")
  inspect(a_node.style.height, content="Length(1)")
}
