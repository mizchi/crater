///|
test "no_difference" {
  let button = @aom.AccessibilityNode::new("btn-1", @aom.Button).with_name(
    "Click",
  )
  let button = {
    ..button,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 100.0, 40.0)),
    ref_id: Some("ref_1"),
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, children: [button], visible: true }
  let tree1 = @aom.AccessibilityTree::new(root)
  let tree2 = @aom.AccessibilityTree::new(root)
  let result = diff_trees(tree1, tree2, DiffConfig::default())
  inspect(result.differences.length(), content="0")
  inspect(result.similarity, content="1")
}

///|
test "element_added" {
  let button1 = @aom.AccessibilityNode::new("btn-1", @aom.Button).with_name(
    "Button 1",
  )
  let button1 = {
    ..button1,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 100.0, 40.0)),
    ref_id: Some("ref_1"),
    visible: true,
  }
  let root1 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root1 = { ..root1, children: [button1], visible: true }
  let button2 = @aom.AccessibilityNode::new("btn-2", @aom.Button).with_name(
    "Button 2",
  )
  let button2 = {
    ..button2,
    bounds: Some(@aom.Bounds::new(220.0, 100.0, 100.0, 40.0)),
    ref_id: Some("ref_2"),
    visible: true,
  }
  let root2 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root2 = { ..root2, children: [button1, button2], visible: true }
  let tree1 = @aom.AccessibilityTree::new(root1)
  let tree2 = @aom.AccessibilityTree::new(root2)
  let result = diff_trees(tree1, tree2, DiffConfig::default())
  inspect(result.added_count, content="1")
}

///|
test "element_moved" {
  let button_before = @aom.AccessibilityNode::new("btn-1", @aom.Button).with_name(
    "Click",
  )
  let button_before = {
    ..button_before,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 100.0, 40.0)),
    ref_id: Some("ref_1"),
    visible: true,
  }
  let button_after = @aom.AccessibilityNode::new("btn-1", @aom.Button).with_name(
    "Click",
  )
  let button_after = {
    ..button_after,
    bounds: Some(@aom.Bounds::new(200.0, 100.0, 100.0, 40.0)), // Moved 100px right
    ref_id: Some("ref_1"),
    visible: true,
  }
  let root1 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root1 = { ..root1, children: [button_before], visible: true }
  let root2 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root2 = { ..root2, children: [button_after], visible: true }
  let tree1 = @aom.AccessibilityTree::new(root1)
  let tree2 = @aom.AccessibilityTree::new(root2)
  let result = diff_trees(tree1, tree2, DiffConfig::default())
  inspect(result.changed_count, content="1")

  // Should detect as "Moved"
  let moved_diff = result.differences
    .iter()
    .find_first(fn(d) {
      match d.change_type {
        Moved => true
        _ => false
      }
    })
  assert_true(moved_diff.is_some())
}

///|
test "element_resized" {
  let button_before = @aom.AccessibilityNode::new("btn-1", @aom.Button).with_name(
    "Click",
  )
  let button_before = {
    ..button_before,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 100.0, 40.0)),
    ref_id: Some("ref_1"),
    visible: true,
  }
  let button_after = @aom.AccessibilityNode::new("btn-1", @aom.Button).with_name(
    "Click",
  )
  let button_after = {
    ..button_after,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 150.0, 50.0)), // Bigger
    ref_id: Some("ref_1"),
    visible: true,
  }
  let root1 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root1 = { ..root1, children: [button_before], visible: true }
  let root2 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root2 = { ..root2, children: [button_after], visible: true }
  let tree1 = @aom.AccessibilityTree::new(root1)
  let tree2 = @aom.AccessibilityTree::new(root2)
  let result = diff_trees(tree1, tree2, DiffConfig::default())

  // Should detect resize
  let resized_diff = result.differences
    .iter()
    .find_first(fn(d) {
      match d.change_type {
        Resized => true
        _ => false
      }
    })
  assert_true(resized_diff.is_some())
}

///|
test "json_output" {
  let root1 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root1 = { ..root1, visible: true }
  let root2 = @aom.AccessibilityNode::new("root", @aom.Document)
  let root2 = { ..root2, visible: true }
  let tree1 = @aom.AccessibilityTree::new(root1)
  let tree2 = @aom.AccessibilityTree::new(root2)
  let result = diff_trees(tree1, tree2, DiffConfig::default())
  let json = result.to_json()
  assert_true(json.contains("\"similarity\""))
  assert_true(json.contains("\"differences\""))
}

///|
test "trees_equal_helper" {
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, visible: true }
  let tree1 = @aom.AccessibilityTree::new(root)
  let tree2 = @aom.AccessibilityTree::new(root)
  inspect(trees_equal(tree1, tree2), content="true")
}
