///|
/// Geometry helpers for TUI rendering.

///|
/// Font metrics for coordinate conversion.
let font_width : Double = 8.0

///|
let font_height : Double = 16.0

///|
/// Convert pixel X to character column (truncates for position).
pub fn px_to_col(px : Double) -> Int {
  (px / font_width).to_int()
}

///|
/// Convert pixel width to character width (rounds up to ensure content fits).
fn px_to_col_width(px : Double) -> Int {
  let result = px / font_width
  let int_part = result.to_int()
  if result > int_part.to_double() {
    int_part + 1
  } else {
    int_part
  }
}

///|
/// Convert pixel Y to character row.
pub fn px_to_row(px : Double) -> Int {
  (px / font_height).to_int()
}

///|
/// Convert pixel height to character height (rounds up).
fn px_to_row_height(px : Double) -> Int {
  let result = px / font_height
  let int_part = result.to_int()
  if result > int_part.to_double() {
    int_part + 1
  } else {
    int_part
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Convert dirty rects in pixel coordinates to character grid rectangles.
pub fn dirty_rects_to_cells(
  rects : Array[@types.BoundingRect],
  scroll_y_px : Int,
  viewport_cols : Int,
  viewport_rows : Int,
  row_offset : Int,
) -> Array[DirtyRect] {
  let result : Array[DirtyRect] = []
  let view_left = 0.0
  let view_right = viewport_cols.to_double() * font_width
  let view_top = scroll_y_px.to_double()
  let view_bottom = view_top + viewport_rows.to_double() * font_height
  for rect in rects {
    let x0 = max_double(rect.x, view_left)
    let y0 = max_double(rect.y, view_top)
    let x1 = min_double(rect.x + rect.width, view_right)
    let y1 = min_double(rect.y + rect.height, view_bottom)
    if x1 <= x0 || y1 <= y0 {
      continue
    }
    let col = px_to_col(x0)
    let row = px_to_row(y0 - view_top) + row_offset
    let w = px_to_col_width(x1 - x0)
    let h = px_to_row_height(y1 - y0)
    if w <= 0 || h <= 0 {
      continue
    }
    result.push({ col, row, width: w, height: h })
  }
  result
}
