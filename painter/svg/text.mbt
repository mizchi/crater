// ============================================================================
// Text Layout (SVG 2.0)
// ============================================================================

///|
/// Text anchor (horizontal alignment)
pub(all) enum TextAnchor {
  Start // Left aligned (default for LTR)
  Middle // Center aligned
  End // Right aligned
}

///|
/// Writing mode (SVG 2.0)
pub(all) enum WritingMode {
  HorizontalTB // Left to right, top to bottom (default)
  VerticalRL // Top to bottom, right to left (Japanese, Chinese)
  VerticalLR // Top to bottom, left to right
} derive(Eq, Debug)

///|
pub impl Show for WritingMode with output(self, logger) {
  let name = match self {
    HorizontalTB => "HorizontalTB"
    VerticalRL => "VerticalRL"
    VerticalLR => "VerticalLR"
  }
  logger.write_string(name)
}

///|
/// Text orientation for vertical writing (SVG 2.0)
pub(all) enum TextOrientation {
  Mixed // Upright for CJK, rotated for others (default)
  Upright // All characters upright
  Sideways // All characters rotated 90°
} derive(Eq, Debug)

///|
pub impl Show for TextOrientation with output(self, logger) {
  let name = match self {
    Mixed => "Mixed"
    Upright => "Upright"
    Sideways => "Sideways"
  }
  logger.write_string(name)
}

///|
/// White space handling (SVG 2.0)
pub(all) enum WhiteSpace {
  Normal // Collapse whitespace, wrap at boundaries
  Pre // Preserve whitespace, no wrapping
  NoWrap // Collapse whitespace, no wrapping
  PreWrap // Preserve whitespace, wrap at boundaries
  PreLine // Collapse spaces, preserve newlines, wrap
  BreakSpaces // Like pre-wrap but break at any space
} derive(Eq, Debug)

///|
pub impl Show for WhiteSpace with output(self, logger) {
  let name = match self {
    Normal => "Normal"
    Pre => "Pre"
    NoWrap => "NoWrap"
    PreWrap => "PreWrap"
    PreLine => "PreLine"
    BreakSpaces => "BreakSpaces"
  }
  logger.write_string(name)
}

///|
/// Text overflow handling (SVG 2.0)
pub(all) enum TextOverflow {
  Clip // Clip at boundary
  Ellipsis // Show "..." at overflow
  Custom(String) // Custom overflow indicator
} derive(Eq, Debug)

///|
pub impl Show for TextOverflow with output(self, logger) {
  match self {
    Clip => logger.write_string("Clip")
    Ellipsis => logger.write_string("Ellipsis")
    Custom(value) => {
      logger.write_string("Custom(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

///|
/// Text decoration style (SVG 2.0)
pub(all) enum TextDecorationStyle {
  Solid
  Double
  Dotted
  Dashed
  Wavy
} derive(Eq, Debug)

///|
pub impl Show for TextDecorationStyle with output(self, logger) {
  let name = match self {
    Solid => "Solid"
    Double => "Double"
    Dotted => "Dotted"
    Dashed => "Dashed"
    Wavy => "Wavy"
  }
  logger.write_string(name)
}

///|
/// Extended text decoration (SVG 2.0)
pub(all) struct TextDecorationFull {
  line : TextDecoration // underline, overline, line-through
  style : TextDecorationStyle
  color : Color? // None means use current color
  thickness : Double? // None means auto
}

///|
pub fn TextDecorationFull::default() -> TextDecorationFull {
  text_decoration_full_from_msvg(@msvg.TextDecorationFull::default())
}

///|
/// Paint order for text (SVG 2.0)
pub(all) enum PaintOrder {
  Normal // Fill first, then stroke (default)
  StrokeFirst // Stroke first, then fill
  FillOnly // Only fill, no stroke
  StrokeOnly // Only stroke, no fill
} derive(Eq, Debug)

///|
pub impl Show for PaintOrder with output(self, logger) {
  let name = match self {
    Normal => "Normal"
    StrokeFirst => "StrokeFirst"
    FillOnly => "FillOnly"
    StrokeOnly => "StrokeOnly"
  }
  logger.write_string(name)
}

///|
/// Dominant baseline (vertical alignment)
pub(all) enum DominantBaseline {
  Auto // Default baseline
  TextTop // Top of em box
  Hanging // Hanging baseline
  Middle // Middle of em box
  Central // Central baseline
  TextBottom // Bottom of em box
  Alphabetic // Alphabetic baseline (default)
  Ideographic // Ideographic baseline
}

///|
/// Text decoration
pub(all) enum TextDecoration {
  NoDecoration
  Underline
  Overline
  LineThrough
} derive(Eq, Debug)

///|
pub impl Show for TextDecoration with output(self, logger) {
  let name = match self {
    NoDecoration => "NoDecoration"
    Underline => "Underline"
    Overline => "Overline"
    LineThrough => "LineThrough"
  }
  logger.write_string(name)
}

///|
/// Font weight
pub(all) enum FontWeight {
  Normal // 400
  Bold // 700
  Lighter
  Bolder
  Weight(Int) // 100-900
}

///|
/// Font style
pub(all) enum FontStyle {
  NormalStyle
  Italic
  Oblique
}

///|
/// Complete text style (SVG 2.0 extended)
pub(all) struct TextStyle {
  font_family : String
  font_size : Double
  font_weight : FontWeight
  font_style : FontStyle
  text_anchor : TextAnchor
  dominant_baseline : DominantBaseline
  text_decoration : TextDecoration
  letter_spacing : Double
  word_spacing : Double
  line_height : Double // Multiplier of font_size
  // SVG 2.0 additions
  writing_mode : WritingMode
  text_orientation : TextOrientation
  white_space : WhiteSpace
  paint_order : PaintOrder
}

///|
pub fn TextStyle::default() -> TextStyle {
  text_style_from_msvg(@msvg.TextStyle::default())
}

///|
/// Text span (styled portion of text)
pub(all) struct TextSpan {
  text : String
  x : Double? // Absolute position (overrides flow)
  y : Double?
  dx : Double // Relative offset
  dy : Double
  style : TextStyle?
}

///|
pub fn TextSpan::new(text : String) -> TextSpan {
  text_span_from_msvg(@msvg.TextSpan::new(text))
}

///|
pub fn TextSpan::with_offset(
  text : String,
  dx : Double,
  dy : Double,
) -> TextSpan {
  text_span_from_msvg(@msvg.TextSpan::with_offset(text, dx, dy))
}

///|
/// Multi-line text block (SVG 2.0 extended)
pub(all) struct TextBlock {
  spans : Array[TextSpan]
  x : Double
  y : Double
  style : TextStyle
  // SVG 2.0 additions
  inline_size : Double? // Max width before wrapping (None = no limit)
  text_overflow : TextOverflow
}

///|
pub fn TextBlock::new(x : Double, y : Double, text : String) -> TextBlock {
  text_block_from_msvg(@msvg.TextBlock::new(x, y, text))
}

///|
pub fn TextBlock::with_style(
  x : Double,
  y : Double,
  text : String,
  style : TextStyle,
) -> TextBlock {
  text_block_from_msvg(
    @msvg.TextBlock::with_style(x, y, text, text_style_to_msvg(style)),
  )
}

///|
/// Create a text block with wrapping
pub fn TextBlock::with_wrap(
  x : Double,
  y : Double,
  text : String,
  inline_size : Double,
) -> TextBlock {
  text_block_from_msvg(@msvg.TextBlock::with_wrap(x, y, text, inline_size))
}

///|
pub fn TextBlock::add_span(self : TextBlock, span : TextSpan) -> Unit {
  self.spans.push(span)
}

///|
/// Calculate text width (simplified - assumes monospace)
pub fn TextBlock::get_width(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_width()
}

///|
/// Get text height
pub fn TextBlock::get_height(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_height()
}

///|
/// Get adjusted x position based on text-anchor
pub fn TextBlock::get_anchor_x(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_anchor_x()
}

///|
/// Get adjusted y position based on dominant-baseline
pub fn TextBlock::get_baseline_y(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_baseline_y()
}

///|
/// Wrap text to fit within inline_size, returns lines
pub fn TextBlock::wrap_text(self : TextBlock) -> Array[String] {
  text_block_to_msvg(self).wrap_text()
}

///|
/// Get the number of lines when text is wrapped
pub fn TextBlock::get_line_count(self : TextBlock) -> Int {
  text_block_to_msvg(self).get_line_count()
}

///|
/// Get total height including all wrapped lines
pub fn TextBlock::get_total_height(self : TextBlock) -> Double {
  text_block_to_msvg(self).get_total_height()
}

///|
/// Check if text is vertical (for writing-mode)
pub fn TextBlock::is_vertical(self : TextBlock) -> Bool {
  text_block_to_msvg(self).is_vertical()
}

///|
/// Process white-space according to mode
pub fn process_white_space(text : String, mode : WhiteSpace) -> String {
  @msvg.process_white_space(text, white_space_to_msvg(mode))
}

///|
/// Apply text-overflow to a line
pub fn apply_text_overflow(
  line : String,
  max_width : Double,
  char_width : Double,
  overflow : TextOverflow,
) -> String {
  @msvg.apply_text_overflow(
    line,
    max_width,
    char_width,
    text_overflow_to_msvg(overflow),
  )
}
