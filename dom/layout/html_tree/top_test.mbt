///|
test "layout html tree builds layout tree from html document" {
  let html =
    #|<div id="root"><span id="child">hi</span></div>
  let doc = @html.parse_document(html)
  let tree = layout_tree_from_html_document(doc, 320.0, 240.0)
  inspect(tree.root.children.length(), content="2")
  inspect(tree.find_node_by_id("span#child") is Some(_), content="true")
}

///|
test "layout html tree applies intrinsic img dimensions" {
  let html =
    #|<img id="hero" width="100" height="50" />
  let doc = @html.parse_document(html)
  let tree = layout_tree_from_html_document(doc, 320.0, 240.0)
  let img = match tree.find_node_by_id("img#hero") {
    Some(node) => node
    None => @tree.LayoutNode::create()
  }
  inspect(img.style.width, content="Length(100)")
  inspect(img.style.height, content="Length(50)")
}

///|
test "layout html tree preserves tag based ids and inline styles" {
  let html =
    #|<div id="root" style="width: 120px; height: 40px;"></div>
  let doc = @html.parse_document(html)
  let tree = layout_tree_from_html_document(doc, 320.0, 240.0)
  let root = match tree.find_node_by_id("div#root") {
    Some(node) => node
    None => @tree.LayoutNode::create()
  }
  inspect(root.style.width, content="Length(120)")
  inspect(root.style.height, content="Length(40)")
}

///|
fn find_layout_by_id(layout : @types.Layout, id : String) -> @types.Layout? {
  if layout.id == id {
    Some(layout)
  } else {
    let mut result : @types.Layout? = None
    for child in layout.children {
      match find_layout_by_id(child, id) {
        Some(found) => {
          result = Some(found)
          break
        }
        None => ()
      }
    }
    result
  }
}

///|
test "layout html tree transfers canvas intrinsic ratio from percent height in flex" {
  let html =
    #|<div id="target" style="display: inline-flex; height: 100px;"><div id="item"><canvas id="c" width="10" height="10" style="height: 100%;"></canvas></div></div>
  let doc = @html.parse_document(html)
  let tree = layout_tree_from_html_document(doc, 800.0, 600.0)
  let layout = tree.compute_full()
  let target = match find_layout_by_id(layout, "div#target") {
    Some(node) => node
    None =>
      @types.Layout::{
        id: "",
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        margin: @types.Rect::zero(),
        padding: @types.Rect::zero(),
        border: @types.Rect::zero(),
        overflow_x: @types.Visible,
        overflow_y: @types.Visible,
        scroll_width: 0.0,
        scroll_height: 0.0,
        children: [],
        text: None,
      }
  }
  let item = match find_layout_by_id(layout, "div#item") {
    Some(node) => node
    None => target
  }
  let canvas = match find_layout_by_id(layout, "canvas#c") {
    Some(node) => node
    None => target
  }
  inspect(target.width, content="100")
  inspect(target.height, content="100")
  inspect(item.width, content="100")
  inspect(item.height, content="100")
  inspect(canvas.width, content="100")
  inspect(canvas.height, content="100")
}
