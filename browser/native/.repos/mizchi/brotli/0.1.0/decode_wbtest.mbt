///|
test "BitReader basic read" {
  let data = Bytes::from_array([b'\x0b', b'\x01', b'\x80', b'\x00'])
  let br = BitReader::new(data)
  let bit = br.read_bits(1)
  inspect(bit, content="1")
}

///|
test "BitReader read_bits multiple" {
  let data = Bytes::from_array([b'\xff', b'\x00', b'\xaa', b'\x55'])
  let br = BitReader::new(data)
  let val1 = br.read_bits(8)
  inspect(val1, content="255")
  let val2 = br.read_bits(8)
  inspect(val2, content="0")
}

///|
test "brotli decompress empty" {
  let compressed = Bytes::from_array([b'\x06'])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="0")
}

///|
test "brotli decompress Hello" {
  let compressed = Bytes::from_array([
    b'\x0b', b'\x02', b'\x80', b'\x48', b'\x65', b'\x6c', b'\x6c', b'\x6f', b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="5")
  inspect(result[0].to_int(), content="72")
  inspect(result[1].to_int(), content="101")
  inspect(result[2].to_int(), content="108")
  inspect(result[3].to_int(), content="108")
  inspect(result[4].to_int(), content="111")
}

///|
test "brotli decompress Hello World" {
  // "Hello, World!" compressed with brotli quality 5
  let compressed = Bytes::from_array([
    b'\x0b', b'\x06', b'\x80', b'\x48', b'\x65', b'\x6c', b'\x6c', b'\x6f', b'\x2c',
    b'\x20', b'\x57', b'\x6f', b'\x72', b'\x6c', b'\x64', b'\x21', b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="13")
  // "Hello, World!" = [72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33]
  inspect(result[0].to_int(), content="72")
  inspect(result[6].to_int(), content="32")
  inspect(result[12].to_int(), content="33")
}

///|
test "brotli decompress repeated data" {
  // "aaaaaaaaaa" compressed with default quality
  let compressed = Bytes::from_array([
    b'\x1b', b'\x09', b'\x00', b'\xf8', b'\x25', b'\xc2', b'\x82', b'\x84', b'\x00',
    b'\x00',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="10")
  // All bytes should be 'a' = 97
  for i in 0..<10 {
    assert_eq(result[i].to_int(), 97)
  }
}

///|
test "brotli decompress fox" {
  // "The quick brown fox jumps over the lazy dog"
  let compressed = Bytes::from_array([
    b'\x0b', b'\x15', b'\x80', b'\x54', b'\x68', b'\x65', b'\x20', b'\x71', b'\x75',
    b'\x69', b'\x63', b'\x6b', b'\x20', b'\x62', b'\x72', b'\x6f', b'\x77', b'\x6e',
    b'\x20', b'\x66', b'\x6f', b'\x78', b'\x20', b'\x6a', b'\x75', b'\x6d', b'\x70',
    b'\x73', b'\x20', b'\x6f', b'\x76', b'\x65', b'\x72', b'\x20', b'\x74', b'\x68',
    b'\x65', b'\x20', b'\x6c', b'\x61', b'\x7a', b'\x79', b'\x20', b'\x64', b'\x6f',
    b'\x67', b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="43")
  // 'T' = 84
  inspect(result[0].to_int(), content="84")
  // 'g' = 103
  inspect(result[42].to_int(), content="103")
}

///|
test "brotli decompress with huffman (q5 repeated)" {
  // "Hello, World! Hello, World! Hello, World!" compressed with quality 5
  // Uses Huffman coding and backward references
  let compressed = Bytes::from_array([
    b'\x1b', b'\x28', b'\x00', b'\x00', b'\xa4', b'\x41', b'\x42', b'\x58', b'\x90',
    b'\xa4', b'\x22', b'\xd1', b'\x50', b'\x93', b'\xcf', b'\xb7', b'\x3a', b'\xd6',
    b'\xc4', b'\x8a', b'\xc1', b'\x15',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="41")
  // First 'H' = 72
  inspect(result[0].to_int(), content="72")
  // Last '!' = 33
  inspect(result[40].to_int(), content="33")
}

///|
test "brotli decompress with huffman (q5 fox repeated)" {
  // Double fox sentence compressed with quality 5
  let compressed = Bytes::from_array([
    b'\x1b', b'\x58', b'\x00', b'\x00', b'\x44', b'\xdb', b'\x46', b'\xa9', b'\x2e',
    b'\x24', b'\x5b', b'\x32', b'\x14', b'\xc5', b'\x53', b'\x91', b'\x67', b'\x72',
    b'\xf2', b'\xe7', b'\x28', b'\x46', b'\x41', b'\x95', b'\x57', b'\xb6', b'\xb2',
    b'\x59', b'\xd0', b'\x7c', b'\xe1', b'\x95', b'\xa7', b'\x23', b'\xf2', b'\xa2',
    b'\xac', b'\x36', b'\x26', b'\xb8', b'\x45', b'\x1f', b'\x18', b'\xc3', b'\xaa',
    b'\xfb', b'\x0f', b'\x81', b'\xc9', b'\x00', b'\x00',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="89")
  // 'T' = 84
  inspect(result[0].to_int(), content="84")
  // '.' = 46 at position 43
  inspect(result[43].to_int(), content="46")
  // Second sentence starts at 45, 'T' = 84
  inspect(result[45].to_int(), content="84")
}

///|
test "brotli decompress with dictionary (q11 repeated)" {
  // "Hello, World! Hello, World! Hello, World!" compressed with quality 11
  // Uses dictionary references
  let compressed = Bytes::from_array([
    b'\x1b', b'\x28', b'\x00', b'\xf8', b'\x9d', b'\x09', b'\x76', b'\xac', b'\x15',
    b'\x2b', b'\x5d', b'\x52', b'\xbe', b'\x06', b'\x61', b'\x41', b'\xba', b'\x52',
    b'\x65', b'\x6f', b'\xc5', b'\x26', b'\xd7', b'\x21', b'\x64', b'\x6c', b'\x6f',
    b'\x82', b'\xa9', b'\x78', b'\x80', b'\x46', b'\xcb', b'\x27', b'\x00',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="41")
  inspect(result[0].to_int(), content="72")
  inspect(result[40].to_int(), content="33")
}

///|
test "brotli decompress with dictionary (q11 fox)" {
  // Double fox sentence compressed with quality 11
  let compressed = Bytes::from_array([
    b'\x1b', b'\x58', b'\x00', b'\x88', b'\x2c', b'\x0e', b'\x78', b'\xd3', b'\xd0',
    b'\x95', b'\x5d', b'\x97', b'\x10', b'\xbb', b'\x17', b'\x2b', b'\xa9', b'\xca',
    b'\xd0', b'\x92', b'\xcc', b'\x8c', b'\xad', b'\x41', b'\x5c', b'\xe6', b'\xf2',
    b'\x36', b'\xc8', b'\x19', b'\x9e', b'\x9e', b'\x0a', b'\x7b', b'\x83', b'\x0d',
    b'\x38', b'\x70', b'\x48', b'\x20', b'\x6f', b'\x21', b'\xbf', b'\x41', b'\xa7',
    b'\x15', b'\xce', b'\x1c', b'\x1e', b'\x27', b'\xaa', b'\x29', b'\x38', b'\xc2',
    b'\xa5', b'\x7d', b'\x1a', b'\x63',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="89")
  inspect(result[0].to_int(), content="84")
  inspect(result[88].to_int(), content="46")
}

// --- google/brotli reference tests (tests/testdata/) ---

///|
test "ref: x (single byte)" {
  // google/brotli tests/testdata/x.compressed → "X"
  let compressed = Bytes::from_array([
    b'\x0b', b'\x00', b'\x80', b'\x58', b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="1")
  inspect(result[0].to_int(), content="88") // 'X' = 0x58
}

///|
test "ref: 10x10y" {
  // google/brotli tests/testdata/10x10y.compressed → "XXXXXXXXXXYYYYYYYYYY"
  let compressed = Bytes::from_array([
    b'\x1b', b'\x13', b'\x00', b'\x00', b'\xa4', b'\xb0', b'\xb2', b'\xea', b'\x81',
    b'\x47', b'\x02', b'\x8a',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="20")
  // First 10 bytes should be 'X' = 88
  for i in 0..<10 {
    assert_eq(result[i].to_int(), 88)
  }
  // Next 10 bytes should be 'Y' = 89
  for i in 10..<20 {
    assert_eq(result[i].to_int(), 89)
  }
}

///|
test "ref: 64x" {
  // google/brotli tests/testdata/64x.compressed → 64 'X' bytes
  let compressed = Bytes::from_array([
    b'\x1b', b'\x3f', b'\x00', b'\x00', b'\x24', b'\xb0', b'\xe2', b'\x99', b'\x80',
    b'\x12',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="64")
  for i in 0..<64 {
    assert_eq(result[i].to_int(), 88) // 'X'
  }
}

///|
test "ref: xyzzy" {
  // google/brotli tests/testdata/xyzzy.compressed → "Xyzzy"
  let compressed = Bytes::from_array([
    b'\x0b', b'\x02', b'\x80', b'\x58', b'\x79', b'\x7a', b'\x7a', b'\x79', b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="5")
  // "Xyzzy" = [88, 121, 122, 122, 121]
  inspect(result[0].to_int(), content="88")
  inspect(result[1].to_int(), content="121")
  inspect(result[2].to_int(), content="122")
  inspect(result[3].to_int(), content="122")
  inspect(result[4].to_int(), content="121")
}

///|
test "ref: ukkonooa" {
  // google/brotli tests/testdata/ukkonooa.compressed → Finnish text (119 bytes)
  let compressed = Bytes::from_array([
    b'\x1b', b'\x76', b'\x00', b'\x00', b'\x14', b'\x4a', b'\xac', b'\x9b', b'\x7a',
    b'\xbd', b'\xe1', b'\x97', b'\x9d', b'\x7f', b'\x8e', b'\xc2', b'\x82', b'\x36',
    b'\x0e', b'\x9c', b'\xe0', b'\x90', b'\x03', b'\xf7', b'\x8b', b'\x9e', b'\x38',
    b'\xe6', b'\xb6', b'\x00', b'\xab', b'\xc3', b'\xca', b'\xa0', b'\xc2', b'\xda',
    b'\x66', b'\x36', b'\xdc', b'\xcd', b'\x80', b'\x8d', b'\x2e', b'\x21', b'\xd7',
    b'\x6e', b'\xe3', b'\xea', b'\x4c', b'\xb8', b'\xf0', b'\xd2', b'\xb8', b'\xc7',
    b'\xc2', b'\x70', b'\x4d', b'\x3a', b'\xf0', b'\x69', b'\x7e', b'\xa1', b'\xb8',
    b'\x45', b'\x73', b'\xab', b'\xc4', b'\x57', b'\x1e',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="119")
  // "ukko nooa, " starts with 'u'=117, 'k'=107
  inspect(result[0].to_int(), content="117")
  inspect(result[1].to_int(), content="107")
  // ends with '.'=46
  inspect(result[118].to_int(), content="46")
}

///|
test "ref: quickfox" {
  // google/brotli tests/testdata/quickfox.compressed
  // "The quick brown fox jumps over the lazy dog"
  let compressed = Bytes::from_array([
    b'\x0b', b'\x15', b'\x80', b'\x54', b'\x68', b'\x65', b'\x20', b'\x71', b'\x75',
    b'\x69', b'\x63', b'\x6b', b'\x20', b'\x62', b'\x72', b'\x6f', b'\x77', b'\x6e',
    b'\x20', b'\x66', b'\x6f', b'\x78', b'\x20', b'\x6a', b'\x75', b'\x6d', b'\x70',
    b'\x73', b'\x20', b'\x6f', b'\x76', b'\x65', b'\x72', b'\x20', b'\x74', b'\x68',
    b'\x65', b'\x20', b'\x6c', b'\x61', b'\x7a', b'\x79', b'\x20', b'\x64', b'\x6f',
    b'\x67', b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="43")
  inspect(result[0].to_int(), content="84") // 'T'
  inspect(result[42].to_int(), content="103") // 'g'
}

///|
test "ref: monkey (843 bytes)" {
  // google/brotli tests/testdata/monkey.compressed (425 bytes → 843 bytes)
  let compressed = Bytes::from_array([
    b'\x1b', b'\x4a', b'\x03', b'\x00', b'\x8c', b'\x94', b'\x6e', b'\xde', b'\xb4',
    b'\xd7', b'\x96', b'\xb1', b'\x78', b'\x86', b'\xf2', b'\x2d', b'\xe1', b'\x1a',
    b'\xbc', b'\x0b', b'\x1c', b'\xba', b'\xa9', b'\xc7', b'\xf7', b'\xcc', b'\x6e',
    b'\xb2', b'\x42', b'\x34', b'\x51', b'\x44', b'\x8b', b'\x4e', b'\x13', b'\x08',
    b'\xa0', b'\xcd', b'\x6e', b'\xe8', b'\x2c', b'\xa5', b'\x53', b'\xa1', b'\x9c',
    b'\x5d', b'\x2c', b'\x1d', b'\x23', b'\x1a', b'\xd2', b'\x56', b'\xbe', b'\xdb',
    b'\xeb', b'\x26', b'\xba', b'\x03', b'\x65', b'\x7c', b'\x96', b'\x6a', b'\xa2',
    b'\x76', b'\xec', b'\xef', b'\x87', b'\x47', b'\x33', b'\xd6', b'\x27', b'\x0e',
    b'\x63', b'\x95', b'\xe2', b'\x1d', b'\x8d', b'\x2c', b'\xc5', b'\xd1', b'\x28',
    b'\x9f', b'\x60', b'\x94', b'\x6f', b'\x02', b'\x8b', b'\xdd', b'\xaa', b'\x64',
    b'\x94', b'\x2c', b'\x1e', b'\x3b', b'\x65', b'\x7c', b'\x07', b'\x45', b'\x5a',
    b'\xb2', b'\xe2', b'\xfc', b'\x49', b'\x81', b'\x2c', b'\x9f', b'\x40', b'\xae',
    b'\xef', b'\x68', b'\x81', b'\xac', b'\x16', b'\x7a', b'\x0f', b'\xf5', b'\x3b',
    b'\x6d', b'\x1c', b'\xb9', b'\x1e', b'\x2d', b'\x5f', b'\xd5', b'\xc8', b'\xaf',
    b'\x5e', b'\x85', b'\xaa', b'\x05', b'\xbe', b'\x53', b'\x75', b'\xc2', b'\xb0',
    b'\x22', b'\x8a', b'\x15', b'\xc6', b'\xa3', b'\xb1', b'\xe6', b'\x42', b'\x14',
    b'\xf4', b'\x84', b'\x54', b'\x53', b'\x19', b'\x5f', b'\xbe', b'\xc3', b'\xf2',
    b'\x1d', b'\xd1', b'\xb7', b'\xe5', b'\xdd', b'\xb6', b'\xd9', b'\x23', b'\xc6',
    b'\xf6', b'\x9f', b'\x9e', b'\xf6', b'\x4d', b'\x65', b'\x30', b'\xfb', b'\xc0',
    b'\x71', b'\x45', b'\x04', b'\xad', b'\x03', b'\xb5', b'\xbe', b'\xc9', b'\xcb',
    b'\xfd', b'\xe2', b'\x50', b'\x5a', b'\x46', b'\x74', b'\x04', b'\x0d', b'\xff',
    b'\x20', b'\x04', b'\x77', b'\xb2', b'\x6d', b'\x27', b'\xbf', b'\x47', b'\xa9',
    b'\x9d', b'\x1b', b'\x96', b'\x2c', b'\x62', b'\x90', b'\x23', b'\x8b', b'\xe0',
    b'\xf8', b'\x1d', b'\xcf', b'\xaf', b'\x1d', b'\x3d', b'\xee', b'\x8a', b'\xc8',
    b'\x75', b'\x23', b'\x66', b'\xdd', b'\xde', b'\xd6', b'\x6d', b'\xe3', b'\x2a',
    b'\x82', b'\x8a', b'\x78', b'\x8a', b'\xdb', b'\xe6', b'\x20', b'\x4c', b'\xb7',
    b'\x5c', b'\x63', b'\xba', b'\x30', b'\xe3', b'\x3f', b'\xb6', b'\xee', b'\x8c',
    b'\x22', b'\xa2', b'\x2a', b'\xb0', b'\x22', b'\x0a', b'\x99', b'\xff', b'\x3d',
    b'\x62', b'\x51', b'\xee', b'\x08', b'\xf6', b'\x3d', b'\x4a', b'\xe4', b'\xcc',
    b'\xef', b'\x22', b'\x87', b'\x11', b'\xe2', b'\x83', b'\x28', b'\xe4', b'\xf5',
    b'\x8f', b'\x35', b'\x19', b'\x63', b'\x5b', b'\xe1', b'\x5a', b'\x92', b'\x73',
    b'\xdd', b'\xa1', b'\x50', b'\x9d', b'\x38', b'\x5c', b'\xeb', b'\xb5', b'\x03',
    b'\x6a', b'\x64', b'\x90', b'\x94', b'\xc8', b'\x8d', b'\xfb', b'\x2f', b'\x8a',
    b'\x86', b'\x22', b'\xcc', b'\x1d', b'\x87', b'\xe0', b'\x48', b'\x0a', b'\x96',
    b'\x77', b'\x90', b'\x39', b'\xc6', b'\x23', b'\x23', b'\x48', b'\xfb', b'\x11',
    b'\x47', b'\x56', b'\xca', b'\x20', b'\xe3', b'\x42', b'\x81', b'\xf7', b'\x77',
    b'\x32', b'\xc1', b'\xa5', b'\x5c', b'\x40', b'\x21', b'\x65', b'\x17', b'\x40',
    b'\x29', b'\x17', b'\x17', b'\x6c', b'\x56', b'\x32', b'\x98', b'\x38', b'\x06',
    b'\xdc', b'\x99', b'\x4d', b'\x33', b'\x29', b'\xbb', b'\x02', b'\xdf', b'\x4c',
    b'\x26', b'\x93', b'\x6c', b'\x17', b'\x82', b'\x86', b'\x20', b'\xd7', b'\x03',
    b'\x79', b'\x7d', b'\x9a', b'\x00', b'\xd7', b'\x87', b'\x00', b'\xe7', b'\x0b',
    b'\x66', b'\xe3', b'\x4c', b'\x66', b'\x71', b'\x67', b'\x08', b'\x32', b'\xf9',
    b'\x08', b'\x3e', b'\x81', b'\x33', b'\xcd', b'\x17', b'\x72', b'\x31', b'\xf0',
    b'\xb8', b'\x94', b'\x52', b'\x4b', b'\x90', b'\x31', b'\x8e', b'\x68', b'\xc1',
    b'\xef', b'\x90', b'\xc9', b'\xe5', b'\xf2', b'\x61', b'\x09', b'\x72', b'\x25',
    b'\xad', b'\xec', b'\xc5', b'\x62', b'\xc0', b'\x0b', b'\x12', b'\x05', b'\xf7',
    b'\x91', b'\x75', b'\x0d', b'\xee', b'\x61', b'\x2e', b'\x2e', b'\x19', b'\x09',
    b'\xc2', b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="843")
  // Verify first bytes: "zn" = [122, 110]
  inspect(result[0].to_int(), content="122")
  inspect(result[1].to_int(), content="110")
}

///|
test "ref: zeros (262144 bytes)" {
  // google/brotli tests/testdata/zeros.compressed → 262144 zero bytes
  let compressed = Bytes::from_array([
    b'\x5b', b'\xff', b'\xff', b'\x03', b'\x60', b'\x02', b'\x20', b'\x1e', b'\x0b',
    b'\x28', b'\xf7', b'\x7e', b'\x00',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="262144")
  // All bytes should be 0
  for i in 0..<100 {
    assert_eq(result[i].to_int(), 0)
  }
  assert_eq(result[262143].to_int(), 0)
}

///|
test "ref: backward65536" {
  // google/brotli tests/testdata/backward65536.compressed → 65792 bytes
  let compressed = Bytes::from_array([
    b'\x5b', b'\xff', b'\x00', b'\x01', b'\x40', b'\x0a', b'\x00', b'\xab', b'\x16',
    b'\x7b', b'\xac', b'\x00', b'\x48', b'\x4e', b'\x73', b'\xed', b'\x01', b'\x92',
    b'\x03',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="65792")
}

///|
test "ref: quickfox_repeated (176128 bytes)" {
  // google/brotli tests/testdata/quickfox_repeated.compressed
  // "The quick brown fox..." repeated many times (176128 bytes)
  let compressed = Bytes::from_array([
    b'\x5b', b'\xff', b'\xaf', b'\x02', b'\xc0', b'\x22', b'\x79', b'\x5c', b'\xfb',
    b'\x5a', b'\x8c', b'\x42', b'\x3b', b'\xf4', b'\x25', b'\x55', b'\x19', b'\x5a',
    b'\x92', b'\x99', b'\xb1', b'\x35', b'\xc8', b'\x19', b'\x9e', b'\x9e', b'\x0a',
    b'\x7b', b'\x4b', b'\x90', b'\xb9', b'\x3c', b'\x98', b'\xc8', b'\x09', b'\x40',
    b'\xf3', b'\xe6', b'\xd9', b'\x4d', b'\xe4', b'\x6d', b'\x65', b'\x1b', b'\x27',
    b'\x87', b'\x13', b'\x5f', b'\xa6', b'\xe9', b'\x30', b'\x96', b'\x7b', b'\x3c',
    b'\x15', b'\xd8', b'\x53', b'\x1c',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="176128")
  // First bytes: "The " = [84, 104, 101, 32]
  inspect(result[0].to_int(), content="84")
  inspect(result[1].to_int(), content="104")
  inspect(result[2].to_int(), content="101")
  inspect(result[3].to_int(), content="32")
}

// --- Node.js zlib brotli compatibility tests ---

///|
test "compat: q5 small text (55 bytes)" {
  // "Hello, World! This is a test of the Brotli compression." compressed with Node.js zlib quality 5
  let compressed = Bytes::from_array([
    b'\x1b', b'\x36', b'\x00', b'\x00', b'\x44', b'\xdd', b'\x96', b'\xea', b'\xde',
    b'\xcf', b'\x4b', b'\x78', b'\x7a', b'\xa9', b'\x22', b'\x86', b'\x83', b'\x3a',
    b'\xd0', b'\xc1', b'\x06', b'\x1c', b'\xb8', b'\x27', b'\x81', b'\x0f', b'\x3e',
    b'\xc1', b'\xc8', b'\xc3', b'\x06', b'\x9c', b'\x78', b'\x50', b'\xfb', b'\x54',
    b'\xac', b'\xe3', b'\xb8', b'\x62', b'\xa0', b'\x59', b'\xd0', b'\x03', b'\x5a',
    b'\x5f', b'\x18', b'\xac', b'\x93', b'\x8f', b'\xda', b'\x8d', b'\xc9', b'\xc3',
    b'\x90', b'\xe6', b'\x0d',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="55")
  // 'H' = 72, 'e' = 101
  inspect(result[0].to_int(), content="72")
  inspect(result[1].to_int(), content="101")
}

///|
test "compat: q5 repeated ABCDEFGH*100 (800 bytes)" {
  // "ABCDEFGH" * 100 compressed with Node.js zlib quality 5
  let compressed = Bytes::from_array([
    b'\x1b', b'\x1f', b'\x03', b'\x00', b'\xc4', b'\x03', b'\xc6', b'\xf6', b'\xa6',
    b'\xa3', b'\xb7', b'\x70', b'\x48', b'\x03', b'\xe5', b'\x74', b'\x07',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="800")
  inspect(result[0].to_int(), content="65") // 'A'
  inspect(result[7].to_int(), content="72") // 'H'
  inspect(result[8].to_int(), content="65") // 'A' (repeat)
}

///|
test "compat: q5 binary 1000 bytes" {
  // Deterministic binary data: (i * 17 + 31) & 0xFF for i in 0..1000
  let compressed = Bytes::from_array([
    b'\x1b', b'\xe7', b'\x03', b'\x00', b'\x8c', b'\xd4', b'\x48', b'\x4d', b'\x73',
    b'\xbb', b'\x81', b'\x71', b'\x5a', b'\xfa', b'\x6c', b'\x5d', b'\x3b', b'\xe0',
    b'\x90', b'\x64', b'\x0d', b'\xcc', b'\x73', b'\x20', b'\x43', b'\x6c', b'\x97',
    b'\x6a', b'\x11', b'\x11', b'\x8d', b'\x06', b'\x47', b'\xe4', b'\x04', b'\xa5',
    b'\xc9', b'\x1d', b'\xc9', b'\xea', b'\x60', b'\x6a', b'\xed', b'\xfc', b'\xa3',
    b'\xb5', b'\xfe', b'\xb0', b'\x10', b'\xaa', b'\xcc', b'\x9e', b'\x68', b'\x18',
    b'\x48', b'\xae', b'\x9e', b'\xbd', b'\x37', b'\x57', b'\x6f', b'\xc6', b'\xa5',
    b'\x48', b'\x6d', b'\xf1', b'\xfa', b'\xfe', b'\xc4', b'\xca', b'\xe9', b'\x5b',
    b'\x63', b'\xf9', b'\xa2', b'\x1d', b'\xb2', b'\xc4', b'\x1a', b'\xab', b'\xeb',
    b'\x8b', b'\x2f', b'\x9f', b'\xbc', b'\xd6', b'\x17', b'\x4f', b'\x0a', b'\x48',
    b'\x12', b'\x5b', b'\xa2', b'\xb5', b'\xbd', b'\xb1', b'\xa5', b'\xe3', b'\x97',
    b'\xda', b'\xfc', b'\x41', b'\x02', b'\x88', b'\x22', b'\x73', b'\xa4', b'\xa6',
    b'\x27', b'\xba', b'\x78', b'\xf4', b'\x5c', b'\x9d', b'\xdd', b'\x09', b'\x93',
    b'\x20', b'\x34', b'\x85', b'\x2b', b'\xdd', b'\x91', b'\x85', b'\xc3', b'\xa7',
    b'\xca', b'\xf4', b'\x86', b'\x1b', b'\x78', b'\x81', b'\x31', b'\x54', b'\xee',
    b'\x9a', b'\x9e', b'\x3f', b'\x78', b'\x2c', b'\x4f', b'\xae', b'\x98', b'\x8e',
    b'\xe3', b'\x1b', b'\x82', b'\xa5', b'\xce', b'\xa9', b'\xb9', b'\xfd', b'\x87',
    b'\xd2', b'\xf8', b'\x82', b'\x6a', b'\x58', b'\x9e', b'\x3e', b'\x50', b'\xec',
    b'\x98', b'\x9c', b'\xdd', b'\xbb', b'\x2f', b'\x8e', b'\xce', b'\x88', b'\x8a',
    b'\xe1', b'\xea', b'\xfc', b'\x85', b'\xf6', b'\x89', b'\x99', b'\xdd', b'\xbb',
    b'\xff', b'\xe1', b'\x09', b'\x56', b'\xd0', b'\x1c', b'\xad', b'\x2f', b'\xdf',
    b'\x36', b'\x5e', b'\xd8', b'\xb9', b'\xfd', b'\x1b', b'\x1c', b'\x21', b'\x19',
    b'\xc5', b'\xd6', b'\x78', b'\x73', b'\xad', b'\x63', b'\xf9', b'\xed', b'\x9b',
    b'\xdf', b'\xfe', b'\x01', b'\x94', b'\x90', b'\x2c', b'\xb5', b'\x27', b'\xdb',
    b'\x32', b'\x9a', b'\xdb', b'\xba', b'\xfe', b'\xe9', b'\xed', b'\x01', b'\x11',
    b'\xc1', b'\x54', b'\xb9', b'\x33', b'\xcd', b'\x23', b'\xd9', b'\xcd', b'\xab',
    b'\xef', b'\xee', b'\xee', b'\x2f', b'\x84', b'\x0c', b'\xa5', b'\x2b', b'\xdd',
    b'\x34', b'\x9c', b'\xd9', b'\xb8', b'\xfc', b'\xea', b'\x6c', b'\x7f', b'\x7c',
    b'\x40', b'\x57', b'\x38', b'\x53', b'\x8d', b'\x43', b'\xe9', b'\xf5', b'\x8b',
    b'\xcf', b'\xf6', b'\xe6', b'\xcb', b'\xf9', b'\x34', b'\xb9', b'\x23', b'\x59',
    b'\x1d', b'\x00',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="1000")
  // First byte: (0 * 17 + 31) & 0xFF = 31
  inspect(result[0].to_int(), content="31")
  // Second: (1 * 17 + 31) & 0xFF = 48
  inspect(result[1].to_int(), content="48")
}

///|
test "compat: q11 large text (22500 bytes)" {
  // "The quick brown fox jumps over the lazy dog. " * 500 compressed with quality 11
  let compressed = Bytes::from_array([
    b'\x1b', b'\xe3', b'\x57', b'\x88', b'\x2c', b'\x0e', b'\x78', b'\xd3', b'\xd0',
    b'\x95', b'\x5d', b'\x97', b'\x10', b'\xbb', b'\x17', b'\x2b', b'\xa9', b'\xca',
    b'\xd0', b'\x92', b'\xcc', b'\x8c', b'\xad', b'\x41', b'\x5c', b'\xe6', b'\xf2',
    b'\x36', b'\xc8', b'\x19', b'\x9e', b'\x9e', b'\x0a', b'\x7b', b'\x83', b'\x0d',
    b'\x38', b'\x70', b'\x48', b'\x20', b'\x6f', b'\x34', b'\xb8', b'\x41', b'\xa7',
    b'\x15', b'\xce', b'\x1c', b'\x1e', b'\x27', b'\xaa', b'\x29', b'\x38', b'\xc2',
    b'\x89', b'\x7b', b'\x02', b'\xd8', b'\xa7', b'\xc1',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="22500")
  inspect(result[0].to_int(), content="84") // 'T'
  inspect(result[44].to_int(), content="32") // ' ' (space after "dog.")
}

///|
test "compat: q1 large text (22500 bytes)" {
  // "The quick brown fox jumps over the lazy dog. " * 500 compressed with quality 1
  let compressed = Bytes::from_array([
    b'\x8b', b'\xf1', b'\x2b', b'\x00', b'\x80', b'\xaa', b'\xaa', b'\xaa', b'\xea',
    b'\xff', b'\x74', b'\xa5', b'\xc3', b'\x49', b'\x6f', b'\x27', b'\x3d', b'\x5c',
    b'\x4c', b'\x55', b'\x45', b'\x37', b'\x53', b'\x35', b'\x31', b'\x53', b'\x33',
    b'\xb5', b'\x0d', b'\x0e', b'\xe0', b'\xe2', b'\x57', b'\x9a', b'\x48', b'\x71',
    b'\x87', b'\x0d', b'\xc6', b'\x3c', b'\x23', b'\xa8', b'\xb5', b'\x59', b'\x38',
    b'\x66', b'\xf1', b'\x2b', b'\x6e', b'\xe8', b'\xb3', b'\x11', b'\xf5', b'\xa5',
    b'\xce', b'\xbe', b'\x9f', b'\xe8', b'\x2d', b'\x83', b'\x2b', b'\x0b', b'\x6d',
    b'\xf9', b'\x3f', b'\x82', b'\x26', b'\xc3', b'\xf0', b'\xdb', b'\x13', b'\x80',
    b'\x01',
  ])
  let result = brotli_decompress(compressed)
  inspect(result.length(), content="22500")
  inspect(result[0].to_int(), content="84") // 'T'
}
