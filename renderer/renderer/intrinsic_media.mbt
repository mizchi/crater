///|
/// Intrinsic media size extraction helpers.

///|
/// Parse dimension from HTML attribute (e.g., "300" or "300px")
fn parse_html_dimension(value : String) -> Double? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  // Remove "px" suffix if present
  let num_str = if trimmed.has_suffix("px") {
    trimmed.unsafe_substring(start=0, end=trimmed.length() - 2)
  } else {
    trimmed
  }
  Some(
    // Parse as double
    @string.parse_double(num_str),
  ) catch {
    _ => None
  }
}

///|
/// Simple URL decode for common SVG data URI characters
fn url_decode(s : String) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i < s.length() {
    let c = s[i].to_int().unsafe_to_char()
    if c == '%' && i + 2 < s.length() {
      // Parse hex value
      let hex1 = s[i + 1].to_int().unsafe_to_char()
      let hex2 = s[i + 2].to_int().unsafe_to_char()
      fn hex_digit(c : Char) -> Int {
        if c >= '0' && c <= '9' {
          c.to_int() - '0'.to_int()
        } else if c >= 'a' && c <= 'f' {
          c.to_int() - 'a'.to_int() + 10
        } else if c >= 'A' && c <= 'F' {
          c.to_int() - 'A'.to_int() + 10
        } else {
          0
        }
      }

      let value = hex_digit(hex1) * 16 + hex_digit(hex2)
      result.write_char(value.unsafe_to_char())
      i = i + 3
    } else {
      result.write_char(c)
      i = i + 1
    }
  }
  result.to_string()
}

///|
/// Find index of pattern in string, returns -1 if not found
fn find_string_index(s : String, pattern : String) -> Int {
  if pattern.length() == 0 || pattern.length() > s.length() {
    return -1
  }
  for i = 0; i <= s.length() - pattern.length(); i = i + 1 {
    let mut found = true
    for j = 0; j < pattern.length(); j = j + 1 {
      if s[i + j].to_int() != pattern[j].to_int() {
        found = false
        break
      }
    }
    if found {
      return i
    }
  }
  -1
}

///|
/// Extract a simple attribute value from SVG string
fn extract_svg_attribute(svg : String, attr_name : String) -> String? {
  // Look for attr='value' or attr="value"
  let patterns = [attr_name + "='", attr_name + "=\""]
  for pattern in patterns {
    let idx = find_string_index(svg, pattern)
    if idx >= 0 {
      let start = idx + pattern.length()
      let quote_char = if pattern.has_suffix("'") { '\'' } else { '"' }
      // Find closing quote
      for end = start; end < svg.length(); end = end + 1 {
        if svg[end].to_int().unsafe_to_char() == quote_char {
          let result = svg.unsafe_substring(start~, end~)
          if result.length() > 0 {
            return Some(result)
          }
        }
      }
    }
  }
  None
}

///|
/// Parse viewBox attribute (format: "minX minY width height")
fn parse_viewbox(viewbox : String) -> (Double, Double)? {
  // Split by spaces
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  for i = 0; i < viewbox.length(); i = i + 1 {
    let c = viewbox[i].to_int().unsafe_to_char()
    if c == ' ' {
      if current.to_string().length() > 0 {
        parts.push(current.to_string())
        current = StringBuilder::new()
      }
    } else {
      current.write_char(c)
    }
  }
  if current.to_string().length() > 0 {
    parts.push(current.to_string())
  }
  if parts.length() >= 4 {
    let width = @string.parse_double(parts[2]) catch { _ => return None }
    let height = @string.parse_double(parts[3]) catch { _ => return None }
    if width > 0.0 && height > 0.0 {
      Some((width, height))
    } else {
      None
    }
  } else {
    None
  }
}

///|
/// Extract intrinsic size from SVG data URI
fn parse_svg_data_uri(src : String) -> (Double, Double)? {
  // Check if it's an SVG data URI
  if !src.has_prefix("data:image/svg+xml") {
    return None
  }
  // Check for base64 encoding (not supported yet)
  if src.contains(";base64,") {
    return None
  }
  // Find the comma that starts the data
  let mut comma_idx = -1
  for i = 0; i < src.length(); i = i + 1 {
    if src[i].to_int().unsafe_to_char() == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  // URL decode the SVG content
  let svg_encoded = src.unsafe_substring(start=comma_idx + 1, end=src.length())
  let svg = url_decode(svg_encoded)
  // Extract width, height, and viewBox
  let width_attr = extract_svg_attribute(svg, "width")
  let height_attr = extract_svg_attribute(svg, "height")
  let viewbox_attr = extract_svg_attribute(svg, "viewBox")
  // Parse width and height
  let parsed_width : Double? = match width_attr {
    Some(w) => parse_html_dimension(w)
    None => None
  }
  let parsed_height : Double? = match height_attr {
    Some(h) => parse_html_dimension(h)
    None => None
  }
  // Get aspect ratio from viewBox
  let viewbox_size : (Double, Double)? = match viewbox_attr {
    Some(vb) => parse_viewbox(vb)
    None => None
  }
  // Calculate final dimensions
  match (parsed_width, parsed_height, viewbox_size) {
    // Both width and height specified
    (Some(w), Some(h), _) => Some((w, h))
    // Only width specified, use viewBox aspect ratio
    (Some(w), None, Some((vb_w, vb_h))) => {
      let aspect = vb_w / vb_h
      Some((w, w / aspect))
    }
    // Only height specified, use viewBox aspect ratio
    (None, Some(h), Some((vb_w, vb_h))) => {
      let aspect = vb_w / vb_h
      Some((h * aspect, h))
    }
    // No width/height but viewBox exists
    (None, None, Some((vb_w, vb_h))) => Some((vb_w, vb_h))
    // Width only, no aspect ratio
    (Some(w), None, None) => Some((w, w))
    // Height only, no aspect ratio
    (None, Some(h), None) => Some((h, h))
    _ => None
  }
}

///|
fn base64_char_value(c : Char) -> Int? {
  let cp = c.to_int()
  if cp >= 'A'.to_int() && cp <= 'Z'.to_int() {
    Some(cp - 'A'.to_int())
  } else if cp >= 'a'.to_int() && cp <= 'z'.to_int() {
    Some(cp - 'a'.to_int() + 26)
  } else if cp >= '0'.to_int() && cp <= '9'.to_int() {
    Some(cp - '0'.to_int() + 52)
  } else if cp == '+'.to_int() {
    Some(62)
  } else if cp == '/'.to_int() {
    Some(63)
  } else {
    None
  }
}

///|
fn decode_base64_prefix(encoded : String, byte_count : Int) -> Array[Int]? {
  let bytes : Array[Int] = []
  let quartet : Array[Int] = []
  for c in encoded.iter() {
    if c == '=' {
      quartet.push(-1)
    } else {
      match base64_char_value(c) {
        Some(v) => quartet.push(v)
        None => continue
      }
    }
    if quartet.length() == 4 {
      let v0 = quartet[0]
      let v1 = quartet[1]
      let v2 = quartet[2]
      let v3 = quartet[3]
      if v0 < 0 || v1 < 0 {
        break
      }
      bytes.push(((v0 << 2) | (v1 >> 4)) & 0xFF)
      if v2 >= 0 {
        bytes.push((((v1 & 0x0F) << 4) | (v2 >> 2)) & 0xFF)
      }
      if v2 >= 0 && v3 >= 0 {
        bytes.push((((v2 & 0x03) << 6) | v3) & 0xFF)
      }
      if bytes.length() >= byte_count {
        return Some(bytes)
      }
      quartet.clear()
    }
  }
  None
}

///|
fn parse_gif_data_uri(src : String) -> (Double, Double)? {
  if !src.to_lower().has_prefix("data:image/gif;base64,") {
    return None
  }
  let mut comma_idx = -1
  for i = 0; i < src.length(); i = i + 1 {
    if src[i].to_int().unsafe_to_char() == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  let encoded = src.unsafe_substring(start=comma_idx + 1, end=src.length())
  match decode_base64_prefix(encoded, 10) {
    Some(bytes) => {
      if bytes.length() < 10 {
        return None
      }
      // GIF header + logical screen descriptor (little-endian width/height)
      if bytes[0] != 'G'.to_int() ||
        bytes[1] != 'I'.to_int() ||
        bytes[2] != 'F'.to_int() {
        return None
      }
      let width = bytes[6] + (bytes[7] << 8)
      let height = bytes[8] + (bytes[9] << 8)
      if width > 0 && height > 0 {
        Some((width.to_double(), height.to_double()))
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn parse_png_data_uri(src : String) -> (Double, Double)? {
  if !src.to_lower().has_prefix("data:image/png;base64,") {
    return None
  }
  let mut comma_idx = -1
  for i = 0; i < src.length(); i = i + 1 {
    if src[i].to_int().unsafe_to_char() == ',' {
      comma_idx = i
      break
    }
  }
  if comma_idx < 0 {
    return None
  }
  let encoded = src.unsafe_substring(start=comma_idx + 1, end=src.length())
  match decode_base64_prefix(encoded, 24) {
    Some(bytes) => {
      if bytes.length() < 24 {
        return None
      }
      // PNG signature
      if bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47 ||
        bytes[4] != 0x0D ||
        bytes[5] != 0x0A ||
        bytes[6] != 0x1A ||
        bytes[7] != 0x0A {
        return None
      }
      // First chunk must be IHDR
      if bytes[12] != 'I'.to_int() ||
        bytes[13] != 'H'.to_int() ||
        bytes[14] != 'D'.to_int() ||
        bytes[15] != 'R'.to_int() {
        return None
      }
      let width = (bytes[16] << 24) |
        (bytes[17] << 16) |
        (bytes[18] << 8) |
        bytes[19]
      let height = (bytes[20] << 24) |
        (bytes[21] << 16) |
        (bytes[22] << 8) |
        bytes[23]
      if width > 0 && height > 0 {
        Some((width.to_double(), height.to_double()))
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Get intrinsic size from image src attribute
fn get_image_intrinsic_size_default(src : String) -> (Double, Double)? {
  // Restrict to data URI parsing to avoid filesystem/network side-effects.
  // SVG/GIF/PNG support compact intrinsic extraction.
  match parse_svg_data_uri(src) {
    Some(size) => Some(size)
    None =>
      match parse_gif_data_uri(src) {
        Some(size) => Some(size)
        None => parse_png_data_uri(src)
      }
  }
}

///|
/// Get intrinsic size from image src attribute, optionally using an external provider.
fn get_image_intrinsic_size(src : String) -> (Double, Double)? {
  match image_intrinsic_size_provider_override.val {
    Some(provider) =>
      match (provider.func)(src) {
        Some(size) => Some(size)
        None => get_image_intrinsic_size_default(src)
      }
    None => get_image_intrinsic_size_default(src)
  }
}
