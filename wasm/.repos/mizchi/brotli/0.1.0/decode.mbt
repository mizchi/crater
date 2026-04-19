///|
fn decode_window_bits(br : BitReader) -> Int {
  if br.read_bits(1) == 0 {
    return 16
  }
  let n = br.read_bits(3)
  if n > 0 {
    return 17 + n
  }
  let n2 = br.read_bits(3)
  if n2 > 0 {
    return 8 + n2
  }
  17
}

///|
fn decode_var_len_uint8(br : BitReader) -> Int {
  if br.read_bits(1) != 0 {
    let nbits = br.read_bits(3)
    if nbits == 0 {
      return 1
    }
    return br.read_bits(nbits) + (1 << nbits)
  }
  0
}

///|
fn decode_meta_block_length(
  br : BitReader,
) -> MetaBlockLength raise BrotliError {
  let out = MetaBlockLength::new()
  out.input_end = br.read_bits(1) != 0
  if out.input_end && br.read_bits(1) != 0 {
    return out
  }
  let size_nibbles = br.read_bits(2) + 4
  if size_nibbles == 7 {
    out.is_metadata = true
    if br.read_bits(1) != 0 {
      raise BrotliError::InvalidData("Invalid reserved bit")
    }
    let size_bytes = br.read_bits(2)
    if size_bytes == 0 {
      return out
    }
    for i in 0..<size_bytes {
      let next_byte = br.read_bits(8)
      if i + 1 == size_bytes && size_bytes > 1 && next_byte == 0 {
        raise BrotliError::InvalidData("Invalid size byte")
      }
      out.meta_block_length = out.meta_block_length | (next_byte << (i * 8))
    }
  } else {
    for i in 0..<size_nibbles {
      let next_nibble = br.read_bits(4)
      if i + 1 == size_nibbles && size_nibbles > 4 && next_nibble == 0 {
        raise BrotliError::InvalidData("Invalid size nibble")
      }
      out.meta_block_length = out.meta_block_length | (next_nibble << (i * 4))
    }
  }
  out.meta_block_length += 1
  if not(out.input_end) && not(out.is_metadata) {
    out.is_uncompressed = br.read_bits(1) != 0
  }
  out
}

///|
fn read_symbol(
  table : FixedArray[HuffmanCode],
  index : Int,
  br : BitReader,
) -> Int {
  br.fill_bit_window()
  let mut idx = index + (ushr(br.val, br.bit_pos) & huffman_table_mask)
  let nbits = table[idx].bits - huffman_table_bits
  if nbits > 0 {
    br.bit_pos += huffman_table_bits
    idx += table[idx].value
    idx += ushr(br.val, br.bit_pos) & ((1 << nbits) - 1)
  }
  br.bit_pos += table[idx].bits
  table[idx].value
}

///|
fn read_huffman_code_lengths(
  code_length_code_lengths : FixedArray[Int],
  num_symbols : Int,
  code_lengths : FixedArray[Int],
  br : BitReader,
) -> Unit raise BrotliError {
  let mut symbol = 0
  let mut prev_code_len = kDefaultCodeLength
  let mut repeat = 0
  let mut repeat_code_len = 0
  let mut space = 32768
  let table : FixedArray[HuffmanCode] = FixedArray::make(32, {
    bits: 0,
    value: 0,
  })
  let _ = brotli_build_huffman_table(
    table, 0, 5, code_length_code_lengths, code_length_codes,
  )
  while symbol < num_symbols && space > 0 {
    br.read_more_input()
    br.fill_bit_window()
    let p = ushr(br.val, br.bit_pos) & 31
    br.bit_pos += table[p].bits
    let code_len = table[p].value & 0xff
    if code_len < kCodeLengthRepeatCode {
      repeat = 0
      code_lengths[symbol] = code_len
      symbol += 1
      if code_len != 0 {
        prev_code_len = code_len
        space -= 32768 >> code_len
      }
    } else {
      let extra_bits = code_len - 14
      let new_len = if code_len == kCodeLengthRepeatCode {
        prev_code_len
      } else {
        0
      }
      if repeat_code_len != new_len {
        repeat = 0
        repeat_code_len = new_len
      }
      let old_repeat = repeat
      if repeat > 0 {
        repeat -= 2
        repeat = repeat << extra_bits
      }
      repeat += br.read_bits(extra_bits) + 3
      let repeat_delta = repeat - old_repeat
      if symbol + repeat_delta > num_symbols {
        raise BrotliError::InvalidData("symbol + repeat_delta > num_symbols")
      }
      for x in 0..<repeat_delta {
        code_lengths[symbol + x] = repeat_code_len
      }
      symbol += repeat_delta
      if repeat_code_len != 0 {
        space -= repeat_delta << (15 - repeat_code_len)
      }
    }
  }
  if space != 0 {
    raise BrotliError::InvalidData("space != 0 in ReadHuffmanCodeLengths")
  }
  while symbol < num_symbols {
    code_lengths[symbol] = 0
    symbol += 1
  }
}

///|
fn read_huffman_code(
  alphabet_size : Int,
  tables : FixedArray[HuffmanCode],
  table : Int,
  br : BitReader,
) -> Int raise BrotliError {
  br.read_more_input()
  let simple_code_or_skip = br.read_bits(2)
  let code_lengths : FixedArray[Int] = FixedArray::make(alphabet_size, 0)
  if simple_code_or_skip == 1 {
    let mut max_bits_counter = alphabet_size - 1
    let mut max_bits = 0
    let symbols : FixedArray[Int] = FixedArray::make(4, 0)
    let num_symbols = br.read_bits(2) + 1
    while max_bits_counter != 0 {
      max_bits_counter = max_bits_counter >> 1
      max_bits += 1
    }
    for i in 0..<num_symbols {
      symbols[i] = br.read_bits(max_bits) % alphabet_size
      code_lengths[symbols[i]] = 2
    }
    code_lengths[symbols[0]] = 1
    if num_symbols == 2 {
      if symbols[0] == symbols[1] {
        raise BrotliError::InvalidData("invalid symbols")
      }
      code_lengths[symbols[1]] = 1
    } else if num_symbols == 3 {
      if symbols[0] == symbols[1] ||
        symbols[0] == symbols[2] ||
        symbols[1] == symbols[2] {
        raise BrotliError::InvalidData("invalid symbols")
      }
    } else if num_symbols == 4 {
      if symbols[0] == symbols[1] ||
        symbols[0] == symbols[2] ||
        symbols[0] == symbols[3] ||
        symbols[1] == symbols[2] ||
        symbols[1] == symbols[3] ||
        symbols[2] == symbols[3] {
        raise BrotliError::InvalidData("invalid symbols")
      }
      if br.read_bits(1) != 0 {
        code_lengths[symbols[2]] = 3
        code_lengths[symbols[3]] = 3
      } else {
        code_lengths[symbols[0]] = 2
      }
    }
  } else {
    let code_length_code_lengths : FixedArray[Int] = FixedArray::make(
      code_length_codes, 0,
    )
    let mut space = 32
    let mut num_codes = 0
    let huff : FixedArray[HuffmanCode] = [
      { bits: 2, value: 0 },
      { bits: 2, value: 4 },
      { bits: 2, value: 3 },
      { bits: 3, value: 2 },
      { bits: 2, value: 0 },
      { bits: 2, value: 4 },
      { bits: 2, value: 3 },
      { bits: 4, value: 1 },
      { bits: 2, value: 0 },
      { bits: 2, value: 4 },
      { bits: 2, value: 3 },
      { bits: 3, value: 2 },
      { bits: 2, value: 0 },
      { bits: 2, value: 4 },
      { bits: 2, value: 3 },
      { bits: 4, value: 5 },
    ]
    for i = simple_code_or_skip; i < code_length_codes && space > 0; i = i + 1 {
      let code_len_idx = kCodeLengthCodeOrder[i]
      br.fill_bit_window()
      let p = ushr(br.val, br.bit_pos) & 15
      br.bit_pos += huff[p].bits
      let v = huff[p].value
      code_length_code_lengths[code_len_idx] = v
      if v != 0 {
        space -= 32 >> v
        num_codes += 1
      }
    }
    if not(num_codes == 1 || space == 0) {
      raise BrotliError::InvalidData("invalid num_codes or space")
    }
    read_huffman_code_lengths(
      code_length_code_lengths, alphabet_size, code_lengths, br,
    )
  }
  let table_size = brotli_build_huffman_table(
    tables, table, huffman_table_bits, code_lengths, alphabet_size,
  )
  if table_size == 0 {
    raise BrotliError::InvalidData("BuildHuffmanTable failed")
  }
  table_size
}

///|
fn read_block_length(
  table : FixedArray[HuffmanCode],
  index : Int,
  br : BitReader,
) -> Int {
  let code = read_symbol(table, index, br)
  let nbits = kBlockLengthPrefixCode[code].nbits
  kBlockLengthPrefixCode[code].offset + br.read_bits(nbits)
}

///|
fn translate_short_codes(
  code : Int,
  ringbuffer : FixedArray[Int],
  index : Int,
) -> Int {
  if code < num_distance_short_codes {
    let idx = (index + kDistanceShortCodeIndexOffset[code]) & 3
    ringbuffer[idx] + kDistanceShortCodeValueOffset[code]
  } else {
    code - num_distance_short_codes + 1
  }
}

///|
fn move_to_front(v : FixedArray[Int], index : Int) -> Unit {
  let value = v[index]
  for i = index; i > 0; i = i - 1 {
    v[i] = v[i - 1]
  }
  v[0] = value
}

///|
fn inverse_move_to_front_transform(v : FixedArray[Int], v_len : Int) -> Unit {
  let mtf : FixedArray[Int] = FixedArray::make(256, 0)
  for i in 0..<256 {
    mtf[i] = i
  }
  for i in 0..<v_len {
    let index = v[i]
    v[i] = mtf[index]
    if index != 0 {
      move_to_front(mtf, index)
    }
  }
}

///|
priv struct HuffmanTreeGroup {
  alphabet_size : Int
  num_htrees : Int
  codes : FixedArray[HuffmanCode]
  htrees : FixedArray[Int]
}

///|
fn HuffmanTreeGroup::new(
  alphabet_size : Int,
  num_htrees : Int,
) -> HuffmanTreeGroup {
  let max_table_idx = ushr(alphabet_size + 31, 5)
  let max_table = if max_table_idx < kMaxHuffmanTableSize.length() {
    kMaxHuffmanTableSize[max_table_idx]
  } else {
    huffman_max_table_size
  }
  let codes_size = num_htrees + num_htrees * max_table
  {
    alphabet_size,
    num_htrees,
    codes: FixedArray::make(codes_size, { bits: 0, value: 0 }),
    htrees: FixedArray::make(num_htrees, 0),
  }
}

///|
fn HuffmanTreeGroup::decode(
  self : HuffmanTreeGroup,
  br : BitReader,
) -> Unit raise BrotliError {
  let mut next = 0
  for i in 0..<self.num_htrees {
    self.htrees[i] = next
    let table_size = read_huffman_code(self.alphabet_size, self.codes, next, br)
    next += table_size
    ignore(i)
  }
}

///|
fn decode_context_map(
  context_map_size : Int,
  br : BitReader,
) -> (Int, FixedArray[Int]) raise BrotliError {
  br.read_more_input()
  let num_htrees = decode_var_len_uint8(br) + 1
  let context_map : FixedArray[Int] = FixedArray::make(context_map_size, 0)
  if num_htrees <= 1 {
    return (num_htrees, context_map)
  }
  let use_rle_for_zeros = br.read_bits(1) != 0
  let mut max_run_length_prefix = 0
  if use_rle_for_zeros {
    max_run_length_prefix = br.read_bits(4) + 1
  }
  let table : FixedArray[HuffmanCode] = FixedArray::make(
    huffman_max_table_size,
    { bits: 0, value: 0 },
  )
  let _ = read_huffman_code(num_htrees + max_run_length_prefix, table, 0, br)
  let mut i = 0
  while i < context_map_size {
    br.read_more_input()
    let code = read_symbol(table, 0, br)
    if code == 0 {
      context_map[i] = 0
      i += 1
    } else if code <= max_run_length_prefix {
      let extra = br.read_bits(code)
      let mut reps = 1 + (1 << code) + extra
      reps -= 1
      while reps > 0 {
        if i >= context_map_size {
          raise BrotliError::InvalidData("i >= context_map_size")
        }
        context_map[i] = 0
        i += 1
        reps -= 1
      }
    } else {
      context_map[i] = code - max_run_length_prefix
      i += 1
    }
  }
  if br.read_bits(1) != 0 {
    inverse_move_to_front_transform(context_map, context_map_size)
  }
  (num_htrees, context_map)
}

///|
fn decode_block_type(
  max_block_type : Int,
  trees : FixedArray[HuffmanCode],
  tree_type : Int,
  block_types : FixedArray[Int],
  ringbuffers : FixedArray[Int],
  indexes : FixedArray[Int],
  br : BitReader,
) -> Unit {
  let ringbuffer = tree_type * 2
  let index = tree_type
  let type_code = read_symbol(trees, tree_type * huffman_max_table_size, br)
  let mut block_type = 0
  if type_code == 0 {
    block_type = ringbuffers[ringbuffer + (indexes[index] & 1)]
  } else if type_code == 1 {
    block_type = ringbuffers[ringbuffer + ((indexes[index] - 1) & 1)] + 1
  } else {
    block_type = type_code - 2
  }
  if block_type >= max_block_type {
    block_type -= max_block_type
  }
  block_types[tree_type] = block_type
  ringbuffers[ringbuffer + (indexes[index] & 1)] = block_type
  indexes[index] += 1
}

///|
fn copy_uncompressed_block_to_output(
  output : FixedArray[Int],
  output_pos : Ref[Int],
  len : Int,
  pos : Int,
  ringbuffer : FixedArray[Int],
  ringbuffer_mask : Int,
  br : BitReader,
) -> Unit raise BrotliError {
  let rb_size = ringbuffer_mask + 1
  let mut rb_pos = pos & ringbuffer_mask
  let mut len = len
  if len < 8 || br.bit_pos + (len << 3) < br.bit_end_pos {
    while len > 0 {
      len -= 1
      br.read_more_input()
      ringbuffer[rb_pos] = br.read_bits(8)
      rb_pos += 1
      if rb_pos == rb_size {
        for x in 0..<rb_size {
          output[output_pos.val + x] = ringbuffer[x]
        }
        output_pos.val += rb_size
        rb_pos = 0
      }
    }
    return
  }
  if br.bit_end_pos < 32 {
    raise BrotliError::InvalidData("bit_end_pos < 32")
  }
  while br.bit_pos < 32 {
    ringbuffer[rb_pos] = ushr(br.val, br.bit_pos) & 0xff
    br.bit_pos += 8
    rb_pos += 1
    len -= 1
  }
  let mut br_pos = br.pos & brotli_ibuf_mask
  let mut nbytes = (br.bit_end_pos - br.bit_pos) >> 3
  if br_pos + nbytes > brotli_ibuf_mask {
    let tail = brotli_ibuf_mask + 1 - br_pos
    for x in 0..<tail {
      ringbuffer[rb_pos + x] = br.buf[br_pos + x]
    }
    nbytes -= tail
    rb_pos += tail
    len -= tail
    br_pos = 0
  }
  for x in 0..<nbytes {
    ringbuffer[rb_pos + x] = br.buf[br_pos + x]
  }
  rb_pos += nbytes
  len -= nbytes
  if rb_pos >= rb_size {
    for x in 0..<rb_size {
      output[output_pos.val + x] = ringbuffer[x]
    }
    output_pos.val += rb_size
    rb_pos -= rb_size
    for x in 0..<rb_pos {
      ringbuffer[x] = ringbuffer[rb_size + x]
    }
  }
  while rb_pos + len >= rb_size {
    let nb = rb_size - rb_pos
    for x in 0..<nb {
      ringbuffer[rb_pos + x] = br.data[br.data_pos + x].to_int()
    }
    br.data_pos += nb
    for x in 0..<rb_size {
      output[output_pos.val + x] = ringbuffer[x]
    }
    output_pos.val += rb_size
    len -= nb
    rb_pos = 0
  }
  for x in 0..<len {
    ringbuffer[rb_pos + x] = br.data[br.data_pos + x].to_int()
  }
  br.data_pos += len
  br.reset()
}

///|
fn brotli_decompress_internal(br : BitReader) -> Bytes raise BrotliError {
  let mut pos = 0
  let mut input_end = false
  let window_bits = decode_window_bits(br)
  let max_backward_distance = (1 << window_bits) - 16
  let mut max_distance = 0
  let ringbuffer_size = 1 << window_bits
  let ringbuffer_mask = ringbuffer_size - 1
  let k_ring_buffer_write_ahead_slack = 128 + brotli_read_size
  let ringbuffer : FixedArray[Int] = FixedArray::make(
    ringbuffer_size +
    k_ring_buffer_write_ahead_slack +
    max_dictionary_word_length,
    0,
  )
  let ringbuffer_end = ringbuffer_size
  let dist_rb : FixedArray[Int] = [16, 15, 11, 4]
  let mut dist_rb_idx = 0
  let mut prev_byte1 = 0
  let mut prev_byte2 = 0
  let block_type_trees : FixedArray[HuffmanCode] = FixedArray::make(
    3 * huffman_max_table_size,
    { bits: 0, value: 0 },
  )
  let block_len_trees : FixedArray[HuffmanCode] = FixedArray::make(
    3 * huffman_max_table_size,
    { bits: 0, value: 0 },
  )
  let mut output_size = 4096
  let mut output : FixedArray[Int] = FixedArray::make(output_size, 0)
  let output_pos : Ref[Int] = Ref::new(0)
  while not(input_end) {
    let block_length : FixedArray[Int] = [1 << 28, 1 << 28, 1 << 28]
    let block_type : FixedArray[Int] = [0, 0, 0]
    let num_block_types : FixedArray[Int] = [1, 1, 1]
    let block_type_rb : FixedArray[Int] = [0, 1, 0, 1, 0, 1]
    let block_type_rb_index : FixedArray[Int] = [0, 0, 0]
    br.read_more_input()
    let meta = decode_meta_block_length(br)
    let mut meta_block_remaining_len = meta.meta_block_length
    let needed = pos + meta_block_remaining_len
    if needed > output_size {
      let new_size = if needed > output_size * 2 {
        needed
      } else {
        output_size * 2
      }
      let tmp : FixedArray[Int] = FixedArray::make(new_size, 0)
      for x in 0..<output_pos.val {
        tmp[x] = output[x]
      }
      output = tmp
      output_size = new_size
    }
    input_end = meta.input_end
    let is_uncompressed = meta.is_uncompressed
    if meta.is_metadata {
      let new_bit_pos = (br.bit_pos + 7) & (7).lnot()
      let _ = br.read_bits(new_bit_pos - br.bit_pos)
      let mut remaining = meta_block_remaining_len
      while remaining > 0 {
        br.read_more_input()
        let _ = br.read_bits(8)
        remaining -= 1
      }
      continue
    }
    if meta_block_remaining_len == 0 {
      continue
    }
    if is_uncompressed {
      br.bit_pos = (br.bit_pos + 7) & (7).lnot()
      copy_uncompressed_block_to_output(
        output, output_pos, meta_block_remaining_len, pos, ringbuffer, ringbuffer_mask,
        br,
      )
      pos += meta_block_remaining_len
      continue
    }
    for i in 0..<3 {
      num_block_types[i] = decode_var_len_uint8(br) + 1
      if num_block_types[i] >= 2 {
        let _ = read_huffman_code(
          num_block_types[i] + 2,
          block_type_trees,
          i * huffman_max_table_size,
          br,
        )
        let _ = read_huffman_code(
          kNumBlockLengthCodes,
          block_len_trees,
          i * huffman_max_table_size,
          br,
        )
        block_length[i] = read_block_length(
          block_len_trees,
          i * huffman_max_table_size,
          br,
        )
        block_type_rb_index[i] = 1
      }
    }
    br.read_more_input()
    let distance_postfix_bits = br.read_bits(2)
    let num_direct_distance_codes = num_distance_short_codes +
      (br.read_bits(4) << distance_postfix_bits)
    let distance_postfix_mask = (1 << distance_postfix_bits) - 1
    let num_distance_codes = num_direct_distance_codes +
      (48 << distance_postfix_bits)
    let context_modes : FixedArray[Int] = FixedArray::make(
      num_block_types[0],
      0,
    )
    for i in 0..<num_block_types[0] {
      br.read_more_input()
      context_modes[i] = br.read_bits(2) << 1
    }
    let (num_literal_htrees, context_map) = decode_context_map(
      num_block_types[0] << kLiteralContextBits,
      br,
    )
    let (num_dist_htrees, dist_context_map) = decode_context_map(
      num_block_types[2] << kDistanceContextBits,
      br,
    )
    let hgroup0 = HuffmanTreeGroup::new(kNumLiteralCodes, num_literal_htrees)
    let hgroup1 = HuffmanTreeGroup::new(
      kNumInsertAndCopyCodes,
      num_block_types[1],
    )
    let hgroup2 = HuffmanTreeGroup::new(num_distance_codes, num_dist_htrees)
    hgroup0.decode(br)
    hgroup1.decode(br)
    hgroup2.decode(br)
    let mut context_map_slice = 0
    let mut dist_context_map_slice = 0
    let mut context_mode = context_modes[block_type[0]]
    let mut context_lookup_offset1 = context_lookup_offsets[context_mode]
    let mut context_lookup_offset2 = context_lookup_offsets[context_mode + 1]
    let mut htree_command = hgroup1.htrees[0]
    while meta_block_remaining_len > 0 {
      br.read_more_input()
      if block_length[1] == 0 {
        decode_block_type(
          num_block_types[1],
          block_type_trees,
          1,
          block_type,
          block_type_rb,
          block_type_rb_index,
          br,
        )
        block_length[1] = read_block_length(
          block_len_trees, huffman_max_table_size, br,
        )
        htree_command = hgroup1.htrees[block_type[1]]
      }
      block_length[1] -= 1
      let cmd_code = read_symbol(hgroup1.codes, htree_command, br)
      let mut range_idx = ushr(cmd_code, 6)
      let mut distance_code = 0
      if range_idx >= 2 {
        range_idx -= 2
        distance_code = -1
      }
      let insert_code = kInsertRangeLut[range_idx] + (ushr(cmd_code, 3) & 7)
      let copy_code = kCopyRangeLut[range_idx] + (cmd_code & 7)
      let insert_length = kInsertLengthPrefixCode[insert_code].offset +
        br.read_bits(kInsertLengthPrefixCode[insert_code].nbits)
      let copy_length = kCopyLengthPrefixCode[copy_code].offset +
        br.read_bits(kCopyLengthPrefixCode[copy_code].nbits)
      prev_byte1 = ringbuffer[(pos - 1) & ringbuffer_mask]
      prev_byte2 = ringbuffer[(pos - 2) & ringbuffer_mask]
      for j in 0..<insert_length {
        br.read_more_input()
        if block_length[0] == 0 {
          decode_block_type(
            num_block_types[0],
            block_type_trees,
            0,
            block_type,
            block_type_rb,
            block_type_rb_index,
            br,
          )
          block_length[0] = read_block_length(block_len_trees, 0, br)
          let context_offset = block_type[0] << kLiteralContextBits
          context_map_slice = context_offset
          context_mode = context_modes[block_type[0]]
          context_lookup_offset1 = context_lookup_offsets[context_mode]
          context_lookup_offset2 = context_lookup_offsets[context_mode + 1]
        }
        let context = context_lookup[context_lookup_offset1 + prev_byte1] |
          context_lookup[context_lookup_offset2 + prev_byte2]
        let literal_htree_index = context_map[context_map_slice + context]
        block_length[0] -= 1
        prev_byte2 = prev_byte1
        prev_byte1 = read_symbol(
          hgroup0.codes,
          hgroup0.htrees[literal_htree_index],
          br,
        )
        ringbuffer[pos & ringbuffer_mask] = prev_byte1
        if (pos & ringbuffer_mask) == ringbuffer_mask {
          for x in 0..<ringbuffer_size {
            output[output_pos.val + x] = ringbuffer[x]
          }
          output_pos.val += ringbuffer_size
        }
        pos += 1
        ignore(j)
      }
      meta_block_remaining_len -= insert_length
      if meta_block_remaining_len <= 0 {
        break
      }
      if distance_code < 0 {
        br.read_more_input()
        if block_length[2] == 0 {
          decode_block_type(
            num_block_types[2],
            block_type_trees,
            2,
            block_type,
            block_type_rb,
            block_type_rb_index,
            br,
          )
          block_length[2] = read_block_length(
            block_len_trees,
            2 * huffman_max_table_size,
            br,
          )
          let dist_context_offset = block_type[2] << kDistanceContextBits
          dist_context_map_slice = dist_context_offset
        }
        block_length[2] -= 1
        let context = if copy_length > 4 { 3 } else { copy_length - 2 }
        let dist_ctx = context & 0xff
        let dist_htree_index = dist_context_map[dist_context_map_slice +
          dist_ctx]
        distance_code = read_symbol(
          hgroup2.codes,
          hgroup2.htrees[dist_htree_index],
          br,
        )
        if distance_code >= num_direct_distance_codes {
          distance_code -= num_direct_distance_codes
          let postfix = distance_code & distance_postfix_mask
          distance_code = ushr(distance_code, distance_postfix_bits)
          let nbits = ushr(distance_code, 1) + 1
          let offset = ((2 + (distance_code & 1)) << nbits) - 4
          distance_code = num_direct_distance_codes +
            ((offset + br.read_bits(nbits)) << distance_postfix_bits) +
            postfix
        }
      }
      let distance = translate_short_codes(distance_code, dist_rb, dist_rb_idx)
      if distance < 0 {
        raise BrotliError::InvalidData("invalid distance")
      }
      if pos < max_backward_distance && max_distance != max_backward_distance {
        max_distance = pos
      } else {
        max_distance = max_backward_distance
      }
      let mut copy_dst = pos & ringbuffer_mask
      let copy_length = copy_length
      if distance > max_distance {
        if copy_length >= min_dictionary_word_length &&
          copy_length <= max_dictionary_word_length {
          let offset = offsets_by_length[copy_length]
          let word_id = distance - max_distance - 1
          let shift = size_bits_by_length[copy_length]
          let mask = (1 << shift) - 1
          let word_idx = word_id & mask
          let transform_idx = ushr(word_id, shift)
          let word_offset = offset + word_idx * copy_length
          if transform_idx < kNumTransforms {
            let len = transform_dictionary_word(
              ringbuffer, copy_dst, word_offset, copy_length, transform_idx,
            )
            copy_dst += len
            pos += len
            meta_block_remaining_len -= len
            if copy_dst >= ringbuffer_end {
              for x in 0..<ringbuffer_size {
                output[output_pos.val + x] = ringbuffer[x]
              }
              output_pos.val += ringbuffer_size
              for x in 0..<(copy_dst - ringbuffer_end) {
                ringbuffer[x] = ringbuffer[ringbuffer_end + x]
              }
            }
          } else {
            raise BrotliError::InvalidData(
              "Invalid backward reference (transform)",
            )
          }
        } else {
          raise BrotliError::InvalidData("Invalid backward reference (dict)")
        }
      } else {
        if distance_code > 0 {
          dist_rb[dist_rb_idx & 3] = distance
          dist_rb_idx += 1
        }
        if copy_length > meta_block_remaining_len {
          raise BrotliError::InvalidData(
            "Invalid backward reference (copy_length)",
          )
        }
        for _j in 0..<copy_length {
          ringbuffer[pos & ringbuffer_mask] = ringbuffer[(pos - distance) &
            ringbuffer_mask]
          if (pos & ringbuffer_mask) == ringbuffer_mask {
            for x in 0..<ringbuffer_size {
              output[output_pos.val + x] = ringbuffer[x]
            }
            output_pos.val += ringbuffer_size
          }
          pos += 1
          meta_block_remaining_len -= 1
        }
      }
      prev_byte1 = ringbuffer[(pos - 1) & ringbuffer_mask]
      prev_byte2 = ringbuffer[(pos - 2) & ringbuffer_mask]
    }
    pos = pos & 0x3fffffff
  }
  let remaining = pos & ringbuffer_mask
  if remaining > 0 {
    for x in 0..<remaining {
      output[output_pos.val + x] = ringbuffer[x]
    }
    output_pos.val += remaining
  }
  Bytes::makei(output_pos.val, fn(i) { output[i].to_byte() })
}
