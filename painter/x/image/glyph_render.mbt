///|
/// Glyph rendering for text using SVG path-based fonts.
/// Replaces bitmap font rendering when a GlyphProvider is configured.

///|
/// Provides glyph outlines and advance widths for text rendering.
pub(all) struct GlyphProvider {
  /// Get SVG path commands for a glyph. Args: (codepoint, font_size, is_bold).
  /// Returns (commands, advance_width).
  get_glyph : (Int, Double, Bool) -> (Array[@svg.PathCommand], Double)
  /// Get kerning adjustment between two codepoints. Args: (cp1, cp2, font_size, is_bold).
  get_kern : (Int, Int, Double, Bool) -> Double
  /// Font ascent in pixels at font_size=1. Multiply by actual font_size.
  ascent_ratio : Double // ascent / units_per_em (e.g. 1854/2048 ≈ 0.905)
  /// Multi-font glyph provider. Args: (codepoint, font_size, is_bold, font_family).
  /// Returns (commands, advance_width) or None to fall back to get_glyph.
  get_glyph_for_family : ((Int, Double, Bool, String) -> (
    Array[@svg.PathCommand],
    Double,
  )?)?
  /// Multi-font kerning. Args: (cp1, cp2, font_size, is_bold, font_family).
  get_kern_for_family : ((Int, Int, Double, Bool, String) -> Double)?
  /// Multi-font ascent ratio. Args: (font_family) -> ratio.
  get_ascent_for_family : ((String) -> Double)?
}

///|
let glyph_provider_override : Ref[GlyphProvider?] = { val: None }

///|
/// Cached rasterized glyph bitmap.
priv struct GlyphBitmap {
  width : Int
  height : Int
  pixels : Array[Bool] // true = has pixel (any coverage > 0)
  advance : Double
  offset_x : Int // bounding box x offset from origin
  offset_y : Int // bounding box y offset from origin
  coverage : Array[Int] // 0..ss*ss coverage from supersampling (0=transparent, ss*ss=full)
  ss_factor : Int // supersample factor (e.g. 4 means 4x4 grid, coverage 0..16)
}

///|
/// Bitmap cache for rasterized glyphs.
/// Key: "cp:fs_int:bold:family" → GlyphBitmap
let glyph_bitmap_cache : Ref[Map[String, GlyphBitmap]] = { val: {} }

///|
/// Cache for parsed glyph path commands (still used for advance width).
/// Key: "cp:fs_int:bold" → (commands, advance)
let glyph_cache : Ref[Map[String, (Array[@svg.PathCommand], Double)]] = {
  val: {},
}

///|
let text_wrap_tolerance : Double = 10.0

///|
fn resolve_text_wrap_tolerance(max_width : Int, font_size : Double) -> Double {
  if max_width <= 0 {
    return text_wrap_tolerance
  }
  let width_tolerance = max_width.to_double() * 0.2
  let font_tolerance = if font_size > 0.0 {
    font_size * 1.5
  } else {
    text_wrap_tolerance
  }
  let capped = if width_tolerance < font_tolerance {
    width_tolerance
  } else {
    font_tolerance
  }
  if capped > text_wrap_tolerance {
    capped
  } else {
    text_wrap_tolerance
  }
}

///|
fn insert_sorted_double(values : Array[Double], value : Double) -> Unit {
  let mut index = 0
  while index < values.length() && values[index] <= value {
    index = index + 1
  }
  values.insert(index, value)
}

///|
fn scanline_intersections_even_odd(
  polylines : Array[Array[(Double, Double)]],
  py : Double,
) -> Array[Double] {
  let intersections : Array[Double] = []
  for polyline in polylines {
    if polyline.length() < 3 {
      continue
    }
    let mut j = polyline.length() - 1
    for i = 0; i < polyline.length(); i = i + 1 {
      let (xi, yi) = polyline[i]
      let (xj, yj) = polyline[j]
      let crosses = (yi > py && yj <= py) || (yj > py && yi <= py)
      if crosses {
        let x_at_y = xi + (py - yi) * (xj - xi) / (yj - yi)
        insert_sorted_double(intersections, x_at_y)
      }
      j = i
    }
  }
  intersections
}

///|
fn rasterize_compound_path_even_odd_to_pixels(
  commands : Array[@svg.PathCommand],
  offset_x : Int,
  offset_y : Int,
  ss : Int,
  ss_width : Int,
  ss_height : Int,
) -> Array[Bool] {
  let pixels = Array::make(ss_width * ss_height, false)
  let polylines = @svg.path_to_polylines(commands, 0.5)
  let sample_scale = ss.to_double()
  for y = 0; y < ss_height; y = y + 1 {
    let py = offset_y.to_double() + (y.to_double() + 0.5) / sample_scale
    let intersections = scanline_intersections_even_odd(polylines, py)
    let mut i = 0
    while i + 1 < intersections.length() {
      let start = ((intersections[i] - offset_x.to_double()) * sample_scale -
        0.5)
        .ceil()
        .to_int()
      let end = ((intersections[i + 1] - offset_x.to_double()) * sample_scale -
        0.5)
        .ceil()
        .to_int()
      let clamped_start = if start < 0 {
        0
      } else if start > ss_width {
        ss_width
      } else {
        start
      }
      let clamped_end = if end < 0 {
        0
      } else if end > ss_width {
        ss_width
      } else {
        end
      }
      for x = clamped_start; x < clamped_end; x = x + 1 {
        pixels[y * ss_width + x] = true
      }
      i = i + 2
    }
  }
  pixels
}

///|
/// Rasterize a glyph to a bitmap. Called once per unique glyph.
fn rasterize_glyph_to_bitmap(
  commands : Array[@svg.PathCommand],
  advance : Double,
) -> GlyphBitmap {
  if commands.length() == 0 {
    return {
      width: 0,
      height: 0,
      pixels: [],
      advance,
      offset_x: 0,
      offset_y: 0,
      coverage: [],
      ss_factor: 1,
    }
  }
  // Find bounding box
  let mut min_x = 99999.0
  let mut min_y = 99999.0
  let mut max_x = -99999.0
  let mut max_y = -99999.0
  for cmd in commands {
    match cmd {
      MoveTo(x, y) | LineTo(x, y) | SmoothQuadraticCurveTo(x, y) => {
        if x < min_x {
          min_x = x
        }
        if y < min_y {
          min_y = y
        }
        if x > max_x {
          max_x = x
        }
        if y > max_y {
          max_y = y
        }
      }
      QuadraticCurveTo(cx, cy, x, y) => {
        for px in [cx, x] {
          if px < min_x {
            min_x = px
          }
          if px > max_x {
            max_x = px
          }
        }
        for py in [cy, y] {
          if py < min_y {
            min_y = py
          }
          if py > max_y {
            max_y = py
          }
        }
      }
      CurveTo(cx1, cy1, cx2, cy2, x, y) => {
        for px in [cx1, cx2, x] {
          if px < min_x {
            min_x = px
          }
          if px > max_x {
            max_x = px
          }
        }
        for py in [cy1, cy2, y] {
          if py < min_y {
            min_y = py
          }
          if py > max_y {
            max_y = py
          }
        }
      }
      ArcTo(_, _, _, _, _, x, y) => {
        if x < min_x {
          min_x = x
        }
        if y < min_y {
          min_y = y
        }
        if x > max_x {
          max_x = x
        }
        if y > max_y {
          max_y = y
        }
      }
      _ => ()
    }
  }
  if min_x >= max_x || min_y >= max_y {
    return {
      width: 0,
      height: 0,
      pixels: [],
      advance,
      offset_x: 0,
      offset_y: 0,
      coverage: [],
      ss_factor: 1,
    }
  }
  let offset_x = min_x.to_int() - 1
  let offset_y = min_y.to_int() - 1
  let width = (max_x - min_x).to_int() + 3
  let height = (max_y - min_y).to_int() + 3
  if width <= 0 || height <= 0 || width > 200 || height > 200 {
    return {
      width: 0,
      height: 0,
      pixels: [],
      advance,
      offset_x: 0,
      offset_y: 0,
      coverage: [],
      ss_factor: 1,
    }
  }
  // 4x supersampling for antialiasing (16 coverage levels)
  let ss = 4 // supersample factor
  let ss_width = width * ss
  let ss_height = height * ss
  let ss_pixels = rasterize_compound_path_even_odd_to_pixels(
    commands, offset_x, offset_y, ss, ss_width, ss_height,
  )
  // Downsample: count coverage in each ss×ss block → 0..ss*ss levels
  // Store as coverage (0=transparent, 1-3=partial, 4=full) in pixels array
  // We encode coverage as: false=0, true=4 for backward compat,
  // but also store coverage values for antialiased blitting
  let pixels = Array::make(width * height, false)
  let coverage = Array::make(width * height, 0)
  for y in 0..<height {
    for x in 0..<width {
      let mut count = 0
      for dy in 0..<ss {
        for dx in 0..<ss {
          let sx = x * ss + dx
          let sy = y * ss + dy
          if sx < ss_width && sy < ss_height && ss_pixels[sy * ss_width + sx] {
            count = count + 1
          }
        }
      }
      coverage[y * width + x] = count
      if count > 0 {
        pixels[y * width + x] = true
      }
    }
  }
  {
    width,
    height,
    pixels,
    advance,
    offset_x,
    offset_y,
    coverage,
    ss_factor: ss,
  }
}

///|
fn glyph_cache_key(
  cp : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
) -> String {
  let bold_flag = if is_bold { 1 } else { 0 }
  let fs_key = (font_size * 10.0).to_int()
  cp.to_string() +
  ":" +
  fs_key.to_string() +
  ":" +
  bold_flag.to_string() +
  ":" +
  font_family
}

///|
pub fn set_glyph_provider(provider : GlyphProvider) -> Unit {
  glyph_provider_override.val = Some(provider)
  glyph_cache.val = {}
  glyph_bitmap_cache.val = {}
}

///|

///|
/// Pre-rasterize common ASCII glyphs at given font sizes.
/// Call after set_glyph_provider to warm the bitmap cache.
pub fn pre_rasterize_glyphs(
  font_sizes : Array[Double],
  font_family? : String = "",
) -> Int {
  let provider = match glyph_provider_override.val {
    Some(p) => p
    None => return 0
  }
  let mut count = 0
  // ASCII printable range: space (32) to tilde (126)
  for fs in font_sizes {
    let baseline_offset = match provider.get_ascent_for_family {
      Some(get_ascent) if font_family.length() > 0 =>
        get_ascent(font_family) * fs
      _ => provider.ascent_ratio * fs
    }
    for cp = 32; cp <= 126; cp = cp + 1 {
      let key = glyph_cache_key(cp, fs, false, font_family)
      if glyph_bitmap_cache.val.get(key) is None {
        let (commands, advance) = match provider.get_glyph_for_family {
          Some(glyph_fn) if font_family.length() > 0 =>
            match glyph_fn(cp, fs, false, font_family) {
              Some(r) => r
              None => (provider.get_glyph)(cp, fs, false)
            }
          _ => (provider.get_glyph)(cp, fs, false)
        }
        let translated = translate_path_commands(commands, 0.0, baseline_offset)
        let bm = rasterize_glyph_to_bitmap(translated, advance)
        glyph_bitmap_cache.val.set(key, bm)
        count = count + 1
      }
    }
  }
  count
}

///|
pub fn clear_glyph_provider() -> Unit {
  glyph_provider_override.val = None
  glyph_cache.val = {}
  glyph_bitmap_cache.val = {}
}

///|
/// Convert mizchi/svg PathCommand to crater's svg PathCommand.
fn convert_msvg_path_command(cmd : @msvg.PathCommand) -> @svg.PathCommand {
  match cmd {
    MoveTo(x, y) => @svg.PathCommand::MoveTo(x, y)
    LineTo(x, y) => @svg.PathCommand::LineTo(x, y)
    QuadraticCurveTo(cx, cy, x, y) =>
      @svg.PathCommand::QuadraticCurveTo(cx, cy, x, y)
    CurveTo(cx1, cy1, cx2, cy2, x, y) =>
      @svg.PathCommand::CurveTo(cx1, cy1, cx2, cy2, x, y)
    ClosePath => @svg.PathCommand::ClosePath
    _ => @svg.PathCommand::ClosePath
  }
}

///|
/// Create a GlyphProvider from a parsed TTFont.
/// This allows native text rendering without JS FFI.
pub fn glyph_provider_from_font(font : @font.TTFont) -> GlyphProvider {
  let units_per_em = font.units_per_em.to_double()
  let ascent_ratio = font.ascent.to_double() / units_per_em
  {
    get_glyph: fn(codepoint, font_size, _is_bold) {
      let outline = font.scaled_outline(codepoint, font_size)
      let commands : Array[@svg.PathCommand] = outline.map(
        convert_msvg_path_command,
      )
      let glyph_id = font.glyph_index(codepoint)
      let advance = if glyph_id != 0 {
        let metrics = font.glyph_metrics(glyph_id)
        metrics.advance_width.to_double() / units_per_em * font_size
      } else {
        0.0
      }
      (commands, advance)
    },
    get_kern: fn(cp1, cp2, font_size, _is_bold) {
      let gid1 = font.glyph_index(cp1)
      let gid2 = font.glyph_index(cp2)
      let kern = font.kern_pair(gid1, gid2)
      kern.to_double() * font_size / units_per_em
    },
    ascent_ratio,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_ascent_for_family: None,
  }
}

///|
/// Parse font bytes and create a GlyphProvider.
/// Returns None if font parsing fails.
pub fn glyph_provider_from_bytes(data : Bytes) -> GlyphProvider? {
  match @font.parse_font(data) {
    Some(font) => Some(glyph_provider_from_font(font))
    None => None
  }
}

///|
fn get_advance(
  provider : GlyphProvider,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family? : String = "",
) -> Double {
  let (_, advance) = match provider.get_glyph_for_family {
    Some(glyph_fn) if font_family.length() > 0 =>
      match glyph_fn(codepoint, font_size, is_bold, font_family) {
        Some(r) => r
        None => (provider.get_glyph)(codepoint, font_size, is_bold)
      }
    _ => (provider.get_glyph)(codepoint, font_size, is_bold)
  }
  advance
}

///|
fn measure_word_width(
  provider : GlyphProvider,
  word : String,
  font_size : Double,
  is_bold : Bool,
  font_family? : String = "",
) -> Double {
  let mut w = 0.0
  let mut prev_cp = 0
  for c in word {
    let cp = c.to_int()
    if prev_cp != 0 {
      let kern = match provider.get_kern_for_family {
        Some(kern_fn) if font_family.length() > 0 =>
          kern_fn(prev_cp, cp, font_size, is_bold, font_family)
        _ => (provider.get_kern)(prev_cp, cp, font_size, is_bold)
      }
      w = w + kern
    }
    w = w + get_advance(provider, cp, font_size, is_bold, font_family~)
    prev_cp = cp
  }
  w
}

///|
fn clamp_opacity(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn blend_color_over_pixel_alpha(
  fb : Framebuffer,
  palette : DynamicPalette,
  px : Int,
  py : Int,
  color : Color,
  alpha : Double,
) -> Unit {
  let clamped = clamp_opacity(alpha)
  if clamped <= 0.0 {
    return
  }
  if clamped >= 1.0 {
    let idx = palette.get_or_add(color)
    fb.set_pixel(px, py, idx)
    return
  }
  let bg_idx = fb.pixels[py * fb.width + px]
  let bg_color = palette_color_at(palette, bg_idx)
  let a_byte = (clamped * 255.0).to_int()
  let blended = color.blend(bg_color, a_byte)
  let idx = palette.get_or_add(blended)
  fb.set_pixel(px, py, idx)
}

///|
/// Split text into words (by whitespace). Preserves newlines as "\n" tokens.
fn split_text_into_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let buf = StringBuilder::new()
  for c in text {
    if c == '\n' {
      if buf.to_string().length() > 0 {
        words.push(buf.to_string())
        buf.reset()
      }
      words.push("\n")
    } else if c == ' ' || c == '\t' || c == '\r' {
      if buf.to_string().length() > 0 {
        words.push(buf.to_string())
        buf.reset()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    words.push(buf.to_string())
  }
  words
}

///|
/// Translate path commands by (dx, dy) offset.
fn translate_path_commands(
  commands : Array[@svg.PathCommand],
  dx : Double,
  dy : Double,
) -> Array[@svg.PathCommand] {
  commands.map(fn(cmd) {
    match cmd {
      MoveTo(x, y) => @svg.PathCommand::MoveTo(x + dx, y + dy)
      LineTo(x, y) => @svg.PathCommand::LineTo(x + dx, y + dy)
      HorizontalLineTo(x) => @svg.PathCommand::HorizontalLineTo(x + dx)
      VerticalLineTo(y) => @svg.PathCommand::VerticalLineTo(y + dy)
      CurveTo(x1, y1, x2, y2, x, y) =>
        @svg.PathCommand::CurveTo(
          x1 + dx,
          y1 + dy,
          x2 + dx,
          y2 + dy,
          x + dx,
          y + dy,
        )
      SmoothCurveTo(x2, y2, x, y) =>
        @svg.PathCommand::SmoothCurveTo(x2 + dx, y2 + dy, x + dx, y + dy)
      QuadraticCurveTo(x1, y1, x, y) =>
        @svg.PathCommand::QuadraticCurveTo(x1 + dx, y1 + dy, x + dx, y + dy)
      SmoothQuadraticCurveTo(x, y) =>
        @svg.PathCommand::SmoothQuadraticCurveTo(x + dx, y + dy)
      ArcTo(rx, ry, rot, large, sweep, x, y) =>
        @svg.PathCommand::ArcTo(rx, ry, rot, large, sweep, x + dx, y + dy)
      ClosePath => @svg.PathCommand::ClosePath
      _ => cmd
    }
  })
}

///|
/// Draw text using the glyph provider with clip rect support.
fn draw_text_with_glyphs_clipped(
  fb : Framebuffer,
  palette : DynamicPalette,
  provider : GlyphProvider,
  x : Int,
  y : Int,
  text : String,
  max_width : Int,
  color : @svg.Color,
  font_size : Double,
  line_height : Double,
  is_bold : Bool,
  clip : ClipRect?,
  font_family? : String = "",
  opacity? : Double = 1.0,
) -> Int {
  let text_opacity = clamp_opacity(opacity) * color.a.to_double() / 255.0
  let effective_line_height = if line_height > 0.0 {
    line_height
  } else {
    font_size
  }
  let baseline_offset = match provider.get_ascent_for_family {
    Some(get_ascent) if font_family.length() > 0 =>
      get_ascent(font_family) * font_size
    _ => provider.ascent_ratio * font_size
  }
  let wrap_tolerance = resolve_text_wrap_tolerance(max_width, font_size)
  let max_x_limit = if max_width > 0 {
    (x + max_width).to_double() + wrap_tolerance
  } else {
    fb.width.to_double()
  }
  let words = split_text_into_words(text)
  let mut cur_x = x.to_double()
  let mut cur_y = y.to_double()
  let mut max_y_seen = y.to_double() + effective_line_height
  let space_advance_layout = get_advance(
    provider,
    ' '.to_int(),
    font_size,
    is_bold,
    font_family~,
  )
  for i, word in words {
    if word == "\n" {
      cur_x = x.to_double()
      cur_y = cur_y + effective_line_height
      max_y_seen = cur_y + effective_line_height
      continue
    }
    let word_width = measure_word_width(
      provider,
      word,
      font_size,
      is_bold,
      font_family~,
    )
    let hard_wrap_limit = if max_width > 0 &&
      word_width > max_width.to_double() + wrap_tolerance {
      (x + max_width).to_double()
    } else {
      max_x_limit
    }
    let mut space_width = 0.0
    if i > 0 && word != "\n" && cur_x > x.to_double() + 0.01 {
      space_width = space_advance_layout
    }
    if max_width > 0 {
      let total_width = space_width + word_width
      if cur_x + total_width > max_x_limit && cur_x > x.to_double() + 0.01 {
        cur_x = x.to_double()
        cur_y = cur_y + effective_line_height
        max_y_seen = cur_y + effective_line_height
        space_width = 0.0
      }
    }
    cur_x = cur_x + space_width
    // Pre-compute palette index for this word's color (constant per word)
    let sixel_color = { r: color.r, g: color.g, b: color.b }
    let color_idx = palette.get_or_add(sixel_color)
    let mut prev_cp = 0
    for c in word {
      let cp = c.to_int()
      // Use bitmap cache: rasterize each glyph once, then blit
      let cache_key = glyph_cache_key(cp, font_size, is_bold, font_family)
      let bitmap = match glyph_bitmap_cache.val.get(cache_key) {
        Some(bm) => bm
        None => {
          let (commands, advance) = match provider.get_glyph_for_family {
            Some(glyph_fn) if font_family.length() > 0 =>
              match glyph_fn(cp, font_size, is_bold, font_family) {
                Some(r) => r
                None => (provider.get_glyph)(cp, font_size, is_bold)
              }
            _ => (provider.get_glyph)(cp, font_size, is_bold)
          }
          let translated = translate_path_commands(
            commands, 0.0, baseline_offset,
          )
          let bm = rasterize_glyph_to_bitmap(translated, advance)
          glyph_bitmap_cache.val.set(cache_key, bm)
          bm
        }
      }
      let kern = if prev_cp != 0 {
        match provider.get_kern_for_family {
          Some(kern_fn) if font_family.length() > 0 =>
            kern_fn(prev_cp, cp, font_size, is_bold, font_family)
          _ => (provider.get_kern)(prev_cp, cp, font_size, is_bold)
        }
      } else {
        0.0
      }
      let mut draw_x = cur_x + kern
      if max_width > 0 &&
        draw_x + bitmap.advance > hard_wrap_limit &&
        cur_x > x.to_double() + 0.01 {
        cur_x = x.to_double()
        cur_y = cur_y + effective_line_height
        max_y_seen = cur_y + effective_line_height
        draw_x = cur_x
      }
      let line_top = cur_y.to_int()
      let line_bottom = (cur_y + effective_line_height).to_int()
      let in_clip_v = match clip {
        Some(cr) => line_bottom >= cr.y && line_top < cr.y + cr.h
        None => line_bottom >= 0 && line_top < fb.height
      }
      // Blit cached bitmap to framebuffer with antialiasing
      if in_clip_v && bitmap.width > 0 {
        let dx = draw_x.to_int() + bitmap.offset_x
        let dy = cur_y.to_int() + bitmap.offset_y
        let has_coverage = bitmap.coverage.length() ==
          bitmap.width * bitmap.height
        for by = 0; by < bitmap.height; by = by + 1 {
          let py = dy + by
          if py < 0 || py >= fb.height {
            continue
          }
          for bx = 0; bx < bitmap.width; bx = bx + 1 {
            let bi = by * bitmap.width + bx
            if bitmap.pixels[bi] {
              let px = dx + bx
              if px >= 0 && px < fb.width && pixel_in_clip(clip, px, py) {
                if has_coverage {
                  let cov = bitmap.coverage[bi]
                  let max_cov = bitmap.ss_factor * bitmap.ss_factor
                  if cov >= max_cov {
                    // Full coverage: solid pixel
                    if text_opacity >= 1.0 {
                      fb.set_pixel(px, py, color_idx)
                    } else {
                      blend_color_over_pixel_alpha(
                        fb, palette, px, py, sixel_color, text_opacity,
                      )
                    }
                  } else {
                    // Partial coverage: blend with background
                    let alpha = cov.to_double() /
                      max_cov.to_double() *
                      text_opacity
                    blend_color_over_pixel_alpha(
                      fb, palette, px, py, sixel_color, alpha,
                    )
                  }
                } else if text_opacity >= 1.0 {
                  fb.set_pixel(px, py, color_idx)
                } else {
                  blend_color_over_pixel_alpha(
                    fb, palette, px, py, sixel_color, text_opacity,
                  )
                }
              }
            }
          }
        }
      }
      cur_x = draw_x + bitmap.advance
      prev_cp = cp
    }
  }
  (max_y_seen - y.to_double()).to_int()
}
