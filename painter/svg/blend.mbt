// ============================================================================
// Blend Modes (mix-blend-mode / isolation)
// ============================================================================

///|
/// CSS mix-blend-mode values
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  Saturation
  ColorMode // 'color' in CSS
  Luminosity
} derive(Eq, Debug)

///|
pub impl Show for BlendMode with output(self, logger) {
  let name = match self {
    Normal => "Normal"
    Multiply => "Multiply"
    Screen => "Screen"
    Overlay => "Overlay"
    Darken => "Darken"
    Lighten => "Lighten"
    ColorDodge => "ColorDodge"
    ColorBurn => "ColorBurn"
    HardLight => "HardLight"
    SoftLight => "SoftLight"
    Difference => "Difference"
    Exclusion => "Exclusion"
    Hue => "Hue"
    Saturation => "Saturation"
    ColorMode => "ColorMode"
    Luminosity => "Luminosity"
  }
  logger.write_string(name)
}

///|
/// CSS isolation values
pub(all) enum Isolation {
  Auto
  Isolate
} derive(Eq, Debug)

///|
pub impl Show for Isolation with output(self, logger) {
  let name = match self {
    Auto => "Auto"
    Isolate => "Isolate"
  }
  logger.write_string(name)
}

///|
/// Blend two colors using the specified blend mode
pub fn blend_with_mode(
  backdrop : Color,
  source : Color,
  mode : BlendMode,
) -> Color {
  color_from_msvg(
    @msvg.blend_with_mode(
      color_to_msvg(backdrop),
      color_to_msvg(source),
      blend_mode_to_msvg(mode),
    ),
  )
}

///|
/// Blend two images using the specified blend mode
pub fn blend_images(
  backdrop : Image,
  source : Image,
  mode : BlendMode,
) -> Image {
  image_from_msvg(
    @msvg.blend_images(
      image_to_msvg(backdrop),
      image_to_msvg(source),
      blend_mode_to_msvg(mode),
    ),
  )
}
