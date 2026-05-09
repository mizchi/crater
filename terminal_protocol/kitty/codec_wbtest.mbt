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

///|
test "encode_indexed_pixels_to_kitty_cells includes placement and cell dimensions" {
  let encoded = encode_indexed_pixels_to_kitty_cells(
    1,
    1,
    [0],
    [Color::rgb(255, 255, 255)],
    3,
    2,
    image_id=7,
    placement_id=11,
  )
  inspect(
    encoded,
    content="\u001b_Ga=T,f=24,q=2,c=3,r=2,i=7,p=11,s=1,v=1,m=0;////\u001b\\",
  )
}

///|
test "encode_indexed_pixels_to_kitty_cells splits payload into continuation chunks" {
  let pixels_per_chunk = chunk_size() / 4
  let encoded = encode_indexed_pixels_to_kitty_cells(
    pixels_per_chunk + 1,
    1,
    Array::make(pixels_per_chunk + 1, 0),
    [Color::rgb(255, 255, 255)],
    3,
    2,
    image_id=7,
    placement_id=11,
  )
  assert_true(
    encoded.contains(
      "\u001b_Ga=T,f=24,q=2,c=3,r=2,i=7,p=11,s=\{pixels_per_chunk + 1},v=1,m=1;",
    ),
  )
  assert_true(encoded.contains("\u001b\\\u001b_Gm=0;////\u001b\\"))
}

///|
test "encode_png_base64_to_kitty_image emits direct image payload" {
  let encoded = encode_png_base64_to_kitty_image(
    "abcd",
    3,
    2,
    image_id=7,
    placement_id=11,
  )
  inspect(
    encoded,
    content="\u001b_Ga=T,f=100,q=2,c=3,r=2,i=7,p=11,m=0;abcd\u001b\\",
  )
}

///|
test "encode_png_base64_to_kitty_image splits base64 payload into continuation chunks" {
  let encoded = encode_png_base64_to_kitty_image(
    "a".repeat(chunk_size() + 1),
    3,
    2,
    image_id=7,
    placement_id=11,
  )
  assert_true(encoded.contains("\u001b_Ga=T,f=100,q=2,c=3,r=2,i=7,p=11,m=1;"))
  assert_true(encoded.contains("\u001b\\\u001b_Gm=0;a\u001b\\"))
}

///|
test "encode_rgba_base64_to_kitty_image emits raw rgba dimensions" {
  let encoded = encode_rgba_base64_to_kitty_image(
    "rgba",
    4,
    5,
    3,
    2,
    image_id=7,
    placement_id=11,
  )
  inspect(
    encoded,
    content="\u001b_Ga=T,f=32,q=2,c=3,r=2,i=7,p=11,s=4,v=5,m=0;rgba\u001b\\",
  )
}

///|
test "placement commands encode put and delete" {
  inspect(
    encode_put_placement(7, 11, 3, 2),
    content="\u001b_Ga=p,q=2,i=7,p=11,c=3,r=2;\u001b\\",
  )
  inspect(
    encode_delete_placement(7, 11),
    content="\u001b_Ga=d,q=2,d=i,i=7,p=11;\u001b\\",
  )
}
