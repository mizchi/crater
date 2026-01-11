///|
test "find_in_region_top_right" {
  // Create a button in the top-right area
  let button = @aom.AccessibilityNode::new("btn-1", @aom.Button)
    .with_name("Login")
    .set_focusable(true)
  let button = {
    ..button,
    bounds: Some(@aom.Bounds::new(1100.0, 20.0, 100.0, 40.0)),
    ref_id: Some("ref_1"),
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, children: [button], visible: true }
  let tree = @aom.AccessibilityTree::new(root)
  let viewport = Viewport::default()
  let results = find_by_spatial(tree, InRegion(TopRight), viewport)
  inspect(results.length(), content="1")
  inspect(results[0].node.name, content="Some(\"Login\")")
}

///|
test "find_by_role_in_region" {
  // Create links in different regions
  let link1 = @aom.AccessibilityNode::new("link-1", @aom.Link)
    .with_name("Home")
    .set_focusable(true)
  let link1 = {
    ..link1,
    bounds: Some(@aom.Bounds::new(50.0, 20.0, 80.0, 30.0)), // Top left
    ref_id: Some("ref_1"),
    visible: true,
  }
  let link2 = @aom.AccessibilityNode::new("link-2", @aom.Link)
    .with_name("Contact")
    .set_focusable(true)
  let link2 = {
    ..link2,
    bounds: Some(@aom.Bounds::new(1100.0, 20.0, 80.0, 30.0)), // Top right
    ref_id: Some("ref_2"),
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, children: [link1, link2], visible: true }
  let tree = @aom.AccessibilityTree::new(root)
  let viewport = Viewport::default()

  // Find links in top-right
  let results = find_by_spatial(
    tree,
    RoleInRegion(@aom.Link, TopRight),
    viewport,
  )
  inspect(results.length(), content="1")
  inspect(results[0].node.name, content="Some(\"Contact\")")
}

///|
test "find_relative_below" {
  // Create a form and a button below it
  let form = @aom.AccessibilityNode::new("form-1", @aom.Form).with_name(
    "Login Form",
  )
  let form = {
    ..form,
    bounds: Some(@aom.Bounds::new(400.0, 200.0, 400.0, 200.0)),
    ref_id: Some("ref_1"),
    visible: true,
  }
  let submit = @aom.AccessibilityNode::new("btn-1", @aom.Button)
    .with_name("Submit")
    .set_focusable(true)
  let submit = {
    ..submit,
    bounds: Some(@aom.Bounds::new(500.0, 420.0, 100.0, 40.0)), // Below form
    ref_id: Some("ref_2"),
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, children: [form, submit], visible: true }
  let tree = @aom.AccessibilityTree::new(root)
  let viewport = Viewport::default()
  let results = find_by_spatial(tree, RelativeTo(Below, "ref_1"), viewport)
  inspect(results.length(), content="1")
  inspect(results[0].node.name, content="Some(\"Submit\")")
}

///|
test "get_click_coords" {
  let button = @aom.AccessibilityNode::new("btn-1", @aom.Button).with_name(
    "Click Me",
  )
  let button = {
    ..button,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 200.0, 50.0)),
    ref_id: Some("ref_1"),
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, children: [button], visible: true }
  let tree = @aom.AccessibilityTree::new(root)
  let coords = get_click_coords(tree, "ref_1")
  inspect(coords, content="Some((200, 125))")
}

///|
test "spatial_region_to_string" {
  inspect(SpatialRegion::TopLeft.to_string(), content="top-left")
  inspect(SpatialRegion::Center.to_string(), content="center")
  inspect(SpatialRegion::BottomRight.to_string(), content="bottom-right")
}

///|
test "grounding with html integration" {
  @dispatch.setup()
  // Simple HTML with buttons at different positions
  let html =
    #|<div id="container" style="width:800px;height:600px">
    #|  <button id="btn-top-left" style="position:absolute;left:50px;top:50px;width:100px;height:40px">Top Left</button>
    #|  <button id="btn-center" style="position:absolute;left:350px;top:280px;width:100px;height:40px">Center</button>
    #|  <button id="btn-bottom-right" style="position:absolute;left:650px;top:510px;width:100px;height:40px">Bottom Right</button>
    #|</div>
  // Parse and assign synthetic IDs
  let doc = @html.assign_synthetic_ids(@html.parse_document(html))
  // Build layout tree
  let layout_tree = @tree.LayoutTree::from_html_document(doc, 800.0, 600.0)
  let _ = layout_tree.calculate_layout(800.0, 600.0)
  // Build AOM with bounds
  let tree = @aom.build_accessibility_tree_with_layout(doc, layout_tree)
  // Check that buttons have bounds attached
  let interactive = @aom.find_interactive(tree)
  inspect(interactive.length(), content="3")
  // All buttons should have bounds
  let mut buttons_with_bounds = 0
  for node in interactive {
    if node.bounds is Some(_) {
      buttons_with_bounds += 1
    }
  }
  inspect(buttons_with_bounds, content="3")
}
