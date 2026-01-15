///|
/// Column - Vertical flex container (like Ink's Box with flexDirection="column")

///|
/// Column options for vertical layout
pub(all) struct ColumnOptions {
  // Size
  width : @types.Dimension
  height : @types.Dimension
  min_width : @types.Dimension
  min_height : @types.Dimension
  max_width : @types.Dimension
  max_height : @types.Dimension
  // Flex item properties
  flex_grow : Double
  flex_shrink : Double
  flex_basis : @types.Dimension
  // Alignment
  justify : @style.Alignment // Main axis (vertical)
  align : @style.Alignment // Cross axis (horizontal)
  wrap : Bool
  gap : Double
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
pub fn ColumnOptions::default() -> ColumnOptions {
  {
    width: @types.Dimension::Auto,
    height: @types.Dimension::Auto,
    min_width: @types.Dimension::Auto,
    min_height: @types.Dimension::Auto,
    max_width: @types.Dimension::Auto,
    max_height: @types.Dimension::Auto,
    flex_grow: 0.0,
    flex_shrink: 1.0,
    flex_basis: @types.Dimension::Auto,
    justify: @style.Alignment::FlexStart,
    align: @style.Alignment::Stretch,
    wrap: false,
    gap: 0.0,
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
/// Create a vertical column container
pub fn column(
  options : ColumnOptions,
  children : Array[@tui.Component],
) -> @tui.Component {
  @tui.box_(
    {
      ..@tui.BoxOptions::default(),
      flex_direction: @style.FlexDirection::Column,
      flex_wrap: if options.wrap {
        @style.FlexWrap::Wrap
      } else {
        @style.FlexWrap::NoWrap
      },
      width: options.width,
      height: options.height,
      min_width: options.min_width,
      min_height: options.min_height,
      max_width: options.max_width,
      max_height: options.max_height,
      flex_grow: options.flex_grow,
      flex_shrink: options.flex_shrink,
      flex_basis: options.flex_basis,
      justify_content: options.justify,
      align_items: options.align,
      gap: options.gap,
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
    children,
  )
}

///|
/// Simple column with default options
pub fn column_(children : Array[@tui.Component]) -> @tui.Component {
  column(ColumnOptions::default(), children)
}

///|
/// Column with gap between children
pub fn column_gap(
  gap : Double,
  children : Array[@tui.Component],
) -> @tui.Component {
  column({ ..ColumnOptions::default(), gap, }, children)
}

///|
/// Column with centered content
pub fn column_center(children : Array[@tui.Component]) -> @tui.Component {
  column(
    {
      ..ColumnOptions::default(),
      justify: @style.Alignment::Center,
      align: @style.Alignment::Center,
    },
    children,
  )
}

///|
/// Column with space between children
pub fn column_between(children : Array[@tui.Component]) -> @tui.Component {
  column(
    { ..ColumnOptions::default(), justify: @style.Alignment::SpaceBetween },
    children,
  )
}

///|
/// Column that fills available space
pub fn column_fill(children : Array[@tui.Component]) -> @tui.Component {
  column({ ..ColumnOptions::default(), flex_grow: 1.0 }, children)
}
