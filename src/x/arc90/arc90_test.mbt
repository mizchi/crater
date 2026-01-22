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
test "readability_prefers_paragraph_container" {
  let para_text = "This is a sample article paragraph, with commas and periods. " +
    "It should be long enough to trigger readability scoring and select the correct container."
  let paragraph = @aom.AccessibilityNode::new("p-1", @aom.Paragraph).with_name(
    para_text,
  )
  let paragraph = {
    ..paragraph,
    tag_name: Some("p"),
    text: Some(para_text),
    visible: true,
  }
  let article = @aom.AccessibilityNode::new("article-1", @aom.Generic)
  let article = {
    ..article,
    bounds: Some(@aom.Bounds::new(100.0, 100.0, 600.0, 400.0)),
    children: [paragraph],
    visible: true,
  }
  let next_link = @aom.AccessibilityNode::new("next-1", @aom.Link).with_name(
    "Next post",
  )
  let next_link = {
    ..next_link,
    tag_name: Some("a"),
    text: Some("Next post"),
    visible: true,
  }
  let wrapper = @aom.AccessibilityNode::new("wrapper-1", @aom.Generic)
  let wrapper = {
    ..wrapper,
    bounds: Some(@aom.Bounds::new(0.0, 0.0, 1280.0, 2000.0)),
    children: [article, next_link],
    visible: true,
  }
  let root = @aom.AccessibilityNode::new("root", @aom.Document)
  let root = { ..root, children: [wrapper], visible: true }
  let tree = @aom.AccessibilityTree::new(root)
  let result = extract_content(tree, ExtractConfig::default())
  match result.main_content {
    Some(node) => inspect(node.id, content="article-1")
    None => assert_true(false)
  }
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
