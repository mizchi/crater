///|
test "absolute_position_in_relative_parent" {
  // Test that position: absolute is positioned relative to position: relative parent
  let html =
    #|<div style="position: relative; width: 200px; height: 100px;">
    #|  <div style="position: absolute; right: 0; top: 10px; width: 50px; height: 20px;">edit</div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let relative_parent = layout.children[0]
  let absolute_child = relative_parent.children[0]

  // Parent should be 200x100
  inspect(relative_parent.width, content="200")
  inspect(relative_parent.height, content="100")

  // Child should be positioned at right: 0, top: 10
  // x = parent_width - child_width - right = 200 - 50 - 0 = 150
  // y = top = 10
  inspect(absolute_child.x, content="150")
  inspect(absolute_child.y, content="10")
  inspect(absolute_child.width, content="50")
  inspect(absolute_child.height, content="20")
}

///|
test "edit_this_page_style" {
  // Simulate the Edit this Page element structure
  let html =
    #|<style>body { margin: 0; }</style>
    #|<div style="position: relative; width: 100%; max-width: 800px;">
    #|  <a style="position: absolute; right: 10px; top: 10px;">Edit this Page</a>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let wrapper = layout.children[0]
  let edit_link = wrapper.children[0]

  // Wrapper should have width from viewport (100% of 375)
  inspect(wrapper.width, content="375")

  // Wrapper should have minimal height since only child is absolute
  // In CSS, an element with only absolute positioned children has 0 height
  // (unless it has explicit height or padding)
  inspect(wrapper.height, content="0")

  // Check actual values
  inspect(
    edit_link.x,
    content=(
      #|253
    ),
  )
  inspect(edit_link.y, content="10")
  inspect(
    edit_link.width,
    content=(
      #|112
    ),
  )
  inspect(
    edit_link.height,
    content=(
      #|19.2
    ),
  )
}

///|
test "wrapper_with_only_absolute_child_should_have_zero_height" {
  // A container with only absolute positioned children should have 0 height
  // because absolute children are taken out of the normal flow
  let html =
    #|<div style="position: relative; width: 200px;">
    #|  <div style="position: absolute; width: 50px; height: 30px;">abs</div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let wrapper = layout.children[0]
  inspect(wrapper.width, content="200")
  // Height should be 0 since only child is absolute positioned
  inspect(wrapper.height, content="0")
}

///|
test "absolute_position_in_static_grid_parent_uses_grid_containing_block" {
  let html =
    #|<p style="margin: 0; line-height: 1.2;">lead</p>
    #|<grid style="display: grid; min-height: 100px; grid-template-rows: auto;">
    #|  <div style="position: absolute; width: 100px; height: 50px;"></div>
    #|  <div style="width: 100px; height: 50px; align-self: end;"></div>
    #|</grid>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let grid = layout.children[1]
  let absolute_child = grid.children[0]

  inspect(grid.y, content="19.2")
  inspect(absolute_child.y, content="0")
  inspect(absolute_child.width, content="100")
  inspect(absolute_child.height, content="50")
}

///|
test "absolute_position_in_inline_with_line_break_uses_multiline_static_y" {
  let html =
    #|<div style="border: 1px solid; position: relative; width: 100px; height: 100px; display: inline-block;">
    #|  <div style="display: inline; color: transparent; font: 10px monospace; line-height: 25px;">
    #|    text
    #|    <div style="position: absolute; width: 50px; height: 50px;"></div>
    #|    <br>text
    #|  </div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let container = layout.children[0]
  let inline = container.children[0]
  let abs = inline.children[1]

  guard inline.height >= 30.0 else {
    fail("inline box should keep multiline height when it contains <br>")
  }
  guard abs.y >= 24.0 && abs.y <= 26.0 else {
    fail("abspos static y should reflect line break baseline progression")
  }
}

///|
test "abspos_non_auto_inset_inside_static_flex_uses_outer_abs_containing_block" {
  let html =
    #|<div style="position: relative; width: 300px; height: 300px;">
    #|  <div style="display: flex; width: 30px; height: 30px; margin-left: 270px;">
    #|    <div style="position: absolute; inset: 0; width: 100px; height: 100px; align-self: center; justify-self: center;"></div>
    #|  </div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let container = layout.children[0]
  let inner = container.children[0]
  let abs = inner.children[0]

  let abs_global_x = inner.x + abs.x
  let abs_global_y = inner.y + abs.y
  guard abs_global_x == 100.0 else {
    fail("abs x should center in outer containing block, not inner flex")
  }
  guard abs_global_y == 100.0 else {
    fail("abs y should center in outer containing block, not inner flex")
  }
}

///|
test "abspos_stretch_inside_static_flex_uses_outer_abs_containing_block" {
  let html =
    #|<style>
    #|body { margin: 0; }
    #|.navigation { display: grid; grid-template-columns: min-content 1fr; width: 600px; height: 80px; column-gap: 10px; }
    #|.navigation__logo { width: 80px; height: 20px; }
    #|.navigation__popup { display: contents; }
    #|.menu { position: relative; display: flex; height: 30px; }
    #|.menu__tab { display: block; width: 120px; height: 30px; }
    #|.menu__panel { position: absolute; left: 0; right: 0; top: 30px; height: 20px; }
    #|</style>
    #|<nav class="navigation">
    #|  <div class="navigation__logo"></div>
    #|  <div class="navigation__popup">
    #|    <div class="menu">
    #|      <div class="menu__tab">
    #|        <div class="menu__panel"></div>
    #|      </div>
    #|    </div>
    #|  </div>
    #|</nav>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 200.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let navigation = layout.children[0]
  let popup = navigation.children[1]
  let menu = popup.children[0]
  let tab = menu.children[0]
  let panel = tab.children[0]

  inspect(menu.x, content="90")
  inspect(menu.width, content="510")
  inspect(panel.x, content="0")
  inspect(panel.width, content="510")
}

///|
test "abspos_non_auto_inset_inside_static_grid_uses_outer_abs_containing_block" {
  let html =
    #|<div style="position: relative; width: 300px; height: 300px;">
    #|  <div style="display: grid; width: 30px; height: 30px; margin-left: 270px;">
    #|    <div style="position: absolute; inset: 0; width: 100px; height: 100px; align-self: center; justify-self: center;"></div>
    #|  </div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  let container = layout.children[0]
  let inner = container.children[0]
  let abs = inner.children[0]

  let abs_global_x = inner.x + abs.x
  let abs_global_y = inner.y + abs.y
  guard abs_global_x == 100.0 else {
    fail("abs x should center in outer containing block, not inner grid")
  }
  guard abs_global_y == 100.0 else {
    fail("abs y should center in outer containing block, not inner grid")
  }
}

///|
test "wpt_inline_abspos_003_block_child_forces_new_line_static_y" {
  set_builtin_text_advance_ratio_override_for_test(1.0)
  @layout_test.set_builtin_text_advance_ratio(1.0)
  let html =
    #|<div id="container" style="font: 20px/1 Ahem; color: white; height: 100px; width: 100px; background: red;">
    #|  <div style="height: 60px;"></div>
    #|  B
    #|  <span style="position: relative;">
    #|    <div></div>
    #|    AA
    #|    <div class="abs" style="position: absolute; background: green; height: 100px; width: 100px; top: -60px;"></div>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let container = layout.children[0]
  guard container.children.length() >= 3 else {
    fail("container should keep block, text, and span")
  }
  let span = container.children[2]
  guard span.id.has_prefix("span") else {
    fail("third child should be inline containing block")
  }
  inspect(span.x, content="0")
  inspect(span.y, content="80")
  inspect(
    span.width,
    content=(
      #|40
    ),
  )
  let text_children : Array[@layout_types.Layout] = []
  for child in span.children {
    match child.text {
      Some(text) => if !text.trim().is_empty() { text_children.push(child) }
      None => ()
    }
  }
  guard text_children.length() == 1 else {
    fail("span should keep one non-whitespace text fragment")
  }
  let text_layout = text_children[0]
  inspect(
    text_layout.width,
    content=(
      #|40
    ),
  )
  match text_layout.text {
    Some(text) => inspect(text == "AA", content="true")
    None => fail("text fragment should keep content")
  }
  let non_text_children : Array[@layout_types.Layout] = []
  for child in span.children {
    if !child.id.has_prefix("#text") {
      non_text_children.push(child)
    }
  }
  guard non_text_children.length() == 2 else {
    fail("span should keep in-flow block child and abs child")
  }
  let abs = non_text_children[1]
  guard abs.id.has_prefix("div.abs") else {
    fail("second non-text child should be absolute descendant")
  }
  inspect(
    abs.y,
    content=(
      #|-80
    ),
  )
  @layout_test.clear_builtin_text_advance_ratio()
  clear_builtin_text_advance_ratio_override_for_test()
}

///|
test "wpt_inline_abspos_004_relative_inline_keeps_carry_for_abs_insets" {
  set_builtin_text_advance_ratio_override_for_test(1.0)
  @layout_test.set_builtin_text_advance_ratio(1.0)
  let html =
    #|<div id="container" style="height: 100px; width: 100px; font: 20px/1 Ahem; color: white; background: red;">
    #|  <div style="height: 50px;"></div>
    #|  BBBB
    #|  <span style="position: relative;">
    #|    <div class="abs" style="position: absolute; background: green; height: 100px; width: 50px; top: -50px; left: -30px;"></div>
    #|    AA A AA AAAA
    #|    <div class="abs" style="position: absolute; background: green; height: 100px; width: 50px; top: -50px; left: -80px;"></div>
    #|  </span>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let container = layout.children[0]
  guard container.children.length() >= 3 else {
    fail("container should keep block, text, and span")
  }
  let span = container.children[2]
  guard span.id.has_prefix("span") else {
    fail("third child should be inline containing block")
  }
  inspect(span.y, content="70")
  inspect(
    span.width,
    content=(
      #|80
    ),
  )
  let abs_children : Array[@layout_types.Layout] = []
  for child in span.children {
    if child.id.has_prefix("div.abs") {
      abs_children.push(child)
    }
  }
  guard abs_children.length() == 2 else {
    fail("span should keep two absolute descendants")
  }
  let abs0 = abs_children[0]
  let abs1 = abs_children[1]
  let abs0_global_x = span.x + abs0.x
  let abs1_global_x = span.x + abs1.x
  let abs0_global_y = span.y + abs0.y
  let abs1_global_y = span.y + abs1.y
  inspect(abs0_global_y, content="0")
  inspect(abs1_global_y, content="0")
  inspect(
    abs0_global_x,
    content=(
      #|50
    ),
  )
  inspect(
    abs1_global_x,
    content=(
      #|0
    ),
  )
  @layout_test.clear_builtin_text_advance_ratio()
  clear_builtin_text_advance_ratio_override_for_test()
}

///|
test "abspos_align_self_stretch_with_inset_shorthand_spans_containing_block" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.container { position: relative; width: 200px; height: 200px; }
    #|.abspos {
    #|  position: absolute;
    #|  inset: 50px auto 50px 50px;
    #|  margin: auto 0 auto 0;
    #|  align-self: stretch;
    #|}
    #|.abspos::before {
    #|  content: '';
    #|  min-width: 50px;
    #|  height: 100%;
    #|  aspect-ratio: 1;
    #|  display: block;
    #|}
    #|</style>
    #|<div class="container"><div class="abspos"></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let container = layout.children[0]
  let abspos = container.children[0]
  inspect(abspos.width, content="100")
  inspect(abspos.height, content="100")
}

///|
test "abspos_justify_self_stretch_with_inset_shorthand_spans_containing_block" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.container { position: relative; width: 200px; height: 200px; }
    #|.abspos {
    #|  position: absolute;
    #|  inset: 50px 50px auto 50px;
    #|  margin: 0 auto 0 auto;
    #|  justify-self: stretch;
    #|}
    #|.abspos::before {
    #|  content: '';
    #|  width: 100%;
    #|  min-height: 50px;
    #|  aspect-ratio: 1;
    #|  display: block;
    #|}
    #|</style>
    #|<div class="container"><div class="abspos"></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let container = layout.children[0]
  let abspos = container.children[0]
  inspect(abspos.width, content="100")
  inspect(abspos.height, content="100")
}

///|
test "empty_absolute_before_pseudo_is_kept_as_paintable_box" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|:root { --stripe: red; }
    #|.alert {
    #|  position: relative;
    #|  width: 100px;
    #|  height: 32px;
    #|  padding-left: 8px;
    #|}
    #|.alert::before {
    #|  content: "";
    #|  position: absolute;
    #|  left: 0;
    #|  top: 0;
    #|  bottom: 0;
    #|  width: 4px;
    #|  display: block;
    #|  background: var(--stripe);
    #|}
    #|</style>
    #|<div class="alert">Alert</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let host = root.children[0]
  guard host.children.length() > 0 else {
    fail("absolute empty ::before should be present")
  }
  inspect(host.children[0].id, content="#pseudo::before")
  inspect(host.children[0].style.background_color.to_hex(), content="#ff0000")
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let host_layout = layout.children[0]
  guard host_layout.children.length() > 0 else {
    fail("absolute empty ::before should have layout")
  }
  let pseudo = host_layout.children[0]
  inspect(pseudo.id, content="#pseudo::before")
  inspect(pseudo.width, content="4")
  inspect(pseudo.height, content="32")
}

///|
test "contain_size_abspos_monolithic_box_keeps_explicit_size_inside_multicol" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#multicol { width: 300px; column-count: 3; }
    #|#container { position: relative; }
    #|#abs-size-contain {
    #|  position: absolute;
    #|  contain: size;
    #|  width: 100px;
    #|  height: 100px;
    #|  background: green;
    #|}
    #|</style>
    #|<div id="multicol"><div id="container"><div id="abs-size-contain"></div></div></div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let multicol = layout.children[0]
  let container = multicol.children[0]
  let abs_box = container.children[0]
  inspect(abs_box.width, content="100")
  inspect(abs_box.height, content="100")
}

///|
test "inline_filter_preserves_abspos_descendant_wpt_like" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#cb { filter: brightness(100%); }
    #|#abs { position: absolute; top: 0; left: 0; width: 10px; height: 10px; }
    #|</style>
    #|<div><span id="cb">text<span id="abs"></span></span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)

  let container = root.children[0]
  inspect(container.id, content="div")
  let cb = container.children[0]
  inspect(cb.id, content="span#cb")
  inspect(cb.children.length(), content="2")
  let abs = cb.children[1]
  inspect(abs.id, content="span#abs")
  inspect(abs.style.position, content="Absolute")
}

///|
test "fixed_child_in_abspos_parent_uses_viewport_reference" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#parent {
    #|  position: absolute;
    #|  top: 100px;
    #|  left: 100px;
    #|}
    #|#fixed {
    #|  position: fixed;
    #|  top: 50px;
    #|  left: 50px;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|</style>
    #|<div id="parent"><div id="fixed"></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let parent = layout.children[0]
  let fixed = parent.children[0]

  // Fixed element should be positioned from viewport, so relative to parent it is negative.
  inspect(fixed.x, content="-50")
  inspect(fixed.y, content="-50")
}

///|
test "backdrop_filter_establishes_fixed_containing_block" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#container {
    #|  width: 200px;
    #|  backdrop-filter: invert(1);
    #|}
    #|#fixed {
    #|  position: fixed;
    #|  top: 0;
    #|  width: 100%;
    #|  height: 200px;
    #|}
    #|</style>
    #|<div id="container"><div id="fixed"></div></div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html_str, ctx)
  let container = layout.children[0]
  let fixed = container.children[0]

  inspect(container.width, content="200")
  inspect(fixed.width, content="200")
}

///|
test "wpt_intrinsic_percent_replaced_019_like_abspos_flex_basis_content_uses_definite_cross_chain" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|.outer { width: 500px; }
    #|.abspos-cb {
    #|  position: relative;
    #|  height: 0;
    #|  width: 0;
    #|  padding: 9%;
    #|  border: 5px solid green;
    #|}
    #|.flex-container {
    #|  height: 100%;
    #|  width: 100%;
    #|  position: absolute;
    #|  display: flex;
    #|  border: 5px solid green;
    #|  box-sizing: border-box;
    #|  top: 0;
    #|  left: 0;
    #|}
    #|.item {
    #|  border: 5px solid green;
    #|  height: 100%;
    #|  flex-basis: content;
    #|  box-sizing: border-box;
    #|}
    #|canvas {
    #|  width: 100%;
    #|  height: 100%;
    #|  border: 5px solid green;
    #|  background: green;
    #|  box-sizing: border-box;
    #|}
    #|</style>
    #|<div class="outer">
    #|  <div class="abspos-cb">
    #|    <div class="flex-container">
    #|      <div class="item">
    #|        <canvas width="10" height="10"></canvas>
    #|      </div>
    #|    </div>
    #|  </div>
    #|</div>
  let root = @renderer.render_to_node(
    html_str,
    @renderer.RenderContext::default(),
  )
  let outer = root.children[0]
  let abspos_cb = outer.children[0]
  let flex = abspos_cb.children[0]
  let item = flex.children[0]
  let canvas = item.children[0]
  inspect(flex.style.width, content="Percent(1)")
  inspect(flex.style.height, content="Percent(1)")
  inspect(item.style.height, content="Percent(1)")
  inspect(canvas.style.width, content="Percent(1)")
  inspect(canvas.style.height, content="Percent(1)")
  debug_inspect(canvas.style.aspect_ratio, content="Some(1)")

  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let laid_out_outer = layout.children[0]
  let laid_out_abspos_cb = laid_out_outer.children[0]
  let laid_out_flex = laid_out_abspos_cb.children[0]
  let laid_out_item = laid_out_flex.children[0]
  let laid_out_canvas = laid_out_item.children[0]
  inspect(laid_out_abspos_cb.width, content="100")
  inspect(laid_out_flex.width, content="90")
  inspect(laid_out_flex.height, content="90")
  inspect(laid_out_item.width, content="80")
  inspect(laid_out_item.height, content="80")
  inspect(laid_out_canvas.width, content="70")
  inspect(laid_out_canvas.height, content="70")
}

///|
test "wpt_intrinsic_percent_replaced_dynamic_005_like_abspos_auto_height_tracks_canvas" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|</style>
    #|<div style="position: relative; width: 100px; height: 100px;">
    #|  <div id="target" style="position: absolute; top:0; background: green;">
    #|    <canvas width="1" height="1" style="height: 100%;"></canvas>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  let target = layout.children[0].children[0]
  let canvas = target.children[0]
  inspect(target.height, content="1")
  inspect(canvas.y, content="0")
  inspect(canvas.height, content="1")
}

///|
test "html_abspos_root_keeps_html_as_layout_root" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html {
    #|  display: flex;
    #|  position: absolute;
    #|  left: 10px;
    #|  right: 20px;
    #|  top: 30px;
    #|  bottom: 40px;
    #|  border: 5px solid black;
    #|  box-sizing: border-box;
    #|}
    #|body { margin: 0; }
    #|</style>
    #|<body>root abs test</body>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  inspect(layout.id, content="html")
  guard (layout.width - 770.0).abs() < 0.01 else {
    fail("absolute-positioned html root width should honor left/right insets")
  }
  guard (layout.height - 530.0).abs() < 0.01 else {
    fail("absolute-positioned html root height should honor top/bottom insets")
  }
  let body = layout.children[0]
  inspect(body.id, content="body")
  guard body.height > 500.0 else {
    fail("body should stretch in cross-axis inside html:flex container")
  }
}

///|
test "html_fixed_root_keeps_html_as_layout_root" {
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|html {
    #|  display: grid;
    #|  position: fixed;
    #|  left: 10px;
    #|  right: 20px;
    #|  top: 30px;
    #|  bottom: 40px;
    #|  border: 5px solid black;
    #|  box-sizing: border-box;
    #|}
    #|body { margin: 0; }
    #|</style>
    #|<body>root fixed test</body>
  let layout = @renderer.render(html_str, @renderer.RenderContext::default())
  inspect(layout.id, content="html")
  guard (layout.width - 770.0).abs() < 0.01 else {
    fail("fixed-positioned html root width should honor left/right insets")
  }
  guard (layout.height - 530.0).abs() < 0.01 else {
    fail("fixed-positioned html root height should honor top/bottom insets")
  }
  let body = layout.children[0]
  inspect(body.id, content="body")
  guard body.height > 500.0 else {
    fail("body should stretch in cross-axis inside html:grid container")
  }
}

///|
test "position relative with negative offset" {
  let html =
    #|<div style="width: 100px; height: 100px;">
    #|  <div style="position: relative; top: -20px; left: -40px; width: 50px; height: 50px;"></div>
    #|</div>
  let ctx = @renderer.RenderContext::default()
  let layout = @renderer.render(html, ctx)
  let outer = layout.children[0]
  let inner = outer.children[0]
  inspect(inner.x, content="-40")
  inspect(inner.y, content="-20")
}
