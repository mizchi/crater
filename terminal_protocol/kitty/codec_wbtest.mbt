///|
test "encode_indexed_pixels_to_kitty encodes a single white pixel" {
  let encoded = encode_indexed_pixels_to_kitty(1, 1, [0], [
    Color::rgb(255, 255, 255),
  ])
  inspect(encoded, content="\u001b_Ga=T,f=24,q=2,s=1,v=1,m=0;////\u001b\\")
}

///|
test "encode_indexed_pixels_to_kitty splits large payload into chunks" {
  let pixels_per_chunk = chunk_size() / 4
  let encoded = encode_indexed_pixels_to_kitty(
    pixels_per_chunk + 1,
    1,
    Array::make(pixels_per_chunk + 1, 0),
    [Color::rgb(255, 255, 255)],
  )
  assert_true(
    encoded.contains("\u001b_Ga=T,f=24,q=2,s=\{pixels_per_chunk + 1},v=1,m=1;"),
  )
  assert_true(encoded.contains("\u001b_Gm=0;"))
}
