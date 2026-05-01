///|
/// PaintNode JSON serialization for native paint renderer.
/// Produces a compact JSON string without external JSON library dependency.
pub fn PaintNode::to_json_string(self : PaintNode) -> String {
  let buf = StringBuilder::new()
  write_paint_node_json(buf, self)
  buf.to_string()
}

///|
fn write_paint_node_json(buf : StringBuilder, node : PaintNode) -> Unit {
  buf.write_string("{\"id\":")
  write_json_string(buf, node.id)
  buf.write_string(",\"tag\":")
  write_json_string(buf, node.tag)
  buf.write_string(",\"x\":")
  write_json_double(buf, node.x)
  buf.write_string(",\"y\":")
  write_json_double(buf, node.y)
  buf.write_string(",\"w\":")
  write_json_double(buf, node.width)
  buf.write_string(",\"h\":")
  write_json_double(buf, node.height)
  buf.write_string(",\"ox\":")
  write_json_string(buf, overflow_to_str(node.overflow_x))
  buf.write_string(",\"oy\":")
  write_json_string(buf, overflow_to_str(node.overflow_y))
  buf.write_string(",\"p\":")
  write_paint_props_json(buf, node.paint)
  match node.text {
    Some(text) => {
      buf.write_string(",\"text\":")
      write_json_string(buf, text)
    }
    None => ()
  }
  buf.write_string(",\"ch\":[")
  for i, child in node.children {
    if i > 0 {
      buf.write_char(',')
    }
    write_paint_node_json(buf, child)
  }
  buf.write_string("]}")
}

///|
fn write_paint_props_json(buf : StringBuilder, p : PaintProperties) -> Unit {
  buf.write_string("{\"op\":")
  write_json_double(buf, p.opacity)
  buf.write_string(",\"c\":")
  write_color_json(buf, p.color)
  buf.write_string(",\"bg\":")
  write_color_json(buf, p.background_color)
  buf.write_string(",\"fs\":")
  write_json_double(buf, p.font_size)
  if p.line_height != p.font_size {
    buf.write_string(",\"lh\":")
    write_json_double(buf, p.line_height)
  }
  if p.letter_spacing != 0.0 {
    buf.write_string(",\"ls\":")
    write_json_double(buf, p.letter_spacing)
  }
  if p.word_spacing != 0.0 {
    buf.write_string(",\"ws\":")
    write_json_double(buf, p.word_spacing)
  }
  if p.is_bold {
    buf.write_string(",\"b\":true")
  }
  if p.font_family != "" {
    buf.write_string(",\"ff\":")
    write_json_string(buf, p.font_family)
  }
  if p.text_decoration_underline {
    buf.write_string(",\"u\":true")
  }
  if p.text_decoration_line_through {
    buf.write_string(",\"lt\":true")
  }
  if p.text_decoration_overline {
    buf.write_string(",\"ov\":true")
  }
  let vis = match p.visibility {
    @style.Visibility::Visible => "visible"
    @style.Visibility::Hidden => "hidden"
    @style.Visibility::Collapse => "collapse"
  }
  if vis != "visible" {
    buf.write_string(",\"vis\":")
    write_json_string(buf, vis)
  }
  if p.border_top_left_radius != 0.0 ||
    p.border_top_right_radius != 0.0 ||
    p.border_bottom_right_radius != 0.0 ||
    p.border_bottom_left_radius != 0.0 {
    buf.write_string(",\"br\":[")
    write_json_double(buf, p.border_top_left_radius)
    buf.write_char(',')
    write_json_double(buf, p.border_top_right_radius)
    buf.write_char(',')
    write_json_double(buf, p.border_bottom_right_radius)
    buf.write_char(',')
    write_json_double(buf, p.border_bottom_left_radius)
    buf.write_char(']')
  }
  if p.border_top_width != 0.0 ||
    p.border_right_width != 0.0 ||
    p.border_bottom_width != 0.0 ||
    p.border_left_width != 0.0 {
    buf.write_string(",\"bw\":[")
    write_json_double(buf, p.border_top_width)
    buf.write_char(',')
    write_json_double(buf, p.border_right_width)
    buf.write_char(',')
    write_json_double(buf, p.border_bottom_width)
    buf.write_char(',')
    write_json_double(buf, p.border_left_width)
    buf.write_char(']')
  }
  if p.border_top_color != @types.Color::transparent() ||
    p.border_right_color != @types.Color::transparent() ||
    p.border_bottom_color != @types.Color::transparent() ||
    p.border_left_color != @types.Color::transparent() {
    buf.write_string(",\"bc\":[")
    write_color_json(buf, p.border_top_color)
    buf.write_char(',')
    write_color_json(buf, p.border_right_color)
    buf.write_char(',')
    write_color_json(buf, p.border_bottom_color)
    buf.write_char(',')
    write_color_json(buf, p.border_left_color)
    buf.write_char(']')
  }
  buf.write_char('}')
}

///|
fn write_color_json(buf : StringBuilder, c : @types.Color) -> Unit {
  buf.write_char('[')
  buf.write_string(c.r.to_string())
  buf.write_char(',')
  buf.write_string(c.g.to_string())
  buf.write_char(',')
  buf.write_string(c.b.to_string())
  buf.write_char(',')
  write_json_double(buf, c.a)
  buf.write_char(']')
}

///|
fn overflow_to_str(o : @types.Overflow) -> String {
  match o {
    @types.Visible => "visible"
    @types.Hidden => "hidden"
    @types.Clip => "clip"
    @types.Scroll => "scroll"
    @types.Auto => "auto"
  }
}

///|
fn write_json_string(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
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
  buf.write_char('"')
}

///|
fn write_json_double(buf : StringBuilder, v : Double) -> Unit {
  if v == 0.0 {
    buf.write_char('0')
    return
  }
  let rounded = (v * 100.0 + 0.5).to_int().to_double() / 100.0
  buf.write_string(rounded.to_string())
}
