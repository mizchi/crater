///|
test "flex_item_with_explicit_width" {
  // Simple flex container with item that has explicit width
  let html =
    #|<div style="display: flex; width: 375px;">
    #|  <div class="item" style="width: 20px; height: 20px; padding: 18px 23px;">item</div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)

  // The item should have width 20 + 23 + 23 = 66px (with padding, content-box)
  // Or just 20px if border-box is applied incorrectly
  // Check the child of the flex container
  let flex_container = layout.children[0]
  let flex_item = flex_container.children[0]
  // Actually, for inline styles, box-sizing defaults to content-box
  // But the layout engine works with border-box internally
  // So after adjust_for_box_sizing, width should be 20 + 46 = 66
  // However, the test shows 20, meaning adjust_for_box_sizing might not be called
  // or padding isn't being parsed correctly
  // Let's first check what the actual value is
  inspect(flex_item.width, content="66")
}

///|
test "flex_item_with_position_relative" {
  // Test that position: relative doesn't affect width
  let html =
    #|<div style="display: flex; width: 375px;">
    #|  <div style="width: 20px; height: 20px; position: relative;">item</div>
    #|</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)
  let flex_container = layout.children[0]
  let flex_item = flex_container.children[0]
  inspect(flex_item.width, content="20")
}
