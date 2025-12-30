// =============================================================================
// SVG Visualization for Layout Results
// =============================================================================

///|
/// Generate SVG string from layout tree
pub fn to_svg(layout : @node.Layout, width : Double, height : Double) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<svg xmlns=\"http://www.w3.org/2000/svg\" ")
  buf.write_string("width=\"")
  buf.write_string(width.to_string())
  buf.write_string("\" height=\"")
  buf.write_string(height.to_string())
  buf.write_string("\">\n")
  buf.write_string("  <style>\n")
  buf.write_string("    rect { stroke: #333; stroke-width: 1; }\n")
  buf.write_string("    text { font-family: sans-serif; font-size: 10px; fill: #333; }\n")
  buf.write_string("  </style>\n")
  render_node(buf, layout, 0.0, 0.0, 0)
  buf.write_string("</svg>\n")
  buf.to_string()
}

///|
fn render_node(
  buf : StringBuilder,
  layout : @node.Layout,
  parent_x : Double,
  parent_y : Double,
  depth : Int
) -> Unit {
  let abs_x = parent_x + layout.x
  let abs_y = parent_y + layout.y
  let fill = get_color(depth)
  let indent = "  ".repeat(depth + 1)

  // Draw rectangle
  buf.write_string(indent)
  buf.write_string("<rect x=\"")
  buf.write_string(abs_x.to_string())
  buf.write_string("\" y=\"")
  buf.write_string(abs_y.to_string())
  buf.write_string("\" width=\"")
  buf.write_string(layout.width.to_string())
  buf.write_string("\" height=\"")
  buf.write_string(layout.height.to_string())
  buf.write_string("\" fill=\"")
  buf.write_string(fill)
  buf.write_string("\" />\n")

  // Draw label
  buf.write_string(indent)
  buf.write_string("<text x=\"")
  buf.write_string((abs_x + 4.0).to_string())
  buf.write_string("\" y=\"")
  buf.write_string((abs_y + 14.0).to_string())
  buf.write_string("\">")
  buf.write_string(layout.id)
  buf.write_string("</text>\n")

  // Render children
  for child in layout.children {
    render_node(buf, child, abs_x, abs_y, depth + 1)
  }
}

///|
fn get_color(depth : Int) -> String {
  // Same colors as browser rendering for side-by-side comparison
  let colors = [
    "rgba(66, 133, 244, 0.3)",  // Blue (root)
    "rgba(52, 168, 83, 0.3)",   // Green (children)
    "rgba(251, 188, 4, 0.3)",   // Yellow
    "rgba(234, 67, 53, 0.3)",   // Red
    "rgba(154, 160, 166, 0.3)", // Gray
  ]
  let idx = depth % colors.length()
  colors[idx]
}
