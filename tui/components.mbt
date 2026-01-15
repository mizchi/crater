///|
/// Component builders for TUI
/// Provides ink-like API for building reactive UI trees

///|
/// Component represents a renderable UI element with its layout, style, and content
pub struct Component {
  node : @node.Node
  styles : RenderStyleMap
  texts : TextContentMap
}

// Global ID counter for unique component IDs

///|
let component_id_counter : Ref[Int] = { val: 0 }

///|
fn next_id() -> String {
  let id = component_id_counter.val
  component_id_counter.val = id + 1
  "c" + id.to_string()
}

///|
/// Merge two components (for combining children)
fn merge_components(
  comps : Array[Component],
) -> (RenderStyleMap, TextContentMap) {
  let styles = RenderStyleMap::new()
  let texts = TextContentMap::new()
  for comp in comps {
    // Copy styles
    for entry in comp.styles.0 {
      styles.set(entry.0, entry.1)
    }
    // Copy texts
    for entry in comp.texts.0 {
      texts.set(entry.0, entry.1)
    }
  }
  (styles, texts)
}

///|
/// Box component options
pub(all) struct BoxOptions {
  // Layout
  width : @types.Dimension
  height : @types.Dimension
  min_width : @types.Dimension
  min_height : @types.Dimension
  max_width : @types.Dimension
  max_height : @types.Dimension
  flex_grow : Double
  flex_shrink : Double
  flex_basis : @types.Dimension
  flex_direction : @style.FlexDirection
  flex_wrap : @style.FlexWrap
  justify_content : @style.Alignment
  align_items : @style.Alignment
  align_content : @style.Alignment
  gap : Double
  padding : Double
  padding_x : Double
  padding_y : Double
  margin : Double
  margin_x : Double
  margin_y : Double
  // Style
  border : BorderChars?
  border_color : Color
  bg : Color
  fg : Color
}

///|
pub fn BoxOptions::default() -> BoxOptions {
  {
    width: @types.Dimension::Auto,
    height: @types.Dimension::Auto,
    min_width: @types.Dimension::Auto,
    min_height: @types.Dimension::Auto,
    max_width: @types.Dimension::Auto,
    max_height: @types.Dimension::Auto,
    flex_grow: 0.0,
    flex_shrink: 1.0,
    flex_basis: @types.Dimension::Auto,
    flex_direction: @style.FlexDirection::Row,
    flex_wrap: @style.FlexWrap::NoWrap,
    justify_content: @style.Alignment::FlexStart,
    align_items: @style.Alignment::Stretch,
    align_content: @style.Alignment::Stretch,
    gap: 0.0,
    padding: 0.0,
    padding_x: 0.0,
    padding_y: 0.0,
    margin: 0.0,
    margin_x: 0.0,
    margin_y: 0.0,
    border: None,
    border_color: Color::white(),
    bg: Color::transparent(),
    fg: Color::white(),
  }
}

///|
/// Create a box component
pub fn box_(options : BoxOptions, children : Array[Component]) -> Component {
  let id = next_id()

  // Merge children's styles and texts
  let (styles, texts) = merge_components(children)

  // Calculate padding (with x/y overrides)
  let pad_left = if options.padding_x > 0.0 {
    options.padding_x
  } else {
    options.padding
  }
  let pad_right = pad_left
  let pad_top = if options.padding_y > 0.0 {
    options.padding_y
  } else {
    options.padding
  }
  let pad_bottom = pad_top

  // Calculate margin (with x/y overrides)
  let margin_left = if options.margin_x > 0.0 {
    options.margin_x
  } else {
    options.margin
  }
  let margin_right = margin_left
  let margin_top = if options.margin_y > 0.0 {
    options.margin_y
  } else {
    options.margin
  }
  let margin_bottom = margin_top

  // Build style based on default with overrides
  let style = @style.Style::default()
  style.display = @style.Display::Flex
  style.flex_direction = options.flex_direction
  style.flex_wrap = options.flex_wrap
  style.justify_content = options.justify_content
  style.align_items = options.align_items
  style.align_content = options.align_content
  style.flex_grow = options.flex_grow
  style.flex_shrink = options.flex_shrink
  style.flex_basis = options.flex_basis
  style.width = options.width
  style.height = options.height
  style.min_width = options.min_width
  style.min_height = options.min_height
  style.max_width = options.max_width
  style.max_height = options.max_height
  style.row_gap = @types.Dimension::Length(options.gap)
  style.column_gap = @types.Dimension::Length(options.gap)
  style.padding = @types.Rect::new(
    @types.Dimension::Length(pad_top),
    @types.Dimension::Length(pad_right),
    @types.Dimension::Length(pad_bottom),
    @types.Dimension::Length(pad_left),
  )
  style.margin = @types.Rect::new(
    @types.Dimension::Length(margin_top),
    @types.Dimension::Length(margin_right),
    @types.Dimension::Length(margin_bottom),
    @types.Dimension::Length(margin_left),
  )
  // Add border padding if border is present
  if options.border is Some(_) {
    style.border = @types.Rect::new(
      @types.Dimension::Length(1.0),
      @types.Dimension::Length(1.0),
      @types.Dimension::Length(1.0),
      @types.Dimension::Length(1.0),
    )
  }

  // Build node
  let child_nodes = children.map(fn(c) { c.node })
  let node = @node.Node::new(id, style, child_nodes)

  // Add this box's style
  styles.set(id, {
    fg: options.fg,
    bg: options.bg,
    bold: false,
    underline: false,
    border: options.border,
    border_fg: options.border_color,
  })
  { node, styles, texts }
}

///|
/// Text component options
pub(all) struct TextOptions {
  fg : Color
  bg : Color
  bold : Bool
  underline : Bool
}

///|
pub fn TextOptions::default() -> TextOptions {
  {
    fg: Color::white(),
    bg: Color::transparent(),
    bold: false,
    underline: false,
  }
}

///|
/// Create a text component
pub fn text(content : String, options : TextOptions) -> Component {
  let id = next_id()

  // Build style for text measurement
  let style = @style.Style::default()

  // Build node with measure function
  let node = @node.Node::with_measure(id, style, text_measure_func(content))

  // Create style and text maps
  let styles = RenderStyleMap::new()
  let texts = TextContentMap::new()
  styles.set(id, {
    fg: options.fg,
    bg: options.bg,
    bold: options.bold,
    underline: options.underline,
    border: None,
    border_fg: Color::white(),
  })
  texts.set(id, content)
  { node, styles, texts }
}

///|
/// Create simple text with default options
pub fn text_(content : String) -> Component {
  text(content, TextOptions::default())
}

///|
/// Create a styled text (convenience function)
pub fn styled_text(
  content : String,
  fg? : Color = Color::white(),
  bg? : Color = Color::transparent(),
  bold? : Bool = false,
  underline? : Bool = false,
) -> Component {
  text(content, { fg, bg, bold, underline })
}

///|
/// Spacer component - flexible empty space
pub fn spacer(flex_grow? : Double = 1.0) -> Component {
  let id = next_id()
  let style = @style.Style::default()
  style.flex_grow = flex_grow
  let node = @node.Node::new(id, style, [])
  { node, styles: RenderStyleMap::new(), texts: TextContentMap::new() }
}
