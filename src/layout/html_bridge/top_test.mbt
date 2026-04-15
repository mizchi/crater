///|
test "layout html bridge builds layout tree from html document" {
  let html =
    #|<div id="root"><span id="child">hi</span></div>
  let doc = @html.parse_document(html)
  let tree = layout_tree_from_html_document(doc, 320.0, 240.0)
  inspect(tree.root.children.length(), content="2")
  inspect(tree.find_node_by_id("child") is Some(_), content="true")
}
