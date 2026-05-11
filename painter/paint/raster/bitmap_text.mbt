///|
/// Check if a character is East Asian Wide (CJK characters that take 2 columns)
fn is_wide_char(c : Char) -> Bool {
  let cp = c.to_int()
  // CJK Unified Ideographs (U+4E00–U+9FFF)
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  // CJK Extension A (U+3400–U+4DBF)
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  // Hiragana (U+3040–U+309F)
  (cp >= 0x3040 && cp <= 0x309F) ||
  // Katakana (U+30A0–U+30FF)
  (cp >= 0x30A0 && cp <= 0x30FF) ||
  // Hangul Syllables (U+AC00–U+D7AF)
  (cp >= 0xAC00 && cp <= 0xD7AF) ||
  // Fullwidth Forms (U+FF00–U+FFEF)
  (cp >= 0xFF00 && cp <= 0xFFEF) ||
  // CJK Symbols and Punctuation (U+3000–U+303F)
  (cp >= 0x3000 && cp <= 0x303F)
}

///|
/// Draw a single character at the given position using bitmap font
/// Returns the width of the character drawn (in pixels)
pub fn Framebuffer::draw_char(
  self : Framebuffer,
  x : Int,
  y : Int,
  c : Char,
  color : Int,
  scale : Int,
) -> Int {
  // Handle CJK: draw outlined rectangle for 2-column width (placeholder)
  if is_wide_char(c) {
    let char_w = font_width * 2 * scale
    let char_h = font_height * scale
    // Draw outlined rectangle as CJK placeholder (not filled to avoid black blocks)
    self.stroke_rect(x + 1, y + 1, char_w - 2, char_h - 2, color)
    return char_w
  }
  // Handle ASCII with bitmap font
  match get_char_bitmap(c) {
    Some(bitmap) => {
      for row = 0; row < font_height; row = row + 1 {
        let row_data = bitmap[row]
        for col = 0; col < font_width; col = col + 1 {
          // Check if bit is set (MSB = leftmost pixel)
          let bit = (row_data >> (7 - col)) & 1
          if bit == 1 {
            // Draw scaled pixel
            for sy = 0; sy < scale; sy = sy + 1 {
              for sx = 0; sx < scale; sx = sx + 1 {
                self.set_pixel(
                  x + col * scale + sx,
                  y + row * scale + sy,
                  color,
                )
              }
            }
          }
        }
      }
      font_width * scale
    }
    None => {
      // Unsupported character: draw small rectangle as placeholder
      let char_w = font_width * scale
      let char_h = font_height * scale
      self.stroke_rect(x + 1, y + 1, char_w - 2, char_h - 2, color)
      char_w
    }
  }
}

///|
/// Draw text string at the given position
/// Handles line wrapping within the given width constraint
/// Returns the height of the text drawn (in pixels)
pub fn Framebuffer::draw_text(
  self : Framebuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  color : Int,
  scale : Int,
) -> Int {
  let char_h = font_height * scale
  let mut cur_x = x
  let mut cur_y = y
  let mut max_y = y + char_h
  for c in text {
    // Handle newline
    if c == '\n' {
      cur_x = x
      cur_y = cur_y + char_h
      max_y = cur_y + char_h
      continue
    }
    // Skip carriage return
    if c == '\r' {
      continue
    }
    // Calculate character width
    let char_w = if is_wide_char(c) {
      font_width * 2 * scale
    } else {
      font_width * scale
    }
    // Check for line wrap
    if max_width > 0 && cur_x + char_w > x + max_width {
      cur_x = x
      cur_y = cur_y + char_h
      max_y = cur_y + char_h
    }
    // Draw the character
    let drawn_w = self.draw_char(cur_x, cur_y, c, color, scale)
    cur_x = cur_x + drawn_w
  }
  max_y - y
}

///|
/// Draw text with clipping support (bitmap font fallback)
fn draw_text_clipped(
  fb : Framebuffer,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  color : Int,
  scale : Int,
  clip : ClipRect?,
) -> Int {
  match clip {
    None => fb.draw_text(x, y, text, max_width, color, scale)
    Some(_) => {
      // For bitmap font, we draw normally but use set_pixel which bounds-checks.
      // To clip, we temporarily render to the framebuffer but only write pixels in clip.
      let char_h = font_height * scale
      let mut cur_x = x
      let mut cur_y = y
      let mut max_y = y + char_h
      for c in text {
        if c == '\n' {
          cur_x = x
          cur_y = cur_y + char_h
          max_y = cur_y + char_h
          continue
        }
        if c == '\r' {
          continue
        }
        let char_w = if is_wide_char(c) {
          font_width * 2 * scale
        } else {
          font_width * scale
        }
        if max_width > 0 && cur_x + char_w > x + max_width {
          cur_x = x
          cur_y = cur_y + char_h
          max_y = cur_y + char_h
        }
        // Only draw if any part might be visible
        if pixel_in_clip(clip, cur_x, cur_y) ||
          pixel_in_clip(clip, cur_x + char_w - 1, cur_y + char_h - 1) {
          let drawn_w = fb.draw_char(cur_x, cur_y, c, color, scale)
          cur_x = cur_x + drawn_w
        } else {
          let char_w2 = if is_wide_char(c) {
            font_width * 2 * scale
          } else {
            font_width * scale
          }
          cur_x = cur_x + char_w2
        }
      }
      max_y - y
    }
  }
}
