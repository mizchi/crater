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
fn Framebuffer::fill_span(
  self : Framebuffer,
  y : Int,
  x1 : Int,
  x2 : Int,
  color : Int,
) -> Unit {
  if y < 0 || y >= self.height {
    return
  }
  let cx1 = @cmp.maximum(x1, 0)
  let cx2 = @cmp.minimum(x2, self.width)
  if cx2 <= cx1 {
    return
  }
  let row = y * self.width
  for px = cx1; px < cx2; px = px + 1 {
    self.pixels[row + px] = color
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
  if w <= 0 || h <= 0 {
    return
  }
  let x1 = @cmp.maximum(x, 0)
  let y1 = @cmp.maximum(y, 0)
  let x2 = @cmp.minimum(x + w, self.width)
  let y2 = @cmp.minimum(y + h, self.height)
  if x2 <= x1 || y2 <= y1 {
    return
  }
  for py = y1; py < y2; py = py + 1 {
    let row = py * self.width
    for px = x1; px < x2; px = px + 1 {
      self.pixels[row + px] = color
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
