// =============================================================================
// Grid Layout Tests
// =============================================================================

///|
/// Default dispatch for tests
fn default_dispatch() -> @node.DispatchFn {
  @node.DispatchFn(fn(node, ctx, dispatch) { compute(node, ctx, dispatch) })
}

///|
test "grid_basic" {
  // 120x120 grid container with 3x3 cells of 40px each
  // 9 children should be placed in row-first order
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Check root size
  assert_eq(layout.width, 120.0)
  assert_eq(layout.height, 120.0)

  // Check child positions
  // Row 0: (0,0), (40,0), (80,0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 40.0)
  assert_eq(layout.children[0].height, 40.0)
  assert_eq(layout.children[1].x, 40.0)
  assert_eq(layout.children[1].y, 0.0)
  assert_eq(layout.children[2].x, 80.0)
  assert_eq(layout.children[2].y, 0.0)

  // Row 1: (0,40), (40,40), (80,40)
  assert_eq(layout.children[3].x, 0.0)
  assert_eq(layout.children[3].y, 40.0)
  assert_eq(layout.children[4].x, 40.0)
  assert_eq(layout.children[4].y, 40.0)
  assert_eq(layout.children[5].x, 80.0)
  assert_eq(layout.children[5].y, 40.0)

  // Row 2: (0,80), (40,80), (80,80)
  assert_eq(layout.children[6].x, 0.0)
  assert_eq(layout.children[6].y, 80.0)
  assert_eq(layout.children[7].x, 40.0)
  assert_eq(layout.children[7].y, 80.0)
  assert_eq(layout.children[8].x, 80.0)
  assert_eq(layout.children[8].y, 80.0)
}

///|
test "grid_with_gap" {
  // 100x100 grid with 2x2 cells and 10px gap
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 4; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    row_gap: @types.Length(10.0),
    column_gap: @types.Length(10.0),
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Check child positions with gaps
  // Row 0: (0,0), (50,0)  <- 40 + 10 gap
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[1].x, 50.0)
  assert_eq(layout.children[1].y, 0.0)

  // Row 1: (0,50), (50,50)  <- 40 + 10 gap
  assert_eq(layout.children[2].x, 0.0)
  assert_eq(layout.children[2].y, 50.0)
  assert_eq(layout.children[3].x, 50.0)
  assert_eq(layout.children[3].y, 50.0)
}

///|
test "grid_with_fr_units" {
  // 200px wide grid with 1fr 2fr columns
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 2; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(300.0),
    height: @types.Length(100.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Fr(1.0),
      @types.TrackSizingFunction::Fr(2.0),
    ],
    grid_template_rows: [@types.TrackSizingFunction::Length(100.0)],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // 1fr + 2fr = 3fr total, 300px / 3 = 100px per fr
  // First column: 1fr = 100px, Second column: 2fr = 200px
  assert_eq(layout.children[0].width, 100.0)
  assert_eq(layout.children[1].width, 200.0)
  assert_eq(layout.children[1].x, 100.0)
}

///|
test "grid_align_content_start" {
  // 200x200 grid with 3x3 cells of 40px - content aligned to start
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    align_content: @types.Start,
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // All items should be positioned from (0,0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 40.0)
  assert_eq(layout.children[0].height, 40.0)

  // Last item at (80, 80)
  assert_eq(layout.children[8].x, 80.0)
  assert_eq(layout.children[8].y, 80.0)
}

///|
test "grid_explicit_placement" {
  // Test explicit grid-row/grid-column placement
  let default_style = @style.Style::default()

  // Item placed at row 1 (0-indexed: grid-row: 1 means first row)
  let item0_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
  }

  // Item placed at row 3, column 3
  let item1_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
  }
  let children = [
    @node.Node::leaf("node0", item0_style),
    @node.Node::leaf("node1", item1_style),
  ]
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // node0 at (0, 0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)

  // node1 at (80, 80) - row 3, column 3
  assert_eq(layout.children[1].x, 80.0)
  assert_eq(layout.children[1].y, 80.0)
}

///|
test "grid_span" {
  // Test grid span
  let default_style = @style.Style::default()

  // Item spanning 2 columns
  let item0_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Span(2),
    },
  }
  let children = [@node.Node::leaf("node0", item0_style)]
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(120.0),
    height: @types.Length(40.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [@types.TrackSizingFunction::Length(40.0)],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // node0 should span 2 columns (80px width)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].width, 80.0)
}

///|
test "grid_with_padding" {
  // Grid container with padding
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 4; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    padding: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Children should be offset by padding
  assert_eq(layout.children[0].x, 10.0)
  assert_eq(layout.children[0].y, 10.0)
  assert_eq(layout.children[1].x, 50.0)
  assert_eq(layout.children[1].y, 10.0)
}

// =============================================================================
// Taffy Ported Tests - align_items
// =============================================================================

///|
test "taffy/grid_align_items_sized_center" {
  // align-items: center - items should be vertically centered in their cells
  // node0: 20x20 at row 1, col 1 -> y should be 10 (centered in 40px cell)
  // node1: 60x60 at row 3, col 3 -> y should be 70 (centered at 80 + (40-60)/2 = 70)
  let default_style = @style.Style::default()
  let node0_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let node1_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(60.0),
    height: @types.Length(60.0),
  }
  let children = [
    @node.Node::leaf("node0", node0_style),
    @node.Node::leaf("node1", node1_style),
  ]
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_items: @types.Center,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())
  assert_eq(layout.width, 120.0)
  assert_eq(layout.height, 120.0)

  // node0: 20x20, centered in 40x40 cell -> y = 10
  assert_eq(layout.children[0].width, 20.0)
  assert_eq(layout.children[0].height, 20.0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 10.0)

  // node1: 60x60 at row3/col3, centered -> x=80, y=70 (but height > cell, so positioned differently)
  assert_eq(layout.children[1].width, 60.0)
  assert_eq(layout.children[1].height, 60.0)
  assert_eq(layout.children[1].x, 80.0)
  assert_eq(layout.children[1].y, 70.0)
}

///|
test "taffy/grid_align_items_sized_start" {
  // align-items: start - items should be at the start of their cells
  let default_style = @style.Style::default()
  let node0_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let node1_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(60.0),
    height: @types.Length(60.0),
  }
  let children = [
    @node.Node::leaf("node0", node0_style),
    @node.Node::leaf("node1", node1_style),
  ]
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_items: @types.Start,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // node0: at start -> y = 0
  assert_eq(layout.children[0].y, 0.0)

  // node1: at start of row 3 -> y = 80
  assert_eq(layout.children[1].y, 80.0)
}

///|
test "taffy/grid_align_items_sized_end" {
  // align-items: end - items should be at the end of their cells
  let default_style = @style.Style::default()
  let node0_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(20.0),
    height: @types.Length(20.0),
  }
  let node1_style = {
    ..default_style,
    grid_row: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
    grid_column: {
      start: @types.GridPlacement::Line(3),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(60.0),
    height: @types.Length(60.0),
  }
  let children = [
    @node.Node::leaf("node0", node0_style),
    @node.Node::leaf("node1", node1_style),
  ]
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_items: @types.End,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // node0: 20px height at end of 40px cell -> y = 20
  assert_eq(layout.children[0].y, 20.0)

  // node1: 60px at end of row starting at 80 -> y = 80 + 40 - 60 = 60 (but clipped)
  assert_eq(layout.children[1].y, 60.0)
}

// =============================================================================
// Taffy Ported Tests - auto tracks
// =============================================================================

///|
test "taffy/grid_auto_single_item" {
  // grid-template-columns: 40px auto 40px with one item setting width:100px
  // The auto column should size to 100px based on item content
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    let style = if i == 1 {
      { ..default_style, width: @types.Length(100.0) }
    } else {
      default_style
    }
    children.push(@node.Node::leaf("node\{i}", style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Auto,
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Container should be 180px wide (40 + 100 + 40)
  assert_eq(layout.width, 180.0)
  assert_eq(layout.height, 120.0)

  // node0: first column, 40px wide
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].width, 40.0)

  // node1: second column (auto), 100px wide
  assert_eq(layout.children[1].x, 40.0)
  assert_eq(layout.children[1].width, 100.0)

  // node2: third column, 40px wide at x=140
  assert_eq(layout.children[2].x, 140.0)
  assert_eq(layout.children[2].width, 40.0)
}

///|
test "taffy/grid_auto_columns" {
  // grid-auto-columns: 10px 20px 30px - repeating pattern for implicit columns
  // grid-auto-flow: column
  let default_style = @style.Style::default()
  let node0_style = {
    ..default_style,
    grid_column: {
      start: @types.GridPlacement::Line(-3),
      end: @types.GridPlacement::Auto,
    },
  }
  let children : Array[@node.Node] = []
  children.push(@node.Node::leaf("node0", node0_style))
  for i = 1; i < 8; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    grid_template_rows: [@types.TrackSizingFunction::Length(100.0)],
    grid_template_columns: [@types.TrackSizingFunction::Length(40.0)],
    grid_auto_columns: [
      @types.TrackSizingFunction::Length(10.0),
      @types.TrackSizingFunction::Length(20.0),
      @types.TrackSizingFunction::Length(30.0),
    ],
    grid_auto_flow: @types.Column,
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Container: 190px wide (30 + 40 + 10 + 20 + 30 + 10 + 20 + 30)
  assert_eq(layout.width, 190.0)
  assert_eq(layout.height, 100.0)

  // node0: implicit column before explicit, width = 30
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].width, 30.0)

  // node1: explicit column, width = 40
  assert_eq(layout.children[1].x, 30.0)
  assert_eq(layout.children[1].width, 40.0)

  // node2: first implicit after explicit, width = 10
  assert_eq(layout.children[2].x, 70.0)
  assert_eq(layout.children[2].width, 10.0)
}

// =============================================================================
// Taffy Ported Tests - align_content
// =============================================================================

///|
test "taffy/grid_align_content_center" {
  // align-content: center - grid tracks centered vertically
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_content: @types.Center,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Total track height = 120, container = 200, offset = (200-120)/2 = 40
  // First row should start at y = 40
  assert_eq(layout.children[0].y, 40.0)
  assert_eq(layout.children[3].y, 80.0)
  assert_eq(layout.children[6].y, 120.0)
}

///|
test "taffy/grid_align_content_space_between" {
  // align-content: space-between - tracks spread with space between
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_content: @types.SpaceBetween,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // space-between: first row at 0, last row at 200-40=160
  // gap = (200 - 120) / 2 = 40
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[3].y, 80.0)
  assert_eq(layout.children[6].y, 160.0)
}

///|
test "taffy/grid_align_content_space_around" {
  // align-content: space-around - equal space around each track
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_content: @types.SpaceAround,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // space-around: 80px free space / 3 = 26.67 per track side
  // Positions approximately: 13.33, 66.67, 120
  // Using approximate values
  inspect(layout.children[0].y, content="13.333333333333334")
}

///|
test "taffy/grid_align_content_space_evenly" {
  // align-content: space-evenly - equal space everywhere
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_content: @types.SpaceEvenly,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // space-evenly: 80px free space / 4 gaps = 20px each
  // Positions: 20, 80, 140
  assert_eq(layout.children[0].y, 20.0)
  assert_eq(layout.children[3].y, 80.0)
  assert_eq(layout.children[6].y, 140.0)
}

///|
test "taffy/grid_align_content_end" {
  // align-content: end - tracks at the end
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    align_content: @types.End,
    width: @types.Length(200.0),
    height: @types.Length(200.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Tracks at end: offset = 200 - 120 = 80
  assert_eq(layout.children[0].y, 80.0)
  assert_eq(layout.children[3].y, 120.0)
  assert_eq(layout.children[6].y, 160.0)
}

// =============================================================================
// Taffy Ported Tests - justify_content
// =============================================================================

///|
test "taffy/grid_justify_content_center" {
  // justify-content: center - grid tracks centered horizontally
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    justify_content: @types.Center,
    width: @types.Length(200.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Total track width = 120, container = 200, offset = (200-120)/2 = 40
  assert_eq(layout.children[0].x, 40.0)
  assert_eq(layout.children[1].x, 80.0)
  assert_eq(layout.children[2].x, 120.0)
}

///|
test "taffy/grid_justify_content_end" {
  // justify-content: end - tracks at the end
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    justify_content: @types.End,
    width: @types.Length(200.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // offset = 200 - 120 = 80
  assert_eq(layout.children[0].x, 80.0)
  assert_eq(layout.children[1].x, 120.0)
  assert_eq(layout.children[2].x, 160.0)
}

// =============================================================================
// Taffy Ported Tests - gap
// =============================================================================

///|
test "taffy/grid_gap" {
  // row-gap and column-gap
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 4; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    row_gap: @types.Length(20.0),
    column_gap: @types.Length(20.0),
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // With 20px gaps: (0,0), (60,0), (0,60), (60,60)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[1].x, 60.0)
  assert_eq(layout.children[1].y, 0.0)
  assert_eq(layout.children[2].x, 0.0)
  assert_eq(layout.children[2].y, 60.0)
  assert_eq(layout.children[3].x, 60.0)
  assert_eq(layout.children[3].y, 60.0)
}

// =============================================================================
// Taffy Ported Tests - minmax
// =============================================================================

///|
test "taffy/grid_minmax_column_fixed_width_within_range" {
  // grid-template-columns: 40px minmax(20px, 40px) 40px
  // Container width: 110px -> minmax column gets 30px (within range)
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(110.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.MinMax(
        @types.MinTrackSizing::Length(20.0),
        @types.MaxTrackSizing::Length(40.0),
      ),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Container: 110x120
  assert_eq(layout.width, 110.0)
  assert_eq(layout.height, 120.0)

  // Row 1: widths 40, 30, 40
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].width, 40.0)
  assert_eq(layout.children[1].x, 40.0)
  assert_eq(layout.children[1].width, 30.0)
  assert_eq(layout.children[2].x, 70.0)
  assert_eq(layout.children[2].width, 40.0)
}

///|
test "taffy/grid_minmax_column_fixed_width_above_range" {
  // grid-template-columns: 40px minmax(20px, 40px) 40px
  // Container width: 140px -> minmax column gets 40px (max)
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(140.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.MinMax(
        @types.MinTrackSizing::Length(20.0),
        @types.MaxTrackSizing::Length(40.0),
      ),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Container: 140x120
  assert_eq(layout.width, 140.0)
  assert_eq(layout.height, 120.0)

  // Row 1: widths 40, 40, 40 (minmax at max)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].width, 40.0)
  assert_eq(layout.children[1].x, 40.0)
  assert_eq(layout.children[1].width, 40.0)
  assert_eq(layout.children[2].x, 80.0)
  assert_eq(layout.children[2].width, 40.0)
}

///|
test "taffy/grid_minmax_column_fixed_width_below_range" {
  // grid-template-columns: 40px minmax(20px, 40px) 40px
  // Container width: 90px -> minmax column gets 20px (min, but needs to shrink to 10px to fit)
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(90.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.MinMax(
        @types.MinTrackSizing::Length(20.0),
        @types.MaxTrackSizing::Length(40.0),
      ),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Container: 90x120
  assert_eq(layout.width, 90.0)
  assert_eq(layout.height, 120.0)

  // Row 1: widths 40, 20, 40 (minmax should not go below min, even if container is too small)
  // Taffy respects minmax minimum - it's the min, not the max that bounds
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].width, 40.0)
  assert_eq(layout.children[1].x, 40.0)
  assert_eq(layout.children[1].width, 20.0)
  assert_eq(layout.children[2].x, 60.0)
  assert_eq(layout.children[2].width, 40.0)
}

///|
test "grid_minmax_min_content_auto_track" {
  let default_style = @style.Style::default()
  let text_measure : @types.MeasureFunc = {
    func: fn(_w : Double, _h : Double) -> @types.IntrinsicSize {
      { min_width: 72.0, max_width: 216.0, min_height: 16.0, max_height: 16.0 }
    },
  }
  let text = @node.Node::with_measure("text", default_style, text_measure)
  let block_child = @node.Node::new("block", default_style, [text])
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(800.0),
    grid_template_columns: [
      @types.MinMax(
        @types.MinTrackSizing::MinContent,
        @types.MaxTrackSizing::Length(100.0),
      ),
      @types.TrackSizingFunction::Auto,
    ],
  }
  let root = @node.Node::new("root", root_style, [block_child])
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())
  assert_eq(layout.children[0].width, 100.0)
}

// =============================================================================
// Taffy Ported Tests - span
// =============================================================================

///|
test "taffy/grid_fr_span_2_proportion" {
  // node0: spans 2 columns with width 60px
  // grid-template-columns: 1fr 2fr -> should be 20px 40px based on spanned item
  let default_style = @style.Style::default()
  let node0 = @node.Node::leaf("node0", {
    ..default_style,
    grid_column: {
      start: @types.GridPlacement::Span(2),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(60.0),
  })
  let node1 = @node.Node::leaf("node1", default_style)
  let node2 = @node.Node::leaf("node2", default_style)
  let root_style = {
    ..default_style,
    display: @types.Grid,
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_columns: [
      @types.TrackSizingFunction::Fr(1.0),
      @types.TrackSizingFunction::Fr(2.0),
    ],
  }
  let root = @node.Node::new("root", root_style, [node0, node1, node2])
  // Use a width that matches the content - 60px from spanned item
  let layout = compute_grid_layout(root, 60.0, 600.0, default_dispatch())

  // Container: 60x80
  assert_eq(layout.width, 60.0)
  assert_eq(layout.height, 80.0)

  // node0: spans 2 cols, width 60, height 40 at (0,0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 60.0)
  assert_eq(layout.children[0].height, 40.0)

  // node1: col 1 (1fr = 20px), row 2, at (0, 40)
  assert_eq(layout.children[1].x, 0.0)
  assert_eq(layout.children[1].y, 40.0)
  assert_eq(layout.children[1].width, 20.0)
  assert_eq(layout.children[1].height, 40.0)

  // node2: col 2 (2fr = 40px), row 2, at (20, 40)
  assert_eq(layout.children[2].x, 20.0)
  assert_eq(layout.children[2].y, 40.0)
  assert_eq(layout.children[2].width, 40.0)
  assert_eq(layout.children[2].height, 40.0)
}

///|
test "taffy/grid_fr_span_2_proportion_with_non_spanned_track" {
  // node0: spans 2 columns with width 60px
  // node1: in 3rd column (row 1)
  // node2, node3, node4: row 2 columns 1, 2, 3
  // grid-template-columns: 1fr 2fr 3fr -> 20px 40px 60px = 120px total
  let default_style = @style.Style::default()
  let node0 = @node.Node::leaf("node0", {
    ..default_style,
    grid_column: {
      start: @types.GridPlacement::Span(2),
      end: @types.GridPlacement::Auto,
    },
    width: @types.Length(60.0),
  })
  let node1 = @node.Node::leaf("node1", default_style)
  let node2 = @node.Node::leaf("node2", default_style)
  let node3 = @node.Node::leaf("node3", default_style)
  let node4 = @node.Node::leaf("node4", default_style)
  let root_style = {
    ..default_style,
    display: @types.Grid,
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_columns: [
      @types.TrackSizingFunction::Fr(1.0),
      @types.TrackSizingFunction::Fr(2.0),
      @types.TrackSizingFunction::Fr(3.0),
    ],
  }
  let root = @node.Node::new("root", root_style, [
    node0, node1, node2, node3, node4,
  ])
  let layout = compute_grid_layout(root, 120.0, 600.0, default_dispatch())

  // Container: 120x80
  assert_eq(layout.width, 120.0)
  assert_eq(layout.height, 80.0)

  // node0: spans cols 1-2, width 60, height 40 at (0,0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 60.0)
  assert_eq(layout.children[0].height, 40.0)

  // node1: col 3 (3fr = 60px), row 1, at (60, 0)
  assert_eq(layout.children[1].x, 60.0)
  assert_eq(layout.children[1].y, 0.0)
  assert_eq(layout.children[1].width, 60.0)
  assert_eq(layout.children[1].height, 40.0)

  // node2: col 1 (1fr = 20px), row 2, at (0, 40)
  assert_eq(layout.children[2].x, 0.0)
  assert_eq(layout.children[2].y, 40.0)
  assert_eq(layout.children[2].width, 20.0)
  assert_eq(layout.children[2].height, 40.0)

  // node3: col 2 (2fr = 40px), row 2, at (20, 40)
  assert_eq(layout.children[3].x, 20.0)
  assert_eq(layout.children[3].y, 40.0)
  assert_eq(layout.children[3].width, 40.0)
  assert_eq(layout.children[3].height, 40.0)

  // node4: col 3 (3fr = 60px), row 2, at (60, 40)
  assert_eq(layout.children[4].x, 60.0)
  assert_eq(layout.children[4].y, 40.0)
  assert_eq(layout.children[4].width, 60.0)
  assert_eq(layout.children[4].height, 40.0)
}

// =============================================================================
// Taffy Ported Tests - aspect-ratio
// =============================================================================

///|
test "taffy/grid_aspect_ratio_fill_child_height" {
  // Child has width=50, height=auto, aspect_ratio=2
  // height = width / aspect_ratio = 50 / 2 = 25
  let default_style = @style.Style::default()
  let node0 = @node.Node::leaf("node0", {
    ..default_style,
    width: @types.Length(50.0),
    aspect_ratio: Some(2.0),
  })
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [node0])
  let layout = compute_grid_layout(root, 200.0, 200.0, default_dispatch())

  // Container: 100x100
  assert_eq(layout.width, 100.0)
  assert_eq(layout.height, 100.0)

  // Child: 50x25 at (0,0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 50.0)
  assert_eq(layout.children[0].height, 25.0)
}

///|
test "taffy/grid_aspect_ratio_fill_child_width" {
  // Child has width=auto, height=40, aspect_ratio=2
  // width = height * aspect_ratio = 40 * 2 = 80
  let default_style = @style.Style::default()
  let node0 = @node.Node::leaf("node0", {
    ..default_style,
    height: @types.Length(40.0),
    aspect_ratio: Some(2.0),
  })
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(100.0),
    height: @types.Length(100.0),
  }
  let root = @node.Node::new("root", root_style, [node0])
  let layout = compute_grid_layout(root, 200.0, 200.0, default_dispatch())

  // Container: 100x100
  assert_eq(layout.width, 100.0)
  assert_eq(layout.height, 100.0)

  // Child: 80x40 at (0,0)
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 80.0)
  assert_eq(layout.children[0].height, 40.0)
}

// =============================================================================
// Taffy Ported Tests - repeat
// =============================================================================

///|
test "grid_repeat_count" {
  // repeat(3, 40px) = 40px 40px 40px
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 3; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(120.0),
    height: @types.Length(40.0),
    grid_template_columns: [
      @types.Repeat(@types.Count(3), [@types.SingleTrackSizing::Length(40.0)]),
    ],
    grid_template_rows: [@types.TrackSizingFunction::Length(40.0)],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 200.0, 200.0, default_dispatch())

  // Container: 120x40
  assert_eq(layout.width, 120.0)
  assert_eq(layout.height, 40.0)

  // 3 children in a row, each 40x40
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].width, 40.0)
  assert_eq(layout.children[1].x, 40.0)
  assert_eq(layout.children[1].width, 40.0)
  assert_eq(layout.children[2].x, 80.0)
  assert_eq(layout.children[2].width, 40.0)
}

///|
test "taffy/grid_auto_fill_fixed_size" {
  // grid-template-columns: 40px repeat(auto-fill, 40px)
  // Container 120px: 40px + auto-fill -> 40px 40px 40px (3 columns)
  let default_style = @style.Style::default()
  let children : Array[@node.Node] = []
  for i = 0; i < 9; i = i + 1 {
    children.push(@node.Node::leaf("node\{i}", default_style))
  }
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(120.0),
    height: @types.Length(120.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(40.0),
      @types.Repeat(@types.AutoFill, [@types.SingleTrackSizing::Length(40.0)]),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 200.0, 200.0, default_dispatch())

  // Container: 120x120
  assert_eq(layout.width, 120.0)
  assert_eq(layout.height, 120.0)

  // 3x3 grid, each cell 40x40
  // Row 1
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 40.0)
  assert_eq(layout.children[1].x, 40.0)
  assert_eq(layout.children[1].y, 0.0)
  assert_eq(layout.children[2].x, 80.0)
  assert_eq(layout.children[2].y, 0.0)
  // Row 2
  assert_eq(layout.children[3].x, 0.0)
  assert_eq(layout.children[3].y, 40.0)
  assert_eq(layout.children[4].x, 40.0)
  assert_eq(layout.children[4].y, 40.0)
  assert_eq(layout.children[5].x, 80.0)
  assert_eq(layout.children[5].y, 40.0)
  // Row 3
  assert_eq(layout.children[6].x, 0.0)
  assert_eq(layout.children[6].y, 80.0)
  assert_eq(layout.children[7].x, 40.0)
  assert_eq(layout.children[7].y, 80.0)
  assert_eq(layout.children[8].x, 80.0)
  assert_eq(layout.children[8].y, 80.0)
}

///|
test "grid_template_areas_basic" {
  let default_style = @style.Style::default()

  // Create children with grid-area names
  let header_style = { ..default_style, grid_area: Some("header") }
  let sidebar_style = { ..default_style, grid_area: Some("sidebar") }
  let main_style = { ..default_style, grid_area: Some("main") }
  let footer_style = { ..default_style, grid_area: Some("footer") }
  let children : Array[@node.Node] = [
    @node.Node::leaf("header", header_style),
    @node.Node::leaf("sidebar", sidebar_style),
    @node.Node::leaf("main", main_style),
    @node.Node::leaf("footer", footer_style),
  ]

  // Classic "holy grail" layout:
  // "header  header"
  // "sidebar main"
  // "footer  footer"
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(200.0),
    height: @types.Length(150.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Length(60.0),
      @types.TrackSizingFunction::Length(140.0),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Length(40.0),
      @types.TrackSizingFunction::Length(70.0),
      @types.TrackSizingFunction::Length(40.0),
    ],
    grid_template_areas: ["header header", "sidebar main", "footer footer"],
  }
  let root = @node.Node::new("root", root_style, children)
  let layout = compute_grid_layout(root, 200.0, 200.0, default_dispatch())

  // Container size
  assert_eq(layout.width, 200.0)
  assert_eq(layout.height, 150.0)

  // Header: spans columns 1-2, row 1
  // x=0, y=0, width=200 (60+140), height=40
  assert_eq(layout.children[0].x, 0.0)
  assert_eq(layout.children[0].y, 0.0)
  assert_eq(layout.children[0].width, 200.0)
  assert_eq(layout.children[0].height, 40.0)

  // Sidebar: column 1, row 2
  // x=0, y=40, width=60, height=70
  assert_eq(layout.children[1].x, 0.0)
  assert_eq(layout.children[1].y, 40.0)
  assert_eq(layout.children[1].width, 60.0)
  assert_eq(layout.children[1].height, 70.0)

  // Main: column 2, row 2
  // x=60, y=40, width=140, height=70
  assert_eq(layout.children[2].x, 60.0)
  assert_eq(layout.children[2].y, 40.0)
  assert_eq(layout.children[2].width, 140.0)
  assert_eq(layout.children[2].height, 70.0)

  // Footer: spans columns 1-2, row 3
  // x=0, y=110, width=200, height=40
  assert_eq(layout.children[3].x, 0.0)
  assert_eq(layout.children[3].y, 110.0)
  assert_eq(layout.children[3].width, 200.0)
  assert_eq(layout.children[3].height, 40.0)
}

// =============================================================================
// Measure Function Tests
// =============================================================================

///|
test "grid_measure_function_basic" {
  // Test that custom measure function is used for intrinsic sizing
  let default_style = @style.Style::default()

  // Create a measure function that returns custom sizes
  let custom_measure : @types.MeasureFunc = {
    func: fn(_available_width, _available_height) {
      { min_width: 50.0, max_width: 100.0, min_height: 25.0, max_height: 50.0 }
    },
  }

  // Create a leaf node with the custom measure function
  let child = @node.Node::with_measure(
    "measured", default_style, custom_measure,
  )
  let root_style = {
    ..default_style,
    display: @types.Grid,
    grid_template_columns: [@types.TrackSizingFunction::MaxContent],
    grid_template_rows: [@types.TrackSizingFunction::MaxContent],
  }
  let root = @node.Node::new("root", root_style, [child])
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Container should size to max-content of the measured child
  assert_eq(layout.width, 100.0)
  assert_eq(layout.height, 50.0)

  // Child should fill the grid cell
  assert_eq(layout.children[0].width, 100.0)
  assert_eq(layout.children[0].height, 50.0)
}

///|
test "grid_measure_function_min_content" {
  // Test that min-content uses min_width from measure function
  let default_style = @style.Style::default()
  let custom_measure : @types.MeasureFunc = {
    func: fn(_available_width, _available_height) {
      { min_width: 30.0, max_width: 80.0, min_height: 15.0, max_height: 40.0 }
    },
  }
  let child = @node.Node::with_measure(
    "measured", default_style, custom_measure,
  )
  let root_style = {
    ..default_style,
    display: @types.Grid,
    grid_template_columns: [@types.TrackSizingFunction::MinContent],
    grid_template_rows: [@types.TrackSizingFunction::MinContent],
  }
  let root = @node.Node::new("root", root_style, [child])
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Container should size to min-content of the measured child
  assert_eq(layout.width, 30.0)
  assert_eq(layout.height, 15.0)
}

///|
test "grid_min_content_spanning_fr" {
  // Grid with 1fr 30px, width: min-content
  // Spanning item should have width = 0 + 30 = 30 (fr track = 0 for min-content)
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.MinContent,
    border: {
      left: @types.Length(10.0),
      right: @types.Length(10.0),
      top: @types.Length(10.0),
      bottom: @types.Length(10.0),
    },
    grid_template_columns: [
      @types.TrackSizingFunction::Fr(1.0),
      @types.TrackSizingFunction::Length(30.0),
    ],
  }

  // Spanning item: grid-column: 1 / span 2
  let item_style = {
    ..default_style,
    grid_column: {
      start: @types.GridPlacement::Line(1),
      end: @types.GridPlacement::Span(2),
    },
  }

  // Filler inside item (300px wide)
  let filler_style = {
    ..default_style,
    width: @types.Length(300.0),
    height: @types.Length(50.0),
  }
  let filler = @node.Node::leaf("filler", filler_style)
  let item = @node.Node::new("item", item_style, [filler])
  let root = @node.Node::new("root", root_style, [item])
  let layout = compute_grid_layout(root, 800.0, 600.0, default_dispatch())

  // Expected: root width = 30 (tracks) + 20 (border) = 50
  // Expected: item width = 30 (spanning 1fr + 30px, where 1fr = 0)
  assert_eq(layout.width, 50.0)
  assert_eq(layout.children[0].width, 30.0)
}

///|
test "grid_fr_sum_less_than_one" {
  // CSS Grid spec: when fr sum < 1, tracks don't exhaust remaining space
  // grid-template-columns: 0.25fr 0.25fr (sum = 0.5)
  // Each 0.25fr should get 25% of available space, not 50%
  // Use align-content/justify-content: Start to prevent stretch distribution
  let default_style = @style.Style::default()
  let root_style = {
    ..default_style,
    display: @types.Grid,
    width: @types.Length(200.0),
    height: @types.Length(300.0),
    grid_template_columns: [
      @types.TrackSizingFunction::Fr(0.25),
      @types.TrackSizingFunction::Fr(0.25),
    ],
    grid_template_rows: [
      @types.TrackSizingFunction::Fr(0.2),
      @types.TrackSizingFunction::Fr(0.3),
    ],
    align_content: @types.Start,
    justify_content: @types.Start,
  } // Prevent stretch distribution
  // Prevent stretch distribution
  let item1 = @node.Node::leaf("item1", default_style)
  let item2 = @node.Node::leaf("item2", default_style)
  let item3 = @node.Node::leaf("item3", default_style)
  let item4 = @node.Node::leaf("item4", default_style)
  let root = @node.Node::new("root", root_style, [item1, item2, item3, item4])
  let ctx : @types.LayoutContext = {
    available_width: 200.0,
    available_height: Some(300.0),
    sizing_mode: @types.Definite,
    viewport_width: 400.0,
    viewport_height: 400.0,
  }
  let layout = compute(root, ctx, default_dispatch())

  // Column widths: 0.25fr + 0.25fr = 0.5, but sum < 1 so use 1.0
  // Each 0.25fr = 0.25 * 200 = 50
  assert_eq(layout.children[0].width, 50.0) // item1 (col 1, 0.25fr)
  assert_eq(layout.children[1].width, 50.0) // item2 (col 2, 0.25fr)

  // Row heights: 0.2fr + 0.3fr = 0.5, but sum < 1 so use 1.0
  // 0.2fr = 0.2 * 300 = 60
  // 0.3fr = 0.3 * 300 = 90
  assert_eq(layout.children[0].height, 60.0) // item1 (row 1, 0.2fr)
  assert_eq(layout.children[2].height, 90.0) // item3 (row 2, 0.3fr)
}
