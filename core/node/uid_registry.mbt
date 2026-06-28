///|
/// Stable uid assignment for incremental reflow.
///
/// `LayoutTree` keys its per-node layout cache by `Node.uid`, but the dynamic-
/// rendering path rebuilds the render node tree from scratch on every DOM
/// mutation, so a plain `next_uid()` would hand every node a fresh uid and the
/// cache would never match (see docs/incremental-reflow-design.md). A
/// `UidRegistry` persists across rebuilds and maps a node's stable identity to a
/// stable uid:
///
/// - elements carry their originating DomTree node id (`Node.dom_id`, phase A),
///   so they key on that and survive moves / re-renders;
/// - anonymous / text boxes (no `dom_id`) key on their owning node's stable uid
///   plus their child index, which is stable as long as the surrounding
///   structure is.
///
/// uids are allocated from the registry's own monotonic counter, so they are
/// unique within the registry (and therefore within any one `LayoutTree` built
/// from a stabilized tree).
pub struct UidRegistry {
  dom_to_uid : Map[Int, Int]
  anon_to_uid : Map[String, Int]
  mut next : Int
}

///|
pub fn UidRegistry::new() -> UidRegistry {
  { dom_to_uid: {}, anon_to_uid: {}, next: 0 }
}

///|
fn UidRegistry::alloc(self : UidRegistry) -> Int {
  let uid = self.next
  self.next = uid + 1
  uid
}

///|
/// The stable uid for an element with DomTree node id `dom_id`.
fn UidRegistry::for_dom(self : UidRegistry, dom_id : Int) -> Int {
  match self.dom_to_uid.get(dom_id) {
    Some(uid) => uid
    None => {
      let uid = self.alloc()
      self.dom_to_uid[dom_id] = uid
      uid
    }
  }
}

///|
/// The stable uid for an anonymous / text node, keyed by its parent's stable uid
/// and its position among siblings.
fn UidRegistry::for_anon(
  self : UidRegistry,
  parent_uid : Int,
  index : Int,
) -> Int {
  let key = parent_uid.to_string() + ":" + index.to_string()
  match self.anon_to_uid.get(key) {
    Some(uid) => uid
    None => {
      let uid = self.alloc()
      self.anon_to_uid[key] = uid
      uid
    }
  }
}

///|
fn stabilize_walk(
  node : Node,
  registry : UidRegistry,
  parent_uid : Int,
  index : Int,
) -> Unit {
  let uid = match node.dom_id {
    Some(dom_id) => registry.for_dom(dom_id)
    None => registry.for_anon(parent_uid, index)
  }
  node.set_uid(uid)
  for i, child in node.children {
    stabilize_walk(child, registry, uid, i)
  }
}

///|
/// Rewrite every uid in `root` to its stable value from `registry`, in place.
/// Call this on a freshly built render node tree before handing it to
/// `LayoutTree::from_node` / `reconcile_from`: nodes that map to the same DomTree
/// element (or the same anonymous slot) keep their uid across rebuilds, so the
/// incremental layout cache matches.
pub fn stabilize_uids(root : Node, registry : UidRegistry) -> Unit {
  stabilize_walk(root, registry, -1, 0)
}
