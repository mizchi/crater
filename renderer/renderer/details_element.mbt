///|
// Details and summary element pruning helpers.

///|
fn clone_node_with_children(
  node : @node.Node,
  children : Array[@node.Node],
) -> @node.Node {
  @node.Node::with_uid_and_measure(
    node.id,
    node.uid,
    node.style,
    children,
    node.measure,
    node.text,
  )
}

///|
fn find_first_summary_path_in_node(node : @node.Node) -> Array[Int]? {
  if node_id_is_tag(node.id, "summary") {
    return Some([])
  }
  for i = 0; i < node.children.length(); i = i + 1 {
    match find_first_summary_path_in_node(node.children[i]) {
      Some(path) => {
        let prefixed : Array[Int] = [i]
        for segment in path {
          prefixed.push(segment)
        }
        return Some(prefixed)
      }
      None => ()
    }
  }
  None
}

///|
fn find_first_summary_path_in_children(
  children : Array[@node.Node],
) -> (Int, Array[Int])? {
  for i = 0; i < children.length(); i = i + 1 {
    match find_first_summary_path_in_node(children[i]) {
      Some(path) => return Some((i, path))
      None => ()
    }
  }
  None
}

///|
fn prune_node_to_summary_path(
  node : @node.Node,
  path : Array[Int],
) -> @node.Node {
  if path.length() == 0 {
    return node
  }
  let next_index = path[0]
  if next_index < 0 || next_index >= node.children.length() {
    return node
  }
  let remaining : Array[Int] = []
  for i = 1; i < path.length(); i = i + 1 {
    remaining.push(path[i])
  }
  let kept_child = prune_node_to_summary_path(
    node.children[next_index],
    remaining,
  )
  let kept_children : Array[@node.Node] = []
  for i = 0; i < next_index; i = i + 1 {
    let sibling = node.children[i]
    if sibling.id == "#text" {
      match sibling.text {
        Some(text) if !text.is_empty() && text.trim().is_empty() =>
          kept_children.push(sibling)
        _ => ()
      }
    }
  }
  kept_children.push(kept_child)
  clone_node_with_children(node, kept_children)
}

///|
fn prune_closed_details_children(
  children : Array[@node.Node],
) -> Array[@node.Node] {
  match find_first_summary_path_in_children(children) {
    Some((top_index, path)) => {
      let pruned_top = prune_node_to_summary_path(children[top_index], path)
      [pruned_top]
    }
    None => []
  }
}
