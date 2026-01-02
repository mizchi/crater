///|
/// E2E test: CSS string → Style → Layout computation

///|
/// Helper to create a node with CSS string
fn node_from_css(id : String, css : String) -> @node.Node {
  let style = @parser.parse_inline_style(css)
  @node.Node::leaf(id, style)
}

///|
/// Helper to create a node with CSS and children
fn node_from_css_with_children(
  id : String,
  css : String,
  children : Array[@node.Node],
) -> @node.Node {
  let style = @parser.parse_inline_style(css)
  @node.Node::new(id, style, children)
}

///|
/// Helper to create layout context
fn make_ctx(width : Double, height : Double) -> @node.LayoutContext {
  {
    available_width: width,
    available_height: Some(height),
    sizing_mode: Definite,
  }
}

///|
test "e2e: simple fixed size box" {
  let root = node_from_css("root", "width: 200px; height: 100px")
  let layout = @flex.compute(root, make_ctx(800.0, 600.0))
  inspect(layout.width, content="200")
  inspect(layout.height, content="100")
}

///|
test "e2e: flex container with children" {
  let child1 = node_from_css("c1", "width: 100px; height: 50px")
  let child2 = node_from_css("c2", "width: 100px; height: 50px")
  let container = node_from_css_with_children(
    "container",
    "display: flex; width: 300px; height: 100px",
    [child1, child2],
  )
  let layout = @flex.compute(container, make_ctx(800.0, 600.0))

  // Container size
  inspect(layout.width, content="300")
  inspect(layout.height, content="100")

  // Children should be laid out horizontally (row direction)
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].x, content="100")
}

///|
test "e2e: flex column direction" {
  let child1 = node_from_css("c1", "width: 100px; height: 50px")
  let child2 = node_from_css("c2", "width: 100px; height: 50px")
  let container = node_from_css_with_children(
    "container",
    "display: flex; flex-direction: column; width: 200px; height: 200px",
    [child1, child2],
  )
  let layout = @flex.compute(container, make_ctx(800.0, 600.0))

  // Children should be laid out vertically
  inspect(layout.children[0].y, content="0")
  inspect(layout.children[1].y, content="50")
}

///|
test "e2e: flex justify-content center" {
  let child = node_from_css("c1", "width: 100px; height: 50px")
  let container = node_from_css_with_children(
    "container",
    "display: flex; justify-content: center; width: 300px; height: 100px",
    [child],
  )
  let layout = @flex.compute(container, make_ctx(800.0, 600.0))

  // Child should be centered: (300 - 100) / 2 = 100
  inspect(layout.children[0].x, content="100")
}

///|
test "e2e: flex-grow distribution" {
  let child1 = node_from_css("c1", "flex-grow: 1; height: 50px")
  let child2 = node_from_css("c2", "flex-grow: 2; height: 50px")
  let container = node_from_css_with_children(
    "container",
    "display: flex; width: 300px; height: 100px",
    [child1, child2],
  )
  let layout = @flex.compute(container, make_ctx(800.0, 600.0))

  // flex-grow 1:2 ratio, so 100px : 200px
  inspect(layout.children[0].width, content="100")
  inspect(layout.children[1].width, content="200")
}

///|
test "e2e: margin and padding" {
  let child = node_from_css("c1", "width: 100px; height: 50px")
  let container = node_from_css_with_children(
    "container",
    "display: flex; width: 300px; height: 100px; padding: 10px",
    [child],
  )
  let layout = @flex.compute(container, make_ctx(800.0, 600.0))

  // Child should start after padding
  inspect(layout.children[0].x, content="10")
  inspect(layout.children[0].y, content="10")
}

///|
test "e2e: gap between flex items" {
  let child1 = node_from_css("c1", "width: 100px; height: 50px")
  let child2 = node_from_css("c2", "width: 100px; height: 50px")
  let container = node_from_css_with_children(
    "container",
    "display: flex; width: 300px; height: 100px; gap: 20px",
    [child1, child2],
  )
  let layout = @flex.compute(container, make_ctx(800.0, 600.0))

  // Second child should have gap
  inspect(layout.children[0].x, content="0")
  inspect(layout.children[1].x, content="120") // 100 + 20 gap
}

///|
test "e2e: nested flex containers" {
  let inner_child1 = node_from_css("ic1", "width: 40px; height: 40px")
  let inner_child2 = node_from_css("ic2", "width: 40px; height: 40px")
  let inner = node_from_css_with_children(
    "inner",
    "display: flex; flex-direction: column",
    [inner_child1, inner_child2],
  )
  let outer_child = node_from_css("oc1", "width: 100px; height: 100px")
  let outer = node_from_css_with_children(
    "outer",
    "display: flex; width: 300px; height: 150px",
    [inner, outer_child],
  )
  let layout = @flex.compute(outer, make_ctx(800.0, 600.0))

  // Inner container children should be vertical
  let inner_layout = layout.children[0]
  inspect(inner_layout.children[0].y, content="0")
  inspect(inner_layout.children[1].y, content="40")

  // Outer layout
  inspect(inner_layout.x, content="0")
  inspect(layout.children[1].x, content="40") // inner width is 40 (from children)
}
