///|
pub using @tui_primitives {type BoxStyle}

///|
pub fn draw_box(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  w : Int32,
  h : Int32,
  style : BoxStyle,
  fg : @types.Color,
  bg : @types.Color,
) -> Unit {
  @tui_primitives.draw_box(buf, x, y, w, h, style, fg, bg)
}

///|
pub fn draw_filled_box(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  w : Int32,
  h : Int32,
  style : BoxStyle,
  fg : @types.Color,
  bg : @types.Color,
) -> Unit {
  @tui_primitives.draw_filled_box(buf, x, y, w, h, style, fg, bg)
}

///|
pub fn draw_hline(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  w : Int32,
  style : BoxStyle,
  fg : @types.Color,
) -> Unit {
  @tui_primitives.draw_hline(buf, x, y, w, style, fg)
}

///|
pub fn draw_vline(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  h : Int32,
  style : BoxStyle,
  fg : @types.Color,
) -> Unit {
  @tui_primitives.draw_vline(buf, x, y, h, style, fg)
}

///|
pub fn draw_link(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  text : String,
  max_width : Int32,
  focused : Bool,
) -> Int32 {
  @tui_primitives.draw_link(buf, x, y, text, max_width, focused)
}

///|
pub fn draw_heading(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  text : String,
  max_width : Int32,
  level : Int32,
) -> Int32 {
  @tui_primitives.draw_heading(buf, x, y, text, max_width, level)
}

///|
pub fn draw_scrollbar(
  buf : CharBuffer,
  x : Int32,
  y : Int32,
  height : Int32,
  scroll_pos : Int32,
  content_height : Int32,
  visible_height : Int32,
) -> Unit {
  @tui_primitives.draw_scrollbar(
    buf, x, y, height, scroll_pos, content_height, visible_height,
  )
}

///|
pub fn draw_status_bar(
  buf : CharBuffer,
  y : Int32,
  url : String,
  link_count : Int32,
  focused_link : Int32,
  focused_link_url~ : String? = None,
  selection_mode~ : Bool = false,
  dark_mode~ : Bool = false,
) -> Unit {
  @tui_primitives.draw_status_bar(
    buf,
    y,
    url,
    link_count,
    focused_link,
    focused_link_url~,
    selection_mode~,
    dark_mode~,
  )
}
