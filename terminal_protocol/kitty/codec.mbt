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
let base64_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
let kitty_chunk_size = 4096

///|
let kitty_pixels_per_chunk : Int = kitty_chunk_size / 4

///|
let kitty_white_triplet = "////"

///|
pub fn chunk_size() -> Int {
  kitty_chunk_size
}

///|
fn write_base64_triplet(
  buf : StringBuilder,
  b0 : Int,
  b1 : Int,
  b2 : Int,
) -> Unit {
  let c0 = (b0 >> 2) & 0x3F
  let c1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
  let c2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
  let c3 = b2 & 0x3F
  buf.write_char(base64_chars[c0].unsafe_to_char())
  buf.write_char(base64_chars[c1].unsafe_to_char())
  buf.write_char(base64_chars[c2].unsafe_to_char())
  buf.write_char(base64_chars[c3].unsafe_to_char())
}

///|
fn encode_base64_triplet(b0 : Int, b1 : Int, b2 : Int) -> String {
  let buf = StringBuilder::new()
  write_base64_triplet(buf, b0, b1, b2)
  buf.to_string()
}

///|
fn build_kitty_palette_triplets(colors : Array[Color]) -> Array[String] {
  let triplets : Array[String] = []
  for color in colors {
    triplets.push(encode_base64_triplet(color.r, color.g, color.b))
  }
  triplets
}

///|
fn write_kitty_pixel_triplet(
  buf : StringBuilder,
  triplets : Array[String],
  color_idx : Int,
) -> Unit {
  if color_idx >= 0 && color_idx < triplets.length() {
    buf.write_string(triplets[color_idx])
  } else {
    buf.write_string(kitty_white_triplet)
  }
}

///|
fn kitty_pixel_triplet(triplets : Array[String], color_idx : Int) -> String {
  if color_idx >= 0 && color_idx < triplets.length() {
    triplets[color_idx]
  } else {
    kitty_white_triplet
  }
}

///|
fn indexed_uniform_color_index(
  width : Int,
  height : Int,
  pixels : Array[Int],
) -> Int? {
  let pixel_count = width * height
  if pixel_count == 0 || pixels.length() == 0 {
    return None
  }
  let color_idx = pixels[0]
  for i in 1..<pixel_count {
    if i >= pixels.length() || pixels[i] != color_idx {
      return None
    }
  }
  Some(color_idx)
}

///|
fn write_kitty_chunk_header(
  buf : StringBuilder,
  width : Int,
  height : Int,
  is_first : Bool,
  has_more : Bool,
) -> Unit {
  if is_first {
    buf.write_string("\u001b_Ga=T,f=24,q=2,s=")
    buf.write_string(width.to_string())
    buf.write_string(",v=")
    buf.write_string(height.to_string())
    buf.write_string(",m=")
  } else {
    buf.write_string("\u001b_Gm=")
  }
  buf.write_string(if has_more { "1" } else { "0" })
  buf.write_string(";")
}

///|
async fn[T : @io.Writer] write_kitty_chunk_header_to(
  writer : T,
  width : Int,
  height : Int,
  is_first : Bool,
  has_more : Bool,
) -> Unit {
  if is_first {
    writer.write("\u001b_Ga=T,f=24,q=2,s=") catch {
      _ => return
    }
    writer.write(width.to_string()) catch {
      _ => return
    }
    writer.write(",v=") catch {
      _ => return
    }
    writer.write(height.to_string()) catch {
      _ => return
    }
    writer.write(",m=") catch {
      _ => return
    }
  } else {
    writer.write("\u001b_Gm=") catch {
      _ => return
    }
  }
  writer.write(if has_more { "1" } else { "0" }) catch {
    _ => return
  }
  writer.write(";") catch {
    _ => return
  }
}

///|
fn write_repeated_kitty_triplet(
  buf : StringBuilder,
  triplet : String,
  count : Int,
) -> Unit {
  if count > 0 {
    buf.write_string(triplet.repeat(count))
  }
}

///|
fn to_kitty_uniform(
  width : Int,
  height : Int,
  pixel_count : Int,
  triplet : String,
) -> String {
  let buf = StringBuilder::new(size_hint=pixel_count * 4)
  let full_chunk_payload = triplet.repeat(kitty_pixels_per_chunk)
  let mut first_chunk = true
  let mut pixel_index = 0
  while pixel_index < pixel_count {
    let remaining = pixel_count - pixel_index
    let chunk_pixels = if remaining > kitty_pixels_per_chunk {
      kitty_pixels_per_chunk
    } else {
      remaining
    }
    let has_more = pixel_index + chunk_pixels < pixel_count
    write_kitty_chunk_header(buf, width, height, first_chunk, has_more)
    if chunk_pixels == kitty_pixels_per_chunk {
      buf.write_string(full_chunk_payload)
    } else {
      write_repeated_kitty_triplet(buf, triplet, chunk_pixels)
    }
    buf.write_string("\u001b\\")
    first_chunk = false
    pixel_index += chunk_pixels
  }
  buf.to_string()
}

///|
async fn[T : @io.Writer] write_kitty_uniform(
  writer : T,
  width : Int,
  height : Int,
  pixel_count : Int,
  triplet : String,
) -> Unit {
  let full_chunk_payload = triplet.repeat(kitty_pixels_per_chunk)
  let mut first_chunk = true
  let mut pixel_index = 0
  while pixel_index < pixel_count {
    let remaining = pixel_count - pixel_index
    let chunk_pixels = if remaining > kitty_pixels_per_chunk {
      kitty_pixels_per_chunk
    } else {
      remaining
    }
    let has_more = pixel_index + chunk_pixels < pixel_count
    write_kitty_chunk_header_to(writer, width, height, first_chunk, has_more)
    if chunk_pixels == kitty_pixels_per_chunk {
      writer.write(full_chunk_payload) catch {
        _ => return
      }
    } else if chunk_pixels > 0 {
      writer.write(triplet.repeat(chunk_pixels)) catch {
        _ => return
      }
    }
    writer.write("\u001b\\") catch {
      _ => return
    }
    first_chunk = false
    pixel_index += chunk_pixels
  }
}

///|
pub fn encode_indexed_pixels_to_kitty(
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
) -> String {
  let triplets = build_kitty_palette_triplets(colors)
  let pixel_count = width * height
  match indexed_uniform_color_index(width, height, pixels) {
    Some(color_idx) =>
      return to_kitty_uniform(
        width,
        height,
        pixel_count,
        kitty_pixel_triplet(triplets, color_idx),
      )
    None => ()
  }
  let buf = StringBuilder::new(size_hint=pixel_count * 4)
  let mut first_chunk = true
  let mut pixel_index = 0
  while pixel_index < pixel_count {
    let remaining = pixel_count - pixel_index
    let chunk_pixels = if remaining > kitty_pixels_per_chunk {
      kitty_pixels_per_chunk
    } else {
      remaining
    }
    let has_more = pixel_index + chunk_pixels < pixel_count
    write_kitty_chunk_header(buf, width, height, first_chunk, has_more)
    for _ in 0..<chunk_pixels {
      let color_idx = if pixel_index < pixels.length() {
        pixels[pixel_index]
      } else {
        -1
      }
      write_kitty_pixel_triplet(buf, triplets, color_idx)
      pixel_index += 1
    }
    buf.write_string("\u001b\\")
    first_chunk = false
  }
  if pixel_count == 0 {
    write_kitty_chunk_header(buf, width, height, true, false)
    buf.write_string("\u001b\\")
  }
  buf.to_string()
}

///|
fn write_kitty_cell_image_header(
  buf : StringBuilder,
  pixel_width : Int,
  pixel_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id : Int,
  placement_id : Int,
  image_format : Int,
  is_first : Bool,
  has_more : Bool,
) -> Unit {
  let m_val = if has_more { 1 } else { 0 }
  if is_first {
    buf.write_string("\u001b_Ga=T,f=")
    buf.write_string(image_format.to_string())
    buf.write_string(",q=2,c=")
    buf.write_string(display_cols.to_string())
    buf.write_string(",r=")
    buf.write_string(display_rows.to_string())
    if image_id > 0 {
      buf.write_string(",i=")
      buf.write_string(image_id.to_string())
      if placement_id > 0 {
        buf.write_string(",p=")
        buf.write_string(placement_id.to_string())
      }
    }
    if pixel_width > 0 && pixel_height > 0 {
      buf.write_string(",s=")
      buf.write_string(pixel_width.to_string())
      buf.write_string(",v=")
      buf.write_string(pixel_height.to_string())
    }
    buf.write_string(",m=")
    buf.write_string(m_val.to_string())
    buf.write_string(";")
  } else {
    buf.write_string("\u001b_Gm=")
    buf.write_string(m_val.to_string())
    buf.write_string(";")
  }
}

///|
pub fn encode_indexed_pixels_to_kitty_cells(
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  let pixel_count = width * height
  if pixel_count <= 0 {
    return ""
  }
  let triplets = build_kitty_palette_triplets(colors)
  let buf = StringBuilder::new(size_hint=pixel_count * 4)
  let mut chunk = StringBuilder::new()
  let mut chunk_len = 0
  let mut first_chunk = true
  for pixel_index in 0..<pixel_count {
    if chunk_len + 4 > kitty_chunk_size {
      write_kitty_cell_image_header(
        buf, width, height, display_cols, display_rows, image_id, placement_id, 24,
        first_chunk, true,
      )
      buf.write_string(chunk.to_string())
      buf.write_string("\u001b\\")
      chunk = StringBuilder::new()
      chunk_len = 0
      first_chunk = false
    }
    let color_idx = if pixel_index < pixels.length() {
      pixels[pixel_index]
    } else {
      -1
    }
    write_kitty_pixel_triplet(chunk, triplets, color_idx)
    chunk_len += 4
  }
  if chunk_len > 0 {
    write_kitty_cell_image_header(
      buf, width, height, display_cols, display_rows, image_id, placement_id, 24,
      first_chunk, false,
    )
    buf.write_string(chunk.to_string())
    buf.write_string("\u001b\\")
  }
  buf.to_string()
}

///|
fn encode_base64_payload_as_kitty_image(
  b64_data : String,
  image_format : Int,
  pixel_width : Int,
  pixel_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id : Int,
  placement_id : Int,
) -> String {
  if b64_data.length() == 0 {
    return ""
  }
  if image_format == 32 && (pixel_width <= 0 || pixel_height <= 0) {
    return ""
  }
  let buf = StringBuilder::new()
  let total_len = b64_data.length()
  let b64_chars = b64_data.to_array()
  for offset = 0; offset < total_len; offset = offset + kitty_chunk_size {
    let end = (offset + kitty_chunk_size).min(total_len)
    write_kitty_cell_image_header(
      buf,
      pixel_width,
      pixel_height,
      display_cols,
      display_rows,
      image_id,
      placement_id,
      image_format,
      offset == 0,
      end < total_len,
    )
    for i = offset; i < end; i = i + 1 {
      buf.write_char(b64_chars[i])
    }
    buf.write_string("\u001b\\")
  }
  buf.to_string()
}

///|
pub fn encode_png_base64_to_kitty_image(
  b64_data : String,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  encode_base64_payload_as_kitty_image(
    b64_data, 100, 0, 0, display_cols, display_rows, image_id, placement_id,
  )
}

///|
pub fn encode_rgba_base64_to_kitty_image(
  b64_data : String,
  pixel_width : Int,
  pixel_height : Int,
  display_cols : Int,
  display_rows : Int,
  image_id? : Int = 0,
  placement_id? : Int = 0,
) -> String {
  encode_base64_payload_as_kitty_image(
    b64_data, 32, pixel_width, pixel_height, display_cols, display_rows, image_id,
    placement_id,
  )
}

///|
pub fn encode_put_placement(
  image_id : Int,
  placement_id : Int,
  display_cols : Int,
  display_rows : Int,
) -> String {
  if image_id <= 0 || placement_id <= 0 {
    return ""
  }
  "\u001b_Ga=p,q=2,i=" +
  image_id.to_string() +
  ",p=" +
  placement_id.to_string() +
  ",c=" +
  display_cols.to_string() +
  ",r=" +
  display_rows.to_string() +
  ";\u001b\\"
}

///|
pub fn encode_delete_placement(image_id : Int, placement_id : Int) -> String {
  if image_id <= 0 || placement_id <= 0 {
    return ""
  }
  "\u001b_Ga=d,q=2,d=i,i=" +
  image_id.to_string() +
  ",p=" +
  placement_id.to_string() +
  ";\u001b\\"
}

///|
pub async fn[T : @io.Writer] write_indexed_pixels_to_kitty(
  writer : T,
  width : Int,
  height : Int,
  pixels : Array[Int],
  colors : Array[Color],
) -> Unit {
  let triplets = build_kitty_palette_triplets(colors)
  let pixel_count = width * height
  match indexed_uniform_color_index(width, height, pixels) {
    Some(color_idx) => {
      write_kitty_uniform(
        writer,
        width,
        height,
        pixel_count,
        kitty_pixel_triplet(triplets, color_idx),
      )
      return
    }
    None => ()
  }
  let mut chunk = StringBuilder::new()
  let mut chunk_len = 0
  let mut first_chunk = true
  for pixel_index in 0..<pixel_count {
    if chunk_len + 4 > kitty_chunk_size {
      write_kitty_chunk_header_to(writer, width, height, first_chunk, true)
      writer.write(chunk.to_string()) catch {
        _ => return
      }
      writer.write("\u001b\\") catch {
        _ => return
      }
      chunk = StringBuilder::new()
      chunk_len = 0
      first_chunk = false
    }
    let color_idx = if pixel_index < pixels.length() {
      pixels[pixel_index]
    } else {
      -1
    }
    write_kitty_pixel_triplet(chunk, triplets, color_idx)
    chunk_len += 4
  }
  write_kitty_chunk_header_to(writer, width, height, first_chunk, false)
  if chunk_len > 0 {
    writer.write(chunk.to_string()) catch {
      _ => return
    }
  }
  writer.write("\u001b\\") catch {
    _ => return
  }
}
