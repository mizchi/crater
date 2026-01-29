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
/// Hash a color for map lookup
fn color_hash(c : Color) -> Int {
  c.r * 65536 + c.g * 256 + c.b
}

///|
/// Get or add a color to the palette, returns palette index
fn DynamicPalette::get_or_add(self : DynamicPalette, c : Color) -> Int {
  let hash = color_hash(c)
  match self.color_map.get(hash) {
    Some(idx) => idx
    None => {
      let idx = self.colors.length()
      // Sixel supports up to 256 colors
      if idx < 256 {
        self.colors.push(c)
        self.color_map.set(hash, idx)
        idx
      } else {
        // Fallback: find closest color (simple approach: return last)
        idx - 1
      }
    }
  }
}

///|
/// Collect all colors from PaintNode tree
fn collect_colors(palette : DynamicPalette, node : @paint.PaintNode) -> Unit {
  // Add background color if not transparent
  if not(node.paint.background_color.is_transparent()) {
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
/// Render a PaintNode tree to framebuffer
fn render_paint_node(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint.PaintNode,
  parent_x : Double,
  parent_y : Double,
) -> Unit {
  // Skip invisible nodes
  if not(node.paint.should_render()) {
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
      render_paint_node(fb, palette, child, abs_x, abs_y)
    }
    return
  }

  // Skip "visually hidden" accessibility pattern:
  // Elements with clip/overflow clipping and very small size (1px x 1px)
  // This is commonly used to hide content visually while keeping it for screen readers
  if node.clips_content() && w <= 1 && h <= 1 {
    return
  }

  // WORKAROUND: Skip very small elements that are likely visually hidden
  // TODO: Properly implement clip rect rendering and overflow clipping
  // - 1x1 or smaller elements (common visually hidden pattern)
  // - Text nodes with width <= 1 (text inside visually hidden containers)
  if w <= 1 && h <= 1 {
    return
  }
  if w <= 1 && node.tag == "#text" {
    return
  }

  // Draw background if not transparent
  if not(node.paint.background_color.is_transparent()) {
    let bg_idx = palette.get_or_add(
      types_color_to_sixel(node.paint.background_color),
    )
    fb.fill_rect(x, y, w, h, bg_idx)
  }

  // Draw text if this is a text node
  match node.text {
    Some(text_content) => {
      let text_idx = palette.get_or_add(types_color_to_sixel(node.paint.color))
      let scale = 1
      let _ = fb.draw_text(x, y, text_content, w, text_idx, scale)

    }
    None => ()
  }

  // Draw border (1px black outline for non-text nodes)
  if node.tag != "#text" && w > 2 && h > 2 {
    let border_color : Color = { r: 0, g: 0, b: 0 }
    let border_idx = palette.get_or_add(border_color)
    fb.stroke_rect(x, y, w, h, border_idx)
  }

  // Render children
  for child in node.children {
    render_paint_node(fb, palette, child, abs_x, abs_y)
  }
}

///|
/// Convert framebuffer to Sixel string with dynamic palette
pub fn to_sixel_dynamic(fb : Framebuffer, palette : DynamicPalette) -> String {
  let buf = StringBuilder::new()

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
  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint.sort_tree_by_stacking_order(node)
  // Collect all colors first
  collect_colors(palette, sorted_node)
  // Render the tree with scroll offset
  render_paint_node(fb, palette, sorted_node, 0.0, -scroll_y.to_double())
  // Convert to Sixel
  to_sixel_dynamic(fb, palette)
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
  // Render the tree
  render_paint_node(fb, palette, sorted_node, 0.0, 0.0)
}
