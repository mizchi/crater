///|
fn make_blank_kitty_fixture(
  width : Int,
  height : Int,
) -> (@image.Framebuffer, @image.DynamicPalette) {
  let fb = @image.Framebuffer::new(width, height)
  let palette = @image.DynamicPalette::new()
  (fb, palette)
}

///|
test "bench/kitty_encode_blank_1440x960" (b : @bench.T) {
  let (fb, palette) = make_blank_kitty_fixture(1440, 960)
  b.bench(name="kitty_encode_blank_1440x960", fn() {
    b.keep(to_kitty(fb, palette))
  })
}

///|
test "bench/kitty_encode_blank_720x480" (b : @bench.T) {
  let (fb, palette) = make_blank_kitty_fixture(720, 480)
  b.bench(name="kitty_encode_blank_720x480", fn() {
    b.keep(to_kitty(fb, palette))
  })
}
