///|
/// Tests for incremental layout

///|
/// Helper to compare layouts approximately
fn layouts_equal(a : @node.Layout, b : @node.Layout) -> Bool {
  let pos_eq = (a.x - b.x).abs() < 0.001 &&
    (a.y - b.y).abs() < 0.001 &&
    (a.width - b.width).abs() < 0.001 &&
    (a.height - b.height).abs() < 0.001
  if not(pos_eq) {
    return false
  }
  if a.children.length() != b.children.length() {
    return false
  }
  for i = 0; i < a.children.length(); i = i + 1 {
    if not(layouts_equal(a.children[i], b.children[i])) {
      return false
    }
  }
  true
}

///|
/// Create a simple flex container for testing
fn create_test_tree() -> LayoutNode {
  let child1 = LayoutNode::leaf("child1", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let child2 = LayoutNode::leaf("child2", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [child1, child2],
  )
  root
}

///|
test "full and incremental layout produce same results" {
  // Setup dispatcher
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First layout (full)
  let layout1 = tree.compute_full()

  // Mark dirty and recompute incrementally
  tree.mark_node_dirty(tree.root.uid)
  let layout2 = tree.compute_incremental()

  // Results should be identical
  assert_true(layouts_equal(layout1, layout2))
}

///|
test "cached layout returned when not dirty" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let layout1 = tree.compute_incremental()

  // Second compute without marking dirty - should return cached
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))

  // Verify cache was used (no dirty flags)
  assert_false(tree.root.dirty)
  assert_false(tree.root.children_dirty)
}

///|
test "dirty propagation to ancestors" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Get child uid
  let child = tree.root.children[0]
  let child_uid = child.uid

  // Mark child dirty
  tree.mark_node_dirty(child_uid)

  // Child should be dirty
  assert_true(child.dirty)

  // Root should have children_dirty
  assert_true(tree.root.children_dirty)
}

///|
test "viewport resize with fixed nodes does not trigger relayout" {
  @dispatch.setup()
  // Fixed size nodes (Length) don't depend on viewport
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Initial layout
  let _ = tree.compute_incremental()

  // Resize viewport - fixed nodes should NOT need relayout
  tree.resize_viewport(1024.0, 768.0)

  // Fixed size nodes don't need layout on viewport change
  assert_false(tree.needs_layout())
}

///|
test "viewport resize with percent nodes triggers relayout" {
  @dispatch.setup()
  // Create tree with percentage-based width
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Percent(0.5), // 50% of parent
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Percent(1.0), // 100% of viewport
      height: @types.Length(200.0),
    },
    [child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Initial layout
  let _ = tree.compute_incremental()

  // Resize viewport - percent nodes SHOULD need relayout
  tree.resize_viewport(1024.0, 768.0)

  // Percent-based nodes need layout on viewport width change
  assert_true(tree.needs_layout())

  // Compute and verify
  let layout = tree.compute_incremental()
  assert_true(layout.width > 0.0)
}

///|
test "multiple dirty marks coalesce" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Initial layout
  let layout1 = tree.compute_incremental()

  // Mark multiple nodes dirty
  for child in tree.root.children {
    tree.mark_node_dirty(child.uid)
  }
  tree.mark_node_dirty(tree.root.uid)

  // Single recompute should handle all
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))
}

///|
test "cache stats show hits on unchanged nodes" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)
  let stats = CacheStats::new()

  // First compute - all misses
  let layout1 = tree.compute_with_stats(stats)
  let first_misses = stats.cache_misses
  assert_true(first_misses > 0)

  // Reset stats
  let stats2 = CacheStats::new()

  // Second compute without changes - should hit cache
  let layout2 = tree.compute_with_stats(stats2)
  assert_true(layouts_equal(layout1, layout2))
  assert_true(stats2.cache_hits > 0)
}

///|
test "partial dirty only recomputes affected subtree" {
  @dispatch.setup()

  // Create deeper tree
  let leaf1 = LayoutNode::leaf("leaf1", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let leaf2 = LayoutNode::leaf("leaf2", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(50.0),
    height: @types.Length(50.0),
  })
  let child1 = LayoutNode::new(
    "child1",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [leaf1],
  )
  let child2 = LayoutNode::new(
    "child2",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(100.0),
      height: @types.Length(100.0),
    },
    [leaf2],
  )
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [child1, child2],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let stats1 = CacheStats::new()
  let _ = tree.compute_with_stats(stats1)

  // Mark only one leaf dirty
  tree.mark_node_dirty(leaf1.uid)

  // Second compute - should have some cache hits
  let stats2 = CacheStats::new()
  let _ = tree.compute_with_stats(stats2)

  // Should compute fewer nodes due to caching
  // (Note: due to parent-child dependencies, may still recompute parents)
  inspect(stats2.cache_hits, content="1")
  inspect(stats2.cache_misses > 0, content="true")
}

///|
test "child caches are synced after computation" {
  @dispatch.setup()

  // Create tree with children
  let child1 = LayoutNode::leaf("child1", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let child2 = LayoutNode::leaf("child2", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [child1, child2],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Initially no caches
  assert_true(child1.cached_layout is None)
  assert_true(child2.cached_layout is None)

  // Compute layout
  let stats = CacheStats::new()
  let _ = tree.compute_with_stats(stats)

  // Children should now have cached layouts
  assert_true(child1.cached_layout is Some(_))
  assert_true(child2.cached_layout is Some(_))

  // Verify cache contains correct dimensions
  match child1.cached_layout {
    Some(cache) => {
      assert_true(cache.result.width > 0.0)
      assert_true(cache.result.height > 0.0)
    }
    None => assert_true(false) // Should not happen
  }
}

///|
test "unchanged children use cache on recompute" {
  @dispatch.setup()
  let child1 = LayoutNode::leaf("child1", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let child2 = LayoutNode::leaf("child2", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [child1, child2],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute - populates caches
  let stats1 = CacheStats::new()
  let layout1 = tree.compute_with_stats(stats1)

  // Second compute without changes
  let stats2 = CacheStats::new()
  let layout2 = tree.compute_with_stats(stats2)

  // Should have cache hit for root (and children don't trigger additional misses)
  assert_true(stats2.cache_hits >= 1)
  assert_true(layouts_equal(layout1, layout2))
}

///|
test "constraint change invalidates cache for percent nodes" {
  @dispatch.setup()
  // Use percent-based nodes that depend on viewport
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Percent(0.5),
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Percent(1.0), // Depends on viewport
      height: @types.Length(200.0),
    },
    [child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let stats1 = CacheStats::new()
  let _ = tree.compute_with_stats(stats1)

  // Change viewport (changes constraint)
  tree.resize_viewport(1024.0, 768.0)

  // Second compute - constraint changed, should miss
  let stats2 = CacheStats::new()
  let _ = tree.compute_with_stats(stats2)

  // Root should miss due to constraint change
  assert_true(stats2.cache_misses > 0)
}

///|
test "from_node creates correct tree structure" {
  @dispatch.setup()

  // Create Node (immutable)
  let node_child = @node.Node::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let node_root = @node.Node::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [node_child],
  )

  // Create LayoutTree from Node
  let tree = LayoutTree::from_node(node_root, 800.0, 600.0)

  // Verify structure
  assert_eq(tree.root.id, "root")
  assert_eq(tree.root.children.length(), 1)
  assert_eq(tree.root.children[0].id, "child")

  // Compute layout
  let layout = tree.compute_incremental()
  assert_true(layout.width > 0.0)
}

///|
test "uid preserved in to_node conversion" {
  @dispatch.setup()

  // Create LayoutNode with specific structure
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [child],
  )

  // Convert to Node and verify uid is preserved
  let node = root.to_node()
  assert_eq(node.uid, root.uid)
  assert_eq(node.children[0].uid, child.uid)
}

///|
test "root level cache hit on unchanged tree" {
  @dispatch.setup()

  // Create simple tree
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute - cache miss
  let stats1 = CacheStats::new()
  let layout1 = tree.compute_with_stats(stats1)

  // Second compute - root should hit cache
  let stats2 = CacheStats::new()
  let layout2 = tree.compute_with_stats(stats2)

  // Results should be identical
  assert_true(layouts_equal(layout1, layout2))

  // Root cache hit
  assert_true(stats2.cache_hits >= 1)
}

///|
test "dirty root forces recomputation" {
  @dispatch.setup()
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let stats1 = CacheStats::new()
  let _ = tree.compute_with_stats(stats1)

  // Mark root dirty
  tree.mark_node_dirty(root.uid)

  // Second compute - must recompute
  let stats2 = CacheStats::new()
  let _ = tree.compute_with_stats(stats2)

  // Should have cache miss for root
  assert_true(stats2.cache_misses >= 1)
}
