///|
/// Dynamic color palette that builds from PaintNode colors
pub struct DynamicPalette {
  colors : Array[Color]
  color_map : Map[Int, Int] // color hash -> palette index
}

///|
pub fn DynamicPalette::new() -> DynamicPalette {
  let colors : Array[Color] = []
  // Reserve index 0 for transparent/white background
  let white = Color::white()
  colors.push(white)
  let color_map : Map[Int, Int] = {}
  color_map.set(color_hash(white), 0)
  { colors, color_map }
}

///|
/// Convert layout Color to raster Color
fn types_color_to_image(c : @types.Color) -> Color {
  { r: c.r, g: c.g, b: c.b }
}

///|
fn clamp_byte(v : Int) -> Int {
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}

///|
fn effective_alpha_byte(color : @types.Color, opacity : Double) -> Int {
  clamp_byte((color.a * opacity * 255.0).to_int())
}

///|
fn palette_color_at(palette : DynamicPalette, idx : Int) -> Color {
  if idx >= 0 && idx < palette.colors.length() {
    palette.colors[idx]
  } else {
    Color::white()
  }
}

///|
/// Hash a color for map lookup
fn color_hash(c : Color) -> Int {
  c.r * 65536 + c.g * 256 + c.b
}

///|
/// Quantize a color channel to reduce palette entries
/// Rounds to nearest multiple of step (e.g., step=4 gives 64 levels per channel)
fn quantize_channel(v : Int, step : Int) -> Int {
  let q = (v + step / 2) / step * step
  if q > 255 {
    255
  } else {
    q
  }
}

///|
/// Get or add a color to the palette, returns palette index
fn DynamicPalette::get_or_add(self : DynamicPalette, c : Color) -> Int {
  let hash = color_hash(c)
  match self.color_map.get(hash) {
    Some(idx) => idx
    None => {
      let idx = self.colors.length()
      if idx < 4096 {
        self.colors.push(c)
        self.color_map.set(hash, idx)
        idx
      } else {
        // Palette full — quantize and find nearest existing entry
        let qc : Color = {
          r: quantize_channel(c.r, 8),
          g: quantize_channel(c.g, 8),
          b: quantize_channel(c.b, 8),
        }
        let qhash = color_hash(qc)
        match self.color_map.get(qhash) {
          Some(qi) => qi
          None => idx - 1
        }
      }
    }
  }
}
