///|
/// Reconstruct glyf and loca tables from WOFF2 transformed format.
/// Returns (glyf_data, loca_data, x_mins) or None on error.
fn reconstruct_glyf_loca(
  data : Bytes,
  src_offset : Int,
  src_length : Int,
) -> (Bytes, Bytes, Array[Int])? {
  ignore(src_length)
  let reader = BinaryReader::at(data, src_offset)
  // Transformed glyf header (36 bytes)
  let _reserved = reader.read_uint16()
  let option_flags = reader.read_uint16()
  let num_glyphs = reader.read_uint16()
  let index_format = reader.read_uint16()
  let n_contour_stream_size = reader.read_uint32()
  let n_points_stream_size = reader.read_uint32()
  let flag_stream_size = reader.read_uint32()
  let glyph_stream_size = reader.read_uint32()
  let composite_stream_size = reader.read_uint32()
  let bbox_stream_size = reader.read_uint32()
  let instruction_stream_size = reader.read_uint32()
  // Set up 7 substream readers
  let mut offset = src_offset + 36
  let n_contour_reader = BinaryReader::at(data, offset)
  offset += n_contour_stream_size
  let n_points_reader = BinaryReader::at(data, offset)
  offset += n_points_stream_size
  let flag_reader = BinaryReader::at(data, offset)
  offset += flag_stream_size
  let glyph_reader = BinaryReader::at(data, offset)
  offset += glyph_stream_size
  let composite_reader = BinaryReader::at(data, offset)
  offset += composite_stream_size
  let bbox_reader = BinaryReader::at(data, offset)
  offset += bbox_stream_size
  let instruction_reader = BinaryReader::at(data, offset)
  // Overlap bitmap (optional, after instruction stream)
  let has_overlap_bitmap = (option_flags & 1) != 0
  let overlap_bitmap_offset = offset + instruction_stream_size
  // Read bbox bitmap
  let bbox_bitmap_length = (num_glyphs + 31) >> 5 << 2
  let bbox_bitmap_start = bbox_reader.position()
  bbox_reader.skip(bbox_bitmap_length)
  // Output
  let glyf_out : Array[Byte] = []
  let loca_values : Array[Int] = Array::make(num_glyphs + 1, 0)
  let x_mins : Array[Int] = Array::make(num_glyphs, 0)
  // Process each glyph
  for glyph_id = 0; glyph_id < num_glyphs; glyph_id = glyph_id + 1 {
    loca_values[glyph_id] = glyf_out.length()
    let n_contours = n_contour_reader.read_int16()
    let have_bbox = {
      let byte_idx = glyph_id >> 3
      let bit_idx = 7 - (glyph_id & 7)
      (data[bbox_bitmap_start + byte_idx].to_int() & (1 << bit_idx)) != 0
    }
    if n_contours == 0 {
      // Empty glyph - no data
      ()
    } else if n_contours == -1 {
      // Composite glyph (must have explicit bbox)
      if not(have_bbox) {
        return None
      }
      // nContours = -1
      write_be16_arr(glyf_out, -1)
      // bbox from bbox stream
      let bx_min = bbox_reader.read_int16()
      let by_min = bbox_reader.read_int16()
      let bx_max = bbox_reader.read_int16()
      let by_max = bbox_reader.read_int16()
      write_be16_arr(glyf_out, bx_min)
      write_be16_arr(glyf_out, by_min)
      write_be16_arr(glyf_out, bx_max)
      write_be16_arr(glyf_out, by_max)
      x_mins[glyph_id] = bx_min
      // Read composite data
      let have_instructions = read_composite_glyph(composite_reader, glyf_out)
      if have_instructions {
        let instruction_size = read_255ushort(glyph_reader)
        write_be16_arr(glyf_out, instruction_size)
        for j = 0; j < instruction_size; j = j + 1 {
          glyf_out.push(instruction_reader.read_uint8().to_byte())
        }
      }
      // Pad to 4-byte boundary
      while glyf_out.length() % 4 != 0 {
        glyf_out.push(b'\x00')
      }
    } else {
      // Simple glyph
      let mut total_points = 0
      let end_points : Array[Int] = Array::make(n_contours, 0)
      let mut end_point = -1
      for c = 0; c < n_contours; c = c + 1 {
        let n = read_255ushort(n_points_reader)
        total_points += n
        end_point += n
        end_points[c] = end_point
        ignore(c)
      }
      // Check overlap bitmap
      let has_overlap = has_overlap_bitmap &&
        ({
          let byte_idx = glyph_id >> 3
          let bit_idx = 7 - (glyph_id & 7)
          (data[overlap_bitmap_offset + byte_idx].to_int() & (1 << bit_idx)) !=
          0
        })
      // Decode triplet-encoded points → TrueType format
      let (
        flags_bytes,
        x_bytes,
        y_bytes,
        comp_x_min,
        comp_y_min,
        comp_x_max,
        comp_y_max,
      ) = decode_triplets_to_truetype(
        flag_reader, glyph_reader, total_points, has_overlap,
      )
      // Read instruction size
      let instruction_size = read_255ushort(glyph_reader)
      // Write nContours
      write_be16_arr(glyf_out, n_contours)
      // Write bbox
      if have_bbox {
        let bx_min = bbox_reader.read_int16()
        let by_min = bbox_reader.read_int16()
        let bx_max = bbox_reader.read_int16()
        let by_max = bbox_reader.read_int16()
        write_be16_arr(glyf_out, bx_min)
        write_be16_arr(glyf_out, by_min)
        write_be16_arr(glyf_out, bx_max)
        write_be16_arr(glyf_out, by_max)
        x_mins[glyph_id] = bx_min
      } else {
        write_be16_arr(glyf_out, comp_x_min)
        write_be16_arr(glyf_out, comp_y_min)
        write_be16_arr(glyf_out, comp_x_max)
        write_be16_arr(glyf_out, comp_y_max)
        x_mins[glyph_id] = comp_x_min
      }
      // Write end points of contours
      for c = 0; c < n_contours; c = c + 1 {
        write_be16_arr(glyf_out, end_points[c])
        ignore(c)
      }
      // Write instructions
      write_be16_arr(glyf_out, instruction_size)
      for j = 0; j < instruction_size; j = j + 1 {
        glyf_out.push(instruction_reader.read_uint8().to_byte())
      }
      // Write flags
      for j = 0; j < flags_bytes.length(); j = j + 1 {
        glyf_out.push(flags_bytes[j])
      }
      // Write x coordinates
      for j = 0; j < x_bytes.length(); j = j + 1 {
        glyf_out.push(x_bytes[j])
      }
      // Write y coordinates
      for j = 0; j < y_bytes.length(); j = j + 1 {
        glyf_out.push(y_bytes[j])
      }
      // Pad to 4-byte boundary
      while glyf_out.length() % 4 != 0 {
        glyf_out.push(b'\x00')
      }
    }
    ignore(glyph_id)
  }
  // Final loca entry
  loca_values[num_glyphs] = glyf_out.length()
  // Build loca table
  let loca_size = if index_format != 0 {
    (num_glyphs + 1) * 4
  } else {
    (num_glyphs + 1) * 2
  }
  let loca_out : Array[Byte] = Array::make(loca_size, b'\x00')
  for i = 0; i <= num_glyphs; i = i + 1 {
    if index_format != 0 {
      loca_out[i * 4] = ((loca_values[i] >> 24) & 0xFF).to_byte()
      loca_out[i * 4 + 1] = ((loca_values[i] >> 16) & 0xFF).to_byte()
      loca_out[i * 4 + 2] = ((loca_values[i] >> 8) & 0xFF).to_byte()
      loca_out[i * 4 + 3] = (loca_values[i] & 0xFF).to_byte()
    } else {
      let v = loca_values[i] >> 1
      loca_out[i * 2] = ((v >> 8) & 0xFF).to_byte()
      loca_out[i * 2 + 1] = (v & 0xFF).to_byte()
    }
    ignore(i)
  }
  let glyf_bytes = Bytes::from_array(glyf_out[:])
  let loca_bytes = Bytes::from_array(loca_out[:])
  Some((glyf_bytes, loca_bytes, x_mins))
}

///|
/// Read a composite glyph from the composite stream, appending data to glyf_out.
/// Returns whether the glyph has instructions.
fn read_composite_glyph(
  composite_reader : BinaryReader,
  glyf_out : Array[Byte],
) -> Bool {
  let flag_arg_1_and_2_are_words = 1
  let flag_we_have_a_scale = 8
  let flag_more_components = 32
  let flag_we_have_an_x_and_y_scale = 64
  let flag_we_have_a_two_by_two = 128
  let flag_we_have_instructions = 256
  let mut have_instructions = false
  let mut more = true
  while more {
    let flags = composite_reader.read_uint16()
    have_instructions = have_instructions ||
      (flags & flag_we_have_instructions) != 0
    more = (flags & flag_more_components) != 0
    // Write flags word
    glyf_out.push(((flags >> 8) & 0xFF).to_byte())
    glyf_out.push((flags & 0xFF).to_byte())
    // Glyph index (uint16) + arguments + optional scale/matrix
    let mut arg_size = 2 // glyph index
    if (flags & flag_arg_1_and_2_are_words) != 0 {
      arg_size += 4
    } else {
      arg_size += 2
    }
    if (flags & flag_we_have_a_scale) != 0 {
      arg_size += 2
    } else if (flags & flag_we_have_an_x_and_y_scale) != 0 {
      arg_size += 4
    } else if (flags & flag_we_have_a_two_by_two) != 0 {
      arg_size += 8
    }
    for j = 0; j < arg_size; j = j + 1 {
      glyf_out.push(composite_reader.read_uint8().to_byte())
    }
  }
  have_instructions
}

///|
/// Decode WOFF2 triplet-encoded points and re-encode to TrueType format.
/// Returns (flags_bytes, x_bytes, y_bytes, xMin, yMin, xMax, yMax)
fn decode_triplets_to_truetype(
  flag_reader : BinaryReader,
  glyph_reader : BinaryReader,
  n_points : Int,
  has_overlap_bit : Bool,
) -> (Array[Byte], Array[Byte], Array[Byte], Int, Int, Int, Int) {
  // TrueType simple glyph flag bits
  let tt_on_curve = 1
  let tt_x_short = 2
  let tt_y_short = 4
  let tt_repeat = 8
  let tt_x_same = 16
  let tt_y_same = 32
  let tt_overlap_simple = 64
  let flags_out : Array[Byte] = []
  let x_out : Array[Byte] = []
  let y_out : Array[Byte] = []
  let mut x = 0
  let mut y = 0
  let mut x_min = 0
  let mut y_min = 0
  let mut x_max = 0
  let mut y_max = 0
  let mut last_flag = -1
  let mut repeat_count = 0
  for i = 0; i < n_points; i = i + 1 {
    let flag = flag_reader.read_uint8()
    let on_curve = (flag & 0x80) == 0 // bit 7 = 0 means on-curve in WOFF2
    let flag_low = flag & 0x7F
    let mut dx = 0
    let mut dy = 0
    if flag_low < 10 {
      // dx = 0, dy from 1 byte
      dx = 0
      let b = glyph_reader.read_uint8()
      dy = ((flag_low & 14) << 7) + b
      if (flag_low & 1) == 0 {
        dy = -dy
      }
    } else if flag_low < 20 {
      // dy = 0, dx from 1 byte
      let b = glyph_reader.read_uint8()
      dx = (((flag_low - 10) & 14) << 7) + b
      if (flag_low & 1) == 0 {
        dx = -dx
      }
      dy = 0
    } else if flag_low < 84 {
      // 1 byte packed dx, dy (4 bits each with offsets)
      let b = glyph_reader.read_uint8()
      let b0 = flag_low - 20
      dx = 1 + (b0 & 0x30) + (b >> 4)
      dy = 1 + ((b0 & 0x0C) << 2) + (b & 0x0F)
      if (flag_low & 1) == 0 {
        dx = -dx
      }
      if (flag_low & 2) == 0 {
        dy = -dy
      }
    } else if flag_low < 120 {
      // 2 bytes: 1 byte dx, 1 byte dy with offsets
      let b0 = glyph_reader.read_uint8()
      let b1 = glyph_reader.read_uint8()
      let idx = flag_low - 84
      dx = 1 + ((idx / 12) << 8) + b0
      dy = 1 + ((idx % 12) >> 2 << 8) + b1
      if (flag_low & 1) == 0 {
        dx = -dx
      }
      if (flag_low & 2) == 0 {
        dy = -dy
      }
    } else if flag_low < 124 {
      // 3 bytes: 12-bit dx, 12-bit dy
      let b0 = glyph_reader.read_uint8()
      let b1 = glyph_reader.read_uint8()
      let b2 = glyph_reader.read_uint8()
      dx = (b0 << 4) + (b1 >> 4)
      dy = ((b1 & 0x0F) << 8) + b2
      if (flag_low & 1) == 0 {
        dx = -dx
      }
      if (flag_low & 2) == 0 {
        dy = -dy
      }
    } else {
      // 4 bytes: 16-bit dx, 16-bit dy
      let b0 = glyph_reader.read_uint8()
      let b1 = glyph_reader.read_uint8()
      let b2 = glyph_reader.read_uint8()
      let b3 = glyph_reader.read_uint8()
      dx = (b0 << 8) + b1
      dy = (b2 << 8) + b3
      if (flag_low & 1) == 0 {
        dx = -dx
      }
      if (flag_low & 2) == 0 {
        dy = -dy
      }
    }
    x += dx
    y += dy
    if i == 0 {
      x_min = x
      x_max = x
      y_min = y
      y_max = y
    } else {
      if x < x_min {
        x_min = x
      }
      if x > x_max {
        x_max = x
      }
      if y < y_min {
        y_min = y
      }
      if y > y_max {
        y_max = y
      }
    }
    // Build TrueType flag byte
    let mut out_flag = if on_curve { tt_on_curve } else { 0 }
    if has_overlap_bit && i == 0 {
      out_flag = out_flag | tt_overlap_simple
    }
    // Encode x coordinate delta
    if dx == 0 {
      out_flag = out_flag | tt_x_same
    } else if dx >= -255 && dx <= 255 {
      out_flag = out_flag | tt_x_short
      if dx > 0 {
        out_flag = out_flag | tt_x_same
      }
      let abs_dx = if dx > 0 { dx } else { -dx }
      x_out.push(abs_dx.to_byte())
    } else {
      // 2-byte signed delta
      x_out.push(((dx >> 8) & 0xFF).to_byte())
      x_out.push((dx & 0xFF).to_byte())
    }
    // Encode y coordinate delta
    if dy == 0 {
      out_flag = out_flag | tt_y_same
    } else if dy >= -255 && dy <= 255 {
      out_flag = out_flag | tt_y_short
      if dy > 0 {
        out_flag = out_flag | tt_y_same
      }
      let abs_dy = if dy > 0 { dy } else { -dy }
      y_out.push(abs_dy.to_byte())
    } else {
      // 2-byte signed delta
      y_out.push(((dy >> 8) & 0xFF).to_byte())
      y_out.push((dy & 0xFF).to_byte())
    }
    // TrueType flag repeat compression
    if out_flag == last_flag && repeat_count < 255 {
      let idx = flags_out.length() - 1
      flags_out[idx] = (flags_out[idx].to_int() | tt_repeat).to_byte()
      repeat_count += 1
    } else {
      if repeat_count > 0 {
        flags_out.push(repeat_count.to_byte())
        repeat_count = 0
      }
      flags_out.push(out_flag.to_byte())
      last_flag = out_flag
    }
    ignore(i)
  }
  if repeat_count > 0 {
    flags_out.push(repeat_count.to_byte())
  }
  (flags_out, x_out, y_out, x_min, y_min, x_max, y_max)
}

///|
/// Reconstruct hmtx table from WOFF2 transformed format
fn reconstruct_hmtx(
  data : Bytes,
  src_offset : Int,
  src_length : Int,
  num_glyphs : Int,
  num_h_metrics : Int,
  x_mins : Array[Int],
) -> Bytes {
  ignore(src_length)
  let reader = BinaryReader::at(data, src_offset)
  let hmtx_flags = reader.read_uint8()
  let has_proportional_lsbs = (hmtx_flags & 1) == 0
  let has_monospace_lsbs = (hmtx_flags & 2) == 0
  // Read advance widths
  let advance_widths : Array[Int] = Array::make(num_h_metrics, 0)
  for i = 0; i < num_h_metrics; i = i + 1 {
    advance_widths[i] = reader.read_uint16()
    ignore(i)
  }
  // Read LSBs
  let lsbs : Array[Int] = Array::make(num_glyphs, 0)
  for i = 0; i < num_h_metrics; i = i + 1 {
    if has_proportional_lsbs {
      lsbs[i] = reader.read_int16()
    } else {
      lsbs[i] = if i < x_mins.length() { x_mins[i] } else { 0 }
    }
    ignore(i)
  }
  for i = num_h_metrics; i < num_glyphs; i = i + 1 {
    if has_monospace_lsbs {
      lsbs[i] = reader.read_int16()
    } else {
      lsbs[i] = if i < x_mins.length() { x_mins[i] } else { 0 }
    }
    ignore(i)
  }
  // Build output: numHMetrics * 4 + (numGlyphs - numHMetrics) * 2
  let output_size = num_h_metrics * 4 + (num_glyphs - num_h_metrics) * 2
  let out : Array[Byte] = Array::make(output_size, b'\x00')
  let mut offset = 0
  for i = 0; i < num_glyphs; i = i + 1 {
    if i < num_h_metrics {
      out[offset] = ((advance_widths[i] >> 8) & 0xFF).to_byte()
      out[offset + 1] = (advance_widths[i] & 0xFF).to_byte()
      offset += 2
    }
    let lsb = lsbs[i]
    out[offset] = ((lsb >> 8) & 0xFF).to_byte()
    out[offset + 1] = (lsb & 0xFF).to_byte()
    offset += 2
    ignore(i)
  }
  Bytes::from_array(out[:])
}
