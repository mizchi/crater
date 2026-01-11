// =============================================================================
// CSS Table Layout Implementation
// =============================================================================
// This implementation supports:
// - Content-based column width distribution
// - Fixed table layout (table-layout: fixed)
// - colspan (cells spanning multiple columns)
// - rowspan (cells spanning multiple rows)
// - border-collapse and border-spacing
// - caption-side (top/bottom)

///|
/// Helper function for max
fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Create a zero-sized layout for a node
fn create_zero_layout(node : @node.Node) -> @node.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@node.Layout] = []
  for child in node.children {
    children.push(create_zero_layout(child))
  }
  {
    id: node.id,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    margin: zero_rect,
    padding: zero_rect,
    border: zero_rect,
    overflow_x: @style.Visible,
    overflow_y: @style.Visible,
    children,
    text: node.text,
  }
}

///|
/// Check if a display type is a table row group (thead, tbody, tfoot)
fn is_table_row_group(display : @style.Display) -> Bool {
  match display {
    @style.TableRowGroup | @style.TableHeaderGroup | @style.TableFooterGroup =>
      true
    _ => false
  }
}

///|
/// Check if a display type is a table row
fn is_table_row(display : @style.Display) -> Bool {
  display == @style.TableRow
}

///|
/// Check if a display type is a table cell
fn is_table_cell(display : @style.Display) -> Bool {
  display == @style.TableCell
}

///|
/// Cell occupancy info - tracks which cell occupies a grid position
priv struct CellOccupancy {
  row_index : Int // Starting row of the cell
  cell_index : Int // Index of cell within the row's children
}

///|
/// Build an occupancy grid for the table
/// Returns: (grid, num_columns) where grid maps (row, col) -> CellOccupancy
fn build_occupancy_grid(rows : Array[@node.Node]) -> (Map[String, CellOccupancy], Int) {
  let grid : Map[String, CellOccupancy] = {}
  let mut num_columns = 0

  for row_idx = 0; row_idx < rows.length(); row_idx = row_idx + 1 {
    let row = rows[row_idx]
    let mut col_idx = 0
    let mut cell_idx = 0

    for child in row.children {
      if child.style.display == @style.None {
        cell_idx = cell_idx + 1
        continue
      }
      if not(is_table_cell(child.style.display)) {
        cell_idx = cell_idx + 1
        continue
      }

      // Skip columns that are already occupied by rowspan from previous rows
      while grid.contains(key_for_pos(row_idx, col_idx)) {
        col_idx = col_idx + 1
      }

      let colspan = if child.style.colspan > 0 { child.style.colspan } else { 1 }
      let rowspan = if child.style.rowspan > 0 { child.style.rowspan } else { 1 }

      // Mark all positions occupied by this cell
      for ri = 0; ri < rowspan; ri = ri + 1 {
        for ci = 0; ci < colspan; ci = ci + 1 {
          let target_row = row_idx + ri
          let target_col = col_idx + ci
          grid[key_for_pos(target_row, target_col)] = {
            row_index: row_idx,
            cell_index: cell_idx,
          }
        }
      }

      // Track max column count
      if col_idx + colspan > num_columns {
        num_columns = col_idx + colspan
      }

      col_idx = col_idx + colspan
      cell_idx = cell_idx + 1
    }
  }

  (grid, num_columns)
}

///|
/// Create a key string for grid position
fn key_for_pos(row : Int, col : Int) -> String {
  row.to_string() + "," + col.to_string()
}

///|
/// Check if a display type is a table column group
fn is_table_column_group(display : @style.Display) -> Bool {
  display == @style.TableColumnGroup
}

///|
/// Check if a display type is a table column
fn is_table_column(display : @style.Display) -> Bool {
  display == @style.TableColumn
}

///|
/// Collect column width specifications from colgroup/col elements
/// Returns an array of optional widths (None if not specified)
fn collect_column_widths(
  table_node : @node.Node,
  parent_width : Double,
) -> Array[Double?] {
  let widths : Array[Double?] = []
  for child in table_node.children {
    if child.style.display == @style.None {
      continue
    }
    if is_table_column_group(child.style.display) {
      // Collect columns from colgroup
      for col in child.children {
        if col.style.display == @style.None {
          continue
        }
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
/// Resolve column width from style
fn resolve_col_width(col : @node.Node, parent_width : Double) -> Double? {
  match col.style.width {
    @types.Length(w) => Some(w)
    @types.Percent(p) => Some(parent_width * p)
    _ => None
  }
}

///|
/// Get the first row in visual order (thead > tbody > tfoot > direct rows)
/// This is used for table-layout: fixed
fn get_first_visual_row(table_node : @node.Node) -> @node.Node? {
  // Priority: thead > direct rows > tbody > tfoot
  // First check for thead
  for child in table_node.children {
    if child.style.display == @style.None {
      continue
    }
    if child.style.display == @style.TableHeaderGroup {
      // Found thead, return first row
      for row in child.children {
        if row.style.display != @style.None && is_table_row(row.style.display) {
          return Some(row)
        }
      }
    }
  }
  // Check for direct rows or tbody
  for child in table_node.children {
    if child.style.display == @style.None {
      continue
    }
    if is_table_row(child.style.display) {
      return Some(child)
    }
    if child.style.display == @style.TableRowGroup {
      for row in child.children {
        if row.style.display != @style.None && is_table_row(row.style.display) {
          return Some(row)
        }
      }
    }
  }
  // Check for tfoot
  for child in table_node.children {
    if child.style.display == @style.None {
      continue
    }
    if child.style.display == @style.TableFooterGroup {
      for row in child.children {
        if row.style.display != @style.None && is_table_row(row.style.display) {
          return Some(row)
        }
      }
    }
  }
  None
}

///|
/// Collect all table rows from table children
/// Handles both direct rows and rows inside row groups (thead, tbody, tfoot)
fn collect_table_rows(table_node : @node.Node) -> Array[@node.Node] {
  let rows : Array[@node.Node] = []
  for child in table_node.children {
    if child.style.display == @style.None {
      continue
    }
    if is_table_row(child.style.display) {
      rows.push(child)
    } else if is_table_row_group(child.style.display) {
      // Collect rows from row group
      for row in child.children {
        if row.style.display != @style.None && is_table_row(row.style.display) {
          rows.push(row)
        }
      }
    }
    // Ignore caption, col, colgroup for now
  }
  rows
}


///|
/// Measure intrinsic width of a cell's content
fn measure_cell_content_width(cell : @node.Node) -> Double {
  let style = cell.style
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let box_extra = padding.horizontal_sum() + border.horizontal_sum()

  // If cell has explicit width, use it
  match style.width {
    @types.Length(w) => return w
    _ => ()
  }

  // Measure children's intrinsic width
  let mut max_child_width = 0.0
  for child in cell.children {
    if child.style.display == @style.None {
      continue
    }
    // Check if child has measure function (text node)
    match child.measure {
      Some(mf) => {
        // Use large available width to get max-content width
        let intrinsic = (mf.func)(10000.0, 10000.0)
        max_child_width = max(max_child_width, intrinsic.max_width)
      }
      None => {
        // Recursively measure child
        let child_width = measure_node_intrinsic_width(child)
        max_child_width = max(max_child_width, child_width)
      }
    }
  }
  max_child_width + box_extra
}

///|
/// Measure intrinsic width of a node recursively
fn measure_node_intrinsic_width(node : @node.Node) -> Double {
  let style = node.style

  // If node has explicit width, use it
  match style.width {
    @types.Length(w) => return w
    _ => ()
  }

  // If node has measure function
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(10000.0, 10000.0)
      return intrinsic.max_width
    }
    None => ()
  }

  // Measure children
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let box_extra = padding.horizontal_sum() + border.horizontal_sum()
  let mut max_width = 0.0
  for child in node.children {
    if child.style.display == @style.None {
      continue
    }
    let child_width = measure_node_intrinsic_width(child)
    max_width = max(max_width, child_width)
  }
  max_width + box_extra
}

///|
/// Get cells from a row as an array
fn get_row_cells(row : @node.Node) -> Array[@node.Node] {
  let cells : Array[@node.Node] = []
  for child in row.children {
    if child.style.display != @style.None && is_table_cell(child.style.display) {
      cells.push(child)
    }
  }
  cells
}

///|
/// Calculate intrinsic (max-content) column widths
/// Returns the minimum width each column needs based on content
fn calculate_intrinsic_column_widths(
  rows : Array[@node.Node],
  num_columns : Int,
  _border_spacing : Double,
) -> Array[Double] {
  let widths : Array[Double] = []
  if num_columns == 0 {
    return widths
  }

  // Initialize column min widths
  for _i = 0; _i < num_columns; _i = _i + 1 {
    widths.push(0.0)
  }

  // Calculate max-content width for each column
  for row in rows {
    let cells = get_row_cells(row)
    for i = 0; i < cells.length() && i < num_columns; i = i + 1 {
      let cell_width = measure_cell_content_width(cells[i])
      if cell_width > widths[i] {
        widths[i] = cell_width
      }
    }
  }
  widths
}

///|
/// Calculate column widths for table-layout: fixed
/// In fixed mode:
/// - Column widths are determined by the first row's cells or <col> elements
/// - Cell content in subsequent rows is ignored
/// - Auto-width columns share remaining space equally
fn calculate_fixed_column_widths(
  first_row : @node.Node?,
  num_columns : Int,
  available_width : Double,
  border_spacing : Double,
  col_widths : Array[Double?],
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
    match explicit_widths[i] {
      Some(w) => widths.push(w)
      None => widths.push(auto_col_width)
    }
  }
  widths
}

///|
/// Calculate column widths based on content and col element specifications
/// Phase 2: Content-based width calculation with col support
fn calculate_column_widths(
  rows : Array[@node.Node],
  num_columns : Int,
  available_width : Double,
  border_spacing : Double,
  col_widths : Array[Double?],
) -> Array[Double] {
  let widths : Array[Double] = []
  if num_columns == 0 {
    return widths
  }

  // Initialize column min widths
  let col_min_widths : Array[Double] = []
  for _i = 0; _i < num_columns; _i = _i + 1 {
    col_min_widths.push(0.0)
  }

  // Calculate max-content width for each column
  for row in rows {
    let cells = get_row_cells(row)
    for i = 0; i < cells.length() && i < num_columns; i = i + 1 {
      let cell_width = measure_cell_content_width(cells[i])
      if cell_width > col_min_widths[i] {
        col_min_widths[i] = cell_width
      }
    }
  }

  // Calculate total spacing
  let total_spacing = border_spacing * (num_columns - 1).to_double()

  // Count columns with explicit widths from col elements and calc remaining width
  let mut fixed_width_total = 0.0
  let mut has_col_widths = false
  for i = 0; i < col_widths.length() && i < num_columns; i = i + 1 {
    match col_widths[i] {
      Some(w) => {
        fixed_width_total = fixed_width_total + w
        has_col_widths = true
      }
      None => ()
    }
  }

  // If we have col widths, use them; otherwise use content-based distribution
  if has_col_widths {
    // Count auto columns
    let mut auto_col_count = 0
    for i = 0; i < num_columns; i = i + 1 {
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

    // Build final widths array
    for i = 0; i < num_columns; i = i + 1 {
      if i < col_widths.length() {
        match col_widths[i] {
          Some(w) => widths.push(w)
          None => widths.push(max(col_min_widths[i], auto_col_width))
        }
      } else {
        widths.push(max(col_min_widths[i], auto_col_width))
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
      let extra_per_col = if num_columns > 0 {
        remaining / num_columns.to_double()
      } else {
        0.0
      }
      for w in col_min_widths {
        widths.push(w + extra_per_col)
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
  widths
}

///|
/// Layout a single table cell
/// border_collapse: whether border-collapse is enabled (borders included in cell dimensions)
fn layout_cell(
  cell : @node.Node,
  cell_width : Double,
  ctx : @node.LayoutContext,
  border_collapse : Bool,
) -> @node.Layout {
  let style = cell.style
  let parent_width = ctx.available_width
  let margin = @types.resolve_rect(style.margin, parent_width)
  let padding = @types.resolve_rect(style.padding, parent_width)
  // In border-collapse mode, borders are included in cell dimensions (like border-box)
  // So we use zero border for layout calculations
  let border : @types.Rect[Double] = if border_collapse {
    @types.Rect::{ left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 }
  } else {
    @types.resolve_rect(style.border, parent_width)
  }

  // Content width = cell width - padding - border
  let content_width = max(
    0.0,
    cell_width - padding.horizontal_sum() - border.horizontal_sum(),
  )

  // Layout children with available width
  let child_ctx : @node.LayoutContext = {
    available_width: content_width,
    available_height: ctx.available_height,
    sizing_mode: ctx.sizing_mode,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }

  // Layout children and calculate content height
  let child_layouts : Array[@node.Layout] = []
  let mut content_height = 0.0
  // Note: In border-collapse mode, border is already 0
  let mut y_offset = padding.top + border.top
  for child in cell.children {
    if child.style.display == @style.None {
      child_layouts.push(create_zero_layout(child))
      continue
    }
    let child_layout = @node.dispatch_layout(child, child_ctx)
    let positioned_layout = {
      ..child_layout,
      x: padding.left + border.left + child_layout.margin.left,
      y: y_offset + child_layout.margin.top,
    }
    y_offset = y_offset +
      child_layout.height +
      child_layout.margin.top +
      child_layout.margin.bottom
    content_height = max(content_height, y_offset)
    child_layouts.push(positioned_layout)
  }

  // Add padding/border to height
  // Note: In border-collapse mode, border is already 0
  let total_height = content_height + padding.bottom + border.bottom

  // Resolve explicit height if set
  // In border-collapse mode, the style.height was adjusted by adjust_for_box_sizing
  // (border added). We need to subtract the border back.
  let style_border = @types.resolve_rect(style.border, parent_width)
  let final_height = match style.height {
    @types.Length(h) => {
      let adjusted_h = if border_collapse {
        h - style_border.vertical_sum()
      } else {
        h
      }
      max(adjusted_h, total_height)
    }
    @types.Percent(p) => {
      let parent_h = ctx.available_height.unwrap_or(0.0)
      max(parent_h * p, total_height)
    }
    _ => total_height
  }
  {
    id: cell.id,
    x: 0.0, // Will be positioned by row layout
    y: 0.0,
    width: cell_width,
    height: final_height,
    margin,
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    children: child_layouts,
    text: cell.text,
  }
}

///|
/// Layout a single table row
/// border_collapse: whether border-collapse is enabled
/// row_index: index of this row for occupancy grid lookup
/// grid: occupancy grid for rowspan tracking
fn layout_row(
  row : @node.Node,
  row_index : Int,
  column_widths : Array[Double],
  border_spacing : Double,
  ctx : @node.LayoutContext,
  border_collapse : Bool,
  grid : Map[String, CellOccupancy],
) -> @node.Layout {
  let style = row.style
  let parent_width = ctx.available_width
  let margin = @types.resolve_rect(style.margin, parent_width)
  let padding = @types.resolve_rect(style.padding, parent_width)
  let border = @types.resolve_rect(style.border, parent_width)

  // Resolve explicit row height from style
  // This is needed BEFORE laying out cells so percentage heights can resolve
  let explicit_row_height = match style.height {
    @types.Length(h) => Some(h)
    @types.Percent(p) => {
      let parent_h = ctx.available_height.unwrap_or(0.0)
      Some(parent_h * p)
    }
    _ => None
  }

  // Create cell context with row height for percentage height resolution
  let cell_ctx : @node.LayoutContext = {
    available_width: ctx.available_width,
    available_height: explicit_row_height,
    sizing_mode: ctx.sizing_mode,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }
  let cell_layouts : Array[@node.Layout] = []
  let mut x_offset = padding.left + border.left
  let mut max_height = 0.0
  let mut col_index = 0
  // Track collapsed border width for border-collapse mode
  let mut collapsed_border_width = 0.0
  let mut first_cell_left_border = 0.0
  let mut last_cell_right_border = 0.0
  let mut cell_idx = 0
  for child in row.children {
    if child.style.display == @style.None {
      cell_layouts.push(create_zero_layout(child))
      cell_idx = cell_idx + 1
      continue
    }
    if not(is_table_cell(child.style.display)) {
      // Skip non-cell children
      cell_layouts.push(create_zero_layout(child))
      cell_idx = cell_idx + 1
      continue
    }

    // Skip columns occupied by rowspan cells from previous rows
    while true {
      match grid.get(key_for_pos(row_index, col_index)) {
        Some(occ) =>
          // If this position's origin is not this cell, skip it
          if occ.row_index != row_index || occ.cell_index != cell_idx {
            // Add spacing for skipped column
            if col_index < column_widths.length() {
              x_offset = x_offset + column_widths[col_index] + border_spacing
            }
            col_index = col_index + 1
          } else {
            break
          }
        None => break
      }
    }

    // Get colspan from style (default 1)
    let colspan = if child.style.colspan > 0 { child.style.colspan } else { 1 }

    // Calculate combined width for all spanned columns
    let mut cell_width = 0.0
    for i = 0; i < colspan; i = i + 1 {
      let idx = col_index + i
      if idx < column_widths.length() {
        cell_width = cell_width + column_widths[idx]
        // Add border_spacing between spanned columns (not after last)
        if i < colspan - 1 {
          cell_width = cell_width + border_spacing
        }
      }
    }
    // In border-collapse mode, the cell's width from the stylesheet was
    // adjusted by adjust_for_box_sizing (border added). We need to subtract
    // the border back since border-collapse cells include border in their dimensions.
    let cell_border = @types.resolve_rect(
      child.style.border,
      ctx.available_width,
    )
    if border_collapse {
      cell_width = cell_width - cell_border.horizontal_sum()
      // Track first cell's left border
      if col_index == 0 {
        first_cell_left_border = cell_border.left
      }
      // Track this cell's right border (will be updated for last cell)
      last_cell_right_border = cell_border.right
      // Add shared border between cells (one per pair)
      if col_index > 0 {
        // Middle border is shared - use max of adjacent borders
        collapsed_border_width = collapsed_border_width + cell_border.left
      }
    }
    let cell_layout = layout_cell(child, cell_width, cell_ctx, border_collapse)
    let positioned_cell = { ..cell_layout, x: x_offset, y: 0.0 }
    max_height = max(max_height, cell_layout.height)
    x_offset = x_offset + cell_width + border_spacing
    // Advance by colspan columns
    col_index = col_index + colspan
    cell_idx = cell_idx + 1
    cell_layouts.push(positioned_cell)
  }

  // Calculate row width
  // Row width should span all columns, even if this row has fewer cells
  // Calculate full row width from all column widths
  let mut full_content_width = 0.0
  for i = 0; i < column_widths.length(); i = i + 1 {
    full_content_width = full_content_width + column_widths[i]
    if i < column_widths.length() - 1 {
      full_content_width = full_content_width + border_spacing
    }
  }
  let row_width = if col_index == 0 {
    // Empty row - use available width from context
    ctx.available_width
  } else if border_collapse {
    // In border-collapse mode:
    // - x_offset tracks actual placed cells with their correct widths
    // - For rows with all cells, use x_offset-based calculation
    // - Add collapsed borders
    let total_border = first_cell_left_border +
      collapsed_border_width +
      last_cell_right_border
    // If row has all columns, use x_offset; otherwise extend to full width
    if col_index >= column_widths.length() {
      x_offset - border_spacing + padding.right + border.right + total_border
    } else {
      // Row has fewer cells - add remaining column widths
      let mut remaining_width = 0.0
      for i = col_index; i < column_widths.length(); i = i + 1 {
        remaining_width = remaining_width + column_widths[i] + border_spacing
      }
      x_offset +
      remaining_width -
      border_spacing +
      padding.right +
      border.right +
      total_border
    }
  } else {
    // Row with cells - use full content width (all columns)
    full_content_width + padding.horizontal_sum() + border.horizontal_sum()
  }

  // Row height is the maximum of:
  // 1. max_height (tallest cell content)
  // 2. explicit_row_height (from row style)
  // 3. ctx.available_height (min height from table distribution)
  let min_height_from_table = ctx.available_height.unwrap_or(0.0)
  let row_content_height = max(
    max_height,
    max(explicit_row_height.unwrap_or(0.0), min_height_from_table),
  )

  // Update cell heights to match row height (for vertical alignment)
  let final_cell_layouts : Array[@node.Layout] = []
  for layout in cell_layouts {
    final_cell_layouts.push({ ..layout, height: row_content_height })
  }
  {
    id: row.id,
    x: 0.0, // Will be positioned by table layout
    y: 0.0,
    width: row_width,
    height: row_content_height + padding.vertical_sum() + border.vertical_sum(),
    margin,
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    children: final_cell_layouts,
    text: row.text,
  }
}

///|
/// Compute intrinsic size of a table (for use by flex layout)
/// parent_is_row: true for width, false for height
pub fn compute_intrinsic_size(
  node : @node.Node,
  parent_is_row : Bool,
) -> Double {
  let style = node.style

  // Handle display:none
  if style.display == @style.None {
    return 0.0
  }
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let border_spacing = style.border_spacing

  // Collect all rows and build occupancy grid
  let rows = collect_table_rows(node)
  let (grid, num_columns) = build_occupancy_grid(rows)
  let _ = grid // Grid not needed for intrinsic size calculation
  if parent_is_row {
    // Compute intrinsic width
    let intrinsic_col_widths = calculate_intrinsic_column_widths(
      rows, num_columns, border_spacing,
    )
    let intrinsic_content_width = if num_columns > 0 {
      let mut total = 0.0
      for w in intrinsic_col_widths {
        total = total + w
      }
      // Total spacing = (num_columns - 1) between + 2 for edges = num_columns + 1
      total + border_spacing * (num_columns + 1).to_double()
    } else {
      0.0
    }
    intrinsic_content_width + padding.horizontal_sum() + border.horizontal_sum()
  } else {
    // Compute intrinsic height
    let mut total_height = 0.0
    for child in node.children {
      if child.style.display == @style.None {
        continue
      }
      if is_table_row(child.style.display) {
        // Direct row
        let row_height = compute_row_intrinsic_height(child)
        total_height = total_height + row_height + border_spacing
      } else if is_table_row_group(child.style.display) {
        // Row group (thead, tbody, tfoot)
        for row in child.children {
          if row.style.display != @style.None && is_table_row(row.style.display) {
            let row_height = compute_row_intrinsic_height(row)
            total_height = total_height + row_height + border_spacing
          }
        }
      }
    }
    // Add top edge spacing
    total_height = total_height + border_spacing
    total_height + padding.vertical_sum() + border.vertical_sum()
  }
}

///|
/// Compute intrinsic height of a table row
fn compute_row_intrinsic_height(row : @node.Node) -> Double {
  let row_style = row.style

  // Check for explicit height
  match row_style.height {
    @types.Length(h) => return h
    _ => ()
  }

  // Find max cell height
  let mut max_height = 0.0
  for child in row.children {
    if child.style.display == @style.None ||
      not(is_table_cell(child.style.display)) {
      continue
    }
    let cell_height = compute_cell_intrinsic_height(child)
    if cell_height > max_height {
      max_height = cell_height
    }
  }
  max_height
}

///|
/// Compute intrinsic height of a table cell
fn compute_cell_intrinsic_height(cell : @node.Node) -> Double {
  let style = cell.style
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let box_extra = padding.vertical_sum() + border.vertical_sum()

  // If cell has explicit height, use it
  match style.height {
    @types.Length(h) => return h + box_extra
    _ => ()
  }

  // Measure children's intrinsic height
  let mut total_height = 0.0
  for child in cell.children {
    if child.style.display == @style.None {
      continue
    }
    // Check if child has measure function (text node)
    match child.measure {
      Some(mf) => {
        let intrinsic = (mf.func)(10000.0, 10000.0)
        total_height = total_height + intrinsic.max_height
      }
      None => {
        let child_height = measure_node_intrinsic_height(child)
        total_height = total_height + child_height
      }
    }
  }
  total_height + box_extra
}

///|
/// Measure intrinsic height of a node recursively
fn measure_node_intrinsic_height(node : @node.Node) -> Double {
  let style = node.style

  // If node has explicit height, use it
  match style.height {
    @types.Length(h) => return h
    _ => ()
  }

  // If node has measure function
  match node.measure {
    Some(mf) => {
      let intrinsic = (mf.func)(10000.0, 10000.0)
      return intrinsic.max_height
    }
    None => ()
  }

  // Measure children
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let box_extra = padding.vertical_sum() + border.vertical_sum()
  let mut total_height = 0.0
  for child in node.children {
    if child.style.display == @style.None {
      continue
    }
    let child_height = measure_node_intrinsic_height(child)
    total_height = total_height + child_height
  }
  total_height + box_extra
}

///|
/// Main table layout computation
pub fn compute(node : @node.Node, ctx : @node.LayoutContext) -> @node.Layout {
  let style = node.style

  // Handle display:none
  if style.display == @style.None {
    return create_zero_layout(node)
  }
  let parent_width = ctx.available_width
  let margin = @types.resolve_rect(style.margin, parent_width)
  let padding = @types.resolve_rect(style.padding, parent_width)
  let border = @types.resolve_rect(style.border, parent_width)

  // Check if border-collapse is enabled
  let is_border_collapse = style.border_collapse == @style.Collapse

  // Border spacing from style (inherited from table element)
  // If border-collapse is collapse, border-spacing is effectively 0
  let border_spacing = if is_border_collapse {
    0.0
  } else {
    style.border_spacing
  }

  // Collect all rows and build occupancy grid
  let rows = collect_table_rows(node)

  // Build occupancy grid to track rowspan/colspan
  let (grid, num_columns) = build_occupancy_grid(rows)

  // Collect column width specifications from col/colgroup elements
  let col_widths = collect_column_widths(node, ctx.available_width)

  // Calculate intrinsic column widths first (for shrink-to-fit)
  let intrinsic_col_widths = calculate_intrinsic_column_widths(
    rows, num_columns, border_spacing,
  )

  // Calculate intrinsic table width (content width based on columns)
  // For table shrink-to-fit, border-spacing is added:
  // - Between columns: (num_columns - 1) gaps
  // - On outer edges: 2 gaps (left and right)
  let intrinsic_content_width = if num_columns > 0 {
    let mut total = 0.0
    for w in intrinsic_col_widths {
      total = total + w
    }
    // Total spacing = (num_columns - 1) between + 2 for edges = num_columns + 1
    total + border_spacing * (num_columns + 1).to_double()
  } else {
    0.0
  }

  // Calculate table width: shrink-to-fit for auto
  let table_width = match style.width {
    @types.Length(w) => w
    @types.Percent(p) => parent_width * p
    _ => {
      // Auto: shrink-to-fit behavior
      // Table width = content width + padding + border
      let min_width = intrinsic_content_width +
        padding.horizontal_sum() +
        border.horizontal_sum()
      // Don't exceed available width
      if min_width > parent_width {
        parent_width
      } else {
        min_width
      }
    }
  }

  // Content width = table width - padding - border
  let content_width = max(
    0.0,
    table_width - padding.horizontal_sum() - border.horizontal_sum(),
  )

  // Row content width excludes edge spacing (only columns + between-column spacing)
  let edge_spacing = border_spacing * 2.0
  let row_content_width = max(0.0, content_width - edge_spacing)

  // Check if using fixed layout
  let is_fixed_layout = style.table_layout == @style.Fixed

  // Calculate column widths with proper distribution
  let column_widths = if is_fixed_layout {
    // Fixed layout: use first row for column widths
    // In visual order, thead comes before tbody
    let first_row = get_first_visual_row(node)
    calculate_fixed_column_widths(
      first_row, num_columns, row_content_width, border_spacing, col_widths,
    )
  } else {
    // Auto layout: use content-based distribution
    calculate_column_widths(
      rows, num_columns, row_content_width, border_spacing, col_widths,
    )
  }

  // Resolve explicit table height from style
  let explicit_table_height : Double? = match style.height {
    @types.Length(h) => Some(h)
    @types.Percent(p) => Some(ctx.available_height.unwrap_or(0.0) * p)
    _ => None
  }

  // Calculate min row height if table has explicit height
  // Distribute table height evenly among rows
  let row_count = rows.length()
  let min_row_height : Double? = match explicit_table_height {
    Some(h) if row_count > 0 => {
      // Available content height = table height - padding - border - all border-spacing
      let available_content_height = h -
        padding.vertical_sum() -
        border.vertical_sum() -
        border_spacing * (row_count + 1).to_double()
      Some(available_content_height / row_count.to_double())
    }
    _ => None
  }

  // Create child context (use row_content_width for row layout)
  // Pass min_row_height so rows can use it as minimum height
  let child_ctx : @node.LayoutContext = {
    available_width: row_content_width,
    available_height: min_row_height,
    sizing_mode: ctx.sizing_mode,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
  }

  // Collect captions and other children separately for caption-side ordering
  // caption-side: top captions go before rows, bottom captions go after
  // Table's caption-side is inherited by captions
  let top_captions : Array[(@node.Node, Int)] = [] // (node, original_index)
  let bottom_captions : Array[(@node.Node, Int)] = []
  let row_children : Array[(@node.Node, Int)] = [] // rows, row groups, cols
  for i = 0; i < node.children.length(); i = i + 1 {
    let child = node.children[i]
    if child.style.display == @style.TableCaption {
      // Use caption's own caption-side, or inherit from table
      let caption_side = child.style.caption_side
      // Note: CSS cascade handles inheritance, so if caption has its own value, use it
      // Otherwise it inherits from table (which is already computed)
      if caption_side == @style.CaptionSide::Bottom {
        bottom_captions.push((child, i))
      } else {
        top_captions.push((child, i))
      }
    } else {
      row_children.push((child, i))
    }
  }

  // Create a map to store layouts by original index
  let layout_map : Map[Int, @node.Layout] = {}

  // Layout all children (including row groups)
  // y_offset includes top edge spacing
  let mut y_offset = padding.top + border.top

  // First: layout top captions
  for entry in top_captions {
    let (child, idx) = entry
    if child.style.display == @style.None {
      layout_map[idx] = create_zero_layout(child)
      continue
    }
    let caption_layout = @node.dispatch_layout(child, child_ctx)
    let positioned_caption = {
      ..caption_layout,
      x: padding.left + border.left,
      y: y_offset,
    }
    y_offset = y_offset + caption_layout.height
    layout_map[idx] = positioned_caption
  }

  // Add border-spacing before rows
  y_offset = y_offset + border_spacing

  // x position for rows includes left edge spacing
  let row_x_offset = padding.left + border.left + border_spacing

  // Track global row index (matching order in collect_table_rows)
  let mut global_row_idx = 0

  // Second: layout rows and row groups
  for entry in row_children {
    let (child, idx) = entry
    if child.style.display == @style.None {
      layout_map[idx] = create_zero_layout(child)
      continue
    }
    if is_table_row(child.style.display) {
      // Direct row
      let row_layout = layout_row(
        child,
        global_row_idx,
        column_widths,
        border_spacing,
        child_ctx,
        is_border_collapse,
        grid,
      )
      let positioned_row = { ..row_layout, x: row_x_offset, y: y_offset }
      y_offset = y_offset + row_layout.height + border_spacing
      layout_map[idx] = positioned_row
      global_row_idx = global_row_idx + 1
    } else if is_table_row_group(child.style.display) {
      // Row group (thead, tbody, tfoot)
      let group_layouts : Array[@node.Layout] = []
      let mut group_y = 0.0
      let mut max_row_width = 0.0
      let group_style = child.style
      let group_margin = @types.resolve_rect(group_style.margin, parent_width)
      let group_padding = @types.resolve_rect(group_style.padding, parent_width)
      let group_border = @types.resolve_rect(group_style.border, parent_width)
      for row in child.children {
        if row.style.display == @style.None {
          group_layouts.push(create_zero_layout(row))
          continue
        }
        if is_table_row(row.style.display) {
          let row_layout = layout_row(
            row,
            global_row_idx,
            column_widths,
            border_spacing,
            child_ctx,
            is_border_collapse,
            grid,
          )
          let positioned_row = {
            ..row_layout,
            x: group_padding.left + group_border.left,
            y: group_y + group_padding.top + group_border.top,
          }
          group_y = group_y + row_layout.height + border_spacing
          // Track max row width for consistent group width
          max_row_width = max(max_row_width, row_layout.width)
          group_layouts.push(positioned_row)
          global_row_idx = global_row_idx + 1
        } else {
          group_layouts.push(create_zero_layout(row))
        }
      }
      // Group height excludes trailing border-spacing
      let group_height = if group_y > 0.0 {
        group_y -
        border_spacing +
        group_padding.vertical_sum() +
        group_border.vertical_sum()
      } else {
        group_padding.vertical_sum() + group_border.vertical_sum()
      }
      // In border-collapse mode, use actual row width; otherwise use row_content_width
      let group_width = if is_border_collapse && max_row_width > 0.0 {
        max_row_width +
        group_padding.horizontal_sum() +
        group_border.horizontal_sum()
      } else {
        row_content_width
      }
      let group_layout : @node.Layout = {
        id: child.id,
        x: row_x_offset,
        y: y_offset,
        width: group_width,
        height: group_height,
        margin: group_margin,
        padding: group_padding,
        border: group_border,
        overflow_x: group_style.overflow_x,
        overflow_y: group_style.overflow_y,
        children: group_layouts,
        text: child.text,
      }
      y_offset = y_offset + group_height + border_spacing
      layout_map[idx] = group_layout
    } else if is_table_column_group(child.style.display) {
      // Colgroup: layout with column widths, positioned later
      // These are placeholder layouts that will be updated after we know table height
      let col_layouts : Array[@node.Layout] = []
      let mut col_x = 0.0
      let mut col_idx = 0
      for col in child.children {
        if col.style.display == @style.None {
          col_layouts.push(create_zero_layout(col))
          continue
        }
        if is_table_column(col.style.display) {
          let col_width = if col_idx < column_widths.length() {
            column_widths[col_idx]
          } else {
            0.0
          }
          let zero_rect : @types.Rect[Double] = {
            left: 0.0,
            right: 0.0,
            top: 0.0,
            bottom: 0.0,
          }
          let col_layout : @node.Layout = {
            id: col.id,
            x: col_x,
            y: 0.0,
            width: col_width,
            height: 0.0, // Will be updated
            margin: zero_rect,
            padding: zero_rect,
            border: zero_rect,
            overflow_x: @style.Visible,
            overflow_y: @style.Visible,
            children: [],
            text: col.text,
          }
          col_x = col_x + col_width + border_spacing
          col_idx = col_idx + 1
          col_layouts.push(col_layout)
        } else {
          col_layouts.push(create_zero_layout(col))
        }
      }
      // Calculate colgroup total width
      let colgroup_width = if col_x > 0.0 {
        col_x - border_spacing
      } else {
        0.0
      }
      let zero_rect : @types.Rect[Double] = {
        left: 0.0,
        right: 0.0,
        top: 0.0,
        bottom: 0.0,
      }
      let colgroup_layout : @node.Layout = {
        id: child.id,
        x: row_x_offset,
        y: y_offset,
        width: colgroup_width,
        height: 0.0, // Will be updated after layout
        margin: zero_rect,
        padding: zero_rect,
        border: zero_rect,
        overflow_x: @style.Visible,
        overflow_y: @style.Visible,
        children: col_layouts,
        text: child.text,
      }
      layout_map[idx] = colgroup_layout
    } else if is_table_column(child.style.display) {
      // Standalone col element (outside colgroup)
      layout_map[idx] = create_zero_layout(child)
    } else {
      // Other children: create zero layout
      layout_map[idx] = create_zero_layout(child)
    }
  }

  // Third: layout bottom captions
  for entry in bottom_captions {
    let (child, idx) = entry
    if child.style.display == @style.None {
      layout_map[idx] = create_zero_layout(child)
      continue
    }
    let caption_layout = @node.dispatch_layout(child, child_ctx)
    let positioned_caption = {
      ..caption_layout,
      x: padding.left + border.left,
      y: y_offset,
    }
    y_offset = y_offset + caption_layout.height
    layout_map[idx] = positioned_caption
  }

  // Calculate table height
  let content_height = y_offset - padding.top - border.top
  let table_height = match style.height {
    @types.Length(h) =>
      max(h, content_height + padding.vertical_sum() + border.vertical_sum())
    @types.Percent(p) => {
      let parent_h = ctx.available_height.unwrap_or(0.0)
      max(
        parent_h * p,
        content_height + padding.vertical_sum() + border.vertical_sum(),
      )
    }
    _ => content_height + padding.vertical_sum() + border.vertical_sum()
  }

  // Calculate row content height for colgroup/col height
  // This is the height of all rows (excluding padding/border)
  let row_content_height = content_height - border_spacing

  // Assemble child_layouts in original order from layout_map
  // Also update colgroup/col heights now that we know the table content height
  let final_child_layouts : Array[@node.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    match layout_map.get(i) {
      Some(layout) => {
        // Check if this is a colgroup by looking at its children which might be cols
        // Colgroups/cols have height=0.0 as placeholder
        if layout.height == 0.0 && layout.children.length() > 0 {
          // This might be a colgroup - update its height and children's heights
          let updated_col_children : Array[@node.Layout] = []
          for col_layout in layout.children {
            if col_layout.height == 0.0 && col_layout.width > 0.0 {
              // This is a col element
              updated_col_children.push({ ..col_layout, height: row_content_height })
            } else {
              updated_col_children.push(col_layout)
            }
          }
          final_child_layouts.push({
            ..layout,
            height: row_content_height,
            children: updated_col_children,
          })
        } else if layout.height == 0.0 && layout.width > 0.0 {
          // Standalone col element
          final_child_layouts.push({ ..layout, height: row_content_height })
        } else {
          final_child_layouts.push(layout)
        }
      }
      None => () // Should not happen
    }
  }
  {
    id: node.id,
    x: margin.left,
    y: margin.top,
    width: table_width,
    height: table_height,
    margin,
    padding,
    border,
    overflow_x: style.overflow_x,
    overflow_y: style.overflow_y,
    children: final_child_layouts,
    text: node.text,
  }
}
