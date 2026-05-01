///|
test "tui paint output exports json and rgba" {
  let style = @style.Style::default()
  let node = @node.Node::new("root", style, [])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 8.0,
    height: 4.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 8.0,
    scroll_height: 4.0,
    children: [],
    text: None,
  }
  let paint_node = @paint_plain.from_node_and_layout(node, layout)
  let json_str = to_json_string(paint_node)
  let rgba = raster_to_rgba_base64(paint_node, 8, 4)
  inspect(json_str.length() > 0, content="true")
  inspect(rgba.length() > 0, content="true")
}

///|
test "tui paint output visual stats detect non-white pixels" {
  let style = @style.Style::default()
  let node = @node.Node::new("root", style, [])
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let layout : @types.Layout = {
    id: "root",
    x: 0.0,
    y: 0.0,
    width: 8.0,
    height: 4.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 8.0,
    scroll_height: 4.0,
    children: [],
    text: None,
  }
  let paint_node = @paint_plain.from_node_and_layout(node, layout)
  let (fb, palette) = raster_to_framebuffer(paint_node, 8, 4)
  let blank = framebuffer_visual_stats(fb, palette)
  inspect(blank.pixel_count, content="32")
  inspect(blank.non_white_pixels, content="0")
  inspect(blank.is_blank, content="true")
  let red_style = @style.Style::default()
  red_style.background_color = @types.Color::rgb(255, 0, 0)
  let red_node = @node.Node::new("root", red_style, [])
  let red_paint_node = @paint_plain.from_node_and_layout(red_node, layout)
  let (red_fb, red_palette) = raster_to_framebuffer(red_paint_node, 8, 4)
  let visible = framebuffer_visual_stats(red_fb, red_palette)
  inspect(visible.non_white_pixels, content="32")
  inspect(visible.is_blank, content="false")
}
