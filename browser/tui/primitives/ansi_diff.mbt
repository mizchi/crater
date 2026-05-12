///|
/// ANSI diff rendering for character buffers.

///|
/// Dirty rectangle for partial diff updates
pub(all) struct DirtyRect {
  col : Int
  row : Int
  width : Int
  height : Int
}

///|
fn DirtyRect::to_plan_rect(self : DirtyRect) -> @tui_buffer.Rect {
  { x: self.col, y: self.row, w: self.width, h: self.height }
}

///|
fn dirty_rects_to_plan_rects(
  rects : Array[DirtyRect],
) -> Array[@tui_buffer.Rect] {
  let planned : Array[@tui_buffer.Rect] = []
  for rect in rects {
    planned.push(rect.to_plan_rect())
  }
  planned
}

///|
/// Optimized ANSI output with diff (only output changed cells)
pub fn buffer_diff_to_ansi(
  current : CharBuffer,
  prev : CharBuffer,
  max_cols? : Int = 0,
) -> String {
  let sb = StringBuilder::new()
  let mut last_row = -1
  let mut last_col = -1
  let style_state = AnsiStyleState::new()
  for
    coord in @tui_buffer.plan_buffer_cells(
      current.width,
      current.height,
      max_cols,
    ) {
    let row = coord.row
    let col = coord.col
    let cell = current.get_cell(col, row)
    let prev_cell = prev.get_cell(col, row)
    // Skip if unchanged
    if cell == prev_cell {
      continue
    }
    // Skip wide char placeholder
    if cell.char == '\u0000' {
      continue
    }
    // Move cursor if not consecutive
    if row != last_row || col != last_col + 1 {
      sb.write_string(ansi_move_to(row + 1, col + 1))
    }
    style_state.write_cell_style(sb, cell)
    sb.write_char(cell.char)
    last_row = row
    last_col = col
  }
  sb.write_string(ansi_reset())
  sb.to_string()
}

///|
/// Optimized ANSI output with diff limited to dirty rectangles
pub fn buffer_diff_to_ansi_rects(
  current : CharBuffer,
  prev : CharBuffer,
  rects : Array[DirtyRect],
  max_cols? : Int = 0,
) -> String {
  if rects.length() == 0 {
    return ""
  }
  let sb = StringBuilder::new()
  let mut last_row = -1
  let mut last_col = -1
  let style_state = AnsiStyleState::new()
  for
    coord in @tui_buffer.plan_dirty_cells(
      current.width,
      current.height,
      dirty_rects_to_plan_rects(rects),
      max_cols,
    ) {
    let row = coord.row
    let col = coord.col
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
    style_state.write_cell_style(sb, cell)
    sb.write_char(cell.char)
    last_row = row
    last_col = col
  }
  sb.write_string(ansi_reset())
  sb.to_string()
}
