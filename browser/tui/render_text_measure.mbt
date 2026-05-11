///|
/// Text measurement helpers for TUI rendering.

///|
/// Calculate text display width for TUI rendering.
/// Uses character-based width (not pixel-based) to ensure text is not clipped
/// due to font-size differences between layout and TUI.
fn calculate_text_display_width(text : String) -> Int {
  let mut width = 0
  for c in text {
    if c == '\n' {
      // Stop at newline for single-line width
      break
    }
    width = width + char_display_width(c)
  }
  width
}
