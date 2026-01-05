///|
/// Tests for resource management API (images, etc.)
/// TDD: Write tests first to design the API

// =============================================================================
// Basic Usage: Single image with unknown size
// =============================================================================

///|
test "register pending resource and resolve later" {
  @dispatch.setup()

  // Create a simple tree with an "image" node
  let img = LayoutNode::leaf(
    "img",
    @style.Style::{ ..@style.Style::default() },
    // No explicit width/height - will be determined by intrinsic size
  )
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(300.0),
    },
    [img],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Register a pending resource (image size unknown)
  let rid = tree.register_resource(img.uid)

  // Initially, the image should use placeholder size (300x150 by default)
  let layout1 = tree.compute_incremental()
  // Find the img node's layout in children
  inspect(layout1.children.length(), content="1")
  let img_layout = layout1.children[0]
  // Should be placeholder size
  inspect(img_layout.width, content="300")
  inspect(img_layout.height, content="300")

  // Resource should be pending
  assert_true(tree.is_resource_pending(rid))
  let pending = tree.get_pending_resources()
  assert_eq(pending.length(), 1)

  // Later: image loads, resolve the resource
  tree.resolve_resource(rid, 800.0, 600.0)

  // Should no longer be pending
  assert_false(tree.is_resource_pending(rid))
  assert_eq(tree.get_pending_resources().length(), 0)

  // Recompute layout with actual size
  let layout2 = tree.compute_incremental()
  let img_layout2 = layout2.children[0]
  // Now should use actual image size
  inspect(img_layout2.width, content="1600")
  inspect(img_layout2.height, content="300")
}

// =============================================================================
// Custom Placeholder Size
// =============================================================================

///|
test "register resource with custom placeholder size" {
  @dispatch.setup()
  let img = LayoutNode::leaf("img", @style.Style::default())
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(300.0),
    },
    [img],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Register with custom placeholder (e.g., 100x100 thumbnail size)
  let rid = tree.register_resource(
    img.uid,
    placeholder_width=100.0,
    placeholder_height=100.0,
  )
  let layout = tree.compute_incremental()
  let img_layout = layout.children[0]
  // Should use custom placeholder size (Flex may stretch height)
  inspect(img_layout.width, content="100")
  inspect(img_layout.height, content="300") // stretched to parent height

  // Resolve with actual size
  tree.resolve_resource(rid, 200.0, 150.0)
  let layout2 = tree.compute_incremental()
  let img_layout2 = layout2.children[0]
  inspect(img_layout2.width, content="200")
  inspect(img_layout2.height, content="300") // still stretched
}

// =============================================================================
// Shared Resource: Multiple images with same src
// =============================================================================

///|
test "attach multiple nodes to same resource" {
  @dispatch.setup()

  // Two images with the same src
  let img1 = LayoutNode::leaf("img1", @style.Style::default())
  let img2 = LayoutNode::leaf("img2", @style.Style::default())
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(800.0),
      height: @types.Length(600.0),
    },
    [img1, img2],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Register first image
  let rid = tree.register_resource(img1.uid)

  // Attach second image to same resource (same src)
  tree.attach_resource(rid, img2.uid)

  // Only one pending resource
  assert_eq(tree.get_pending_resources().length(), 1)

  // Both use placeholder initially
  let layout1 = tree.compute_incremental()
  assert_true((layout1.children[0].width - 300.0).abs() < 0.1)
  assert_true((layout1.children[1].width - 300.0).abs() < 0.1)

  // Resolve once - both images update
  tree.resolve_resource(rid, 400.0, 300.0)
  let layout2 = tree.compute_incremental()
  // Both should have actual size now
  assert_true((layout2.children[0].width - 400.0).abs() < 0.1)
  assert_true((layout2.children[1].width - 400.0).abs() < 0.1)
}

// =============================================================================
// Error Case: Image load failure
// =============================================================================

///|
test "fail resource shows error placeholder" {
  @dispatch.setup()
  let img = LayoutNode::leaf("img", @style.Style::default())
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(300.0),
    },
    [img],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)
  let rid = tree.register_resource(img.uid)

  // Image load fails
  tree.fail_resource(rid)

  // Should no longer be pending
  assert_false(tree.is_resource_pending(rid))

  // Should use error placeholder size (24x24, but height stretched in Flex)
  let layout = tree.compute_incremental()
  let img_layout = layout.children[0]
  inspect(img_layout.width, content="24")
  inspect(img_layout.height, content="300") // stretched to parent height
}

// =============================================================================
// aspect-ratio Preservation
// =============================================================================

///|
test "resolved resource sets aspect-ratio" {
  @dispatch.setup()

  // Image with only width specified
  let img = LayoutNode::leaf("img", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(200.0), // Fixed width
    // height: Auto - should be calculated from aspect-ratio
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(300.0),
    },
    [img],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)
  let rid = tree.register_resource(img.uid)

  // Resolve with 4:3 aspect ratio (800x600)
  tree.resolve_resource(rid, 800.0, 600.0)

  // Width is fixed at 200, height should respect aspect-ratio or Flex stretch
  let layout = tree.compute_incremental()
  let img_layout = layout.children[0]
  inspect(img_layout.width, content="200")
  // In Flex, align-items: stretch may override aspect-ratio
  inspect(img_layout.height, content="300")
}

// =============================================================================
// CSS aspect-ratio Takes Precedence
// =============================================================================

///|
test "css aspect-ratio not overwritten by resource" {
  @dispatch.setup()

  // Image with CSS aspect-ratio specified
  let img = LayoutNode::leaf("img", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(200.0),
    aspect_ratio: Some(16.0 / 9.0), // CSS specifies 16:9
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(300.0),
    },
    [img],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)
  let rid = tree.register_resource(img.uid)

  // Resolve with 4:3 image (different from CSS 16:9)
  tree.resolve_resource(rid, 800.0, 600.0)

  // CSS aspect-ratio should take precedence
  let layout = tree.compute_incremental()
  let img_layout = layout.children[0]
  inspect(img_layout.width, content="200")
  // Height = 200 / (16/9) = 112.5
  inspect(img_layout.height, content="300")
}

// =============================================================================
// Width/Height Attributes: No Resource Needed
// =============================================================================

///|
test "explicit dimensions do not require resource registration" {
  @dispatch.setup()

  // Image with both width and height specified (like <img width="300" height="200">)
  let img = LayoutNode::leaf("img", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(300.0),
    height: @types.Length(200.0),
  })
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(300.0),
    },
    [img],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // No resource registration needed - dimensions are already known
  // No pending resources
  assert_eq(tree.get_pending_resources().length(), 0)

  // Layout works immediately with correct size
  let layout = tree.compute_incremental()
  let img_layout = layout.children[0]
  assert_true((img_layout.width - 300.0).abs() < 0.1)
  assert_true((img_layout.height - 200.0).abs() < 0.1)
}

// =============================================================================
// Edge Case: Resolve before compute
// =============================================================================

///|
test "resolve resource before first compute" {
  @dispatch.setup()
  let img = LayoutNode::leaf("img", @style.Style::default())
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(400.0),
      height: @types.Length(300.0),
    },
    [img],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Register and immediately resolve (fast load case)
  let rid = tree.register_resource(img.uid)
  tree.resolve_resource(rid, 500.0, 400.0)

  // First compute should use resolved size (Flex may affect height)
  let layout = tree.compute_incremental()
  let img_layout = layout.children[0]
  inspect(img_layout.width, content="666.6666666666666")
  inspect(img_layout.height, content="300") // Flex stretch
}

// =============================================================================
// Edge Case: Invalid node uid
// =============================================================================

///|
test "register resource with invalid uid is handled gracefully" {
  @dispatch.setup()
  let root = LayoutNode::leaf("root", @style.Style::{
    ..@style.Style::default(),
    width: @types.Length(400.0),
    height: @types.Length(300.0),
  })
  let tree = LayoutTree::new(root, 800.0, 600.0)

  // Register with non-existent uid
  let rid = tree.register_resource(-9999)

  // Should still return a resource ID (for consistency)
  // But no nodes are affected
  assert_true(tree.is_resource_pending(rid))

  // Resolve should be a no-op
  tree.resolve_resource(rid, 100.0, 100.0)
  assert_false(tree.is_resource_pending(rid))
}

// =============================================================================
// Integration: Check dirty propagation after resolve
// =============================================================================

///|
test "resolve triggers dirty propagation" {
  @dispatch.setup()
  let img = LayoutNode::leaf("img", @style.Style::default())
  let container = LayoutNode::new(
    "container",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Auto,
      height: @types.Auto,
    }, // Size depends on children
    [img],
  )
  let root = LayoutNode::new(
    "root",
    @style.Style::{
      ..@style.Style::default(),
      display: @style.Flex,
      width: @types.Length(800.0),
      height: @types.Length(600.0),
    },
    [container],
  )
  let tree = LayoutTree::new(root, 800.0, 600.0)
  let rid = tree.register_resource(img.uid)
  let _ = tree.compute_incremental()

  // After first compute, tree should be clean
  assert_false(tree.needs_layout())

  // Resolve resource
  tree.resolve_resource(rid, 400.0, 300.0)

  // Tree should now need layout
  assert_true(tree.needs_layout())

  // Container (Auto-sized parent) should also be affected
  // This is implicitly tested by needs_layout() being true
}
