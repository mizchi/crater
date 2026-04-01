///|
/// Sixel Renderer for terminal visualization
/// Sixel is a DEC graphics format for displaying images in terminals

///|
/// RGB Color (0-255 range)
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
}

///|
/// Predefined colors for visualization
pub fn Color::transparent() -> Color {
  { r: 0, g: 0, b: 0 }
}

///|
pub fn Color::blue() -> Color {
  { r: 66, g: 133, b: 244 }
}

///|
pub fn Color::green() -> Color {
  { r: 52, g: 168, b: 83 }
}

///|
pub fn Color::yellow() -> Color {
  { r: 251, g: 188, b: 4 }
}

///|
pub fn Color::red() -> Color {
  { r: 234, g: 67, b: 53 }
}

///|
pub fn Color::gray() -> Color {
  { r: 154, g: 160, b: 166 }
}

///|
pub fn Color::white() -> Color {
  { r: 255, g: 255, b: 255 }
}

///|
pub fn Color::black() -> Color {
  { r: 0, g: 0, b: 0 }
}

///|
/// Get color by depth level
pub fn get_depth_color(depth : Int) -> Color {
  let colors = [
    Color::blue(),
    Color::green(),
    Color::yellow(),
    Color::red(),
    Color::gray(),
  ]
  colors[depth % colors.length()]
}

///|
/// Blend color with alpha (0-255)
pub fn Color::blend(self : Color, bg : Color, alpha : Int) -> Color {
  let a = alpha.to_double() / 255.0
  let inv_a = 1.0 - a
  {
    r: (self.r.to_double() * a + bg.r.to_double() * inv_a).to_int(),
    g: (self.g.to_double() * a + bg.g.to_double() * inv_a).to_int(),
    b: (self.b.to_double() * a + bg.b.to_double() * inv_a).to_int(),
  }
}

///|
let sixel_bit_masks : Array[Int] = [1, 2, 4, 8, 16, 32]

///|
let base64_chars : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
fn write_base64_quad(
  buf : StringBuilder,
  b0 : Int,
  b1 : Int,
  b2 : Int,
  padding : Int,
) -> Unit {
  let c0 = (b0 >> 2) & 0x3F
  let c1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
  let c2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
  let c3 = b2 & 0x3F
  buf.write_char(base64_chars[c0].unsafe_to_char())
  buf.write_char(base64_chars[c1].unsafe_to_char())
  if padding >= 2 {
    buf.write_char('=')
  } else {
    buf.write_char(base64_chars[c2].unsafe_to_char())
  }
  if padding >= 1 {
    buf.write_char('=')
  } else {
    buf.write_char(base64_chars[c3].unsafe_to_char())
  }
}

///|
fn encode_bytes_base64(bytes : Array[Int]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i]
    let remaining = bytes.length() - i
    if remaining >= 3 {
      write_base64_quad(out, b0, bytes[i + 1], bytes[i + 2], 0)
      i = i + 3
    } else if remaining == 2 {
      write_base64_quad(out, b0, bytes[i + 1], 0, 1)
      i = i + 2
    } else {
      write_base64_quad(out, b0, 0, 0, 2)
      i = i + 1
    }
  }
  out.to_string()
}

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
fn write_sixel_row_compressed(
  buf : StringBuilder,
  band_rows : Array[Int],
  row_base : Int,
  width : Int,
) -> Unit {
  if width <= 0 {
    return
  }
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
}

///|
/// Simple framebuffer for rendering
pub struct Framebuffer {
  width : Int
  height : Int
  pixels : Array[Int] // Color index per pixel (0 = transparent)
}

///|
pub fn Framebuffer::new(width : Int, height : Int) -> Framebuffer {
  let size = width * height
  let pixels : Array[Int] = Array::make(size, 0)
  { width, height, pixels }
}

///|
fn Framebuffer::set_pixel(
  self : Framebuffer,
  x : Int,
  y : Int,
  color : Int,
) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.pixels[y * self.width + x] = color
  }
}

///|
pub fn Framebuffer::get_pixel(self : Framebuffer, x : Int, y : Int) -> Int {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.pixels[y * self.width + x]
  } else {
    0
  }
}

///|
/// Draw a filled rectangle
pub fn Framebuffer::fill_rect(
  self : Framebuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Int,
) -> Unit {
  for py = y; py < y + h; py = py + 1 {
    for px = x; px < x + w; px = px + 1 {
      self.set_pixel(px, py, color)
    }
  }
}

///|
/// Draw a rectangle outline
pub fn Framebuffer::stroke_rect(
  self : Framebuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Int,
) -> Unit {
  // Top and bottom edges
  for px = x; px < x + w; px = px + 1 {
    self.set_pixel(px, y, color)
    self.set_pixel(px, y + h - 1, color)
  }
  // Left and right edges
  for py = y; py < y + h; py = py + 1 {
    self.set_pixel(x, py, color)
    self.set_pixel(x + w - 1, py, color)
  }
}

///|
/// Draw a filled rectangle with diagonal hatching pattern
/// spacing: pixels between diagonal lines (e.g., 4)
pub fn Framebuffer::fill_rect_hatched(
  self : Framebuffer,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  bg_color : Int,
  line_color : Int,
  spacing : Int,
) -> Unit {
  for py = y; py < y + h; py = py + 1 {
    for px = x; px < x + w; px = px + 1 {
      // Diagonal pattern: (x + y) % spacing == 0
      if (px + py) % spacing == 0 {
        self.set_pixel(px, py, line_color)
      } else {
        self.set_pixel(px, py, bg_color)
      }
    }
  }
}

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

///|
/// Color palette for Sixel output
priv struct Palette {
  colors : Array[Color]
}

///|
fn Palette::new() -> Palette {
  {
    colors: [
      Color::white(),
      Color::blue(),
      Color::green(),
      Color::yellow(),
      Color::red(),
      Color::gray(),
      Color::black(),
    ],
  }
}

///|
/// Extended palette with depth gradients and text colors
fn Palette::extended() -> Palette {
  {
    colors: [
      Color::white(), // 0: background
      { r: 220, g: 235, b: 250 }, // 1: depth 0 - very light blue
      { r: 185, g: 215, b: 240 }, // 2: depth 1 - light blue
      { r: 150, g: 195, b: 230 }, // 3: depth 2 - medium light blue
      { r: 115, g: 175, b: 220 }, // 4: depth 3 - medium blue
      { r: 80, g: 155, b: 210 }, // 5: depth 4 - darker blue
      { r: 45, g: 135, b: 200 }, // 6: depth 5+ - dark blue
      { r: 34, g: 139, b: 34 }, // 7: text color - forest green
      { r: 0, g: 100, b: 0 }, // 8: text border - dark green
      Color::black(), // 9: black for borders
    ],
  }
}

///|
/// Convert framebuffer to Sixel string
pub fn to_sixel(fb : Framebuffer) -> String {
  let buf = StringBuilder::new()
  let palette = Palette::new()

  // Sixel start sequence: ESC P q
  buf.write_string("\u001bPq")

  // Define color palette
  // Format: #n;2;r;g;b (RGB in 0-100 range)
  for i, color in palette.colors {
    buf.write_string("#")
    buf.write_string(i.to_string())
    buf.write_string(";2;")
    buf.write_string((color.r * 100 / 255).to_string())
    buf.write_string(";")
    buf.write_string((color.g * 100 / 255).to_string())
    buf.write_string(";")
    buf.write_string((color.b * 100 / 255).to_string())
  }

  // Process in bands of 6 pixels height
  let num_bands = (fb.height + 5) / 6
  for band = 0; band < num_bands; band = band + 1 {
    let y_start = band * 6

    // For each color in palette
    for color_idx = 0
        color_idx < palette.colors.length()
        color_idx = color_idx + 1 {
      // Select color
      buf.write_string("#")
      buf.write_string(color_idx.to_string())

      // Encode row
      for x = 0; x < fb.width; x = x + 1 {
        let mut sixel_value = 0
        // Bit masks for each of the 6 pixels in a sixel
        let bit_masks = [1, 2, 4, 8, 16, 32]
        for bit = 0; bit < 6; bit = bit + 1 {
          let y = y_start + bit
          if y < fb.height {
            let pixel = fb.get_pixel(x, y)
            if pixel == color_idx {
              sixel_value = sixel_value | bit_masks[bit]
            }
          }
        }
        // Sixel character is value + 63 ('?')
        let ch = (63 + sixel_value).unsafe_to_char()
        buf.write_char(ch)
      }

      // Carriage return (go back to start of row)
      buf.write_string("$")
    }

    // Line feed (move to next band)
    buf.write_string("-")
  }

  // Sixel end sequence: ESC \
  buf.write_string("\u001b\\")
  buf.to_string()
}

///|
/// Convert framebuffer to Sixel string with extended palette
pub fn to_sixel_extended(fb : Framebuffer) -> String {
  let buf = StringBuilder::new()
  let palette = Palette::extended()

  // Sixel start sequence: ESC P q
  buf.write_string("\u001bPq")

  // Define color palette
  for i, color in palette.colors {
    buf.write_string("#")
    buf.write_string(i.to_string())
    buf.write_string(";2;")
    buf.write_string((color.r * 100 / 255).to_string())
    buf.write_string(";")
    buf.write_string((color.g * 100 / 255).to_string())
    buf.write_string(";")
    buf.write_string((color.b * 100 / 255).to_string())
  }

  // Process in bands of 6 pixels height
  let num_bands = (fb.height + 5) / 6
  for band = 0; band < num_bands; band = band + 1 {
    let y_start = band * 6
    for color_idx = 0
        color_idx < palette.colors.length()
        color_idx = color_idx + 1 {
      buf.write_string("#")
      buf.write_string(color_idx.to_string())
      for x = 0; x < fb.width; x = x + 1 {
        let mut sixel_value = 0
        let bit_masks = [1, 2, 4, 8, 16, 32]
        for bit = 0; bit < 6; bit = bit + 1 {
          let y = y_start + bit
          if y < fb.height {
            let pixel = fb.get_pixel(x, y)
            if pixel == color_idx {
              sixel_value = sixel_value | bit_masks[bit]
            }
          }
        }
        let ch = (63 + sixel_value).unsafe_to_char()
        buf.write_char(ch)
      }
      buf.write_string("$")
    }
    buf.write_string("-")
  }
  buf.write_string("\u001b\\")
  buf.to_string()
}

///|
/// Render layout tree to Sixel string
pub fn render_layout(
  layout : @types.Layout,
  width : Int,
  height : Int,
) -> String {
  render_layout_with_options(layout, width, height, false)
}

///|
/// Render layout tree to Sixel string with options
pub fn render_layout_with_options(
  layout : @types.Layout,
  width : Int,
  height : Int,
  show_box_model : Bool,
) -> String {
  let fb = Framebuffer::new(width, height)
  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)
  // Render nodes
  if show_box_model {
    render_node_with_box_model(fb, layout, 0.0, 0.0, 0, true)
    to_sixel(fb)
  } else {
    render_node_simple(fb, layout, 0.0, 0.0, 0)
    to_sixel_extended(fb)
  }
}

///|
/// Check if this is a text node
fn is_text_node(id : String) -> Bool {
  id == "#text"
}

///|
/// Simple rendering with depth-based gradient colors
/// Extended palette indices:
///   0: white (background)
///   1-6: depth gradient (light to dark blue)
///   7: text fill (forest green)
///   8: text border (dark green)
///   9: black (borders)
fn render_node_simple(
  fb : Framebuffer,
  layout : @types.Layout,
  parent_x : Double,
  parent_y : Double,
  depth : Int,
) -> Unit {
  let abs_x = parent_x + layout.x
  let abs_y = parent_y + layout.y
  let x = abs_x.to_int()
  let y = abs_y.to_int()
  let w = layout.width.to_int()
  let h = layout.height.to_int()

  // Skip zero-sized nodes
  if w == 0 || h == 0 {
    for child in layout.children {
      render_node_simple(fb, child, abs_x, abs_y, depth + 1)
    }
    return
  }
  if is_text_node(layout.id) {
    // Text nodes: render actual text content if available
    fb.fill_rect(x, y, w, h, 0) // White background
    match layout.text {
      Some(text_content) => {
        // Draw text using bitmap font (scale 1 = 8x16 pixels per char)
        // Use the layout width directly without padding reduction
        // since text measurement already accounts for the exact text width
        let scale = 1
        let _ = fb.draw_text(x, y, text_content, w, 7, scale)
        // Draw border
        fb.stroke_rect(x, y, w, h, 8) // Dark green border
      }
      None => {
        // Fallback: diagonal hatching for text nodes without content
        fb.fill_rect_hatched(x, y, w, h, 0, 7, 3)
        fb.stroke_rect(x, y, w, h, 8)
      }
    }
  } else {
    // Container nodes: depth-based blue gradient (1-6, clamped)
    let color_idx = if depth < 6 { depth + 1 } else { 6 }
    fb.fill_rect(x, y, w, h, color_idx)
    fb.stroke_rect(x, y, w, h, 9) // Black border
  }

  // Render children
  for child in layout.children {
    render_node_simple(fb, child, abs_x, abs_y, depth + 1)
  }
}

///|
/// Render node with optional box model visualization
fn render_node_with_box_model(
  fb : Framebuffer,
  layout : @types.Layout,
  parent_x : Double,
  parent_y : Double,
  depth : Int,
  show_box_model : Bool,
) -> Unit {
  let abs_x = parent_x + layout.x
  let abs_y = parent_y + layout.y
  let x = abs_x.to_int()
  let y = abs_y.to_int()
  let w = layout.width.to_int()
  let h = layout.height.to_int()

  // Skip zero-sized nodes
  if w == 0 || h == 0 {
    // Still render children
    for child in layout.children {
      render_node_with_box_model(
        fb,
        child,
        abs_x,
        abs_y,
        depth + 1,
        show_box_model,
      )
    }
    return
  }

  // Different rendering for text nodes vs container nodes
  if is_text_node(layout.id) {
    // Render text with diagonal hatching pattern
    fb.fill_rect_hatched(x, y, w, h, 0, 5, 3) // White bg, gray lines, spacing 3
    fb.stroke_rect(x, y, w, h, 6) // Black border
    // Show box model: margin (orange), padding (green), content (blue)
  } else if show_box_model {
    let margin_t = layout.margin.top.to_int()
    let margin_r = layout.margin.right.to_int()
    let margin_b = layout.margin.bottom.to_int()
    let margin_l = layout.margin.left.to_int()
    let padding_t = layout.padding.top.to_int()
    let padding_r = layout.padding.right.to_int()
    let padding_b = layout.padding.bottom.to_int()
    let padding_l = layout.padding.left.to_int()
    let border_t = layout.border.top.to_int()
    let border_r = layout.border.right.to_int()
    let border_b = layout.border.bottom.to_int()
    let border_l = layout.border.left.to_int()

    // Draw margin area (orange/yellow) - color 4
    // Top margin
    if margin_t > 0 {
      fb.fill_rect(
        x - margin_l,
        y - margin_t,
        w + margin_l + margin_r,
        margin_t,
        4,
      )
    }
    // Bottom margin
    if margin_b > 0 {
      fb.fill_rect(x - margin_l, y + h, w + margin_l + margin_r, margin_b, 4)
    }
    // Left margin (excluding corners already covered)
    if margin_l > 0 {
      fb.fill_rect(x - margin_l, y, margin_l, h, 4)
    }
    // Right margin
    if margin_r > 0 {
      fb.fill_rect(x + w, y, margin_r, h, 4)
    }

    // Draw padding area (green) - color 2
    // Content area starts after border
    let content_x = x + border_l + padding_l
    let content_y = y + border_t + padding_t
    let content_w = w - border_l - border_r - padding_l - padding_r
    let content_h = h - border_t - border_b - padding_t - padding_b

    // Top padding
    if padding_t > 0 {
      fb.fill_rect(
        x + border_l,
        y + border_t,
        w - border_l - border_r,
        padding_t,
        2,
      )
    }
    // Bottom padding
    if padding_b > 0 {
      fb.fill_rect(
        x + border_l,
        y + h - border_b - padding_b,
        w - border_l - border_r,
        padding_b,
        2,
      )
    }
    // Left padding
    if padding_l > 0 {
      fb.fill_rect(
        x + border_l,
        y + border_t + padding_t,
        padding_l,
        content_h,
        2,
      )
    }
    // Right padding
    if padding_r > 0 {
      fb.fill_rect(
        x + w - border_r - padding_r,
        y + border_t + padding_t,
        padding_r,
        content_h,
        2,
      )
    }

    // Draw content area (blue) - color 1
    if content_w > 0 && content_h > 0 {
      fb.fill_rect(content_x, content_y, content_w, content_h, 1)
    }

    // Draw border (black outline)
    fb.stroke_rect(x, y, w, h, 6)
  } else {
    // Simple rendering: just fill with depth-based color
    let color = depth % 5 + 1
    fb.fill_rect(x, y, w, h, color)
    fb.stroke_rect(x, y, w, h, 6)
  }

  // Render children
  for child in layout.children {
    render_node_with_box_model(
      fb,
      child,
      abs_x,
      abs_y,
      depth + 1,
      show_box_model,
    )
  }
}

///|
/// Simple print function that outputs sixel to stdout
pub fn print_layout(layout : @types.Layout, width : Int, height : Int) -> Unit {
  let _ = render_layout(layout, width, height)
}

// =============================================================================
// PaintNode-based Rendering with Dynamic Colors
// =============================================================================

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
  colors.push(Color::white())
  { colors, color_map: {} }
}

///|
/// Convert types.Color to sixel Color
fn types_color_to_sixel(c : @types.Color) -> Color {
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
#cfg(target="js")
extern "js" fn framebuffer_to_rgba_base64_js(
  pixels : Array[Int],
  palette_r : Array[Int],
  palette_g : Array[Int],
  palette_b : Array[Int],
) -> String =
  #|(pixels, pr, pg, pb) => {
  #|  const n = pixels.length;
  #|  const buf = new Uint8Array(n * 4);
  #|  for (let i = 0; i < n; i++) {
  #|    const idx = pixels[i];
  #|    const o = i * 4;
  #|    buf[o] = pr[idx] | 0;
  #|    buf[o + 1] = pg[idx] | 0;
  #|    buf[o + 2] = pb[idx] | 0;
  #|    buf[o + 3] = 255;
  #|  }
  #|  if (typeof Buffer === "function") {
  #|    return Buffer.from(buf.buffer, buf.byteOffset, buf.byteLength).toString("base64");
  #|  }
  #|  let s = '';
  #|  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  #|  const len = buf.length;
  #|  let i = 0;
  #|  for (; i + 2 < len; i += 3) {
  #|    const b0 = buf[i], b1 = buf[i+1], b2 = buf[i+2];
  #|    s += chars[b0 >> 2] + chars[((b0 & 3) << 4) | (b1 >> 4)] + chars[((b1 & 15) << 2) | (b2 >> 6)] + chars[b2 & 63];
  #|  }
  #|  if (i + 1 === len) {
  #|    const b0 = buf[i];
  #|    s += chars[b0 >> 2] + chars[(b0 & 3) << 4] + '==';
  #|  } else if (i + 2 === len) {
  #|    const b0 = buf[i], b1 = buf[i+1];
  #|    s += chars[b0 >> 2] + chars[((b0 & 3) << 4) | (b1 >> 4)] + chars[(b1 & 15) << 2] + '=';
  #|  }
  #|  return s;
  #|}

///|
#cfg(not(target="js"))
fn framebuffer_to_rgba_base64_js(
  pixels : Array[Int],
  palette_r : Array[Int],
  palette_g : Array[Int],
  palette_b : Array[Int],
) -> String {
  let rgba : Array[Int] = []
  for idx in pixels {
    rgba.push(palette_r[idx])
    rgba.push(palette_g[idx])
    rgba.push(palette_b[idx])
    rgba.push(255)
  }
  encode_bytes_base64(rgba)
}

///|
pub fn framebuffer_to_rgba_base64(
  fb : Framebuffer,
  palette : DynamicPalette,
) -> String {
  let palette_r : Array[Int] = []
  let palette_g : Array[Int] = []
  let palette_b : Array[Int] = []
  for color in palette.colors {
    palette_r.push(color.r)
    palette_g.push(color.g)
    palette_b.push(color.b)
  }
  framebuffer_to_rgba_base64_js(fb.pixels, palette_r, palette_g, palette_b)
}

///|
fn blend_types_color_over_pixel(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  color : @types.Color,
  opacity : Double,
) -> Unit {
  let alpha = effective_alpha_byte(color, opacity)
  if alpha <= 0 {
    return
  }
  let src = types_color_to_sixel(color)
  if alpha >= 255 {
    let idx = palette.get_or_add(src)
    fb.set_pixel(x, y, idx)
    return
  }
  let dst_idx = fb.get_pixel(x, y)
  let dst = palette_color_at(palette, dst_idx)
  let blended = src.blend(dst, alpha)
  let idx = palette.get_or_add(blended)
  fb.set_pixel(x, y, idx)
}

///|
fn fill_rect_with_types_color(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
) -> Unit {
  let alpha = effective_alpha_byte(color, opacity)
  if alpha <= 0 {
    return
  }
  if alpha >= 255 {
    let idx = palette.get_or_add(types_color_to_sixel(color))
    fb.fill_rect(x, y, w, h, idx)
    return
  }
  for py = y; py < y + h; py = py + 1 {
    for px = x; px < x + w; px = px + 1 {
      blend_types_color_over_pixel(fb, palette, px, py, color, opacity)
    }
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

///|
/// Collect all colors from PaintNode tree
fn collect_colors(palette : DynamicPalette, node : @paint.PaintNode) -> Unit {
  // Add background color if not transparent
  if !node.paint.background_color.is_transparent() {
    let _ = palette.get_or_add(
      types_color_to_sixel(node.paint.background_color),
    )
  }
  // Add text color
  let _ = palette.get_or_add(types_color_to_sixel(node.paint.color))

  // Process children
  for child in node.children {
    collect_colors(palette, child)
  }
}

///|
/// Clip rectangle for overflow clipping.
/// None means no clipping (full framebuffer).
pub(all) struct ClipRect {
  x : Int
  y : Int
  w : Int
  h : Int
}

///|
/// Intersect two clip rectangles. Returns None if they don't overlap.
fn clip_intersect(a : ClipRect, b : ClipRect) -> ClipRect? {
  let x1 = @cmp.maximum(a.x, b.x)
  let y1 = @cmp.maximum(a.y, b.y)
  let x2 = @cmp.minimum(a.x + a.w, b.x + b.w)
  let y2 = @cmp.minimum(a.y + a.h, b.y + b.h)
  if x2 > x1 && y2 > y1 {
    Some({ x: x1, y: y1, w: x2 - x1, h: y2 - y1 })
  } else {
    None
  }
}

///|
/// Check if a pixel is inside the clip rect
fn pixel_in_clip(clip : ClipRect?, px : Int, py : Int) -> Bool {
  match clip {
    None => true
    Some(c) => px >= c.x && px < c.x + c.w && py >= c.y && py < c.y + c.h
  }
}

///|
fn draw_text_decoration_line(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  color : @types.Color,
  clip : ClipRect?,
) -> Unit {
  if y < 0 || y >= fb.height {
    return
  }
  let line_color = palette.get_or_add(types_color_to_sixel(color))
  for px = x; px < x + w && px < fb.width; px = px + 1 {
    if px >= 0 && pixel_in_clip(clip, px, y) {
      fb.set_pixel(px, y, line_color)
    }
  }
}

///|
/// Fill a rect clipped to the given clip rectangle
fn fill_rect_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  match clip {
    None => fill_rect_with_types_color(fb, palette, x, y, w, h, color, opacity)
    Some(c) => {
      let cx1 = @cmp.maximum(x, c.x)
      let cy1 = @cmp.maximum(y, c.y)
      let cx2 = @cmp.minimum(x + w, c.x + c.w)
      let cy2 = @cmp.minimum(y + h, c.y + c.h)
      if cx2 > cx1 && cy2 > cy1 {
        fill_rect_with_types_color(
          fb,
          palette,
          cx1,
          cy1,
          cx2 - cx1,
          cy2 - cy1,
          color,
          opacity,
        )
      }
    }
  }
}

///|

///|
/// Compute coverage (0.0-1.0) for a pixel near a rounded corner boundary.
/// Returns 1.0 if fully inside, 0.0 if fully outside, fractional at the edge.
fn rounded_corner_coverage(
  px : Int,
  py : Int,
  rect_x : Int,
  rect_y : Int,
  rect_w : Int,
  rect_h : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Double {
  let lx = px - rect_x
  let ly = py - rect_y
  // Check each corner; if pixel is not in any corner zone, fully inside
  // Top-left corner
  if tl > 0 && lx < tl && ly < tl {
    let dx = (tl - lx).to_double() - 0.5
    let dy = (tl - ly).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = tl.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  // Top-right corner
  if tr > 0 && lx >= rect_w - tr && ly < tr {
    let dx = (lx - (rect_w - tr - 1)).to_double() - 0.5
    let dy = (tr - ly).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = tr.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  // Bottom-right corner
  if br > 0 && lx >= rect_w - br && ly >= rect_h - br {
    let dx = (lx - (rect_w - br - 1)).to_double() - 0.5
    let dy = (ly - (rect_h - br - 1)).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = br.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  // Bottom-left corner
  if bl > 0 && lx < bl && ly >= rect_h - bl {
    let dx = (bl - lx).to_double() - 0.5
    let dy = (ly - (rect_h - bl - 1)).to_double() - 0.5
    let dist = (dx * dx + dy * dy).sqrt()
    let r = bl.to_double()
    if dist >= r + 0.5 {
      return 0.0
    }
    if dist <= r - 0.5 {
      return 1.0
    }
    return r + 0.5 - dist
  }
  1.0
}

///|
/// Fill a rounded rect (with optional clip)
fn fill_rounded_rect_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  let alpha = effective_alpha_byte(color, opacity)
  if alpha <= 0 {
    return
  }
  let src = types_color_to_sixel(color)
  // Determine draw bounds (intersect with clip)
  let x1 = match clip {
    Some(c) => @cmp.maximum(x, c.x)
    None => x
  }
  let y1 = match clip {
    Some(c) => @cmp.maximum(y, c.y)
    None => y
  }
  let x2 = match clip {
    Some(c) => @cmp.minimum(x + w, c.x + c.w)
    None => x + w
  }
  let y2 = match clip {
    Some(c) => @cmp.minimum(y + h, c.y + c.h)
    None => y + h
  }
  if x2 <= x1 || y2 <= y1 {
    return
  }
  let has_radius = tl > 0 || tr > 0 || br > 0 || bl > 0
  if has_radius {
    // Antialiased rounded corners: use coverage-based blending
    let idx = palette.get_or_add(src)
    for py = y1; py < y2; py = py + 1 {
      for px = x1; px < x2; px = px + 1 {
        let cov = rounded_corner_coverage(px, py, x, y, w, h, tl, tr, br, bl)
        if cov <= 0.0 {
          continue
        }
        let effective_alpha = cov * opacity
        if effective_alpha >= 1.0 {
          fb.set_pixel(px, py, idx)
        } else if effective_alpha > 0.0 {
          // Blend foreground with background using coverage
          let dst_idx = fb.get_pixel(px, py)
          let dst = palette_color_at(palette, dst_idx)
          let a_byte = (effective_alpha * 255.0).to_int()
          let blended = src.blend(dst, a_byte)
          let blended_idx = palette.get_or_add(blended)
          fb.set_pixel(px, py, blended_idx)
        }
      }
    }
  } else if alpha >= 255 {
    let idx = palette.get_or_add(src)
    for py = y1; py < y2; py = py + 1 {
      for px = x1; px < x2; px = px + 1 {
        fb.set_pixel(px, py, idx)
      }
    }
  } else {
    for py = y1; py < y2; py = py + 1 {
      for px = x1; px < x2; px = px + 1 {
        blend_types_color_over_pixel(fb, palette, px, py, color, opacity)
      }
    }
  }
}

///|
/// Interpolate between two colors at position t (0.0-1.0)
fn lerp_color(a : @types.Color, b : @types.Color, t : Double) -> @types.Color {
  let r = (a.r.to_double() * (1.0 - t) + b.r.to_double() * t).to_int()
  let g = (a.g.to_double() * (1.0 - t) + b.g.to_double() * t).to_int()
  let b_val = (a.b.to_double() * (1.0 - t) + b.b.to_double() * t).to_int()
  let alpha = a.a * (1.0 - t) + b.a * t
  @types.Color::rgba(clamp_byte(r), clamp_byte(g), clamp_byte(b_val), alpha)
}

///|
/// Sample a gradient at position t (0.0-1.0)
fn sample_gradient(grad : @types.LinearGradient, t : Double) -> @types.Color {
  let stops = grad.stops
  if stops.length() == 0 {
    return @types.Color::transparent()
  }
  if t <= stops[0].position {
    return stops[0].color
  }
  let last = stops.length() - 1
  if t >= stops[last].position {
    return stops[last].color
  }
  // Find the two stops that bracket t
  for i = 0; i < last; i = i + 1 {
    if t >= stops[i].position && t <= stops[i + 1].position {
      let range = stops[i + 1].position - stops[i].position
      let local_t = if range > 0.0 {
        (t - stops[i].position) / range
      } else {
        0.0
      }
      return lerp_color(stops[i].color, stops[i + 1].color, local_t)
    }
  }
  stops[last].color
}

///|
/// Fill a rect with a linear gradient (with optional clip and border-radius)
fn fill_linear_gradient_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  grad : @types.LinearGradient,
  opacity : Double,
  clip : ClipRect?,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  // Determine draw bounds
  let x1 = match clip {
    Some(c) => @cmp.maximum(x, c.x)
    None => x
  }
  let y1 = match clip {
    Some(c) => @cmp.maximum(y, c.y)
    None => y
  }
  let x2 = match clip {
    Some(c) => @cmp.minimum(x + w, c.x + c.w)
    None => x + w
  }
  let y2 = match clip {
    Some(c) => @cmp.minimum(y + h, c.y + c.h)
    None => y + h
  }
  if x2 <= x1 || y2 <= y1 {
    return
  }
  let has_radius = tl > 0 || tr > 0 || br > 0 || bl > 0
  // Convert angle to direction vector
  // CSS gradient angles: 0deg = to top, 90deg = to right, 180deg = to bottom
  let pi = 3.14159265358979
  let rad = (grad.angle_deg - 90.0) * pi / 180.0
  let dx = @math.cos(rad)
  let dy = @math.sin(rad)
  // Project rect corners onto gradient line to find the extent
  let cx = w.to_double() / 2.0
  let cy = h.to_double() / 2.0
  let half_len = (cx * dx.abs() + cy * dy.abs()).abs()
  let inv_len = if half_len > 0.001 { 1.0 / (2.0 * half_len) } else { 0.0 }
  for py = y1; py < y2; py = py + 1 {
    let fy = (py - y).to_double() - cy
    for px = x1; px < x2; px = px + 1 {
      let cov = if has_radius {
        rounded_corner_coverage(px, py, x, y, w, h, tl, tr, br, bl)
      } else {
        1.0
      }
      if cov <= 0.0 {
        continue
      }
      let fx = (px - x).to_double() - cx
      let proj = fx * dx + fy * dy
      let t = (proj + half_len) * inv_len
      // Clamp t
      let tc = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
      let color = sample_gradient(grad, tc)
      if color.a > 0.0 {
        let effective_opacity = opacity * cov
        if effective_opacity >= 1.0 && color.a >= 1.0 {
          let idx = palette.get_or_add(types_color_to_sixel(color))
          fb.set_pixel(px, py, idx)
        } else {
          blend_types_color_over_pixel(
            fb, palette, px, py, color, effective_opacity,
          )
        }
      }
    }
  }
}

///|
/// Resolve border-radius value: negative means percentage of reference dimension
fn resolve_radius(val : Double, ref_dim : Int) -> Int {
  if val < 0.0 {
    // Negative encodes percentage: -0.5 means 50%
    let frac = -val
    (frac * ref_dim.to_double()).to_int()
  } else {
    val.to_int()
  }
}

///|
/// Render a PaintNode tree to framebuffer
fn render_paint_node(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint.PaintNode,
  parent_x : Double,
  parent_y : Double,
) -> Unit {
  render_paint_node_clipped(fb, palette, node, parent_x, parent_y, None)
}

///|
/// Render a PaintNode tree to framebuffer with optional clip rect
fn render_paint_node_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint.PaintNode,
  parent_x : Double,
  parent_y : Double,
  clip : ClipRect?,
) -> Unit {
  // Skip invisible nodes
  if !node.paint.should_render() {
    return
  }
  let abs_x = parent_x + node.x
  let abs_y = parent_y + node.y
  let x = abs_x.to_int()
  let y = abs_y.to_int()
  let w = node.width.to_int()
  let h = node.height.to_int()

  // Skip zero-sized nodes
  if w <= 0 || h <= 0 {
    for child in node.children {
      render_paint_node_clipped(fb, palette, child, abs_x, abs_y, clip)
    }
    return
  }

  // Skip "visually hidden" accessibility pattern:
  // Elements with clip/overflow clipping and very small size (1px x 1px)
  if node.clips_content() && w <= 1 && h <= 1 {
    return
  }

  // Skip very small elements that are likely visually hidden
  if w <= 1 && h <= 1 {
    return
  }
  if w <= 1 && node.tag == "#text" {
    return
  }

  // Skip nodes entirely outside the framebuffer
  if x >= fb.width || y >= fb.height || x + w <= 0 || y + h <= 0 {
    return
  }
  // If there's a clip rect, check if this node is fully outside it
  match clip {
    Some(c) =>
      if x >= c.x + c.w || y >= c.y + c.h || x + w <= c.x || y + h <= c.y {
        return
      }
    None => ()
  }

  // Compute border-radius values (negative means percentage)
  // Clamp to half of element dimensions per CSS spec
  let min_dim = @cmp.minimum(w, h)
  let max_r = min_dim / 2
  let tl_r = resolve_radius(node.paint.border_top_left_radius, min_dim).min(
    max_r,
  )
  let tr_r = resolve_radius(node.paint.border_top_right_radius, min_dim).min(
    max_r,
  )
  let br_r = resolve_radius(node.paint.border_bottom_right_radius, min_dim).min(
    max_r,
  )
  let bl_r = resolve_radius(node.paint.border_bottom_left_radius, min_dim).min(
    max_r,
  )
  let has_radius = tl_r > 0 || tr_r > 0 || br_r > 0 || bl_r > 0

  // Draw background: gradient or solid color
  match node.paint.background_image {
    @types.Gradient(grad) =>
      fill_linear_gradient_clipped(
        fb,
        palette,
        x,
        y,
        w,
        h,
        grad,
        node.paint.opacity,
        clip,
        tl_r,
        tr_r,
        br_r,
        bl_r,
      )
    @types.None =>
      if !node.paint.background_color.is_transparent() {
        if has_radius {
          fill_rounded_rect_clipped(
            fb,
            palette,
            x,
            y,
            w,
            h,
            node.paint.background_color,
            node.paint.opacity,
            clip,
            tl_r,
            tr_r,
            br_r,
            bl_r,
          )
        } else {
          fill_rect_clipped(
            fb,
            palette,
            x,
            y,
            w,
            h,
            node.paint.background_color,
            node.paint.opacity,
            clip,
          )
        }
      }
  }

  // Draw borders
  let bt = node.paint.border_top_width.to_int()
  let br = node.paint.border_right_width.to_int()
  let bb = node.paint.border_bottom_width.to_int()
  let bl = node.paint.border_left_width.to_int()
  let opacity = node.paint.opacity
  if bt > 0 && !node.paint.border_top_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x,
      y,
      w,
      bt,
      node.paint.border_top_color,
      opacity,
      clip,
    )
  }
  if bb > 0 && !node.paint.border_bottom_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x,
      y + h - bb,
      w,
      bb,
      node.paint.border_bottom_color,
      opacity,
      clip,
    )
  }
  if bl > 0 && !node.paint.border_left_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x,
      y + bt,
      bl,
      h - bt - bb,
      node.paint.border_left_color,
      opacity,
      clip,
    )
  }
  if br > 0 && !node.paint.border_right_color.is_transparent() {
    fill_rect_clipped(
      fb,
      palette,
      x + w - br,
      y + bt,
      br,
      h - bt - bb,
      node.paint.border_right_color,
      opacity,
      clip,
    )
  }

  // Draw inline SVG image if this is an <img> with SVG data URI src
  if node.tag == "img" && w > 0 && h > 0 {
    match node.src {
      Some(src) =>
        if src.has_prefix("data:image/svg+xml") {
          let svg_text = decode_svg_data_uri(src)
          if svg_text.length() > 0 {
            render_svg_into_region(fb, palette, svg_text, x, y, w, h, clip)
          }
        }
      None => ()
    }
  }
  // Draw text if this is a text node
  match node.text {
    Some(text_content) =>
      match glyph_provider_override.val {
        Some(provider) => {
          let svg_color = @svg.Color::rgb(
            node.paint.color.r,
            node.paint.color.g,
            node.paint.color.b,
          )
          let font_size = node.paint.font_size
          let _ = draw_text_with_glyphs_clipped(
            fb,
            palette,
            provider,
            x,
            y,
            text_content,
            w,
            svg_color,
            font_size,
            font_size,
            node.paint.is_bold,
            clip,
            font_family=node.paint.font_family,
          )
        }
        None => {
          let text_idx = palette.get_or_add(
            types_color_to_sixel(node.paint.color),
          )
          let scale = 1
          let _ = draw_text_clipped(
            fb, x, y, text_content, w, text_idx, scale, clip,
          )
        }
      }
    None => ()
  }
  // Draw text decorations
  match node.text {
    Some(_) => {
      let font_size = node.paint.font_size
      if node.paint.text_decoration_overline {
        draw_text_decoration_line(
          fb,
          palette,
          x,
          y + (font_size * 0.15).to_int(),
          w,
          node.paint.color,
          clip,
        )
      }
      if node.paint.text_decoration_line_through {
        draw_text_decoration_line(
          fb,
          palette,
          x,
          y + (font_size * 0.6).to_int(),
          w,
          node.paint.color,
          clip,
        )
      }
      if node.paint.text_decoration_underline {
        draw_text_decoration_line(
          fb,
          palette,
          x,
          y + (font_size * 1.1).to_int(),
          w,
          node.paint.color,
          clip,
        )
      }
    }
    None => ()
  }

  // Compute child clip: if this node clips content, intersect with current clip
  let child_clip = if node.clips_content() {
    let node_clip : ClipRect = { x, y, w, h }
    match clip {
      None => Some(node_clip)
      Some(parent_clip) => clip_intersect(parent_clip, node_clip)
    }
  } else {
    clip
  }

  // If clip intersection is empty, skip all children
  match (node.clips_content(), child_clip) {
    (true, None) => return
    _ => ()
  }

  // Render children with (possibly narrowed) clip
  // Propagate opacity to children (CSS opacity affects entire subtree)
  if node.paint.opacity < 1.0 {
    for child in node.children {
      let child_with_opacity = {
        ..child,
        paint: {
          ..child.paint,
          opacity: child.paint.opacity * node.paint.opacity,
        },
      }
      render_paint_node_clipped(
        fb, palette, child_with_opacity, abs_x, abs_y, child_clip,
      )
    }
  } else {
    for child in node.children {
      render_paint_node_clipped(fb, palette, child, abs_x, abs_y, child_clip)
    }
  }
}

///|
/// Decode SVG data URI to SVG text
fn decode_svg_data_uri(src : String) -> String {
  // Handle data:image/svg+xml,<svg>...</svg> (URL-encoded)
  // and data:image/svg+xml;utf8,<svg>...</svg>
  let prefixes = [
    "data:image/svg+xml,", "data:image/svg+xml;utf8,", "data:image/svg+xml;charset=utf-8,",
  ]
  for prefix in prefixes {
    if src.has_prefix(prefix) {
      let encoded = src.unsafe_substring(
        start=prefix.length(),
        end=src.length(),
      )
      return url_decode_simple(encoded)
    }
  }
  // data:image/svg+xml;base64,... not handled yet
  ""
}

///|
/// Simple URL decode (%XX → char)
fn url_decode_simple(s : String) -> String {
  let buf = StringBuilder::new()
  let chars = s.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if chars[i] == '%' && i + 2 < len {
      let hi = hex_digit(chars[i + 1])
      let lo = hex_digit(chars[i + 2])
      if hi >= 0 && lo >= 0 {
        buf.write_char((hi * 16 + lo).unsafe_to_char())
        i = i + 3
        continue
      }
    }
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
fn hex_digit(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// Render SVG into a region of the framebuffer
fn render_svg_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  svg_text : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
) -> Unit {
  let svg_node = match @svg.parse_svg(svg_text) {
    Some(n) => n
    None => return
  }
  let scene = @svg.Scene::new(svg_node)
  let bounds = scene.get_bounds()
  let vw = bounds.width()
  let vh = bounds.height()
  if vw <= 0.0 || vh <= 0.0 {
    return
  }
  // Render SVG to temporary framebuffer at target size
  let tmp_fb = Framebuffer::new(w, h)
  let tmp_palette = DynamicPalette::new()
  tmp_fb.fill_rect(0, 0, w, h, 0)
  let camera = @svg.Camera::new(w, h)
  camera.set_position(vw / 2.0, vh / 2.0)
  let zoom = (w.to_double() / vw).min(h.to_double() / vh)
  camera.set_zoom(zoom)
  render_svg_scene_with_camera(scene, tmp_fb, tmp_palette, camera)
  // Blit temporary framebuffer into main framebuffer
  for py = 0; py < h; py = py + 1 {
    let dst_y = y + py
    if dst_y < 0 || dst_y >= fb.height {
      continue
    }
    for px = 0; px < w; px = px + 1 {
      let dst_x = x + px
      if dst_x < 0 || dst_x >= fb.width {
        continue
      }
      if !pixel_in_clip(clip, dst_x, dst_y) {
        continue
      }
      let tmp_idx = tmp_fb.pixels[py * w + px]
      if tmp_idx > 0 {
        // Non-white pixel: map from tmp palette to main palette
        let color = if tmp_idx < tmp_palette.colors.length() {
          tmp_palette.colors[tmp_idx]
        } else {
          Color::white()
        }
        let main_idx = palette.get_or_add(color)
        fb.set_pixel(dst_x, dst_y, main_idx)
      }
    }
  }
}

///|
/// Convert framebuffer to Sixel string with dynamic palette
pub fn to_sixel_dynamic(fb : Framebuffer, palette : DynamicPalette) -> String {
  let buf = StringBuilder::new()
  let palette_len = palette.colors.length()

  // Sixel start sequence: ESC P q
  buf.write_string("\u001bPq")

  // Define color palette
  for i, color in palette.colors {
    buf.write_string("#")
    buf.write_string(i.to_string())
    buf.write_string(";2;")
    buf.write_string((color.r * 100 / 255).to_string())
    buf.write_string(";")
    buf.write_string((color.g * 100 / 255).to_string())
    buf.write_string(";")
    buf.write_string((color.b * 100 / 255).to_string())
  }

  // Process in bands of 6 pixels height
  let num_bands = (fb.height + 5) / 6
  for band = 0; band < num_bands; band = band + 1 {
    let y_start = band * 6
    let active_colors = Array::make(palette_len, false)
    let band_rows = Array::make(palette_len * fb.width, 0)
    for bit = 0; bit < 6; bit = bit + 1 {
      let y = y_start + bit
      if y >= fb.height {
        continue
      }
      let row_offset = y * fb.width
      let bit_mask = sixel_bit_masks[bit]
      for x = 0; x < fb.width; x = x + 1 {
        let color_idx = fb.pixels[row_offset + x]
        active_colors[color_idx] = true
        let cell_idx = color_idx * fb.width + x
        band_rows[cell_idx] = band_rows[cell_idx] | bit_mask
      }
    }
    for color_idx = 0; color_idx < palette_len; color_idx = color_idx + 1 {
      if !active_colors[color_idx] {
        continue
      }
      buf.write_string("#")
      buf.write_string(color_idx.to_string())
      let row_base = color_idx * fb.width
      write_sixel_row_compressed(buf, band_rows, row_base, fb.width)
      buf.write_string("$")
    }
    buf.write_string("-")
  }
  buf.write_string("\u001b\\")
  buf.to_string()
}

///|
/// Render PaintNode tree to Sixel string with actual CSS colors
pub fn render_paint_node_to_sixel(
  node : @paint.PaintNode,
  width : Int,
  height : Int,
) -> String {
  let fb = Framebuffer::new(width, height)
  let palette = DynamicPalette::new()

  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)

  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint.sort_tree_by_stacking_order(node)

  // Collect all colors first
  collect_colors(palette, sorted_node)

  // Render the tree
  render_paint_node(fb, palette, sorted_node, 0.0, 0.0)

  // Convert to Sixel
  to_sixel_dynamic(fb, palette)
}

///|
/// Render Node + Layout to Sixel string with CSS colors
pub fn render_with_styles(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
) -> String {
  let paint_node = @paint.from_node_and_layout(node, layout)
  render_paint_node_to_sixel(paint_node, width, height)
}

///|
/// Render PaintNode tree to Sixel string with scroll offset
pub fn render_paint_node_to_sixel_scrolled(
  node : @paint.PaintNode,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  let fb = Framebuffer::new(width, height)
  let palette = DynamicPalette::new()
  render_paint_node_to_framebuffer_scrolled(node, fb, palette, scroll_y)
  // Convert to Sixel
  to_sixel_dynamic(fb, palette)
}

///|
/// Render PaintNode tree to framebuffer with scroll offset
pub fn render_paint_node_to_framebuffer_scrolled(
  node : @paint.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
  scroll_y : Int,
) -> Unit {
  // Fill with white background
  fb.fill_rect(0, 0, fb.width, fb.height, 0)
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint.sort_tree_by_stacking_order(node)
  // Collect all colors first
  collect_colors(palette, sorted_node)
  // CSS canvas background propagation (CSS 2.1 §14.2):
  // If root (<html>) background is transparent, use <body> background instead
  let mut canvas_bg = sorted_node.paint.background_color
  if canvas_bg.is_transparent() {
    for child in sorted_node.children {
      if child.tag == "body" && !child.paint.background_color.is_transparent() {
        canvas_bg = child.paint.background_color
        break
      }
    }
  }
  if !canvas_bg.is_transparent() {
    let bg_sixel = { r: canvas_bg.r, g: canvas_bg.g, b: canvas_bg.b }
    let bg_idx = palette.get_or_add(bg_sixel)
    fb.fill_rect(0, 0, fb.width, fb.height, bg_idx)
  }
  // Render the tree with scroll offset
  render_paint_node(fb, palette, sorted_node, 0.0, -scroll_y.to_double())
}

///|
/// Render Node + Layout to Sixel string with CSS colors and scroll offset
pub fn render_with_styles_scrolled(
  node : @node.Node,
  layout : @types.Layout,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  let paint_node = @paint.from_node_and_layout(node, layout)
  render_paint_node_to_sixel_scrolled(paint_node, width, height, scroll_y)
}

///|
/// Render PaintNode tree to framebuffer (for use by other renderers like Kitty)
pub fn render_paint_node_to_framebuffer(
  node : @paint.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
) -> Unit {
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint.sort_tree_by_stacking_order(node)
  // Collect all colors first
  collect_colors(palette, sorted_node)
  // CSS canvas background propagation (CSS 2.1 §14.2):
  // If root (<html>) background is transparent, use <body> background instead
  let mut canvas_bg = sorted_node.paint.background_color
  if canvas_bg.is_transparent() {
    // Look for body element among root's children
    for child in sorted_node.children {
      if child.tag == "body" && !child.paint.background_color.is_transparent() {
        canvas_bg = child.paint.background_color
        break
      }
    }
  }
  if !canvas_bg.is_transparent() {
    let bg_sixel = { r: canvas_bg.r, g: canvas_bg.g, b: canvas_bg.b }
    let bg_idx = palette.get_or_add(bg_sixel)
    fb.fill_rect(0, 0, fb.width, fb.height, bg_idx)
  }
  // Render the tree
  render_paint_node(fb, palette, sorted_node, 0.0, 0.0)
}
