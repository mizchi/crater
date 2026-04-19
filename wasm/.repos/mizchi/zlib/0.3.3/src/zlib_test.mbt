///|
/// Tests for zlib stored blocks implementation
test "adler32 empty" {
  let result = adler32(Bytes::from_array([]))
  inspect(result, content="1")
}

///|
test "adler32 simple" {
  // "abc" should produce known value
  let data = Bytes::from_array([b'a', b'b', b'c'])
  let result = adler32(data)
  // s1 = 1 + 97 + 98 + 99 = 295
  // s2 = 0 + (1+97) + (1+97+98) + (1+97+98+99) = 98 + 196 + 295 = 589
  // result = (589 << 16) | 295 = 38600999
  inspect(result, content="38600999")
}

///|
test "zlib round trip empty" {
  let data = Bytes::from_array([])
  let compressed = zlib_compress_stored(data)
  let decompressed = zlib_decompress_stored(compressed)
  inspect(decompressed.length(), content="0")
}

///|
test "zlib round trip simple" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = zlib_compress_stored(data)
  let decompressed = zlib_decompress_stored(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "zlib round trip fixed" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = zlib_compress(data)
  let decompressed = zlib_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "zlib round trip larger" {
  // Test with data larger than comfort but smaller than block limit
  let data : Array[Byte] = []
  for i = 0; i < 1000; i = i + 1 {
    data.push((i % 256).to_byte())
  }
  let bytes = Bytes::from_array(
    FixedArray::makei(data.length(), fn(i) { data[i] }),
  )
  let compressed = zlib_compress_stored(bytes)
  let decompressed = zlib_decompress_stored(compressed)
  inspect(decompressed.length(), content="1000")

  // Verify content
  for i = 0; i < 1000; i = i + 1 {
    assert_eq(decompressed[i], (i % 256).to_byte())
  }
}

///|
test "zlib header format" {
  let data = Bytes::from_array([b'x'])
  let compressed = zlib_compress_stored(data)

  // Check zlib header
  inspect(compressed[0], content="b'\\x78'") // CMF
  inspect(compressed[1], content="b'\\x01'") // FLG

  // Check BFINAL=1 (stored block, final)
  inspect(compressed[2], content="b'\\x01'")

  // Check LEN=1 (little-endian)
  inspect(compressed[3], content="b'\\x01'")
  inspect(compressed[4], content="b'\\x00'")

  // Check NLEN=0xfffe
  inspect(compressed[5], content="b'\\xFE'")
  inspect(compressed[6], content="b'\\xFF'")

  // Check data
  inspect(compressed[7], content="b'\\x78'") // 'x'
}

///|
test "zlib decompress at offset" {
  let payload = Bytes::from_array([b'a', b'b'])
  let compressed = zlib_compress_stored(payload)
  let bytes : Array[Byte] = []
  bytes.push(b'X')
  bytes.push(b'Y')
  for b in compressed {
    bytes.push(b)
  }
  bytes.push(b'Z')
  let data = Bytes::from_array(
    FixedArray::makei(bytes.length(), fn(i) { bytes[i] }),
  )
  let (out, next_offset) = zlib_decompress_stored_at(data, 2)
  assert_true(out.length() == payload.length())
  for i = 0; i < payload.length(); i = i + 1 {
    assert_true(out[i] == payload[i])
  }
  assert_true(next_offset == 2 + compressed.length())
}

///|
test "zlib decompress deflate" {
  // zlib.deflateSync(Buffer.from("hello")).toString("hex")
  let hex = "789ccb48cdc9c90700062c0215"
  let compressed = hex_to_bytes(hex)
  let decompressed = zlib_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "deflate round trip stored" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = deflate_compress_stored(data)
  let decompressed = deflate_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "deflate round trip fixed" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = deflate_compress(data)
  let decompressed = deflate_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "gzip round trip stored" {
  let data = Bytes::from_array([b'h', b'e', b'l', b'l', b'o'])
  let compressed = gzip_compress_stored(data)
  let decompressed = gzip_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
test "gzip decompress fixture" {
  // python3: gzip.compress(b"hello").hex()
  let hex = "1f8b08000000000000ffcb48cdc9c9070086a6103605000000"
  let compressed = hex_to_bytes(hex)
  let decompressed = gzip_decompress(compressed)
  inspect(decompressed.length(), content="5")
  inspect(decompressed[0], content="b'\\x68'")
  inspect(decompressed[4], content="b'\\x6F'")
}

///|
let fixture_size : Int = 256 * 1024

///|
fn assert_fixture_pattern(data : Bytes) -> Unit raise {
  if data.length() != fixture_size {
    fail("fixture length mismatch: \{data.length()}")
  }
  for i in 0..<fixture_size {
    let expected = (i % 256).to_byte()
    if data[i] != expected {
      fail("fixture mismatch at \{i}")
    }
  }
}

///|
test "deflate decompress dynamic fixture" {
  let compressed = try! @fs.read_file_to_bytes(
    "fixtures/deflate_dynamic_256k.bin",
  )
  let decompressed = deflate_decompress(compressed)
  assert_fixture_pattern(decompressed)
}

///|
test "adler32 dynamic fixture" {
  let compressed = try! @fs.read_file_to_bytes(
    "fixtures/deflate_dynamic_256k.bin",
  )
  let decompressed = deflate_decompress(compressed)
  let checksum = adler32(decompressed)
  inspect(checksum, content="-1886380573")
}

///|
test "zlib decompress dynamic fixture" {
  let compressed = try! @fs.read_file_to_bytes("fixtures/zlib_dynamic_256k.bin")
  let decompressed = zlib_decompress(compressed)
  assert_fixture_pattern(decompressed)
}

///|
test "gzip decompress dynamic fixture" {
  let compressed = try! @fs.read_file_to_bytes("fixtures/gzip_dynamic_256k.bin")
  let decompressed = gzip_decompress(compressed)
  assert_fixture_pattern(decompressed)
}

///|
test "fixture loader hex roundtrip" {
  let bytes = Bytes::from_array([b'\x00', b'\x01', b'\xff'])
  let hex = bytes_to_hex(bytes)
  inspect(hex, content="0001ff")
  let back = hex_to_bytes(hex)
  inspect(back.length(), content="3")
  inspect(back[0], content="b'\\x00'")
  inspect(back[1], content="b'\\x01'")
  inspect(back[2], content="b'\\xFF'")
}
