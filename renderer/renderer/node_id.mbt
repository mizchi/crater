///|
// Node id helpers shared by renderer element conversion and layout adjustments.

///|
fn node_id_is_tag(node_id : String, tag : String) -> Bool {
  node_id == tag ||
  node_id.has_prefix(tag + "#") ||
  node_id.has_prefix(tag + ".")
}

///|
/// Create node ID from element
fn make_node_id(elem : @html.Element) -> String {
  match elem.id {
    Some(id) => elem.tag + "#" + id
    None =>
      if elem.classes.length() > 0 {
        elem.tag + "." + elem.classes[0]
      } else {
        elem.tag
      }
  }
}
