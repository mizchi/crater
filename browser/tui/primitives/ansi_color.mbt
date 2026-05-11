///|
/// ANSI color adapters for crater paint colors.

///|
/// Convert RGB color to 256-color palette index.
pub fn rgb_to_256(r : Int, g : Int, b : Int) -> Int {
  @tui_ansi.rgb_to_256(r, g, b)
}

///|
/// Convert Color to 256-color palette index.
pub fn color_to_256(color : @types.Color) -> Int {
  rgb_to_256(color.r, color.g, color.b)
}

///|
/// Set foreground color from Color type.
pub fn ansi_fg_color(color : @types.Color) -> String {
  ansi_fg_256(color_to_256(color))
}

///|
/// Set background color from Color type.
pub fn ansi_bg_color(color : @types.Color) -> String {
  ansi_bg_256(color_to_256(color))
}
