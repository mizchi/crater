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
