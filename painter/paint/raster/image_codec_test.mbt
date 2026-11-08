///|
test "image codec preserves RGBA byte shape through PNG encoding" {
  let rgba = b"\xff\x00\x40\xff\x10\x20\x30\x80"
  let image : @image.ImageData = { width: 2, height: 1, data: rgba, }
  let encoded = @image.encode_png(image)
  let decoded = @image.decode_image(encoded)
  inspect(decoded.width, content="2")
  inspect(decoded.height, content="1")
  assert_eq(decoded.data, rgba)
}
