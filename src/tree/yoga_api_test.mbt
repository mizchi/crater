///|
/// Tests for Yoga-compatible API

///|
fn setup_dispatch() -> Unit {
  @dispatch.setup()
}

///|
test "yoga_api/basic_usage" {
  setup_dispatch()
  // Create nodes using Yoga-like factory
  let root = @tree.LayoutNode::create_with_id("root")
  let child1 = @tree.LayoutNode::create_with_id("child1")
  let child2 = @tree.LayoutNode::create_with_id("child2")

  // Configure root with method chaining
  let _ = root
    .set_display(@style.Flex)
    .set_flex_direction(@style.Row)
    .set_width(400.0)
    .set_height(200.0)
    .set_padding(10.0)

  // Configure children
  let _ = child1.set_width(100.0).set_height(50.0).set_margin(5.0)
  let _ = child2.set_flex_grow(1.0).set_height(50.0).set_margin(5.0)

  // Add children
  let _ = root.add_child(child1).add_child(child2)

  // Create tree and calculate layout
  let tree = @tree.LayoutTree::new(root, 400.0, 200.0)
  let _ = tree.calculate_layout(400.0, 200.0)

  // Read layout results
  inspect(root.get_layout_width(), content="400")
  inspect(root.get_layout_height(), content="200")
  inspect(child1.get_layout_x() > 0.0, content="true") // Has margin + padding
  inspect(child1.get_layout_width(), content="100")
}

///|
test "yoga_api/auto_dirty_on_style_change" {
  setup_dispatch()
  let node = @tree.LayoutNode::create()
  let _ = node.set_width(100.0)

  // Node starts dirty
  inspect(node.is_dirty(), content="true")

  // Create tree and compute layout
  let tree = @tree.LayoutTree::new(node, 800.0, 600.0)
  let _ = tree.calculate_layout(800.0, 600.0)

  // After layout, dirty should be cleared
  inspect(node.is_dirty(), content="false")

  // Changing style should mark dirty
  let _ = node.set_width(200.0)
  inspect(node.is_dirty(), content="true")
}

///|
test "yoga_api/no_dirty_on_same_value" {
  setup_dispatch()
  let node = @tree.LayoutNode::create()
  let _ = node.set_width(100.0)
  let tree = @tree.LayoutTree::new(node, 800.0, 600.0)
  let _ = tree.calculate_layout(800.0, 600.0)
  inspect(node.is_dirty(), content="false")

  // Setting same value should NOT mark dirty
  let _ = node.set_width(100.0)
  inspect(node.is_dirty(), content="false")

  // Setting different value SHOULD mark dirty
  let _ = node.set_width(101.0)
  inspect(node.is_dirty(), content="true")
}

///|
test "yoga_api/child_manipulation" {
  setup_dispatch()
  let parent = @tree.LayoutNode::create_with_id("parent")
  let child1 = @tree.LayoutNode::create_with_id("child1")
  let child2 = @tree.LayoutNode::create_with_id("child2")
  let child3 = @tree.LayoutNode::create_with_id("child3")

  // Add children
  let _ = parent.add_child(child1)
  inspect(parent.get_child_count(), content="1")
  let _ = parent.add_child(child2)
  inspect(parent.get_child_count(), content="2")

  // Insert at specific index
  let _ = parent.insert_child(child3, 1)
  inspect(parent.get_child_count(), content="3")

  // Verify order
  match parent.get_child(0) {
    Some(c) => inspect(c.id, content="child1")
    None => panic()
  }
  match parent.get_child(1) {
    Some(c) => inspect(c.id, content="child3")
    None => panic()
  }
  match parent.get_child(2) {
    Some(c) => inspect(c.id, content="child2")
    None => panic()
  }

  // Remove child
  let _ = parent.remove_child_at(1)
  inspect(parent.get_child_count(), content="2")
}

///|
test "yoga_api/has_new_layout" {
  setup_dispatch()
  let root = @tree.LayoutNode::create()
  let child = @tree.LayoutNode::create()
  let _ = root.set_width(100.0).set_height(100.0)
  let _ = child.set_width(50.0).set_height(50.0)
  let _ = root.add_child(child)
  let tree = @tree.LayoutTree::new(root, 800.0, 600.0)

  // Before layout, has_new_layout is false
  inspect(root.get_has_new_layout(), content="false")

  // After layout, has_new_layout is true
  let _ = tree.calculate_layout(800.0, 600.0)
  inspect(root.get_has_new_layout(), content="true")
  inspect(child.get_has_new_layout(), content="true")

  // Mark as seen
  root.mark_layout_seen()
  inspect(root.get_has_new_layout(), content="false")
}

///|
test "yoga_api/flex_layout" {
  setup_dispatch()
  let container = @tree.LayoutNode::create()
  let item1 = @tree.LayoutNode::create()
  let item2 = @tree.LayoutNode::create()
  let item3 = @tree.LayoutNode::create()

  // Setup flex container
  let _ = container
    .set_display(@style.Flex)
    .set_flex_direction(@style.Row)
    .set_width(300.0)
    .set_height(100.0)

  // Setup flex items with different grow values
  let _ = item1.set_flex_grow(1.0).set_height(50.0)
  let _ = item2.set_flex_grow(2.0).set_height(50.0)
  let _ = item3.set_width(50.0).set_height(50.0) // Fixed width
  let _ = container.add_child(item1).add_child(item2).add_child(item3)
  let tree = @tree.LayoutTree::new(container, 300.0, 100.0)
  let _ = tree.calculate_layout(300.0, 100.0)

  // item3 should be 50px, remaining 250px split 1:2 between item1 and item2
  let remaining = 300.0 - 50.0 // 250px
  let expected_item1 = remaining / 3.0 // ~83.33
  let expected_item2 = remaining * 2.0 / 3.0 // ~166.67
  inspect(
    (item1.get_layout_width() - expected_item1).abs() < 0.1,
    content="true",
  )
  inspect(
    (item2.get_layout_width() - expected_item2).abs() < 0.1,
    content="true",
  )
  inspect(item3.get_layout_width(), content="50")
}

///|
test "yoga_api/incremental_layout" {
  setup_dispatch()
  let root = @tree.LayoutNode::create()
  let child = @tree.LayoutNode::create()
  let _ = root.set_display(@style.Flex).set_width(200.0).set_height(200.0)
  let _ = child.set_width(100.0).set_height(100.0)
  let _ = root.add_child(child)
  let tree = @tree.LayoutTree::new(root, 200.0, 200.0)

  // First layout
  let _ = tree.calculate_layout(200.0, 200.0)
  let first_width = child.get_layout_width()
  inspect(first_width, content="100")

  // Modify child - use tree.mark_node_dirty to propagate to ancestors
  let _ = child.set_width(150.0)
  tree.mark_node_dirty(child.uid) // Propagate dirty up the tree
  let _ = tree.calculate_layout(200.0, 200.0)
  let second_width = child.get_layout_width()
  inspect(second_width, content="150")
}

///|
test "yoga_api/alignment" {
  setup_dispatch()
  let container = @tree.LayoutNode::create()
  let item = @tree.LayoutNode::create()
  let _ = container
    .set_display(@style.Flex)
    .set_width(200.0)
    .set_height(200.0)
    .set_justify_content(@style.Center)
    .set_align_items(@style.Center)
  let _ = item.set_width(50.0).set_height(50.0)
  let _ = container.add_child(item)
  let tree = @tree.LayoutTree::new(container, 200.0, 200.0)
  let _ = tree.calculate_layout(200.0, 200.0)

  // Item should be centered (200-50)/2 = 75
  inspect((item.get_layout_x() - 75.0).abs() < 0.1, content="true")
  inspect((item.get_layout_y() - 75.0).abs() < 0.1, content="true")
}

///|
test "yoga_api/gap" {
  setup_dispatch()
  let container = @tree.LayoutNode::create()
  let item1 = @tree.LayoutNode::create()
  let item2 = @tree.LayoutNode::create()
  let _ = container
    .set_display(@style.Flex)
    .set_flex_direction(@style.Row)
    .set_width(200.0)
    .set_height(50.0)
    .set_gap(10.0)
  let _ = item1.set_width(50.0).set_height(50.0)
  let _ = item2.set_width(50.0).set_height(50.0)
  let _ = container.add_child(item1).add_child(item2)
  let tree = @tree.LayoutTree::new(container, 200.0, 50.0)
  let _ = tree.calculate_layout(200.0, 50.0)

  // item1 at x=0, item2 at x=50+10(gap)=60
  inspect(item1.get_layout_x(), content="0")
  inspect(item2.get_layout_x(), content="60")
}
