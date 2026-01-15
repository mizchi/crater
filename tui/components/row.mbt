///|
/// Row - Horizontal flex container (like Ink's Box with flexDirection="row")

///|
/// Row options for horizontal layout
pub(all) struct RowOptions {
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
  justify : @style.Alignment // Main axis (horizontal)
  align : @style.Alignment // Cross axis (vertical)
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
pub fn RowOptions::default() -> RowOptions {
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
/// Create a horizontal row container
pub fn row(
  options : RowOptions,
  children : Array[@tui.Component],
) -> @tui.Component {
  @tui.box_(
    {
      ..@tui.BoxOptions::default(),
      flex_direction: @style.FlexDirection::Row,
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
/// Simple row with default options
pub fn row_(children : Array[@tui.Component]) -> @tui.Component {
  row(RowOptions::default(), children)
}

///|
/// Row with gap between children
pub fn row_gap(
  gap : Double,
  children : Array[@tui.Component],
) -> @tui.Component {
  row({ ..RowOptions::default(), gap, }, children)
}

///|
/// Row with centered content
pub fn row_center(children : Array[@tui.Component]) -> @tui.Component {
  row(
    {
      ..RowOptions::default(),
      justify: @style.Alignment::Center,
      align: @style.Alignment::Center,
    },
    children,
  )
}

///|
/// Row with space between children
pub fn row_between(children : Array[@tui.Component]) -> @tui.Component {
  row(
    { ..RowOptions::default(), justify: @style.Alignment::SpaceBetween },
    children,
  )
}

///|
/// Row with space around children
pub fn row_around(children : Array[@tui.Component]) -> @tui.Component {
  row(
    { ..RowOptions::default(), justify: @style.Alignment::SpaceAround },
    children,
  )
}

///|
/// Row with evenly distributed children
pub fn row_evenly(children : Array[@tui.Component]) -> @tui.Component {
  row(
    { ..RowOptions::default(), justify: @style.Alignment::SpaceEvenly },
    children,
  )
}
