///|
/// CLI helper for Arc90 extraction testing
/// This demonstrates how to use the extraction on a parsed accessibility tree

///|
/// Print extraction result in human-readable format
pub fn print_extraction_result(result : ExtractionResult) -> String {
  result.to_summary()
}

///|
/// Extract and print statistics about content detection
pub fn get_extraction_stats(result : ExtractionResult) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Arc90 Extraction Statistics:\n")
  buf.write_string("----------------------------\n")
  buf.write_string("Total content blocks found: ")
  buf.write_string(result.content_blocks.length().to_string())
  buf.write_string("\n")
  buf.write_string("Navigation elements: ")
  buf.write_string(result.detected_navigation.length().to_string())
  buf.write_string("\n")
  buf.write_string("Detected ads: ")
  buf.write_string(result.detected_ads.length().to_string())
  buf.write_string("\n\n")
  match result.main_content {
    Some(node) => {
      buf.write_string("Main Content Detected:\n")
      buf.write_string("  Role: ")
      buf.write_string(node.role.to_string())
      buf.write_string("\n")
      match node.name {
        Some(name) => {
          let display_name = if name.length() > 100 {
            name.unsafe_substring(start=0, end=100) + "..."
          } else {
            name
          }
          buf.write_string("  Name: \"")
          buf.write_string(display_name)
          buf.write_string("\"\n")
        }
        None => ()
      }
      match node.text {
        Some(text) => {
          let display_text = if text.length() > 200 {
            text.unsafe_substring(start=0, end=200) + "..."
          } else {
            text
          }
          buf.write_string("  Text: \"")
          buf.write_string(display_text)
          buf.write_string("\"\n")
        }
        None => ()
      }
    }
    None => buf.write_string("No main content detected.\n")
  }
  buf.write_string("\nTop 3 Content Blocks by Score:\n")
  let len = result.content_blocks.length()
  let limit = if len < 3 { len } else { 3 }
  for i in 0..<limit {
    let block = result.content_blocks[i]
    buf.write_string("  ")
    buf.write_string((i + 1).to_string())
    buf.write_string(". [")
    buf.write_string(block.node.role.to_string())
    buf.write_string("] score=")
    // Format score to 2 decimal places manually
    let score_int = (block.score * 100.0).to_int()
    buf.write_string((score_int / 100).to_string())
    buf.write_string(".")
    let decimal = score_int % 100
    if decimal < 10 {
      buf.write_string("0")
    }
    buf.write_string(decimal.to_string())
    buf.write_string("\n")
  }
  buf.to_string()
}
