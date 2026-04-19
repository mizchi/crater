///| Huffman tree for deflate decoding

///|
priv struct HuffmanTree {
  left : Array[Int]
  right : Array[Int]
  symbol : Array[Int]
  table_bits : Int
  table_symbol : FixedArray[Int]
  table_len : FixedArray[Int]
  table_sub : FixedArray[Int]
  sub_bits : Array[Int]
  sub_symbol : Array[FixedArray[Int]]
  sub_len : Array[FixedArray[Int]]
}

///|
fn HuffmanTree::new(table_bits : Int) -> HuffmanTree {
  let size = if table_bits <= 0 { 0 } else { 1 << table_bits }
  {
    left: [-1],
    right: [-1],
    symbol: [-1],
    table_bits,
    table_symbol: FixedArray::make(size, -1),
    table_len: FixedArray::make(size, 0),
    table_sub: FixedArray::make(size, -1),
    sub_bits: [],
    sub_symbol: [],
    sub_len: [],
  }
}

///|
fn HuffmanTree::add_node(self : HuffmanTree) -> Int {
  self.left.push(-1)
  self.right.push(-1)
  self.symbol.push(-1)
  self.left.length() - 1
}

///|
fn HuffmanTree::insert(
  self : HuffmanTree,
  code : Int,
  len : Int,
  sym : Int,
) -> Unit raise ZlibError {
  if len == 0 {
    return
  }
  let mut node = 0
  for i in 0..<len {
    let bit = (code >> i) & 1
    let next = if bit == 0 { self.left[node] } else { self.right[node] }
    let child = if next == -1 {
      let idx = self.add_node()
      if bit == 0 {
        self.left[node] = idx
      } else {
        self.right[node] = idx
      }
      idx
    } else {
      next
    }
    node = child
  }
  if self.symbol[node] != -1 {
    raise ZlibError::InvalidData("Invalid Huffman code")
  }
  self.symbol[node] = sym
}

///|
fn HuffmanTree::decode(
  self : HuffmanTree,
  reader : BitReader,
) -> Int raise ZlibError {
  if self.table_bits > 0 {
    let bits = reader.peek_bits(self.table_bits)
    let sym = self.table_symbol[bits]
    if sym != -1 {
      let len = self.table_len[bits]
      reader.drop_bits(len)
      return sym
    }
    let sub_idx = self.table_sub[bits]
    if sub_idx != -1 {
      let sub_bits = self.sub_bits[sub_idx]
      let bits2 = reader.peek_bits(self.table_bits + sub_bits)
      let sub_index = bits2 >> self.table_bits
      let sym2 = self.sub_symbol[sub_idx][sub_index]
      if sym2 != -1 {
        let len2 = self.sub_len[sub_idx][sub_index]
        reader.drop_bits(len2)
        return sym2
      }
    }
  }
  let mut node = 0
  while true {
    let bit = reader.read_bits(1)
    node = if bit == 0 { self.left[node] } else { self.right[node] }
    if node == -1 {
      raise ZlibError::InvalidData("Invalid Huffman code")
    }
    if self.symbol[node] != -1 {
      return self.symbol[node]
    }
  }
  raise ZlibError::InvalidData("Unreachable")
}

///|
fn reverse_bits(code : Int, len : Int) -> Int {
  let mut result = 0
  for i = 0; i < len; i = i + 1 {
    let bit = (code >> i) & 1
    result = (result << 1) | bit
  }
  result
}

///|
fn build_huffman_tree(
  lengths : Array[Int],
  max_bits : Int,
) -> HuffmanTree raise ZlibError {
  let bl_count : FixedArray[Int] = FixedArray::make(max_bits + 1, 0)
  for len in lengths {
    if len > 0 {
      bl_count[len] = bl_count[len] + 1
    }
  }
  let next_code : FixedArray[Int] = FixedArray::make(max_bits + 1, 0)
  let mut code = 0
  for bits = 1; bits <= max_bits; bits = bits + 1 {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }
  let table_bits = if max_bits > 9 { 9 } else { max_bits }
  let tree = HuffmanTree::new(table_bits)
  let rev_codes : Array[Int] = []
  for _ in 0..<lengths.length() {
    rev_codes.push(0)
  }
  let next_code_work : FixedArray[Int] = FixedArray::make(max_bits + 1, 0)
  for i in 0..<=max_bits {
    next_code_work[i] = next_code[i]
  }
  for i = 0; i < lengths.length(); i = i + 1 {
    let len = lengths[i]
    if len > 0 {
      let c = next_code_work[len]
      next_code_work[len] = next_code_work[len] + 1
      rev_codes[i] = reverse_bits(c, len)
    }
  }
  if table_bits > 0 {
    let prefix_max : FixedArray[Int] = FixedArray::make(1 << table_bits, 0)
    for i = 0; i < lengths.length(); i = i + 1 {
      let len = lengths[i]
      if len > table_bits {
        let rev = rev_codes[i]
        let prefix = rev & ((1 << table_bits) - 1)
        if len > prefix_max[prefix] {
          prefix_max[prefix] = len
        }
      }
    }
    for prefix in 0..<prefix_max.length() {
      let max_len = prefix_max[prefix]
      if max_len > table_bits {
        let sub_bits = max_len - table_bits
        let size = 1 << sub_bits
        let sub_idx = tree.sub_bits.length()
        tree.sub_bits.push(sub_bits)
        tree.sub_symbol.push(FixedArray::make(size, -1))
        tree.sub_len.push(FixedArray::make(size, 0))
        tree.table_sub[prefix] = sub_idx
      }
    }
  }
  for i = 0; i < lengths.length(); i = i + 1 {
    let len = lengths[i]
    if len > 0 {
      let rev = rev_codes[i]
      tree.insert(rev, len, i)
      if len <= table_bits {
        let fill = 1 << (table_bits - len)
        for j in 0..<fill {
          let idx = rev | (j << len)
          tree.table_symbol[idx] = i
          tree.table_len[idx] = len
        }
      } else if table_bits > 0 {
        let prefix = rev & ((1 << table_bits) - 1)
        let sub_idx = tree.table_sub[prefix]
        if sub_idx == -1 {
          raise ZlibError::InvalidData("Invalid Huffman subtable")
        }
        let sub_bits = tree.sub_bits[sub_idx]
        let sub_len = len - table_bits
        if sub_len > sub_bits {
          raise ZlibError::InvalidData("Invalid Huffman subtable width")
        }
        let sub_code = rev >> table_bits
        let fill = 1 << (sub_bits - sub_len)
        for j in 0..<fill {
          let idx = sub_code | (j << sub_len)
          if tree.sub_symbol[sub_idx][idx] != -1 {
            raise ZlibError::InvalidData("Invalid Huffman code")
          }
          tree.sub_symbol[sub_idx][idx] = i
          tree.sub_len[sub_idx][idx] = len
        }
      }
    }
  }
  tree
}
