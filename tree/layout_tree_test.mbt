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

// =============================================================================
// Edge Case Tests for Cache Integrity
// =============================================================================

///|
test "edge: rapid dirty/compute cycles" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Get reference layout
  let ref_layout = tree.compute_full()

  // Rapid cycle: dirty -> compute -> dirty -> compute
  for i = 0; i < 100; i = i + 1 {
    tree.mark_node_dirty(tree.root.uid)
    let layout = tree.compute_incremental()
    // Every iteration should produce correct layout
    assert_true(layouts_equal(ref_layout, layout))
  }
}

///|
test "edge: same node marked dirty multiple times" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Get reference layout
  let ref_layout = tree.compute_full()

  // Mark same node dirty 10 times before computing
  for i = 0; i < 10; i = i + 1 {
    tree.mark_node_dirty(tree.root.uid)
  }

  // Should still produce correct result
  let layout = tree.compute_incremental()
  assert_true(layouts_equal(ref_layout, layout))
}

///|
test "edge: parent and child both dirty" {
  @dispatch.setup()
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let parent = LayoutNode::new(
    "parent",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(200.0),
      height: @types.Length(100.0),
    },
    [child],
  )
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [parent],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Get reference layout
  let ref_layout = tree.compute_full()

  // Mark BOTH parent and child dirty (unusual but valid)
  tree.mark_node_dirty(parent.uid)
  tree.mark_node_dirty(child.uid)

  // Should handle gracefully
  let layout = tree.compute_incremental()
  assert_true(layouts_equal(ref_layout, layout))
}

///|
test "edge: all children dirty but parent clean" {
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

  // First compute
  let ref_layout = tree.compute_full()

  // Mark all children dirty, but NOT root
  tree.mark_node_dirty(child1.uid)
  tree.mark_node_dirty(child2.uid)

  // Root should have children_dirty set
  assert_true(tree.root.children_dirty)
  assert_false(tree.root.dirty)

  // Compute should still be correct
  let layout = tree.compute_incremental()
  assert_true(layouts_equal(ref_layout, layout))
}

///|
test "edge: viewport resize during dirty state" {
  @dispatch.setup()
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
      width: @types.Percent(1.0),
      height: @types.Length(200.0),
    },
    [child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let _ = tree.compute_incremental()

  // Mark node dirty
  tree.mark_node_dirty(child.uid)

  // Resize viewport while dirty (edge case)
  tree.resize_viewport(1024.0, 768.0)

  // Compute should use new viewport and handle dirty correctly
  let layout = tree.compute_incremental()
  assert_true(layout.width > 800.0) // Should use new viewport
}

///|
test "edge: zero-size node" {
  @dispatch.setup()
  let zero_child = LayoutNode::leaf("zero", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(0.0),
    height: @types.Length(0.0),
  })
  let normal_child = LayoutNode::leaf("normal", @style.Style::{
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
    [zero_child, normal_child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Compute should handle zero-size nodes
  let layout1 = tree.compute_incremental()
  assert_true(layout1.width > 0.0)

  // Cache should work with zero-size nodes
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))
}

///|
test "edge: deeply nested tree cache consistency" {
  @dispatch.setup()

  // Create 10-level deep tree
  fn create_deep(depth : Int) -> LayoutNode {
    if depth == 0 {
      LayoutNode::leaf("leaf", @style.Style::{
        ..@style.Style::default(),
        width: @types.Length(50.0),
        height: @types.Length(30.0),
      })
    } else {
      LayoutNode::new(
        "level_" + depth.to_string(),
        @style.Style::{
          ..@style.Style::default(),
          display: @style.Flex,
          width: @types.Length(100.0 + depth.to_double() * 10.0),
          height: @types.Length(50.0 + depth.to_double() * 5.0),
          padding: @types.Rect::{
            top: @types.Length(5.0),
            right: @types.Length(5.0),
            bottom: @types.Length(5.0),
            left: @types.Length(5.0),
          },
        },
        [create_deep(depth - 1)],
      )
    }
  }

  let root = create_deep(10)
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let ref_layout = tree.compute_full()

  // Multiple incremental computes should all match
  for iter = 0; iter < 5; iter = iter + 1 {
    let layout = tree.compute_incremental()
    assert_true(layouts_equal(ref_layout, layout))
  }

  // Mark deepest node dirty
  fn find_deepest(node : LayoutNode) -> LayoutNode {
    if node.children.length() == 0 {
      node
    } else {
      find_deepest(node.children[0])
    }
  }

  let deepest = find_deepest(tree.root)
  tree.mark_node_dirty(deepest.uid)

  // Should still produce correct layout
  let layout_after_dirty = tree.compute_incremental()
  assert_true(layouts_equal(ref_layout, layout_after_dirty))
}

///|
test "edge: intrinsic cache with Auto-sized nodes" {
  @dispatch.setup()

  // Auto-sized parent with fixed children
  let child1 = LayoutNode::leaf("child1", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let child2 = LayoutNode::leaf("child2", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(80.0),
    height: @types.Length(40.0),
  })
  let auto_parent = LayoutNode::new(
    "auto_parent",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Auto,
      height: @types.Auto,
    }, // Intrinsic sizing
    [child1, child2],
  )
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [auto_parent],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute - fills intrinsic cache
  let layout1 = tree.compute_full()

  // Mark child dirty - should invalidate intrinsic cache for ancestors
  tree.mark_node_dirty(child1.uid)

  // Compute should still be correct (intrinsic recalculated)
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))

  // Multiple computes should be consistent
  let layout3 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout3))
}

///|
test "edge: constraint key None vs Some(height)" {
  @dispatch.setup()

  // Node that might receive different constraint types
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

  // Compute with definite height
  let layout1 = tree.compute_incremental()

  // Verify cache key uses height correctly
  match tree.root.cached_layout {
    Some(cache) =>
      // Cache should have constraint with height
      assert_true(cache.constraint.available_height is Some(_))
    None => assert_true(false)
  }

  // Layout should be consistent
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))
}

///|
test "edge: re-dirty immediately after compute" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Get reference layout
  let ref_layout = tree.compute_full()

  // Compute, immediately re-dirty, compute again
  for iter = 0; iter < 10; iter = iter + 1 {
    let _ = tree.compute_incremental()
    // Immediately mark dirty (before any other operation)
    tree.mark_node_dirty(tree.root.uid)
  }

  // Final compute should still be correct
  let final_layout = tree.compute_incremental()
  assert_true(layouts_equal(ref_layout, final_layout))
}

///|
test "edge: alternating nodes dirty" {
  @dispatch.setup()

  // Create tree with multiple children
  let children : Array[LayoutNode] = []
  for i = 0; i < 5; i = i + 1 {
    children.push(
      LayoutNode::leaf("child_" + i.to_string(), @style.Style::{
        ..@style.Style::default(),
        width: @types.Length(50.0),
        height: @types.Length(30.0),
      }),
    )
  }
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    children,
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Get reference
  let ref_layout = tree.compute_full()

  // Mark only odd-indexed children dirty
  for i = 0; i < 5; i = i + 1 {
    if i % 2 == 1 {
      tree.mark_node_dirty(children[i].uid)
    }
  }

  // Should handle partial dirty correctly
  let layout = tree.compute_incremental()
  assert_true(layouts_equal(ref_layout, layout))
}

///|
test "edge: compute on minimal tree (single node)" {
  @dispatch.setup()

  // Single root node with no children
  let root = LayoutNode::leaf("root", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Should work on single node
  let layout1 = tree.compute_incremental()
  assert_true(layout1.width > 0.0)

  // Cache should work
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))

  // Dirty and recompute
  tree.mark_node_dirty(root.uid)
  let layout3 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout3))
}

///|
test "edge: mixed fixed and Auto siblings" {
  @dispatch.setup()
  let fixed_child = LayoutNode::leaf("fixed", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let auto_child = LayoutNode::new(
    "auto_container",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Auto,
      height: @types.Auto,
    },
    [
      LayoutNode::leaf("inner", @style.Style::{
        ..@style.Style::default(),
        width: @types.Length(80.0),
        height: @types.Length(40.0),
      }),
    ],
  )
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(200.0),
    },
    [fixed_child, auto_child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let layout1 = tree.compute_full()

  // Mark only fixed child dirty (shouldn't affect auto sibling's intrinsic)
  tree.mark_node_dirty(fixed_child.uid)
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))

  // Mark auto child dirty
  tree.mark_node_dirty(auto_child.uid)
  let layout3 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout3))
}

///|
test "edge: cache survives full/incremental alternation" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Alternate between full and incremental computes
  let ref_layout = tree.compute_full()
  for i = 0; i < 10; i = i + 1 {
    let layout = if i % 2 == 0 {
      tree.mark_node_dirty(tree.root.uid)
      tree.compute_full()
    } else {
      tree.compute_incremental()
    }
    assert_true(layouts_equal(ref_layout, layout))
  }
}

///|
test "edge: very wide tree (many siblings)" {
  @dispatch.setup()

  // Create tree with 100 siblings
  let children : Array[LayoutNode] = []
  for i = 0; i < 100; i = i + 1 {
    children.push(
      LayoutNode::leaf("child_" + i.to_string(), @style.Style::{
        ..@style.Style::default(),
        width: @types.Length(10.0),
        height: @types.Length(10.0),
      }),
    )
  }
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      flex_wrap: @style.Wrap,
      width: @types.Length(500.0),
      height: @types.Length(500.0),
    },
    children,
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // First compute
  let ref_layout = tree.compute_full()

  // Mark random children dirty
  tree.mark_node_dirty(children[0].uid)
  tree.mark_node_dirty(children[50].uid)
  tree.mark_node_dirty(children[99].uid)

  // Should still be correct
  let layout = tree.compute_incremental()
  assert_true(layouts_equal(ref_layout, layout))
}

///|
test "edge: negative margin handling" {
  @dispatch.setup()
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
    margin: @types.Rect::{
      top: @types.Length(-10.0),
      right: @types.Length(0.0),
      bottom: @types.Length(0.0),
      left: @types.Length(-5.0),
    },
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

  // Should handle negative margins
  let layout1 = tree.compute_incremental()

  // Cache should work with negative margins
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))

  // Dirty and recompute
  tree.mark_node_dirty(child.uid)
  let layout3 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout3))
}

///|
test "edge: percent and viewport edge cases" {
  @dispatch.setup()

  // 100% width and height
  let child = LayoutNode::leaf("child", @style.Style::{
    ..@style.Style::default(),
    width: @types.Percent(1.0),
    height: @types.Percent(1.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Percent(1.0),
      height: @types.Percent(1.0),
    },
    [child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Compute at initial viewport
  let layout1 = tree.compute_incremental()
  assert_true((layout1.width - 800.0).abs() < 0.1)

  // Resize to very small viewport
  tree.resize_viewport(100.0, 50.0)
  let layout2 = tree.compute_incremental()
  assert_true((layout2.width - 100.0).abs() < 0.1)

  // Resize to very large viewport
  tree.resize_viewport(2000.0, 1500.0)
  let layout3 = tree.compute_incremental()
  assert_true((layout3.width - 2000.0).abs() < 0.1)

  // Back to original
  tree.resize_viewport(800.0, 600.0)
  let layout4 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout4))
}

///|
test "edge: display none node" {
  @dispatch.setup()
  let visible_child = LayoutNode::leaf("visible", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(100.0),
    height: @types.Length(50.0),
  })
  let hidden_child = LayoutNode::leaf("hidden", @style.Style::{
    ..@style.Style::default(),
    display: @style.None,
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
    [visible_child, hidden_child],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Compute should handle display:none
  let layout1 = tree.compute_incremental()

  // Cache should work
  let layout2 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout2))

  // Mark hidden node dirty - shouldn't affect visible layout
  tree.mark_node_dirty(hidden_child.uid)
  let layout3 = tree.compute_incremental()
  assert_true(layouts_equal(layout1, layout3))
}

///|
test "edge: find_node returns correct node" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Find root
  match tree.find_node(tree.root.uid) {
    Some(found) => assert_eq(found.id, "root")
    None => assert_true(false)
  }

  // Find child
  let child_uid = tree.root.children[0].uid
  match tree.find_node(child_uid) {
    Some(found) => assert_eq(found.id, "child1")
    None => assert_true(false)
  }

  // Non-existent uid
  match tree.find_node(-999) {
    Some(_) => assert_true(false)
    None => assert_true(true) // Expected
  }
}

///|
test "edge: get_parent returns correct parent" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Root has no parent
  match tree.get_parent(tree.root.uid) {
    Some(_) => assert_true(false)
    None => assert_true(true) // Expected
  }

  // Child has root as parent
  let child_uid = tree.root.children[0].uid
  match tree.get_parent(child_uid) {
    Some(parent) => assert_eq(parent.id, "root")
    None => assert_true(false)
  }
}

///|
test "edge: cache consistency across 1000 operations" {
  @dispatch.setup()
  let root = create_test_tree()
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Get reference
  let ref_layout = tree.compute_full()

  // Perform 1000 random-ish operations
  for i = 0; i < 1000; i = i + 1 {
    let op = i % 4
    if op == 0 {
      // Compute incremental
      let layout = tree.compute_incremental()
      assert_true(layouts_equal(ref_layout, layout))
    } else if op == 1 {
      // Mark root dirty and compute
      tree.mark_node_dirty(tree.root.uid)
      let layout = tree.compute_incremental()
      assert_true(layouts_equal(ref_layout, layout))
    } else if op == 2 {
      // Mark child dirty and compute
      tree.mark_node_dirty(tree.root.children[i % 2].uid)
      let layout = tree.compute_incremental()
      assert_true(layouts_equal(ref_layout, layout))
    } else {
      // Full compute
      let layout = tree.compute_full()
      assert_true(layouts_equal(ref_layout, layout))
    }
  }
}
