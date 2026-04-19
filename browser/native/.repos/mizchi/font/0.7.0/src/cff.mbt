///|
fn parse_cff_index(reader : BinaryReader) -> CFFIndex {
  let count = reader.read_uint16()
  if count == 0 {
    return { data_offset: reader.position(), offsets: [0] }
  }
  let off_size = reader.read_uint8()
  let offsets = Array::new(capacity=count + 1)
  for i = 0; i <= count; i = i + 1 {
    let off = read_cff_offset(reader, off_size)
    offsets.push(off - 1)
    ignore(i)
  }
  let data_offset = reader.position()
  let data_size = offsets[count]
  reader.skip(data_size)
  { data_offset, offsets }
}

///|
fn read_cff_offset(reader : BinaryReader, off_size : Int) -> Int {
  match off_size {
    1 => reader.read_uint8()
    2 => reader.read_uint16()
    3 => {
      let b0 = reader.read_uint8()
      let b1 = reader.read_uint8()
      let b2 = reader.read_uint8()
      (b0 << 16) | (b1 << 8) | b2
    }
    4 => reader.read_uint32()
    _ => 0
  }
}

///|
fn CFFIndex::count(self : CFFIndex) -> Int {
  if self.offsets.length() <= 1 {
    0
  } else {
    self.offsets.length() - 1
  }
}

///|
fn CFFIndex::entry(self : CFFIndex, i : Int) -> (Int, Int) {
  let start = self.data_offset + self.offsets[i]
  let len = self.offsets[i + 1] - self.offsets[i]
  (start, len)
}

///|
fn parse_cff_dict(
  data : Bytes,
  offset : Int,
  length : Int,
) -> Map[Int, Array[Int]] {
  let result : Map[Int, Array[Int]] = {}
  let reader = BinaryReader::at(data, offset)
  let end = offset + length
  let operands : Array[Int] = []
  while reader.position() < end {
    let b0 = reader.read_uint8()
    if b0 >= 32 {
      let val = decode_dict_operand(reader, b0)
      operands.push(val)
    } else if b0 == 12 {
      let b1 = reader.read_uint8()
      let op = 1200 + b1
      result[op] = operands.copy()
      operands.clear()
    } else {
      result[b0] = operands.copy()
      operands.clear()
    }
  }
  result
}

///|
fn decode_dict_operand(reader : BinaryReader, b0 : Int) -> Int {
  if b0 >= 32 && b0 <= 246 {
    b0 - 139
  } else if b0 >= 247 && b0 <= 250 {
    let b1 = reader.read_uint8()
    (b0 - 247) * 256 + b1 + 108
  } else if b0 >= 251 && b0 <= 254 {
    let b1 = reader.read_uint8()
    -(b0 - 251) * 256 - b1 - 108
  } else if b0 == 28 {
    let hi = reader.read_uint8()
    let lo = reader.read_uint8()
    let val = (hi << 8) | lo
    if val >= 32768 {
      val - 65536
    } else {
      val
    }
  } else if b0 == 29 {
    let b1 = reader.read_uint8()
    let b2 = reader.read_uint8()
    let b3 = reader.read_uint8()
    let b4 = reader.read_uint8()
    (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
  } else if b0 == 30 {
    skip_real_number(reader)
    0
  } else {
    0
  }
}

///|
fn skip_real_number(reader : BinaryReader) -> Unit {
  for i = 0; i < 20; i = i + 1 {
    let b = reader.read_uint8()
    let hi = (b >> 4) & 0xF
    let lo = b & 0xF
    if hi == 0xF || lo == 0xF {
      return
    }
    ignore(i)
  }
}

///|
fn parse_cff_table(data : Bytes, cff_offset : Int) -> CFFData? {
  let reader = BinaryReader::at(data, cff_offset)
  let _major = reader.read_uint8()
  let _minor = reader.read_uint8()
  let hdr_size = reader.read_uint8()
  let _off_size = reader.read_uint8()
  reader.seek(cff_offset + hdr_size)
  let _name_index = parse_cff_index(reader)
  let top_dict_index = parse_cff_index(reader)
  if top_dict_index.count() == 0 {
    return None
  }
  let _string_index = parse_cff_index(reader)
  let global_subrs = parse_cff_index(reader)
  let (td_offset, td_length) = top_dict_index.entry(0)
  let top_dict = parse_cff_dict(data, td_offset, td_length)
  let charstrings_offset = match top_dict.get(17) {
    Some(ops) => if ops.length() > 0 { ops[0] } else { return None }
    None => return None
  }
  let (private_size, private_offset) = match top_dict.get(18) {
    Some(ops) => if ops.length() >= 2 { (ops[0], ops[1]) } else { (0, 0) }
    None => (0, 0)
  }
  let cs_reader = BinaryReader::at(data, cff_offset + charstrings_offset)
  let charstrings = parse_cff_index(cs_reader)
  let mut default_width_x = 0
  let mut nominal_width_x = 0
  let mut local_subrs : CFFIndex = { data_offset: 0, offsets: [0] }
  if private_size > 0 {
    let priv_abs_offset = cff_offset + private_offset
    let priv_dict = parse_cff_dict(data, priv_abs_offset, private_size)
    if priv_dict.get(20) is Some(ops) {
      if ops.length() > 0 {
        default_width_x = ops[0]
      }
    }
    if priv_dict.get(21) is Some(ops) {
      if ops.length() > 0 {
        nominal_width_x = ops[0]
      }
    }
    match priv_dict.get(19) {
      Some(ops) =>
        if ops.length() > 0 {
          let subr_offset = priv_abs_offset + ops[0]
          let subr_reader = BinaryReader::at(data, subr_offset)
          local_subrs = parse_cff_index(subr_reader)
        }
      None => ()
    }
  }
  Some({
    charstrings,
    global_subrs,
    local_subrs,
    default_width_x,
    nominal_width_x,
    is_cff2: false,
    ivs: None,
  })
}

///|
/// Parse a CFF2 INDEX structure (count is uint32 instead of uint16)
fn parse_cff2_index(reader : BinaryReader) -> CFFIndex {
  let count = reader.read_uint32()
  if count == 0 {
    return { data_offset: reader.position(), offsets: [0] }
  }
  let off_size = reader.read_uint8()
  let offsets = Array::new(capacity=count + 1)
  for i = 0; i <= count; i = i + 1 {
    let off = read_cff_offset(reader, off_size)
    offsets.push(off - 1)
    ignore(i)
  }
  let data_offset = reader.position()
  let data_size = offsets[count]
  reader.skip(data_size)
  { data_offset, offsets }
}

///|
/// Normalize a user-space axis value to [-1, 1]
fn normalize_axis_coord(value : Double, axis : VarAxis) -> Double {
  if value <= axis.default_value {
    if value <= axis.min_value {
      return -1.0
    }
    if axis.default_value == axis.min_value {
      return 0.0
    }
    -(axis.default_value - value) / (axis.default_value - axis.min_value)
  } else {
    if value >= axis.max_value {
      return 1.0
    }
    if axis.max_value == axis.default_value {
      return 0.0
    }
    (value - axis.default_value) / (axis.max_value - axis.default_value)
  }
}

///|
/// Compute the scalar for a single variation region given normalized coordinates
fn compute_region_scalar(region : VarRegion, coords : Array[Double]) -> Double {
  let mut scalar = 1.0
  for i = 0; i < region.axes.length(); i = i + 1 {
    let ra = region.axes[i]
    let coord = if i < coords.length() { coords[i] } else { 0.0 }
    if ra.peak_coord == 0.0 {
      continue
    }
    if coord == ra.peak_coord {
      continue
    }
    if coord <= ra.start_coord || coord >= ra.end_coord {
      return 0.0
    }
    if coord < ra.peak_coord {
      scalar = scalar *
        (coord - ra.start_coord) /
        (ra.peak_coord - ra.start_coord)
    } else {
      scalar = scalar * (ra.end_coord - coord) / (ra.end_coord - ra.peak_coord)
    }
  }
  scalar
}

///|
/// Precompute scalars for all regions referenced by a given vsindex
fn precompute_scalars(
  ivs : ItemVariationStore,
  vsindex : Int,
  coords : Array[Double],
) -> Array[Double] {
  if vsindex < 0 || vsindex >= ivs.data.length() {
    return []
  }
  let ivd = ivs.data[vsindex]
  let scalars : Array[Double] = []
  for ri in ivd.region_indices {
    if ri >= 0 && ri < ivs.regions.length() {
      scalars.push(compute_region_scalar(ivs.regions[ri], coords))
    } else {
      scalars.push(0.0)
    }
  }
  scalars
}

///|
/// Parse an ItemVariationStore from CFF2 TopDICT op 24
fn parse_item_variation_store(data : Bytes, offset : Int) -> ItemVariationStore {
  let reader = BinaryReader::at(data, offset)
  let _length = reader.read_uint16() // total length
  let _format = reader.read_uint16() // must be 1
  let region_list_offset = reader.read_uint32()
  let data_count = reader.read_uint16()
  // Read data offsets
  let data_offsets : Array[Int] = []
  for i = 0; i < data_count; i = i + 1 {
    data_offsets.push(reader.read_uint32())
    ignore(i)
  }
  // Parse VarRegionList
  let rl_abs = offset + 2 + region_list_offset // skip length field (2 bytes)
  let rl_reader = BinaryReader::at(data, rl_abs)
  let axis_count = rl_reader.read_uint16()
  let region_count = rl_reader.read_uint16()
  let regions : Array[VarRegion] = []
  for _r = 0; _r < region_count; _r = _r + 1 {
    let axes : Array[VarRegionAxis] = []
    for _a = 0; _a < axis_count; _a = _a + 1 {
      let start_coord = rl_reader.read_f2dot14()
      let peak_coord = rl_reader.read_f2dot14()
      let end_coord = rl_reader.read_f2dot14()
      axes.push({ start_coord, peak_coord, end_coord })
    }
    regions.push({ axes, })
  }
  // Parse ItemVariationData subtables
  let ivd_list : Array[ItemVariationData] = []
  for i = 0; i < data_count; i = i + 1 {
    let ivd_abs = offset + 2 + data_offsets[i] // skip length field
    let ivd_reader = BinaryReader::at(data, ivd_abs)
    let item_count = ivd_reader.read_uint16()
    let word_delta_count = ivd_reader.read_uint16()
    let region_index_count = ivd_reader.read_uint16()
    let long_words = (word_delta_count & 0x8000) != 0
    let word_count = word_delta_count & 0x7FFF
    let region_indices : Array[Int] = []
    for _j = 0; _j < region_index_count; _j = _j + 1 {
      region_indices.push(ivd_reader.read_uint16())
    }
    let delta_sets : Array[Array[Int]] = []
    for _item = 0; _item < item_count; _item = _item + 1 {
      let deltas : Array[Int] = []
      for col = 0; col < region_index_count; col = col + 1 {
        if col < word_count {
          if long_words {
            deltas.push(ivd_reader.read_uint32())
          } else {
            deltas.push(ivd_reader.read_int16())
          }
        } else if long_words {
          deltas.push(ivd_reader.read_int16())
        } else {
          deltas.push(ivd_reader.read_int8())
        }
      }
      delta_sets.push(deltas)
    }
    ivd_list.push({ region_indices, delta_sets })
    ignore(i)
  }
  { regions, data: ivd_list }
}

///|
/// Parse a CFF2 table
fn parse_cff2_table(data : Bytes, cff2_offset : Int) -> CFFData? {
  let reader = BinaryReader::at(data, cff2_offset)
  let _major = reader.read_uint8() // 2
  let _minor = reader.read_uint8() // 0
  let hdr_size = reader.read_uint8()
  let top_dict_length = reader.read_uint16()
  // TopDICT starts at hdrSize, raw bytes (not INDEX)
  reader.seek(cff2_offset + hdr_size)
  let top_dict = parse_cff_dict(data, cff2_offset + hdr_size, top_dict_length)
  // Global Subr INDEX follows TopDICT
  reader.seek(cff2_offset + hdr_size + top_dict_length)
  let global_subrs = parse_cff2_index(reader)
  // CharStrings INDEX from TopDICT op 17
  let charstrings_offset = match top_dict.get(17) {
    Some(ops) => if ops.length() > 0 { ops[0] } else { return None }
    None => return None
  }
  let cs_reader = BinaryReader::at(data, cff2_offset + charstrings_offset)
  let charstrings = parse_cff2_index(cs_reader)
  // FDArray from TopDICT op 1236
  let mut local_subrs : CFFIndex = { data_offset: 0, offsets: [0] }
  if top_dict.get(1236) is Some(ops) && ops.length() > 0 {
    let fd_offset = cff2_offset + ops[0]
    let fd_reader = BinaryReader::at(data, fd_offset)
    let fd_index = parse_cff2_index(fd_reader)
    if fd_index.count() > 0 {
      let (fd_entry_offset, fd_entry_length) = fd_index.entry(0)
      let font_dict = parse_cff_dict(data, fd_entry_offset, fd_entry_length)
      if font_dict.get(18) is Some(priv_ops) && priv_ops.length() >= 2 {
        let priv_size = priv_ops[0]
        let priv_offset = cff2_offset + priv_ops[1]
        if priv_size > 0 {
          let priv_dict = parse_cff_dict(data, priv_offset, priv_size)
          if priv_dict.get(19) is Some(subr_ops) && subr_ops.length() > 0 {
            let subr_offset = priv_offset + subr_ops[0]
            let subr_reader = BinaryReader::at(data, subr_offset)
            local_subrs = parse_cff2_index(subr_reader)
          }
        }
      }
    }
  }
  // ItemVariationStore from TopDICT op 24
  let ivs : ItemVariationStore? = top_dict
    .get(24)
    .map(fn(ops) {
      if ops.length() > 0 {
        let ivs_offset = cff2_offset + ops[0]
        Some(parse_item_variation_store(data, ivs_offset))
      } else {
        None
      }
    })
    .bind(fn(x) { x })
  Some({
    charstrings,
    global_subrs,
    local_subrs,
    default_width_x: 0,
    nominal_width_x: 0,
    is_cff2: true,
    ivs,
  })
}

///|
fn calc_subr_bias(count : Int) -> Int {
  if count < 1240 {
    107
  } else if count < 33900 {
    1131
  } else {
    32768
  }
}

///|
/// Mutable state for the CharString interpreter
priv struct CSState {
  mut x : Double
  mut y : Double
  mut has_width : Bool
  mut num_stems : Int
  mut first_move : Bool
  mut ended : Bool
  is_cff2 : Bool
  storage : FixedArray[Double] // put/get storage (32 slots, CFF spec)
  mut vsindex : Int
  mut scalars : Array[Double]?
}

///|
fn cff_glyph_outline(
  data : Bytes,
  cff : CFFData,
  glyph_id : Int,
) -> Array[@svg.PathCommand] {
  if glyph_id < 0 || glyph_id >= cff.charstrings.count() {
    return []
  }
  let (cs_offset, cs_length) = cff.charstrings.entry(glyph_id)
  let commands : Array[@svg.PathCommand] = []
  let stack : Array[Double] = []
  let state : CSState = {
    x: 0.0,
    y: 0.0,
    has_width: false,
    num_stems: 0,
    first_move: true,
    ended: false,
    is_cff2: cff.is_cff2,
    storage: FixedArray::make(32, 0.0),
    vsindex: 0,
    scalars: None,
  }
  interpret_charstring(
    data, cs_offset, cs_length, cff, commands, stack, state, 0,
  )
  // CFF2: endchar is optional; close path implicitly if not ended
  if cff.is_cff2 && not(state.ended) && not(state.first_move) {
    commands.push(@svg.ClosePath)
  }
  commands
}

///|
fn cff_glyph_outline_var(
  data : Bytes,
  cff : CFFData,
  glyph_id : Int,
  scalars : Array[Double],
) -> Array[@svg.PathCommand] {
  if glyph_id < 0 || glyph_id >= cff.charstrings.count() {
    return []
  }
  let (cs_offset, cs_length) = cff.charstrings.entry(glyph_id)
  let commands : Array[@svg.PathCommand] = []
  let stack : Array[Double] = []
  let state : CSState = {
    x: 0.0,
    y: 0.0,
    has_width: false,
    num_stems: 0,
    first_move: true,
    ended: false,
    is_cff2: true,
    storage: FixedArray::make(32, 0.0),
    vsindex: 0,
    scalars: Some(scalars),
  }
  interpret_charstring(
    data, cs_offset, cs_length, cff, commands, stack, state, 0,
  )
  if not(state.ended) && not(state.first_move) {
    commands.push(@svg.ClosePath)
  }
  commands
}

///|
fn interpret_charstring(
  data : Bytes,
  offset : Int,
  length : Int,
  cff : CFFData,
  commands : Array[@svg.PathCommand],
  stack : Array[Double],
  state : CSState,
  depth : Int,
) -> Unit {
  if depth > 10 {
    return
  }
  let reader = BinaryReader::at(data, offset)
  let end = offset + length
  while reader.position() < end {
    let b0 = reader.read_uint8()
    if b0 == 28 {
      let hi = reader.read_uint8()
      let lo = reader.read_uint8()
      let val = (hi << 8) | lo
      let signed = if val >= 32768 { val - 65536 } else { val }
      stack.push(signed.to_double())
    } else if b0 == 255 {
      // Fixed 16.16: read as signed 32-bit via two int16 reads
      let hi = reader.read_int16()
      let lo = reader.read_uint16()
      let raw = hi * 65536 + lo
      stack.push(raw.to_double() / 65536.0)
    } else if b0 >= 32 && b0 <= 246 {
      stack.push((b0 - 139).to_double())
    } else if b0 >= 247 && b0 <= 250 {
      let b1 = reader.read_uint8()
      stack.push(((b0 - 247) * 256 + b1 + 108).to_double())
    } else if b0 >= 251 && b0 <= 254 {
      let b1 = reader.read_uint8()
      stack.push((-(b0 - 251) * 256 - b1 - 108).to_double())
    } else {
      exec_operator(data, b0, reader, cff, commands, stack, state, depth)
      if state.ended {
        return
      }
    }
  }
}

///|
fn check_width(stack : Array[Double], state : CSState, expected : Int) -> Unit {
  if not(state.has_width) {
    if not(state.is_cff2) && stack.length() > expected {
      let _ = stack.remove(0)
    }
    state.has_width = true
  }
}

///|
fn exec_operator(
  data : Bytes,
  b0 : Int,
  reader : BinaryReader,
  cff : CFFData,
  commands : Array[@svg.PathCommand],
  stack : Array[Double],
  state : CSState,
  depth : Int,
) -> Unit {
  match b0 {
    1 | 3 | 18 | 23 => {
      // hstem, vstem, hstemhm, vstemhm
      let pair_count = stack.length() / 2 * 2
      check_width(stack, state, pair_count)
      state.num_stems = state.num_stems + stack.length() / 2
      stack.clear()
    }
    4 => {
      // vmoveto
      check_width(stack, state, 1)
      if not(state.first_move) {
        commands.push(@svg.ClosePath)
      }
      state.first_move = false
      state.y = state.y + stack[0]
      commands.push(@svg.MoveTo(state.x, state.y))
      stack.clear()
    }
    5 => {
      // rlineto
      let mut i = 0
      while i + 1 < stack.length() {
        state.x = state.x + stack[i]
        state.y = state.y + stack[i + 1]
        commands.push(@svg.LineTo(state.x, state.y))
        i = i + 2
      }
      stack.clear()
    }
    6 => {
      // hlineto
      let mut horiz = true
      for i in 0..<stack.length() {
        if horiz {
          state.x = state.x + stack[i]
        } else {
          state.y = state.y + stack[i]
        }
        commands.push(@svg.LineTo(state.x, state.y))
        horiz = not(horiz)
      }
      stack.clear()
    }
    7 => {
      // vlineto
      let mut horiz = false
      for i in 0..<stack.length() {
        if horiz {
          state.x = state.x + stack[i]
        } else {
          state.y = state.y + stack[i]
        }
        commands.push(@svg.LineTo(state.x, state.y))
        horiz = not(horiz)
      }
      stack.clear()
    }
    8 => {
      // rrcurveto
      let mut i = 0
      while i + 5 < stack.length() {
        let cx1 = state.x + stack[i]
        let cy1 = state.y + stack[i + 1]
        let cx2 = cx1 + stack[i + 2]
        let cy2 = cy1 + stack[i + 3]
        state.x = cx2 + stack[i + 4]
        state.y = cy2 + stack[i + 5]
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, state.x, state.y))
        i = i + 6
      }
      stack.clear()
    }
    10 => {
      // callsubr (local)
      let idx = stack.unsafe_pop().to_int() +
        calc_subr_bias(cff.local_subrs.count())
      if idx >= 0 && idx < cff.local_subrs.count() {
        let (sub_off, sub_len) = cff.local_subrs.entry(idx)
        interpret_charstring(
          data,
          sub_off,
          sub_len,
          cff,
          commands,
          stack,
          state,
          depth + 1,
        )
      }
    }
    11 => () // return
    12 => {
      let b1 = reader.read_uint8()
      exec_operator_12(b1, commands, stack, state)
    }
    14 => {
      // endchar
      check_width(stack, state, 0)
      if not(state.first_move) {
        commands.push(@svg.ClosePath)
      }
      stack.clear()
      state.ended = true
    }
    15 =>
      // vsindex (CFF2): set variation index and recompute scalars
      if state.is_cff2 && stack.length() > 0 {
        state.vsindex = stack.unsafe_pop().to_int()
        if cff.ivs is Some(ivs) && state.scalars is Some(_) {
          let new_scalars = precompute_scalars(ivs, state.vsindex, [])
          state.scalars = Some(new_scalars)
        }
      }
    16 =>
      // blend (CFF2): interpolate deltas into base values
      if state.is_cff2 && stack.length() > 0 {
        let n = stack.unsafe_pop().to_int()
        match state.scalars {
          Some(scalars) => {
            let k = scalars.length()
            // Stack layout: val1..valN d1_1..d1_k .. dN_1..dN_k
            let base_start = stack.length() - n * k - n
            for i = 0; i < n; i = i + 1 {
              let mut blended = stack[base_start + i]
              for j = 0; j < k; j = j + 1 {
                blended = blended +
                  stack[base_start + n + i * k + j] * scalars[j]
              }
              stack[base_start + i] = blended
            }
            // Remove deltas, keep blended base values
            let new_len = stack.length() - n * k
            while stack.length() > new_len {
              let _ = stack.unsafe_pop()
            }
          }
          None =>
            // No variation: just remove deltas (k=0, nothing to pop beyond N)
            ()
        }
      }
    19 | 20 => {
      // hintmask, cntrmask
      let pair_count = stack.length() / 2 * 2
      check_width(stack, state, pair_count)
      state.num_stems = state.num_stems + stack.length() / 2
      stack.clear()
      let mask_bytes = (state.num_stems + 7) / 8
      reader.skip(mask_bytes)
    }
    21 => {
      // rmoveto
      check_width(stack, state, 2)
      if not(state.first_move) {
        commands.push(@svg.ClosePath)
      }
      state.first_move = false
      state.x = state.x + stack[0]
      state.y = state.y + stack[1]
      commands.push(@svg.MoveTo(state.x, state.y))
      stack.clear()
    }
    22 => {
      // hmoveto
      check_width(stack, state, 1)
      if not(state.first_move) {
        commands.push(@svg.ClosePath)
      }
      state.first_move = false
      state.x = state.x + stack[0]
      commands.push(@svg.MoveTo(state.x, state.y))
      stack.clear()
    }
    24 => {
      // rcurveline
      let n = stack.length()
      let mut i = 0
      while i + 5 < n - 2 {
        let cx1 = state.x + stack[i]
        let cy1 = state.y + stack[i + 1]
        let cx2 = cx1 + stack[i + 2]
        let cy2 = cy1 + stack[i + 3]
        state.x = cx2 + stack[i + 4]
        state.y = cy2 + stack[i + 5]
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, state.x, state.y))
        i = i + 6
      }
      state.x = state.x + stack[n - 2]
      state.y = state.y + stack[n - 1]
      commands.push(@svg.LineTo(state.x, state.y))
      stack.clear()
    }
    25 => {
      // rlinecurve
      let n = stack.length()
      let mut i = 0
      while i + 1 < n - 6 {
        state.x = state.x + stack[i]
        state.y = state.y + stack[i + 1]
        commands.push(@svg.LineTo(state.x, state.y))
        i = i + 2
      }
      let cx1 = state.x + stack[n - 6]
      let cy1 = state.y + stack[n - 5]
      let cx2 = cx1 + stack[n - 4]
      let cy2 = cy1 + stack[n - 3]
      state.x = cx2 + stack[n - 2]
      state.y = cy2 + stack[n - 1]
      commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, state.x, state.y))
      stack.clear()
    }
    26 => {
      // vvcurveto
      let n = stack.length()
      let mut i = 0
      let mut dx1 = 0.0
      if n % 4 != 0 {
        dx1 = stack[0]
        i = 1
      }
      while i + 3 < n {
        let cy1 = state.y + stack[i]
        let cx1 = state.x + dx1
        let cx2 = cx1 + stack[i + 1]
        let cy2 = cy1 + stack[i + 2]
        state.x = cx2
        state.y = cy2 + stack[i + 3]
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, state.x, state.y))
        i = i + 4
        dx1 = 0.0
      }
      stack.clear()
    }
    27 => {
      // hhcurveto
      let n = stack.length()
      let mut i = 0
      let mut dy1 = 0.0
      if n % 4 != 0 {
        dy1 = stack[0]
        i = 1
      }
      while i + 3 < n {
        let cx1 = state.x + stack[i]
        let cy1 = state.y + dy1
        let cx2 = cx1 + stack[i + 1]
        let cy2 = cy1 + stack[i + 2]
        state.x = cx2 + stack[i + 3]
        state.y = cy2
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, state.x, state.y))
        i = i + 4
        dy1 = 0.0
      }
      stack.clear()
    }
    29 => {
      // callgsubr (global)
      let idx = stack.unsafe_pop().to_int() +
        calc_subr_bias(cff.global_subrs.count())
      if idx >= 0 && idx < cff.global_subrs.count() {
        let (sub_off, sub_len) = cff.global_subrs.entry(idx)
        interpret_charstring(
          data,
          sub_off,
          sub_len,
          cff,
          commands,
          stack,
          state,
          depth + 1,
        )
      }
    }
    30 => exec_vh_curves(commands, stack, state, true) // vhcurveto
    31 => exec_vh_curves(commands, stack, state, false) // hvcurveto
    _ => stack.clear()
  }
}

///|
fn exec_vh_curves(
  commands : Array[@svg.PathCommand],
  stack : Array[Double],
  state : CSState,
  start_vertical : Bool,
) -> Unit {
  let n = stack.length()
  let mut i = 0
  let mut phase = start_vertical
  while i + 3 < n {
    let remaining = n - i
    if phase {
      // Vertical start: dy1 dx2 dy2 dx3 [dy3]
      let cx1 = state.x
      let cy1 = state.y + stack[i]
      let cx2 = cx1 + stack[i + 1]
      let cy2 = cy1 + stack[i + 2]
      state.x = cx2 + stack[i + 3]
      state.y = cy2 + (if remaining == 5 { stack[i + 4] } else { 0.0 })
      commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, state.x, state.y))
      i = i + 4 + (if remaining == 5 { 1 } else { 0 })
    } else {
      // Horizontal start: dx1 dx2 dy2 dy3 [dx3]
      let cx1 = state.x + stack[i]
      let cy1 = state.y
      let cx2 = cx1 + stack[i + 1]
      let cy2 = cy1 + stack[i + 2]
      state.x = cx2 + (if remaining == 5 { stack[i + 4] } else { 0.0 })
      state.y = cy2 + stack[i + 3]
      commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, state.x, state.y))
      i = i + 4 + (if remaining == 5 { 1 } else { 0 })
    }
    phase = not(phase)
  }
  stack.clear()
}

///|
fn exec_operator_12(
  b1 : Int,
  commands : Array[@svg.PathCommand],
  stack : Array[Double],
  state : CSState,
) -> Unit {
  match b1 {
    3 => {
      // and
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(if a != 0.0 && b != 0.0 { 1.0 } else { 0.0 })
    }
    4 => {
      // or
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(if a != 0.0 || b != 0.0 { 1.0 } else { 0.0 })
    }
    5 => {
      // not
      let a = stack.unsafe_pop()
      stack.push(if a == 0.0 { 1.0 } else { 0.0 })
    }
    9 => {
      // abs
      let a = stack.unsafe_pop()
      stack.push(a.abs())
    }
    10 => {
      // add
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(a + b)
    }
    11 => {
      // sub
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(a - b)
    }
    12 => {
      // div
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(a / b)
    }
    14 => {
      // neg
      let a = stack.unsafe_pop()
      stack.push(-a)
    }
    15 => {
      // eq
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(if a == b { 1.0 } else { 0.0 })
    }
    18 => {
      // drop
      let _ = stack.unsafe_pop()
    }
    20 => {
      // put
      let i = stack.unsafe_pop().to_int()
      let val = stack.unsafe_pop()
      if i >= 0 && i < state.storage.length() {
        state.storage[i] = val
      }
    }
    21 => {
      // get
      let i = stack.unsafe_pop().to_int()
      if i >= 0 && i < state.storage.length() {
        stack.push(state.storage[i])
      } else {
        stack.push(0.0)
      }
    }
    22 => {
      // ifelse: s1 s2 v1 v2 -> (v1 <= v2 ? s1 : s2)
      let v2 = stack.unsafe_pop()
      let v1 = stack.unsafe_pop()
      let s2 = stack.unsafe_pop()
      let s1 = stack.unsafe_pop()
      stack.push(if v1 <= v2 { s1 } else { s2 })
    }
    23 =>
      // random - deterministic: always push 1.0
      stack.push(1.0)
    24 => {
      // mul
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(a * b)
    }
    26 => {
      // sqrt
      let a = stack.unsafe_pop()
      stack.push(a.sqrt())
    }
    27 => {
      // dup
      let a = stack.unsafe_pop()
      stack.push(a)
      stack.push(a)
    }
    28 => {
      // exch
      let b = stack.unsafe_pop()
      let a = stack.unsafe_pop()
      stack.push(b)
      stack.push(a)
    }
    29 => {
      // index
      let i = stack.unsafe_pop().to_int()
      let idx = if i < 0 { 0 } else { i }
      if idx < stack.length() {
        stack.push(stack[stack.length() - 1 - idx])
      }
    }
    30 => {
      // roll: n j roll - rotate top n elements by j positions
      let j = stack.unsafe_pop().to_int()
      let n = stack.unsafe_pop().to_int()
      if n > 0 && n <= stack.length() {
        let base = stack.length() - n
        let temp : Array[Double] = []
        for i = 0; i < n; i = i + 1 {
          temp.push(stack[base + i])
        }
        let shift = (j % n + n) % n
        for i = 0; i < n; i = i + 1 {
          stack[base + i] = temp[(i + n - shift) % n]
        }
      }
    }
    34 => {
      // hflex
      if stack.length() >= 7 {
        let dx1 = stack[0]
        let dx2 = stack[1]
        let dy2 = stack[2]
        let dx3 = stack[3]
        let dx4 = stack[4]
        let dx5 = stack[5]
        let dx6 = stack[6]
        let cx1 = state.x + dx1
        let cy1 = state.y
        let cx2 = cx1 + dx2
        let cy2 = cy1 + dy2
        let jx = cx2 + dx3
        let jy = cy2
        let cx3 = jx + dx4
        let cy3 = jy
        let cx4 = cx3 + dx5
        let cy4 = cy3 - dy2
        state.x = cx4 + dx6
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, jx, jy))
        commands.push(@svg.CurveTo(cx3, cy3, cx4, cy4, state.x, state.y))
      }
      stack.clear()
    }
    35 => {
      // flex
      if stack.length() >= 13 {
        let cx1 = state.x + stack[0]
        let cy1 = state.y + stack[1]
        let cx2 = cx1 + stack[2]
        let cy2 = cy1 + stack[3]
        let mx = cx2 + stack[4]
        let my = cy2 + stack[5]
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, mx, my))
        let cx3 = mx + stack[6]
        let cy3 = my + stack[7]
        let cx4 = cx3 + stack[8]
        let cy4 = cy3 + stack[9]
        state.x = cx4 + stack[10]
        state.y = cy4 + stack[11]
        commands.push(@svg.CurveTo(cx3, cy3, cx4, cy4, state.x, state.y))
      }
      stack.clear()
    }
    36 => {
      // hflex1
      if stack.length() >= 9 {
        let cx1 = state.x + stack[0]
        let cy1 = state.y + stack[1]
        let cx2 = cx1 + stack[2]
        let cy2 = cy1 + stack[3]
        let mx = cx2 + stack[4]
        let my = cy2
        let cx3 = mx + stack[5]
        let cy3 = my
        let cx4 = cx3 + stack[6]
        let cy4 = cy3 + stack[7]
        state.x = cx4 + stack[8]
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, mx, my))
        commands.push(@svg.CurveTo(cx3, cy3, cx4, cy4, state.x, state.y))
      }
      stack.clear()
    }
    37 => {
      // flex1
      if stack.length() >= 11 {
        let cx1 = state.x + stack[0]
        let cy1 = state.y + stack[1]
        let cx2 = cx1 + stack[2]
        let cy2 = cy1 + stack[3]
        let mx = cx2 + stack[4]
        let my = cy2 + stack[5]
        let cx3 = mx + stack[6]
        let cy3 = my + stack[7]
        let cx4 = cx3 + stack[8]
        let cy4 = cy3 + stack[9]
        let d6 = stack[10]
        let adx = (cx4 - state.x).abs()
        let ady = (cy4 - state.y).abs()
        if adx > ady {
          state.x = cx4 + d6
          state.y = cy4
        } else {
          state.x = cx4
          state.y = cy4 + d6
        }
        commands.push(@svg.CurveTo(cx1, cy1, cx2, cy2, mx, my))
        commands.push(@svg.CurveTo(cx3, cy3, cx4, cy4, state.x, state.y))
      }
      stack.clear()
    }
    _ => stack.clear()
  }
}
