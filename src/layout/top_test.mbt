///|
fn sized_node(
  display : @types.Display,
  width : Double,
  height : Double,
  children? : Array[Node] = [],
) -> Node {
  let style = Style::default()
  style.display = display
  style.width = @types.Length(width)
  style.height = @types.Length(height)
  Node::new("node", style, children)
}

///|
test "layout package compute_layout handles block nodes" {
  let node = sized_node(@types.Block, 120.0, 40.0)
  let layout = compute_layout(node, size(320.0, 240.0))
  inspect(layout.width, content="120")
  inspect(layout.height, content="40")
}

///|
test "layout package compute_flex_layout handles flex containers" {
  let child = sized_node(@types.Block, 40.0, 20.0)
  let style = Style::default()
  style.display = @types.Flex
  style.width = @types.Length(120.0)
  style.height = @types.Length(40.0)
  let node = Node::new("node", style, [child])
  let ctx : @types.LayoutContext = {
    available_width: 120.0,
    available_height: Some(40.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 120.0,
    viewport_height: 40.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = compute_flex_layout(node, ctx)
  inspect(layout.children.length(), content="1")
}

///|
fn compat_dispatch() -> DispatchFn {
  DispatchFn(fn(node, ctx, dispatch) {
    match node.style.display {
      @types.Flex | @types.InlineFlex =>
        compute_flex_layout_with_dispatch(node, ctx, dispatch)
      @types.Grid | @types.InlineGrid =>
        compute_grid_layout_in_context(node, ctx, dispatch)
      _ => compute_block_layout_with_dispatch(node, ctx, dispatch)
    }
  })
}

///|
test "layout package compute_grid_layout handles grid containers" {
  let child = sized_node(@types.Block, 40.0, 20.0)
  let style = Style::default()
  style.display = @types.Grid
  style.width = @types.Length(120.0)
  style.height = @types.Length(40.0)
  style.grid_template_columns = [@types.TrackSizingFunction::Fr(1.0)]
  style.grid_template_rows = [@types.TrackSizingFunction::Fr(1.0)]
  let node = Node::new("node", style, [child])
  let layout = compute_grid_layout(node, 120.0, 40.0)
  inspect(layout.width, content="120")
  inspect(layout.height, content="40")
  inspect(layout.children.length(), content="1")
}

///|
test "layout package dispatch-aware wrappers support custom routing" {
  let child = sized_node(@types.Block, 40.0, 20.0)
  let style = Style::default()
  style.display = @types.Flex
  style.width = @types.Length(120.0)
  style.height = @types.Length(40.0)
  let node = Node::new("node", style, [child])
  let ctx : @types.LayoutContext = {
    available_width: 120.0,
    available_height: Some(40.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 120.0,
    viewport_height: 40.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = compute_flex_layout_with_dispatch(node, ctx, compat_dispatch())
  inspect(layout.children.length(), content="1")
}

///|
test "layout package compute_layout_in_context handles explicit context" {
  let node = sized_node(@types.Block, 64.0, 24.0)
  let ctx : @types.LayoutContext = {
    available_width: 200.0,
    available_height: Some(100.0),
    sizing_mode: @types.MaxContent,
    viewport_width: 200.0,
    viewport_height: 100.0,
    stretch_width: false,
    stretch_height: false,
  }
  let layout = compute_layout_in_context(node, ctx)
  inspect(layout.width, content="64")
  inspect(layout.height, content="24")
}

///|
test "layout package layout_tree_from_node preserves id lookup" {
  let child_style = Style::default()
  child_style.display = @types.Block
  child_style.width = @types.Length(40.0)
  child_style.height = @types.Length(20.0)
  let child = Node::new("child", child_style, [])
  let root_style = Style::default()
  root_style.display = @types.Block
  root_style.width = @types.Length(120.0)
  root_style.height = @types.Length(80.0)
  let root = Node::new("root", root_style, [child])
  let tree = layout_tree_from_node(root, 320.0, 240.0)
  inspect(tree.find_node_by_id("child") is Some(_), content="true")
}
