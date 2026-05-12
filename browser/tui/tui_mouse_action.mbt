///|
/// Mouse action parsing for TUI key events.

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
