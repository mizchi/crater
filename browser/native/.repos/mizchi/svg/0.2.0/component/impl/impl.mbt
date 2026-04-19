///|
fn render(svg_markup : String, width : UInt, height : UInt) -> Image? {
  let w = width.reinterpret_as_int()
  let h = height.reinterpret_as_int()
  @svg.render_svg_to_image(svg_markup, w, h).map(image_to_wit)
}

///|
fn image_to_wit(img : @svg.Image) -> Image {
  let len = img.pixels.length()
  let data : Array[Byte] = Array::new(capacity=len * 4)
  for color in img.pixels {
    data.push(color.r.to_byte())
    data.push(color.g.to_byte())
    data.push(color.b.to_byte())
    data.push(color.a.to_byte())
  }
  {
    width: img.width.reinterpret_as_uint(),
    height: img.height.reinterpret_as_uint(),
    data,
  }
}
