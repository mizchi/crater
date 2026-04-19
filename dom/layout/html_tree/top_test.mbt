///|
test "layout html tree builds layout tree from html document" {
  let html =
    #|<div id="root"><span id="child">hi</span></div>
  let doc = @html.parse_document(html)
  let tree = layout_tree_from_html_document(doc, 320.0, 240.0)
  inspect(tree.root.children.length(), content="2")
  inspect(tree.find_node_by_id("child") is Some(_), content="true")
}

///|
test "layout html tree applies intrinsic img dimensions" {
  let html =
    #|<img id="hero" width="100" height="50" />
  let doc = @html.parse_document(html)
  let tree = layout_tree_from_html_document(doc, 320.0, 240.0)
  let img = match tree.find_node_by_id("hero") {
    Some(node) => node
    None => @tree.LayoutNode::create()
  }
  inspect(img.style.width, content="Length(100)")
  inspect(img.style.height, content="Length(50)")
}
