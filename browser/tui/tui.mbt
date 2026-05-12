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
        parse_mouse_action(key, "MouseScrollUp:", MouseScrollUpKind)
      } else if key.has_prefix("MouseScrollDown:") {
        parse_mouse_action(key, "MouseScrollDown:", MouseScrollDownKind)
      } else if key.has_prefix("MouseDown:") {
        parse_mouse_action(key, "MouseDown:", MouseDownKind)
      } else if key.has_prefix("MouseUp:") {
        parse_mouse_action(key, "MouseUp:", MouseUpKind)
      } else if key.has_prefix("MouseMove:") {
        parse_mouse_action(key, "MouseMove:", MouseMoveKind)
      } else if key.has_prefix("Mouse:") {
        parse_mouse_action(key, "Mouse:", MouseClickKind)
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
priv enum MouseActionKind {
  MouseClickKind
  MouseDownKind
  MouseUpKind
  MouseMoveKind
  MouseScrollUpKind
  MouseScrollDownKind
}

///|
fn MouseActionKind::to_action(
  self : MouseActionKind,
  col : Int,
  row : Int,
) -> BrowserAction {
  match self {
    MouseClickKind => MouseClick(col, row)
    MouseDownKind => MouseDown(col, row)
    MouseUpKind => MouseUp(col, row)
    MouseMoveKind => MouseMove(col, row)
    MouseScrollUpKind => MouseScrollUp(col, row)
    MouseScrollDownKind => MouseScrollDown(col, row)
  }
}

///|
fn parse_mouse_action(
  key : String,
  prefix : String,
  kind : MouseActionKind,
) -> BrowserAction? {
  let parts = key.unsafe_substring(start=prefix.length(), end=key.length())
  match parts.find(",") {
    Some(comma_idx) => {
      let col_str = parts.unsafe_substring(start=0, end=comma_idx)
      let row_str = parts.unsafe_substring(
        start=comma_idx + 1,
        end=parts.length(),
      )
      let col = @string.parse_int(col_str) catch { _ => return None }
      let row = @string.parse_int(row_str) catch { _ => return None }
      Some(kind.to_action(col, row))
    }
    None => None
  }
}
