///|
/// Hint overlay rendering for TUI hit-a-hint mode.

///|
/// Hint data for hit-a-hint feature.
pub(all) struct HintData {
  label : String // The hint label (e.g., "a", "b", "aa")
  href : String // Link URL
  text : String // Link text
  col : Int // Screen column position
  row : Int // Screen row position
}

///|
/// Calculate display width of a string (full-width chars count as 2).
fn display_width(s : String) -> Int {
  let mut width = 0
  for c in s {
    // Basic check: characters above U+2E80 are typically full-width.
    let code = c.to_int()
    if code >= 0x2E80 {
      width = width + 2
    } else {
      width = width + 1
    }
  }
  width
}

///|
/// Draw hint overlays on the buffer.
/// Labels are shown to the right of link text for visibility.
fn draw_hints(
  buf : CharBuffer,
  hints : Array[HintData],
  viewport_height : Int,
) -> Unit {
  let hint_style : TextStyle = {
    fg: @types.Color::rgb(0, 0, 0), // Black text
    bg: @types.Color::rgb(255, 220, 0), // Bright yellow background
    bold: true,
    underline: false,
  }
  for hint in hints {
    if hint.row < 0 || hint.row >= viewport_height {
      continue
    }
    let label_text = "[" + hint.label + "]"
    let label_col = hint.col + display_width(hint.text)
    let _ = buf.write_text(
      label_col,
      hint.row,
      label_text,
      hint_style,
      label_text.length(),
    )
  }
}

///|
/// Draw status bar for hint mode with hint list.
fn draw_hint_mode_status_bar(
  buf : CharBuffer,
  y : Int,
  hint_input : String,
  hints : Array[HintData],
) -> Unit {
  let style : TextStyle = {
    fg: @types.Color::rgb(0, 0, 0),
    bg: @types.Color::rgb(255, 220, 0),
    bold: true,
    underline: false,
  }
  for col = 0; col < buf.width; col = col + 1 {
    let cell : CharCell = {
      char: ' ',
      fg: @types.Color::rgb(0, 0, 0),
      bg: @types.Color::rgb(255, 220, 0),
      bold: false,
      underline: false,
      reverse: false,
    }
    buf.set_cell(col, y, cell)
  }
  let sb = StringBuilder::new()
  sb.write_string(" HINT [")
  sb.write_string(hint_input)
  sb.write_string("]: ")
  let mut shown = 0
  let max_show = 8
  for hint in hints {
    if hint_input.length() == 0 || hint.label.has_prefix(hint_input) {
      if shown > 0 {
        sb.write_string(" ")
      }
      sb.write_string(hint.label)
      sb.write_string(":")
      let text = hint.text
      let max_len = 12
      if text.to_array().length() > max_len {
        let chars = text.to_array()
        for i = 0; i < max_len - 2; i = i + 1 {
          sb.write_char(chars[i])
        }
        sb.write_string("..")
      } else {
        sb.write_string(text)
      }
      shown = shown + 1
      if shown >= max_show {
        sb.write_string(" ...")
        break
      }
    }
  }
  if shown == 0 {
    sb.write_string("(no match)")
  }
  sb.write_string(" | ESC:cancel")
  let status = sb.to_string()
  let _ = buf.write_text(0, y, status, style, buf.width)
}
