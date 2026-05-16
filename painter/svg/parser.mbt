///|
/// Parse SVG markup string into SVGNode via the shared mizchi/svg parser.
pub fn parse_svg(svg_str : String) -> SVGNode? {
  match @msvg.parse_svg_document(svg_str) {
    Some(doc) => Some(SVGNode::from_msvg(doc.root))
    None => None
  }
}

///|
pub fn parse_transform(value : String) -> Transform {
  Transform::from_msvg(@msvg.parse_transform(value))
}
