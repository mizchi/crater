///|
test "content_extraction_basic" {
  // Create a simple tree with main content and navigation
  let nav_node = @aom.AccessibilityNode::new("nav-1", @aom.Navigation).with_name(
    "Site Navigation",
  )
  let nav_node = {
    ..nav_node,
    bounds: Some(@aom.Bounds::new(0.0, 0.0, 1280.0, 60.0)),
    visible: true,
  }
  let article_node = @aom.AccessibilityNode::new("article-1", @aom.Article).with_name(
    "Main Article",
  )
  let article_node = {
    ..article_node,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 800.0, 600.0)),
    text: Some(
      "This is a long article content that should be detected as the main content. It has substantial text and is positioned in the center of the page.",
    ),
    visible: true,
  }
  let sidebar_node = @aom.AccessibilityNode::new(
    "sidebar-1",
    @aom.Complementary,
  ).with_name("Sidebar")
  let sidebar_node = {
    ..sidebar_node,
    bounds: Some(@aom.Bounds::new(1000.0, 100.0, 280.0, 400.0)),
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = {
    ..root,
    children: [nav_node, article_node, sidebar_node],
    visible: true,
  }
  let tree = @aom.AccessibilityTree::new(root)
  let result = extract_content(tree, ExtractConfig::default())

  // Navigation should be detected (at least 1)
  assert_true(result.detected_navigation.length() >= 1)

  // Should find content blocks
  assert_true(result.content_blocks.length() > 0)
}

///|
test "ad_detection" {
  // Create a node with common ad dimensions
  let ad_node = @aom.AccessibilityNode::new("ad-1", @aom.Generic)
  let ad_node = {
    ..ad_node,
    bounds: Some(@aom.Bounds::new(900.0, 200.0, 300.0, 250.0)), // 300x250 Medium Rectangle
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, children: [ad_node], visible: true }
  let tree = @aom.AccessibilityTree::new(root)
  let result = extract_content(tree, ExtractConfig::default())

  // Should detect as ad
  inspect(result.detected_ads.length(), content="1")
}

///|
test "extraction_result_summary" {
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, visible: true }
  let tree = @aom.AccessibilityTree::new(root)
  let result = extract_content(tree, ExtractConfig::default())
  let summary = result.to_summary()

  // Should produce valid summary
  assert_true(summary.contains("Content Extraction Result"))
}
