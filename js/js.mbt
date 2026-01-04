///|
/// JavaScript API for Crater layout engine
/// Provides browser-friendly functions for HTML rendering

///|
/// Render HTML to layout tree (text representation)
pub fn renderHtml(html : String, width : Int, height : Int) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)
  let buf = StringBuilder::new()
  format_layout(layout, buf, 0)
  buf.to_string()
}

///|
fn format_layout(
  layout : @node.Layout,
  buf : StringBuilder,
  indent : Int,
) -> Unit {
  let mut i = 0
  while i < indent {
    buf.write_string("  ")
    i = i + 1
  }
  buf.write_string(layout.id)
  buf.write_string(" (")
  buf.write_string(layout.x.to_string())
  buf.write_string(", ")
  buf.write_string(layout.y.to_string())
  buf.write_string(") ")
  buf.write_string(layout.width.to_string())
  buf.write_string("x")
  buf.write_string(layout.height.to_string())
  buf.write_string("\n")
  for child in layout.children {
    format_layout(child, buf, indent + 1)
  }
}

///|
/// Render HTML to JSON layout tree
pub fn renderHtmlToJson(html : String, width : Int, height : Int) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)
  @renderer.layout_to_json(layout)
}

///|
/// Render HTML to paint node tree (JSON format with colors)
pub fn renderHtmlToPaintTree(
  html : String,
  width : Int,
  height : Int,
) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  let paint_tree = @paint.from_node_and_layout(node, layout)
  paint_node_to_json(paint_tree)
}

///|
fn paint_node_to_json(node : @paint.PaintNode) -> String {
  let buf = StringBuilder::new()
  write_paint_node(node, buf)
  buf.to_string()
}

///|
fn write_paint_node(node : @paint.PaintNode, buf : StringBuilder) -> Unit {
  buf.write_string("{\"id\":\"")
  buf.write_string(escape_json_string(node.id))
  buf.write_string("\",\"x\":")
  buf.write_string(node.x.to_string())
  buf.write_string(",\"y\":")
  buf.write_string(node.y.to_string())
  buf.write_string(",\"width\":")
  buf.write_string(node.width.to_string())
  buf.write_string(",\"height\":")
  buf.write_string(node.height.to_string())
  buf.write_string(",\"backgroundColor\":\"")
  buf.write_string(color_to_css(node.paint.background_color))
  buf.write_string("\",\"color\":\"")
  buf.write_string(color_to_css(node.paint.color))
  buf.write_string("\",\"opacity\":")
  buf.write_string(node.paint.opacity.to_string())
  // Text content
  match node.text {
    Some(t) => {
      buf.write_string(",\"text\":\"")
      buf.write_string(escape_json_string(t))
      buf.write_string("\"")
    }
    None => ()
  }
  // Children
  buf.write_string(",\"children\":[")
  let mut first = true
  for child in node.children {
    if not(first) {
      buf.write_string(",")
    }
    first = false
    write_paint_node(child, buf)
  }
  buf.write_string("]}")
}

///|
fn color_to_css(color : @types.Color) -> String {
  let buf = StringBuilder::new()
  buf.write_string("rgba(")
  buf.write_string(color.r.to_string())
  buf.write_string(",")
  buf.write_string(color.g.to_string())
  buf.write_string(",")
  buf.write_string(color.b.to_string())
  buf.write_string(",")
  // alpha is already 0.0-1.0, round to 2 decimal places
  let alpha = (color.a * 100.0).to_int().to_double() / 100.0
  buf.write_string(alpha.to_string())
  buf.write_string(")")
  buf.to_string()
}

///|
fn escape_json_string(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Render HTML to Sixel graphics string
pub fn renderHtmlToSixel(html : String, width : Int, height : Int) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let layout = @renderer.render(html, ctx)
  @sixel.render_layout_with_options(layout, width, height, false)
}

///|
/// Render HTML to Sixel with actual CSS colors
pub fn renderHtmlToSixelWithStyles(
  html : String,
  width : Int,
  height : Int,
) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
  }
  let node = @renderer.render_to_node(html, ctx)
  let layout = @renderer.render(html, ctx)
  @sixel.render_with_styles(node, layout, width, height)
}
