///|
/// Glyph rasterization — converts font outlines to pixel bitmaps via SVG rendering.

///|
/// Rasterized glyph pixel data (RGBA8 flat array: [r,g,b,a, r,g,b,a, ...]).
pub struct GlyphBitmap {
  width : Int
  height : Int
  pixels : Array[Int]
} derive(Show)

///|
/// Convert font outline PathCommands to SVG path `d` attribute string.
pub fn path_commands_to_svg_d(commands : Array[@svg.PathCommand]) -> String {
  let parts : Array[String] = []
  for cmd in commands {
    match cmd {
      @svg.PathCommand::MoveTo(x, y) =>
        parts.push("M " + x.to_string() + " " + y.to_string())
      @svg.PathCommand::LineTo(x, y) =>
        parts.push("L " + x.to_string() + " " + y.to_string())
      @svg.PathCommand::QuadraticCurveTo(cx, cy, x, y) =>
        parts.push(
          "Q " +
          cx.to_string() +
          " " +
          cy.to_string() +
          " " +
          x.to_string() +
          " " +
          y.to_string(),
        )
      @svg.PathCommand::CurveTo(cx1, cy1, cx2, cy2, x, y) =>
        parts.push(
          "C " +
          cx1.to_string() +
          " " +
          cy1.to_string() +
          " " +
          cx2.to_string() +
          " " +
          cy2.to_string() +
          " " +
          x.to_string() +
          " " +
          y.to_string(),
        )
      @svg.PathCommand::ClosePath => parts.push("Z")
      _ => ()
    }
  }
  let mut result = ""
  for i, p in parts {
    if i > 0 {
      result = result + " "
    }
    result = result + p
  }
  result
}

///|
/// Compute bounding box from outline path commands.
pub fn outline_bbox(
  commands : Array[@svg.PathCommand],
) -> (Double, Double, Double, Double) {
  let mut x_min = 1.0e10
  let mut y_min = 1.0e10
  let mut x_max = -1.0e10
  let mut y_max = -1.0e10
  for cmd in commands {
    let points : Array[(Double, Double)] = match cmd {
      @svg.PathCommand::MoveTo(x, y) => [(x, y)]
      @svg.PathCommand::LineTo(x, y) => [(x, y)]
      @svg.PathCommand::QuadraticCurveTo(cx, cy, x, y) => [(cx, cy), (x, y)]
      @svg.PathCommand::CurveTo(cx1, cy1, cx2, cy2, x, y) =>
        [(cx1, cy1), (cx2, cy2), (x, y)]
      _ => []
    }
    for pt in points {
      let (px, py) = pt
      if px < x_min {
        x_min = px
      }
      if py < y_min {
        y_min = py
      }
      if px > x_max {
        x_max = px
      }
      if py > y_max {
        y_max = py
      }
    }
  }
  (x_min, y_min, x_max, y_max)
}

///|
/// Rasterize a glyph outline to a pixel bitmap using SVG rendering.
/// Returns None for glyphs with no outline (e.g., space).
pub fn rasterize_glyph(
  font : TTFont,
  codepoint : Int,
  size_px : Double,
) -> GlyphBitmap? {
  let outline = font.scaled_outline(codepoint, size_px)
  if outline.length() == 0 {
    return None
  }
  let (x_min, y_min, x_max, y_max) = outline_bbox(outline)
  if x_max <= x_min || y_max <= y_min {
    return None
  }
  let pad = 1.0
  let w = (x_max - x_min + pad * 2.0).ceil().to_int()
  let h = (y_max - y_min + pad * 2.0).ceil().to_int()
  if w <= 0 || h <= 0 {
    return None
  }
  // Direct path rendering: skip SVG string serialization/parsing.
  // Transform: translate(-x_min+pad, y_max+pad) scale(1, -1) for font Y-up → image Y-down
  let tx = -x_min + pad
  let ty = y_max + pad
  // Affine transform [a, b, c, d, e, f]: scale(1,-1) then translate(tx,ty)
  // Combined: [1, 0, 0, -1, tx, ty]
  let transform = [1.0, 0.0, 0.0, -1.0, tx, ty]
  let img = @svg.render_path_commands_to_image(
    outline,
    w,
    h,
    @svg.Color::white(),
    transform~,
  )
  let pixels : Array[Int] = []
  for i = 0; i < img.pixels.length(); i = i + 1 {
    let color = img.pixels[i]
    pixels.push(color.r)
    pixels.push(color.g)
    pixels.push(color.b)
    pixels.push(color.a)
  }
  Some({ width: img.width, height: img.height, pixels })
}

///|
/// Copy a GlyphBitmap into a larger pixel array at the given position.
pub fn blit_to_atlas(
  atlas_pixels : Array[Int],
  atlas_width : Int,
  src : GlyphBitmap,
  dst_x : Int,
  dst_y : Int,
) -> Unit {
  let atlas_height = atlas_pixels.length() / (atlas_width * 4)
  let mut src_x_start = 0
  let mut src_y_start = 0
  if dst_x < 0 {
    src_x_start = -dst_x
  }
  if dst_y < 0 {
    src_y_start = -dst_y
  }
  let mut src_x_end = src.width
  let mut src_y_end = src.height
  if dst_x + src_x_end > atlas_width {
    src_x_end = atlas_width - dst_x
  }
  if dst_y + src_y_end > atlas_height {
    src_y_end = atlas_height - dst_y
  }
  if src_x_start >= src_x_end || src_y_start >= src_y_end {
    return
  }
  let copy_width = src_x_end - src_x_start
  let row_copy_len = copy_width * 4
  for row in src_y_start..<src_y_end {
    let src_offset = (row * src.width + src_x_start) * 4
    let dst_offset = ((dst_y + row) * atlas_width + (dst_x + src_x_start)) * 4
    src.pixels[src_offset:src_offset + row_copy_len].blit_to(
      atlas_pixels,
      dst_offset~,
    )
  }
}
