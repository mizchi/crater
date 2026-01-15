///|
test "CharBuffer::new creates buffer with correct size" {
  let buf = CharBuffer::new(10, 5)
  inspect(buf.width, content="10")
  inspect(buf.height, content="5")
}

///|
test "CharBuffer::write_text writes text correctly" {
  let buf = CharBuffer::new(20, 3)
  let style = TextStyle::default()
  let written = buf.write_text(0, 0, "Hello", style, 20)
  inspect(written, content="5")
  inspect(buf.get_cell(0, 0).char, content="H")
  inspect(buf.get_cell(4, 0).char, content="o")
}

///|
test "char_display_width handles ASCII and CJK" {
  inspect(char_display_width('A'), content="1")
  inspect(char_display_width('a'), content="1")
  inspect(char_display_width('\u4E2D'), content="2") // 中
  inspect(char_display_width('\u3042'), content="2") // あ
}

///|
test "string_display_width calculates mixed text" {
  inspect(string_display_width("Hello"), content="5")
  inspect(string_display_width("AB\u4E2D"), content="4") // AB中
}

///|
test "BorderChars::single returns correct characters" {
  let border = BorderChars::single()
  inspect(border.top_left, content="┌")
  inspect(border.horizontal, content="─")
}
