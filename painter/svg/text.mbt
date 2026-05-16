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
  TextDecorationFull::from_msvg(@msvg.TextDecorationFull::default())
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
  TextStyle::from_msvg(@msvg.TextStyle::default())
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
  TextSpan::from_msvg(@msvg.TextSpan::new(text))
}

///|
pub fn TextSpan::with_offset(
  text : String,
  dx : Double,
  dy : Double,
) -> TextSpan {
  TextSpan::from_msvg(@msvg.TextSpan::with_offset(text, dx, dy))
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
  TextBlock::from_msvg(@msvg.TextBlock::new(x, y, text))
}

///|
pub fn TextBlock::with_style(
  x : Double,
  y : Double,
  text : String,
  style : TextStyle,
) -> TextBlock {
  TextBlock::from_msvg(
    @msvg.TextBlock::with_style(x, y, text, style.to_msvg()),
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
  TextBlock::from_msvg(@msvg.TextBlock::with_wrap(x, y, text, inline_size))
}

///|
pub fn TextBlock::add_span(self : TextBlock, span : TextSpan) -> Unit {
  self.spans.push(span)
}

///|
/// Calculate text width (simplified - assumes monospace)
pub fn TextBlock::get_width(self : TextBlock) -> Double {
  self.to_msvg().get_width()
}

///|
/// Get text height
pub fn TextBlock::get_height(self : TextBlock) -> Double {
  self.to_msvg().get_height()
}

///|
/// Get adjusted x position based on text-anchor
pub fn TextBlock::get_anchor_x(self : TextBlock) -> Double {
  self.to_msvg().get_anchor_x()
}

///|
/// Get adjusted y position based on dominant-baseline
pub fn TextBlock::get_baseline_y(self : TextBlock) -> Double {
  self.to_msvg().get_baseline_y()
}

///|
/// Wrap text to fit within inline_size, returns lines
pub fn TextBlock::wrap_text(self : TextBlock) -> Array[String] {
  self.to_msvg().wrap_text()
}

///|
/// Get the number of lines when text is wrapped
pub fn TextBlock::get_line_count(self : TextBlock) -> Int {
  self.to_msvg().get_line_count()
}

///|
/// Get total height including all wrapped lines
pub fn TextBlock::get_total_height(self : TextBlock) -> Double {
  self.to_msvg().get_total_height()
}

///|
/// Check if text is vertical (for writing-mode)
pub fn TextBlock::is_vertical(self : TextBlock) -> Bool {
  self.to_msvg().is_vertical()
}

///|
/// Process white-space according to mode
pub fn process_white_space(text : String, mode : WhiteSpace) -> String {
  @msvg.process_white_space(text, mode.to_msvg())
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
    overflow.to_msvg(),
  )
}

///|
fn TextAnchor::from_msvg(anchor : @msvg.TextAnchor) -> TextAnchor {
  match anchor {
    Start => Start
    Middle => Middle
    End => End
  }
}

///|
fn TextAnchor::to_msvg(self : TextAnchor) -> @msvg.TextAnchor {
  match self {
    Start => @msvg.TextAnchor::Start
    Middle => @msvg.TextAnchor::Middle
    End => @msvg.TextAnchor::End
  }
}

///|
fn WritingMode::from_msvg(mode : @msvg.WritingMode) -> WritingMode {
  match mode {
    HorizontalTB => HorizontalTB
    VerticalRL => VerticalRL
    VerticalLR => VerticalLR
  }
}

///|
fn WritingMode::to_msvg(self : WritingMode) -> @msvg.WritingMode {
  match self {
    HorizontalTB => @msvg.WritingMode::HorizontalTB
    VerticalRL => @msvg.WritingMode::VerticalRL
    VerticalLR => @msvg.WritingMode::VerticalLR
  }
}

///|
fn TextOrientation::from_msvg(
  orientation : @msvg.TextOrientation,
) -> TextOrientation {
  match orientation {
    Mixed => Mixed
    Upright => Upright
    Sideways => Sideways
  }
}

///|
fn TextOrientation::to_msvg(self : TextOrientation) -> @msvg.TextOrientation {
  match self {
    Mixed => @msvg.TextOrientation::Mixed
    Upright => @msvg.TextOrientation::Upright
    Sideways => @msvg.TextOrientation::Sideways
  }
}

///|
fn WhiteSpace::from_msvg(mode : @msvg.WhiteSpace) -> WhiteSpace {
  match mode {
    Normal => Normal
    Pre => Pre
    NoWrap => NoWrap
    PreWrap => PreWrap
    PreLine => PreLine
    BreakSpaces => BreakSpaces
  }
}

///|
fn WhiteSpace::to_msvg(self : WhiteSpace) -> @msvg.WhiteSpace {
  match self {
    Normal => @msvg.WhiteSpace::Normal
    Pre => @msvg.WhiteSpace::Pre
    NoWrap => @msvg.WhiteSpace::NoWrap
    PreWrap => @msvg.WhiteSpace::PreWrap
    PreLine => @msvg.WhiteSpace::PreLine
    BreakSpaces => @msvg.WhiteSpace::BreakSpaces
  }
}

///|
fn TextOverflow::from_msvg(overflow : @msvg.TextOverflow) -> TextOverflow {
  match overflow {
    Clip => Clip
    Ellipsis => Ellipsis
    Custom(indicator) => Custom(indicator)
  }
}

///|
fn TextOverflow::to_msvg(self : TextOverflow) -> @msvg.TextOverflow {
  match self {
    Clip => @msvg.TextOverflow::Clip
    Ellipsis => @msvg.TextOverflow::Ellipsis
    Custom(indicator) => @msvg.TextOverflow::Custom(indicator)
  }
}

///|
fn TextDecorationStyle::from_msvg(
  style : @msvg.TextDecorationStyle,
) -> TextDecorationStyle {
  match style {
    Solid => Solid
    Double => Double
    Dotted => Dotted
    Dashed => Dashed
    Wavy => Wavy
  }
}

///|
fn TextDecoration::from_msvg(
  decoration : @msvg.TextDecoration,
) -> TextDecoration {
  match decoration {
    NoDecoration => NoDecoration
    Underline => Underline
    Overline => Overline
    LineThrough => LineThrough
  }
}

///|
fn TextDecoration::to_msvg(self : TextDecoration) -> @msvg.TextDecoration {
  match self {
    NoDecoration => @msvg.TextDecoration::NoDecoration
    Underline => @msvg.TextDecoration::Underline
    Overline => @msvg.TextDecoration::Overline
    LineThrough => @msvg.TextDecoration::LineThrough
  }
}

///|
fn FontWeight::from_msvg(weight : @msvg.FontWeight) -> FontWeight {
  match weight {
    Normal => Normal
    Bold => Bold
    Lighter => Lighter
    Bolder => Bolder
    Weight(value) => Weight(value)
  }
}

///|
fn FontWeight::to_msvg(self : FontWeight) -> @msvg.FontWeight {
  match self {
    Normal => @msvg.FontWeight::Normal
    Bold => @msvg.FontWeight::Bold
    Lighter => @msvg.FontWeight::Lighter
    Bolder => @msvg.FontWeight::Bolder
    Weight(value) => @msvg.FontWeight::Weight(value)
  }
}

///|
fn FontStyle::from_msvg(style : @msvg.FontStyle) -> FontStyle {
  match style {
    NormalStyle => NormalStyle
    Italic => Italic
    Oblique => Oblique
  }
}

///|
fn FontStyle::to_msvg(self : FontStyle) -> @msvg.FontStyle {
  match self {
    NormalStyle => @msvg.FontStyle::NormalStyle
    Italic => @msvg.FontStyle::Italic
    Oblique => @msvg.FontStyle::Oblique
  }
}

///|
fn DominantBaseline::from_msvg(
  baseline : @msvg.DominantBaseline,
) -> DominantBaseline {
  match baseline {
    Auto => Auto
    TextTop => TextTop
    Hanging => Hanging
    Middle => Middle
    Central => Central
    TextBottom => TextBottom
    Alphabetic => Alphabetic
    Ideographic => Ideographic
  }
}

///|
fn DominantBaseline::to_msvg(self : DominantBaseline) -> @msvg.DominantBaseline {
  match self {
    Auto => @msvg.DominantBaseline::Auto
    TextTop => @msvg.DominantBaseline::TextTop
    Hanging => @msvg.DominantBaseline::Hanging
    Middle => @msvg.DominantBaseline::Middle
    Central => @msvg.DominantBaseline::Central
    TextBottom => @msvg.DominantBaseline::TextBottom
    Alphabetic => @msvg.DominantBaseline::Alphabetic
    Ideographic => @msvg.DominantBaseline::Ideographic
  }
}

///|
fn PaintOrder::from_msvg(order : @msvg.PaintOrder) -> PaintOrder {
  if order.order.length() == 1 {
    match order.order[0] {
      Fill => FillOnly
      Stroke => StrokeOnly
      Markers => Normal
    }
  } else if order.order.length() >= 2 {
    match (order.order[0], order.order[1]) {
      (Stroke, Fill) => StrokeFirst
      _ => Normal
    }
  } else {
    Normal
  }
}

///|
fn PaintOrder::to_msvg(self : PaintOrder) -> @msvg.PaintOrder {
  let items = match self {
    Normal =>
      [
        @msvg.PaintOrderItem::Fill,
        @msvg.PaintOrderItem::Stroke,
        @msvg.PaintOrderItem::Markers,
      ]
    StrokeFirst =>
      [
        @msvg.PaintOrderItem::Stroke,
        @msvg.PaintOrderItem::Fill,
        @msvg.PaintOrderItem::Markers,
      ]
    FillOnly => [@msvg.PaintOrderItem::Fill]
    StrokeOnly => [@msvg.PaintOrderItem::Stroke]
  }
  @msvg.PaintOrder::{ order: items }
}

///|
fn TextDecorationFull::from_msvg(
  decoration : @msvg.TextDecorationFull,
) -> TextDecorationFull {
  {
    line: TextDecoration::from_msvg(decoration.line),
    style: TextDecorationStyle::from_msvg(decoration.style),
    color: Color::from_msvg_option(decoration.color),
    thickness: decoration.thickness,
  }
}

///|
fn TextStyle::from_msvg(style : @msvg.TextStyle) -> TextStyle {
  {
    font_family: style.font_family,
    font_size: style.font_size,
    font_weight: FontWeight::from_msvg(style.font_weight),
    font_style: FontStyle::from_msvg(style.font_style),
    text_anchor: TextAnchor::from_msvg(style.text_anchor),
    dominant_baseline: DominantBaseline::from_msvg(style.dominant_baseline),
    text_decoration: TextDecoration::from_msvg(style.text_decoration),
    letter_spacing: style.letter_spacing,
    word_spacing: style.word_spacing,
    line_height: style.line_height,
    writing_mode: WritingMode::from_msvg(style.writing_mode),
    text_orientation: TextOrientation::from_msvg(style.text_orientation),
    white_space: WhiteSpace::from_msvg(style.white_space),
    paint_order: PaintOrder::from_msvg(style.paint_order),
  }
}

///|
fn TextStyle::to_msvg(self : TextStyle) -> @msvg.TextStyle {
  @msvg.TextStyle::{
    font_family: self.font_family,
    font_size: self.font_size,
    font_weight: self.font_weight.to_msvg(),
    font_style: self.font_style.to_msvg(),
    text_anchor: self.text_anchor.to_msvg(),
    dominant_baseline: self.dominant_baseline.to_msvg(),
    text_decoration: self.text_decoration.to_msvg(),
    letter_spacing: self.letter_spacing,
    word_spacing: self.word_spacing,
    line_height: self.line_height,
    writing_mode: self.writing_mode.to_msvg(),
    text_orientation: self.text_orientation.to_msvg(),
    white_space: self.white_space.to_msvg(),
    paint_order: self.paint_order.to_msvg(),
  }
}

///|
fn TextSpan::from_msvg(span : @msvg.TextSpan) -> TextSpan {
  {
    text: span.text,
    x: span.x,
    y: span.y,
    dx: span.dx,
    dy: span.dy,
    style: match span.style {
      Some(style) => Some(TextStyle::from_msvg(style))
      None => None
    },
  }
}

///|
fn TextSpan::to_msvg(self : TextSpan) -> @msvg.TextSpan {
  @msvg.TextSpan::{
    text: self.text,
    x: self.x,
    y: self.y,
    dx: self.dx,
    dy: self.dy,
    style: match self.style {
      Some(style) => Some(style.to_msvg())
      None => None
    },
  }
}

///|
fn TextBlock::from_msvg(block : @msvg.TextBlock) -> TextBlock {
  {
    spans: block.spans.map(TextSpan::from_msvg),
    x: block.x,
    y: block.y,
    style: TextStyle::from_msvg(block.style),
    inline_size: block.inline_size,
    text_overflow: TextOverflow::from_msvg(block.text_overflow),
  }
}

///|
fn TextBlock::to_msvg(self : TextBlock) -> @msvg.TextBlock {
  @msvg.TextBlock::{
    spans: self.spans.map(fn(s) { s.to_msvg() }),
    x: self.x,
    y: self.y,
    style: self.style.to_msvg(),
    inline_size: self.inline_size,
    text_overflow: self.text_overflow.to_msvg(),
  }
}
