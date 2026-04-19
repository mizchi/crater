///|
/// Parse gvar table header, shared tuples, and glyph offsets
fn parse_gvar(
  reader : BinaryReader,
  offset : Int,
  num_glyphs : Int,
) -> GvarData? {
  let r = BinaryReader::at(reader.data, offset)
  let _version_major = r.read_uint16()
  let _version_minor = r.read_uint16()
  let axis_count = r.read_uint16()
  let shared_tuple_count = r.read_uint16()
  let shared_tuples_offset = r.read_uint32()
  let glyph_count = r.read_uint16()
  let flags = r.read_uint16()
  let glyph_var_data_array_offset = r.read_uint32()
  // Read glyph offsets
  let offsets_are_long = (flags & 1) != 0
  let glyph_offsets : Array[Int] = []
  for i = 0; i <= glyph_count; i = i + 1 {
    if offsets_are_long {
      glyph_offsets.push(r.read_uint32())
    } else {
      glyph_offsets.push(r.read_uint16() * 2)
    }
    ignore(i)
  }
  // Parse shared tuples
  let shared_tuples : Array[Array[Double]] = []
  let st_reader = BinaryReader::at(reader.data, offset + shared_tuples_offset)
  for i = 0; i < shared_tuple_count; i = i + 1 {
    let tuple : Array[Double] = []
    for j = 0; j < axis_count; j = j + 1 {
      tuple.push(st_reader.read_f2dot14())
      ignore(j)
    }
    shared_tuples.push(tuple)
    ignore(i)
  }
  ignore(num_glyphs)
  Some({
    axis_count,
    shared_tuples,
    gvar_offset: offset,
    glyph_var_data_offset: offset + glyph_var_data_array_offset,
    glyph_offsets,
  })
}

///|
/// Unpack packed point numbers from gvar data.
/// Returns empty array if all points are referenced.
fn unpack_points(reader : BinaryReader) -> Array[Int] {
  let count_byte = reader.read_uint8()
  if count_byte == 0 {
    return [] // all points
  }
  let count = if (count_byte & 0x80) != 0 {
    ((count_byte & 0x7F) << 8) | reader.read_uint8()
  } else {
    count_byte
  }
  let points : Array[Int] = Array::new(capacity=count)
  let mut i = 0
  while i < count {
    let run_header = reader.read_uint8()
    let run_count = (run_header & 0x7F) + 1
    let is_words = (run_header & 0x80) != 0
    let mut point = if points.length() > 0 {
      points[points.length() - 1]
    } else {
      0
    }
    for _j = 0; _j < run_count && i < count; _j = _j + 1 {
      if is_words {
        point = point + reader.read_uint16()
      } else {
        point = point + reader.read_uint8()
      }
      points.push(point)
      i = i + 1
    }
  }
  points
}

///|
/// Unpack RLE-compressed deltas from gvar data
fn unpack_deltas(reader : BinaryReader, count : Int) -> Array[Int] {
  let deltas : Array[Int] = Array::new(capacity=count)
  let mut i = 0
  while i < count {
    let run_header = reader.read_uint8()
    let run_count = (run_header & 0x3F) + 1
    let is_zeros = (run_header & 0x80) != 0
    let is_words = (run_header & 0x40) != 0
    for _j = 0; _j < run_count && i < count; _j = _j + 1 {
      if is_zeros {
        deltas.push(0)
      } else if is_words {
        deltas.push(reader.read_int16())
      } else {
        deltas.push(reader.read_int8())
      }
      i = i + 1
    }
  }
  deltas
}

///|
/// IUP (Interpolation of Untouched Points) for a single contour.
/// Given sparse delta assignments, interpolate deltas for unassigned points.
fn iup_contour(
  deltas : Array[Int],
  coords : Array[Int],
  end_point : Int,
  start_point : Int,
  touch_flags : Array[Bool],
) -> Unit {
  // Find touched points in this contour
  let touched : Array[Int] = []
  for i = start_point; i <= end_point; i = i + 1 {
    if touch_flags[i] {
      touched.push(i)
    }
  }
  if touched.is_empty() {
    return
  }
  if touched.length() == 1 {
    // All points get same delta
    let d = deltas[touched[0]]
    for i = start_point; i <= end_point; i = i + 1 {
      deltas[i] = d
    }
    return
  }
  // Interpolate between each pair of touched points
  let n_touched = touched.length()
  for ti = 0; ti < n_touched; ti = ti + 1 {
    let i0 = touched[ti]
    let i1 = touched[(ti + 1) % n_touched]
    let d0 = deltas[i0]
    let d1 = deltas[i1]
    let c0 = coords[i0]
    let c1 = coords[i1]
    // Points between i0 and i1 (wrapping around contour)
    let mut idx = i0 + 1
    if idx > end_point {
      idx = start_point
    }
    while idx != i1 {
      if not(touch_flags[idx]) {
        let c = coords[idx]
        deltas[idx] = iup_interpolate(c, c0, c1, d0, d1)
      }
      idx = idx + 1
      if idx > end_point {
        idx = start_point
      }
    }
  }
}

///|
/// IUP interpolation helper
fn iup_interpolate(coord : Int, c0 : Int, c1 : Int, d0 : Int, d1 : Int) -> Int {
  if c0 == c1 {
    if d0 == d1 {
      return d0
    }
    return (d0 + d1) / 2
  }
  // Sort so min_c <= max_c
  let (min_c, max_c, min_d, max_d) = if c0 < c1 {
    (c0, c1, d0, d1)
  } else {
    (c1, c0, d1, d0)
  }
  if coord <= min_c {
    return min_d
  }
  if coord >= max_c {
    return max_d
  }
  // Linear interpolation
  let num = (coord - min_c) * (max_d - min_d)
  let den = max_c - min_c
  min_d + (num + den / 2) / den
}

///|
/// Apply gvar deltas to a glyph's coordinates.
/// Returns (dx_array, dy_array) to be added to the original coordinates.
fn apply_gvar_deltas(
  data : Bytes,
  gvar : GvarData,
  glyph_id : Int,
  coords : Array[Double],
  x_coords : Array[Int],
  y_coords : Array[Int],
  end_points : Array[Int],
) -> (Array[Int], Array[Int]) {
  let num_points = x_coords.length()
  let dx_total : Array[Int] = Array::make(num_points, 0)
  let dy_total : Array[Int] = Array::make(num_points, 0)
  if glyph_id >= gvar.glyph_offsets.length() - 1 {
    return (dx_total, dy_total)
  }
  let var_offset = gvar.glyph_var_data_offset + gvar.glyph_offsets[glyph_id]
  let var_end = gvar.glyph_var_data_offset + gvar.glyph_offsets[glyph_id + 1]
  if var_offset >= var_end {
    return (dx_total, dy_total)
  }
  let reader = BinaryReader::at(data, var_offset)
  let tuple_count_word = reader.read_uint16()
  let tuple_count = tuple_count_word & 0x0FFF
  let has_shared_points = (tuple_count_word & 0x8000) != 0
  let data_offset = reader.read_uint16()
  // Shared points (if any)
  let serialized_data_start = var_offset + data_offset
  let ser_reader = BinaryReader::at(data, serialized_data_start)
  let shared_points : Array[Int] = if has_shared_points {
    unpack_points(ser_reader)
  } else {
    []
  }
  // Parse tuple variation headers
  for _t = 0; _t < tuple_count; _t = _t + 1 {
    let variation_data_size = reader.read_uint16()
    let tuple_index = reader.read_uint16()
    let has_embedded_peak = (tuple_index & 0x8000) != 0
    let has_intermediate = (tuple_index & 0x4000) != 0
    let has_private_points = (tuple_index & 0x2000) != 0
    let shared_idx = tuple_index & 0x0FFF
    // Get peak coordinates
    let peak : Array[Double] = []
    if has_embedded_peak {
      for _a = 0; _a < gvar.axis_count; _a = _a + 1 {
        peak.push(reader.read_f2dot14())
      }
    } else if shared_idx < gvar.shared_tuples.length() {
      let st = gvar.shared_tuples[shared_idx]
      for v in st {
        peak.push(v)
      }
    }
    // Get intermediate start/end
    let start : Array[Double] = []
    let end_vals : Array[Double] = []
    if has_intermediate {
      for _a = 0; _a < gvar.axis_count; _a = _a + 1 {
        start.push(reader.read_f2dot14())
      }
      for _a = 0; _a < gvar.axis_count; _a = _a + 1 {
        end_vals.push(reader.read_f2dot14())
      }
    }
    // Compute tuple scalar
    let scalar = compute_tuple_scalar(
      peak, start, end_vals, coords, has_intermediate,
    )
    if scalar == 0.0 {
      // Skip this tuple's serialized data
      let save_pos = ser_reader.position()
      ser_reader.seek(save_pos + variation_data_size)
      continue
    }
    // Read point indices
    let points = if has_private_points {
      unpack_points(ser_reader)
    } else {
      shared_points
    }
    let is_all_points = points.is_empty()
    let n_deltas = if is_all_points { num_points } else { points.length() }
    // Read deltas (x then y)
    let dx = unpack_deltas(ser_reader, n_deltas)
    let dy = unpack_deltas(ser_reader, n_deltas)
    if is_all_points {
      // Apply to all points directly
      for i = 0; i < num_points; i = i + 1 {
        dx_total[i] = dx_total[i] + (dx[i].to_double() * scalar + 0.5).to_int()
        dy_total[i] = dy_total[i] + (dy[i].to_double() * scalar + 0.5).to_int()
      }
    } else {
      // Sparse points: assign then IUP
      let dx_work : Array[Int] = Array::make(num_points, 0)
      let dy_work : Array[Int] = Array::make(num_points, 0)
      let touch_flags : Array[Bool] = Array::make(num_points, false)
      for i = 0; i < points.length(); i = i + 1 {
        let pi = points[i]
        if pi < num_points {
          dx_work[pi] = (dx[i].to_double() * scalar + 0.5).to_int()
          dy_work[pi] = (dy[i].to_double() * scalar + 0.5).to_int()
          touch_flags[pi] = true
        }
      }
      // IUP per contour
      let mut contour_start = 0
      for ep in end_points {
        iup_contour(dx_work, x_coords, ep, contour_start, touch_flags)
        iup_contour(dy_work, y_coords, ep, contour_start, touch_flags)
        contour_start = ep + 1
      }
      for i = 0; i < num_points; i = i + 1 {
        dx_total[i] = dx_total[i] + dx_work[i]
        dy_total[i] = dy_total[i] + dy_work[i]
      }
    }
  }
  (dx_total, dy_total)
}

///|
/// Compute the scalar for a gvar tuple.
/// Without intermediate regions, implicit region is:
///   peak > 0: start=0, end=1.0
///   peak < 0: start=-1.0, end=0
fn compute_tuple_scalar(
  peak : Array[Double],
  start : Array[Double],
  end_vals : Array[Double],
  coords : Array[Double],
  has_intermediate : Bool,
) -> Double {
  let mut scalar = 1.0
  for i = 0; i < peak.length(); i = i + 1 {
    let p = peak[i]
    let c = if i < coords.length() { coords[i] } else { 0.0 }
    if p == 0.0 {
      continue
    }
    if c == p {
      continue
    }
    let (s, e) = if has_intermediate {
      let sv = if i < start.length() { start[i] } else { 0.0 }
      let ev = if i < end_vals.length() { end_vals[i] } else { 0.0 }
      (sv, ev)
    } else if p > 0.0 {
      (0.0, 1.0)
    } else {
      (-1.0, 0.0)
    }
    if c <= s || c >= e {
      return 0.0
    }
    if c < p {
      scalar = scalar * (c - s) / (p - s)
    } else {
      scalar = scalar * (e - c) / (e - p)
    }
  }
  scalar
}
