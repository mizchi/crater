///|
pub using @tui_primitives {type CharBuffer, type CharCell, type TextStyle}

///|
pub fn char_display_width(c : Char) -> Int {
  @tui_primitives.char_display_width(c)
}
