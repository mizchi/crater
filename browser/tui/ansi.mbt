///|
pub using @tui_primitives {type DirtyRect, type PlainLink}

///|
pub fn ansi_reset() -> String {
  @tui_primitives.ansi_reset()
}

///|
pub fn ansi_bold() -> String {
  @tui_primitives.ansi_bold()
}

///|
pub fn ansi_underline() -> String {
  @tui_primitives.ansi_underline()
}

///|
pub fn ansi_reverse() -> String {
  @tui_primitives.ansi_reverse()
}

///|
pub fn ansi_fg_256(color_idx : Int) -> String {
  @tui_primitives.ansi_fg_256(color_idx)
}

///|
pub fn ansi_bg_256(color_idx : Int) -> String {
  @tui_primitives.ansi_bg_256(color_idx)
}

///|
pub fn ansi_move_to(row : Int, col : Int) -> String {
  @tui_primitives.ansi_move_to(row, col)
}

///|
pub fn rgb_to_256(r : Int, g : Int, b : Int) -> Int {
  @tui_primitives.rgb_to_256(r, g, b)
}

///|
pub fn color_to_256(color : @types.Color) -> Int {
  @tui_primitives.color_to_256(color)
}

///|
pub fn ansi_fg_color(color : @types.Color) -> String {
  @tui_primitives.ansi_fg_color(color)
}

///|
pub fn ansi_bg_color(color : @types.Color) -> String {
  @tui_primitives.ansi_bg_color(color)
}

///|
pub fn buffer_to_ansi(buf : CharBuffer, max_cols? : Int = 0) -> String {
  @tui_primitives.buffer_to_ansi(buf, max_cols~)
}

///|
pub fn buffer_diff_to_ansi(
  current : CharBuffer,
  prev : CharBuffer,
  max_cols? : Int = 0,
) -> String {
  @tui_primitives.buffer_diff_to_ansi(current, prev, max_cols~)
}

///|
pub fn buffer_diff_to_ansi_rects(
  current : CharBuffer,
  prev : CharBuffer,
  rects : Array[DirtyRect],
  max_cols? : Int = 0,
) -> String {
  @tui_primitives.buffer_diff_to_ansi_rects(current, prev, rects, max_cols~)
}

///|
pub fn enable_mouse() -> String {
  @tui_primitives.enable_mouse()
}

///|
pub fn disable_mouse() -> String {
  @tui_primitives.disable_mouse()
}

///|
pub fn ansi_hyperlink_start(url : String) -> String {
  @tui_primitives.ansi_hyperlink_start(url)
}

///|
pub fn ansi_hyperlink_end() -> String {
  @tui_primitives.ansi_hyperlink_end()
}

///|
pub fn buffer_to_plain(buf : CharBuffer) -> String {
  @tui_primitives.buffer_to_plain(buf)
}

///|
pub fn buffer_to_plain_with_links(
  buf : CharBuffer,
  links : Array[PlainLink],
) -> String {
  @tui_primitives.buffer_to_plain_with_links(buf, links)
}
