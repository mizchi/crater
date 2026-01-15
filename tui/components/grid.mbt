///|
/// Grid - CSS Grid-like layout container

///|
/// Grid options
pub(all) struct GridOptions {
  // Size
  width : @types.Dimension
  height : @types.Dimension
  min_width : @types.Dimension
  min_height : @types.Dimension
  max_width : @types.Dimension
  max_height : @types.Dimension
  // Grid configuration
  columns : Int // Number of columns
  rows : Int // Number of rows (0 = auto)
  column_gap : Double
  row_gap : Double
  // Alignment
  justify_items : @style.Alignment
  align_items : @style.Alignment
  // Spacing
  padding : Double
  padding_x : Double
  padding_y : Double
  margin : Double
  margin_x : Double
  margin_y : Double
  // Style
  border : @tui.BorderChars?
  border_color : @tui.Color
  bg : @tui.Color
  fg : @tui.Color
}

///|
pub fn GridOptions::default() -> GridOptions {
  {
    width: @types.Dimension::Auto,
    height: @types.Dimension::Auto,
    min_width: @types.Dimension::Auto,
    min_height: @types.Dimension::Auto,
    max_width: @types.Dimension::Auto,
    max_height: @types.Dimension::Auto,
    columns: 2,
    rows: 0,
    column_gap: 0.0,
    row_gap: 0.0,
    justify_items: @style.Alignment::Stretch,
    align_items: @style.Alignment::Stretch,
    padding: 0.0,
    padding_x: 0.0,
    padding_y: 0.0,
    margin: 0.0,
    margin_x: 0.0,
    margin_y: 0.0,
    border: None,
    border_color: @tui.Color::white(),
    bg: @tui.Color::transparent(),
    fg: @tui.Color::white(),
  }
}

///|
/// Create a grid layout using nested Row/Column
/// This simulates CSS Grid using flexbox
pub fn grid(
  options : GridOptions,
  children : Array[@tui.Component],
) -> @tui.Component {
  let num_columns = if options.columns > 0 { options.columns } else { 2 }
  let rows : Array[@tui.Component] = []

  // Group children into rows
  let mut current_row : Array[@tui.Component] = []
  for i, child in children {
    current_row.push(child)
    if (i + 1) % num_columns == 0 {
      // Complete row - wrap in a Row component
      rows.push(
        row(
          {
            ..RowOptions::default(),
            gap: options.column_gap,
            justify: options.justify_items,
            align: options.align_items,
          },
          current_row,
        ),
      )
      current_row = []
    }
  }

  // Handle remaining children in last incomplete row
  if current_row.length() > 0 {
    rows.push(
      row(
        {
          ..RowOptions::default(),
          gap: options.column_gap,
          justify: options.justify_items,
          align: options.align_items,
        },
        current_row,
      ),
    )
  }

  // Wrap rows in a Column
  column(
    {
      ..ColumnOptions::default(),
      width: options.width,
      height: options.height,
      min_width: options.min_width,
      min_height: options.min_height,
      max_width: options.max_width,
      max_height: options.max_height,
      gap: options.row_gap,
      padding: options.padding,
      padding_x: options.padding_x,
      padding_y: options.padding_y,
      margin: options.margin,
      margin_x: options.margin_x,
      margin_y: options.margin_y,
      border: options.border,
      border_color: options.border_color,
      bg: options.bg,
      fg: options.fg,
    },
    rows,
  )
}

///|
/// Simple grid with specified number of columns
pub fn grid_cols(
  columns : Int,
  children : Array[@tui.Component],
) -> @tui.Component {
  grid({ ..GridOptions::default(), columns, }, children)
}

///|
/// Grid with equal gaps
pub fn grid_gap(
  columns : Int,
  gap : Double,
  children : Array[@tui.Component],
) -> @tui.Component {
  grid(
    { ..GridOptions::default(), columns, column_gap: gap, row_gap: gap },
    children,
  )
}

///|
/// 2-column grid
pub fn grid2(children : Array[@tui.Component]) -> @tui.Component {
  grid_cols(2, children)
}

///|
/// 3-column grid
pub fn grid3(children : Array[@tui.Component]) -> @tui.Component {
  grid_cols(3, children)
}

///|
/// 4-column grid
pub fn grid4(children : Array[@tui.Component]) -> @tui.Component {
  grid_cols(4, children)
}
