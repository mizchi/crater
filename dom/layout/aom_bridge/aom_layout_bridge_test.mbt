///|
test "extract bounds from LayoutTree" {
  @layout.setup()
  // Create a simple layout tree manually
  let child = @layout.LayoutNode::new(
    "btn1",
    @style.Style::{
      ..@style.Style::default(),
      width: @types.Length(100.0),
      height: @types.Length(40.0),
    },
    [],
  )
  let root = @layout.LayoutNode::new(
    "container",
    @style.Style::{
      ..@style.Style::default(),
      width: @types.Length(800.0),
      height: @types.Length(600.0),
      display: @types.Flex,
      justify_content: @types.Center,
      align_items: @types.Center,
    },
    [child],
  )
  let layout_tree = @layout.LayoutTree::new(root, 800.0, 600.0)
  let _ = layout_tree.calculate_layout(800.0, 600.0)
  let bounds_map = extract_bounds_from_layout(layout_tree)
  match bounds_map.get("container") {
    Some(b) => {
      inspect(b.x, content="0")
      inspect(b.y, content="0")
      inspect(b.width, content="800")
      inspect(b.height, content="600")
    }
    None => panic()
  }
  match bounds_map.get("btn1") {
    Some(b) => {
      inspect(b.width, content="100")
      inspect(b.height, content="40")
      // Centered: x = (800 - 100) / 2 = 350
      inspect(b.x, content="350")
      // Centered: y = (600 - 40) / 2 = 280
      inspect(b.y, content="280")
    }
    None => panic()
  }
}

///|
test "build_accessibility_tree_with_layout - full integration" {
  @layout.setup()
  let html =
    #|<div id="nav">
    #|  <button id="btn">Menu</button>
    #|</div>
  let doc = @html.parse_document(html)
  let layout_tree = @layout_html_tree.layout_tree_from_html_document(
    doc, 800.0, 600.0,
  )
  let _ = layout_tree.calculate_layout(800.0, 600.0)
  let a11y_tree = build_accessibility_tree_with_layout(doc, layout_tree)
  match a11y_tree.find_by_source_id("btn") {
    Some(node) => {
      inspect(node.role, content="Button")
      debug_inspect(node.name, content="Some(\"Menu\")")
      inspect(node.bounds is Some(_), content="true")
    }
    None => panic()
  }
}
