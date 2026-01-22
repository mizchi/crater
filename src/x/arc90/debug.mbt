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
