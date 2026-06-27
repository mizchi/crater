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

///|
/// Internal attribute the dynamic-rendering path stamps onto a render
/// `@html.Element` to carry its originating `@dom.DomTree` node id through to the
/// render `@node.Node` (see `attach_dom_id`). It lives only on the derived render
/// document, never on the DomTree, so it is not serialized into `html_content`;
/// the cascade ignores it (`html_to_selector_element` filters it out).
pub let crater_dom_id_attr : String = "data-crater-domid"

///|
/// Parse a non-negative integer, or `None` on any non-digit. Dependency-free so
/// `core`-adjacent render code keeps a small import surface.
fn parse_dom_id(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut acc = 0
  for c in s {
    let d = c.to_int() - '0'.to_int()
    if d < 0 || d > 9 {
      return None
    }
    acc = acc * 10 + d
  }
  Some(acc)
}

///|
/// Copy the originating DomTree node id (if the element carries the internal
/// `data-crater-domid` attribute) onto the freshly-built render node.
fn attach_dom_id(node : @node.Node, elem : @html.Element) -> @node.Node {
  match elem.attributes.get(crater_dom_id_attr) {
    Some(s) => node.set_dom_id(parse_dom_id(s))
    None => ()
  }
  node
}
