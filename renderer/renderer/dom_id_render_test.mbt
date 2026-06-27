///|
/// Phase 1(A) of incremental reflow (docs/incremental-reflow-design.md): the
/// dynamic-rendering path stamps a `data-crater-domid` attribute onto each
/// render element so the originating DomTree node id reaches the render
/// `@node.Node` as a stable, mutation-surviving identity. The renderer copies it
/// into `Node.dom_id` and keeps it out of the cascade.

///|
fn find_render_node_by_id(node : @node.Node, id : String) -> @node.Node? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    match find_render_node_by_id(child, id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
test "dom_id is threaded onto the render node and hidden from the cascade" {
  // The element carries the internal id attribute, and a page rule would recolor
  // it red *if* the attribute leaked into selector matching.
  let html =
    #|<style>[data-crater-domid]{color:#ff0000}</style>
    #|<div data-crater-domid="7">hi</div>
  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let div = find_render_node_by_id(root, "div").unwrap()
  // The DomTree id reaches the render node...
  inspect(div.dom_id, content="Some(7)")
  // ...but the cascade never saw the attribute, so the rule did not match
  // (still the default color, not red).
  inspect(div.style.color.to_rgba_string() == "rgb(255, 0, 0)", content="false")
}

///|
test "dom_id is None on the static parse path (no internal attribute)" {
  let html = "<div>plain</div>"
  let root = @renderer.render_to_node(html, @renderer.RenderContext::default())
  let div = find_render_node_by_id(root, "div").unwrap()
  inspect(div.dom_id, content="None")
}
