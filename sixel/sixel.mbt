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
  let colors = [Color::blue(), Color::green(), Color::yellow(), Color::red(), Color::gray()]
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
fn Framebuffer::set_pixel(self : Framebuffer, x : Int, y : Int, color : Int) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    self.pixels[y * self.width + x] = color
  }
}

///|
fn Framebuffer::get_pixel(self : Framebuffer, x : Int, y : Int) -> Int {
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
  color : Int
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
  color : Int
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
/// Color palette for Sixel output
priv struct Palette {
  colors : Array[Color]
}

///|
fn Palette::new() -> Palette {
  { colors: [Color::white(), Color::blue(), Color::green(), Color::yellow(), Color::red(), Color::gray(), Color::black()] }
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
    for color_idx = 0; color_idx < palette.colors.length(); color_idx = color_idx + 1 {
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
              sixel_value = sixel_value.lor(bit_masks[bit])
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
/// Render layout tree to Sixel string
pub fn render_layout(
  layout : @node.Layout,
  width : Int,
  height : Int
) -> String {
  let fb = Framebuffer::new(width, height)
  // Fill with white background
  fb.fill_rect(0, 0, width, height, 0)
  // Render nodes
  render_node(fb, layout, 0.0, 0.0, 0)
  to_sixel(fb)
}

///|
/// Check if this is a text node
fn is_text_node(id : String) -> Bool {
  id == "#text"
}

///|
fn render_node(
  fb : Framebuffer,
  layout : @node.Layout,
  parent_x : Double,
  parent_y : Double,
  depth : Int
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
      render_node(fb, child, abs_x, abs_y, depth + 1)
    }
    return
  }

  // Different rendering for text nodes vs container nodes
  if is_text_node(layout.id) {
    // Render text as a dark gray filled rectangle (placeholder for actual text)
    fb.fill_rect(x, y, w, h, 5) // Gray color (index 5)
  } else {
    // Color index based on depth (1-5)
    let color = (depth % 5) + 1

    // Fill with semi-transparent color (we can't do real alpha in sixel, so just fill)
    fb.fill_rect(x, y, w, h, color)
    // Draw border
    fb.stroke_rect(x, y, w, h, 6) // Black border
  }

  // Render children
  for child in layout.children {
    render_node(fb, child, abs_x, abs_y, depth + 1)
  }
}

///|
/// Simple print function that outputs sixel to stdout
pub fn print_layout(layout : @node.Layout, width : Int, height : Int) -> Unit {
  let sixel = render_layout(layout, width, height)
  println(sixel)
}
