///|
/// Basic table layout test
test "simple table layout" {
  // Create styles
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(200.0),
  }

  // Create nodes
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let cell3 = @node.Node::new("cell3", cell_style, [])
  let cell4 = @node.Node::new("cell4", cell_style, [])
  let row2 = @node.Node::new("row2", row_style, [cell3, cell4])
  let table = @node.Node::new("table", table_style, [row1, row2])

  // Create context
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }

  // Compute layout
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Check table dimensions
  assert_true(layout.width > 0.0)
  assert_true(layout.height > 0.0)
  assert_eq(layout.children.length(), 2) // 2 rows
}

///|
/// Test table with tbody
test "table with row group" {
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let tbody_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRowGroup,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(200.0),
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1])
  let tbody = @node.Node::new("tbody", tbody_style, [row1])
  let table = @node.Node::new("table", table_style, [tbody])
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Check table has children (tbody)
  assert_eq(layout.children.length(), 1)
  // tbody should have the row
  assert_eq(layout.children[0].children.length(), 1)
}

///|
/// Test equal column width distribution
test "table equal column widths" {
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(200.0),
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Table width should be 200
  inspect(layout.width, content="200")

  // Row should have 2 cells
  assert_eq(layout.children[0].children.length(), 2)

  // Each cell should be approximately 100px wide (minus spacing)
  // (200 - 2px border-spacing) / 2 = 99px per column
  let cell1_layout = layout.children[0].children[0]
  let cell2_layout = layout.children[0].children[1]
  assert_true(cell1_layout.width > 90.0)
  assert_true(cell2_layout.width > 90.0)

  // CRITICAL: Cells must be positioned horizontally, not vertically
  // Cell 1 should be at x=0 (or small offset), Cell 2 should be at x > cell1_width
  inspect(cell1_layout.x, content="0")
  inspect(cell1_layout.y, content="0")
  inspect(cell2_layout.y, content="0") // Both cells on same row
  // Cell 2 must be to the right of Cell 1
  assert_true(cell2_layout.x > 0.0)
}

///|
/// Test content-based column width with explicit cell widths
test "table content-based column widths" {
  // Cell with explicit width should affect column width
  let wide_cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(150.0),
  }
  let narrow_cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(50.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(300.0),
  }
  let cell1 = @node.Node::new("cell1", wide_cell_style, [])
  let cell2 = @node.Node::new("cell2", narrow_cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Table width should be 300
  inspect(layout.width, content="300")

  // First cell should be wider than second cell
  let cell1_layout = layout.children[0].children[0]
  let cell2_layout = layout.children[0].children[1]
  assert_true(cell1_layout.width > cell2_layout.width)
}

///|
/// Test shrink-to-fit behavior for table with auto width
test "table shrink-to-fit width" {
  // Cells with explicit widths
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  // Table with auto width (should shrink to fit content)
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    border_spacing: 10.0,
  } // 10px border-spacing
  // width: Auto (default)
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @types.LayoutContext = {
    available_width: 800.0, // Large available width
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Table should shrink to fit: 100 + 10 + 100 = 210px
  // Not 800px (parent width)
  inspect(layout.width, content="230")

  // Row should have 2 cells
  let row_layout = layout.children[0]
  assert_eq(row_layout.children.length(), 2)

  // Cell2 should be at x = 110 (100 + 10 spacing)
  inspect(row_layout.children[0].x, content="0")
  inspect(row_layout.children[1].x, content="110")
}

///|
/// Test border-collapse layout
test "table border-collapse" {
  // Cell with explicit width and border
  // In real CSS, adjust_for_box_sizing converts content-box dimensions to include border
  // So width=50 with border=10 becomes width=70 (50 + 10 + 10)
  // Here we simulate that by setting width/height to 70 (50 content + 20 border)
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(70.0), // 50 content + 10 + 10 border (simulating adjust_for_box_sizing)
    height: @types.Length(70.0), // 50 content + 10 + 10 border
    border: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  // Table with border-collapse: collapse
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    border_collapse: @style.Collapse,
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // With border-collapse, cell dimensions should be 50x50 (border included)
  let row_layout = layout.children[0]
  let cell_layout = row_layout.children[0]

  // Cell height should be 50 (not 70 = 50 + 10 + 10)
  inspect(cell_layout.height, content="50")

  // Cell border in layout should be 0 (collapsed borders don't add to dimensions)
  inspect(cell_layout.border.top, content="0")
}

///|
/// Test table-layout: fixed
test "table-layout fixed" {
  // Two cells with auto width
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    height: @types.Length(100.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  // Table with table-layout: fixed and explicit width
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    table_layout: @style.TableLayout::Fixed,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Table should be 200px wide
  inspect(layout.width, content="200")

  // Each cell should be 100px wide (200 / 2 columns)
  let row_layout = layout.children[0]
  inspect(row_layout.children[0].width, content="100")
  inspect(row_layout.children[1].width, content="100")
}

///|
/// Test table-layout: fixed with explicit cell width in first row
test "table-layout fixed with explicit width" {
  // First row has cell with 150px width
  let cell_w150_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(150.0),
    height: @types.Length(50.0),
  }
  let cell_auto_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    height: @types.Length(50.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    table_layout: @style.TableLayout::Fixed,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell1 = @node.Node::new("cell1", cell_w150_style, [])
  let cell2 = @node.Node::new("cell2", cell_auto_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // First cell should be 150px, second gets remaining 50px
  let row_layout = layout.children[0]
  inspect(row_layout.children[0].width, content="150")
  inspect(row_layout.children[1].width, content="50")
}

///|
/// Test rowspan - cell spanning multiple rows
test "table rowspan" {
  // Row 0: Cell A (rowspan=2, 100px wide), Cell B (100px wide)
  // Row 1: Cell C (should be at column 1, 100px wide)
  let cell_a_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
    rowspan: 2,
  }
  let cell_b_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  }
  let cell_c_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell_a = @node.Node::new("cell_a", cell_a_style, [])
  let cell_b = @node.Node::new("cell_b", cell_b_style, [])
  let row0 = @node.Node::new("row0", row_style, [cell_a, cell_b])
  let cell_c = @node.Node::new("cell_c", cell_c_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell_c])
  let table = @node.Node::new("table", table_style, [row0, row1])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Row 0 should have 2 cells
  let row0_layout = layout.children[0]
  assert_eq(row0_layout.children.length(), 2)

  // Row 1 should have 1 cell
  let row1_layout = layout.children[1]
  assert_eq(row1_layout.children.length(), 1)

  // Cell C in row 1 should be at x = 100 (after the rowspan cell A)
  // because column 0 is occupied by cell A's rowspan
  let cell_c_layout = row1_layout.children[0]
  inspect(cell_c_layout.x, content="100")
}

///|
/// Test rowspan height distribution - tall rowspan cell expands rows
test "table rowspan height distribution" {
  // Row 0: Cell A (rowspan=2, tall content), Cell B (short)
  // Row 1: Cell C (short)
  // The rowspan cell's height should be distributed across both rows
  let cell_a_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(100.0), // Tall cell
    rowspan: 2,
  }
  let cell_b_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(20.0), // Short cell
  }
  let cell_c_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(20.0), // Short cell
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell_a = @node.Node::new("cell_a", cell_a_style, [])
  let cell_b = @node.Node::new("cell_b", cell_b_style, [])
  let row0 = @node.Node::new("row0", row_style, [cell_a, cell_b])
  let cell_c = @node.Node::new("cell_c", cell_c_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell_c])
  let table = @node.Node::new("table", table_style, [row0, row1])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Row 0 and Row 1 should have equal heights (100 / 2 = 50 each)
  // because the rowspan cell (100px) needs to fit across both rows
  let row0_layout = layout.children[0]
  let row1_layout = layout.children[1]

  // Each row should be 50px (100px rowspan cell / 2 rows)
  // Note: base height for row 0 is 20 (from cell B), row 1 is 20 (from cell C)
  // Extra needed = 100 - 40 = 60, distributed evenly = 30 each
  // So row 0 = 20 + 30 = 50, row 1 = 20 + 30 = 50
  inspect(row0_layout.height, content="50")
  inspect(row1_layout.height, content="50")

  // Cell C should be at correct x position (skipping rowspan cell's column)
  let cell_c_layout = row1_layout.children[0]
  inspect(cell_c_layout.x, content="100")
}

///|
/// Test rowspan with tbody - cell spanning multiple rows inside tbody
test "table rowspan with tbody" {
  // Row 0: Cell A (rowspan=2), Cell B
  // Row 1: Cell C (should be at column 1)
  let cell_a_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
    rowspan: 2,
  }
  let cell_b_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  }
  let cell_c_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let tbody_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRowGroup,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell_a = @node.Node::new("cell_a", cell_a_style, [])
  let cell_b = @node.Node::new("cell_b", cell_b_style, [])
  let row0 = @node.Node::new("row0", row_style, [cell_a, cell_b])
  let cell_c = @node.Node::new("cell_c", cell_c_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell_c])
  let tbody = @node.Node::new("tbody", tbody_style, [row0, row1])
  let table = @node.Node::new("table", table_style, [tbody])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
  }
  @dispatch.setup()
  let layout = @dispatch.compute(table, ctx)

  // Table should have 1 child (tbody)
  assert_eq(layout.children.length(), 1)

  // tbody should have 2 rows
  let tbody_layout = layout.children[0]
  assert_eq(tbody_layout.children.length(), 2)

  // Row 0 should have 2 cells
  let row0_layout = tbody_layout.children[0]
  assert_eq(row0_layout.children.length(), 2)

  // Row 1 should have 1 cell
  let row1_layout = tbody_layout.children[1]
  assert_eq(row1_layout.children.length(), 1)

  // Cell C in row 1 should be at x = 100 (after the rowspan cell A)
  let cell_c_layout = row1_layout.children[0]
  inspect(cell_c_layout.x, content="100")
}
