///|
/// Grid - CSS Grid-like layout container

///|
/// Create a grid layout using nested Row/Column
/// This simulates CSS Grid using flexbox
pub fn grid(
  children : Array[@tui.Component],
  // Grid configuration
  columns? : Int = 2,
  column_gap? : Double = 0.0,
  row_gap? : Double = 0.0,
  // Size
  width? : @types.Dimension = @types.Dimension::Auto,
  height? : @types.Dimension = @types.Dimension::Auto,
  min_width? : @types.Dimension = @types.Dimension::Auto,
  min_height? : @types.Dimension = @types.Dimension::Auto,
  max_width? : @types.Dimension = @types.Dimension::Auto,
  max_height? : @types.Dimension = @types.Dimension::Auto,
  // Alignment
  justify_items? : @style.Alignment = @style.Alignment::Stretch,
  align_items? : @style.Alignment = @style.Alignment::Stretch,
  // Spacing
  padding? : Double = 0.0,
  padding_x? : Double = 0.0,
  padding_y? : Double = 0.0,
  margin? : Double = 0.0,
  margin_x? : Double = 0.0,
  margin_y? : Double = 0.0,
  // Style
  border? : @tui.BorderChars? = None,
  border_color? : @tui.Color = @tui.Color::white(),
  bg? : @tui.Color = @tui.Color::transparent(),
  fg? : @tui.Color = @tui.Color::white(),
) -> @tui.Component {
  let num_columns = if columns > 0 { columns } else { 2 }
  let rows : Array[@tui.Component] = []

  // Group children into rows
  let mut current_row : Array[@tui.Component] = []
  for i, child in children {
    current_row.push(child)
    if (i + 1) % num_columns == 0 {
      // Complete row - wrap in a Row component
      rows.push(
        row(
          current_row,
          gap=column_gap,
          justify=justify_items,
          align=align_items,
        ),
      )
      current_row = []
    }
  }

  // Handle remaining children in last incomplete row
  if current_row.length() > 0 {
    rows.push(
      row(current_row, gap=column_gap, justify=justify_items, align=align_items),
    )
  }

  // Wrap rows in a Column
  column(
    rows,
    width~,
    height~,
    min_width~,
    min_height~,
    max_width~,
    max_height~,
    gap=row_gap,
    padding~,
    padding_x~,
    padding_y~,
    margin~,
    margin_x~,
    margin_y~,
    border~,
    border_color~,
    bg~,
    fg~,
  )
}
