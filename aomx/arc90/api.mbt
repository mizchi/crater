// =============================================================================
// Main API
// =============================================================================

///|
/// Extract main content from an accessibility tree with layout information
pub fn extract_content(
  tree : @aom.AccessibilityTree,
  config : ExtractConfig,
) -> ExtractionResult {
  let content_blocks : Array[ContentBlock] = []
  let detected_ads : Array[@aom.AccessibilityNode] = []
  let detected_navigation : Array[@aom.AccessibilityNode] = []
  let readability_scores = build_readability_scores(tree.root)

  // Collect and score all potential content blocks
  collect_content_blocks(
    tree.root,
    config,
    content_blocks,
    detected_ads,
    detected_navigation,
    readability_scores.scores,
    false,
    false,
  )

  // Sort by score descending
  content_blocks.sort_by(fn(a, b) { b.score.compare(a.score) })

  // First, try to find an article or main element
  let article_node = find_article_or_main(tree.root)

  // Best readability-style candidate from content blocks
  let best_readability_block = find_best_readability_block(
    content_blocks,
    readability_scores.scores,
  )
  let best_readability_candidate = find_best_readability_candidate(
    readability_scores.candidates,
    readability_scores.scores,
  )

  // Main content selection strategy:
  // Compare article/main with top content_block and choose the better one
  let top_block = if content_blocks.length() > 0 {
    Some(content_blocks[0])
  } else {
    None
  }
  let base_main = select_base_main_content(
    article_node,
    top_block,
    config,
    readability_scores.scores,
  )
  let main_content = refine_main_content(
    base_main,
    best_readability_block,
    best_readability_candidate,
    config,
    readability_scores.scores,
  )
  { main_content, content_blocks, detected_ads, detected_navigation }
}

///|
/// Find the first article or main element in the tree
fn find_article_or_main(
  node : @aom.AccessibilityNode,
) -> @aom.AccessibilityNode? {
  match find_first_article(node) {
    Some(article) => Some(article)
    None => find_first_main(node)
  }
}

///|
fn find_first_article(node : @aom.AccessibilityNode) -> @aom.AccessibilityNode? {
  let is_article = match node.tag_name {
    Some(tag) => tag == "article"
    None => node.role == @aom.Article
  }
  if is_article {
    return Some(node)
  }
  for child in node.children {
    match find_first_article(child) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn find_first_main(node : @aom.AccessibilityNode) -> @aom.AccessibilityNode? {
  let is_main = match node.tag_name {
    Some(tag) => tag == "main"
    None => node.role == @aom.Main
  }
  if is_main {
    return Some(node)
  }
  for child in node.children {
    match find_first_main(child) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
/// Quick extraction - returns just the main content node
pub fn extract_main_content(
  tree : @aom.AccessibilityTree,
) -> @aom.AccessibilityNode? {
  let result = extract_content(tree, ExtractConfig::default())
  result.main_content
}
