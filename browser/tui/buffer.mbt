///|
pub using @tui_primitives {type CharBuffer, type CharCell, type TextStyle}

///|
pub fn char_display_width(c : Char) -> Int32 {
  @tui_primitives.char_display_width(c)
}
