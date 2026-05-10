///|
pub using @tui_core {type CharBuffer, type CharCell, type TextStyle}

///|
pub fn char_display_width(c : Char) -> Int {
  @tui_core.char_display_width(c)
}
