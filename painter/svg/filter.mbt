// ============================================================================
// Filter Effects
// ============================================================================

///|
/// Filter types
pub(all) enum Filter {
  Blur(Double) // Blur radius
  DropShadow(Double, Double, Double, Color) // offsetX, offsetY, blur, color
  Brightness(Double) // Factor (1.0 = normal)
  Contrast(Double) // Factor (1.0 = normal)
  Grayscale(Double) // Amount (0.0-1.0)
  Sepia(Double) // Amount (0.0-1.0)
  HueRotate(Double) // Angle in degrees
  Invert(Double) // Amount (0.0-1.0)
  Saturate(Double) // Factor (1.0 = normal, 0.0 = grayscale, 2.0 = double)
  ColorMatrix(FixedArray[Double]) // 5x4 matrix (20 values) for feColorMatrix
}

///|
/// Apply blur filter to a region of pixels
pub fn apply_blur(
  pixels : Array[Array[Color]],
  radius : Int,
) -> Array[Array[Color]] {
  @msvg.apply_blur(
      pixels.map(fn(row) { row.map(fn(c) { c.to_msvg() }) }),
      radius,
    )
    .map(fn(row) { row.map(Color::from_msvg) })
}

///|
/// Apply brightness filter to a color
pub fn apply_brightness(color : Color, factor : Double) -> Color {
  Color::from_msvg(@msvg.apply_brightness(color.to_msvg(), factor))
}

///|
/// Apply grayscale filter to a color
pub fn apply_grayscale(color : Color, amount : Double) -> Color {
  Color::from_msvg(@msvg.apply_grayscale(color.to_msvg(), amount))
}

///|
/// Apply contrast filter to a color
pub fn apply_contrast(color : Color, factor : Double) -> Color {
  Color::from_msvg(@msvg.apply_contrast(color.to_msvg(), factor))
}

///|
/// Apply sepia filter to a color
pub fn apply_sepia(color : Color, amount : Double) -> Color {
  Color::from_msvg(@msvg.apply_sepia(color.to_msvg(), amount))
}

///|
/// Apply hue rotation to a color
pub fn apply_hue_rotate(color : Color, angle_degrees : Double) -> Color {
  Color::from_msvg(@msvg.apply_hue_rotate(color.to_msvg(), angle_degrees))
}

///|
/// Apply invert filter to a color
pub fn apply_invert(color : Color, amount : Double) -> Color {
  Color::from_msvg(@msvg.apply_invert(color.to_msvg(), amount))
}

///|
/// Apply saturate filter to a color
pub fn apply_saturate(color : Color, factor : Double) -> Color {
  Color::from_msvg(@msvg.apply_saturate(color.to_msvg(), factor))
}

///|
/// Apply color matrix filter (feColorMatrix)
/// Matrix is 5x4 (20 values) in row-major order:
/// [R'] = [a00 a01 a02 a03 a04] [R]
/// [G'] = [a10 a11 a12 a13 a14] [G]
/// [B'] = [a20 a21 a22 a23 a24] [B]
/// [A'] = [a30 a31 a32 a33 a34] [A]
///                              [1]
pub fn apply_color_matrix(color : Color, matrix : FixedArray[Double]) -> Color {
  Color::from_msvg(@msvg.apply_color_matrix(color.to_msvg(), matrix))
}

///|
/// Create identity color matrix
pub fn identity_matrix() -> FixedArray[Double] {
  @msvg.identity_matrix()
}

///|
/// Create saturate color matrix
pub fn saturate_matrix(factor : Double) -> FixedArray[Double] {
  @msvg.saturate_matrix(factor)
}

///|
/// Create hue-rotate color matrix
pub fn hue_rotate_matrix(angle_degrees : Double) -> FixedArray[Double] {
  @msvg.hue_rotate_matrix(angle_degrees)
}

///|
/// Create luminance-to-alpha color matrix
pub fn luminance_to_alpha_matrix() -> FixedArray[Double] {
  @msvg.luminance_to_alpha_matrix()
}

///|
/// Apply drop shadow to an image and return new image with shadow
pub fn apply_drop_shadow(
  image : Image,
  offset_x : Int,
  offset_y : Int,
  blur_radius : Int,
  shadow_color : Color,
) -> Image {
  Image::from_msvg(
    @msvg.apply_drop_shadow(
      image.to_msvg(),
      offset_x,
      offset_y,
      blur_radius,
      shadow_color.to_msvg(),
    ),
  )
}

///|
/// Apply a filter to an image (returns new image)
pub fn apply_filter(image : Image, filter : Filter) -> Image {
  Image::from_msvg(
    @msvg.apply_filter(image.to_msvg(), filter.to_msvg()),
  )
}

///|
fn Filter::from_msvg(filter : @msvg.Filter) -> Filter {
  match filter {
    Blur(value) => Blur(value)
    DropShadow(dx, dy, blur, color) =>
      DropShadow(dx, dy, blur, Color::from_msvg(color))
    Brightness(value) => Brightness(value)
    Contrast(value) => Contrast(value)
    Grayscale(value) => Grayscale(value)
    Sepia(value) => Sepia(value)
    HueRotate(value) => HueRotate(value)
    Invert(value) => Invert(value)
    Saturate(value) => Saturate(value)
    ColorMatrix(values) => ColorMatrix(values)
  }
}

///|
fn Filter::to_msvg(self : Filter) -> @msvg.Filter {
  match self {
    Blur(value) => @msvg.Filter::Blur(value)
    DropShadow(dx, dy, blur, color) =>
      @msvg.Filter::DropShadow(dx, dy, blur, color.to_msvg())
    Brightness(value) => @msvg.Filter::Brightness(value)
    Contrast(value) => @msvg.Filter::Contrast(value)
    Grayscale(value) => @msvg.Filter::Grayscale(value)
    Sepia(value) => @msvg.Filter::Sepia(value)
    HueRotate(value) => @msvg.Filter::HueRotate(value)
    Invert(value) => @msvg.Filter::Invert(value)
    Saturate(value) => @msvg.Filter::Saturate(value)
    ColorMatrix(values) => @msvg.Filter::ColorMatrix(values)
  }
}
