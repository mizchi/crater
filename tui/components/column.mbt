///|
/// Column - Vertical flex container (like Ink's Box with flexDirection="column")

///|
/// Create a vertical column container
pub fn column(
  children : Array[@tui.Component],
  // Size
  width? : @types.Dimension = @types.Dimension::Auto,
  height? : @types.Dimension = @types.Dimension::Auto,
  min_width? : @types.Dimension = @types.Dimension::Auto,
  min_height? : @types.Dimension = @types.Dimension::Auto,
  max_width? : @types.Dimension = @types.Dimension::Auto,
  max_height? : @types.Dimension = @types.Dimension::Auto,
  // Flex item properties
  flex_grow? : Double = 0.0,
  flex_shrink? : Double = 1.0,
  flex_basis? : @types.Dimension = @types.Dimension::Auto,
  // Alignment
  justify? : @style.Alignment = @style.Alignment::FlexStart,
  align? : @style.Alignment = @style.Alignment::Stretch,
  wrap? : Bool = false,
  gap? : Double = 0.0,
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
  @tui.box(
    children,
    flex_direction=@style.FlexDirection::Column,
    flex_wrap=if wrap { @style.FlexWrap::Wrap } else { @style.FlexWrap::NoWrap },
    width~,
    height~,
    min_width~,
    min_height~,
    max_width~,
    max_height~,
    flex_grow~,
    flex_shrink~,
    flex_basis~,
    justify_content=justify,
    align_items=align,
    gap~,
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
