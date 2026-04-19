///|
/// Parse raw glyph point data: coordinates, flags, and contour endpoints
fn parse_glyph_points(
  reader : BinaryReader,
  num_contours : Int,
) -> (Array[Int], Array[Int], Array[Int], Array[Int]) {
  let end_points = Array::new(capacity=num_contours)
  for i = 0; i < num_contours; i = i + 1 {
    end_points.push(reader.read_uint16())
    ignore(i)
  }
  let num_points = if num_contours > 0 {
    end_points[num_contours - 1] + 1
  } else {
    0
  }
  let instruction_length = reader.read_uint16()
  reader.skip(instruction_length)
  let flags = Array::new(capacity=num_points)
  let mut i = 0
  while i < num_points {
    let flag = reader.read_uint8()
    flags.push(flag)
    if (flag & 8) != 0 {
      let repeat_count = reader.read_uint8()
      for _j = 0; _j < repeat_count; _j = _j + 1 {
        flags.push(flag)
      }
      i = i + repeat_count
    }
    i = i + 1
  }
  let x_coords = Array::new(capacity=num_points)
  let mut x = 0
  for i = 0; i < num_points; i = i + 1 {
    let flag = flags[i]
    let x_short = (flag & 2) != 0
    let x_same = (flag & 16) != 0
    if x_short {
      let dx = reader.read_uint8()
      if x_same {
        x = x + dx
      } else {
        x = x - dx
      }
    } else if x_same {
      ()
    } else {
      x = x + reader.read_int16()
    }
    x_coords.push(x)
  }
  let y_coords = Array::new(capacity=num_points)
  let mut y = 0
  for i = 0; i < num_points; i = i + 1 {
    let flag = flags[i]
    let y_short = (flag & 4) != 0
    let y_same = (flag & 32) != 0
    if y_short {
      let dy = reader.read_uint8()
      if y_same {
        y = y + dy
      } else {
        y = y - dy
      }
    } else if y_same {
      ()
    } else {
      y = y + reader.read_int16()
    }
    y_coords.push(y)
  }
  (x_coords, y_coords, flags, end_points)
}

///|
/// Assemble contours from raw point data
fn assemble_contours(
  x_coords : Array[Int],
  y_coords : Array[Int],
  flags : Array[Int],
  end_points : Array[Int],
) -> Array[Array[GlyphPoint]] {
  let contours : Array[Array[GlyphPoint]] = []
  let mut start = 0
  for ep in end_points {
    let contour : Array[GlyphPoint] = []
    for j = start; j <= ep; j = j + 1 {
      contour.push({
        x: x_coords[j],
        y: y_coords[j],
        on_curve: (flags[j] & 1) != 0,
      })
    }
    contours.push(contour)
    start = ep + 1
  }
  contours
}

///|
/// Parse a simple glyph from the glyf table
fn parse_simple_glyph(
  reader : BinaryReader,
  num_contours : Int,
) -> Array[Array[GlyphPoint]] {
  let (x_coords, y_coords, flags, end_points) = parse_glyph_points(
    reader, num_contours,
  )
  assemble_contours(x_coords, y_coords, flags, end_points)
}

///|
fn contours_to_path_commands(
  contours : Array[Array[GlyphPoint]],
) -> Array[@svg.PathCommand] {
  let commands : Array[@svg.PathCommand] = []
  for contour in contours {
    if contour.is_empty() {
      continue
    }
    contour_to_path(contour, commands)
  }
  commands
}

///|
fn contour_to_path(
  contour : Array[GlyphPoint],
  commands : Array[@svg.PathCommand],
) -> Unit {
  let n = contour.length()
  if n == 0 {
    return
  }
  let first = contour[0]
  let last = contour[n - 1]
  let (start_x, start_y, start_idx) = if first.on_curve {
    (first.x.to_double(), first.y.to_double(), 0)
  } else if last.on_curve {
    (last.x.to_double(), last.y.to_double(), 0)
  } else {
    let mx = (first.x + last.x).to_double() / 2.0
    let my = (first.y + last.y).to_double() / 2.0
    (mx, my, 0)
  }
  commands.push(@svg.MoveTo(start_x, start_y))
  let mut i = start_idx
  while i < n {
    let p = contour[i]
    if p.on_curve {
      commands.push(@svg.LineTo(p.x.to_double(), p.y.to_double()))
      i = i + 1
    } else {
      let ctrl_x = p.x.to_double()
      let ctrl_y = p.y.to_double()
      let next_idx = (i + 1) % n
      let next = contour[next_idx]
      if next.on_curve {
        commands.push(
          @svg.QuadraticCurveTo(
            ctrl_x,
            ctrl_y,
            next.x.to_double(),
            next.y.to_double(),
          ),
        )
        i = i + 2
      } else {
        let mid_x = (ctrl_x + next.x.to_double()) / 2.0
        let mid_y = (ctrl_y + next.y.to_double()) / 2.0
        commands.push(@svg.QuadraticCurveTo(ctrl_x, ctrl_y, mid_x, mid_y))
        i = i + 1
      }
    }
  }
  commands.push(@svg.ClosePath)
}

///|
fn parse_compound_glyph(
  font : TTFont,
  reader : BinaryReader,
) -> Array[@svg.PathCommand] {
  let commands : Array[@svg.PathCommand] = []
  let mut has_more = true
  while has_more {
    let flags = reader.read_uint16()
    let glyph_index = reader.read_uint16()
    let mut dx = 0.0
    let mut dy = 0.0
    let arg1_and_2_are_words = (flags & 1) != 0
    let args_are_xy = (flags & 2) != 0
    if arg1_and_2_are_words {
      if args_are_xy {
        dx = reader.read_int16().to_double()
        dy = reader.read_int16().to_double()
      } else {
        let _p1 = reader.read_uint16()
        let _p2 = reader.read_uint16()
      }
    } else if args_are_xy {
      dx = reader.read_int8().to_double()
      dy = reader.read_int8().to_double()
    } else {
      let _p1 = reader.read_uint8()
      let _p2 = reader.read_uint8()
    }
    let mut sx = 1.0
    let mut sy = 1.0
    let we_have_a_scale = (flags & 8) != 0
    let we_have_an_x_and_y_scale = (flags & 64) != 0
    let we_have_a_two_by_two = (flags & 128) != 0
    if we_have_a_scale {
      sx = reader.read_int16().to_double() / 16384.0
      sy = sx
    } else if we_have_an_x_and_y_scale {
      sx = reader.read_int16().to_double() / 16384.0
      sy = reader.read_int16().to_double() / 16384.0
    } else if we_have_a_two_by_two {
      sx = reader.read_int16().to_double() / 16384.0
      let _sxy = reader.read_int16().to_double() / 16384.0
      let _syx = reader.read_int16().to_double() / 16384.0
      sy = reader.read_int16().to_double() / 16384.0
    }
    let component_cmds = glyph_outline_by_id(font, glyph_index)
    let transformed = transform_commands(component_cmds, dx, dy, sx, sy)
    for cmd in transformed {
      commands.push(cmd)
    }
    has_more = (flags & 32) != 0
  }
  commands
}

///|
fn transform_commands(
  commands : Array[@svg.PathCommand],
  dx : Double,
  dy : Double,
  sx : Double,
  sy : Double,
) -> Array[@svg.PathCommand] {
  let result : Array[@svg.PathCommand] = []
  for cmd in commands {
    let transformed : @svg.PathCommand = match cmd {
      @svg.MoveTo(x, y) => @svg.MoveTo(x * sx + dx, y * sy + dy)
      @svg.LineTo(x, y) => @svg.LineTo(x * sx + dx, y * sy + dy)
      @svg.QuadraticCurveTo(cx, cy, x, y) =>
        @svg.QuadraticCurveTo(
          cx * sx + dx,
          cy * sy + dy,
          x * sx + dx,
          y * sy + dy,
        )
      @svg.CurveTo(cx1, cy1, cx2, cy2, x, y) =>
        @svg.CurveTo(
          cx1 * sx + dx,
          cy1 * sy + dy,
          cx2 * sx + dx,
          cy2 * sy + dy,
          x * sx + dx,
          y * sy + dy,
        )
      @svg.ClosePath => @svg.ClosePath
      other => other
    }
    result.push(transformed)
  }
  result
}

///|
pub fn scale_commands(
  commands : Array[@svg.PathCommand],
  scale : Double,
  flip_y : Bool,
) -> Array[@svg.PathCommand] {
  let result : Array[@svg.PathCommand] = []
  let ys = if flip_y { -scale } else { scale }
  for cmd in commands {
    let scaled : @svg.PathCommand = match cmd {
      @svg.MoveTo(x, y) => @svg.MoveTo(x * scale, y * ys)
      @svg.LineTo(x, y) => @svg.LineTo(x * scale, y * ys)
      @svg.QuadraticCurveTo(cx, cy, x, y) =>
        @svg.QuadraticCurveTo(cx * scale, cy * ys, x * scale, y * ys)
      @svg.CurveTo(cx1, cy1, cx2, cy2, x, y) =>
        @svg.CurveTo(
          cx1 * scale,
          cy1 * ys,
          cx2 * scale,
          cy2 * ys,
          x * scale,
          y * ys,
        )
      @svg.ClosePath => @svg.ClosePath
      other => other
    }
    result.push(scaled)
  }
  result
}

///|
fn glyph_outline_by_id(
  font : TTFont,
  glyph_id : Int,
) -> Array[@svg.PathCommand] {
  if glyph_id < 0 || glyph_id >= font.num_glyphs {
    return []
  }
  match font.cff {
    Some(cff) =>
      // Variable CFF2 font: use var path with default (zero) scalars
      match cff.ivs {
        Some(ivs) => {
          let scalars = precompute_scalars(ivs, 0, [])
          cff_glyph_outline_var(font.data, cff, glyph_id, scalars)
        }
        None => cff_glyph_outline(font.data, cff, glyph_id)
      }
    None => glyf_outline_by_id(font, glyph_id)
  }
}

///|
fn glyph_outline_by_id_var(
  font : TTFont,
  glyph_id : Int,
  scalars : Array[Double],
) -> Array[@svg.PathCommand] {
  if glyph_id < 0 || glyph_id >= font.num_glyphs {
    return []
  }
  match font.cff {
    Some(cff) => cff_glyph_outline_var(font.data, cff, glyph_id, scalars)
    None => glyf_outline_by_id(font, glyph_id)
  }
}

///|
/// Get glyf outline with gvar variation applied
fn glyf_outline_by_id_var_gvar(
  font : TTFont,
  glyph_id : Int,
  coords : Array[Double],
) -> Array[@svg.PathCommand] {
  let glyf_offset = font.loca[glyph_id]
  let next_offset = font.loca[glyph_id + 1]
  if glyf_offset == next_offset {
    return []
  }
  let offset = font.glyf_offset + glyf_offset
  let reader = BinaryReader::at(font.data, offset)
  let num_contours = reader.read_int16()
  let _x_min = reader.read_int16()
  let _y_min = reader.read_int16()
  let _x_max = reader.read_int16()
  let _y_max = reader.read_int16()
  if num_contours < 0 {
    // Compound glyph: no gvar support yet, fall back to static
    return parse_compound_glyph(font, reader)
  }
  let (x_coords, y_coords, flags, end_points) = parse_glyph_points(
    reader, num_contours,
  )
  guard font.gvar is Some(gvar) else {
    return contours_to_path_commands(
      assemble_contours(x_coords, y_coords, flags, end_points),
    )
  }
  let (dx, dy) = apply_gvar_deltas(
    font.data,
    gvar,
    glyph_id,
    coords,
    x_coords,
    y_coords,
    end_points,
  )
  // Apply deltas
  let var_x : Array[Int] = []
  let var_y : Array[Int] = []
  for i = 0; i < x_coords.length(); i = i + 1 {
    var_x.push(x_coords[i] + dx[i])
    var_y.push(y_coords[i] + dy[i])
  }
  let contours = assemble_contours(var_x, var_y, flags, end_points)
  contours_to_path_commands(contours)
}

///|
/// Interpolate glyph metrics for glyf+gvar variable fonts using phantom points.
/// Phantom points are appended after the real glyph points:
///   phantom[0] = (0, 0)           — origin
///   phantom[1] = (advance, 0)     — advance width
///   phantom[2] = (lsb, 0)         — left side bearing
///   phantom[3] = (0, 0)           — reserved
/// Returns (interpolated_advance, interpolated_lsb, bbox).
fn gvar_interpolate_metrics(
  font : TTFont,
  gvar : GvarData,
  glyph_id : Int,
  coords : Array[Double],
  advance : Int,
  lsb : Int,
) -> (Int, Int, GlyphBBox) {
  let default_bbox : GlyphBBox = { x_min: 0, y_min: 0, x_max: 0, y_max: 0 }
  if glyph_id >= font.loca.length() - 1 {
    return (advance, lsb, default_bbox)
  }
  let glyf_off = font.loca[glyph_id]
  let next_off = font.loca[glyph_id + 1]
  if glyf_off == next_off {
    // Empty glyph — still apply phantom point deltas
    let x_coords : Array[Int] = [0, advance, lsb, 0]
    let y_coords : Array[Int] = [0, 0, 0, 0]
    let end_points : Array[Int] = []
    let (dx, _dy) = apply_gvar_deltas(
      font.data,
      gvar,
      glyph_id,
      coords,
      x_coords,
      y_coords,
      end_points,
    )
    let var_advance = if dx.length() > 1 { advance + dx[1] } else { advance }
    let var_lsb = if dx.length() > 2 { lsb + dx[2] } else { lsb }
    return (var_advance, var_lsb, default_bbox)
  }
  let offset = font.glyf_offset + glyf_off
  let reader = BinaryReader::at(font.data, offset)
  let num_contours = reader.read_int16()
  let x_min = reader.read_int16()
  let y_min = reader.read_int16()
  let x_max = reader.read_int16()
  let y_max = reader.read_int16()
  if num_contours < 0 {
    // Compound glyph — return static metrics with table bbox
    return (advance, lsb, { x_min, y_min, x_max, y_max })
  }
  let (x_coords, y_coords, flags, end_points) = parse_glyph_points(
    reader, num_contours,
  )
  // Append 4 phantom points
  let x_with_phantom = x_coords.copy()
  let y_with_phantom = y_coords.copy()
  x_with_phantom.push(0) // phantom 0: origin x
  y_with_phantom.push(0) // phantom 0: origin y
  x_with_phantom.push(advance) // phantom 1: advance x
  y_with_phantom.push(0) // phantom 1: advance y
  x_with_phantom.push(lsb) // phantom 2: lsb x
  y_with_phantom.push(0) // phantom 2: lsb y
  x_with_phantom.push(0) // phantom 3: reserved
  y_with_phantom.push(0) // phantom 3: reserved
  let (dx, dy) = apply_gvar_deltas(
    font.data,
    gvar,
    glyph_id,
    coords,
    x_with_phantom,
    y_with_phantom,
    end_points,
  )
  let num_real = x_coords.length()
  let var_advance = if dx.length() > num_real + 1 {
    advance + dx[num_real + 1]
  } else {
    advance
  }
  let var_lsb = if dx.length() > num_real + 2 {
    lsb + dx[num_real + 2]
  } else {
    lsb
  }
  // Compute variable bbox from interpolated outline
  let var_x : Array[Int] = []
  let var_y : Array[Int] = []
  for i = 0; i < num_real; i = i + 1 {
    var_x.push(x_coords[i] + dx[i])
    var_y.push(y_coords[i] + dy[i])
  }
  let contours = assemble_contours(var_x, var_y, flags, end_points)
  let outline = contours_to_path_commands(contours)
  let bbox = compute_path_bbox(outline)
  (var_advance, var_lsb, bbox)
}

///|
fn glyf_outline_by_id(font : TTFont, glyph_id : Int) -> Array[@svg.PathCommand] {
  let glyf_offset = font.loca[glyph_id]
  let next_offset = font.loca[glyph_id + 1]
  if glyf_offset == next_offset {
    return []
  }
  let offset = font.glyf_offset + glyf_offset
  let reader = BinaryReader::at(font.data, offset)
  let num_contours = reader.read_int16()
  let _x_min = reader.read_int16()
  let _y_min = reader.read_int16()
  let _x_max = reader.read_int16()
  let _y_max = reader.read_int16()
  if num_contours >= 0 {
    let contours = parse_simple_glyph(reader, num_contours)
    contours_to_path_commands(contours)
  } else {
    parse_compound_glyph(font, reader)
  }
}
