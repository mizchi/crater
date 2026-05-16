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
  Color::from_msvg(
    @msvg.blend_with_mode(
      backdrop.to_msvg(),
      source.to_msvg(),
      mode.to_msvg(),
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
  Image::from_msvg(
    @msvg.blend_images(
      backdrop.to_msvg(),
      source.to_msvg(),
      mode.to_msvg(),
    ),
  )
}

///|
fn BlendMode::to_msvg(self : BlendMode) -> @msvg.BlendMode {
  match self {
    Normal => @msvg.BlendMode::Normal
    Multiply => @msvg.BlendMode::Multiply
    Screen => @msvg.BlendMode::Screen
    Overlay => @msvg.BlendMode::Overlay
    Darken => @msvg.BlendMode::Darken
    Lighten => @msvg.BlendMode::Lighten
    ColorDodge => @msvg.BlendMode::ColorDodge
    ColorBurn => @msvg.BlendMode::ColorBurn
    HardLight => @msvg.BlendMode::HardLight
    SoftLight => @msvg.BlendMode::SoftLight
    Difference => @msvg.BlendMode::Difference
    Exclusion => @msvg.BlendMode::Exclusion
    Hue => @msvg.BlendMode::Hue
    Saturation => @msvg.BlendMode::Saturation
    ColorMode => @msvg.BlendMode::ColorMode
    Luminosity => @msvg.BlendMode::Luminosity
  }
}
