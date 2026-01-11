///|
/// Basic table layout test
test "simple table layout" {
  // Create styles
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableCell,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
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
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.Definite,
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
    display: @style.TableCell,
    width: @types.Length(50.0),
    height: @types.Length(20.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRow,
  }
  let tbody_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRowGroup,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
    width: @types.Length(200.0),
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1])
  let tbody = @node.Node::new("tbody", tbody_style, [row1])
  let table = @node.Node::new("table", table_style, [tbody])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.Definite,
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
    display: @style.TableCell,
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
    width: @types.Length(200.0),
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.Definite,
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
    display: @style.TableCell,
    width: @types.Length(150.0),
  }
  let narrow_cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableCell,
    width: @types.Length(50.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
    width: @types.Length(300.0),
  }
  let cell1 = @node.Node::new("cell1", wide_cell_style, [])
  let cell2 = @node.Node::new("cell2", narrow_cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @node.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @node.Definite,
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
    display: @style.TableCell,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRow,
  }
  // Table with auto width (should shrink to fit content)
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
    border_spacing: 10.0,
  } // 10px border-spacing
  // width: Auto (default)
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @node.LayoutContext = {
    available_width: 800.0, // Large available width
    available_height: Some(600.0),
    sizing_mode: @node.Definite,
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
    display: @style.TableCell,
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
    display: @style.TableRow,
  }
  // Table with border-collapse: collapse
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
    border_collapse: @style.Collapse,
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.Definite,
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
    display: @style.TableCell,
    height: @types.Length(100.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRow,
  }
  // Table with table-layout: fixed and explicit width
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
    table_layout: @style.Fixed,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell1 = @node.Node::new("cell1", cell_style, [])
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.Definite,
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
    display: @style.TableCell,
    width: @types.Length(150.0),
    height: @types.Length(50.0),
  }
  let cell_auto_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableCell,
    height: @types.Length(50.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @style.Table,
    table_layout: @style.Fixed,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell1 = @node.Node::new("cell1", cell_w150_style, [])
  let cell2 = @node.Node::new("cell2", cell_auto_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @node.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @node.Definite,
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
