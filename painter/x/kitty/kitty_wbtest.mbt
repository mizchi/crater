///|
test "to_kitty encodes a single white pixel" {
  let fb = @image.Framebuffer::new(1, 1)
  let palette = @image.DynamicPalette::new()
  let encoded = to_kitty(fb, palette)
  inspect(encoded, content="\u001b_Ga=T,f=24,s=1,v=1,m=0;////\u001b\\")
}

///|
test "to_kitty splits large payload into multiple kitty chunks" {
  let pixels_per_chunk = kitty_chunk_size / 4
  let fb = @image.Framebuffer::new(pixels_per_chunk + 1, 1)
  let palette = @image.DynamicPalette::new()
  let encoded = to_kitty(fb, palette)
  assert_true(
    encoded.contains("\u001b_Ga=T,f=24,s=\{pixels_per_chunk + 1},v=1,m=1;"),
  )
  assert_true(encoded.contains("\u001b_Gm=0;"))
}

///|
async test "write_kitty streams the same bytes as to_kitty" {
  let fb = @image.Framebuffer::new(3, 2)
  let palette = @image.DynamicPalette::new()
  let (reader, writer) = @pipe.pipe()
  defer reader.close()
  write_kitty(writer, fb, palette)
  writer.close()
  let streamed = reader.read_all().text()
  assert_eq(streamed, to_kitty(fb, palette))
}
