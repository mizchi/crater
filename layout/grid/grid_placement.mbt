// Grid area parsing, named lines, auto-placement and absolute grid areas.

///|
/// Grid area bounds (row_start, row_end, col_start, col_end)
#derive(Debug)
struct GridAreaBounds {
  row_start : Int32
  row_end : Int32
  col_start : Int32
  col_end : Int32
}

///|
pub extend GridAreaBounds with @debug.Debug::{to_repr}

///|
/// Parse grid-template-areas into a 2D array of area names
fn parse_grid_template_areas(
  template_areas : Array[String],
) -> Array[Array[String]] {
  let result : Array[Array[String]] = []
  for i = 0; i < template_areas.length(); i = i + 1 {
    let row_str = template_areas[i]
    let cells : Array[String] = []
    // Split by whitespace
    let mut current = ""
    for c in row_str {
      if c == ' ' || c == '\t' {
        if current.length() > 0 {
          cells.push(current)
          current = ""
        }
      } else {
        current = current + c.to_string()
      }
    }
    if current.length() > 0 {
      cells.push(current)
    }
    result.push(cells)
  }
  result
}

///|
/// Find the bounds of a named grid area
/// Whether a placement edge is explicit (a line number, name, or named line).
fn grid_placement_is_explicit(p : @types.GridPlacement) -> Bool {
  match p {
    @types.GridPlacement::Line(_)
    | @types.GridPlacement::Named(_)
    | @types.GridPlacement::NamedLine(_, _) => true
    _ => false
  }
}

///|
/// An item is explicitly column-positioned if grid-column has an explicit start,
/// or it carries a `grid-area` (which fixes both axes).
fn style_has_explicit_column(style : @style.Style) -> Bool {
  (match style.grid_area {
    Some(_) => true
    None => false
  }) ||
  grid_placement_is_explicit(style.grid_column.start)
}

///|
/// An item is explicitly row-positioned if grid-row has an explicit start, or it
/// carries a `grid-area`.
fn style_has_explicit_row(style : @style.Style) -> Bool {
  (match style.grid_area {
    Some(_) => true
    None => false
  }) ||
  grid_placement_is_explicit(style.grid_row.start)
}

///|
/// Trim leading / trailing ASCII whitespace.
fn trim_grid_ws(s : String) -> String {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let mut start = 0
  let mut end = chars.length()
  while start < end && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  while end > start && (chars[end - 1] == ' ' || chars[end - 1] == '\t') {
    end = end - 1
  }
  let mut r = ""
  for i = start; i < end; i = i + 1 {
    r = r + chars[i].to_string()
  }
  r
}

///|
/// Parse a signed base-10 integer; `None` when the string isn't a bare integer.
fn parse_grid_int(s : String) -> Int32? {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  if chars[0] == '-' {
    neg = true
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut val = 0
  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      val = val * 10 + (c.to_int() - 48)
    } else {
      return None
    }
    i = i + 1
  }
  Some(if neg { -val } else { val })
}

///|
/// Parse one `grid-area` component (`auto`, `<integer>`, or `span <integer>`)
/// into a placement. Returns `None` for names (`foo`) or `span <ident>`, which
/// aren't line-based and should fall back to named-area handling.
fn parse_grid_area_token(raw : String) -> @types.GridPlacement? {
  let t = trim_grid_ws(raw)
  if t == "" || t == "auto" {
    return Some(@types.GridPlacement::Auto)
  }
  let chars : Array[Char] = []
  for c in t {
    chars.push(c)
  }
  if chars.length() >= 4 &&
    chars[0] == 's' &&
    chars[1] == 'p' &&
    chars[2] == 'a' &&
    chars[3] == 'n' {
    let mut rest = ""
    for i = 4; i < chars.length(); i = i + 1 {
      rest = rest + chars[i].to_string()
    }
    match parse_grid_int(trim_grid_ws(rest)) {
      Some(n) => return Some(@types.GridPlacement::Span(n))
      None => return None
    }
  }
  match parse_grid_int(t) {
    Some(n) => Some(@types.GridPlacement::Line(n))
    None => None
  }
}

///|
/// Parse a numeric / line-based `grid-area` shorthand
/// (`<row-start> / <col-start> / <row-end> / <col-end>`) into (column, row)
/// grid lines. Returns `None` when the value isn't line-based (a single token,
/// or any component that is a bare name), so callers keep the named-area path.
fn parse_grid_area_lines(area : String) -> (@types.GridLine, @types.GridLine)? {
  let tokens : Array[String] = []
  let mut current = ""
  for c in area {
    if c == '/' {
      tokens.push(current)
      current = ""
    } else {
      current = current + c.to_string()
    }
  }
  tokens.push(current)
  if tokens.length() < 2 {
    return None
  }
  let placements : Array[@types.GridPlacement] = []
  for t in tokens {
    match parse_grid_area_token(t) {
      Some(p) => placements.push(p)
      None => return None
    }
  }
  let row_start = placements[0]
  let col_start = placements[1]
  let row_end = if placements.length() > 2 {
    placements[2]
  } else {
    @types.GridPlacement::Auto
  }
  let col_end = if placements.length() > 3 {
    placements[3]
  } else {
    @types.GridPlacement::Auto
  }
  Some(
    ({ start: col_start, end: col_end, }, { start: row_start, end: row_end, }),
  )
}

///|
/// Resolve a fully-explicit item's track span (col_start, col_end, row_start,
/// row_end). A `grid-area` first tries the `grid-template-areas` map; then the
/// numeric / line-based shorthand (`3 / 3`, `1 / 1 / auto / span 2`); when the
/// name is neither, it falls back to named-line placement (`grid-area: foo` =>
/// `foo / foo` on both axes, with the implicit `<name>-start` / `<name>-end`
/// area expansion). Otherwise grid-column / grid-row are resolved.
fn resolve_explicit_item_placement(
  style : @style.Style,
  grid_areas : Array[Array[String]],
  columns : Int32,
  explicit_rows : Int32,
  column_line_names : Array[Array[String]],
  row_line_names : Array[Array[String]],
) -> (Int32, Int32, Int32, Int32) {
  match style.grid_area {
    Some(area_name) =>
      match find_grid_area_bounds(grid_areas, area_name) {
        Some(bounds) =>
          (bounds.col_start, bounds.col_end, bounds.row_start, bounds.row_end)
        None =>
          // Not a template area. Try the numeric / line-based `grid-area`
          // shorthand (`3 / 3`); only a bare name falls through to named lines.
          match parse_grid_area_lines(area_name) {
            Some((col_line, row_line)) => {
              let (cs, ce) = resolve_line_placement(
                col_line, 0, columns, column_line_names,
              )
              let (rs, re) = resolve_line_placement(
                row_line, 0, explicit_rows, row_line_names,
              )
              (cs, ce, rs, re)
            }
            None => {
              // Treat the name as a line for all four edges.
              let line : @types.GridLine = {
                start: @types.GridPlacement::Named(area_name),
                end: @types.GridPlacement::Named(area_name),
              }
              let (cs, ce) = resolve_line_placement(
                line, 0, columns, column_line_names,
              )
              let (rs, re) = resolve_line_placement(
                line, 0, explicit_rows, row_line_names,
              )
              (cs, ce, rs, re)
            }
          }
      }
    None => {
      let (cs, ce) = resolve_line_placement(
        style.grid_column,
        0,
        columns,
        column_line_names,
      )
      let (rs, re) = resolve_line_placement(
        style.grid_row,
        0,
        explicit_rows,
        row_line_names,
      )
      (cs, ce, rs, re)
    }
  }
}

///|
fn find_grid_area_bounds(
  areas : Array[Array[String]],
  name : String,
) -> GridAreaBounds? {
  let mut min_row = -1
  let mut max_row = -1
  let mut min_col = -1
  let mut max_col = -1
  for row = 0; row < areas.length(); row = row + 1 {
    let cols = areas[row]
    for col = 0; col < cols.length(); col = col + 1 {
      if cols[col] == name {
        if min_row < 0 || row < min_row {
          min_row = row
        }
        if max_row < 0 || row > max_row {
          max_row = row
        }
        if min_col < 0 || col < min_col {
          min_col = col
        }
        if max_col < 0 || col > max_col {
          max_col = col
        }
      }
    }
  }
  if min_row >= 0 {
    Some({
      row_start: min_row,
      row_end: max_row + 1,
      col_start: min_col,
      col_end: max_col + 1,
    })
  } else {
    None
  }
}

///|
/// Place grid items using 2-pass auto-placement algorithm
/// Pass 1: Identify all explicit Line placements to determine grid bounds
/// Pass 2: Auto-place remaining items starting from the minimum column/row
fn place_grid_items(
  children : Array[@node.Node],
  explicit_columns : Int32,
  explicit_rows : Int32,
  auto_flow : @types.GridAutoFlow,
  grid_areas : Array[Array[String]],
  column_line_names : Array[Array[String]],
  row_line_names : Array[Array[String]],
) -> Array[GridItemPlacement] {
  let columns = if explicit_columns > 0 { explicit_columns } else { 1 }

  // === PASS 1: Find grid bounds from explicit Line placements ===
  let mut min_col = 0
  let mut min_row = 0
  let mut max_col = columns
  let mut max_row = if explicit_rows > 0 { explicit_rows } else { 1 }
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style
    if style.display is @types.Display::None {
      continue
    }
    // Skip absolute positioned items - they don't participate in grid placement
    if style.position is @types.Absolute || style.position is @types.Fixed {
      continue
    }

    // Check for explicit column Line placement
    match style.grid_column.start {
      @types.GridPlacement::Line(n) => {
        let col_idx = if n > 0 {
          n - 1
        } else if n < 0 {
          columns + 1 + n
        } else {
          0
        }
        if col_idx < min_col {
          min_col = col_idx
        }
        let end_idx = col_idx + 1
        if end_idx > max_col {
          max_col = end_idx
        }
      }
      _ => ()
    }

    // Check for explicit row Line placement
    match style.grid_row.start {
      @types.GridPlacement::Line(n) => {
        let row_idx = if n > 0 {
          n - 1
        } else if n < 0 {
          explicit_rows + 1 + n
        } else {
          0
        }
        if row_idx < min_row {
          min_row = row_idx
        }
        let end_idx = row_idx + 1
        if end_idx > max_row {
          max_row = end_idx
        }
      }
      _ => ()
    }
  }

  // === PASS 2: Place explicitly positioned items first ===
  // This ensures we know which cells are occupied before auto-placement
  let placements : Array[GridItemPlacement] = []
  let occupied : Array[(Int32, Int32)] = []

  // Initialize placements array
  for i = 0; i < children.length(); i = i + 1 {
    placements.push({
      row_start: 0,
      row_end: 0,
      column_start: 0,
      column_end: 0,
    })
  }

  // First, place FULLY explicitly positioned items (both column and row are Line)
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style
    if style.display is @types.Display::None {
      continue
    }
    // Skip absolute positioned items
    if style.position is @types.Absolute || style.position is @types.Fixed {
      continue
    }

    // Check if item has explicit Line positioning
    let has_explicit_column = style_has_explicit_column(style)
    let has_explicit_row = style_has_explicit_row(style)

    // Only process FULLY explicitly positioned items (both column AND row)
    // Semi-explicit items (one explicit, one auto) will be processed in Pass 3
    if !(has_explicit_column && has_explicit_row) {
      continue
    }

    // Resolve grid-area (template area or named-line fallback) / grid-line.
    let (col_start, col_end, row_start, row_end) = resolve_explicit_item_placement(
      style, grid_areas, columns, explicit_rows, column_line_names, row_line_names,
    )
    placements[i] = {
      row_start,
      row_end,
      column_start: col_start,
      column_end: col_end,
    }

    // Mark cells as occupied
    for r = row_start; r < row_end; r = r + 1 {
      for c = col_start; c < col_end; c = c + 1 {
        occupied.push((r, c))
      }
    }
  }

  // Helper to check if a cell is occupied
  fn is_cell_occupied(
    occupied : Array[(Int32, Int32)],
    row : Int32,
    col : Int32,
  ) -> Bool {
    for i = 0; i < occupied.length(); i = i + 1 {
      let (r, c) = occupied[i]
      if r == row && c == col {
        return true
      }
    }
    false
  }

  // === PASS 3: Place items with a definite row and auto column ===
  // CSS grid auto-placement locks definite-row items before the general cursor pass.
  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style
    if style.display is @types.Display::None {
      continue
    }
    if style.position is @types.Absolute || style.position is @types.Fixed {
      continue
    }
    let has_explicit_column = style_has_explicit_column(style)
    let has_explicit_row = style_has_explicit_row(style)
    if has_explicit_column || !has_explicit_row {
      continue
    }
    let (rs, re) = resolve_line_placement(
      style.grid_row,
      0,
      explicit_rows,
      row_line_names,
    )
    let mut col_cursor = min_col
    while is_cell_occupied(occupied, rs, col_cursor) {
      col_cursor = col_cursor + 1
    }
    let (cs, ce) = resolve_line_placement(
      style.grid_column,
      col_cursor,
      columns,
      column_line_names,
    )
    placements[i] = {
      row_start: rs,
      row_end: re,
      column_start: cs,
      column_end: ce,
    }
    for r = rs; r < re; r = r + 1 {
      for c = cs; c < ce; c = c + 1 {
        occupied.push((r, c))
      }
    }
  }

  // === PASS 4: Auto-place remaining items ===
  // Auto-placement cursor starts at the minimum index (to fill implicit tracks first)
  let mut next_row = min_row
  let mut next_column = min_col

  for i = 0; i < children.length(); i = i + 1 {
    let child = children[i]
    let style = child.style
    if style.display is @types.Display::None {
      continue
    }
    // Skip absolute positioned items
    if style.position is @types.Absolute || style.position is @types.Fixed {
      continue
    }

    // Skip items already placed in Pass 2/3
    let has_explicit_column = style_has_explicit_column(style)
    let has_explicit_row = style_has_explicit_row(style)
    if has_explicit_row {
      continue
    }

    // Check for grid-area placement
    let area_placement = match style.grid_area {
      Some(area_name) => find_grid_area_bounds(grid_areas, area_name)
      None => None
    }
    let (col_start, col_end, row_start, row_end) = match area_placement {
      Some(bounds) =>
        (bounds.col_start, bounds.col_end, bounds.row_start, bounds.row_end)
      None =>
        // For semi-explicit items, use explicit position for one dimension,
        // cursor for the other
        if has_explicit_row {
          // Explicit row, auto column - find first unoccupied column in that row
          let (rs, re) = resolve_line_placement(
            style.grid_row,
            0,
            explicit_rows,
            row_line_names,
          )
          let row_to_check = rs
          let mut col_cursor = min_col
          while is_cell_occupied(occupied, row_to_check, col_cursor) {
            col_cursor = col_cursor + 1
            // Don't wrap for semi-explicit items, just extend
          }
          let (cs, ce) = resolve_line_placement(
            style.grid_column,
            col_cursor,
            columns,
            column_line_names,
          )
          (cs, ce, rs, re)
        } else if has_explicit_column {
          // Explicit column, auto row - find first unoccupied row in that column
          let (cs, ce) = resolve_line_placement(
            style.grid_column,
            0,
            columns,
            column_line_names,
          )
          let col_to_check = cs
          let mut row_cursor = min_row
          while is_cell_occupied(occupied, row_cursor, col_to_check) {
            row_cursor = row_cursor + 1
            // Don't wrap for semi-explicit items, just extend
          }
          let (rs, re) = resolve_line_placement(
            style.grid_row,
            row_cursor,
            explicit_rows,
            row_line_names,
          )
          (cs, ce, rs, re)
        } else {
          // Fully auto-placed: find next unoccupied cell
          match auto_flow {
            @types.Row | @types.RowDense =>
              // Row-major: advance column, then row
              while is_cell_occupied(occupied, next_row, next_column) {
                next_column = next_column + 1
                if next_column >= columns {
                  next_column = min_col
                  next_row = next_row + 1
                }
              }
            @types.Column | @types.ColumnDense => {
              // Column-major: advance row, then column
              let rows = if explicit_rows > 0 { explicit_rows } else { 1 }
              while is_cell_occupied(occupied, next_row, next_column) {
                next_row = next_row + 1
                if next_row >= rows {
                  next_row = min_row
                  next_column = next_column + 1
                }
              }
            }
          }
          let (cs, ce) = resolve_line_placement(
            style.grid_column,
            next_column,
            columns,
            column_line_names,
          )
          let (rs, re) = resolve_line_placement(
            style.grid_row,
            next_row,
            explicit_rows,
            row_line_names,
          )
          (cs, ce, rs, re)
        }
    }
    placements[i] = {
      row_start,
      row_end,
      column_start: col_start,
      column_end: col_end,
    }

    // Mark cells as occupied
    for r = row_start; r < row_end; r = r + 1 {
      for c = col_start; c < col_end; c = c + 1 {
        occupied.push((r, c))
      }
    }

    // Advance cursor only for fully auto-placed items
    if !has_explicit_column && !has_explicit_row {
      match auto_flow {
        @types.Row | @types.RowDense => {
          next_column = col_end
          if next_column >= columns {
            next_column = min_col
            next_row = next_row + 1
          }
        }
        @types.Column | @types.ColumnDense => {
          next_row = row_end
          let rows = if explicit_rows > 0 { explicit_rows } else { 1 }
          if next_row >= rows {
            next_row = min_row
            next_column = next_column + 1
          }
        }
      }
    }
  }
  placements
}

///|
/// Resolve a grid line placement to start/end indices (0-indexed)
/// Negative indices are allowed - they indicate implicit tracks before the explicit grid
/// The 0-based grid line that is the `s`-th line carrying `name` strictly after
/// line `after`, for `span <s> <name>` resolution. None when there aren't `s`
/// such lines (the caller then falls back to an `s`-track span).
fn nth_named_line_after(
  name : String,
  s : Int32,
  after : Int32,
  line_names : Array[Array[String]],
) -> Int32? {
  if s <= 0 {
    return None
  }
  let mut count = 0
  for j = after + 1; j < line_names.length(); j = j + 1 {
    if line_names[j].contains(name) {
      count = count + 1
      if count == s {
        return Some(j)
      }
    }
  }
  None
}

///|
fn resolve_line_placement(
  line : @types.GridLine,
  auto_position : Int32,
  explicit_count : Int32,
  line_names : Array[Array[String]],
) -> (Int32, Int32) {
  // Resolve named-line placements (e.g. `grid-column: sidebar`) to concrete
  // 1-based line numbers against the template's declared line names (with the
  // `<name>-start` / `<name>-end` implicit-area expansion), then fall through to
  // the normal numeric / span logic.
  let (named_start, named_end) = @computed.resolve_grid_line_placement(
    line.start,
    line.end,
    line_names,
  )
  // `Named` (`sidebar`) and `NamedLine` (`col 2`) both resolve to a concrete
  // 1-based line via @computed; substitute the resolved line number.
  let eff_start : @types.GridPlacement = match (line.start, named_start) {
    (@types.GridPlacement::Named(_), Some(n))
    | (@types.GridPlacement::NamedLine(_, _), Some(n)) =>
      @types.GridPlacement::Line(n)
    _ => line.start
  }
  let eff_end : @types.GridPlacement = match (line.end, named_end) {
    (@types.GridPlacement::Named(_), Some(n))
    | (@types.GridPlacement::NamedLine(_, _), Some(n)) =>
      @types.GridPlacement::Line(n)
    _ => line.end
  }
  let start = match eff_start {
    @types.GridPlacement::Auto => auto_position
    // Unresolved named placements fall back to auto.
    @types.GridPlacement::Named(_) | @types.GridPlacement::NamedLine(_, _) =>
      auto_position
    // `span N name` not resolvable here; approximate as auto start.
    @types.GridPlacement::SpanNamed(_, _) => auto_position
    @types.GridPlacement::Line(n) =>
      if n > 0 {
        n - 1 // Convert 1-indexed to 0-indexed
      } else if n < 0 {
        // Negative indices count from end of explicit grid
        // For N explicit tracks, there are N+1 lines numbered 1 to N+1
        // Line(-1) = Line(N+1), Line(-2) = Line(N), etc.
        // Line number to track index: Line k → track k-1
        // For 1-column grid: Line(-1)=2→track 1, Line(-2)=1→track 0, Line(-3)=0→track -1
        explicit_count + 1 + n // Don't clamp - negative values are valid for implicit tracks
      } else {
        auto_position
      }
    @types.GridPlacement::Span(_) => auto_position
  }
  let end = match eff_end {
    @types.GridPlacement::Auto => start + 1
    @types.GridPlacement::Named(_) | @types.GridPlacement::NamedLine(_, _) =>
      start + 1 // unresolved name
    @types.GridPlacement::Line(n) =>
      if n > 0 {
        n - 1
      } else if n < 0 {
        explicit_count + 1 + n // Don't clamp
      } else {
        start + 1
      }
    @types.GridPlacement::Span(s) => start + s
    // `span N name`: the end is the Nth line carrying `name` after the start
    // line; fall back to an N-track span when there aren't enough named lines.
    @types.GridPlacement::SpanNamed(s, name) =>
      match nth_named_line_after(name, s, start, line_names) {
        Some(j) => j
        None => start + s
      }
  }

  // Handle span in start position
  let (final_start, final_end) = match eff_start {
    @types.GridPlacement::Span(s) =>
      match eff_end {
        @types.GridPlacement::Line(n) => {
          let e = if n > 0 { n - 1 } else { explicit_count + 1 + n }
          (e - s, e)
        }
        _ => (start, start + s)
      }
    _ => (start, end)
  }

  // Ensure end > start, but allow negative start values
  (
    final_start,
    if final_end > final_start {
      final_end
    } else {
      final_start + 1
    },
  )
}

///|
/// Get the bounds (position and size) for a span of tracks
fn get_span_bounds(
  tracks : Array[GridTrack],
  start : Int32,
  end : Int32,
) -> (Double, Double) {
  if tracks.length() == 0 {
    return (0.0, 0.0)
  }
  let track_count = tracks.length()
  let clamped_start = if start < track_count { start } else { track_count - 1 }
  let clamped_end = if end < track_count { end } else { track_count }
  if clamped_start >= track_count || clamped_end <= clamped_start {
    return (0.0, 0.0)
  }
  let start_track = tracks[clamped_start]
  let mut total_size = 0.0
  for i = clamped_start; i < clamped_end && i < track_count; i = i + 1 {
    total_size = total_size + tracks[i].size
  }

  // Add gaps between spanned tracks
  if clamped_end > clamped_start + 1 && clamped_start + 1 < track_count {
    let gap = tracks[clamped_start + 1].position -
      (start_track.position + start_track.size)
    total_size = total_size +
      gap * (clamped_end - clamped_start - 1).to_double()
  }
  (start_track.position, total_size)
}

///|
/// Resolve the horizontal grid area for an absolute item
fn resolve_absolute_grid_area_x(
  grid_column : @types.GridLine,
  column_tracks : Array[GridTrack],
  col_offset : Int32,
  explicit_column_count : Int32,
  default_left : Double,
  default_right : Double,
  content_box_offset : Double, // content_box_left - padding_box_left
) -> (Double, Double) {
  let start_line = resolve_absolute_grid_line(
    grid_column.start,
    col_offset,
    explicit_column_count,
  )
  let end_line = resolve_absolute_grid_line(
    grid_column.end,
    col_offset,
    explicit_column_count,
  )

  // Track positions are relative to content box, so add offset to convert to padding box
  let left = match start_line {
    Some(idx) =>
      if idx >= 0 && idx < column_tracks.length() {
        column_tracks[idx].position + content_box_offset
      } else {
        default_left
      }
    None => default_left
  }
  let right = match end_line {
    Some(idx) =>
      if idx >= 0 && idx < column_tracks.length() {
        column_tracks[idx].position + content_box_offset
      } else if idx == column_tracks.length() {
        // End line after last track
        let last = column_tracks[column_tracks.length() - 1]
        last.position + last.size + content_box_offset
      } else {
        default_right
      }
    None => default_right
  }
  (left, right)
}

///|
/// Resolve the vertical grid area for an absolute item
fn resolve_absolute_grid_area_y(
  grid_row : @types.GridLine,
  row_tracks : Array[GridTrack],
  row_offset : Int32,
  explicit_row_count : Int32,
  default_top : Double,
  default_bottom : Double,
  content_box_offset : Double, // content_box_top - padding_box_top
) -> (Double, Double) {
  let start_line = resolve_absolute_grid_line(
    grid_row.start,
    row_offset,
    explicit_row_count,
  )
  let end_line = resolve_absolute_grid_line(
    grid_row.end,
    row_offset,
    explicit_row_count,
  )

  // Track positions are relative to content box, so add offset to convert to padding box
  let top = match start_line {
    Some(idx) =>
      if idx >= 0 && idx < row_tracks.length() {
        row_tracks[idx].position + content_box_offset
      } else {
        default_top
      }
    None => default_top
  }
  let bottom = match end_line {
    Some(idx) =>
      if idx >= 0 && idx < row_tracks.length() {
        row_tracks[idx].position + content_box_offset
      } else if idx == row_tracks.length() {
        // End line after last track
        let last = row_tracks[row_tracks.length() - 1]
        last.position + last.size + content_box_offset
      } else {
        default_bottom
      }
    None => default_bottom
  }
  (top, bottom)
}

///|
/// Resolve a grid placement to a track index for absolute positioning
/// Returns None if the placement is Auto
fn resolve_absolute_grid_line(
  placement : @types.GridPlacement,
  offset : Int32,
  explicit_count : Int32,
) -> Int32? {
  match placement {
    @types.GridPlacement::Auto => None
    @types.GridPlacement::Line(n) =>
      if n > 0 {
        Some(n - 1 + offset)
      } else if n < 0 {
        Some(explicit_count + 1 + n + offset)
      } else {
        Some(offset)
      }
    @types.GridPlacement::Span(_) => None // Span without explicit end defaults to Auto
    // Named / named-line / named-span placements are not resolved for abspos.
    @types.GridPlacement::Named(_)
    | @types.GridPlacement::NamedLine(_, _)
    | @types.GridPlacement::SpanNamed(_, _) => None
  }
}
