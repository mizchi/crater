///|
/// Additional tests for character width calculation

///|
test "char_display_width: Hiragana is full-width" {
  inspect(char_display_width('あ'), content="2")
  inspect(char_display_width('い'), content="2")
  inspect(char_display_width('う'), content="2")
  inspect(char_display_width('ん'), content="2")
}

///|
test "char_display_width: Katakana is full-width" {
  inspect(char_display_width('ア'), content="2")
  inspect(char_display_width('イ'), content="2")
  inspect(char_display_width('カ'), content="2")
  inspect(char_display_width('ン'), content="2")
}

///|
test "char_display_width: Full-width ASCII" {
  // Full-width letters (U+FF00 - U+FF60)
  inspect(char_display_width('Ａ'), content="2") // U+FF21
  inspect(char_display_width('ａ'), content="2") // U+FF41
  inspect(char_display_width('０'), content="2") // U+FF10
}

///|
test "string_display_width: mixed width strings" {
  // "abc" = 3 half-width chars = width 3
  inspect(string_display_width("abc"), content="3")
  // "あいう" = 3 full-width chars = width 6
  inspect(string_display_width("あいう"), content="6")
  // "abcあいう" = 3 half + 3 full = 3 + 6 = 9
  inspect(string_display_width("abcあいう"), content="9")
  // "Hello世界" = 5 half + 2 full = 5 + 4 = 9
  inspect(string_display_width("Hello世界"), content="9")
}

///|
test "string_display_width: empty string" {
  inspect(string_display_width(""), content="0")
}
