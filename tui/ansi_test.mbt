///|
/// Tests for ANSI escape sequence generation

///|
test "ansi_move_to: generates correct escape sequence" {
  // Move to (1, 1) - ANSI is 1-indexed
  inspect(ansi_move_to(0, 0), content="\u{1b}[0;0H")
  inspect(ansi_move_to(10, 5), content="\u{1b}[10;5H")
}

///|
test "ansi_clear_screen: generates clear sequence" {
  inspect(ansi_clear_screen(), content="\u{1b}[2J")
}

///|
test "ansi_reset: generates reset sequence" {
  inspect(ansi_reset(), content="\u{1b}[0m")
}

///|
test "ansi_hide_cursor and ansi_show_cursor" {
  inspect(ansi_hide_cursor(), content="\u{1b}[?25l")
  inspect(ansi_show_cursor(), content="\u{1b}[?25h")
}

///|
test "ansi_enter_alt_screen and ansi_leave_alt_screen" {
  inspect(ansi_enter_alt_screen(), content="\u{1b}[?1049h")
  inspect(ansi_leave_alt_screen(), content="\u{1b}[?1049l")
}

///|
test "enable_mouse and disable_mouse" {
  // Should enable both X10 and SGR modes
  inspect(enable_mouse(), content="\u{1b}[?1000h\u{1b}[?1006h")
  inspect(disable_mouse(), content="\u{1b}[?1006l\u{1b}[?1000l")
}

///|
test "ansi_fg_color: generates foreground color" {
  let color = Color::rgb(255, 0, 0) // Red
  let seq = ansi_fg_color(color)
  // Uses 256-color mode
  assert_true(seq.length() > 0)
}

///|
test "ansi_bg_color: generates background color" {
  let color = Color::rgb(0, 0, 255) // Blue
  let seq = ansi_bg_color(color)
  assert_true(seq.length() > 0)
}

///|
test "rgb_to_256: converts RGB to 256 color index" {
  // Black
  inspect(rgb_to_256(0, 0, 0), content="16")
  // White
  inspect(rgb_to_256(255, 255, 255), content="231")
  // Pure red (approximate)
  inspect(rgb_to_256(255, 0, 0), content="196")
}

///|
test "ansi_bold: generates bold sequence" {
  inspect(ansi_bold(), content="\u{1b}[1m")
}

///|
test "ansi_underline: generates underline sequence" {
  inspect(ansi_underline(), content="\u{1b}[4m")
}
