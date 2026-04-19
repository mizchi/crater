///|
let max_length : Int = 15

///|
fn get_next_key(key : Int, len : Int) -> Int {
  let mut step = 1 << (len - 1)
  while (key & step) != 0 {
    step = step >> 1
  }
  (key & (step - 1)) + step
}

///|
fn replicate_value(
  table : FixedArray[HuffmanCode],
  i : Int,
  step : Int,
  end : Int,
  code : HuffmanCode,
) -> Unit {
  let mut e = end
  while e > 0 {
    e -= step
    table[i + e] = code
  }
}

///|
fn next_table_bit_size(
  count : FixedArray[Int],
  len : Int,
  root_bits : Int,
) -> Int {
  let mut left = 1 << (len - root_bits)
  let mut l = len
  while l < max_length {
    left -= count[l]
    if left <= 0 {
      break
    }
    l += 1
    left = left << 1
  }
  l - root_bits
}

///|
fn brotli_build_huffman_table(
  root_table : FixedArray[HuffmanCode],
  table : Int,
  root_bits : Int,
  code_lengths : FixedArray[Int],
  code_lengths_size : Int,
) -> Int {
  let start_table = table
  let mut table = table
  let mut key = 0
  let mut symbol = 0
  let count : FixedArray[Int] = FixedArray::make(max_length + 1, 0)
  let offset : FixedArray[Int] = FixedArray::make(max_length + 1, 0)
  let sorted : FixedArray[Int] = FixedArray::make(code_lengths_size, 0)
  for s in 0..<code_lengths_size {
    count[code_lengths[s]] += 1
  }
  offset[1] = 0
  for len in 1..<max_length {
    offset[len + 1] = offset[len] + count[len]
  }
  for s in 0..<code_lengths_size {
    if code_lengths[s] != 0 {
      sorted[offset[code_lengths[s]]] = s
      offset[code_lengths[s]] += 1
    }
  }
  let mut table_bits = root_bits
  let mut table_size = 1 << table_bits
  let mut total_size = table_size
  if offset[max_length] == 1 {
    for k in 0..<total_size {
      root_table[table + k] = { bits: 0, value: sorted[0] & 0xffff }
    }
    return total_size
  }
  key = 0
  symbol = 0
  let mut len = 1
  let mut step = 2
  while len <= root_bits {
    while count[len] > 0 {
      let code : HuffmanCode = {
        bits: len & 0xff,
        value: sorted[symbol] & 0xffff,
      }
      symbol += 1
      replicate_value(root_table, table + key, step, table_size, code)
      key = get_next_key(key, len)
      count[len] -= 1
    }
    len += 1
    step = step << 1
  }
  let mask = total_size - 1
  let mut low = -1
  len = root_bits + 1
  step = 2
  while len <= max_length {
    while count[len] > 0 {
      if (key & mask) != low {
        table += table_size
        table_bits = next_table_bit_size(count, len, root_bits)
        table_size = 1 << table_bits
        total_size += table_size
        low = key & mask
        root_table[start_table + low] = {
          bits: (table_bits + root_bits) & 0xff,
          value: (table - start_table - low) & 0xffff,
        }
      }
      let code : HuffmanCode = {
        bits: (len - root_bits) & 0xff,
        value: sorted[symbol] & 0xffff,
      }
      symbol += 1
      replicate_value(
        root_table,
        table + ushr(key, root_bits),
        step,
        table_size,
        code,
      )
      key = get_next_key(key, len)
      count[len] -= 1
    }
    len += 1
    step = step << 1
  }
  total_size
}
