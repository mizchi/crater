///| Deflate compression (fixed Huffman + LZ77)

///|
let deflate_length_base : FixedArray[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let deflate_length_extra : FixedArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let deflate_dist_base : FixedArray[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let deflate_dist_extra : FixedArray[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
let window_size : Int = 32768

///|
let max_match_len : Int = 258

///|
let min_match_len : Int = 3

///|
let hash_size : Int = 1 << 15

///|
let max_chain : Int = 64

///|
priv enum DeflateToken {
  Lit(Int)
  Match(len~ : Int, dist~ : Int)
}

///|
priv struct HuffNode {
  freq : Int
  left : Int
  right : Int
  sym : Int
}

///|
priv struct RleToken {
  sym : Int
  extra_bits : Int
  extra_val : Int
}

///|
fn deflate_reverse_bits(code : Int, len : Int) -> Int {
  let mut v = code
  let mut out = 0
  let mut n = len
  while n > 0 {
    out = (out << 1) | (v & 1)
    v = v >> 1
    n -= 1
  }
  out
}

///|
fn fixed_lit_code(sym : Int) -> (Int, Int) {
  if sym <= 143 {
    let code = sym + 0x30
    (deflate_reverse_bits(code, 8), 8)
  } else if sym <= 255 {
    let code = sym - 144 + 0x190
    (deflate_reverse_bits(code, 9), 9)
  } else if sym <= 279 {
    let code = sym - 256
    (deflate_reverse_bits(code, 7), 7)
  } else {
    let code = sym - 280 + 0xC0
    (deflate_reverse_bits(code, 8), 8)
  }
}

///|
fn fixed_dist_code(sym : Int) -> (Int, Int) {
  (deflate_reverse_bits(sym, 5), 5)
}

///|
fn length_code_info(len : Int) -> (Int, Int, Int) {
  for i in 0..<deflate_length_base.length() {
    let base = deflate_length_base[i]
    let extra = deflate_length_extra[i]
    let max_len = base + ((1 << extra) - 1)
    if len <= max_len {
      return (257 + i, extra, len - base)
    }
  }
  (285, 0, 0)
}

///|
fn dist_code_info(dist : Int) -> (Int, Int, Int) {
  for i in 0..<deflate_dist_base.length() {
    let base = deflate_dist_base[i]
    let extra = deflate_dist_extra[i]
    let max_dist = base + ((1 << extra) - 1)
    if dist <= max_dist {
      return (i, extra, dist - base)
    }
  }
  (29, 13, dist - deflate_dist_base[29])
}

///|
fn hash3(data : Bytes, pos : Int) -> Int {
  let b0 = data[pos].to_int()
  let b1 = data[pos + 1].to_int()
  let b2 = data[pos + 2].to_int()
  ((b0 << 8) ^ (b1 << 4) ^ b2) & (hash_size - 1)
}

///|
fn write_literal(writer : BitWriter, sym : Int) -> Unit {
  let (code, len) = fixed_lit_code(sym)
  writer.write_bits(code, len)
}

///|
fn write_match(writer : BitWriter, length : Int, distance : Int) -> Unit {
  let (len_code, len_extra_bits, len_extra_val) = length_code_info(length)
  let (code_bits, code_len) = fixed_lit_code(len_code)
  writer.write_bits(code_bits, code_len)
  if len_extra_bits > 0 {
    writer.write_bits(len_extra_val, len_extra_bits)
  }
  let (dist_code, dist_extra_bits, dist_extra_val) = dist_code_info(distance)
  let (dist_bits, dist_len) = fixed_dist_code(dist_code)
  writer.write_bits(dist_bits, dist_len)
  if dist_extra_bits > 0 {
    writer.write_bits(dist_extra_val, dist_extra_bits)
  }
}

///|
fn write_end_block(writer : BitWriter) -> Unit {
  let (code, len) = fixed_lit_code(256)
  writer.write_bits(code, len)
}

///|
fn insert_hash(
  data : Bytes,
  pos : Int,
  head : FixedArray[Int],
  prev : FixedArray[Int],
) -> Unit {
  if pos + 2 >= data.length() {
    return
  }
  let h = hash3(data, pos)
  prev[pos] = head[h]
  head[h] = pos
}

///|
fn build_tokens(data : Bytes) -> Array[DeflateToken] {
  let tokens : Array[DeflateToken] = []
  let len = data.length()
  let head : FixedArray[Int] = FixedArray::make(hash_size, -1)
  let prev : FixedArray[Int] = FixedArray::make(len, -1)
  let mut pos = 0
  while pos < len {
    let remaining = len - pos
    let mut best_len = 0
    let mut best_dist = 0
    if remaining >= min_match_len {
      let h = hash3(data, pos)
      let mut candidate = head[h]
      let limit = if pos > window_size { pos - window_size } else { 0 }
      let max_len = if remaining < max_match_len {
        remaining
      } else {
        max_match_len
      }
      let mut chain = 0
      while candidate >= limit && chain < max_chain {
        if data[candidate] == data[pos] &&
          data[candidate + 1] == data[pos + 1] &&
          data[candidate + 2] == data[pos + 2] {
          let mut l = min_match_len
          while l < max_len && data[candidate + l] == data[pos + l] {
            l += 1
          }
          if l > best_len {
            best_len = l
            best_dist = pos - candidate
            if l == max_len {
              break
            }
          }
        }
        candidate = prev[candidate]
        chain += 1
      }
    }
    if best_len >= min_match_len {
      tokens.push(Match(len=best_len, dist=best_dist))
      for i = 0; i < best_len; i = i + 1 {
        insert_hash(data, pos + i, head, prev)
      }
      pos = pos + best_len
    } else {
      tokens.push(Lit(data[pos].to_int()))
      insert_hash(data, pos, head, prev)
      pos = pos + 1
    }
  }
  tokens
}

///|
fn write_tokens_fixed(tokens : Array[DeflateToken], writer : BitWriter) -> Unit {
  for t in tokens {
    match t {
      Lit(sym) => write_literal(writer, sym)
      Match(len~, dist~) => write_match(writer, len, dist)
    }
  }
}

///|
fn build_huffman_lengths(freqs : Array[Int], max_bits : Int) -> Array[Int]? {
  let lengths : Array[Int] = Array::make(freqs.length(), 0)
  let nodes : Array[HuffNode] = []
  let active : Array[Int] = []
  for i in 0..<freqs.length() {
    if freqs[i] > 0 {
      nodes.push({ freq: freqs[i], left: -1, right: -1, sym: i })
      active.push(nodes.length() - 1)
    }
  }
  if active.length() == 0 {
    return None
  }
  if active.length() == 1 {
    lengths[nodes[active[0]].sym] = 1
    return Some(lengths)
  }
  while active.length() > 1 {
    let mut min1 = 0
    let mut min2 = 1
    if nodes[active[min2]].freq < nodes[active[min1]].freq {
      let tmp = min1
      min1 = min2
      min2 = tmp
    }
    for i in 2..<active.length() {
      let idx = active[i]
      if nodes[idx].freq < nodes[active[min1]].freq {
        min2 = min1
        min1 = i
      } else if nodes[idx].freq < nodes[active[min2]].freq {
        min2 = i
      }
    }
    let a = active[min1]
    let b = active[min2]
    if min1 > min2 {
      ignore(active.remove(min1))
      ignore(active.remove(min2))
    } else {
      ignore(active.remove(min2))
      ignore(active.remove(min1))
    }
    nodes.push({
      freq: nodes[a].freq + nodes[b].freq,
      left: a,
      right: b,
      sym: -1,
    })
    active.push(nodes.length() - 1)
  }
  let root = active[0]
  let stack : Array[(Int, Int)] = [(root, 0)]
  while stack.length() > 0 {
    let idx = stack.length() - 1
    let (node_id, depth) = stack[idx]
    ignore(stack.remove(idx))
    let node = nodes[node_id]
    if node.left < 0 && node.right < 0 {
      let len = if depth == 0 { 1 } else { depth }
      if len > max_bits {
        return None
      }
      lengths[node.sym] = len
    } else {
      if node.left >= 0 {
        stack.push((node.left, depth + 1))
      }
      if node.right >= 0 {
        stack.push((node.right, depth + 1))
      }
    }
  }
  Some(lengths)
}

///|
fn build_canonical_codes(
  lengths : Array[Int],
  max_bits : Int,
) -> Array[(Int, Int)] {
  let codes : Array[(Int, Int)] = Array::make(lengths.length(), (0, 0))
  let bl_count : Array[Int] = Array::make(max_bits + 1, 0)
  for len in lengths {
    if len > 0 {
      bl_count[len] = bl_count[len] + 1
    }
  }
  let next_code : Array[Int] = Array::make(max_bits + 1, 0)
  let mut code = 0
  for bits in 1..<=max_bits {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }
  for sym in 0..<lengths.length() {
    let len = lengths[sym]
    if len > 0 {
      let c = next_code[len]
      next_code[len] = c + 1
      codes[sym] = (deflate_reverse_bits(c, len), len)
    }
  }
  codes
}

///|
fn emit_rle_lengths(lengths : Array[Int]) -> Array[RleToken] {
  let out : Array[RleToken] = []
  let mut i = 0
  while i < lengths.length() {
    let len = lengths[i]
    let mut run = 1
    while i + run < lengths.length() && lengths[i + run] == len {
      run += 1
    }
    if len == 0 {
      let mut remaining = run
      while remaining > 0 {
        if remaining >= 11 {
          let chunk = if remaining > 138 { 138 } else { remaining }
          out.push({ sym: 18, extra_bits: 7, extra_val: chunk - 11 })
          remaining = remaining - chunk
        } else if remaining >= 3 {
          let chunk = if remaining > 10 { 10 } else { remaining }
          out.push({ sym: 17, extra_bits: 3, extra_val: chunk - 3 })
          remaining = remaining - chunk
        } else {
          for _ in 0..<remaining {
            out.push({ sym: 0, extra_bits: 0, extra_val: 0 })
          }
          remaining = 0
        }
      }
    } else {
      out.push({ sym: len, extra_bits: 0, extra_val: 0 })
      let mut remaining = run - 1
      while remaining > 0 {
        if remaining >= 3 {
          let chunk = if remaining > 6 { 6 } else { remaining }
          out.push({ sym: 16, extra_bits: 2, extra_val: chunk - 3 })
          remaining = remaining - chunk
        } else {
          out.push({ sym: len, extra_bits: 0, extra_val: 0 })
          remaining = remaining - 1
        }
      }
    }
    i = i + run
  }
  out
}

///|
fn write_tokens_dynamic(
  tokens : Array[DeflateToken],
  lit_codes : Array[(Int, Int)],
  dist_codes : Array[(Int, Int)],
  writer : BitWriter,
) -> Unit {
  for t in tokens {
    match t {
      Lit(sym) => {
        let (code, len) = lit_codes[sym]
        writer.write_bits(code, len)
      }
      Match(len~, dist~) => {
        let (len_code, len_extra_bits, len_extra_val) = length_code_info(len)
        let (code, code_len) = lit_codes[len_code]
        writer.write_bits(code, code_len)
        if len_extra_bits > 0 {
          writer.write_bits(len_extra_val, len_extra_bits)
        }
        let (dist_code, dist_extra_bits, dist_extra_val) = dist_code_info(dist)
        let (dist_bits, dist_len) = dist_codes[dist_code]
        writer.write_bits(dist_bits, dist_len)
        if dist_extra_bits > 0 {
          writer.write_bits(dist_extra_val, dist_extra_bits)
        }
      }
    }
  }
  let (eob_code, eob_len) = lit_codes[256]
  writer.write_bits(eob_code, eob_len)
}

///|
fn deflate_compress_dynamic(data : Bytes) -> Bytes? {
  let tokens = build_tokens(data)
  let lit_freq : Array[Int] = Array::make(286, 0)
  let dist_freq : Array[Int] = Array::make(30, 0)
  for t in tokens {
    match t {
      Lit(sym) => lit_freq[sym] = lit_freq[sym] + 1
      Match(len~, dist~) => {
        let (len_code, _, _) = length_code_info(len)
        let (dist_code, _, _) = dist_code_info(dist)
        lit_freq[len_code] = lit_freq[len_code] + 1
        dist_freq[dist_code] = dist_freq[dist_code] + 1
      }
    }
  }
  lit_freq[256] = lit_freq[256] + 1
  let mut any_dist = false
  for v in dist_freq {
    if v > 0 {
      any_dist = true
      break
    }
  }
  if not(any_dist) {
    dist_freq[0] = 1
  }
  let lit_lengths = match build_huffman_lengths(lit_freq, 15) {
    None => return None
    Some(v) => v
  }
  let dist_lengths = match build_huffman_lengths(dist_freq, 15) {
    None => return None
    Some(v) => v
  }
  let lit_codes = build_canonical_codes(lit_lengths, 15)
  let dist_codes = build_canonical_codes(dist_lengths, 15)
  let mut hlit = 286
  while hlit > 257 && lit_lengths[hlit - 1] == 0 {
    hlit -= 1
  }
  let mut hdist = 30
  while hdist > 1 && dist_lengths[hdist - 1] == 0 {
    hdist -= 1
  }
  let combined : Array[Int] = []
  for i in 0..<hlit {
    combined.push(lit_lengths[i])
  }
  for i in 0..<hdist {
    combined.push(dist_lengths[i])
  }
  let rle = emit_rle_lengths(combined)
  let cl_freq : Array[Int] = Array::make(19, 0)
  for tok in rle {
    cl_freq[tok.sym] = cl_freq[tok.sym] + 1
  }
  let cl_lengths = match build_huffman_lengths(cl_freq, 7) {
    None => return None
    Some(v) => v
  }
  let cl_codes = build_canonical_codes(cl_lengths, 7)
  let order : FixedArray[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let mut hclen = 4
  for i in 0..<order.length() {
    if cl_lengths[order[i]] != 0 {
      hclen = i + 1
    }
  }
  let writer = BitWriter::new()
  writer.write_bits(1, 1)
  writer.write_bits(2, 2)
  writer.write_bits(hlit - 257, 5)
  writer.write_bits(hdist - 1, 5)
  writer.write_bits(hclen - 4, 4)
  for i in 0..<hclen {
    writer.write_bits(cl_lengths[order[i]], 3)
  }
  for tok in rle {
    let (code, len) = cl_codes[tok.sym]
    writer.write_bits(code, len)
    if tok.extra_bits > 0 {
      writer.write_bits(tok.extra_val, tok.extra_bits)
    }
  }
  write_tokens_dynamic(tokens, lit_codes, dist_codes, writer)
  Some(writer.finish())
}

///|
pub fn deflate_compress_fixed(data : Bytes) -> Bytes {
  let writer = BitWriter::new()
  // BFINAL=1, BTYPE=01 (fixed Huffman)
  writer.write_bits(1, 1)
  writer.write_bits(1, 2)
  let tokens = build_tokens(data)
  write_tokens_fixed(tokens, writer)
  write_end_block(writer)
  writer.finish()
}

///|
pub fn deflate_compress_best(data : Bytes) -> Bytes {
  let fixed = deflate_compress_fixed(data)
  match deflate_compress_dynamic(data) {
    None => fixed
    Some(dynamic) =>
      if dynamic.length() < fixed.length() {
        dynamic
      } else {
        fixed
      }
  }
}
