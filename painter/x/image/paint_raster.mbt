///|
/// Framebuffer and paint tree rasterization for image outputs.
/// Terminal protocols are encoded by crater-painter-terminal packages.

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
  let src = types_color_to_image(color)
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
fn blend_raster_color_over_pixel(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  color : Color,
  alpha : Int,
) -> Unit {
  let a = clamp_byte(alpha)
  if a <= 0 {
    return
  }
  if a >= 255 {
    let idx = palette.get_or_add(color)
    fb.set_pixel(x, y, idx)
    return
  }
  let dst_idx = fb.get_pixel(x, y)
  let dst = palette_color_at(palette, dst_idx)
  let blended = color.blend(dst, a)
  let idx = palette.get_or_add(blended)
  fb.set_pixel(x, y, idx)
}

///|
fn ensure_blend_cache_size(cache : Array[Int], idx : Int) -> Unit {
  while idx >= cache.length() {
    cache.push(-1)
  }
}

///|
fn cached_blended_index(
  palette : DynamicPalette,
  color : Color,
  alpha : Int,
  dst_idx : Int,
  cache : Array[Int],
) -> Int {
  if dst_idx < 0 {
    let dst = Color::white()
    let blended = color.blend(dst, alpha)
    return palette.get_or_add(blended)
  }
  ensure_blend_cache_size(cache, dst_idx)
  match cache[dst_idx] {
    cached if cached >= 0 => cached
    _ => {
      let dst = palette_color_at(palette, dst_idx)
      let blended = color.blend(dst, alpha)
      let idx = palette.get_or_add(blended)
      cache[dst_idx] = idx
      idx
    }
  }
}

///|
fn blend_span_with_raster_color(
  fb : Framebuffer,
  palette : DynamicPalette,
  y : Int,
  x1 : Int,
  x2 : Int,
  color : Color,
  alpha : Int,
  cache : Array[Int],
) -> Unit {
  let a = clamp_byte(alpha)
  if a <= 0 {
    return
  }
  if a >= 255 {
    let idx = palette.get_or_add(color)
    fb.fill_span(y, x1, x2, idx)
    return
  }
  if y < 0 || y >= fb.height {
    return
  }
  let cx1 = @cmp.maximum(x1, 0)
  let cx2 = @cmp.minimum(x2, fb.width)
  if cx2 <= cx1 {
    return
  }
  let row = y * fb.width
  for px = cx1; px < cx2; px = px + 1 {
    let pos = row + px
    let dst_idx = fb.pixels[pos]
    let blended_idx = cached_blended_index(palette, color, a, dst_idx, cache)
    fb.pixels[pos] = blended_idx
  }
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
    let idx = palette.get_or_add(types_color_to_image(color))
    fb.fill_rect(x, y, w, h, idx)
    return
  }
  let x1 = @cmp.maximum(x, 0)
  let y1 = @cmp.maximum(y, 0)
  let x2 = @cmp.minimum(x + w, fb.width)
  let y2 = @cmp.minimum(y + h, fb.height)
  if x2 <= x1 || y2 <= y1 {
    return
  }
  let src = types_color_to_image(color)
  let cache = Array::make(palette.colors.length(), -1)
  for py = y1; py < y2; py = py + 1 {
    blend_span_with_raster_color(fb, palette, py, x1, x2, src, alpha, cache)
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
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  if y < 0 || y >= fb.height {
    return
  }
  for px = x; px < x + w && px < fb.width; px = px + 1 {
    if px >= 0 && pixel_in_clip(clip, px, y) {
      blend_types_color_over_pixel(fb, palette, px, y, color, opacity)
    }
  }
}

///|
fn resolve_text_render_box(
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> (Int, Int, Int) {
  if node.tag == "input" {
    let inset = @cmp.maximum(2, (node.paint.font_size * 0.75).round().to_int())
    let vertical_offset = @cmp.maximum(
      0,
      ((h.to_double() - node.paint.font_size) / 2.0).round().to_int(),
    )
    (x + inset, y + vertical_offset, @cmp.maximum(0, w - inset * 2))
  } else {
    (x, y, w)
  }
}

///|
fn resolve_glyph_text_wrap_width(
  w : Int,
  h : Int,
  font_size : Double,
  text : String,
) -> Int {
  if h.to_double() <= font_size * 1.3 && text.length() <= 72 {
    0
  } else {
    w
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
fn fill_box_shadow_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
  spread : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  if w <= 0 || h <= 0 || color.is_transparent() {
    return
  }
  let draw_tl = @cmp.maximum(tl + spread, 0)
  let draw_tr = @cmp.maximum(tr + spread, 0)
  let draw_br = @cmp.maximum(br + spread, 0)
  let draw_bl = @cmp.maximum(bl + spread, 0)
  let has_radius = draw_tl > 0 || draw_tr > 0 || draw_br > 0 || draw_bl > 0
  if has_radius {
    fill_rounded_rect_clipped(
      fb, palette, x, y, w, h, color, opacity, clip, draw_tl, draw_tr, draw_br, draw_bl,
    )
  } else {
    fill_rect_clipped(fb, palette, x, y, w, h, color, opacity, clip)
  }
}

///|
fn blurred_shadow_layer_count(blur : Int) -> Int {
  let by_radius = blur / 8 + 4
  if by_radius < 4 {
    4
  } else if by_radius > 12 {
    12
  } else {
    by_radius
  }
}

///|
fn fill_blurred_box_shadow_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : @types.Color,
  opacity : Double,
  clip : ClipRect?,
  spread : Int,
  blur : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  if blur <= 0 {
    fill_box_shadow_clipped(
      fb, palette, x, y, w, h, color, opacity, clip, spread, tl, tr, br, bl,
    )
    return
  }
  let steps = blurred_shadow_layer_count(blur)
  let layer_opacity = opacity / steps.to_double()
  for i = steps; i > 0; i = i - 1 {
    let expansion = (blur.to_double() * i.to_double() / steps.to_double()).to_int()
    fill_box_shadow_clipped(
      fb,
      palette,
      x - expansion,
      y - expansion,
      w + expansion * 2,
      h + expansion * 2,
      color,
      layer_opacity,
      clip,
      spread + expansion,
      tl,
      tr,
      br,
      bl,
    )
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
fn fill_rounded_corner_pixels_fast(
  fb : Framebuffer,
  palette : DynamicPalette,
  rect_x : Int,
  rect_y : Int,
  rect_w : Int,
  rect_h : Int,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  idx : Int,
  src : Color,
  alpha : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
  corner_x : Int,
  corner_y : Int,
  radius : Int,
) -> Unit {
  if radius <= 0 {
    return
  }
  let cx1 = @cmp.maximum(corner_x, x1)
  let cy1 = @cmp.maximum(corner_y, y1)
  let cx2 = @cmp.minimum(corner_x + radius, x2)
  let cy2 = @cmp.minimum(corner_y + radius, y2)
  if cx2 <= cx1 || cy2 <= cy1 {
    return
  }
  for py = cy1; py < cy2; py = py + 1 {
    for px = cx1; px < cx2; px = px + 1 {
      let cov = rounded_corner_coverage(
        px, py, rect_x, rect_y, rect_w, rect_h, tl, tr, br, bl,
      )
      if cov >= 1.0 {
        if alpha >= 255 {
          fb.set_pixel(px, py, idx)
        } else {
          blend_raster_color_over_pixel(fb, palette, px, py, src, alpha)
        }
      } else if cov > 0.0 {
        blend_raster_color_over_pixel(
          fb,
          palette,
          px,
          py,
          src,
          (cov * alpha.to_double()).to_int(),
        )
      }
    }
  }
}

///|
fn fill_rounded_rect_fast(
  fb : Framebuffer,
  palette : DynamicPalette,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  src : Color,
  alpha : Int,
  tl : Int,
  tr : Int,
  br : Int,
  bl : Int,
) -> Unit {
  let idx = palette.get_or_add(src)
  let cache = Array::make(palette.colors.length(), -1)
  for py = y1; py < y2; py = py + 1 {
    let mut row_x1 = x
    let mut row_x2 = x + w
    if tl > 0 && py < y + tl {
      row_x1 = @cmp.maximum(row_x1, x + tl)
    }
    if bl > 0 && py >= y + h - bl {
      row_x1 = @cmp.maximum(row_x1, x + bl)
    }
    if tr > 0 && py < y + tr {
      row_x2 = @cmp.minimum(row_x2, x + w - tr)
    }
    if br > 0 && py >= y + h - br {
      row_x2 = @cmp.minimum(row_x2, x + w - br)
    }
    let cx1 = @cmp.maximum(row_x1, x1)
    let cx2 = @cmp.minimum(row_x2, x2)
    if cx2 > cx1 {
      if alpha >= 255 {
        fb.fill_span(py, cx1, cx2, idx)
      } else {
        blend_span_with_raster_color(
          fb, palette, py, cx1, cx2, src, alpha, cache,
        )
      }
    }
  }
  fill_rounded_corner_pixels_fast(
    fb, palette, x, y, w, h, x1, y1, x2, y2, idx, src, alpha, tl, tr, br, bl, x,
    y, tl,
  )
  fill_rounded_corner_pixels_fast(
    fb,
    palette,
    x,
    y,
    w,
    h,
    x1,
    y1,
    x2,
    y2,
    idx,
    src,
    alpha,
    tl,
    tr,
    br,
    bl,
    x + w - tr,
    y,
    tr,
  )
  fill_rounded_corner_pixels_fast(
    fb,
    palette,
    x,
    y,
    w,
    h,
    x1,
    y1,
    x2,
    y2,
    idx,
    src,
    alpha,
    tl,
    tr,
    br,
    bl,
    x + w - br,
    y + h - br,
    br,
  )
  fill_rounded_corner_pixels_fast(
    fb,
    palette,
    x,
    y,
    w,
    h,
    x1,
    y1,
    x2,
    y2,
    idx,
    src,
    alpha,
    tl,
    tr,
    br,
    bl,
    x,
    y + h - bl,
    bl,
  )
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
  let src = types_color_to_image(color)
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
    fill_rounded_rect_fast(
      fb, palette, x, y, w, h, x1, y1, x2, y2, src, alpha, tl, tr, br, bl,
    )
  } else if alpha >= 255 {
    let idx = palette.get_or_add(src)
    for py = y1; py < y2; py = py + 1 {
      fb.fill_span(py, x1, x2, idx)
    }
  } else {
    let cache = Array::make(palette.colors.length(), -1)
    for py = y1; py < y2; py = py + 1 {
      blend_span_with_raster_color(fb, palette, py, x1, x2, src, alpha, cache)
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
          let idx = palette.get_or_add(types_color_to_image(color))
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
fn same_types_color(a : @types.Color, b : @types.Color) -> Bool {
  a.r == b.r && a.g == b.g && a.b == b.b && (a.a - b.a).abs() < 0.000001
}

///|
fn can_draw_uniform_rounded_border_ring(
  node : @paint_model.PaintNode,
  bt : Int,
  br : Int,
  bb : Int,
  bl : Int,
  has_radius : Bool,
) -> Bool {
  let solid_background = match node.paint.background_image {
    @types.None => true
    @types.Gradient(_) => false
  }
  has_radius &&
  bt > 0 &&
  bt == br &&
  bt == bb &&
  bt == bl &&
  !node.paint.border_top_color.is_transparent() &&
  same_types_color(node.paint.border_top_color, node.paint.border_right_color) &&
  same_types_color(node.paint.border_top_color, node.paint.border_bottom_color) &&
  same_types_color(node.paint.border_top_color, node.paint.border_left_color) &&
  !node.paint.background_color.is_transparent() &&
  solid_background
}

///|
fn draw_uniform_rounded_border_ring_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  border_width : Int,
  clip : ClipRect?,
  tl_r : Int,
  tr_r : Int,
  br_r : Int,
  bl_r : Int,
) -> Unit {
  fill_rounded_rect_clipped(
    fb,
    palette,
    x,
    y,
    w,
    h,
    node.paint.border_top_color,
    node.paint.opacity,
    clip,
    tl_r,
    tr_r,
    br_r,
    bl_r,
  )
  let inner_w = w - border_width * 2
  let inner_h = h - border_width * 2
  if inner_w <= 0 || inner_h <= 0 {
    return
  }
  fill_rounded_rect_clipped(
    fb,
    palette,
    x + border_width,
    y + border_width,
    inner_w,
    inner_h,
    node.paint.background_color,
    node.paint.opacity,
    clip,
    @cmp.maximum(tl_r - border_width, 0),
    @cmp.maximum(tr_r - border_width, 0),
    @cmp.maximum(br_r - border_width, 0),
    @cmp.maximum(bl_r - border_width, 0),
  )
}

///|
fn make_transparent_framebuffer(width : Int, height : Int) -> Framebuffer {
  { width, height, pixels: Array::make(width * height, -1) }
}

///|
fn blend_group_framebuffer_over(
  fb : Framebuffer,
  palette : DynamicPalette,
  group_fb : Framebuffer,
  group_palette : DynamicPalette,
  opacity : Double,
  clip : ClipRect?,
) -> Unit {
  let alpha = clamp_byte((opacity * 255.0).to_int())
  if alpha <= 0 {
    return
  }
  let x1 = match clip {
    Some(c) => @cmp.maximum(c.x, 0)
    None => 0
  }
  let y1 = match clip {
    Some(c) => @cmp.maximum(c.y, 0)
    None => 0
  }
  let x2 = match clip {
    Some(c) => @cmp.minimum(c.x + c.w, fb.width)
    None => fb.width
  }
  let y2 = match clip {
    Some(c) => @cmp.minimum(c.y + c.h, fb.height)
    None => fb.height
  }
  if x2 <= x1 || y2 <= y1 {
    return
  }
  for py = y1; py < y2; py = py + 1 {
    let row = py * group_fb.width
    for px = x1; px < x2; px = px + 1 {
      let idx = group_fb.pixels[row + px]
      if idx >= 0 && idx < group_palette.colors.length() {
        blend_raster_color_over_pixel(
          fb,
          palette,
          px,
          py,
          group_palette.colors[idx],
          alpha,
        )
      }
    }
  }
}

///|
fn render_group_opacity_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
  parent_x : Double,
  parent_y : Double,
  clip : ClipRect?,
) -> Unit {
  let group_fb = make_transparent_framebuffer(fb.width, fb.height)
  let group_palette = DynamicPalette::new()
  let opaque_node = { ..node, paint: { ..node.paint, opacity: 1.0 } }
  render_paint_node_clipped(
    group_fb, group_palette, opaque_node, parent_x, parent_y, clip,
  )
  blend_group_framebuffer_over(
    fb,
    palette,
    group_fb,
    group_palette,
    node.paint.opacity,
    clip,
  )
}

///|
/// Render a PaintNode tree to framebuffer
fn render_paint_node(
  fb : Framebuffer,
  palette : DynamicPalette,
  node : @paint_model.PaintNode,
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
  node : @paint_model.PaintNode,
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
  if node.paint.opacity < 1.0 && !node.children.is_empty() {
    render_group_opacity_clipped(fb, palette, node, parent_x, parent_y, clip)
    return
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

  for shadow in node.paint.box_shadows {
    if shadow.inset || shadow.color.is_transparent() {
      continue
    }
    let spread = shadow.spread_radius.to_int()
    let blur = shadow.blur_radius.to_int()
    let shadow_x = x + shadow.offset_x.to_int() - spread
    let shadow_y = y + shadow.offset_y.to_int() - spread
    let shadow_w = w + spread * 2
    let shadow_h = h + spread * 2
    fill_blurred_box_shadow_clipped(
      fb,
      palette,
      shadow_x,
      shadow_y,
      shadow_w,
      shadow_h,
      shadow.color,
      node.paint.opacity,
      clip,
      spread,
      blur,
      tl_r,
      tr_r,
      br_r,
      bl_r,
    )
  }

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
  let rounded_border_drawn = if can_draw_uniform_rounded_border_ring(
      node, bt, br, bb, bl, has_radius,
    ) {
    draw_uniform_rounded_border_ring_clipped(
      fb, palette, node, x, y, w, h, bt, clip, tl_r, tr_r, br_r, bl_r,
    )
    true
  } else {
    false
  }
  if !rounded_border_drawn &&
    bt > 0 &&
    !node.paint.border_top_color.is_transparent() {
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
  if !rounded_border_drawn &&
    bb > 0 &&
    !node.paint.border_bottom_color.is_transparent() {
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
  if !rounded_border_drawn &&
    bl > 0 &&
    !node.paint.border_left_color.is_transparent() {
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
  if !rounded_border_drawn &&
    br > 0 &&
    !node.paint.border_right_color.is_transparent() {
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

  // Draw resolved image content before alt fallback text.
  let drew_replaced_image = if node.tag == "img" && w > 0 && h > 0 {
    match node.src {
      Some(src) =>
        render_image_src_into_region(
          fb,
          palette,
          src,
          x,
          y,
          w,
          h,
          clip,
          node.paint.opacity,
        )
      None => false
    }
  } else {
    false
  }
  if !drew_replaced_image {
    // Draw text if this is a text node
    match node.text {
      Some(text_content) => {
        let (text_x, text_y, text_w) = resolve_text_render_box(node, x, y, w, h)
        match glyph_provider_override.val {
          Some(provider) => {
            let svg_color = @svg.Color::rgb(
              node.paint.color.r,
              node.paint.color.g,
              node.paint.color.b,
            )
            let font_size = node.paint.font_size
            let wrap_width = resolve_glyph_text_wrap_width(
              text_w, h, font_size, text_content,
            )
            let _ = draw_text_with_glyphs_clipped(
              fb,
              palette,
              provider,
              text_x,
              text_y,
              text_content,
              wrap_width,
              svg_color,
              font_size,
              node.paint.line_height,
              node.paint.is_bold,
              clip,
              font_family=node.paint.font_family,
              opacity=node.paint.opacity,
              letter_spacing=node.paint.letter_spacing,
              word_spacing=node.paint.word_spacing,
              font_weight=node.paint.font_weight,
            )
          }
          None => {
            let text_idx = palette.get_or_add(
              types_color_to_image(node.paint.color),
            )
            let scale = 1
            let _ = draw_text_clipped(
              fb, text_x, text_y, text_content, text_w, text_idx, scale, clip,
            )
          }
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
            node.paint.opacity,
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
            node.paint.opacity,
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
            node.paint.opacity,
            clip,
          )
        }
      }
      None => ()
    }
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
fn resolve_image_src(src : String) -> ResolvedImage? {
  match image_provider_override.val {
    Some(provider) =>
      match (provider.resolve)(src) {
        Some(image) => Some(image)
        None =>
          if src.has_prefix("data:image/svg+xml") {
            let svg_text = decode_svg_data_uri(src)
            if svg_text.length() > 0 {
              Some(ResolvedImage::Svg(svg_text))
            } else {
              None
            }
          } else {
            None
          }
      }
    None =>
      if src.has_prefix("data:image/svg+xml") {
        let svg_text = decode_svg_data_uri(src)
        if svg_text.length() > 0 {
          Some(ResolvedImage::Svg(svg_text))
        } else {
          None
        }
      } else {
        None
      }
  }
}

///|
fn render_image_src_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  src : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
  opacity : Double,
) -> Bool {
  match resolve_image_src(src) {
    Some(ResolvedImage::Raster(image)) =>
      render_raster_image_into_region(
        fb, palette, image, x, y, w, h, clip, opacity,
      )
    Some(ResolvedImage::Svg(svg_text)) =>
      if svg_text.length() > 0 {
        render_svg_into_region(fb, palette, svg_text, x, y, w, h, clip)
        true
      } else {
        false
      }
    None => false
  }
}

///|
fn render_raster_image_into_region(
  fb : Framebuffer,
  palette : DynamicPalette,
  image : RasterImage,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  clip : ClipRect?,
  opacity : Double,
) -> Bool {
  if image.width <= 0 ||
    image.height <= 0 ||
    w <= 0 ||
    h <= 0 ||
    image.rgba.length() < image.width * image.height * 4 {
    return false
  }
  for py = 0; py < h; py = py + 1 {
    let dst_y = y + py
    if dst_y < 0 || dst_y >= fb.height {
      continue
    }
    let src_y = (py * image.height / h).min(image.height - 1)
    for px = 0; px < w; px = px + 1 {
      let dst_x = x + px
      if dst_x < 0 || dst_x >= fb.width {
        continue
      }
      if !pixel_in_clip(clip, dst_x, dst_y) {
        continue
      }
      let src_x = (px * image.width / w).min(image.width - 1)
      let idx = (src_y * image.width + src_x) * 4
      let alpha = clamp_byte(
        (image.rgba[idx + 3].to_double() * opacity).to_int(),
      )
      if alpha <= 0 {
        continue
      }
      blend_raster_color_over_pixel(
        fb,
        palette,
        dst_x,
        dst_y,
        {
          r: clamp_byte(image.rgba[idx]),
          g: clamp_byte(image.rgba[idx + 1]),
          b: clamp_byte(image.rgba[idx + 2]),
        },
        alpha,
      )
    }
  }
  true
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
/// Render PaintNode tree to framebuffer with scroll offset
pub fn render_paint_node_to_framebuffer_scrolled(
  node : @paint_model.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
  scroll_y : Int,
) -> Unit {
  // Fill with white background
  fb.fill_rect(0, 0, fb.width, fb.height, 0)
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint_traversal.sort_tree_by_stacking_order(node)
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
    let bg_raster = { r: canvas_bg.r, g: canvas_bg.g, b: canvas_bg.b }
    let bg_idx = palette.get_or_add(bg_raster)
    fb.fill_rect(0, 0, fb.width, fb.height, bg_idx)
  }
  // Render the tree with scroll offset
  render_paint_node(fb, palette, sorted_node, 0.0, -scroll_y.to_double())
}

///|
/// Render PaintNode tree to framebuffer (for use by other renderers like Kitty)
pub fn render_paint_node_to_framebuffer(
  node : @paint_model.PaintNode,
  fb : Framebuffer,
  palette : DynamicPalette,
) -> Unit {
  // Sort by stacking order (z-index) for correct rendering
  let sorted_node = @paint_traversal.sort_tree_by_stacking_order(node)
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
    let bg_raster = { r: canvas_bg.r, g: canvas_bg.g, b: canvas_bg.b }
    let bg_idx = palette.get_or_add(bg_raster)
    fb.fill_rect(0, 0, fb.width, fb.height, bg_idx)
  }
  // Render the tree
  render_paint_node(fb, palette, sorted_node, 0.0, 0.0)
}
