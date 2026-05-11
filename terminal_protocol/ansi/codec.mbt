///|
pub fn ansi_reset() -> String {
  @tui_ansi.ansi_reset()
}

///|
pub fn ansi_bold() -> String {
  @tui_ansi.ansi_bold()
}

///|
pub fn ansi_underline() -> String {
  @tui_ansi.ansi_underline()
}

///|
pub fn ansi_reverse() -> String {
  @tui_ansi.ansi_reverse()
}

///|
pub fn ansi_fg_256(color_idx : Int) -> String {
  @tui_ansi.ansi_fg_256(color_idx)
}

///|
pub fn ansi_bg_256(color_idx : Int) -> String {
  @tui_ansi.ansi_bg_256(color_idx)
}

///|
pub fn ansi_move_to(row : Int, col : Int) -> String {
  @tui_ansi.ansi_move_to(row, col)
}

///|
pub fn rgb_to_256(r : Int, g : Int, b : Int) -> Int {
  @tui_ansi.rgb_to_256(r, g, b)
}

///|
pub fn enable_mouse_all() -> String {
  @tui_ansi.enable_mouse_all()
}

///|
pub fn disable_mouse_all() -> String {
  @tui_ansi.disable_mouse_all()
}
