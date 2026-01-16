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
/// Create a box component
pub fn box(
  children : Array[Component],
  // ID
  id? : String = "",
  // Layout
  width? : @types.Dimension = @types.Dimension::Auto,
  height? : @types.Dimension = @types.Dimension::Auto,
  min_width? : @types.Dimension = @types.Dimension::Auto,
  min_height? : @types.Dimension = @types.Dimension::Auto,
  max_width? : @types.Dimension = @types.Dimension::Auto,
  max_height? : @types.Dimension = @types.Dimension::Auto,
  flex_grow? : Double = 0.0,
  flex_shrink? : Double = 1.0,
  flex_basis? : @types.Dimension = @types.Dimension::Auto,
  flex_direction? : @style.FlexDirection = @style.FlexDirection::Row,
  flex_wrap? : @style.FlexWrap = @style.FlexWrap::NoWrap,
  justify_content? : @style.Alignment = @style.Alignment::FlexStart,
  align_items? : @style.Alignment = @style.Alignment::Stretch,
  align_content? : @style.Alignment = @style.Alignment::Stretch,
  gap? : Double = 0.0,
  padding? : Double = 0.0,
  padding_x? : Double = 0.0,
  padding_y? : Double = 0.0,
  margin? : Double = 0.0,
  margin_x? : Double = 0.0,
  margin_y? : Double = 0.0,
  // Style
  border? : BorderChars? = None,
  border_color? : Color = Color::white(),
  bg? : Color = Color::transparent(),
  fg? : Color = Color::white(),
) -> Component {
  let actual_id = if id == "" { next_id() } else { id }

  // Merge children's styles and texts
  let (styles, texts) = merge_components(children)

  // Calculate padding (with x/y overrides)
  let pad_left = if padding_x > 0.0 { padding_x } else { padding }
  let pad_right = pad_left
  let pad_top = if padding_y > 0.0 { padding_y } else { padding }
  let pad_bottom = pad_top

  // Calculate margin (with x/y overrides)
  let margin_left = if margin_x > 0.0 { margin_x } else { margin }
  let margin_right = margin_left
  let margin_top = if margin_y > 0.0 { margin_y } else { margin }
  let margin_bottom = margin_top

  // Build style based on default with overrides
  let style = @style.Style::default()
  style.display = @style.Display::Flex
  style.flex_direction = flex_direction
  style.flex_wrap = flex_wrap
  style.justify_content = justify_content
  style.align_items = align_items
  style.align_content = align_content
  style.flex_grow = flex_grow
  style.flex_shrink = flex_shrink
  style.flex_basis = flex_basis
  style.width = width
  style.height = height
  style.min_width = min_width
  style.min_height = min_height
  style.max_width = max_width
  style.max_height = max_height
  style.row_gap = @types.Dimension::Length(gap)
  style.column_gap = @types.Dimension::Length(gap)
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
  if border is Some(_) {
    style.border = @types.Rect::new(
      @types.Dimension::Length(1.0),
      @types.Dimension::Length(1.0),
      @types.Dimension::Length(1.0),
      @types.Dimension::Length(1.0),
    )
  }

  // Build node
  let child_nodes = children.map(fn(c) { c.node })
  let node = @node.Node::new(actual_id, style, child_nodes)

  // Add this box's style
  styles.set(actual_id, {
    fg,
    bg,
    bold: false,
    underline: false,
    border,
    border_fg: border_color,
  })
  { node, styles, texts }
}

///|
/// Create a text component
pub fn text(
  content : String,
  fg? : Color = Color::white(),
  bg? : Color = Color::transparent(),
  bold? : Bool = false,
  underline? : Bool = false,
) -> Component {
  let id = next_id()

  // Build style for text measurement
  let style = @style.Style::default()

  // Build node with measure function
  let node = @node.Node::with_measure(id, style, text_measure_func(content))

  // Create style and text maps
  let styles = RenderStyleMap::new()
  let texts = TextContentMap::new()
  styles.set(id, {
    fg,
    bg,
    bold,
    underline,
    border: None,
    border_fg: Color::white(),
  })
  texts.set(id, content)
  { node, styles, texts }
}

///|
/// Create a styled text (alias for text with labeled arguments)
pub fn styled_text(
  content : String,
  fg? : Color = Color::white(),
  bg? : Color = Color::transparent(),
  bold? : Bool = false,
  underline? : Bool = false,
) -> Component {
  text(content, fg~, bg~, bold~, underline~)
}

///|
/// Create a box with text content that wraps within the box's bounds
/// Unlike text(), this renders the text directly within the box's layout dimensions
pub fn text_box(
  content : String,
  // ID
  id? : String = "",
  // Size
  width? : @types.Dimension = @types.Dimension::Auto,
  height? : @types.Dimension = @types.Dimension::Auto,
  min_width? : @types.Dimension = @types.Dimension::Auto,
  min_height? : @types.Dimension = @types.Dimension::Auto,
  max_width? : @types.Dimension = @types.Dimension::Auto,
  max_height? : @types.Dimension = @types.Dimension::Auto,
  // Flex properties
  flex_grow? : Double = 0.0,
  flex_shrink? : Double = 1.0,
  flex_basis? : @types.Dimension = @types.Dimension::Auto,
  // Padding & Margin
  padding? : Double = 0.0,
  padding_x? : Double = 0.0,
  padding_y? : Double = 0.0,
  margin? : Double = 0.0,
  margin_x? : Double = 0.0,
  margin_y? : Double = 0.0,
  // Border
  border? : BorderChars? = None,
  border_color? : Color = Color::white(),
  // Style
  bg? : Color = Color::transparent(),
  fg? : Color = Color::white(),
  bold? : Bool = false,
  underline? : Bool = false,
) -> Component {
  let actual_id = if id == "" { next_id() } else { id }

  // Build style
  let style = @style.Style::default()
  style.width = width
  style.height = height
  style.min_width = min_width
  style.min_height = min_height
  style.max_width = max_width
  style.max_height = max_height
  style.flex_grow = flex_grow
  style.flex_shrink = flex_shrink
  style.flex_basis = flex_basis
  // Padding
  let pad = padding
  let pad_x = if padding_x > 0.0 { padding_x } else { pad }
  let pad_y = if padding_y > 0.0 { padding_y } else { pad }
  style.padding = @types.Rect::new(
    @types.Dimension::Length(pad_y),
    @types.Dimension::Length(pad_x),
    @types.Dimension::Length(pad_y),
    @types.Dimension::Length(pad_x),
  )
  // Margin
  let mar = margin
  let mar_x = if margin_x > 0.0 { margin_x } else { mar }
  let mar_y = if margin_y > 0.0 { margin_y } else { mar }
  style.margin = @types.Rect::new(
    @types.Dimension::Length(mar_y),
    @types.Dimension::Length(mar_x),
    @types.Dimension::Length(mar_y),
    @types.Dimension::Length(mar_x),
  )

  // Build node (no children, text rendered directly in this box)
  let node = @node.Node::new(actual_id, style, [])

  // Create style and text maps
  let styles = RenderStyleMap::new()
  let texts = TextContentMap::new()
  styles.set(actual_id, {
    fg,
    bg,
    bold,
    underline,
    border,
    border_fg: border_color,
  })
  texts.set(actual_id, content)
  { node, styles, texts }
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
