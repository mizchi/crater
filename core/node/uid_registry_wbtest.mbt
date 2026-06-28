///|
/// Stable-uid assignment for incremental reflow: a rebuilt node tree must keep
/// each node's uid stable across re-renders so the layout cache matches.

///|
fn tagged_node(id : String, dom_id : Int, children : Array[Node]) -> Node {
  let n = Node::new(id, @style.Style::default(), children)
  n.set_dom_id(Some(dom_id))
  n
}

///|
test "stabilize_uids: matching dom_ids keep the same uid across rebuilds" {
  let reg = UidRegistry::new()
  let t1 = tagged_node("root", 10, [
    tagged_node("a", 11, []),
    tagged_node("b", 12, []),
  ])
  stabilize_uids(t1, reg)
  let u_root = t1.uid
  let u_a = t1.children[0].uid
  let u_b = t1.children[1].uid
  // Distinct uids within one tree.
  inspect(u_root != u_a && u_a != u_b && u_root != u_b, content="true")
  // Re-render: fresh node objects, same dom_ids, plus a newly appended child.
  let t2 = tagged_node("root", 10, [
    tagged_node("a", 11, []),
    tagged_node("b", 12, []),
    tagged_node("c", 13, []),
  ])
  stabilize_uids(t2, reg)
  // Same dom_ids -> same uids.
  inspect(t2.uid == u_root, content="true")
  inspect(t2.children[0].uid == u_a, content="true")
  inspect(t2.children[1].uid == u_b, content="true")
  // New dom_id -> a fresh, distinct uid.
  let u_c = t2.children[2].uid
  inspect(u_c != u_root && u_c != u_a && u_c != u_b, content="true")
}

///|
test "stabilize_uids: anonymous nodes are keyed by position under their parent" {
  let reg = UidRegistry::new()
  let root = tagged_node("root", 1, [
    Node::new("text1", @style.Style::default(), []),
    Node::new("text2", @style.Style::default(), []),
  ])
  stabilize_uids(root, reg)
  let u0 = root.children[0].uid
  let u1 = root.children[1].uid
  inspect(u0 != u1, content="true")
  // Re-render with fresh anonymous nodes in the same positions under dom 1.
  let root2 = tagged_node("root", 1, [
    Node::new("text1b", @style.Style::default(), []),
    Node::new("text2b", @style.Style::default(), []),
  ])
  stabilize_uids(root2, reg)
  inspect(root2.children[0].uid == u0, content="true")
  inspect(root2.children[1].uid == u1, content="true")
}
