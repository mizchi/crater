///|
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
}

///|
pub fn Color::rgb(r : Int, g : Int, b : Int) -> Color {
  { r, g, b }
}

///|
let sixel_bit_masks : Array[Int] = [1, 2, 4, 8, 16, 32]

///|
fn write_sixel_repeat_or_char(
  buf : StringBuilder,
  ch : Char,
  repeat_count : Int,
) -> Unit {
  if repeat_count >= 4 {
    buf.write_string("!")
    buf.write_string(repeat_count.to_string())
    buf.write_char(ch)
  } else {
    for _i in 0..<repeat_count {
      buf.write_char(ch)
    }
  }
}

///|
fn write_sixel_row(
  buf : StringBuilder,
  band_rows : Array[Int],
  row_base : Int,
  width : Int,
  compress : Bool,
) -> Unit {
  if width <= 0 {
    return
  }
  if compress {
    let mut run_char = (63 + band_rows[row_base]).unsafe_to_char()
    let mut run_len = 1
    for x = 1; x < width; x = x + 1 {
      let next_char = (63 + band_rows[row_base + x]).unsafe_to_char()
      if next_char == run_char {
        run_len = run_len + 1
      } else {
        write_sixel_repeat_or_char(buf, run_char, run_len)
        run_char = next_char
        run_len = 1
      }
    }
    write_sixel_repeat_or_char(buf, run_char, run_len)
  } else {
    for x = 0; x < width; x = x + 1 {
      buf.write_char((63 + band_rows[row_base + x]).unsafe_to_char())
    }
  }
}

///|
fn color_percent_string(value : Int) -> String {
  (value * 100 / 255).to_string()
}

///|
fn build_sixel_palette_definition(colors : Array[Color]) -> String {
  let buf = StringBuilder::new()
  for i, color in colors {
    buf.write_string("#")
    buf.write_string(i.to_string())
    buf.write_string(";2;")
    buf.write_string(color_percent_string(color.r))
    buf.write_string(";")
    buf.write_string(color_percent_string(color.g))
    buf.write_string(";")
    buf.write_string(color_percent_string(color.b))
  }
  buf.to_string()
}

///|
fn build_sixel_color_headers(count : Int) -> Array[String] {
  let headers : Array[String] = []
  for i = 0; i < count; i = i + 1 {
    headers.push("#" + i.to_string())
  }
  headers
}

///|
pub fn encode_indexed_pixels_to_sixel(
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
  include_all_colors? : Bool = false,
  compress? : Bool = true,
) -> String {
  let buf = StringBuilder::new()
  let palette_len = colors.length()
  let color_headers = build_sixel_color_headers(palette_len)

  buf.write_string("\u001bPq")
  buf.write_string(build_sixel_palette_definition(colors))

  let num_bands = (height + 5) / 6
  for band = 0; band < num_bands; band = band + 1 {
    let y_start = band * 6
    let active_colors = Array::make(palette_len, include_all_colors)
    let band_rows = Array::make(palette_len * width, 0)
    for bit = 0; bit < 6; bit = bit + 1 {
      let y = y_start + bit
      if y >= height {
        continue
      }
      let row_offset = y * width
      let bit_mask = sixel_bit_masks[bit]
      for x = 0; x < width; x = x + 1 {
        let pixel_offset = row_offset + x
        if pixel_offset >= pixels.length() {
          continue
        }
        let color_idx = pixels[pixel_offset]
        if color_idx < 0 || color_idx >= palette_len {
          continue
        }
        active_colors[color_idx] = true
        let cell_idx = color_idx * width + x
        band_rows[cell_idx] = band_rows[cell_idx] | bit_mask
      }
    }
    for color_idx = 0; color_idx < palette_len; color_idx = color_idx + 1 {
      if !active_colors[color_idx] {
        continue
      }
      buf.write_string(color_headers[color_idx])
      let row_base = color_idx * width
      write_sixel_row(buf, band_rows, row_base, width, compress)
      buf.write_char('$')
    }
    buf.write_char('-')
  }
  buf.write_string("\u001b\\")
  buf.to_string()
}
