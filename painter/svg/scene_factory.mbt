///|
/// Helper: Create a rectangle node
pub fn rect(
  id : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> SVGNode {
  SVGNode::from_msvg(@msvg.rect(id, x, y, width, height))
}

///|
/// Helper: Create a circle node
pub fn circle(id : String, cx : Double, cy : Double, r : Double) -> SVGNode {
  SVGNode::from_msvg(@msvg.circle(id, cx, cy, r))
}

///|
/// Helper: Create a line node
pub fn line(
  id : String,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> SVGNode {
  SVGNode::from_msvg(@msvg.line(id, x1, y1, x2, y2))
}

///|
/// Helper: Create a path node from path data string
pub fn path(id : String, d : String) -> SVGNode {
  SVGNode::from_msvg(@msvg.path(id, d))
}

///|
/// Helper: Create a text node
pub fn text(
  id : String,
  x : Double,
  y : Double,
  content : String,
  font_size : Double,
) -> SVGNode {
  SVGNode::from_msvg(@msvg.text(id, x, y, content, font_size))
}

///|
/// Helper: Create a group node
pub fn group(id : String, children : Array[SVGNode]) -> SVGNode {
  let node = SVGNode::new(Group)
  node.id = id
  for child in children {
    node.children.push(child)
  }
  node
}
