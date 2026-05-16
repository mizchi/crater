///|
fn white_space_to_msvg(mode : WhiteSpace) -> @msvg.WhiteSpace {
  match mode {
    Normal => @msvg.WhiteSpace::Normal
    Pre => @msvg.WhiteSpace::Pre
    NoWrap => @msvg.WhiteSpace::NoWrap
    PreWrap => @msvg.WhiteSpace::PreWrap
    PreLine => @msvg.WhiteSpace::PreLine
    BreakSpaces => @msvg.WhiteSpace::BreakSpaces
  }
}

///|
fn text_overflow_to_msvg(overflow : TextOverflow) -> @msvg.TextOverflow {
  match overflow {
    Clip => @msvg.TextOverflow::Clip
    Ellipsis => @msvg.TextOverflow::Ellipsis
    Custom(indicator) => @msvg.TextOverflow::Custom(indicator)
  }
}

///|
fn text_anchor_from_msvg(anchor : @msvg.TextAnchor) -> TextAnchor {
  match anchor {
    Start => Start
    Middle => Middle
    End => End
  }
}

///|
fn text_anchor_to_msvg(anchor : TextAnchor) -> @msvg.TextAnchor {
  match anchor {
    Start => @msvg.TextAnchor::Start
    Middle => @msvg.TextAnchor::Middle
    End => @msvg.TextAnchor::End
  }
}

///|
fn writing_mode_from_msvg(mode : @msvg.WritingMode) -> WritingMode {
  match mode {
    HorizontalTB => HorizontalTB
    VerticalRL => VerticalRL
    VerticalLR => VerticalLR
  }
}

///|
fn writing_mode_to_msvg(mode : WritingMode) -> @msvg.WritingMode {
  match mode {
    HorizontalTB => @msvg.WritingMode::HorizontalTB
    VerticalRL => @msvg.WritingMode::VerticalRL
    VerticalLR => @msvg.WritingMode::VerticalLR
  }
}

///|
fn text_orientation_from_msvg(
  orientation : @msvg.TextOrientation,
) -> TextOrientation {
  match orientation {
    Mixed => Mixed
    Upright => Upright
    Sideways => Sideways
  }
}

///|
fn text_orientation_to_msvg(
  orientation : TextOrientation,
) -> @msvg.TextOrientation {
  match orientation {
    Mixed => @msvg.TextOrientation::Mixed
    Upright => @msvg.TextOrientation::Upright
    Sideways => @msvg.TextOrientation::Sideways
  }
}

///|
fn white_space_from_msvg(mode : @msvg.WhiteSpace) -> WhiteSpace {
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
fn text_overflow_from_msvg(overflow : @msvg.TextOverflow) -> TextOverflow {
  match overflow {
    Clip => Clip
    Ellipsis => Ellipsis
    Custom(indicator) => Custom(indicator)
  }
}

///|
fn text_decoration_style_from_msvg(
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
fn text_decoration_from_msvg(
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
fn text_decoration_to_msvg(decoration : TextDecoration) -> @msvg.TextDecoration {
  match decoration {
    NoDecoration => @msvg.TextDecoration::NoDecoration
    Underline => @msvg.TextDecoration::Underline
    Overline => @msvg.TextDecoration::Overline
    LineThrough => @msvg.TextDecoration::LineThrough
  }
}

///|
fn font_weight_from_msvg(weight : @msvg.FontWeight) -> FontWeight {
  match weight {
    Normal => Normal
    Bold => Bold
    Lighter => Lighter
    Bolder => Bolder
    Weight(value) => Weight(value)
  }
}

///|
fn font_weight_to_msvg(weight : FontWeight) -> @msvg.FontWeight {
  match weight {
    Normal => @msvg.FontWeight::Normal
    Bold => @msvg.FontWeight::Bold
    Lighter => @msvg.FontWeight::Lighter
    Bolder => @msvg.FontWeight::Bolder
    Weight(value) => @msvg.FontWeight::Weight(value)
  }
}

///|
fn font_style_from_msvg(style : @msvg.FontStyle) -> FontStyle {
  match style {
    NormalStyle => NormalStyle
    Italic => Italic
    Oblique => Oblique
  }
}

///|
fn font_style_to_msvg(style : FontStyle) -> @msvg.FontStyle {
  match style {
    NormalStyle => @msvg.FontStyle::NormalStyle
    Italic => @msvg.FontStyle::Italic
    Oblique => @msvg.FontStyle::Oblique
  }
}

///|
fn dominant_baseline_from_msvg(
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
fn dominant_baseline_to_msvg(
  baseline : DominantBaseline,
) -> @msvg.DominantBaseline {
  match baseline {
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
fn paint_order_from_msvg(order : @msvg.PaintOrder) -> PaintOrder {
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
fn paint_order_to_msvg(order : PaintOrder) -> @msvg.PaintOrder {
  let items = match order {
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
fn text_decoration_full_from_msvg(
  decoration : @msvg.TextDecorationFull,
) -> TextDecorationFull {
  {
    line: text_decoration_from_msvg(decoration.line),
    style: text_decoration_style_from_msvg(decoration.style),
    color: Color::from_msvg_option(decoration.color),
    thickness: decoration.thickness,
  }
}

///|
fn text_style_from_msvg(style : @msvg.TextStyle) -> TextStyle {
  {
    font_family: style.font_family,
    font_size: style.font_size,
    font_weight: font_weight_from_msvg(style.font_weight),
    font_style: font_style_from_msvg(style.font_style),
    text_anchor: text_anchor_from_msvg(style.text_anchor),
    dominant_baseline: dominant_baseline_from_msvg(style.dominant_baseline),
    text_decoration: text_decoration_from_msvg(style.text_decoration),
    letter_spacing: style.letter_spacing,
    word_spacing: style.word_spacing,
    line_height: style.line_height,
    writing_mode: writing_mode_from_msvg(style.writing_mode),
    text_orientation: text_orientation_from_msvg(style.text_orientation),
    white_space: white_space_from_msvg(style.white_space),
    paint_order: paint_order_from_msvg(style.paint_order),
  }
}

///|
fn text_style_to_msvg(style : TextStyle) -> @msvg.TextStyle {
  @msvg.TextStyle::{
    font_family: style.font_family,
    font_size: style.font_size,
    font_weight: font_weight_to_msvg(style.font_weight),
    font_style: font_style_to_msvg(style.font_style),
    text_anchor: text_anchor_to_msvg(style.text_anchor),
    dominant_baseline: dominant_baseline_to_msvg(style.dominant_baseline),
    text_decoration: text_decoration_to_msvg(style.text_decoration),
    letter_spacing: style.letter_spacing,
    word_spacing: style.word_spacing,
    line_height: style.line_height,
    writing_mode: writing_mode_to_msvg(style.writing_mode),
    text_orientation: text_orientation_to_msvg(style.text_orientation),
    white_space: white_space_to_msvg(style.white_space),
    paint_order: paint_order_to_msvg(style.paint_order),
  }
}

///|
fn text_span_from_msvg(span : @msvg.TextSpan) -> TextSpan {
  {
    text: span.text,
    x: span.x,
    y: span.y,
    dx: span.dx,
    dy: span.dy,
    style: match span.style {
      Some(style) => Some(text_style_from_msvg(style))
      None => None
    },
  }
}

///|
fn text_span_to_msvg(span : TextSpan) -> @msvg.TextSpan {
  @msvg.TextSpan::{
    text: span.text,
    x: span.x,
    y: span.y,
    dx: span.dx,
    dy: span.dy,
    style: match span.style {
      Some(style) => Some(text_style_to_msvg(style))
      None => None
    },
  }
}

///|
fn text_block_from_msvg(block : @msvg.TextBlock) -> TextBlock {
  {
    spans: block.spans.map(text_span_from_msvg),
    x: block.x,
    y: block.y,
    style: text_style_from_msvg(block.style),
    inline_size: block.inline_size,
    text_overflow: text_overflow_from_msvg(block.text_overflow),
  }
}

///|
fn text_block_to_msvg(block : TextBlock) -> @msvg.TextBlock {
  @msvg.TextBlock::{
    spans: block.spans.map(text_span_to_msvg),
    x: block.x,
    y: block.y,
    style: text_style_to_msvg(block.style),
    inline_size: block.inline_size,
    text_overflow: text_overflow_to_msvg(block.text_overflow),
  }
}

///|
fn use_element_from_msvg(use_element : @msvg.UseElement) -> UseElement {
  {
    href: use_element.href,
    x: use_element.x,
    y: use_element.y,
    width: use_element.width,
    height: use_element.height,
    transform: Transform::from_msvg(use_element.transform),
  }
}

///|
fn use_element_to_msvg(use_element : UseElement) -> @msvg.UseElement {
  @msvg.UseElement::{
    href: use_element.href,
    x: use_element.x,
    y: use_element.y,
    width: use_element.width,
    height: use_element.height,
    transform: use_element.transform.to_msvg(),
  }
}

///|
fn symbol_from_msvg(symbol : @msvg.Symbol) -> Symbol {
  {
    id: symbol.id,
    content: SVGNode::from_msvg(symbol.content),
    view_box: ViewBox::from_msvg_option(symbol.view_box),
    preserve_aspect_ratio: PreserveAspectRatio::default(),
  }
}

///|
fn symbol_to_msvg(symbol : Symbol) -> @msvg.Symbol {
  @msvg.Symbol::{
    id: symbol.id,
    content: symbol.content.to_msvg(),
    view_box: ViewBox::to_msvg_option(symbol.view_box),
    width: None,
    height: None,
    preserve_aspect_ratio: symbol.preserve_aspect_ratio.to_msvg(),
    display_none: false,
  }
}

///|
fn symbol_registry_to_msvg(registry : SymbolRegistry) -> @msvg.SymbolRegistry {
  let converted = @msvg.SymbolRegistry::new()
  registry.symbols.each(fn(_id, symbol) {
    converted.add(symbol_to_msvg(symbol))
  })
  converted
}
