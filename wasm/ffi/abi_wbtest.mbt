///|
test "borrowed string pointers address the first UTF-16 code unit" {
  let text = "AB日本語"
  let ptr = str2ptr(text)
  inspect(load16_u(ptr), content="65")
  inspect(load16_u(ptr + 2), content="66")
}

///|
test "borrowed array pointers address the first element" {
  let bytes : FixedArray[Byte] = [
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99,
  ]
  assert_eq(load8_u(bytes2ptr(bytes)), bytes[0].to_int())
  let ints : FixedArray[Int32] = [0x12345678, 0x76543210, 0]
  assert_eq(load32(int_array2ptr(ints)), ints[0])
}

///|
test "canonical ABI allocation preserves allocator metadata across sizes" {
  for size in 1..<129 {
    let ptr = malloc(size)
    for i in 0..<size {
      store8(ptr + i, i)
    }
    for i in 0..<size {
      assert_eq(load8_u(ptr + i), i)
    }
    free(ptr)
  }
}

///|
test "canonical ABI memory can transfer ownership to a MoonBit string" {
  let ptr = malloc(6)
  store16(ptr, 65)
  store16(ptr + 2, 0xD83D)
  store16(ptr + 4, 0xDE00)
  let text = ptr2str(ptr, 3)
  inspect(text, content="A😀")
}
