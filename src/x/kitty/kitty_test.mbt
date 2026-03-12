///|
test "to_kitty encodes a single white pixel" {
  let fb = @sixel.Framebuffer::new(1, 1)
  let palette = @sixel.DynamicPalette::new()
  let encoded = to_kitty(fb, palette)
  inspect(encoded, content="\u001b_Ga=T,f=24,s=1,v=1,m=0;////\u001b\\")
}

///|
test "to_kitty splits large payload into multiple kitty chunks" {
  let fb = @sixel.Framebuffer::new(1025, 1)
  let palette = @sixel.DynamicPalette::new()
  let encoded = to_kitty(fb, palette)
  assert_true(encoded.contains("\u001b_Ga=T,f=24,s=1025,v=1,m=1;"))
  assert_true(encoded.contains("\u001b_Gm=0;"))
}
