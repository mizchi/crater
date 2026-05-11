///|
pub using @tui_primitives {type BoxStyle}

///|
pub fn draw_box(
  buf : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  style : BoxStyle,
  fg : @types.Color,
  bg : @types.Color,
) -> Unit {
  @tui_primitives.draw_box(buf, x, y, w, h, style, fg, bg)
}

///|
pub fn draw_filled_box(
  buf : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  style : BoxStyle,
  fg : @types.Color,
  bg : @types.Color,
) -> Unit {
  @tui_primitives.draw_filled_box(buf, x, y, w, h, style, fg, bg)
}

///|
pub fn draw_hline(
  buf : CharBuffer,
  x : Int,
  y : Int,
  w : Int,
  style : BoxStyle,
  fg : @types.Color,
) -> Unit {
  @tui_primitives.draw_hline(buf, x, y, w, style, fg)
}

///|
pub fn draw_vline(
  buf : CharBuffer,
  x : Int,
  y : Int,
  h : Int,
  style : BoxStyle,
  fg : @types.Color,
) -> Unit {
  @tui_primitives.draw_vline(buf, x, y, h, style, fg)
}

///|
pub fn draw_link(
  buf : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  focused : Bool,
) -> Int {
  @tui_primitives.draw_link(buf, x, y, text, max_width, focused)
}

///|
pub fn draw_heading(
  buf : CharBuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  level : Int,
) -> Int {
  @tui_primitives.draw_heading(buf, x, y, text, max_width, level)
}

///|
pub fn draw_scrollbar(
  buf : CharBuffer,
  x : Int,
  y : Int,
  height : Int,
  scroll_pos : Int,
  content_height : Int,
  visible_height : Int,
) -> Unit {
  @tui_primitives.draw_scrollbar(
    buf, x, y, height, scroll_pos, content_height, visible_height,
  )
}

///|
pub fn draw_status_bar(
  buf : CharBuffer,
  y : Int,
  url : String,
  link_count : Int,
  focused_link : Int,
  focused_link_url? : String? = None,
  selection_mode? : Bool = false,
  dark_mode? : Bool = false,
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
