///|
/// TUI (Terminal User Interface) common types and utilities

///|
/// Browser action triggered by user input
pub enum BrowserAction {
  ScrollUp
  ScrollDown
  NextLink
  PrevLink
  ActivateLink
  GoToUrl(String)
  Refresh
  Quit
}

///|
/// Map key to browser action
pub fn key_to_action(key : String) -> BrowserAction? {
  match key {
    "j" | "ArrowDown" => Some(ScrollDown)
    "k" | "ArrowUp" => Some(ScrollUp)
    "Tab" | "n" => Some(NextLink)
    "N" | "p" => Some(PrevLink)
    "Enter" => Some(ActivateLink)
    "g" => Some(GoToUrl(""))
    "r" => Some(Refresh)
    "q" | "Escape" => Some(Quit)
    _ => None
  }
}

///|
/// Clear terminal screen (ANSI escape)
pub fn clear_screen() -> String {
  "\u001b[2J\u001b[H"
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
  buf.write_string(" | Links: ")
  buf.write_string((focused + 1).to_string())
  buf.write_string("/")
  buf.write_string(link_count.to_string())
  buf.write_string(" | q:quit j/k:scroll Tab:next link Enter:go ")
  buf.write_string("\u001b[0m") // Reset
  buf.to_string()
}
