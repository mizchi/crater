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
    stretch_width: false,
    stretch_height: false,
  }

  // Compute layout
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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
test "table intrinsic width respects colspan distribution" {
  let wide_cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(48.0),
    colspan: 2,
  }
  let narrow_cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(24.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    border_spacing: 0.0,
  }

  let span_cell = @node.Node::new("span", wide_cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [span_cell])
  let cell_a = @node.Node::new("a", narrow_cell_style, [])
  let cell_b = @node.Node::new("b", narrow_cell_style, [])
  let row2 = @node.Node::new("row2", row_style, [cell_a, cell_b])
  let table = @node.Node::new("table", table_style, [row1, row2])

  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }

  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  assert_eq(layout.children.length(), 2)
  let row2_layout = layout.children[1]
  assert_eq(row2_layout.children.length(), 2)

  // Colspan width should be distributed across 2 columns (24 + 24),
  // instead of inflating only the first column.
  inspect(row2_layout.children[0].width, content="24")
  inspect(row2_layout.children[1].x, content="24")
}

///|
test "table row ignores direct text nodes between cells" {
  let text_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Inline,
  }
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
  let text = @node.Node::leaf("#text", text_style)
  let cell2 = @node.Node::new("cell2", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell1, text, cell2])
  let table = @node.Node::new("table", table_style, [row1])
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  assert_eq(layout.children.length(), 1)
  let row_layout = layout.children[0]
  assert_eq(row_layout.children.length(), 2)
  assert_true(row_layout.children[0].width > 90.0)
  assert_true(row_layout.children[1].width > 90.0)
}

///|
test "table_max_width_percent_constraint" {
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(60.0),
    height: @types.Length(10.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    border_spacing: 0.0,
    max_width: @types.Percent(0.5),
  }
  let cell = @node.Node::new("cell", cell_style, [])
  let row = @node.Node::new("row", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 100.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 100.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  // Auto-layout tables must not shrink below their intrinsic minimum width,
  // even if max-width is tighter.
  inspect(layout.width, content="60")
}

///|
test "table_min_width_percent_constraint" {
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(10.0),
    height: @types.Length(10.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    min_width: @types.Percent(1.0),
  }
  let cell = @node.Node::new("cell", cell_style, [])
  let row = @node.Node::new("row", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 100.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 100.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  inspect(layout.width, content="100")
}

///|
test "table width less than intrinsic min expands" {
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(50.0),
    height: @types.Length(10.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(1.0),
  }
  let cell = @node.Node::new("cell", cell_style, [])
  let row = @node.Node::new("row", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 100.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 100.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  inspect(layout.width, content="50")
}

///|
test "table intrinsic width includes anonymous flow child" {
  let child_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Block,
    width: @types.Length(100.0),
    height: @types.Length(10.0),
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
  }
  let child = @node.Node::new("child", child_style, [])
  let table = @node.Node::new("table", table_style, [child])
  inspect(compute_intrinsic_size(table, true), content="100")
}

///|
test "vertical writing table ignores intrinsic max-width constraint" {
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(60.0),
    height: @types.Length(10.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    writing_mode: @style.WritingMode::VerticalLr,
    width: @types.Length(150.0),
    max_width: @types.MinContent,
  }
  let cell = @node.Node::new("cell", cell_style, [])
  let row = @node.Node::new("row", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 400.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 300.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  inspect(layout.width, content="150")
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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  // Table width should be 300
  inspect(layout.width, content="300")

  // First cell should be wider than second cell
  let cell1_layout = layout.children[0].children[0]
  let cell2_layout = layout.children[0].children[1]
  assert_true(cell1_layout.width > cell2_layout.width)
}

///|
test "table auto layout treats explicit cell width as minimum" {
  let text_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Inline,
  }
  let wide_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 150.0, max_width: 150.0, min_height: 20.0, max_height: 20.0 }
    },
  }
  let wide_text = @node.Node::with_measure("text", text_style, wide_measure)
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    border_spacing: 0.0,
  }
  let cell = @node.Node::new("cell", cell_style, [wide_text])
  let row = @node.Node::new("row", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  inspect(layout.width, content="150")
  inspect(layout.children[0].children[0].width, content="150")
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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  // With border-collapse, cell dimensions should be 50x50 (border included)
  let row_layout = layout.children[0]
  let cell_layout = row_layout.children[0]

  // Cell height should be 50 (not 70 = 50 + 10 + 10)
  inspect(cell_layout.height, content="50")

  // Cell border in layout should be 0 (collapsed borders don't add to dimensions)
  inspect(cell_layout.border.top, content="0")
}

///|
test "table border-collapse uses half border for inner table area" {
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
    border_collapse: @style.Collapse,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    border: {
      left: @types.Length(20.0),
      right: @types.Length(20.0),
      top: @types.Length(20.0),
      bottom: @types.Length(20.0),
    },
  }
  let cell = @node.Node::new("cell", cell_style, [])
  let row = @node.Node::new("row", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  inspect(layout.width, content="100")
  inspect(layout.height, content="100")
  inspect(layout.children[0].width, content="80")
  inspect(layout.children[0].height, content="80")
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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  // First cell should be 150px, second gets remaining 50px
  let row_layout = layout.children[0]
  inspect(row_layout.children[0].width, content="150")
  inspect(row_layout.children[1].width, content="50")
}

///|
test "table-layout fixed keeps explicit width below intrinsic content" {
  let text_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Inline,
  }
  let wide_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 400.0, max_width: 400.0, min_height: 20.0, max_height: 20.0 }
    },
  }
  let wide_text = @node.Node::with_measure("text", text_style, wide_measure)
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
    table_layout: @style.TableLayout::Fixed,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let cell = @node.Node::new("cell", cell_style, [wide_text])
  let row = @node.Node::new("row", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  inspect(layout.width, content="200")
}

///|
test "table-layout fixed standalone table-column boxes use resolved widths" {
  let col_auto_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableColumn,
  }
  let col_fixed_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableColumn,
    width: @types.Length(200.0),
  }
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
    table_layout: @style.TableLayout::Fixed,
    width: @types.Length(200.0),
    border_spacing: 0.0,
  }
  let col1 = @node.Node::new("col1", col_auto_style, [])
  let col2 = @node.Node::new("col2", col_fixed_style, [])
  let col3 = @node.Node::new("col3", col_auto_style, [])
  let td1 = @node.Node::new("td1", cell_style, [])
  let td2 = @node.Node::new("td2", cell_style, [])
  let td3 = @node.Node::new("td3", cell_style, [])
  let row = @node.Node::new("row", row_style, [td1, td2, td3])
  let table = @node.Node::new("table", table_style, [col1, col2, col3, row])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  inspect(layout.width, content="200")
  inspect(layout.children[0].width, content="0")
  inspect(layout.children[1].x, content="0")
  inspect(layout.children[1].width, content="200")
  inspect(layout.children[2].x, content="200")
  inspect(layout.children[2].width, content="0")
}

///|
test "table column visibility collapse enforces zero-width track" {
  let col1_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableColumn,
    width: @types.Length(65.0),
  }
  let col2_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableColumn,
    visibility: @style.Collapse,
  }
  let col3_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableColumn,
    width: @types.Length(160.0),
  }
  let cell1_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(65.0),
  }
  let cell2_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(120.0),
  }
  let cell3_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(160.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    border_spacing: 0.0,
  }

  let col1 = @node.Node::new("col1", col1_style, [])
  let col2 = @node.Node::new("col2", col2_style, [])
  let col3 = @node.Node::new("col3", col3_style, [])
  let td1 = @node.Node::new("td1", cell1_style, [])
  let td2 = @node.Node::new("td2", cell2_style, [])
  let td3 = @node.Node::new("td3", cell3_style, [])
  let row = @node.Node::new("row", row_style, [td1, td2, td3])
  let table = @node.Node::new("table", table_style, [col1, col2, col3, row])

  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }

  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  inspect(layout.width, content="225")
  inspect(layout.children[1].width, content="0")
  inspect(layout.children[3].children[1].width, content="0")
  inspect(layout.children[3].children[2].x, content="65")
}

///|
test "table collapsed row suppresses vertical border spacing in rowspan flow" {
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(100.0),
    padding: {
      left: @types.Length(0.0),
      right: @types.Length(0.0),
      top: @types.Length(0.0),
      bottom: @types.Length(0.0),
    },
    rowspan: 2,
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let collapsed_row_style : @style.Style = {
    ..row_style,
    visibility: @style.Collapse,
  }
  let tbody_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRowGroup,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    border_spacing: 50.0,
    border_spacing_vertical: 100.0,
  }
  let cell = @node.Node::new("cell", cell_style, [])
  let row1 = @node.Node::new("row1", row_style, [cell])
  let row2 = @node.Node::new("row2", collapsed_row_style, [])
  let tbody = @node.Node::new("tbody", tbody_style, [row1, row2])
  let table = @node.Node::new("table", table_style, [tbody])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  inspect(layout.height, content="200")
  inspect(layout.children[0].height, content="0")
  inspect(layout.children[0].children[1].y, content="0")
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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

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

///|
/// Vertical writing-mode inline flow should contribute column advances to table intrinsic width.
test "table intrinsic width includes vertical inline columns" {
  let text_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Inline,
    width: @types.Length(10.0),
    height: @types.Length(15.0),
  }
  let br_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Inline,
    width: @types.Length(10.0),
    height: @types.Length(0.0),
  }
  let content_style : @style.Style = {
    ..@style.Style::default(),
    writing_mode: @style.WritingMode::VerticalLr,
  }
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
    padding: {
      left: @types.Length(30.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
    border: {
      left: @types.Length(5.0),
      right: @types.Length(5.0),
      top: @types.Length(5.0),
      bottom: @types.Length(5.0),
    },
  }

  let text1 = @node.Node::leaf("#text", text_style)
  let br = @node.Node::leaf("br", br_style)
  let text2 = @node.Node::leaf("#text", text_style)
  let content = @node.Node::new("content", content_style, [text1, br, text2])
  let cell = @node.Node::new("td", cell_style, [content])
  let row = @node.Node::new("tr", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])

  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)

  // (10 + 10 columns) + (padding 35) + (border 10)
  assert_true(layout.width > 60.0)
  let cell_layout = layout.children[0].children[0]
  let content_layout = cell_layout.children[0]
  assert_true(content_layout.width > 10.0)
}

///|
test "table cell centers block child in vertical writing mode" {
  let block_style : @style.Style = {
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
    border: {
      left: @types.Length(1.0),
      right: @types.Length(1.0),
      top: @types.Length(1.0),
      bottom: @types.Length(1.0),
    },
  }
  let cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    writing_mode: @style.WritingMode::VerticalLr,
    border: {
      left: @types.Length(2.0),
      right: @types.Length(2.0),
      top: @types.Length(2.0),
      bottom: @types.Length(2.0),
    },
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    writing_mode: @style.WritingMode::VerticalLr,
    width: @types.Length(150.0),
    border: {
      left: @types.Length(2.0),
      right: @types.Length(2.0),
      top: @types.Length(2.0),
      bottom: @types.Length(2.0),
    },
  }

  let block = @node.Node::leaf("div.item", block_style)
  let cell = @node.Node::new("td", cell_style, [block])
  let row = @node.Node::new("tr", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  let block_layout = layout.children[0].children[0].children[0]
  assert_true(block_layout.x > 35.0)
}

///|
test "table preserves negative descendant offsets inside cell scroll container" {
  let default_style = @style.Style::default()
  let indicator_style : @style.Style = {
    ..default_style,
    width: @types.Length(72.0),
    height: @types.Length(72.0),
  }
  let scroller_style : @style.Style = {
    ..default_style,
    width: @types.Length(24.0),
    height: @types.Length(24.0),
    overflow_x: @types.Overflow::Hidden,
    overflow_y: @types.Overflow::Hidden,
    justify_content: @types.Alignment::Center,
    align_content: @types.Alignment::Center,
    align_content_unsafe: true,
  }
  let cell_style : @style.Style = { ..default_style, display: @types.TableCell }
  let row_style : @style.Style = { ..default_style, display: @types.TableRow }
  let table_style : @style.Style = { ..default_style, display: @types.Table }

  let indicator = @node.Node::leaf("div.indicator", indicator_style)
  let scroller = @node.Node::new("div.test", scroller_style, [indicator])
  let cell = @node.Node::new("td", cell_style, [scroller])
  let row = @node.Node::new("tr", row_style, [cell])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 800.0,
    available_height: Some(600.0),
    sizing_mode: @types.Definite,
    viewport_width: 800.0,
    viewport_height: 600.0,
    stretch_width: false,
    stretch_height: false,
  }
  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  let scroller_layout = layout.children[0].children[0].children[0]
  let indicator_layout = scroller_layout.children[0]
  inspect(indicator_layout.x, content="0")
  inspect(indicator_layout.y, content="-24")
}

///|
test "table percent column consumes remaining width after fixed sibling" {
  let percent_cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Percent(1.0),
    height: @types.Length(10.0),
  }
  let fixed_cell_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableCell,
    width: @types.Length(6.0),
    height: @types.Length(10.0),
  }
  let row_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.TableRow,
  }
  let table_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Table,
    width: @types.Length(100.0),
    border_spacing: 0.0,
  }

  let first = @node.Node::new("first", percent_cell_style, [])
  let second = @node.Node::new("second", fixed_cell_style, [])
  let row = @node.Node::new("row", row_style, [first, second])
  let table = @node.Node::new("table", table_style, [row])
  let ctx : @types.LayoutContext = {
    available_width: 100.0,
    available_height: Some(100.0),
    sizing_mode: @types.Definite,
    viewport_width: 100.0,
    viewport_height: 100.0,
    stretch_width: false,
    stretch_height: false,
  }

  @dispatch.setup()
  let layout = @dispatch.compute_layout(table, ctx)
  let row_layout = layout.children[0]
  let first_layout = row_layout.children[0]
  let second_layout = row_layout.children[1]
  inspect(first_layout.width, content="94")
  inspect(second_layout.x, content="94")
  inspect(second_layout.width, content="6")
}
