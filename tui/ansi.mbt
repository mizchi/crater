///|
/// ANSI Escape Sequences for terminal output

///|
pub fn ansi_reset() -> String {
  "\u001b[0m"
}

///|
pub fn ansi_bold() -> String {
  "\u001b[1m"
}

///|
pub fn ansi_underline() -> String {
  "\u001b[4m"
}

///|
pub fn ansi_reverse() -> String {
  "\u001b[7m"
}

///|
pub fn ansi_fg_256(color_idx : Int) -> String {
  "\u001b[38;5;" + color_idx.to_string() + "m"
}

///|
pub fn ansi_bg_256(color_idx : Int) -> String {
  "\u001b[48;5;" + color_idx.to_string() + "m"
}

///|
pub fn ansi_move_to(row : Int, col : Int) -> String {
  "\u001b[" + row.to_string() + ";" + col.to_string() + "H"
}

///|
pub fn ansi_clear_screen() -> String {
  "\u001b[2J"
}

///|
pub fn ansi_clear_line() -> String {
  "\u001b[2K"
}

///|
pub fn ansi_hide_cursor() -> String {
  "\u001b[?25l"
}

///|
pub fn ansi_show_cursor() -> String {
  "\u001b[?25h"
}

///|
pub fn ansi_enter_alt_screen() -> String {
  "\u001b[?1049h"
}

///|
pub fn ansi_leave_alt_screen() -> String {
  "\u001b[?1049l"
}

///|
/// Convert RGB color to 256-color palette index
pub fn rgb_to_256(r : Int, g : Int, b : Int) -> Int {
  if r == g && g == b {
    if r < 8 {
      16
    } else if r > 248 {
      231
    } else {
      232 + (r - 8) * 24 / 240
    }
  } else {
    let r6 = r * 6 / 256
    let g6 = g * 6 / 256
    let b6 = b * 6 / 256
    16 + r6 * 36 + g6 * 6 + b6
  }
}

///|
pub fn color_to_256(color : Color) -> Int {
  rgb_to_256(color.r, color.g, color.b)
}

///|
pub fn ansi_fg_color(color : Color) -> String {
  ansi_fg_256(color_to_256(color))
}

///|
pub fn ansi_bg_color(color : Color) -> String {
  ansi_bg_256(color_to_256(color))
}

///|
/// Convert CharBuffer to ANSI-encoded string
pub fn buffer_to_ansi(buf : CharBuffer) -> String {
  let sb = StringBuilder::new()
  let mut last_fg = -1
  let mut last_bg = -1
  let mut last_bold = false
  let mut last_underline = false
  for row = 0; row < buf.height; row = row + 1 {
    sb.write_string(ansi_move_to(row + 1, 1))
    for col = 0; col < buf.width; col = col + 1 {
      let cell = buf.get_cell(col, row)
      if cell.char == '\u0000' {
        continue
      }
      let fg_idx = if cell.fg.is_transparent() {
        7
      } else {
        color_to_256(cell.fg)
      }
      let bg_idx = if cell.bg.is_transparent() {
        -1
      } else {
        color_to_256(cell.bg)
      }
      let need_reset = (last_bold && not(cell.bold)) ||
        (last_underline && not(cell.underline))
      if need_reset {
        sb.write_string(ansi_reset())
        last_fg = -1
        last_bg = -1
        last_bold = false
        last_underline = false
      }
      if cell.bold && not(last_bold) {
        sb.write_string(ansi_bold())
        last_bold = true
      }
      if cell.underline && not(last_underline) {
        sb.write_string(ansi_underline())
        last_underline = true
      }
      if fg_idx != last_fg {
        sb.write_string(ansi_fg_256(fg_idx))
        last_fg = fg_idx
      }
      if bg_idx >= 0 && bg_idx != last_bg {
        sb.write_string(ansi_bg_256(bg_idx))
        last_bg = bg_idx
      }
      sb.write_char(cell.char)
    }
  }
  sb.write_string(ansi_reset())
  sb.to_string()
}

///|
/// Optimized ANSI output with diff (only output changed cells)
pub fn buffer_diff_to_ansi(current : CharBuffer, prev : CharBuffer) -> String {
  let sb = StringBuilder::new()
  let mut last_row = -1
  let mut last_col = -1
  let mut last_fg = -1
  let mut last_bg = -1
  let mut last_bold = false
  let mut last_underline = false
  for row = 0; row < current.height; row = row + 1 {
    for col = 0; col < current.width; col = col + 1 {
      let cell = current.get_cell(col, row)
      let prev_cell = prev.get_cell(col, row)
      if cell == prev_cell {
        continue
      }
      if cell.char == '\u0000' {
        continue
      }
      if row != last_row || col != last_col + 1 {
        sb.write_string(ansi_move_to(row + 1, col + 1))
      }
      let fg_idx = if cell.fg.is_transparent() {
        7
      } else {
        color_to_256(cell.fg)
      }
      let bg_idx = if cell.bg.is_transparent() {
        -1
      } else {
        color_to_256(cell.bg)
      }
      let need_reset = (last_bold && not(cell.bold)) ||
        (last_underline && not(cell.underline))
      if need_reset {
        sb.write_string(ansi_reset())
        last_fg = -1
        last_bg = -1
        last_bold = false
        last_underline = false
      }
      if cell.bold && not(last_bold) {
        sb.write_string(ansi_bold())
        last_bold = true
      }
      if cell.underline && not(last_underline) {
        sb.write_string(ansi_underline())
        last_underline = true
      }
      if fg_idx != last_fg {
        sb.write_string(ansi_fg_256(fg_idx))
        last_fg = fg_idx
      }
      if bg_idx >= 0 && bg_idx != last_bg {
        sb.write_string(ansi_bg_256(bg_idx))
        last_bg = bg_idx
      }
      sb.write_char(cell.char)
      last_row = row
      last_col = col
    }
  }
  sb.write_string(ansi_reset())
  sb.to_string()
}

///|
pub fn enable_mouse() -> String {
  "\u001b[?1000h\u001b[?1006h"
}

///|
pub fn disable_mouse() -> String {
  "\u001b[?1006l\u001b[?1000l"
}
