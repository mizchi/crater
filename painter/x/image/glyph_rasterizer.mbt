///|
/// Glyph outline rasterization helpers.

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
  let ss = 4
  let ss_width = width * ss
  let ss_height = height * ss
  let ss_pixels = rasterize_compound_path_even_odd_to_pixels(
    commands, offset_x, offset_y, ss, ss_width, ss_height,
  )
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
