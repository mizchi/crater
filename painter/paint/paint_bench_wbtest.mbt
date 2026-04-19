///|
/// Helper: create a deep Layout tree simulating MDN-like structure
fn make_deep_layout(
  depth : Int,
  breadth : Int,
  y_offset : Double,
) -> @types.Layout {
  if depth <= 0 {
    return {
      id: "#text",
      x: 0.0,
      y: y_offset,
      width: 100.0,
      height: 16.0,
      margin: @types.Rect::zero(),
      padding: @types.Rect::zero(),
      border: @types.Rect::zero(),
      overflow_x: @types.Visible,
      overflow_y: @types.Visible,
      scroll_width: 0.0,
      scroll_height: 0.0,
      children: [],
      text: Some("text"),
    }
  }
  let children : Array[@types.Layout] = []
  for i = 0; i < breadth; i = i + 1 {
    children.push(make_deep_layout(depth - 1, breadth, i.to_double() * 50.0))
  }
  {
    id: "div",
    x: 0.0,
    y: y_offset,
    width: 640.0,
    height: 200.0,
    margin: @types.Rect::zero(),
    padding: @types.Rect::zero(),
    border: @types.Rect::zero(),
    overflow_x: @types.Visible,
    overflow_y: @types.Visible,
    scroll_width: 0.0,
    scroll_height: 0.0,
    children,
    text: None,
  }
}

///|
/// Helper: create a matching Node tree for the Layout tree
fn make_deep_node(depth : Int, breadth : Int) -> @node.Node {
  if depth <= 0 {
    return @node.Node::leaf("#text", @style.Style::default())
  }
  let children : Array[@node.Node] = []
  for i = 0; i < breadth; i = i + 1 {
    children.push(make_deep_node(depth - 1, breadth))
  }
  @node.Node::new("div", @style.Style::default(), children)
}

///|
/// Count nodes in a Layout tree
fn count_layout_nodes(layout : @types.Layout) -> Int {
  let mut count = 1
  for child in layout.children {
    count = count + count_layout_nodes(child)
  }
  count
}

///|
/// Benchmark: viewport culling on a large tree (3280 nodes)
/// Before optimization: O(n²) due to calculate_layout_extent at every node
/// After optimization: O(n) with precomputed extent tree
test "bench/viewport_culling_large_tree" (b : @bench.T) {
  let layout = make_deep_layout(7, 3, 0.0)
  let node = make_deep_node(7, 3)
  let node_count = count_layout_nodes(layout)
  b.bench(name="paint_viewport_culling_\{node_count}", fn() {
    b.keep(from_node_and_layout_with_viewport(node, layout, 0.0, 400.0, 0.0))
  })
}

///|
/// Benchmark: stacking order sort with early exit for uniform z-index
test "bench/stacking_order_sort" (b : @bench.T) {
  let layout = make_deep_layout(7, 3, 0.0)
  let node = make_deep_node(7, 3)
  let paint = from_node_and_layout(node, layout)
  b.bench(name="paint_stacking_sort", fn() {
    b.keep(sort_tree_by_stacking_order(paint))
  })
}

///|
/// Benchmark: simulate scrolling through 50 positions on large tree
test "bench/scroll_simulation" (b : @bench.T) {
  let layout = make_deep_layout(7, 3, 0.0)
  let node = make_deep_node(7, 3)
  let scroll_positions : Array[Double] = []
  for i = 0; i < 50; i = i + 1 {
    scroll_positions.push(i.to_double() * 200.0)
  }
  b.bench(name="paint_scroll_sim_50", fn() {
    let mut last = None
    for scroll_y in scroll_positions {
      last = from_node_and_layout_with_viewport(
        node,
        layout,
        scroll_y,
        scroll_y + 400.0,
        0.0,
      )
    }
    b.keep(last)
  })
}
