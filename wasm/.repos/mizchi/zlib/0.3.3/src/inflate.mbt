///| Deflate decompression for zlib streams

///|
/// Length base values for symbols 257..285
let length_base : FixedArray[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra : FixedArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
/// Distance base values for symbols 0..29
let dist_base : FixedArray[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let dist_extra : FixedArray[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), fn(i) { arr[i] }))
}

///|
fn inflate_deflate_stream(
  data : Bytes,
  start : Int,
) -> (Bytes, Int) raise ZlibError {
  let reader = BitReader::new(data, start)
  let output : Array[Byte] = []
  inflate_blocks(reader, output)
  reader.align_byte()
  (bytes_from_array(output), reader.offset())
}

///|
fn inflate_blocks(
  reader : BitReader,
  output : Array[Byte],
) -> Unit raise ZlibError {
  let mut is_final = false
  while not(is_final) {
    let bfinal = reader.read_bits(1)
    let btype = reader.read_bits(2)
    if btype == 0 {
      inflate_stored_block(reader, output)
    } else if btype == 1 {
      let (lit_tree, dist_tree) = build_fixed_trees()
      inflate_huffman_block(reader, output, lit_tree, dist_tree)
    } else if btype == 2 {
      let (lit_tree, dist_tree) = build_dynamic_trees(reader)
      inflate_huffman_block(reader, output, lit_tree, dist_tree)
    } else {
      raise ZlibError::InvalidData("Invalid deflate block type")
    }
    if bfinal == 1 {
      is_final = true
    }
  }
}

///|
fn inflate_stored_block(
  reader : BitReader,
  output : Array[Byte],
) -> Unit raise ZlibError {
  reader.align_byte()
  let len = reader.read_u16_le_aligned()
  let nlen = reader.read_u16_le_aligned()
  if (len ^ nlen) != 0xffff {
    raise ZlibError::InvalidData("Invalid stored block length")
  }
  reader.read_bytes_aligned(output, len)
}

///|
fn inflate_huffman_block(
  reader : BitReader,
  output : Array[Byte],
  lit_tree : HuffmanTree,
  dist_tree : HuffmanTree,
) -> Unit raise ZlibError {
  while true {
    let sym = lit_tree.decode(reader)
    if sym < 256 {
      output.push(sym.to_byte())
      continue
    }
    if sym == 256 {
      break
    }
    if sym < 257 || sym > 285 {
      raise ZlibError::InvalidData("Invalid length symbol: \{sym}")
    }
    let len_index = sym - 257
    let base_len = length_base[len_index]
    let extra_bits = length_extra[len_index]
    let extra = if extra_bits == 0 { 0 } else { reader.read_bits(extra_bits) }
    let length = base_len + extra
    let dist_sym = dist_tree.decode(reader)
    if dist_sym < 0 || dist_sym >= dist_base.length() {
      raise ZlibError::InvalidData("Invalid distance symbol: \{dist_sym}")
    }
    let base_dist = dist_base[dist_sym]
    let dist_extra_bits = dist_extra[dist_sym]
    let dist_extra_val = if dist_extra_bits == 0 {
      0
    } else {
      reader.read_bits(dist_extra_bits)
    }
    let distance = base_dist + dist_extra_val
    if distance <= 0 || distance > output.length() {
      raise ZlibError::InvalidData("Invalid distance")
    }
    let start = output.length() - distance
    let mut remaining = length
    while remaining > 0 {
      let chunk = if remaining > distance { distance } else { remaining }
      for i in 0..<chunk {
        output.push(output[start + i])
      }
      remaining -= chunk
    }
  }
}

///|
fn build_fixed_trees() -> (HuffmanTree, HuffmanTree) raise ZlibError {
  let lit_lengths : Array[Int] = []
  for i in 0..<288 {
    let len = if i <= 143 {
      8
    } else if i <= 255 {
      9
    } else if i <= 279 {
      7
    } else {
      8
    }
    lit_lengths.push(len)
  }
  let dist_lengths : Array[Int] = []
  for _ in 0..<32 {
    dist_lengths.push(5)
  }
  let lit_tree = build_huffman_tree(lit_lengths, 15)
  let dist_tree = build_huffman_tree(dist_lengths, 15)
  (lit_tree, dist_tree)
}

///|
fn build_dynamic_trees(
  reader : BitReader,
) -> (HuffmanTree, HuffmanTree) raise ZlibError {
  let hlit = reader.read_bits(5) + 257
  let hdist = reader.read_bits(5) + 1
  let hclen = reader.read_bits(4) + 4
  let order : FixedArray[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let code_len_lengths : Array[Int] = []
  for _ in 0..<19 {
    code_len_lengths.push(0)
  }
  for i in 0..<hclen {
    code_len_lengths[order[i]] = reader.read_bits(3)
  }
  let code_len_tree = build_huffman_tree(code_len_lengths, 7)
  let total = hlit + hdist
  let lengths : Array[Int] = []
  let mut prev = 0
  while lengths.length() < total {
    let sym = code_len_tree.decode(reader)
    if sym <= 15 {
      lengths.push(sym)
      prev = sym
    } else if sym == 16 {
      let repeat = reader.read_bits(2) + 3
      for _ in 0..<repeat {
        lengths.push(prev)
      }
    } else if sym == 17 {
      let repeat = reader.read_bits(3) + 3
      for _ in 0..<repeat {
        lengths.push(0)
      }
      prev = 0
    } else if sym == 18 {
      let repeat = reader.read_bits(7) + 11
      for _ in 0..<repeat {
        lengths.push(0)
      }
      prev = 0
    } else {
      raise ZlibError::InvalidData("Invalid code length symbol")
    }
  }
  let lit_lengths : Array[Int] = []
  for i in 0..<hlit {
    lit_lengths.push(lengths[i])
  }
  let dist_lengths : Array[Int] = []
  for i in 0..<hdist {
    dist_lengths.push(lengths[hlit + i])
  }
  let lit_tree = build_huffman_tree(lit_lengths, 15)
  let dist_tree = if all_zero_lengths(dist_lengths) {
    build_huffman_tree([1], 1)
  } else {
    build_huffman_tree(dist_lengths, 15)
  }
  (lit_tree, dist_tree)
}

///|
fn all_zero_lengths(lengths : Array[Int]) -> Bool {
  for len in lengths {
    if len != 0 {
      return false
    }
  }
  true
}
