///|
pub using @tui_core {type DirtyRect, type PlainLink}

///|
pub fn ansi_reset() -> String {
  @tui_core.ansi_reset()
}

///|
pub fn ansi_bold() -> String {
  @tui_core.ansi_bold()
}

///|
pub fn ansi_underline() -> String {
  @tui_core.ansi_underline()
}

///|
pub fn ansi_reverse() -> String {
  @tui_core.ansi_reverse()
}

///|
pub fn ansi_fg_256(color_idx : Int) -> String {
  @tui_core.ansi_fg_256(color_idx)
}

///|
pub fn ansi_bg_256(color_idx : Int) -> String {
  @tui_core.ansi_bg_256(color_idx)
}

///|
pub fn ansi_move_to(row : Int, col : Int) -> String {
  @tui_core.ansi_move_to(row, col)
}

///|
pub fn rgb_to_256(r : Int, g : Int, b : Int) -> Int {
  @tui_core.rgb_to_256(r, g, b)
}

///|
pub fn color_to_256(color : @types.Color) -> Int {
  @tui_core.color_to_256(color)
}

///|
pub fn ansi_fg_color(color : @types.Color) -> String {
  @tui_core.ansi_fg_color(color)
}

///|
pub fn ansi_bg_color(color : @types.Color) -> String {
  @tui_core.ansi_bg_color(color)
}

///|
pub fn buffer_to_ansi(buf : CharBuffer, max_cols? : Int = 0) -> String {
  @tui_core.buffer_to_ansi(buf, max_cols~)
}

///|
pub fn buffer_diff_to_ansi(
  current : CharBuffer,
  prev : CharBuffer,
  max_cols? : Int = 0,
) -> String {
  @tui_core.buffer_diff_to_ansi(current, prev, max_cols~)
}

///|
pub fn buffer_diff_to_ansi_rects(
  current : CharBuffer,
  prev : CharBuffer,
  rects : Array[DirtyRect],
  max_cols? : Int = 0,
) -> String {
  @tui_core.buffer_diff_to_ansi_rects(current, prev, rects, max_cols~)
}

///|
pub fn enable_mouse() -> String {
  @tui_core.enable_mouse()
}

///|
pub fn disable_mouse() -> String {
  @tui_core.disable_mouse()
}

///|
pub fn ansi_hyperlink_start(url : String) -> String {
  @tui_core.ansi_hyperlink_start(url)
}

///|
pub fn ansi_hyperlink_end() -> String {
  @tui_core.ansi_hyperlink_end()
}

///|
pub fn buffer_to_plain(buf : CharBuffer) -> String {
  @tui_core.buffer_to_plain(buf)
}

///|
pub fn buffer_to_plain_with_links(
  buf : CharBuffer,
  links : Array[PlainLink],
) -> String {
  @tui_core.buffer_to_plain_with_links(buf, links)
}
