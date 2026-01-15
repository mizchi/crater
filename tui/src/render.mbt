///|
/// Render crater Layout to CharBuffer

///|
/// Rendering options for a node
pub(all) struct RenderStyle {
  fg : Color
  bg : Color
  bold : Bool
  underline : Bool
  border : BorderChars?
  border_fg : Color
}

///|
pub fn RenderStyle::default() -> RenderStyle {
  {
    fg: Color::white(),
    bg: Color::transparent(),
    bold: false,
    underline: false,
    border: None,
    border_fg: Color::white(),
  }
}

///|
/// Map from node ID to render style
pub struct RenderStyleMap(Map[String, RenderStyle])

///|
pub fn RenderStyleMap::new() -> RenderStyleMap {
  RenderStyleMap(Map::new())
}

///|
pub fn RenderStyleMap::set(
  self : RenderStyleMap,
  id : String,
  style : RenderStyle,
) -> Unit {
  self.0.set(id, style)
}

///|
pub fn RenderStyleMap::get(self : RenderStyleMap, id : String) -> RenderStyle {
  match self.0.get(id) {
    Some(s) => s
    None => RenderStyle::default()
  }
}

///|
/// Map from node ID to text content
pub struct TextContentMap(Map[String, String])

///|
pub fn TextContentMap::new() -> TextContentMap {
  TextContentMap(Map::new())
}

///|
pub fn TextContentMap::set(
  self : TextContentMap,
  id : String,
  text : String,
) -> Unit {
  self.0.set(id, text)
}

///|
pub fn TextContentMap::get(self : TextContentMap, id : String) -> String? {
  self.0.get(id)
}

///|
/// Render Layout to CharBuffer
pub fn render_layout(
  buf : CharBuffer,
  layout : @node.Layout,
  styles : RenderStyleMap,
  texts : TextContentMap,
  offset_x : Int,
  offset_y : Int,
) -> Unit {
  let x = offset_x + layout.x.to_int()
  let y = offset_y + layout.y.to_int()
  let w = layout.width.to_int()
  let h = layout.height.to_int()
  let style = styles.get(layout.id)
  // Fill background if not transparent
  if not(style.bg.is_transparent()) {
    buf.fill_bg(x, y, w, h, style.bg)
  }
  // Draw border if specified
  match style.border {
    Some(border) => draw_border(buf, x, y, w, h, border, style.border_fg)
    None => ()
  }
  // Draw text content if present
  match texts.get(layout.id) {
    Some(text) => {
      let has_border = style.border is Some(_)
      let content_x = x +
        (if has_border { 1 } else { 0 }) +
        layout.padding.left.to_int()
      let content_y = y +
        (if has_border { 1 } else { 0 }) +
        layout.padding.top.to_int()
      let content_w = w -
        (if has_border { 2 } else { 0 }) -
        layout.padding.left.to_int() -
        layout.padding.right.to_int()
      let content_h = h -
        (if has_border { 2 } else { 0 }) -
        layout.padding.top.to_int() -
        layout.padding.bottom.to_int()
      if content_w > 0 && content_h > 0 {
        let text_style : TextStyle = {
          fg: style.fg,
          bg: Color::transparent(),
          bold: style.bold,
          underline: style.underline,
        }
        let _ = buf.write_text_wrapped(
          content_x, content_y, text, text_style, content_w, content_h,
        )

      }
    }
    None => ()
  }
  // Render children
  for child in layout.children {
    render_layout(buf, child, styles, texts, x, y)
  }
}

///|
fn draw_border(
  buf : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  border : BorderChars,
  fg : Color,
) -> Unit {
  if w < 2 || h < 2 {
    return
  }
  // Top-left corner
  buf.set_cell(x, y, { ..CharCell::default(), char: border.top_left, fg })
  // Top-right corner
  buf.set_cell(x + w - 1, y, {
    ..CharCell::default(),
    char: border.top_right,
    fg,
  })
  // Bottom-left corner
  buf.set_cell(x, y + h - 1, {
    ..CharCell::default(),
    char: border.bottom_left,
    fg,
  })
  // Bottom-right corner
  buf.set_cell(x + w - 1, y + h - 1, {
    ..CharCell::default(),
    char: border.bottom_right,
    fg,
  })
  // Top and bottom edges
  for col = x + 1; col < x + w - 1; col = col + 1 {
    buf.set_cell(col, y, { ..CharCell::default(), char: border.horizontal, fg })
    buf.set_cell(col, y + h - 1, {
      ..CharCell::default(),
      char: border.horizontal,
      fg,
    })
  }
  // Left and right edges
  for row = y + 1; row < y + h - 1; row = row + 1 {
    buf.set_cell(x, row, { ..CharCell::default(), char: border.vertical, fg })
    buf.set_cell(x + w - 1, row, {
      ..CharCell::default(),
      char: border.vertical,
      fg,
    })
  }
}

///|
/// Quick render function: Layout -> ANSI string
pub fn render_to_ansi(
  layout : @node.Layout,
  styles : RenderStyleMap,
  texts : TextContentMap,
  width : Int,
  height : Int,
) -> String {
  let buf = CharBuffer::new(width, height)
  render_layout(buf, layout, styles, texts, 0, 0)
  buffer_to_ansi(buf)
}
