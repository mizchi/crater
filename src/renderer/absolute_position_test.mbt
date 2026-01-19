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
  inspect(edit_link.x, content="253")
  inspect(edit_link.y, content="10")
  inspect(edit_link.width, content="112")
  inspect(edit_link.height, content="16")
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
