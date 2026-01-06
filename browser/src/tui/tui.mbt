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
  MouseClick(Int, Int) // (col, row) coordinates
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
    _ =>
      // Check for mouse click: "Mouse:col,row"
      if key.has_prefix("Mouse:") {
        parse_mouse_click(key)
      } else {
        None
      }
  }
}

///|
/// Parse mouse click event "Mouse:col,row" into MouseClick action
fn parse_mouse_click(key : String) -> BrowserAction? {
  // Format: "Mouse:col,row"
  let parts = try {
    key[6:].to_string()
  } catch {
    _ => return None
  }
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = try {
        parts[:comma_idx].to_string()
      } catch {
        _ => return None
      }
      let row_str = try {
        parts[comma_idx + 1:].to_string()
      } catch {
        _ => return None
      }
      let col = @strconv.parse_int(col_str) catch { _ => return None }
      let row = @strconv.parse_int(row_str) catch { _ => return None }
      Some(MouseClick(col, row))
    }
    None => None
  }
}

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
  buf.write_string(" | Links: ")
  buf.write_string((focused + 1).to_string())
  buf.write_string("/")
  buf.write_string(link_count.to_string())
  buf.write_string(" | q:quit j/k:scroll Tab:next link Enter:go ")
  buf.write_string("\u001b[0m") // Reset
  buf.to_string()
}
