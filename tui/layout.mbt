///|
/// Integration with crater layout engine
/// Uses character-based measurements (1 char = 1 unit width/height)

///|
/// Create a MeasureFunc for text that uses character width
pub fn text_measure_func(text : String) -> @node.MeasureFunc {
  {
    func: fn(
      available_width : Double,
      _available_height : Double,
    ) -> @node.IntrinsicSize {
      let max_width = available_width.to_int()
      // Calculate min-content (longest word)
      let mut min_width = 0
      let mut current_word = 0
      for c in text {
        if c == ' ' || c == '\n' {
          if current_word > min_width {
            min_width = current_word
          }
          current_word = 0
        } else {
          current_word = current_word + char_display_width(c)
        }
      }
      if current_word > min_width {
        min_width = current_word
      }
      // Calculate max-content (total width without wrapping)
      let max_content = string_display_width(text)
      // Calculate actual width and height based on wrapping
      let actual_width = if max_width > 0 && max_content > max_width {
        max_width
      } else if max_content > 0 {
        max_content
      } else {
        min_width
      }
      // Calculate height with wrapping
      let height = if actual_width > 0 {
        calculate_wrapped_height(text, actual_width)
      } else {
        1
      }
      {
        min_width: min_width.to_double(),
        max_width: max_content.to_double(),
        min_height: 1.0,
        max_height: height.to_double(),
      }
    },
  }
}

///|
fn calculate_wrapped_height(text : String, max_width : Int) -> Int {
  let mut lines = 1
  let mut current_width = 0
  for c in text {
    if c == '\n' {
      lines = lines + 1
      current_width = 0
      continue
    }
    let w = char_display_width(c)
    if current_width + w > max_width {
      lines = lines + 1
      current_width = w
    } else {
      current_width = current_width + w
    }
  }
  lines
}

///|
/// Compute layout using crater engine with character-based viewport
pub fn compute_layout(
  node : @node.Node,
  width : Int,
  height : Int,
) -> @node.Layout {
  let viewport = @types.Size::new(width.to_double(), height.to_double())
  @crater.compute_layout(node, viewport)
}

///|
/// Border characters for box drawing
pub(all) struct BorderChars {
  top_left : Char
  top_right : Char
  bottom_left : Char
  bottom_right : Char
  horizontal : Char
  vertical : Char
}

///|
pub fn BorderChars::single() -> BorderChars {
  {
    top_left: '\u250C',
    top_right: '\u2510',
    bottom_left: '\u2514',
    bottom_right: '\u2518',
    horizontal: '\u2500',
    vertical: '\u2502',
  }
}

///|
pub fn BorderChars::double() -> BorderChars {
  {
    top_left: '\u2554',
    top_right: '\u2557',
    bottom_left: '\u255A',
    bottom_right: '\u255D',
    horizontal: '\u2550',
    vertical: '\u2551',
  }
}

///|
pub fn BorderChars::rounded() -> BorderChars {
  {
    top_left: '\u256D',
    top_right: '\u256E',
    bottom_left: '\u2570',
    bottom_right: '\u256F',
    horizontal: '\u2500',
    vertical: '\u2502',
  }
}

///|
pub fn BorderChars::ascii() -> BorderChars {
  {
    top_left: '+',
    top_right: '+',
    bottom_left: '+',
    bottom_right: '+',
    horizontal: '-',
    vertical: '|',
  }
}
