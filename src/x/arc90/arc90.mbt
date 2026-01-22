///|
/// Arc90 Extended Content Extraction
/// Uses layout coordinates + text density for high-precision content extraction

// =============================================================================
// Types
// =============================================================================

///|
/// Content block with scoring information
pub(all) struct ContentBlock {
  node : @aom.AccessibilityNode
  score : Double
  text_density : Double
  visual_score : Double
  position_penalty : Double
}

///|
/// Extraction result
pub(all) struct ExtractionResult {
  main_content : @aom.AccessibilityNode?
  content_blocks : Array[ContentBlock]
  detected_ads : Array[@aom.AccessibilityNode]
  detected_navigation : Array[@aom.AccessibilityNode]
}

///|
/// Configuration for extraction
pub(all) struct ExtractConfig {
  /// Minimum text length to consider as content
  min_text_length : Int
  /// Viewport width for position analysis
  viewport_width : Double
  /// Viewport height for position analysis
  viewport_height : Double
  /// Common ad sizes to detect
  ad_sizes : Array[(Double, Double)]
}

///|
priv struct ReadabilityScores {
  scores : Map[String, Double]
  candidates : Array[@aom.AccessibilityNode]
}

///|
pub fn ExtractConfig::default() -> ExtractConfig {
  {
    min_text_length: 50,
    viewport_width: 1280.0,
    viewport_height: 800.0,
    ad_sizes: [
      (300.0, 250.0), // Medium Rectangle
      (728.0, 90.0), // Leaderboard
      (160.0, 600.0), // Wide Skyscraper
      (300.0, 600.0), // Half Page
      (320.0, 50.0), // Mobile Banner
      (320.0, 100.0), // Large Mobile Banner
    ],
  }
}

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
  // Check by role
  match node.role {
    @aom.Article | @aom.Main => return Some(node)
    _ => ()
  }

  // Check by tag name
  match node.tag_name {
    Some(tag) => if tag == "article" || tag == "main" { return Some(node) }
    None => ()
  }

  // Recurse into children
  for child in node.children {
    match find_article_or_main(child) {
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

// =============================================================================
// Content Block Collection
// =============================================================================

///|
fn collect_content_blocks(
  node : @aom.AccessibilityNode,
  config : ExtractConfig,
  blocks : Array[ContentBlock],
  ads : Array[@aom.AccessibilityNode],
  nav : Array[@aom.AccessibilityNode],
  readability_scores : Map[String, Double],
) -> Unit {
  // Check if this is navigation
  if is_navigation(node) {
    nav.push(node)
    return
  }

  // Check if this looks like an ad
  if is_likely_ad(node, config) {
    ads.push(node)
    return
  }

  // Score content-bearing nodes
  if is_content_container(node) {
    let text_content = get_text_content(node)
    if text_content.length() >= config.min_text_length {
      let block = score_content_block(
        node, text_content, config, readability_scores,
      )
      blocks.push(block)
    }
  }

  // Recurse into children
  for child in node.children {
    collect_content_blocks(child, config, blocks, ads, nav, readability_scores)
  }
}

///|
fn is_navigation(node : @aom.AccessibilityNode) -> Bool {
  // Check by role
  match node.role {
    @aom.Navigation | @aom.Banner | @aom.ContentInfo | @aom.Complementary =>
      return true
    _ => ()
  }

  // Check by tag name
  match node.tag_name {
    Some(tag) =>
      match tag {
        "header" | "footer" | "nav" | "aside" => return true
        _ => ()
      }
    None => ()
  }
  false
}

///|
fn is_content_container(node : @aom.AccessibilityNode) -> Bool {
  match node.role {
    @aom.Article | @aom.Main | @aom.Region | @aom.Document => true
    @aom.Generic | @aom.Group =>
      // Generic containers might be content if they have substantial text
      true
    _ => false
  }
}

///|
fn is_likely_ad(node : @aom.AccessibilityNode, config : ExtractConfig) -> Bool {
  match node.bounds {
    Some(bounds) => {
      // Check for common ad sizes
      for ad_size in config.ad_sizes {
        let (ad_w, ad_h) = ad_size
        if is_approx(bounds.width, ad_w, 5.0) &&
          is_approx(bounds.height, ad_h, 5.0) {
          return true
        }
      }

      // Fixed position elements at edges are often ads
      let is_edge_fixed = bounds.x < 10.0 ||
        bounds.x + bounds.width > config.viewport_width - 10.0

      // Very small height with full width = banner ad
      if bounds.height < 100.0 && bounds.width > config.viewport_width * 0.8 {
        return true
      }

      // Sidebar position with common ad dimensions
      if is_edge_fixed && bounds.width < 350.0 && bounds.height > 200.0 {
        return true
      }
      false
    }
    None => false
  }
}

///|
fn is_approx(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() < tolerance
}

// =============================================================================
// Scoring
// =============================================================================

///|
fn score_content_block(
  node : @aom.AccessibilityNode,
  text_content : String,
  config : ExtractConfig,
  readability_scores : Map[String, Double],
) -> ContentBlock {
  let text_density = calculate_text_density(node, text_content)
  let visual_score = calculate_visual_score(node, config)
  let position_penalty = calculate_position_penalty(node, config)

  // Role bonus: semantic content elements score higher
  let role_bonus : Double = match node.role {
    @aom.Article => 2.0
    @aom.Main => 1.8
    @aom.Region => 1.2
    _ => 1.0
  }

  // Tag-based adjustment
  let tag_multiplier : Double = match node.tag_name {
    Some(tag) =>
      match tag {
        "article" => 1.5
        "main" => 1.5
        "section" => 1.1
        "header" | "footer" | "nav" | "aside" => 0.1
        _ => 1.0
      }
    None => 1.0
  }

  // Selector-based scoring (class/id patterns)
  let selector_score = calculate_selector_score(node)

  // Link density scoring (penalize high link density)
  let link_density_score = calculate_link_density_score(node, text_content)

  // Readability-style: paragraph count bonus
  // More paragraphs = likely main content
  let paragraph_bonus = calculate_paragraph_bonus(node)

  // Readability-style: punctuation bonus
  // More commas/periods = likely prose content (not navigation)
  let punctuation_bonus = calculate_punctuation_bonus(text_content)

  // Readability-style paragraph-level scoring bonus (propagated from paragraphs)
  let readability_score = get_readability_score(readability_scores, node)
  let readability_bonus = calculate_readability_bonus(readability_score)

  // Navigation-like text penalty
  let navigation_penalty = calculate_navigation_penalty(node, text_content)
  let repetition_penalty = calculate_repetition_penalty(text_content)

  // Combined score
  let base_score = text_density * visual_score * (1.0 - position_penalty)
  let score = base_score *
    role_bonus *
    tag_multiplier *
    selector_score *
    link_density_score *
    paragraph_bonus *
    punctuation_bonus *
    readability_bonus *
    navigation_penalty *
    repetition_penalty
  { node, score, text_density, visual_score, position_penalty }
}

///|
/// Text density = text length / bounding box area
fn calculate_text_density(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  match node.bounds {
    Some(bounds) => {
      let area = bounds.width * bounds.height
      if area > 0.0 {
        text_content.length().to_double() / area * 1000.0 // Normalize
      } else {
        0.0
      }
    }
    None => text_content.length().to_double() / 1000.0 // Fallback: just text length
  }
}

///|
/// Visual score based on size and proportion
fn calculate_visual_score(
  node : @aom.AccessibilityNode,
  config : ExtractConfig,
) -> Double {
  match node.bounds {
    Some(bounds) => {
      // Larger content areas score higher
      let area_ratio = bounds.width *
        bounds.height /
        (config.viewport_width * config.viewport_height)

      // Content should be reasonably wide (not sidebar)
      let width_ratio = bounds.width / config.viewport_width
      let width_score = if width_ratio > 0.5 {
        1.0
      } else if width_ratio > 0.3 {
        0.7
      } else {
        0.3
      }

      // Prefer taller content blocks
      let height_score = if bounds.height > 500.0 {
        1.0
      } else if bounds.height > 200.0 {
        0.7
      } else {
        0.4
      }
      (area_ratio * 10.0 + width_score + height_score) / 3.0
    }
    None => 0.5 // Neutral score without bounds
  }
}

///|
/// Position penalty for sidebar/header/footer positions
fn calculate_position_penalty(
  node : @aom.AccessibilityNode,
  config : ExtractConfig,
) -> Double {
  match node.bounds {
    Some(bounds) => {
      let mut penalty = 0.0

      // Top of page penalty (likely header)
      if bounds.y < 100.0 {
        penalty = penalty + 0.3
      }

      // Sidebar penalty (far left or right)
      let center_x = bounds.x + bounds.width / 2.0
      let center_ratio = center_x / config.viewport_width
      if center_ratio < 0.25 || center_ratio > 0.75 {
        penalty = penalty + 0.2
      }

      // Very bottom penalty (likely footer)
      if bounds.y > config.viewport_height * 0.9 {
        penalty = penalty + 0.3
      }
      if penalty > 0.8 {
        0.8
      } else {
        penalty
      } // Don't penalize more than 80%
    }
    None => 0.0
  }
}

///|
/// Selector-based scoring using class/id name patterns (Readability-style)
fn calculate_selector_score(node : @aom.AccessibilityNode) -> Double {
  let mut score = 1.0

  // Check selector for class/id patterns
  // Selector format: "tag#id.class1.class2"
  match node.selector {
    Some(selector_str) => {
      let selector_lower = selector_str.to_lower()
      // Positive patterns (content indicators)
      if contains_any(selector_lower, [
          "article", "content", "post", "text", "body", "entry", "story", "main",
          "blog", "news",
        ]) {
        score = score * 1.5
      }
      // Negative patterns (non-content indicators)
      if contains_any(selector_lower, [
          "sidebar", "side-bar", "widget", "ad", "advertisement", "sponsor", "promo",
          "social", "share", "comment", "related", "recommend", "footer", "header",
          "nav", "menu", "breadcrumb", "pagination", "meta",
        ]) {
        score = score * 0.3
      }
    }
    None => ()
  }

  // Check id for patterns (id is String, not Option)
  if node.id.length() > 0 {
    let id_lower = node.id.to_lower()
    if contains_any(id_lower, [
        "article", "content", "post", "main", "story", "entry",
      ]) {
      score = score * 1.5
    }
    if contains_any(id_lower, [
        "sidebar", "widget", "ad", "sponsor", "comment", "footer", "header", "nav",
      ]) {
      score = score * 0.3
    }
  }
  score
}

///|
/// Check if string contains any of the patterns
fn contains_any(s : String, patterns : FixedArray[String]) -> Bool {
  for pattern in patterns {
    if string_contains(s, pattern) {
      return true
    }
  }
  false
}

///|
/// Simple string contains check
fn string_contains(haystack : String, needle : String) -> Bool {
  if needle.length() == 0 {
    return true
  }
  if haystack.length() < needle.length() {
    return false
  }
  let h_len = haystack.length()
  let n_len = needle.length()
  for i in 0..<(h_len - n_len + 1) {
    let mut found = true
    for j in 0..<n_len {
      if haystack[i + j] != needle[j] {
        found = false
        break
      }
    }
    if found {
      return true
    }
  }
  false
}

///|
/// Paragraph bonus - more paragraphs = likely main content
fn calculate_paragraph_bonus(node : @aom.AccessibilityNode) -> Double {
  let p_count = count_paragraph_elements(node)

  // Score based on paragraph count
  if p_count >= 5 {
    1.5 // Many paragraphs = strong content indicator
  } else if p_count >= 3 {
    1.3
  } else if p_count >= 1 {
    1.1
  } else {
    1.0 // No paragraphs = neutral
  }
}

///|
/// Count paragraph elements (p, pre, blockquote)
fn count_paragraph_elements(node : @aom.AccessibilityNode) -> Int {
  let mut count = 0

  // Check if this is a paragraph-like element
  match node.tag_name {
    Some(tag) =>
      match tag {
        "p" | "pre" | "blockquote" => count = count + 1
        _ => ()
      }
    None => ()
  }

  // Recurse into children
  for child in node.children {
    count = count + count_paragraph_elements(child)
  }
  count
}

///|
/// Punctuation bonus - more commas/periods = likely prose content
fn calculate_punctuation_bonus(text_content : String) -> Double {
  let mut comma_count = 0
  let mut period_count = 0
  for c in text_content {
    match c {
      ',' => comma_count = comma_count + 1
      '.' => period_count = period_count + 1
      _ => ()
    }
  }
  let total_punct = comma_count + period_count
  let text_len = text_content.length()

  // Avoid division by zero
  if text_len < 100 {
    return 1.0
  }

  // Calculate punctuation density
  let punct_density = total_punct.to_double() / text_len.to_double() * 100.0

  // Score based on punctuation density
  // Normal prose has ~2-4% punctuation
  if punct_density > 2.0 && punct_density < 5.0 {
    1.3 // Good prose density
  } else if punct_density > 1.0 && punct_density < 6.0 {
    1.1 // Acceptable density
  } else if punct_density > 6.0 {
    0.9 // Too much punctuation (might be lists/code)
  } else {
    1.0 // Low punctuation = neutral
  }
}

///|
/// Link density scoring - penalize elements with high ratio of link text
fn calculate_link_density_score(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let link_density = calculate_link_density(node, text_content)

  // High link density = likely navigation, not content
  if link_density > 0.5 {
    0.2 // Heavy penalty
  } else if link_density > 0.3 {
    0.5
  } else if link_density > 0.1 {
    0.8
  } else {
    1.0 // Low link density = good content
  }
}

///|
/// Calculate link density ratio (0.0 - 1.0)
fn calculate_link_density(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let total_length = text_content.length()
  if total_length == 0 {
    return 0.0
  }
  let link_length = count_link_text_length(node)
  link_length / total_length.to_double()
}

///|
/// Count the total length of text within link elements
fn count_link_text_length(node : @aom.AccessibilityNode) -> Double {
  let mut length = 0.0

  // Check if this node is a link
  match node.role {
    @aom.Link => {
      let coefficient = match node.href {
        Some(href) =>
          if href.length() > 0 && href[0] == '#' {
            0.3
          } else {
            1.0
          }
        None => 1.0
      }
      let mut text_len = 0
      match node.name {
        Some(name) => text_len = text_len + name.length()
        None => ()
      }
      match node.text {
        Some(text) => text_len = text_len + text.length()
        None => ()
      }
      length = length + text_len.to_double() * coefficient
    }
    _ => ()
  }

  // Recurse into children
  for child in node.children {
    length = length + count_link_text_length(child)
  }
  length
}

// =============================================================================
// Readability-style Scoring
// =============================================================================

///|
fn build_readability_scores(root : @aom.AccessibilityNode) -> ReadabilityScores {
  let scores : Map[String, Double] = {}
  let candidates : Array[@aom.AccessibilityNode] = []
  let seen : Map[String, Bool] = {}
  let ancestors : Array[@aom.AccessibilityNode] = []
  collect_readability_candidates(root, ancestors, scores, candidates, seen)
  adjust_readability_scores(candidates, scores)
  { scores, candidates }
}

///|
fn collect_readability_candidates(
  node : @aom.AccessibilityNode,
  ancestors : Array[@aom.AccessibilityNode],
  scores : Map[String, Double],
  candidates : Array[@aom.AccessibilityNode],
  seen : Map[String, Bool],
) -> Unit {
  if should_score_for_readability(node) {
    let text_content = get_text_content(node)
    if text_content.length() >= 25 {
      let content_score = calculate_readability_content_score(text_content)
      let depth = ancestors.length()
      let max_depth = if depth < 3 { depth } else { 3 }
      for i in 0..<max_depth {
        let ancestor = ancestors[depth - 1 - i]
        ensure_readability_initialized(scores, candidates, seen, ancestor)
        let divider = if i == 0 {
          1.0
        } else if i == 1 {
          2.0
        } else {
          i.to_double() * 3.0
        }
        add_readability_score(scores, ancestor, content_score / divider)
      }
    }
  }
  ancestors.push(node)
  for child in node.children {
    collect_readability_candidates(child, ancestors, scores, candidates, seen)
  }
  let _ = ancestors.pop()

}

///|
fn should_score_for_readability(node : @aom.AccessibilityNode) -> Bool {
  match node.tag_name {
    Some(tag) =>
      match tag {
        "section" | "h2" | "h3" | "h4" | "h5" | "h6" | "p" | "td" | "pre" =>
          true
        _ => node.role == @aom.Paragraph || node.role == @aom.Heading
      }
    None => node.role == @aom.Paragraph || node.role == @aom.Heading
  }
}

///|
fn calculate_readability_content_score(text_content : String) -> Double {
  let mut score = 1.0
  let comma_count = count_readability_commas(text_content)
  score = score + comma_count.to_double()
  let text_len = text_content.length()
  let length_bonus = if text_len / 100 > 3 { 3 } else { text_len / 100 }
  score = score + length_bonus.to_double()
  score
}

///|
fn count_readability_commas(text_content : String) -> Int {
  let mut count = 0
  for c in text_content {
    if c == ',' {
      count = count + 1
    }
  }
  count
}

///|
fn ensure_readability_initialized(
  scores : Map[String, Double],
  candidates : Array[@aom.AccessibilityNode],
  seen : Map[String, Bool],
  node : @aom.AccessibilityNode,
) -> Unit {
  match scores.get(node.id) {
    Some(_) => ()
    None => {
      scores[node.id] = initial_readability_score(node)
      match seen.get(node.id) {
        Some(_) => ()
        None => {
          seen[node.id] = true
          candidates.push(node)
        }
      }
    }
  }
}

///|
fn initial_readability_score(node : @aom.AccessibilityNode) -> Double {
  let tag_score = match node.tag_name {
    Some(tag) =>
      match tag {
        "article" | "main" => 10.0
        "div" => 5.0
        "pre" | "td" | "blockquote" => 3.0
        "address" | "ol" | "ul" | "dl" | "dd" | "dt" | "li" | "form" => -3.0
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" | "th" => -5.0
        _ => 0.0
      }
    None =>
      match node.role {
        @aom.Article | @aom.Main => 10.0
        @aom.Blockquote => 3.0
        @aom.Heading => -5.0
        _ => 0.0
      }
  }
  tag_score + calculate_readability_class_weight(node)
}

///|
fn calculate_readability_class_weight(node : @aom.AccessibilityNode) -> Double {
  let mut weight = 0.0
  let selector_lower = match node.selector {
    Some(selector_str) => selector_str.to_lower()
    None => ""
  }
  if selector_lower.length() > 0 {
    if contains_any(selector_lower, readability_negative_patterns()) {
      weight = weight - 25.0
    }
    if contains_any(selector_lower, readability_positive_patterns()) {
      weight = weight + 25.0
    }
  }
  if node.id.length() > 0 {
    let id_lower = node.id.to_lower()
    if contains_any(id_lower, readability_negative_patterns()) {
      weight = weight - 25.0
    }
    if contains_any(id_lower, readability_positive_patterns()) {
      weight = weight + 25.0
    }
  }
  weight
}

///|
fn readability_positive_patterns() -> FixedArray[String] {
  [
    "article", "body", "content", "entry", "hentry", "h-entry", "main", "page", "pagination",
    "post", "text", "blog", "story",
  ]
}

///|
fn readability_negative_patterns() -> FixedArray[String] {
  [
    "-ad-", "hidden", " hid ", "banner", "combx", "comment", "com-", "contact", "footer",
    "gdpr", "masthead", "media", "meta", "outbrain", "promo", "related", "scroll",
    "share", "shoutbox", "sidebar", "skyscraper", "sponsor", "shopping", "tags",
    "widget",
  ]
}

///|
fn readability_unlikely_patterns() -> FixedArray[String] {
  [
    "-ad-", "ai2html", "banner", "breadcrumbs", "combx", "comment", "community",
    "cover-wrap", "disqus", "extra", "footer", "gdpr", "header", "legends", "menu",
    "related", "remark", "replies", "rss", "shoutbox", "sidebar", "skyscraper", "social",
    "sponsor", "supplemental", "ad-break", "agegate", "pagination", "pager", "popup",
    "yom-remote",
  ]
}

///|
fn readability_ok_patterns() -> FixedArray[String] {
  ["and", "article", "body", "column", "content", "main", "shadow"]
}

///|
fn adjust_readability_scores(
  candidates : Array[@aom.AccessibilityNode],
  scores : Map[String, Double],
) -> Unit {
  for candidate in candidates {
    let base_score = get_readability_score(scores, candidate)
    let text_content = get_text_content(candidate)
    let link_density = calculate_link_density(candidate, text_content)
    let mut score = base_score * (1.0 - link_density)
    let text_density = calculate_readability_text_density(candidate)
    if text_density > 0.0 {
      let density_bonus = text_density / 10.0
      let bonus = if density_bonus > 0.1 { 0.1 } else { density_bonus }
      score = score * (1.0 + bonus)
    }
    let repetition_penalty = calculate_repetition_penalty(text_content)
    score = score * repetition_penalty
    scores[candidate.id] = score
  }
}

///|
fn calculate_readability_text_density(node : @aom.AccessibilityNode) -> Double {
  let text_len = get_text_content(node).length()
  if text_len == 0 {
    return 0.0
  }
  let child_count = node.children.length()
  let denom = if child_count > 0 { child_count.to_double() } else { 1.0 }
  text_len.to_double() / denom
}

///|
fn add_readability_score(
  scores : Map[String, Double],
  node : @aom.AccessibilityNode,
  delta : Double,
) -> Unit {
  let current = match scores.get(node.id) {
    Some(v) => v
    None => 0.0
  }
  scores[node.id] = current + delta
}

///|
fn get_readability_score(
  scores : Map[String, Double],
  node : @aom.AccessibilityNode,
) -> Double {
  match scores.get(node.id) {
    Some(v) => v
    None => 0.0
  }
}

///|
fn is_probably_content(node : @aom.AccessibilityNode) -> Bool {
  if not(node.visible) {
    return false
  }
  if is_unlikely_candidate(node) {
    return false
  }
  let text_content = get_text_content(node)
  if text_content.length() < 140 {
    return false
  }
  let link_density = calculate_link_density(node, text_content)
  if link_density > 0.5 {
    return false
  }
  let text_density = calculate_readability_text_density(node)
  if text_density < 0.1 {
    return false
  }
  true
}

///|
fn is_unlikely_candidate(node : @aom.AccessibilityNode) -> Bool {
  let selector_lower = match node.selector {
    Some(selector_str) => selector_str.to_lower()
    None => ""
  }
  let id_lower = node.id.to_lower()
  let match_string = if selector_lower.is_empty() {
    id_lower
  } else {
    selector_lower + " " + id_lower
  }
  if contains_any(match_string, readability_unlikely_patterns()) &&
    not(contains_any(match_string, readability_ok_patterns())) {
    true
  } else {
    false
  }
}

///|
fn calculate_readability_bonus(readability_score : Double) -> Double {
  if readability_score <= 0.0 {
    1.0
  } else {
    let bonus = 1.0 + readability_score / 8.0
    if bonus > 3.0 {
      3.0
    } else {
      bonus
    }
  }
}

///|
fn calculate_navigation_penalty(
  node : @aom.AccessibilityNode,
  text_content : String,
) -> Double {
  let text_len = text_content.length()
  if text_len == 0 {
    return 1.0
  }
  let text_lower = text_content.to_lower()
  let patterns : FixedArray[String] = [
    "read more", "continue reading", "next", "previous", "next post", "previous post",
    "older", "newer", "related", "recommended", "see also", "more stories",
  ]
  if not(contains_any(text_lower, patterns)) {
    return 1.0
  }
  let link_density = calculate_link_density(node, text_content)
  if text_len < 200 {
    0.3
  } else if text_len < 400 && link_density > 0.2 {
    0.5
  } else if link_density > 0.5 {
    0.6
  } else {
    0.9
  }
}

///|
fn calculate_repetition_penalty(text_content : String) -> Double {
  let parts = text_content.to_lower().split(" ")
  let mut total = 0
  let mut unique = 0
  let seen : Map[String, Bool] = {}
  for part in parts {
    let word = part.trim().to_string()
    if word.length() < 3 {
      continue
    }
    total = total + 1
    match seen.get(word) {
      Some(_) => ()
      None => {
        seen[word] = true
        unique = unique + 1
      }
    }
  }
  if total < 12 {
    return 1.0
  }
  let ratio = unique.to_double() / total.to_double()
  if ratio < 0.15 {
    0.2
  } else if ratio < 0.25 {
    0.3
  } else if ratio < 0.35 {
    0.5
  } else if ratio < 0.45 {
    0.8
  } else {
    1.0
  }
}

// =============================================================================
// Main Content Selection
// =============================================================================

///|
fn find_best_readability_candidate(
  candidates : Array[@aom.AccessibilityNode],
  scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  let mut best : @aom.AccessibilityNode? = None
  let mut best_score = 0.0
  for candidate in candidates {
    if not(is_readability_selection_candidate(candidate)) {
      continue
    }
    let score = get_readability_score(scores, candidate)
    if score > best_score {
      best_score = score
      best = Some(candidate)
    }
  }
  best
}

///|
fn is_readability_selection_candidate(node : @aom.AccessibilityNode) -> Bool {
  if node.role == @aom.Document {
    return false
  }
  match node.tag_name {
    Some(tag) => if tag == "html" || tag == "body" { false } else { true }
    None => true
  }
}

///|
fn find_best_readability_block(
  blocks : Array[ContentBlock],
  scores : Map[String, Double],
) -> ContentBlock? {
  let mut best : ContentBlock? = None
  let mut best_score = 0.0
  for block in blocks {
    let score = get_readability_score(scores, block.node)
    if score > best_score {
      best_score = score
      best = Some(block)
    }
  }
  best
}

///|
fn select_base_main_content(
  article_node : @aom.AccessibilityNode?,
  top_block : ContentBlock?,
  config : ExtractConfig,
  readability_scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  match article_node {
    Some(node) => {
      let article_text = get_text_content(node)
      let article_len = article_text.length()
      match top_block {
        Some(block) => {
          let block_text = get_text_content(block.node)
          let block_len = block_text.length()
          let article_readability = get_readability_score(
            readability_scores, node,
          )
          let block_readability = get_readability_score(
            readability_scores,
            block.node,
          )

          // Prefer high-readability candidate if article/main looks weak
          if block_readability > article_readability * 1.4 &&
            block_len >= config.min_text_length {
            return Some(block.node)
          }

          // Choose based on relative text lengths:
          // - If content_block is 20x+ larger, it's likely the real content
          // - Otherwise prefer semantic article/main
          if block_len > article_len * 20 {
            Some(block.node)
          } else if article_len >= config.min_text_length {
            Some(node)
          } else {
            Some(block.node)
          }
        }
        None =>
          if article_len >= config.min_text_length {
            Some(node)
          } else {
            None
          }
      }
    }
    None =>
      match top_block {
        Some(block) => Some(block.node)
        None => None
      }
  }
}

///|
fn refine_main_content(
  base_main : @aom.AccessibilityNode?,
  best_readability_block : ContentBlock?,
  best_readability_candidate : @aom.AccessibilityNode?,
  config : ExtractConfig,
  readability_scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  let readability_node = select_readability_node(
    best_readability_block, best_readability_candidate, readability_scores,
  )
  match (base_main, readability_node) {
    (None, Some(candidate)) => Some(candidate)
    (Some(main), Some(candidate)) => {
      if main.id == candidate.id {
        return Some(main)
      }
      let main_text = get_text_content(main)
      let main_len = main_text.length()
      let read_text = get_text_content(candidate)
      let read_len = read_text.length()
      let main_readability = get_readability_score(readability_scores, main)
      let read_readability = get_readability_score(
        readability_scores, candidate,
      )
      let main_nav_penalty = calculate_navigation_penalty(main, main_text)
      let read_nav_penalty = calculate_navigation_penalty(candidate, read_text)
      if read_len >= config.min_text_length {
        if main_len < config.min_text_length {
          return Some(candidate)
        }
        let main_probably = is_probably_content(main)
        let read_probably = is_probably_content(candidate)
        if read_probably {
          if not(main_probably) {
            return Some(candidate)
          }
          if main_nav_penalty < 0.6 && read_nav_penalty >= 0.9 {
            return Some(candidate)
          }
          if should_prefer_smaller_container(
              main_len, read_len, main_readability, read_readability,
            ) {
            return Some(candidate)
          }
          if read_readability > main_readability * 1.6 {
            return Some(candidate)
          }
        } else if not(main_probably) &&
          read_readability > main_readability * 1.8 {
          return Some(candidate)
        }
      }
      Some(main)
    }
    (Some(main), None) => Some(main)
    (None, None) => None
  }
}

///|
fn select_readability_node(
  best_readability_block : ContentBlock?,
  best_readability_candidate : @aom.AccessibilityNode?,
  scores : Map[String, Double],
) -> @aom.AccessibilityNode? {
  match (best_readability_block, best_readability_candidate) {
    (None, None) => None
    (Some(block), None) => Some(block.node)
    (None, Some(candidate)) => Some(candidate)
    (Some(block), Some(candidate)) => {
      if block.node.id == candidate.id {
        return Some(candidate)
      }
      let block_score = get_readability_score(scores, block.node)
      let cand_score = get_readability_score(scores, candidate)
      if block_score > cand_score * 1.05 {
        Some(block.node)
      } else if cand_score > block_score * 1.05 {
        Some(candidate)
      } else {
        let block_len = get_text_content(block.node).length()
        let cand_len = get_text_content(candidate).length()
        if cand_len <= block_len {
          Some(candidate)
        } else {
          Some(block.node)
        }
      }
    }
  }
}

///|
fn should_prefer_smaller_container(
  main_len : Int,
  candidate_len : Int,
  main_readability : Double,
  candidate_readability : Double,
) -> Bool {
  if candidate_len == 0 {
    return false
  }
  let ratio = main_len.to_double() / candidate_len.to_double()
  if candidate_len < 600 &&
    ratio >= 6.0 &&
    candidate_readability >= main_readability {
    true
  } else if candidate_len < 1200 &&
    ratio >= 7.0 &&
    candidate_readability >= main_readability * 0.9 {
    true
  } else {
    false
  }
}
// =============================================================================
// Text Extraction
// =============================================================================

///|
fn get_text_content(node : @aom.AccessibilityNode) -> String {
  // Use aggregated text if available
  match node.text {
    Some(text) => text
    None => {
      // Otherwise collect from children
      let buf = StringBuilder::new()
      collect_text(node, buf)
      buf.to_string()
    }
  }
}

///|
fn collect_text(node : @aom.AccessibilityNode, buf : StringBuilder) -> Unit {
  match node.text {
    Some(text) if not(text.is_empty()) => {
      buf.write_string(text)
      buf.write_string(" ")
      return
    }
    _ => ()
  }
  match node.name {
    Some(name) if not(name.is_empty()) => {
      buf.write_string(name)
      buf.write_string(" ")
    }
    _ => ()
  }
  for child in node.children {
    collect_text(child, buf)
  }
}

// =============================================================================
// Debug Output
// =============================================================================

///|
pub fn ContentBlock::to_string(self : ContentBlock) -> String {
  let role = self.node.role.to_string()
  let name = match self.node.name {
    Some(n) => n
    None => "(no name)"
  }
  "ContentBlock { role: \{role}, name: \{name}, score: \{self.score}, text_density: \{self.text_density}, visual: \{self.visual_score}, penalty: \{self.position_penalty} }"
}

///|
pub fn ExtractionResult::to_summary(self : ExtractionResult) -> String {
  let buf = StringBuilder::new()
  buf.write_string("=== Content Extraction Result ===\n")
  match self.main_content {
    Some(node) => {
      buf.write_string("Main Content: ")
      buf.write_string(node.role.to_string())
      match node.name {
        Some(name) => {
          buf.write_string(" \"")
          buf.write_string(name)
          buf.write_string("\"")
        }
        None => ()
      }
      buf.write_string("\n")
    }
    None => buf.write_string("Main Content: (not found)\n")
  }
  buf.write_string("\nTop Content Blocks:\n")
  let len = self.content_blocks.length()
  let limit = if len < 5 { len } else { 5 }
  for i in 0..<limit {
    buf.write_string("  ")
    buf.write_string((i + 1).to_string())
    buf.write_string(". ")
    buf.write_string(self.content_blocks[i].to_string())
    buf.write_string("\n")
  }
  buf.write_string("\nDetected Ads: ")
  buf.write_string(self.detected_ads.length().to_string())
  buf.write_string("\nDetected Navigation: ")
  buf.write_string(self.detected_navigation.length().to_string())
  buf.write_string("\n")
  buf.to_string()
}
