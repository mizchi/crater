///|
/// TUI (Terminal User Interface) common types and utilities

///|
/// Browser action triggered by user input
pub enum BrowserAction {
  ScrollUp
  ScrollDown
  PageUp // Scroll up by one page
  PageDown // Scroll down by one page
  NextLink
  PrevLink
  ActivateLink
  GoToUrl(String)
  Refresh
  Quit
  Back // Go back to previous page
  Forward // Go forward to next page
  MouseClick(Int, Int) // Legacy synthesized click at (col, row)
  MouseDown(Int, Int) // Mouse button press at (col, row)
  MouseUp(Int, Int) // Mouse button release at (col, row)
  MouseMove(Int, Int) // Mouse move at (col, row)
  MouseScrollUp(Int, Int) // Mouse wheel scroll up at (col, row)
  MouseScrollDown(Int, Int) // Mouse wheel scroll down at (col, row)
  EnterHintMode // Start hit-a-hint mode (triggered by 'f')
  HintChar(String) // Hint character input (a-z)
  ExitHintMode // Exit hint mode (Escape)
  ToggleRawMode // Toggle raw mode for text selection (triggered by 'v')
  ToggleDarkMode // Toggle dark mode (triggered by 'd')
}

///|
/// Map key to browser action (normal mode)
pub fn key_to_action(key : String) -> BrowserAction? {
  match key {
    "j" | "ArrowDown" => Some(ScrollDown)
    "k" | "ArrowUp" => Some(ScrollUp)
    "Ctrl-D" | "PageDown" | " " => Some(PageDown)
    "Ctrl-U" | "PageUp" | "Shift-Space" => Some(PageUp)
    "Tab" | "n" => Some(NextLink)
    "Shift-Tab" | "N" | "p" => Some(PrevLink)
    "Enter" => Some(ActivateLink)
    "g" => Some(GoToUrl(""))
    "r" => Some(Refresh)
    "q" => Some(Quit)
    "f" => Some(EnterHintMode)
    "Escape" => Some(ExitHintMode)
    "v" => Some(ToggleRawMode)
    "d" => Some(ToggleDarkMode)
    "H" | "Backspace" | "Delete" => Some(Back)
    "L" => Some(Forward)
    _ =>
      // Check for mouse events: "Mouse:col,row", "MouseDown:col,row",
      // "MouseUp:col,row", "MouseMove:col,row",
      // "MouseScrollUp:col,row", or "MouseScrollDown:col,row"
      if key.has_prefix("MouseScrollUp:") {
        parse_mouse_scroll_up(key)
      } else if key.has_prefix("MouseScrollDown:") {
        parse_mouse_scroll_down(key)
      } else if key.has_prefix("MouseDown:") {
        parse_mouse_down(key)
      } else if key.has_prefix("MouseUp:") {
        parse_mouse_up(key)
      } else if key.has_prefix("MouseMove:") {
        parse_mouse_move(key)
      } else if key.has_prefix("Mouse:") {
        parse_mouse_click(key)
      } else {
        None
      }
  }
}

///|
/// Map key to browser action in hint mode
/// In hint mode, a-z are hint characters, Escape exits
pub fn key_to_hint_action(key : String) -> BrowserAction? {
  match key {
    "Escape" => Some(ExitHintMode)
    _ => {
      // Check if it's a single lowercase letter
      if key.length() == 1 {
        let c = key[0]
        // MoonBit doesn't have char range check easily, use code comparison
        // a-z are 97-122
        if c >= 'a' && c <= 'z' {
          return Some(HintChar(key))
        }
      }
      None
    }
  }
}

///|
/// Parse mouse click event "Mouse:col,row" into MouseClick action
fn parse_mouse_click(key : String) -> BrowserAction? {
  // Format: "Mouse:col,row"
  let parts = key.unsafe_substring(start=6, end=key.length())
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = parts.unsafe_substring(start=0, end=comma_idx)
      let row_str = parts.unsafe_substring(
        start=comma_idx + 1,
        end=parts.length(),
      )
      let col = @string.parse_int(col_str) catch { _ => return None }
      let row = @string.parse_int(row_str) catch { _ => return None }
      Some(MouseClick(col, row))
    }
    None => None
  }
}

///|
fn parse_mouse_down(key : String) -> BrowserAction? {
  let parts = key.unsafe_substring(start=10, end=key.length())
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = parts.unsafe_substring(start=0, end=comma_idx)
      let row_str = parts.unsafe_substring(
        start=comma_idx + 1,
        end=parts.length(),
      )
      let col = @string.parse_int(col_str) catch { _ => return None }
      let row = @string.parse_int(row_str) catch { _ => return None }
      Some(MouseDown(col, row))
    }
    None => None
  }
}

///|
fn parse_mouse_up(key : String) -> BrowserAction? {
  let parts = key.unsafe_substring(start=8, end=key.length())
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = parts.unsafe_substring(start=0, end=comma_idx)
      let row_str = parts.unsafe_substring(
        start=comma_idx + 1,
        end=parts.length(),
      )
      let col = @string.parse_int(col_str) catch { _ => return None }
      let row = @string.parse_int(row_str) catch { _ => return None }
      Some(MouseUp(col, row))
    }
    None => None
  }
}

///|
fn parse_mouse_move(key : String) -> BrowserAction? {
  let parts = key.unsafe_substring(start=10, end=key.length())
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = parts.unsafe_substring(start=0, end=comma_idx)
      let row_str = parts.unsafe_substring(
        start=comma_idx + 1,
        end=parts.length(),
      )
      let col = @string.parse_int(col_str) catch { _ => return None }
      let row = @string.parse_int(row_str) catch { _ => return None }
      Some(MouseMove(col, row))
    }
    None => None
  }
}

///|
/// Parse mouse scroll up event "MouseScrollUp:col,row"
fn parse_mouse_scroll_up(key : String) -> BrowserAction? {
  // Format: "MouseScrollUp:col,row"
  let parts = key.unsafe_substring(start=14, end=key.length())
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = parts.unsafe_substring(start=0, end=comma_idx)
      let row_str = parts.unsafe_substring(
        start=comma_idx + 1,
        end=parts.length(),
      )
      let col = @string.parse_int(col_str) catch { _ => return None }
      let row = @string.parse_int(row_str) catch { _ => return None }
      Some(MouseScrollUp(col, row))
    }
    None => None
  }
}

///|
/// Parse mouse scroll down event "MouseScrollDown:col,row"
fn parse_mouse_scroll_down(key : String) -> BrowserAction? {
  // Format: "MouseScrollDown:col,row"
  let parts = key.unsafe_substring(start=16, end=key.length())
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = parts.unsafe_substring(start=0, end=comma_idx)
      let row_str = parts.unsafe_substring(
        start=comma_idx + 1,
        end=parts.length(),
      )
      let col = @string.parse_int(col_str) catch { _ => return None }
      let row = @string.parse_int(row_str) catch { _ => return None }
      Some(MouseScrollDown(col, row))
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
  buf.write_string(" | Focus: ")
  buf.write_string((focused + 1).to_string())
  buf.write_string("/")
  buf.write_string(link_count.to_string())
  buf.write_string(" | q:quit j/k:scroll Tab:focus Enter:go v:select ")
  buf.write_string("\u001b[0m") // Reset
  buf.to_string()
}
