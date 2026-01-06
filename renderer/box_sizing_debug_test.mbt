///|
test "debug_box_sizing_adjustment" {
  // Test that box-sizing: content-box adjusts width correctly
  let html =
    #|<div style="width: 20px; height: 20px; padding: 10px; box-sizing: content-box;">test</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
  }

  // Test inline style parsing directly
  let inline_style = @parser.parse_inline_style(
    "width: 20px; height: 20px; padding: 10px; box-sizing: content-box;",
  )
  // After adjust_for_box_sizing, width should be 40 (20 + 10 + 10)
  inspect(inline_style.width, content="Length(40)")
  inspect(inline_style.padding.left, content="Length(10)")
  inspect(inline_style.box_sizing, content="BorderBox")

  // Get the node to inspect the style
  let node = @renderer.render_to_node(html, ctx)
  let div_node = node.children[0]

  // Check the style values - should match inline_style
  inspect(div_node.style.width, content="Length(40)")
  inspect(div_node.style.padding.left, content="Length(10)")
  inspect(div_node.style.box_sizing, content="BorderBox")
  let layout = @renderer.render(html, ctx)
  let div = layout.children[0]

  // With box-sizing: content-box:
  // width = 20 (content) + 10 + 10 (padding) = 40
  // height = 20 (content) + 10 + 10 (padding) = 40
  inspect(div.width, content="40")
  inspect(div.height, content="40")
}

///|
test "debug_border_box_no_adjustment" {
  // Test that box-sizing: border-box doesn't adjust
  let html =
    #|<div style="width: 40px; height: 40px; padding: 10px; box-sizing: border-box;">test</div>
  let ctx : @renderer.RenderContext = {
    viewport_width: 375.0,
    viewport_height: 600.0,
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)
  let div = layout.children[0]

  // With box-sizing: border-box:
  // width = 40 (includes padding)
  // height = 40 (includes padding)
  inspect(div.width, content="40")
  inspect(div.height, content="40")
}
