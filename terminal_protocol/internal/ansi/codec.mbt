///|
/// ANSI Escape Sequences for terminal output.
/// This package is layout-free and can be reused by browser/TUI adapters.

///|
pub fn ansi_reset() -> String {
  "\u001b[0m"
}

///|
pub fn ansi_bold() -> String {
  "\u001b[1m"
}

///|
pub fn ansi_dim() -> String {
  "\u001b[2m"
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
pub fn ansi_fg_256(color_idx : Int32) -> String {
  "\u001b[38;5;" + color_idx.to_string() + "m"
}

///|
pub fn ansi_bg_256(color_idx : Int32) -> String {
  "\u001b[48;5;" + color_idx.to_string() + "m"
}

///|
pub fn ansi_bg_reset() -> String {
  "\u001b[49m"
}

///|
/// Move cursor to a 0-indexed row/column.
pub fn ansi_move_to(row : Int32, col : Int32) -> String {
  "\u001b[" + (row + 1).to_string() + ";" + (col + 1).to_string() + "H"
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
pub fn ansi_reset_attrs() -> String {
  ansi_reset()
}

///|
pub fn ansi_full_reset() -> String {
  ansi_reset() +
  ansi_enter_alt_screen() +
  ansi_hide_cursor() +
  ansi_clear_screen() +
  "\u001b[H"
}

///|
pub fn rgb_to_256(r : Int32, g : Int32, b : Int32) -> Int32 {
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
pub fn enable_mouse() -> String {
  "\u001b[?1000h\u001b[?1006h"
}

///|
pub fn disable_mouse() -> String {
  "\u001b[?1006l\u001b[?1000l"
}

///|
pub fn enable_mouse_all() -> String {
  "\u001b[?1003h\u001b[?1006h"
}

///|
pub fn disable_mouse_all() -> String {
  "\u001b[?1006l\u001b[?1003l"
}
