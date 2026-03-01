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
fn create_zero_layout(node : @node.Node) -> @types.Layout {
  let zero_rect : @types.Rect[Double] = {
    left: 0.0,
    right: 0.0,
    top: 0.0,
    bottom: 0.0,
  }
  let children : Array[@types.Layout] = []
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
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: node.text,
  }
}

///|
/// Calculate position offset for position: relative elements
/// Returns (x_offset, y_offset) based on inset properties
fn calculate_relative_offset(
  style : @style.Style,
  container_width : Double,
  container_height : Double,
) -> (Double, Double) {
  // Only apply offset for position: relative
  if style.position != @types.Relative {
    return (0.0, 0.0)
  }
  @core.resolve_relative_inset_offsets(
    style.inset,
    container_width,
    Some(container_height),
  )
}

///|
/// Check if a display type is a table row group (thead, tbody, tfoot)
fn is_table_row_group(display : @types.Display) -> Bool {
  match display {
    @types.TableRowGroup | @types.TableHeaderGroup | @types.TableFooterGroup =>
      true
    _ => false
  }
}

///|
/// Check if a display type is a table row
fn is_table_row(display : @types.Display) -> Bool {
  display == @types.TableRow
}

///|
/// Check if a display type is a table cell
fn is_table_cell(display : @types.Display) -> Bool {
  display == @types.TableCell
}

///|
/// Cell occupancy info - tracks which cell occupies a grid position
priv struct CellOccupancy {
  row_index : Int // Starting row of the cell
  cell_index : Int // Index of cell within the row's children
}

///|
/// Rowspan cell info - tracks cells that span multiple rows for height distribution
priv struct RowspanCellInfo {
  start_row : Int // Starting row index
  rowspan : Int // Number of rows spanned
  cell_height : Double // Content height of the cell
}

///|
/// A row-level flow item used to reorder table header/footer groups visually.
priv struct TableRowFlowItem {
  indices : Array[Int]
  base_y : Double
  advance : Double
  bucket : Int // 0: header, 1: body, 2: footer
}

///|
/// A table child flattened through display:contents wrappers.
priv struct FlattenedContentsChild {
  child : @node.Node
  wrappers : Array[@node.Node]
}

///|
/// Entry for table child processing and mapping back to original index.
priv struct TableChildEntry {
  child : @node.Node
  index : Int
  wrappers : Array[@node.Node]
}

///|
/// Clone wrapper path with one additional display:contents wrapper.
fn push_table_wrapper_path(
  wrappers : Array[@node.Node],
  wrapper : @node.Node,
) -> Array[@node.Node] {
  let next : Array[@node.Node] = []
  for existing in wrappers {
    next.push(existing)
  }
  next.push(wrapper)
  next
}

///|
/// Flatten to the first non-display:none descendant through display:contents.
fn flatten_first_non_none_contents_child(
  node : @node.Node,
  wrappers : Array[@node.Node],
) -> FlattenedContentsChild? {
  if node.style.display == @types.Display::None {
    return None
  }
  if node.style.display != @types.Contents {
    if is_ignorable_table_text_node(node) {
      return None
    }
    return Some({ child: node, wrappers })
  }
  let next_wrappers = push_table_wrapper_path(wrappers, node)
  for child in node.children {
    match flatten_first_non_none_contents_child(child, next_wrappers) {
      Some(flattened) => return Some(flattened)
      None => ()
    }
  }
  None
}

///|
/// Append children with display:contents descendants flattened in place.
fn append_table_effective_children(
  node : @node.Node,
  out : Array[@node.Node],
) -> Unit {
  if node.style.display == @types.Display::None {
    return ()
  }
  if node.style.display == @types.Contents {
    for child in node.children {
      append_table_effective_children(child, out)
    }
    return ()
  }
  out.push(node)
}

///|
/// Flatten one container level for table model processing.
fn collect_table_effective_children(node : @node.Node) -> Array[@node.Node] {
  let children : Array[@node.Node] = []
  for child in node.children {
    append_table_effective_children(child, children)
  }
  children
}

///|
fn is_table_whitespace_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn is_whitespace_only_table_text(text : String) -> Bool {
  for c in text.iter() {
    if not(is_table_whitespace_char(c)) {
      return false
    }
  }
  true
}

///|
fn zero_layout_rect() -> @types.Rect[Double] {
  { left: 0.0, right: 0.0, top: 0.0, bottom: 0.0 }
}

///|
/// Wrap a computed layout with display:contents wrapper nodes.
fn wrap_layout_with_contents_wrappers(
  child_layout : @types.Layout,
  wrappers : Array[@node.Node],
) -> @types.Layout {
  let mut wrapped = child_layout
  for i = wrappers.length(); i > 0; i = i - 1 {
    let wrapper = wrappers[i - 1]
    let children : Array[@types.Layout] = []
    children.push(wrapped)
    wrapped = {
      id: wrapper.id,
      x: 0.0,
      y: 0.0,
      width: 0.0,
      height: 0.0,
      margin: zero_layout_rect(),
      padding: zero_layout_rect(),
      border: zero_layout_rect(),
      overflow_x: wrapper.style.overflow_x,
      overflow_y: wrapper.style.overflow_y,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children,
      text: wrapper.text,
    }
  }
  wrapped
}

///|
/// Build an occupancy grid for the table
/// Returns: (grid, num_columns) where grid maps (row, col) -> CellOccupancy
fn build_occupancy_grid(
  rows : Array[@node.Node],
) -> (Map[String, CellOccupancy], Int) {
  let grid : Map[String, CellOccupancy] = {}
  let mut num_columns = 0
  for row_idx = 0; row_idx < rows.length(); row_idx = row_idx + 1 {
    let row = rows[row_idx]
    let mut col_idx = 0
    let row_cells = get_row_cells(row)
    for cell_idx = 0; cell_idx < row_cells.length(); cell_idx = cell_idx + 1 {
      let child = row_cells[cell_idx]

      // Skip columns that are already occupied by rowspan from previous rows
      while grid.contains(key_for_pos(row_idx, col_idx)) {
        col_idx = col_idx + 1
      }
      let colspan = if child.style.colspan > 0 {
        child.style.colspan
      } else {
        1
      }
      let rowspan = if child.style.rowspan > 0 {
        child.style.rowspan
      } else {
        1
      }

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
/// Resolve column width from style
fn resolve_col_width(col : @node.Node, parent_width : Double) -> Double? {
  match col.style.width {
    @types.Length(w) => Some(w)
    @types.Percent(p) => Some(parent_width * p)
    _ => None
  }
}

///|
fn column_start_x(
  column_widths : Array[Double],
  col_idx : Int,
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
/// Get the first row in visual order (thead > tbody > tfoot > direct rows)
/// This is used for table-layout: fixed
fn get_first_visual_row(table_node : @node.Node) -> @node.Node? {
  let effective_children = collect_table_effective_children(table_node)
  // Priority: thead > direct rows > tbody > tfoot
  // First check for thead
  for child in effective_children {
    if child.style.display == @types.TableHeaderGroup {
      // Found thead, return first row
      let rows = normalize_row_group_rows(child)
      if rows.length() > 0 {
        return Some(rows[0])
      }
    }
  }
  // Check for direct rows or tbody
  for child in effective_children {
    if is_table_row(child.style.display) {
      return Some(child)
    }
    if child.style.display == @types.TableRowGroup {
      let rows = normalize_row_group_rows(child)
      if rows.length() > 0 {
        return Some(rows[0])
      }
    }
  }
  // Check for tfoot
  for child in effective_children {
    if child.style.display == @types.TableFooterGroup {
      let rows = normalize_row_group_rows(child)
      if rows.length() > 0 {
        return Some(rows[0])
      }
    }
  }
  None
}

///|
/// Table row model ignores direct whitespace text children.
fn is_ignorable_table_text_node(node : @node.Node) -> Bool {
  if not(node.id.has_prefix("#text")) {
    return false
  }
  match node.text {
    Some(text) => is_whitespace_only_table_text(text)
    None => true
  }
}

///|
/// Collect all table rows from table children
/// Handles both direct rows and rows inside row groups (thead, tbody, tfoot)
fn collect_table_rows(table_node : @node.Node) -> Array[@node.Node] {
  let rows : Array[@node.Node] = []
  let mut pending_cells : Array[@node.Node] = []
  let mut anon_row_index = 0
  fn flush_pending_cells() -> Unit {
    if pending_cells.length() == 0 {
      return ()
    }
    let anon_row_style : @style.Style = {
      ..@style.Style::default(),
      display: @types.TableRow,
    }
    rows.push(
      @node.Node::new(
        "__anon-table-row-" + anon_row_index.to_string(),
        anon_row_style,
        pending_cells,
      ),
    )
    pending_cells = []
    anon_row_index = anon_row_index + 1
  }
  for child in collect_table_effective_children(table_node) {
    if is_ignorable_table_text_node(child) {
      continue
    }
    if is_table_row(child.style.display) {
      flush_pending_cells()
      rows.push(child)
    } else if is_table_cell(child.style.display) {
      // Anonymous table row wrapper for direct table-cell children.
      pending_cells.push(child)
    } else if is_table_row_group(child.style.display) {
      flush_pending_cells()
      // Collect rows from row group, synthesizing anonymous rows for
      // non-row children per table model rules.
      for row in normalize_row_group_rows(child) {
        rows.push(row)
      }
    }
    // Ignore caption, col, colgroup for now
  }
  flush_pending_cells()
  rows
}

///|
/// Normalize row-group children into table rows.
/// Non-row children are wrapped into anonymous row/cell structures.
fn normalize_row_group_rows(row_group : @node.Node) -> Array[@node.Node] {
  let rows : Array[@node.Node] = []
  let mut pending_non_rows : Array[@node.Node] = []
  let mut anon_row_index = 0
  fn flush_pending_non_rows() -> Unit {
    if pending_non_rows.length() == 0 {
      return ()
    }
    let anon_row_style : @style.Style = {
      ..@style.Style::default(),
      display: @types.TableRow,
    }
    rows.push(
      @node.Node::new(
        "__anon-table-rowgrp-row-" + anon_row_index.to_string(),
        anon_row_style,
        pending_non_rows,
      ),
    )
    pending_non_rows = []
    anon_row_index = anon_row_index + 1
  }
  for child in row_group.children {
    if is_ignorable_table_text_node(child) {
      continue
    }
    if is_table_row(child.style.display) {
      flush_pending_non_rows()
      rows.push(child)
    } else {
      pending_non_rows.push(child)
    }
  }
  flush_pending_non_rows()
  rows
}

///|
fn is_inline_intrinsic_child(node : @node.Node) -> Bool {
  if node.id == "br" || node.id.has_prefix("#text") {
    return true
  }
  if node.style.display == @types.Contents {
    let mut has_in_flow_child = false
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      match child.style.float {
        @types.Float::Left | @types.Float::Right => return false
        @types.Float::None => ()
      }
      has_in_flow_child = true
      if not(is_inline_intrinsic_child(child)) {
        return false
      }
    }
    return has_in_flow_child
  }
  match node.style.display {
    @types.Inline
    | @types.InlineBlock
    | @types.InlineFlex
    | @types.InlineGrid => true
    _ => false
  }
}

///|
/// In vertical writing mode, physical width is block axis and WPT expects
/// table max-width intrinsic keywords to behave like an initial constraint.
fn ignore_intrinsic_max_width_constraint(style : @style.Style) -> Bool {
  style.writing_mode.is_vertical()
}

///|
fn has_vertical_inline_flow_children(children : Array[@node.Node]) -> Bool {
  let mut has_in_flow_child = false
  for child in children {
    if not(is_in_flow_intrinsic_child(child)) {
      continue
    }
    has_in_flow_child = true
    if not(is_inline_intrinsic_child(child)) {
      return false
    }
  }
  has_in_flow_child
}

///|
fn is_in_flow_intrinsic_child(child : @node.Node) -> Bool {
  if child.style.display == @types.Display::None {
    return false
  }
  if child.style.position == @types.Absolute ||
    child.style.position == @types.Fixed {
    return false
  }
  match child.style.float {
    @types.Float::Left | @types.Float::Right => false
    @types.Float::None => true
  }
}

///|
/// Measure intrinsic width of a cell's content
fn measure_cell_content_width(cell : @node.Node) -> Double {
  let style = cell.style
  let box_extra = if style.display == @types.Contents {
    0.0
  } else {
    let padding = @types.resolve_rect_intrinsic(style.padding)
    let border = @types.resolve_rect_intrinsic(style.border)
    padding.horizontal_sum() + border.horizontal_sum()
  }

  let explicit_width = match style.width {
    @types.Length(w) => Some(w)
    _ => None
  }

  fn child_intrinsic_width(child : @node.Node) -> Double {
    match child.measure {
      Some(mf) => {
        let intrinsic = (mf.func)(10000.0, 10000.0)
        intrinsic.max_width
      }
      None => measure_node_intrinsic_width(child)
    }
  }

  let mut has_inline_flow = false
  let mut inline_only = true
  for child in cell.children {
    if not(is_in_flow_intrinsic_child(child)) {
      continue
    }
    has_inline_flow = true
    if not(is_inline_intrinsic_child(child)) {
      inline_only = false
      break
    }
  }

  let mut max_child_width = 0.0
  if inline_only && has_inline_flow {
    let mut current_line_width = 0.0
    for child in cell.children {
      if not(is_in_flow_intrinsic_child(child)) {
        continue
      }
      if child.id == "br" {
        if current_line_width > max_child_width {
          max_child_width = current_line_width
        }
        current_line_width = 0.0
      } else {
        current_line_width = current_line_width + child_intrinsic_width(child)
      }
    }
    if current_line_width > max_child_width {
      max_child_width = current_line_width
    }
  } else {
    // Non-inline content: use max child contribution as before.
    for child in cell.children {
      if not(is_in_flow_intrinsic_child(child)) {
        continue
      }
      let child_width = child_intrinsic_width(child)
      max_child_width = max(max_child_width, child_width)
    }
  }
  let mut intrinsic_width = match explicit_width {
    Some(w) => w
    None => max_child_width + box_extra
  }
  // Table-cell intrinsic contribution should respect explicit min/max bounds.
  match style.max_width {
    @types.Length(max_w) =>
      if intrinsic_width > max_w {
        intrinsic_width = max_w
      }
    _ => ()
  }
  match style.min_width {
    @types.Length(min_w) =>
      if intrinsic_width < min_w {
        intrinsic_width = min_w
      }
    _ => ()
  }
  if intrinsic_width < box_extra {
    box_extra
  } else {
    intrinsic_width
  }
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
  let box_extra = if style.display == @types.Contents {
    0.0
  } else {
    let padding = @types.resolve_rect_intrinsic(style.padding)
    let border = @types.resolve_rect_intrinsic(style.border)
    padding.horizontal_sum() + border.horizontal_sum()
  }
  if style.writing_mode.is_vertical() &&
    has_vertical_inline_flow_children(node.children) {
    let mut total_columns_width = 0.0
    let mut current_column_width = 0.0
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      let child_width = measure_node_intrinsic_width(child)
      if child.id == "br" {
        total_columns_width = total_columns_width +
          max(current_column_width, child_width)
        current_column_width = 0.0
      } else {
        current_column_width = max(current_column_width, child_width)
      }
    }
    return total_columns_width + current_column_width + box_extra
  }
  let mut has_horizontal_inline_flow = false
  let mut is_horizontal_inline_only = true
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    has_horizontal_inline_flow = true
    if not(is_inline_intrinsic_child(child)) {
      is_horizontal_inline_only = false
      break
    }
  }
  if is_horizontal_inline_only && has_horizontal_inline_flow {
    let mut max_line_width = 0.0
    let mut current_line_width = 0.0
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      if child.id == "br" {
        if current_line_width > max_line_width {
          max_line_width = current_line_width
        }
        current_line_width = 0.0
      } else {
        current_line_width = current_line_width +
          measure_node_intrinsic_width(child)
      }
    }
    if current_line_width > max_line_width {
      max_line_width = current_line_width
    }
    return max_line_width + box_extra
  }
  let mut max_width = 0.0
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    let child_width = measure_node_intrinsic_width(child)
    max_width = max(max_width, child_width)
  }
  max_width + box_extra
}

///|
/// Normalize row children into table cells.
/// Non-cell children are wrapped into anonymous table-cell boxes.
fn normalize_row_cells(row : @node.Node) -> Array[@node.Node] {
  let cells : Array[@node.Node] = []
  let mut pending_non_cells : Array[@node.Node] = []
  let mut anon_cell_index = 0
  fn flush_pending_non_cells() -> Unit {
    if pending_non_cells.length() == 0 {
      return ()
    }
    let anon_cell_style : @style.Style = {
      ..@style.Style::default(),
      display: @types.TableCell,
    }
    cells.push(
      @node.Node::new(
        "__anon-table-cell-" + anon_cell_index.to_string(),
        anon_cell_style,
        pending_non_cells,
      ),
    )
    pending_non_cells = []
    anon_cell_index = anon_cell_index + 1
  }
  for child in row.children {
    if is_ignorable_table_text_node(child) {
      continue
    }
    if is_table_cell(child.style.display) {
      flush_pending_non_cells()
      cells.push(child)
    } else if child.style.display == @types.Contents {
      match flatten_first_non_none_contents_child(child, []) {
        Some(flattened) =>
          if is_table_cell(flattened.child.style.display) {
            // Keep display:contents wrapper in the output tree, but treat each
            // wrapped table-cell branch as its own anonymous cell boundary.
            flush_pending_non_cells()
            pending_non_cells.push(child)
            flush_pending_non_cells()
          } else {
            pending_non_cells.push(child)
          }
        None => pending_non_cells.push(child)
      }
    } else {
      pending_non_cells.push(child)
    }
  }
  flush_pending_non_cells()
  cells
}

///|
/// Get cells from a row as an array
fn get_row_cells(row : @node.Node) -> Array[@node.Node] {
  normalize_row_cells(row)
}

///|
/// Calculate intrinsic (max-content) column widths
/// Returns the minimum width each column needs based on content
fn calculate_intrinsic_column_widths(
  rows : Array[@node.Node],
  num_columns : Int,
  border_spacing : Double,
  grid : Map[String, CellOccupancy],
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

      let cell_width = measure_cell_content_width(cell)
      let mut current_span_width = 0.0
      for i = 0; i < span; i = i + 1 {
        current_span_width = current_span_width + widths[col_index + i]
        if i < span - 1 {
          current_span_width = current_span_width + border_spacing
        }
      }

      if cell_width > current_span_width {
        let extra_per_col = (cell_width - current_span_width) / span.to_double()
        for i = 0; i < span; i = i + 1 {
          let idx = col_index + i
          widths[idx] = widths[idx] + extra_per_col
        }
      }

      col_index = col_index + raw_colspan
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
  grid : Map[String, CellOccupancy],
) -> Array[Double] {
  let widths : Array[Double] = []
  if num_columns == 0 {
    return widths
  }

  // Use the same colspan/rowspan-aware intrinsic contribution model.
  let col_min_widths = calculate_intrinsic_column_widths(
    rows, num_columns, border_spacing, grid,
  )

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
  ctx : @types.LayoutContext,
  border_collapse : Bool,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
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

  // Resolve a definite content-box height for percentage descendants in the
  // anonymous cell content wrapper.
  let style_border = @types.resolve_rect(style.border, parent_width)
  let resolved_cell_border_box_height : Double? = match style.height {
    @types.Length(h) =>
      Some(if border_collapse { h - style_border.vertical_sum() } else { h })
    @types.Percent(p) =>
      match ctx.available_height {
        Some(parent_h) => Some(parent_h * p)
        None => None
      }
    _ => ctx.available_height
  }
  let content_height_for_percent : Double? = match
    resolved_cell_border_box_height {
    Some(h) =>
      Some(max(0.0, h - padding.vertical_sum() - border.vertical_sum()))
    None => None
  }

  // Layout children with available width
  let child_ctx : @types.LayoutContext = {
    available_width: content_width,
    available_height: content_height_for_percent,
    sizing_mode: ctx.sizing_mode,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }

  // Layout cell contents through an anonymous block to preserve inline flow.
  let zero_dim_rect : @types.Rect[@types.Dimension] = @types.Rect::new(
    @types.Length(0.0),
    @types.Length(0.0),
    @types.Length(0.0),
    @types.Length(0.0),
  )
  let anon_content_style : @style.Style = {
    ..style,
    display: @types.Block,
    width: @types.Auto,
    height: match content_height_for_percent {
      Some(h) => @types.Length(h)
      None => @types.Auto
    },
    margin: zero_dim_rect,
    padding: zero_dim_rect,
    border: zero_dim_rect,
    float: @types.Float::None,
    position: @types.Static,
  }
  let anon_content = @node.Node::new(
    "__anon-table-cell-content",
    anon_content_style,
    cell.children,
  )
  let @node.DispatchFn(dispatch_fn) = dispatch
  let content_layout = dispatch_fn(anon_content, child_ctx, dispatch)
  let child_layouts : Array[@types.Layout] = []
  for child_layout in content_layout.children {
    let centered_x = if style.writing_mode.is_vertical() {
      let free_space = content_width - child_layout.width
      if free_space > 0.0 {
        child_layout.x + free_space / 2.0
      } else {
        child_layout.x
      }
    } else {
      child_layout.x
    }
    child_layouts.push({
      ..child_layout,
      x: centered_x + padding.left + border.left,
      y: child_layout.y + padding.top + border.top,
    })
  }

  // Add padding/border to height.
  // Note: In border-collapse mode, border is already 0.
  let total_height = content_layout.height +
    padding.vertical_sum() +
    border.vertical_sum()

  // Resolve explicit height if set
  // In border-collapse mode, the style.height was adjusted by adjust_for_box_sizing
  // (border added). We need to subtract the border back.
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
  let normalized_child_layouts : Array[@types.Layout] = []
  for child_layout in child_layouts {
    let normalized_y = if child_layout.y < border.top &&
      child_layout.height >= final_height - 0.5 {
      border.top
    } else {
      child_layout.y
    }
    normalized_child_layouts.push({ ..child_layout, y: normalized_y })
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
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: normalized_child_layouts,
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
  ctx : @types.LayoutContext,
  border_collapse : Bool,
  grid : Map[String, CellOccupancy],
  dispatch : @node.DispatchFn,
) -> @types.Layout {
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
    _ => ctx.available_height
  }

  // Create cell context with row height for percentage height resolution
  let cell_ctx : @types.LayoutContext = {
    available_width: ctx.available_width,
    available_height: explicit_row_height,
    sizing_mode: ctx.sizing_mode,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  let cell_layouts : Array[@types.Layout] = []
  let mut x_offset = padding.left + border.left
  let mut max_height = 0.0
  let mut col_index = 0
  // Track collapsed border width for border-collapse mode
  let mut collapsed_border_width = 0.0
  let mut first_cell_left_border = 0.0
  let mut last_cell_right_border = 0.0
  let row_cells = get_row_cells(row)
  for cell_idx = 0; cell_idx < row_cells.length(); cell_idx = cell_idx + 1 {
    let child = row_cells[cell_idx]

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
    let cell_layout = layout_cell(
      child, cell_width, cell_ctx, border_collapse, dispatch,
    )
    // Apply position: relative offset for cells
    let (rel_x, rel_y) = calculate_relative_offset(
      child.style,
      cell_width,
      cell_layout.height,
    )
    let positioned_cell = { ..cell_layout, x: x_offset + rel_x, y: rel_y }
    // Only count rowspan=1 cells towards max_height
    // Rowspan cells have their height distributed separately
    let rowspan = if child.style.rowspan > 0 { child.style.rowspan } else { 1 }
    if rowspan == 1 {
      max_height = max(max_height, cell_layout.height)
    }
    x_offset = x_offset + cell_width + border_spacing
    // Advance by colspan columns
    col_index = col_index + colspan
    // Keep anonymous cells until row height normalization is done.
    // Flattening too early makes descendants inherit row height incorrectly.
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
  let final_cell_layouts : Array[@types.Layout] = []
  for layout in cell_layouts {
    final_cell_layouts.push({ ..layout, height: row_content_height })
  }
  let row_children : Array[@types.Layout] = []
  for layout in final_cell_layouts {
    if layout.id.has_prefix("__anon-table-cell-") {
      for anon_child in layout.children {
        row_children.push({
          ..anon_child,
          x: layout.x + anon_child.x,
          y: layout.y + anon_child.y,
        })
      }
    } else {
      row_children.push(layout)
    }
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
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: row_children,
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
  if style.display == @types.Display::None {
    return 0.0
  }
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let border_spacing = style.border_spacing

  // Collect all rows and build occupancy grid
  let rows = collect_table_rows(node)
  let (grid, num_columns) = build_occupancy_grid(rows)
  if parent_is_row {
    // Compute intrinsic width
    let intrinsic_col_widths = calculate_intrinsic_column_widths(
      rows, num_columns, border_spacing, grid,
    )
    let intrinsic_content_width = if num_columns > 0 {
      let mut total = 0.0
      for w in intrinsic_col_widths {
        total = total + w
      }
      // Total spacing = (num_columns - 1) between + 2 for edges = num_columns + 1
      total + border_spacing * (num_columns + 1).to_double()
    } else {
      // Anonymous table flow content contributes to intrinsic width when no
      // explicit table rows/cells exist.
      let mut anon_flow_intrinsic_width = 0.0
      let mut float_total_width = 0.0
      for child in node.children {
        if child.style.display == @types.Display::None {
          continue
        }
        if is_table_row(child.style.display) ||
          is_table_row_group(child.style.display) ||
          is_table_column(child.style.display) ||
          is_table_column_group(child.style.display) ||
          child.style.display == @types.TableCaption ||
          is_table_cell(child.style.display) {
          continue
        }
        let child_width = measure_node_intrinsic_width(child)
        match child.style.float {
          @types.Float::Left | @types.Float::Right =>
            float_total_width = float_total_width + child_width
          @types.Float::None =>
            if child_width > anon_flow_intrinsic_width {
              anon_flow_intrinsic_width = child_width
            }
        }
      }
      if float_total_width > anon_flow_intrinsic_width {
        anon_flow_intrinsic_width = float_total_width
      }
      anon_flow_intrinsic_width
    }
    intrinsic_content_width + padding.horizontal_sum() + border.horizontal_sum()
  } else {
    // Compute intrinsic height
    let mut caption_intrinsic_height = 0.0
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      if child.style.display == @types.TableCaption {
        caption_intrinsic_height = caption_intrinsic_height +
          measure_node_intrinsic_height(child)
      }
    }

    let mut row_intrinsic_height = 0.0
    if rows.length() > 0 {
      // Row area includes edge spacing and between-row spacing.
      row_intrinsic_height = border_spacing
      for row in rows {
        row_intrinsic_height = row_intrinsic_height +
          compute_row_intrinsic_height(row) +
          border_spacing
      }
    }

    let mut anon_flow_intrinsic_height = 0.0
    if rows.length() == 0 {
      let mut float_max_height = 0.0
      for child in node.children {
        if child.style.display == @types.Display::None {
          continue
        }
        if is_table_row(child.style.display) ||
          is_table_row_group(child.style.display) ||
          is_table_column(child.style.display) ||
          is_table_column_group(child.style.display) ||
          child.style.display == @types.TableCaption ||
          is_table_cell(child.style.display) {
          continue
        }
        let child_height = measure_node_intrinsic_height(child)
        match child.style.float {
          @types.Float::Left | @types.Float::Right =>
            if child_height > float_max_height {
              float_max_height = child_height
            }
          @types.Float::None =>
            anon_flow_intrinsic_height = anon_flow_intrinsic_height +
              child_height
        }
      }
      if float_max_height > anon_flow_intrinsic_height {
        anon_flow_intrinsic_height = float_max_height
      }
    }

    caption_intrinsic_height +
    row_intrinsic_height +
    anon_flow_intrinsic_height +
    padding.vertical_sum() +
    border.vertical_sum()
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
  for child in get_row_cells(row) {
    let cell_height = compute_cell_intrinsic_height(child)
    if cell_height > max_height {
      max_height = cell_height
    }
  }
  max_height
}

///|
/// Compute base row heights (excluding cells with rowspan > 1)
/// Returns: Array of base heights for each row
fn compute_base_row_heights(
  rows : Array[@node.Node],
  grid : Map[String, CellOccupancy],
  border_collapse : Bool,
) -> Array[Double] {
  let heights : Array[Double] = []
  for row_idx = 0; row_idx < rows.length(); row_idx = row_idx + 1 {
    let row = rows[row_idx]
    let row_style = row.style

    // Check for explicit row height
    let mut max_height = match row_style.height {
      @types.Length(h) => h
      _ => 0.0
    }

    // Find max cell height among cells that DON'T have rowspan > 1
    for child in get_row_cells(row) {
      let rowspan = if child.style.rowspan > 0 {
        child.style.rowspan
      } else {
        1
      }

      // Only consider cells that don't span multiple rows
      if rowspan == 1 {
        let cell_height = compute_cell_height_for_row(child, border_collapse)
        if cell_height > max_height {
          max_height = cell_height
        }
      }
    }
    heights.push(max_height)
  }
  let _ = grid // Grid not needed for base calculation but kept for consistency
  heights
}

///|
/// Compute cell height for row height calculation
/// In border-collapse mode, subtracts border from explicit heights
fn compute_cell_height_for_row(
  cell : @node.Node,
  border_collapse : Bool,
) -> Double {
  let style = cell.style
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let box_extra = padding.vertical_sum() + border.vertical_sum()
  let explicit_height = match style.height {
    @types.Length(h) =>
      // In border-collapse mode, explicit height includes border, so subtract it.
      Some(if border_collapse { h - border.vertical_sum() } else { h })
    _ => None
  }
  fn child_intrinsic_height(child : @node.Node) -> Double {
    match (child.style.height, explicit_height) {
      (@types.Percent(p), Some(cell_h)) if p > 0.0 => {
        let child_padding = @types.resolve_rect_intrinsic(child.style.padding)
        let child_border = @types.resolve_rect_intrinsic(child.style.border)
        if child.style.box_sizing == @types.BorderBox {
          return @types.max(0.0, cell_h * p)
        }
        return @types.max(
          0.0,
          cell_h * p +
          child_padding.vertical_sum() +
          child_border.vertical_sum(),
        )
      }
      _ => ()
    }
    match child.measure {
      Some(mf) => {
        let intrinsic = (mf.func)(10000.0, 10000.0)
        intrinsic.max_height
      }
      None => measure_node_intrinsic_height(child)
    }
  }

  let mut has_inline_flow = false
  let mut inline_only = true
  for child in cell.children {
    if not(is_in_flow_intrinsic_child(child)) {
      continue
    }
    has_inline_flow = true
    if not(is_inline_intrinsic_child(child)) {
      inline_only = false
      break
    }
  }

  let mut total_height = 0.0
  if inline_only && has_inline_flow {
    let mut current_line_height = 0.0
    for child in cell.children {
      if not(is_in_flow_intrinsic_child(child)) {
        continue
      }
      if child.id == "br" {
        total_height = total_height + current_line_height
        current_line_height = 0.0
      } else {
        let child_height = child_intrinsic_height(child)
        if child_height > current_line_height {
          current_line_height = child_height
        }
      }
    }
    total_height = total_height + current_line_height
  } else {
    for child in cell.children {
      if not(is_in_flow_intrinsic_child(child)) {
        continue
      }
      total_height = total_height + child_intrinsic_height(child)
    }
  }
  let content_intrinsic_height = total_height + box_extra
  match explicit_height {
    Some(h) =>
      if h > content_intrinsic_height {
        h
      } else {
        content_intrinsic_height
      }
    None => content_intrinsic_height
  }
}

///|
/// Collect all rowspan cells with their info
/// Returns: Array of RowspanCellInfo
fn collect_rowspan_cells(rows : Array[@node.Node]) -> Array[RowspanCellInfo] {
  let cells : Array[RowspanCellInfo] = []
  for row_idx = 0; row_idx < rows.length(); row_idx = row_idx + 1 {
    let row = rows[row_idx]
    for child in get_row_cells(row) {
      let rowspan = if child.style.rowspan > 0 {
        child.style.rowspan
      } else {
        1
      }
      if rowspan > 1 {
        let cell_height = compute_cell_intrinsic_height(child)
        cells.push({ start_row: row_idx, rowspan, cell_height })
      }
    }
  }
  cells
}

///|
/// Distribute rowspan cell heights across spanned rows
/// Modifies heights array in place
fn distribute_rowspan_heights(
  heights : Array[Double],
  rowspan_cells : Array[RowspanCellInfo],
  border_spacing : Double,
) -> Unit {
  for cell_info in rowspan_cells {
    let start = cell_info.start_row
    let span = cell_info.rowspan
    let end = start + span

    // Clamp end to array bounds
    let actual_end = if end > heights.length() { heights.length() } else { end }
    let actual_span = actual_end - start
    if actual_span <= 0 {
      continue
    }

    // Calculate current total height of spanned rows (including border-spacing between)
    let mut current_total = 0.0
    for i = start; i < actual_end; i = i + 1 {
      current_total = current_total + heights[i]
      if i < actual_end - 1 {
        current_total = current_total + border_spacing
      }
    }

    // If cell needs more height, distribute extra evenly
    if cell_info.cell_height > current_total {
      let extra = cell_info.cell_height - current_total
      let extra_per_row = extra / actual_span.to_double()
      for i = start; i < actual_end; i = i + 1 {
        heights[i] = heights[i] + extra_per_row
      }
    }
  }
}

///|
/// Compute intrinsic height of a table cell
/// Note: For explicit heights, we return just h because adjust_for_box_sizing
/// has already converted content-box dimensions to include border.
fn compute_cell_intrinsic_height(cell : @node.Node) -> Double {
  let style = cell.style
  let padding = @types.resolve_rect_intrinsic(style.padding)
  let border = @types.resolve_rect_intrinsic(style.border)
  let box_extra = padding.vertical_sum() + border.vertical_sum()
  let explicit_height = match style.height {
    @types.Length(h) => Some(h)
    _ => None
  }

  fn child_intrinsic_height(child : @node.Node) -> Double {
    match (child.style.height, explicit_height) {
      (@types.Percent(p), Some(cell_h)) if p > 0.0 => {
        let child_padding = @types.resolve_rect_intrinsic(child.style.padding)
        let child_border = @types.resolve_rect_intrinsic(child.style.border)
        if child.style.box_sizing == @types.BorderBox {
          return @types.max(0.0, cell_h * p)
        }
        return @types.max(
          0.0,
          cell_h * p +
          child_padding.vertical_sum() +
          child_border.vertical_sum(),
        )
      }
      _ => ()
    }
    match child.measure {
      Some(mf) => {
        let intrinsic = (mf.func)(10000.0, 10000.0)
        intrinsic.max_height
      }
      None => measure_node_intrinsic_height(child)
    }
  }
  let mut has_inline_flow = false
  let mut inline_only = true
  for child in cell.children {
    if not(is_in_flow_intrinsic_child(child)) {
      continue
    }
    has_inline_flow = true
    if not(is_inline_intrinsic_child(child)) {
      inline_only = false
      break
    }
  }

  let mut total_height = 0.0
  if inline_only && has_inline_flow {
    let mut current_line_height = 0.0
    for child in cell.children {
      if not(is_in_flow_intrinsic_child(child)) {
        continue
      }
      if child.id == "br" {
        total_height = total_height + current_line_height
        current_line_height = 0.0
      } else {
        let child_height = child_intrinsic_height(child)
        if child_height > current_line_height {
          current_line_height = child_height
        }
      }
    }
    total_height = total_height + current_line_height
  } else {
    for child in cell.children {
      if not(is_in_flow_intrinsic_child(child)) {
        continue
      }
      total_height = total_height + child_intrinsic_height(child)
    }
  }
  let content_intrinsic_height = total_height + box_extra
  match explicit_height {
    Some(h) =>
      if h > content_intrinsic_height {
        h
      } else {
        content_intrinsic_height
      }
    None => content_intrinsic_height
  }
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
  if style.writing_mode.is_vertical() &&
    has_vertical_inline_flow_children(node.children) {
    let mut max_column_height = 0.0
    let mut current_column_height = 0.0
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      let child_height = measure_node_intrinsic_height(child)
      if child.id == "br" {
        max_column_height = max(max_column_height, current_column_height)
        current_column_height = 0.0
      } else {
        current_column_height = current_column_height + child_height
      }
    }
    return max(max_column_height, current_column_height) + box_extra
  }
  let mut has_horizontal_inline_flow = false
  let mut inline_only = true
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    has_horizontal_inline_flow = true
    if not(is_inline_intrinsic_child(child)) {
      inline_only = false
      break
    }
  }
  if inline_only && has_horizontal_inline_flow {
    let mut total_lines_height = 0.0
    let mut current_line_height = 0.0
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      if child.id == "br" {
        total_lines_height = total_lines_height + current_line_height
        current_line_height = 0.0
      } else {
        let child_height = measure_node_intrinsic_height(child)
        if child_height > current_line_height {
          current_line_height = child_height
        }
      }
    }
    total_lines_height = total_lines_height + current_line_height
    return total_lines_height + box_extra
  }
  let mut total_height = 0.0
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    let child_height = measure_node_intrinsic_height(child)
    total_height = total_height + child_height
  }
  total_height + box_extra
}

///|
/// Main table layout computation
pub fn compute(
  node : @node.Node,
  ctx : @types.LayoutContext,
  dispatch : @node.DispatchFn,
) -> @types.Layout {
  let style = node.style

  // Handle display:none
  if style.display == @types.Display::None {
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
    rows, num_columns, border_spacing, grid,
  )

  // Calculate intrinsic table width (content width based on columns)
  // For table shrink-to-fit, border-spacing is added:
  // - Between columns: (num_columns - 1) gaps
  // - On outer edges: 2 gaps (left and right)
  let mut anon_flow_intrinsic_width = 0.0
  if num_columns == 0 {
    let mut float_total_width = 0.0
    for child in node.children {
      if child.style.display == @types.Display::None {
        continue
      }
      if is_table_row(child.style.display) ||
        is_table_row_group(child.style.display) ||
        is_table_column(child.style.display) ||
        is_table_column_group(child.style.display) ||
        child.style.display == @types.TableCaption ||
        is_table_cell(child.style.display) {
        continue
      }
      let child_width = measure_node_intrinsic_width(child)
      match child.style.float {
        @types.Float::Left | @types.Float::Right =>
          float_total_width = float_total_width + child_width
        @types.Float::None =>
          if child_width > anon_flow_intrinsic_width {
            anon_flow_intrinsic_width = child_width
          }
      }
    }
    if float_total_width > anon_flow_intrinsic_width {
      anon_flow_intrinsic_width = float_total_width
    }
  }
  let @node.DispatchFn(dispatch_fn) = dispatch
  let caption_intrinsic_width_ctx : @types.LayoutContext = {
    available_width: 0.0,
    available_height: None,
    sizing_mode: @types.MaxContent,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  let mut caption_intrinsic_max_width = 0.0
  if num_columns == 0 {
    for child in node.children {
      if child.style.display == @types.Display::None ||
        child.style.display != @types.TableCaption {
        continue
      }
      if child.style.position == @types.Absolute ||
        child.style.position == @types.Fixed {
        continue
      }
      let caption_layout = dispatch_fn(
        child, caption_intrinsic_width_ctx, dispatch,
      )
      if caption_layout.width > caption_intrinsic_max_width {
        caption_intrinsic_max_width = caption_layout.width
      }
    }
  }
  let intrinsic_content_width = if num_columns > 0 {
    let mut total = 0.0
    for w in intrinsic_col_widths {
      total = total + w
    }
    // Total spacing = (num_columns - 1) between + 2 for edges = num_columns + 1
    total + border_spacing * (num_columns + 1).to_double()
  } else if caption_intrinsic_max_width > anon_flow_intrinsic_width {
    caption_intrinsic_max_width
  } else {
    anon_flow_intrinsic_width
  }

  // Calculate table width: shrink-to-fit for auto, unless in stretch context
  let intrinsic_table_width = intrinsic_content_width +
    padding.horizontal_sum() +
    border.horizontal_sum()
  let mut table_width = if ctx.stretch_width {
    // Flex/grid parents may have already resolved the used main size.
    // Respect that definite size for table layout.
    parent_width
  } else {
    match style.width {
      @types.Length(w) => w
      @types.Percent(p) => parent_width * p
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        intrinsic_table_width
      @types.Auto => {
        // Normal flow: shrink-to-fit behavior
        // Table width = content width + padding + border
        let min_width = intrinsic_table_width
        // Don't exceed available width
        if min_width > parent_width {
          parent_width
        } else {
          min_width
        }
      }
    }
  }
  // Apply width constraints only when width wasn't forced by parent stretch.
  if not(ctx.stretch_width) {
    // Apply max-width first, then min-width (min takes precedence over max).
    match style.max_width {
      @types.Length(max_w) => if table_width > max_w { table_width = max_w }
      @types.Percent(p) => {
        let max_w = parent_width * p
        if table_width > max_w {
          table_width = max_w
        }
      }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        if not(ignore_intrinsic_max_width_constraint(style)) &&
          table_width > intrinsic_table_width {
          table_width = intrinsic_table_width
        }
      @types.Auto => ()
    }
    match style.min_width {
      @types.Length(min_w) => if table_width < min_w { table_width = min_w }
      @types.Percent(p) => {
        let min_w = parent_width * p
        if table_width < min_w {
          table_width = min_w
        }
      }
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        if table_width < intrinsic_table_width {
          table_width = intrinsic_table_width
        }
      @types.Auto => ()
    }
  }
  let min_table_width = padding.horizontal_sum() + border.horizontal_sum()
  if table_width < min_table_width {
    table_width = min_table_width
  }
  if not(ctx.stretch_width) {
    let should_enforce_intrinsic_min_width = match style.max_width {
      @types.MinContent | @types.MaxContent | @types.FitContent(_) =>
        not(ignore_intrinsic_max_width_constraint(style))
      _ => true
    }
    let is_fixed_layout = style.table_layout == @style.TableLayout::Fixed
    // Auto-layout tables cannot be narrower than their intrinsic minimum width,
    // even when max-width is tighter than the intrinsic minimum.
    if not(is_fixed_layout) &&
      should_enforce_intrinsic_min_width &&
      table_width < intrinsic_table_width {
      table_width = intrinsic_table_width
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
  let is_fixed_layout = style.table_layout == @style.TableLayout::Fixed

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
      rows, num_columns, row_content_width, border_spacing, col_widths, grid,
    )
  }

  let caption_measure_ctx : @types.LayoutContext = {
    available_width: table_width,
    available_height: None,
    sizing_mode: ctx.sizing_mode,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  let mut caption_intrinsic_total = 0.0
  for child in node.children {
    if child.style.display == @types.Display::None {
      continue
    }
    if child.style.display == @types.TableCaption {
      if child.style.position == @types.Absolute ||
        child.style.position == @types.Fixed {
        continue
      }
      let caption_layout = dispatch_fn(child, caption_measure_ctx, dispatch)
      caption_intrinsic_total = caption_intrinsic_total + caption_layout.height
    }
  }

  // Resolve table height constraints
  let (resolved_min_table_height, resolved_max_table_height) = if ctx.stretch_height {
    // Flex/grid parent already resolved used block-size.
    (0.0, 1.0e10)
  } else {
    (
      match style.min_height {
        @types.Length(h) => h
        @types.Percent(p) =>
          ctx.available_height.unwrap_or(0.0) * p +
          padding.vertical_sum() +
          border.vertical_sum()
        _ => 0.0
      },
      match style.max_height {
        @types.Length(h) => h
        @types.Percent(p) =>
          ctx.available_height.unwrap_or(0.0) * p +
          padding.vertical_sum() +
          border.vertical_sum()
        _ => 1.0e10
      },
    )
  }

  // Resolve explicit table height from style
  // Percent height is treated as content-box and converted to border-box.
  let explicit_table_height : Double? = match style.height {
    @types.Length(h) => Some(h)
    @types.Percent(p) =>
      Some(
        ctx.available_height.unwrap_or(0.0) * p +
        padding.vertical_sum() +
        border.vertical_sum(),
      )
    _ => None
  }
  let stretch_table_height : Double? = if ctx.stretch_height {
    match ctx.available_height {
      Some(h) if h < 1.0e9 => Some(max(0.0, h - caption_intrinsic_total))
      _ => None
    }
  } else {
    None
  }
  let target_table_height = match stretch_table_height {
    Some(h) => Some(h)
    None =>
      match explicit_table_height {
        Some(h) => {
          let clamped_min = max(h, resolved_min_table_height)
          let clamped = if clamped_min > resolved_max_table_height {
            resolved_max_table_height
          } else {
            clamped_min
          }
          Some(clamped)
        }
        None =>
          if resolved_min_table_height > 0.0 {
            if resolved_min_table_height > resolved_max_table_height {
              Some(resolved_max_table_height)
            } else {
              Some(resolved_min_table_height)
            }
          } else {
            None
          }
      }
  }

  // Calculate row heights with rowspan distribution
  let row_count = rows.length()
  let row_heights : Array[Double] = if row_count > 0 {
    // Step 1: Calculate base row heights (excluding rowspan cells)
    let base_heights = compute_base_row_heights(rows, grid, is_border_collapse)

    // Step 2: Collect all rowspan cells
    let rowspan_cells = collect_rowspan_cells(rows)

    // Step 3: Distribute rowspan cell heights across spanned rows
    distribute_rowspan_heights(base_heights, rowspan_cells, border_spacing)

    // Step 3.5: Table padding contributes to the row grid edges.
    // Put top/bottom padding into first/last row so row-group/cell sizes
    // keep matching table growth behavior.
    if base_heights.length() > 0 {
      if padding.top > 0.0 {
        base_heights[0] = base_heights[0] + padding.top
      }
      if padding.bottom > 0.0 {
        let last = base_heights.length() - 1
        base_heights[last] = base_heights[last] + padding.bottom
      }
    }

    // Step 4: If table has explicit/min height, ensure rows fill it
    match target_table_height {
      Some(h) => {
        // Calculate current total row height
        let mut current_total = border_spacing // top edge
        for i = 0; i < base_heights.length(); i = i + 1 {
          current_total = current_total + base_heights[i]
          current_total = current_total + border_spacing
        }
        let available_content_height = h -
          padding.vertical_sum() -
          border.vertical_sum()

        // If explicit height is larger, distribute extra evenly
        if available_content_height > current_total && row_count > 0 {
          let extra = available_content_height - current_total
          let extra_per_row = extra / row_count.to_double()
          for i = 0; i < base_heights.length(); i = i + 1 {
            base_heights[i] = base_heights[i] + extra_per_row
          }
        }
      }
      None => ()
    }
    base_heights
  } else {
    []
  }

  // Create base child context (use row_content_width for row layout)
  let base_child_ctx : @types.LayoutContext = {
    available_width: row_content_width,
    available_height: None,
    sizing_mode: ctx.sizing_mode,
    viewport_width: ctx.viewport_width,
    viewport_height: ctx.viewport_height,
    stretch_width: false,
    stretch_height: false,
  }
  let caption_child_ctx : @types.LayoutContext = {
    ..base_child_ctx,
    available_width: table_width,
  }

  // Collect captions and other children separately for caption-side ordering
  // caption-side: top captions go before rows, bottom captions go after
  // Table's caption-side is inherited by captions
  let top_captions : Array[TableChildEntry] = []
  let bottom_captions : Array[TableChildEntry] = []
  let row_children : Array[TableChildEntry] = [] // rows, row groups, cols
  let effective_child_by_index : Map[Int, @node.Node] = {}
  for i = 0; i < node.children.length(); i = i + 1 {
    let original_child = node.children[i]
    match flatten_first_non_none_contents_child(original_child, []) {
      Some(flattened) => {
        let child = flattened.child
        let entry : TableChildEntry = {
          child,
          index: i,
          wrappers: flattened.wrappers,
        }
        effective_child_by_index[i] = child
        if child.style.display == @types.TableCaption {
          // Use caption's own caption-side, or inherit from table
          let caption_side = child.style.caption_side
          // Note: CSS cascade handles inheritance, so if caption has its own value, use it
          // Otherwise it inherits from table (which is already computed)
          if caption_side == @style.CaptionSide::Bottom {
            bottom_captions.push(entry)
          } else {
            top_captions.push(entry)
          }
        } else {
          row_children.push(entry)
        }
      }
      None => {
        effective_child_by_index[i] = original_child
        row_children.push({ child: original_child, index: i, wrappers: [] })
      }
    }
  }

  // Create a map to store layouts by original index
  let layout_map : Map[Int, @types.Layout] = {}

  // Layout all children (including row groups)
  // y_offset includes top edge spacing
  let mut y_offset = padding.top + border.top

  // First: layout top captions
  for entry in top_captions {
    let child = entry.child
    let idx = entry.index
    if child.style.display == @types.Display::None {
      layout_map[idx] = wrap_layout_with_contents_wrappers(
        create_zero_layout(child),
        entry.wrappers,
      )
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      let out_of_flow_caption_ctx : @types.LayoutContext = {
        ..caption_child_ctx,
        available_width: 0.0,
        sizing_mode: @types.MaxContent,
      }
      let caption_layout = dispatch_fn(child, out_of_flow_caption_ctx, dispatch)
      layout_map[idx] = wrap_layout_with_contents_wrappers(
        caption_layout,
        entry.wrappers,
      )
      continue
    }
    let caption_layout = dispatch_fn(child, caption_child_ctx, dispatch)
    let positioned_caption = {
      ..caption_layout,
      x: padding.left + border.left,
      y: y_offset,
    }
    y_offset = y_offset + caption_layout.height
    layout_map[idx] = wrap_layout_with_contents_wrappers(
      positioned_caption,
      entry.wrappers,
    )
  }

  // Add border-spacing before rows
  y_offset = y_offset + border_spacing
  let row_flow_start_y = y_offset

  // x position for rows includes left edge spacing
  let row_x_offset = padding.left + border.left + border_spacing

  // Track global row index (matching order in collect_table_rows)
  let mut global_row_idx = 0
  let mut has_anon_flow_children = false
  let row_flow_items : Array[TableRowFlowItem] = []

  // Second: layout rows and row groups
  if row_count == 0 {
    // No table rows: lay out non-table children as an anonymous block flow.
    let anon_children : Array[@node.Node] = []
    let anon_entries : Array[TableChildEntry] = []
    for entry in row_children {
      let child = entry.child
      let idx = entry.index
      if is_ignorable_table_text_node(child) {
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          create_zero_layout(child),
          entry.wrappers,
        )
        continue
      }
      if child.style.display == @types.Display::None {
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          create_zero_layout(child),
          entry.wrappers,
        )
        continue
      }
      if is_table_column_group(child.style.display) ||
        is_table_column(child.style.display) {
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          create_zero_layout(child),
          entry.wrappers,
        )
        continue
      }
      anon_children.push(child)
      anon_entries.push(entry)
    }
    if anon_children.length() > 0 {
      has_anon_flow_children = true
      let anon_style : @style.Style = {
        ..@style.Style::default(),
        display: @types.Block,
        width: @types.Length(row_content_width),
      }
      let anon_node = @node.Node::new(
        "__anon-table-flow", anon_style, anon_children,
      )
      let anon_ctx : @types.LayoutContext = {
        available_width: row_content_width,
        available_height: None,
        sizing_mode: @types.Definite,
        viewport_width: ctx.viewport_width,
        viewport_height: ctx.viewport_height,
        stretch_width: false,
        stretch_height: false,
      }
      let anon_layout = dispatch_fn(anon_node, anon_ctx, dispatch)
      for i = 0; i < anon_entries.length(); i = i + 1 {
        let entry = anon_entries[i]
        if i < anon_layout.children.length() {
          let child_layout = anon_layout.children[i]
          layout_map[entry.index] = wrap_layout_with_contents_wrappers(
            {
              ..child_layout,
              x: row_x_offset + child_layout.x,
              y: y_offset + child_layout.y,
            },
            entry.wrappers,
          )
        } else {
          layout_map[entry.index] = wrap_layout_with_contents_wrappers(
            create_zero_layout(entry.child),
            entry.wrappers,
          )
        }
      }
      y_offset = y_offset + anon_layout.height
    }
  } else {
    let mut pending_direct_cells : Array[(@node.Node, Int, Array[@node.Node])] = []
    let mut first_footer_bucket_taken = false
    let mut table_col_idx = 0
    fn flush_pending_direct_cells() -> Unit {
      if pending_direct_cells.length() == 0 {
        return ()
      }
      let base_y = y_offset
      // Consecutive direct table-cell children belong to the same anonymous row.
      let anon_row_style : @style.Style = {
        ..@style.Style::default(),
        display: @types.TableRow,
      }
      let anon_row_children : Array[@node.Node] = []
      for entry in pending_direct_cells {
        let (cell, _, _) = entry
        anon_row_children.push(cell)
      }
      let anon_row = @node.Node::new(
        "__anon-table-row-layout-" + global_row_idx.to_string(),
        anon_row_style,
        anon_row_children,
      )
      let row_height = if global_row_idx < row_heights.length() {
        Some(row_heights[global_row_idx])
      } else {
        None
      }
      let row_ctx : @types.LayoutContext = {
        ..base_child_ctx,
        available_height: row_height,
      }
      let row_layout = layout_row(
        anon_row, global_row_idx, column_widths, border_spacing, row_ctx, is_border_collapse,
        grid, dispatch,
      )
      let run_indices : Array[Int] = []
      for i = 0; i < pending_direct_cells.length(); i = i + 1 {
        let (cell, idx, wrappers) = pending_direct_cells[i]
        run_indices.push(idx)
        if i < row_layout.children.length() {
          let cell_layout = row_layout.children[i]
          let (rel_x, rel_y) = calculate_relative_offset(
            cell.style,
            cell_layout.width,
            cell_layout.height,
          )
          layout_map[idx] = wrap_layout_with_contents_wrappers(
            {
              ..cell_layout,
              x: row_x_offset + cell_layout.x + rel_x,
              y: y_offset + cell_layout.y + rel_y,
            },
            wrappers,
          )
        } else {
          layout_map[idx] = wrap_layout_with_contents_wrappers(
            create_zero_layout(cell),
            wrappers,
          )
        }
      }
      let advance = row_layout.height + border_spacing
      y_offset = y_offset + row_layout.height + border_spacing
      row_flow_items.push({ indices: run_indices, base_y, advance, bucket: 1 })
      global_row_idx = global_row_idx + 1
      pending_direct_cells = []
    }

    for entry in row_children {
      let child = entry.child
      let idx = entry.index
      if is_ignorable_table_text_node(child) {
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          create_zero_layout(child),
          entry.wrappers,
        )
        continue
      }
      if child.style.display == @types.Display::None {
        flush_pending_direct_cells()
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          create_zero_layout(child),
          entry.wrappers,
        )
        continue
      }
      if is_table_cell(child.style.display) {
        pending_direct_cells.push((child, idx, entry.wrappers))
      } else if is_table_row(child.style.display) {
        flush_pending_direct_cells()
        let base_y = y_offset
        // Direct row - use pre-calculated row height
        let row_height = if global_row_idx < row_heights.length() {
          Some(row_heights[global_row_idx])
        } else {
          None
        }
        let row_ctx : @types.LayoutContext = {
          ..base_child_ctx,
          available_height: row_height,
        }
        let row_layout = layout_row(
          child, global_row_idx, column_widths, border_spacing, row_ctx, is_border_collapse,
          grid, dispatch,
        )
        // Apply position: relative offset for rows
        let (rel_x, rel_y) = calculate_relative_offset(
          child.style,
          row_layout.width,
          row_layout.height,
        )
        let positioned_row = {
          ..row_layout,
          x: row_x_offset + rel_x,
          y: y_offset + rel_y,
        }
        let indices : Array[Int] = [idx]
        let advance = row_layout.height + border_spacing
        y_offset = y_offset + row_layout.height + border_spacing
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          positioned_row,
          entry.wrappers,
        )
        row_flow_items.push({ indices, base_y, advance, bucket: 1 })
        global_row_idx = global_row_idx + 1
      } else if is_table_row_group(child.style.display) {
        flush_pending_direct_cells()
        let base_y = y_offset
        // Row group (thead, tbody, tfoot)
        let group_layouts : Array[@types.Layout] = []
        let mut group_y = 0.0
        let mut max_row_width = 0.0
        let group_style = child.style
        let group_margin = @types.resolve_rect(group_style.margin, parent_width)
        let group_padding = @types.resolve_rect(
          group_style.padding,
          parent_width,
        )
        let group_border = @types.resolve_rect(group_style.border, parent_width)
        for row in normalize_row_group_rows(child) {
          // Use pre-calculated row height for rows in row groups
          let row_height = if global_row_idx < row_heights.length() {
            Some(row_heights[global_row_idx])
          } else {
            None
          }
          let row_ctx : @types.LayoutContext = {
            ..base_child_ctx,
            available_height: row_height,
          }
          let row_layout = layout_row(
            row, global_row_idx, column_widths, border_spacing, row_ctx, is_border_collapse,
            grid, dispatch,
          )
          // Apply position: relative offset for rows inside groups
          let (rel_x, rel_y) = calculate_relative_offset(
            row.style,
            row_layout.width,
            row_layout.height,
          )
          let positioned_row = {
            ..row_layout,
            x: group_padding.left + group_border.left + rel_x,
            y: group_y + group_padding.top + group_border.top + rel_y,
          }
          group_y = group_y + row_layout.height + border_spacing
          // Track max row width for consistent group width
          max_row_width = max(max_row_width, row_layout.width)
          if row.id.has_prefix("__anon-table-rowgrp-row-") {
            for anon_child in row_layout.children {
              group_layouts.push({
                ..anon_child,
                x: positioned_row.x + anon_child.x,
                y: positioned_row.y + anon_child.y,
              })
            }
          } else {
            group_layouts.push(positioned_row)
          }
          global_row_idx = global_row_idx + 1
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
        // Apply position: relative offset for row groups
        let (rel_x, rel_y) = calculate_relative_offset(
          group_style, row_content_width, group_height,
        )
        let group_layout : @types.Layout = {
          id: child.id,
          x: row_x_offset + rel_x,
          y: y_offset + rel_y,
          width: group_width,
          height: group_height,
          margin: group_margin,
          padding: group_padding,
          border: group_border,
          overflow_x: group_style.overflow_x,
          overflow_y: group_style.overflow_y,
          scroll_width: 0.0,
          scroll_height: 0.0,
          children: group_layouts,
          text: child.text,
        }
        let bucket = match child.style.display {
          @types.TableHeaderGroup => 0
          @types.TableFooterGroup =>
            if not(first_footer_bucket_taken) {
              first_footer_bucket_taken = true
              2
            } else {
              1
            }
          _ => 1
        }
        let indices : Array[Int] = [idx]
        let advance = group_height + border_spacing
        y_offset = y_offset + group_height + border_spacing
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          group_layout,
          entry.wrappers,
        )
        row_flow_items.push({ indices, base_y, advance, bucket })
      } else if is_table_column_group(child.style.display) {
        flush_pending_direct_cells()
        // Colgroup: layout with column widths, positioned later
        // These are placeholder layouts that will be updated after we know table height
        let col_layouts : Array[@types.Layout] = []
        let mut col_x = 0.0
        for col in collect_table_effective_children(child) {
          if is_table_column(col.style.display) {
            let col_width = if table_col_idx < column_widths.length() {
              column_widths[table_col_idx]
            } else {
              0.0
            }
            let zero_rect : @types.Rect[Double] = {
              left: 0.0,
              right: 0.0,
              top: 0.0,
              bottom: 0.0,
            }
            let col_layout : @types.Layout = {
              id: col.id,
              x: col_x,
              y: 0.0,
              width: col_width,
              height: 0.0, // Will be updated
              margin: zero_rect,
              padding: zero_rect,
              border: zero_rect,
              overflow_x: @types.Visible,
              overflow_y: @types.Visible,
              scroll_width: 0.0,
              scroll_height: 0.0,
              children: [],
              text: col.text,
            }
            col_x = col_x + col_width + border_spacing
            table_col_idx = table_col_idx + 1
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
        let colgroup_layout : @types.Layout = {
          id: child.id,
          x: row_x_offset,
          y: y_offset,
          width: colgroup_width,
          height: 0.0, // Will be updated after layout
          margin: zero_rect,
          padding: zero_rect,
          border: zero_rect,
          overflow_x: @types.Visible,
          overflow_y: @types.Visible,
          scroll_width: 0.0,
          scroll_height: 0.0,
          children: col_layouts,
          text: child.text,
        }
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          colgroup_layout,
          entry.wrappers,
        )
      } else if is_table_column(child.style.display) {
        flush_pending_direct_cells()
        // Standalone col element (outside colgroup)
        let col_width = if table_col_idx < column_widths.length() {
          column_widths[table_col_idx]
        } else {
          0.0
        }
        let zero_rect : @types.Rect[Double] = {
          left: 0.0,
          right: 0.0,
          top: 0.0,
          bottom: 0.0,
        }
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          {
            id: child.id,
            x: column_start_x(column_widths, table_col_idx, border_spacing),
            y: 0.0,
            width: col_width,
            height: 0.0,
            margin: zero_rect,
            padding: zero_rect,
            border: zero_rect,
            overflow_x: @types.Visible,
            overflow_y: @types.Visible,
            scroll_width: 0.0,
            scroll_height: 0.0,
            children: [],
            text: child.text,
          },
          entry.wrappers,
        )
        table_col_idx = table_col_idx + 1
      } else {
        flush_pending_direct_cells()
        // Other children: create zero layout
        layout_map[idx] = wrap_layout_with_contents_wrappers(
          create_zero_layout(child),
          entry.wrappers,
        )
      }
    }
    flush_pending_direct_cells()

    // Visual ordering for row groups: headers first, footers last.
    if row_flow_items.length() > 0 {
      let header_items : Array[TableRowFlowItem] = []
      let body_items : Array[TableRowFlowItem] = []
      let footer_items : Array[TableRowFlowItem] = []
      for item in row_flow_items {
        if item.bucket == 0 {
          header_items.push(item)
        } else if item.bucket == 2 {
          footer_items.push(item)
        } else {
          body_items.push(item)
        }
      }
      let visual_items : Array[TableRowFlowItem] = []
      for item in header_items {
        visual_items.push(item)
      }
      for item in body_items {
        visual_items.push(item)
      }
      for i = footer_items.length(); i > 0; i = i - 1 {
        visual_items.push(footer_items[i - 1])
      }

      let mut next_y = row_flow_start_y
      for item in visual_items {
        let delta = next_y - item.base_y
        if delta != 0.0 {
          for idx in item.indices {
            match layout_map.get(idx) {
              Some(layout) =>
                layout_map[idx] = { ..layout, y: layout.y + delta }
              None => ()
            }
          }
        }
        next_y = next_y + item.advance
      }
    }
  }

  // Third: layout bottom captions
  for entry in bottom_captions {
    let child = entry.child
    let idx = entry.index
    if child.style.display == @types.Display::None {
      layout_map[idx] = wrap_layout_with_contents_wrappers(
        create_zero_layout(child),
        entry.wrappers,
      )
      continue
    }
    if child.style.position == @types.Absolute ||
      child.style.position == @types.Fixed {
      let out_of_flow_caption_ctx : @types.LayoutContext = {
        ..caption_child_ctx,
        available_width: 0.0,
        sizing_mode: @types.MaxContent,
      }
      let caption_layout = dispatch_fn(child, out_of_flow_caption_ctx, dispatch)
      layout_map[idx] = wrap_layout_with_contents_wrappers(
        caption_layout,
        entry.wrappers,
      )
      continue
    }
    let caption_layout = dispatch_fn(child, caption_child_ctx, dispatch)
    let positioned_caption = {
      ..caption_layout,
      x: padding.left + border.left,
      y: y_offset,
    }
    y_offset = y_offset + caption_layout.height
    layout_map[idx] = wrap_layout_with_contents_wrappers(
      positioned_caption,
      entry.wrappers,
    )
  }

  // Calculate table height
  // y_offset includes table padding/border offsets already.
  // Convert back to content height before adding box model in final height.
  let content_height = y_offset - padding.top - border.top
  let has_rendered_content = row_count > 0 ||
    has_anon_flow_children ||
    top_captions.length() > 0 ||
    bottom_captions.length() > 0
  let raw_table_height = if has_rendered_content {
    match style.height {
      @types.Length(h) =>
        max(h, content_height + padding.vertical_sum() + border.vertical_sum())
      @types.Percent(p) => {
        let parent_h = ctx.available_height.unwrap_or(0.0)
        max(
          parent_h * p + padding.vertical_sum() + border.vertical_sum(),
          content_height + padding.vertical_sum() + border.vertical_sum(),
        )
      }
      _ => content_height + padding.vertical_sum() + border.vertical_sum()
    }
  } else {
    padding.vertical_sum() + border.vertical_sum()
  }
  let clamped_min_height = max(raw_table_height, resolved_min_table_height)
  let mut table_height = if clamped_min_height > resolved_max_table_height {
    resolved_max_table_height
  } else {
    clamped_min_height
  }
  // In vertical writing modes, physical height is inline-size.
  // Auto-layout tables should not shrink below intrinsic inline minimum size.
  if style.writing_mode.is_vertical() &&
    not(ctx.stretch_height) &&
    not(is_fixed_layout) {
    let intrinsic_inline_height = compute_intrinsic_size(node, false)
    if table_height < intrinsic_inline_height {
      table_height = intrinsic_inline_height
    }
  }

  // Calculate row content height for colgroup/col height
  // This is the height of all rows (excluding padding/border)
  let row_content_height = content_height - border_spacing

  // Assemble child_layouts in original order from layout_map
  // Also update colgroup/col heights now that we know the table content height
  let final_child_layouts : Array[@types.Layout] = []
  for i = 0; i < node.children.length(); i = i + 1 {
    let effective_child = match effective_child_by_index.get(i) {
      Some(child) => child
      None => node.children[i]
    }
    match layout_map.get(i) {
      Some(layout) =>
        if is_table_column_group(effective_child.style.display) {
          // This might be a colgroup - update its height and children's heights
          let updated_col_children : Array[@types.Layout] = []
          for col_layout in layout.children {
            if col_layout.height == 0.0 && col_layout.width > 0.0 {
              // This is a col element
              updated_col_children.push({
                ..col_layout,
                height: row_content_height,
              })
            } else {
              updated_col_children.push(col_layout)
            }
          }
          final_child_layouts.push({
            ..layout,
            height: row_content_height,
            children: updated_col_children,
          })
        } else if is_table_column(effective_child.style.display) {
          // Standalone col element
          final_child_layouts.push({ ..layout, height: row_content_height })
        } else {
          final_child_layouts.push(layout)
        }
      None => () // Should not happen
    }
  }
  fn overflow_creates_scroll_container(overflow : @types.Overflow) -> Bool {
    match overflow {
      @types.Visible | @types.Clip => false
      @types.Hidden | @types.Scroll | @types.Auto => true
    }
  }
  fn normalize_cell_descendant_offsets(
    layout : @types.Layout,
    inside_cell : Bool,
  ) -> @types.Layout {
    let is_cell_box = inside_cell ||
      layout.id == "td" ||
      layout.id == "th" ||
      layout.id.has_prefix("__anon-table-cell-")
    let keeps_descendant_negative_offsets = overflow_creates_scroll_container(
        layout.overflow_x,
      ) ||
      overflow_creates_scroll_container(layout.overflow_y)
    let propagate_inside_cell = is_cell_box &&
      not(keeps_descendant_negative_offsets)
    let normalized_children : Array[@types.Layout] = []
    for child in layout.children {
      let normalized_child = normalize_cell_descendant_offsets(
        child, propagate_inside_cell,
      )
      let normalized_y = if propagate_inside_cell && normalized_child.y < 0.0 {
        0.0
      } else {
        normalized_child.y
      }
      normalized_children.push({ ..normalized_child, y: normalized_y })
    }
    { ..layout, children: normalized_children }
  }
  let normalized_child_layouts : Array[@types.Layout] = []
  for child_layout in final_child_layouts {
    normalized_child_layouts.push(
      normalize_cell_descendant_offsets(child_layout, false),
    )
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
    scroll_width: 0.0,
    scroll_height: 0.0,
    children: normalized_child_layouts,
    text: node.text,
  }
}
