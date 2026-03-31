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
    color_scheme: @media.ColorScheme::Light,
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
    #|<div style="position: relative; width: 100%; max-width: 800px;">
    #|  <a style="position: absolute; right: 10px; top: 10px;">Edit this Page</a>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
    color_scheme: @media.ColorScheme::Light,
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
  @inline.set_builtin_text_advance_ratio(1.0)
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
      #|48
    ),
  )
  let non_text_children : Array[@types.Layout] = []
  for child in span.children {
    if not(child.id.has_prefix("#text")) {
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
      #|-79.2
    ),
  )
  @inline.clear_builtin_text_advance_ratio()
  clear_builtin_text_advance_ratio_override_for_test()
}

///|
test "wpt_inline_abspos_004_relative_inline_keeps_carry_for_abs_insets" {
  set_builtin_text_advance_ratio_override_for_test(1.0)
  @inline.set_builtin_text_advance_ratio(1.0)
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
      #|100
    ),
  )
  let abs_children : Array[@types.Layout] = []
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
  inspect(abs0.y, content="-50")
  inspect(abs1.y, content="-50")
  inspect(
    abs0.x,
    content=(
      #|-30
    ),
  )
  inspect(
    abs1.x,
    content=(
      #|-80
    ),
  )
  @inline.clear_builtin_text_advance_ratio()
  clear_builtin_text_advance_ratio_override_for_test()
}
