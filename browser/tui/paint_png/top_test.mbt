///|
extern "js" fn js_png_color_type(encoded : String) -> Int =
  #| (encoded) => {
  #|   try {
  #|     const buf = Buffer.from(String(encoded || ""), "base64");
  #|     return buf.length > 25 ? (buf[25] | 0) : -1;
  #|   } catch (_) {
  #|     return -1;
  #|   }
  #| }

///|
test "tui paint png output exports png" {
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
  let png = raster_to_png_base64(paint_node, 8, 4)
  inspect(png.length() > 0, content="true")
  inspect(js_png_color_type(png), content="3")
}
