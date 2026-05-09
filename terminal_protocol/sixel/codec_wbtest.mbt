///|
test "encode_indexed_pixels_to_sixel compresses active color rows" {
  let pixels = Array::make(24, 1)
  let colors = [Color::rgb(255, 255, 255), Color::rgb(66, 133, 244)]
  let result = encode_indexed_pixels_to_sixel(4, 6, pixels, colors)
  inspect(
    result,
    content="\u001bPq#0;2;100;100;100#1;2;25;52;95#1!4~$-\u001b\\",
  )
}
