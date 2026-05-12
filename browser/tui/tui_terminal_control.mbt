///|
/// Terminal control escape sequences used by the TUI.

///|
/// Clear terminal screen (ANSI escape)
pub fn clear_screen() -> String {
  "\u001b[2J\u001b[H"
}

///|
/// Enter alternate screen buffer (like vim/less)
pub fn enter_alt_screen() -> String {
  "\u001b[?1049h\u001b[H"
}

///|
/// Exit alternate screen buffer (restore previous screen)
pub fn exit_alt_screen() -> String {
  "\u001b[?1049l"
}

///|
/// Move cursor to position (ANSI escape)
pub fn move_cursor(row : Int, col : Int) -> String {
  "\u001b[" + row.to_string() + ";" + col.to_string() + "H"
}

///|
/// Hide cursor (ANSI escape)
pub fn hide_cursor() -> String {
  "\u001b[?25l"
}

///|
/// Show cursor (ANSI escape)
pub fn show_cursor() -> String {
  "\u001b[?25h"
}

///|
/// Status bar format
pub fn format_status_bar(
  url : String,
  link_count : Int,
  focused : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("\u001b[7m") // Reverse video
  buf.write_string(" URL: ")
  buf.write_string(url)
  buf.write_string(" | Focus: ")
  buf.write_string((focused + 1).to_string())
  buf.write_string("/")
  buf.write_string(link_count.to_string())
  buf.write_string(" | q:quit j/k:scroll Tab:focus Enter:go v:select ")
  buf.write_string("\u001b[0m") // Reset
  buf.to_string()
}
