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

  // Collect and score all potential content blocks
  collect_content_blocks(
    tree.root,
    config,
    content_blocks,
    detected_ads,
    detected_navigation,
  )

  // Sort by score descending
  content_blocks.sort_by(fn(a, b) { b.score.compare(a.score) })

  // Main content is the highest scoring block
  let main_content = if content_blocks.length() > 0 {
    Some(content_blocks[0].node)
  } else {
    None
  }
  { main_content, content_blocks, detected_ads, detected_navigation }
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
      let block = score_content_block(node, text_content, config)
      blocks.push(block)
    }
  }

  // Recurse into children
  for child in node.children {
    collect_content_blocks(child, config, blocks, ads, nav)
  }
}

///|
fn is_navigation(node : @aom.AccessibilityNode) -> Bool {
  match node.role {
    @aom.Navigation | @aom.Banner | @aom.ContentInfo | @aom.Complementary =>
      true
    _ => false
  }
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
) -> ContentBlock {
  let text_density = calculate_text_density(node, text_content)
  let visual_score = calculate_visual_score(node, config)
  let position_penalty = calculate_position_penalty(node, config)

  // Combined score: text density is most important, modified by visual/position
  let score = text_density * visual_score * (1.0 - position_penalty)
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
