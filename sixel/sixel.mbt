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
  layout : @node.Layout,
  width : Int,
  height : Int,
) -> String {
  render_layout_with_options(layout, width, height, false)
}

///|
/// Render layout tree to Sixel string with options
pub fn render_layout_with_options(
  layout : @node.Layout,
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
  layout : @node.Layout,
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
    // Text nodes: diagonal hatching pattern (white bg with green lines)
    fb.fill_rect_hatched(x, y, w, h, 0, 7, 3) // White bg, forest green lines, spacing 3
    fb.stroke_rect(x, y, w, h, 8) // Dark green border
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
  layout : @node.Layout,
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
pub fn print_layout(layout : @node.Layout, width : Int, height : Int) -> Unit {
  let sixel = render_layout(layout, width, height)
  println(sixel)
}
