// Column collection and intrinsic, fixed and automatic table column sizing.

///|
/// Check if a display type is a table column group
fn is_table_column_group(display : @types.Display) -> Bool {
  display == @types.TableColumnGroup
}

///|
/// Check if a display type is a table column
fn is_table_column(display : @types.Display) -> Bool {
  display == @types.TableColumn
}

///|
/// Collect column width specifications from colgroup/col elements
/// Returns an array of optional widths (None if not specified)
fn collect_column_widths(
  table_node : @node.Node,
  parent_width : Double,
) -> Array[Double?] {
  let widths : Array[Double?] = []
  for child in collect_table_effective_children(table_node) {
    if is_table_column_group(child.style.display) {
      // Collect columns from colgroup
      for col in collect_table_effective_children(child) {
        if is_table_column(col.style.display) {
          let col_width = resolve_col_width(col, parent_width)
          widths.push(col_width)
        }
      }
    } else if is_table_column(child.style.display) {
      // Direct col element (outside colgroup)
      let col_width = resolve_col_width(child, parent_width)
      widths.push(col_width)
    }
  }
  widths
}

///|
/// Collect collapsed-column flags from colgroup/col definitions.
/// Indexes match collect_column_widths() order.
fn collect_collapsed_columns(table_node : @node.Node) -> Array[Bool] {
  let collapsed_columns : Array[Bool] = []
  for child in collect_table_effective_children(table_node) {
    if is_table_column_group(child.style.display) {
      let group_collapsed = child.style.visibility == @style.Collapse
      for col in collect_table_effective_children(child) {
        if is_table_column(col.style.display) {
          let is_collapsed = group_collapsed ||
            col.style.visibility == @style.Collapse
          collapsed_columns.push(is_collapsed)
        }
      }
    } else if is_table_column(child.style.display) {
      collapsed_columns.push(child.style.visibility == @style.Collapse)
    }
  }
  collapsed_columns
}

///|
fn is_collapsed_column(
  collapsed_columns : Array[Bool],
  col_idx : Int32,
) -> Bool {
  col_idx < collapsed_columns.length() && collapsed_columns[col_idx]
}

///|
/// Resolve column width from style
fn resolve_col_width(col : @node.Node, parent_width : Double) -> Double? {
  match col.style.width {
    @types.Length(w) => Some(w)
    @types.Percent(p) => Some(parent_width * p)
    @types.Calc(px, pct) => Some(parent_width * pct + px)
    @types.MathFn(__mop, __mterms) =>
      Some(
        @types.apply_math_op(
          __mop,
          __mterms.map(fn(__t) { parent_width * __t.1 + __t.0 }),
        ),
      )
    _ => None
  }
}

///|
fn column_start_x(
  column_widths : Array[Double],
  col_idx : Int32,
  border_spacing : Double,
) -> Double {
  let mut x = 0.0
  for i = 0; i < col_idx; i = i + 1 {
    if i < column_widths.length() {
      x = x + column_widths[i]
    }
    x = x + border_spacing
  }
  x
}

///|
/// Calculate intrinsic (max-content) column widths
/// Returns the minimum width each column needs based on content
fn calculate_intrinsic_column_widths(
  rows : Array[@node.Node],
  num_columns : Int32,
  border_spacing : Double,
  grid : Map[String, CellOccupancy],
  collapsed_columns : Array[Bool],
  border_collapse~ : Bool = false,
) -> Array[Double] {
  let widths : Array[Double] = []
  if num_columns == 0 {
    return widths
  }

  // Initialize column min widths
  for _i = 0; _i < num_columns; _i = _i + 1 {
    widths.push(0.0)
  }

  // Calculate max-content width constraints for each column.
  // For colspan cells, distribute any missing span width across spanned columns.
  for row_idx = 0; row_idx < rows.length(); row_idx = row_idx + 1 {
    let row = rows[row_idx]
    let cells = get_row_cells(row)
    let mut col_index = 0
    for cell_idx = 0; cell_idx < cells.length(); cell_idx = cell_idx + 1 {
      let cell = cells[cell_idx]

      // Skip columns occupied by previous-row rowspan cells.
      while true {
        match grid.get(key_for_pos(row_idx, col_index)) {
          Some(occ) =>
            if occ.row_index != row_idx || occ.cell_index != cell_idx {
              col_index = col_index + 1
            } else {
              break
            }
          None => break
        }
      }

      if col_index >= num_columns {
        break
      }

      let raw_colspan = if cell.style.colspan > 0 {
        cell.style.colspan
      } else {
        1
      }
      let remaining_cols = num_columns - col_index
      let span = if raw_colspan < remaining_cols {
        raw_colspan
      } else {
        remaining_cols
      }
      if span <= 0 {
        col_index = col_index + raw_colspan
        continue
      }

      let mut span_has_collapsed_column = false
      let active_columns : Array[Int32] = []
      for i = 0; i < span; i = i + 1 {
        let idx = col_index + i
        if is_collapsed_column(collapsed_columns, idx) {
          span_has_collapsed_column = true
        } else {
          active_columns.push(idx)
        }
      }
      // Width contributions from cells spanning collapsed columns are clipped.
      if span_has_collapsed_column || active_columns.length() == 0 {
        col_index = col_index + raw_colspan
        continue
      }

      // Anonymous single-column cells synthesized from stray inline content
      // (e.g. when a parser-edge attaches a previous row's inline anchors to
      // an otherwise-empty spacer <tr>) must not inflate a real column's
      // intrinsic width — their content is layout noise, not the column's
      // max-content. Skip their contribution to column widths.
      if @node.str_has_prefix(cell.id, "__anon-table-cell-") && span == 1 {
        col_index = col_index + raw_colspan
        continue
      }
      let cell_width = measure_cell_content_width(cell, border_collapse~)
      let mut current_span_width = 0.0
      for i = 0; i < active_columns.length(); i = i + 1 {
        let idx = active_columns[i]
        current_span_width = current_span_width + widths[idx]
        if i < active_columns.length() - 1 {
          current_span_width = current_span_width + border_spacing
        }
      }
      if cell_width > current_span_width {
        let extra_per_col = (cell_width - current_span_width) /
          active_columns.length().to_double()
        for idx in active_columns {
          widths[idx] = widths[idx] + extra_per_col
        }
      }
      col_index = col_index + raw_colspan
    }
  }
  for i = 0; i < num_columns; i = i + 1 {
    if is_collapsed_column(collapsed_columns, i) {
      widths[i] = 0.0
    }
  }
  widths
}

///|
fn calculate_intrinsic_column_percentages(
  rows : Array[@node.Node],
  num_columns : Int32,
  grid : Map[String, CellOccupancy],
  collapsed_columns : Array[Bool],
) -> Array[Double] {
  let percentages : Array[Double] = []
  if num_columns == 0 {
    return percentages
  }
  for _i = 0; _i < num_columns; _i = _i + 1 {
    percentages.push(0.0)
  }
  for row_idx = 0; row_idx < rows.length(); row_idx = row_idx + 1 {
    let row = rows[row_idx]
    let cells = get_row_cells(row)
    let mut col_index = 0
    for cell_idx = 0; cell_idx < cells.length(); cell_idx = cell_idx + 1 {
      let cell = cells[cell_idx]

      while true {
        match grid.get(key_for_pos(row_idx, col_index)) {
          Some(occ) =>
            if occ.row_index != row_idx || occ.cell_index != cell_idx {
              col_index = col_index + 1
            } else {
              break
            }
          None => break
        }
      }

      if col_index >= num_columns {
        break
      }

      let raw_colspan = if cell.style.colspan > 0 {
        cell.style.colspan
      } else {
        1
      }
      if raw_colspan == 1 && !is_collapsed_column(collapsed_columns, col_index) {
        match cell.style.width {
          @types.Percent(p) =>
            if p > percentages[col_index] {
              percentages[col_index] = p
            }
          _ => ()
        }
      }

      col_index = col_index + raw_colspan
    }
  }
  percentages
}

///|
/// Calculate column widths for table-layout: fixed
/// In fixed mode:
/// - Column widths are determined by the first row's cells or <col> elements
/// - Cell content in subsequent rows is ignored
/// - Auto-width columns share remaining space equally
fn calculate_fixed_column_widths(
  first_row : @node.Node?,
  num_columns : Int32,
  available_width : Double,
  border_spacing : Double,
  col_widths : Array[Double?],
  collapsed_columns : Array[Bool],
) -> Array[Double] {
  let widths : Array[Double] = []
  if num_columns == 0 {
    return widths
  }

  // Calculate total spacing
  let total_spacing = border_spacing * (num_columns - 1).to_double()
  let content_available = max(0.0, available_width - total_spacing)

  // Collect explicit widths from first row cells and col elements
  // Priority: col element width > first row cell width > auto
  let explicit_widths : Array[Double?] = []
  for i = 0; i < num_columns; i = i + 1 {
    if is_collapsed_column(collapsed_columns, i) {
      explicit_widths.push(Some(0.0))
      continue
    }
    // First check col element width
    if i < col_widths.length() {
      match col_widths[i] {
        Some(w) => {
          explicit_widths.push(Some(w))
          continue
        }
        None => ()
      }
    }
    // Then check first row cell width
    match first_row {
      Some(row) => {
        let cells = get_row_cells(row)
        if i < cells.length() {
          let cell_style = cells[i].style
          match cell_style.width {
            @types.Length(w) => {
              explicit_widths.push(Some(w))
              continue
            }
            @types.Percent(p) => {
              explicit_widths.push(Some(available_width * p))
              continue
            }
            @types.Calc(px, pct) => {
              explicit_widths.push(Some(available_width * pct + px))
              continue
            }
            @types.MathFn(__mop, __mterms) => {
              let px = @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) { __t.0 }),
              )
              let pct = @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) { __t.1 }),
              )
              explicit_widths.push(Some(available_width * pct + px))
              continue
            }
            _ => ()
          }
        }
      }
      None => ()
    }
    explicit_widths.push(None)
  }

  // Calculate fixed width total and count auto columns
  let mut fixed_width_total = 0.0
  let mut auto_col_count = 0
  for i = 0; i < num_columns; i = i + 1 {
    match explicit_widths[i] {
      Some(w) => fixed_width_total = fixed_width_total + w
      None => auto_col_count = auto_col_count + 1
    }
  }

  // Distribute remaining width equally among auto columns
  let auto_available = max(0.0, content_available - fixed_width_total)
  let auto_col_width = if auto_col_count > 0 {
    auto_available / auto_col_count.to_double()
  } else {
    0.0
  }

  // Build final widths array
  for i = 0; i < num_columns; i = i + 1 {
    if is_collapsed_column(collapsed_columns, i) {
      widths.push(0.0)
    } else {
      match explicit_widths[i] {
        Some(w) => widths.push(w)
        None => widths.push(auto_col_width)
      }
    }
  }
  widths
}

///|
/// Minimum content width of a fixed-layout table per CSS 2.1 §17.5.2.1: the used
/// table width is the greater of the specified `width` and the sum of the
/// columns' widths (from `<col>` or the first row) plus the inter-column and edge
/// cell spacing, so a fixed table grows to fit columns wider than its own
/// `width`. Cell widths are already stored border-box (content + padding +
/// border), matching the column widths used by `calculate_fixed_column_widths`.
/// Percentage column widths resolve against the table width itself and so are
/// excluded here (they cannot force the table to grow beyond its own width);
/// auto columns contribute nothing to the minimum.
fn fixed_layout_natural_content_width(
  first_row : @node.Node?,
  num_columns : Int32,
  border_spacing : Double,
  col_widths : Array[Double?],
  collapsed_columns : Array[Bool],
) -> Double {
  if num_columns == 0 {
    return 0.0
  }
  let cells = match first_row {
    Some(row) => get_row_cells(row)
    None => []
  }
  let mut total = 0.0
  for i = 0; i < num_columns; i = i + 1 {
    if is_collapsed_column(collapsed_columns, i) {
      continue
    }
    // Column width: <col> width takes priority, then the first row's cell width.
    let col_explicit = if i < col_widths.length() {
      col_widths[i]
    } else {
      None
    }
    let width = match col_explicit {
      Some(w) => Some(w)
      None =>
        if i < cells.length() {
          match cells[i].style.width {
            @types.Length(w) => Some(w)
            @types.Calc(px, _) => Some(px)
            @types.MathFn(__mop, __mterms) => {
              let px = @types.apply_math_op(
                __mop,
                __mterms.map(fn(__t) { __t.0 }),
              )
              Some(px)
            }
            _ => None
          }
        } else {
          None
        }
    }
    match width {
      Some(w) => total = total + w
      None => ()
    }
  }
  total + border_spacing * (num_columns + 1).to_double()
}

///|
/// Calculate column widths based on content and col element specifications
/// Phase 2: Content-based width calculation with col support
fn calculate_column_widths(
  rows : Array[@node.Node],
  num_columns : Int32,
  available_width : Double,
  border_spacing : Double,
  col_widths : Array[Double?],
  grid : Map[String, CellOccupancy],
  collapsed_columns : Array[Bool],
  border_collapse~ : Bool = false,
) -> Array[Double] {
  let widths : Array[Double] = []
  if num_columns == 0 {
    return widths
  }

  // Use the same colspan/rowspan-aware intrinsic contribution model.
  let col_min_widths = calculate_intrinsic_column_widths(
    rows,
    num_columns,
    border_spacing,
    grid,
    collapsed_columns,
    border_collapse~,
  )
  let col_percentages = calculate_intrinsic_column_percentages(
    rows, num_columns, grid, collapsed_columns,
  )

  // Calculate total spacing
  let total_spacing = border_spacing * (num_columns - 1).to_double()

  // Count columns with explicit widths from col elements and calc remaining width
  let mut fixed_width_total = 0.0
  let mut has_explicit_col_widths = false
  for i = 0; i < col_widths.length() && i < num_columns; i = i + 1 {
    match col_widths[i] {
      Some(w) => {
        fixed_width_total = fixed_width_total + w
        has_explicit_col_widths = true
      }
      None => ()
    }
  }
  let mut has_collapsed_columns = false
  for i = 0; i < num_columns; i = i + 1 {
    if is_collapsed_column(collapsed_columns, i) {
      has_collapsed_columns = true
      break
    }
  }
  let has_col_widths = has_explicit_col_widths || has_collapsed_columns

  // If we have col widths, use them; otherwise use content-based distribution
  if has_col_widths {
    // Count auto columns
    let mut auto_col_count = 0
    for i = 0; i < num_columns; i = i + 1 {
      if is_collapsed_column(collapsed_columns, i) {
        continue
      }
      if i >= col_widths.length() {
        auto_col_count = auto_col_count + 1
      } else {
        match col_widths[i] {
          Some(_) => ()
          None => auto_col_count = auto_col_count + 1
        }
      }
    }

    // Available width for auto columns
    let auto_available = max(
      0.0,
      available_width - total_spacing - fixed_width_total,
    )
    let auto_col_width = if auto_col_count > 0 {
      auto_available / auto_col_count.to_double()
    } else {
      0.0
    }
    let should_fill_auto_columns = has_explicit_col_widths

    // Build final widths array
    for i = 0; i < num_columns; i = i + 1 {
      if is_collapsed_column(collapsed_columns, i) {
        widths.push(0.0)
      } else if i < col_widths.length() {
        match col_widths[i] {
          Some(w) => widths.push(w)
          None =>
            if should_fill_auto_columns {
              widths.push(max(col_min_widths[i], auto_col_width))
            } else {
              widths.push(col_min_widths[i])
            }
        }
      } else if should_fill_auto_columns {
        widths.push(max(col_min_widths[i], auto_col_width))
      } else {
        widths.push(col_min_widths[i])
      }
    }
  } else {
    // No col widths - use content-based distribution
    // Calculate total min width
    let mut total_min_width = total_spacing
    for w in col_min_widths {
      total_min_width = total_min_width + w
    }

    // Available content width
    let content_available = max(0.0, available_width - total_spacing)
    if total_min_width <= available_width {
      // All columns fit - use min widths and distribute remaining space
      let remaining = content_available - (total_min_width - total_spacing)
      let mut total_percentage = 0.0
      for i = 0; i < num_columns; i = i + 1 {
        if is_collapsed_column(collapsed_columns, i) {
          continue
        }
        total_percentage = total_percentage + col_percentages[i]
      }
      if remaining > 0.0 && total_percentage > 0.0 {
        let mut distributed = 0.0
        let mut last_percent_col = -1
        for i = 0; i < num_columns; i = i + 1 {
          if !is_collapsed_column(collapsed_columns, i) &&
            col_percentages[i] > 0.0 {
            last_percent_col = i
          }
        }
        for i = 0; i < num_columns; i = i + 1 {
          let base_width = col_min_widths[i]
          if i == last_percent_col {
            widths.push(base_width + (remaining - distributed))
          } else if col_percentages[i] > 0.0 {
            let extra = remaining * (col_percentages[i] / total_percentage)
            widths.push(base_width + extra)
            distributed = distributed + extra
          } else {
            widths.push(base_width)
          }
        }
      } else {
        // Distribute remaining width to the widest column(s).
        // Small columns (rank, vote) keep their min-width,
        // large columns (title, content) absorb the remaining space.
        // This matches browser behavior where text-heavy columns expand.
        let mut max_min_w = 0.0
        let mut max_count = 0
        for i = 0; i < num_columns; i = i + 1 {
          if is_collapsed_column(collapsed_columns, i) {
            continue
          }
          if col_min_widths[i] > max_min_w {
            max_min_w = col_min_widths[i]
            max_count = 1
          } else if col_min_widths[i] == max_min_w {
            max_count += 1
          }
        }
        if remaining > 0.0 && max_count > 0 {
          let extra_per_wide = remaining / max_count.to_double()
          for i = 0; i < num_columns; i = i + 1 {
            let w = col_min_widths[i]
            if w == max_min_w {
              widths.push(w + extra_per_wide)
            } else {
              widths.push(w)
            }
          }
        } else {
          for w in col_min_widths {
            widths.push(w)
          }
        }
      }
    } else {
      // Columns don't fit - scale proportionally
      let scale = if total_min_width - total_spacing > 0.0 {
        content_available / (total_min_width - total_spacing)
      } else {
        1.0
      }
      for w in col_min_widths {
        widths.push(w * scale)
      }
    }
  }
  for i = 0; i < num_columns; i = i + 1 {
    if is_collapsed_column(collapsed_columns, i) {
      widths[i] = 0.0
    }
  }
  widths
}
