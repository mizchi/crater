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
test "wpt_position_absolute_center_vertical_rl_inline_blocks_wrap_to_columns" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#containing-block {
    #|  position: relative;
    #|  width: 100px;
    #|  height: 100px;
    #|  display: flex;
    #|  flex-direction: column;
    #|}
    #|#containing-block > div { flex-grow: 1; }
    #|#inner-flex {
    #|  display: flex;
    #|  align-items: center;
    #|  margin: 10px;
    #|  width: 100px;
    #|}
    #|span {
    #|  display: inline-block;
    #|  inline-size: 50px;
    #|  block-size: 10px;
    #|}
    #|</style>
    #|<div id="containing-block">
    #|  <div id="inner-flex">
    #|    <div style="position: absolute; left: 0; width: 100px; writing-mode: vertical-rl;">
    #|      <span></span><span></span>
    #|    </div>
    #|  </div>
    #|  <div style="width: 100px;"></div>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let containing_block = layout.children[0]
  let inner_flex = containing_block.children[0]
  let absolute_child = inner_flex.children[0]
  let first_span = absolute_child.children[0]
  let second_span = absolute_child.children[1]

  inspect(absolute_child.width, content="100")
  inspect(first_span.x, content="90")
  inspect(first_span.y, content="0")
  inspect(second_span.x, content="80")
  inspect(second_span.y, content="0")
}

///|
test "absolute_vertical_rl_inline_blocks_use_containing_block_height" {
  let html =
    #|<!DOCTYPE html>
    #|<style>
    #|body { margin: 0; }
    #|#containing-block {
    #|  position: relative;
    #|  width: 100px;
    #|  height: 100px;
    #|}
    #|span {
    #|  display: inline-block;
    #|  inline-size: 50px;
    #|  block-size: 10px;
    #|}
    #|</style>
    #|<div id="containing-block">
    #|  <div style="position: absolute; left: 0; width: 100px; writing-mode: vertical-rl;">
    #|    <span></span><span></span>
    #|  </div>
    #|</div>
  let layout = @renderer.render(html, @renderer.RenderContext::default())
  let containing_block = layout.children[0]
  let absolute_child = containing_block.children[0]
  let first_span = absolute_child.children[0]
  let second_span = absolute_child.children[1]

  inspect(absolute_child.width, content="100")
  inspect(first_span.x, content="90")
  inspect(first_span.y, content="0")
  inspect(second_span.x, content="80")
  inspect(second_span.y, content="0")
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
  // filter on the inline parent must establish an abspos containing block,
  // so the abspos descendant resolves top: 0 against the filtered span rather
  // than the outer block (issue #64, filter-cb-abspos-inline-001).
  inspect(cb.style.has_filter, content="true")
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
test "inline_style_attribute_filter_establishes_abspos_cb" {
  // The inline style attribute path (not a stylesheet rule) must also
  // surface filter: <fn> through to layout's has_filter flag, so abspos
  // descendants of an element whose filter lives on style="..." still
  // resolve their CB against that element.
  let html_str =
    #|<!DOCTYPE html>
    #|<div><span id="cb" style="filter: blur(2px)">text<span id="abs" style="position: absolute; top: 0; left: 0; width: 5px; height: 5px"></span></span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let container = root.children[0]
  let cb = container.children[0]
  inspect(cb.id, content="span#cb")
  inspect(cb.style.has_filter, content="true")
  let abs = cb.children[1]
  inspect(abs.id, content="span#abs")
  inspect(abs.style.position, content="Absolute")
}

///|
test "filter_var_resolving_to_none_does_not_establish_abspos_cb" {
  // issue #236: filter: var(--fx) where --fx is none must NOT establish an
  // abspos containing block — it computes to filter: none. Reading the raw
  // cascaded text ("var(--fx)") used to mis-set has_filter here.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#cb { --fx: none; filter: var(--fx); }
    #|</style>
    #|<div><span id="cb">text</span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let cb = root.children[0].children[0]
  inspect(cb.id, content="span#cb")
  inspect(cb.style.has_filter, content="false")
}

///|
test "filter_var_unresolved_does_not_establish_abspos_cb" {
  // issue #236: filter: var(--undef) with no fallback is an unresolved var,
  // which computes to the initial value none and must NOT establish the CB.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#cb { filter: var(--undef); }
    #|</style>
    #|<div><span id="cb">text</span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let cb = root.children[0].children[0]
  inspect(cb.id, content="span#cb")
  inspect(cb.style.has_filter, content="false")
}

///|
test "filter_var_resolving_to_non_filter_token_does_not_establish_abspos_cb" {
  // issue #236: filter: var(--fx) where --fx holds a non-filter token is an
  // invalid filter value, computing to none; it must NOT establish the CB.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#cb { --fx: invalid-token; filter: var(--fx); }
    #|</style>
    #|<div><span id="cb">text</span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let cb = root.children[0].children[0]
  inspect(cb.id, content="span#cb")
  inspect(cb.style.has_filter, content="false")
}

///|
test "filter_var_resolving_to_filter_function_establishes_abspos_cb" {
  // The valid var() case must still establish the CB: filter: var(--fx)
  // where --fx is a real filter function behaves like a literal filter.
  let html_str =
    #|<!DOCTYPE html>
    #|<style>
    #|#cb { --fx: blur(2px); filter: var(--fx); }
    #|</style>
    #|<div><span id="cb">text</span></div>
  let ctx = @renderer.RenderContext::default()
  let root = @renderer.render_to_node(html_str, ctx)
  let cb = root.children[0].children[0]
  inspect(cb.id, content="span#cb")
  inspect(cb.style.has_filter, content="true")
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

///|
/// Regression (#64): `filter` on an inline element establishes a containing
/// block for its absolutely-positioned descendants. Previously the renderer's
/// establishes_absolute_containing_block ignored filter (it only checked
/// position / containment / transform), so an abspos child with top:0/left:0
/// was placed relative to an ancestor instead of the filtered inline box.
test "filter_on_inline_establishes_abs_containing_block" {
  let html_filter =
    #|<p>Filler text.</p>
    #|<div><span id="cb" style="filter: brightness(100%)">corner text<span id="abspos" style="position:absolute; top:0; left:0; width:10px; height:10px"></span></span></div>
  let html_rel =
    #|<p>Filler text.</p>
    #|<div><span id="cb" style="position:relative; filter: brightness(100%)">corner text<span id="abspos" style="position:absolute; top:0; left:0; width:10px; height:10px"></span></span></div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let lf = @renderer.render(html_filter, ctx)
  let lr = @renderer.render(html_rel, ctx)
  let cb_f = lf.children[1].children[0]
  let cb_r = lr.children[1].children[0]
  let abspos_f = cb_f.children[cb_f.children.length() - 1]
  let abspos_r = cb_r.children[cb_r.children.length() - 1]
  // top:0/left:0 relative to #cb -> child lands at the CB origin (0,0), not
  // pushed up to an ancestor baseline.
  inspect(abspos_f.x, content="0")
  inspect(abspos_f.y, content="0")
  // The filtered CB places the child identically to the relative CB.
  assert_eq(abspos_f.x, abspos_r.x)
  assert_eq(abspos_f.y, abspos_r.y)
}

///|
/// Regression: an absolutely-positioned box with no positioned ancestor is
/// sized against the initial containing block (the viewport), so height:100%
/// resolves to the viewport height rather than collapsing to 0. Previously the
/// percentage height was resolved against the static parent's auto (0) height.
test "absolute_percentage_height_resolves_against_icb" {
  let html =
    #|<style>html, body { margin: 0; padding: 0; }</style>
    #|<div id="outer" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;"></div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 800.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  fn find_outer(n : @layout_types.Layout) -> @layout_types.Layout? {
    if n.id.has_suffix("#outer") {
      return Some(n)
    }
    for child in n.children {
      match find_outer(child) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }

  match find_outer(layout) {
    Some(outer) => {
      inspect(outer.width, content="800")
      inspect(outer.height, content="600")
    }
    None => inspect(false, content="#outer not found")
  }
}
