///|
test "layout style bridge applies cascaded values to node" {
  let node = @tree.LayoutNode::create_with_id("box")
  let values = @css.cascade_declarations([
    @css.Declaration::new("width", "100px"),
    @css.Declaration::new("display", "flex"),
    @css.Declaration::new("gap", "12px"),
  ])
  inspect(apply_css_values(node, values), content="true")
  inspect(node.style.width, content="Length(100)")
  inspect(node.style.display, content="Flex")
  inspect(node.style.row_gap, content="Length(12)")
}

///|
test "layout style bridge updates tree nodes by id" {
  let root = @tree.LayoutNode::create_with_id("root")
  let child = @tree.LayoutNode::create_with_id("child")
  let root = root.add_child(child)
  let tree = @tree.LayoutTree::new(root, 320.0, 240.0)
  let values = @css.cascade_declarations([
    @css.Declaration::new("height", "40px"),
  ])
  inspect(update_node_style(tree, "child", values), content="true")
  let updated_child = match tree.find_node_by_id("child") {
    Some(node) => node
    None => @tree.LayoutNode::create()
  }
  inspect(updated_child.style.height, content="Length(40)")
}

///|
test "layout style bridge adds and removes subtree nodes" {
  let root = @tree.LayoutNode::create_with_id("root")
  let tree = @tree.LayoutTree::new(root, 320.0, 240.0)
  let child = @tree.LayoutNode::create_with_id("child")
  inspect(add_node(tree, "root", 0, child), content="true")
  inspect(tree.find_node_by_id("child") is Some(_), content="true")
  inspect(remove_node(tree, "child"), content="true")
  inspect(tree.find_node_by_id("child") is Some(_), content="false")
}
