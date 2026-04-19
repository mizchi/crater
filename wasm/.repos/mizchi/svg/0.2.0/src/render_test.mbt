///|
/// Public rendering helpers

///|
test "render_svg_node_to_image_basic" {
  let node = rect("r", 0.0, 0.0, 10.0, 10.0)
  node.fill = SolidColor(Color::black())
  let image = render_svg_node_to_image(node, 20, 20)
  let pixel = image.get_pixel(5, 5)
  inspect(pixel.is_transparent(), content="false")
}

///|
test "render_svg_document_to_image_basic" {
  let node = rect("r", 2.0, 2.0, 6.0, 6.0)
  node.fill = SolidColor(Color::black())
  let doc = SVGDocument::new(node)
  let image = render_svg_document_to_image(doc, 16, 16)
  let pixel = image.get_pixel(4, 4)
  inspect(pixel.is_transparent(), content="false")
}

///|
test "render_svg_viewbox_root" {
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\">" +
    "<rect width=\"10\" height=\"10\" fill=\"black\"/>" +
    "</svg>"
  let image = match render_svg_to_image(svg, 20, 20) {
    Some(img) => img
    None => Image::new(1, 1)
  }
  let pixel = image.get_pixel(15, 15)
  inspect(pixel.is_transparent(), content="false")
}
