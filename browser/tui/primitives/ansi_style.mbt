///|
/// ANSI style state used while serializing character buffers.

///|
priv struct AnsiStyleState {
  mut fg : Int
  mut bg : Int
  mut bold : Bool
  mut underline : Bool
}

///|
fn AnsiStyleState::new() -> AnsiStyleState {
  { fg: -1, bg: -1, bold: false, underline: false }
}

///|
fn AnsiStyleState::reset(self : AnsiStyleState) -> Unit {
  self.fg = -1
  self.bg = -1
  self.bold = false
  self.underline = false
}

///|
fn AnsiStyleState::write_cell_style(
  self : AnsiStyleState,
  sb : StringBuilder,
  cell : CharCell,
) -> Unit {
  let fg_idx = if cell.fg.is_transparent() {
    7 // Default white
  } else {
    color_to_256(cell.fg)
  }
  let bg_idx = if cell.bg.is_transparent() {
    -1 // No background
  } else {
    color_to_256(cell.bg)
  }
  let need_reset = (self.bold && !cell.bold) ||
    (self.underline && !cell.underline)
  if need_reset {
    sb.write_string(ansi_reset())
    self.reset()
  }
  if cell.bold && !self.bold {
    sb.write_string(ansi_bold())
    self.bold = true
  }
  if cell.underline && !self.underline {
    sb.write_string(ansi_underline())
    self.underline = true
  }
  if fg_idx != self.fg {
    sb.write_string(ansi_fg_256(fg_idx))
    self.fg = fg_idx
  }
  if bg_idx >= 0 && bg_idx != self.bg {
    sb.write_string(ansi_bg_256(bg_idx))
    self.bg = bg_idx
  }
}
