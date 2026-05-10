///|
// Text node construction helpers.

///|
/// Create a node for text content with inherited font properties
fn create_text_node(text : String, parent_style : @style.Style) -> @node.Node {
  let normalized_text = if parent_style.display == @types.TableCell &&
    has_line_break_char(text) {
    trim_trailing_collapsible_whitespace(text)
  } else {
    text
  }
  let trimmed = trim_collapsible_whitespace_edges(normalized_text)
  let font_size = parent_style.font_size
  let font_weight = parent_style.font_weight
  let font_family = parent_style.font_family
  let text_line_height = parent_style.line_height
  let white_space = parent_style.white_space
  let writing_mode = parent_style.writing_mode
  let ls = parent_style.letter_spacing
  let ws = parent_style.word_spacing
  // Create text style with inherited font properties and color for rendering
  // Text nodes should be inline-level to flow with other inline content
  let text_style : @style.Style = {
    ..@style.Style::default(),
    display: @types.Inline,
    font_size,
    font_weight,
    font_family,
    line_height: text_line_height,
    white_space,
    writing_mode,
    direction: parent_style.direction,
    letter_spacing: ls,
    word_spacing: ws,
    color: parent_style.color,
    text_decoration_underline: parent_style.text_decoration_underline,
    text_decoration_line_through: parent_style.text_decoration_line_through,
    text_decoration_overline: parent_style.text_decoration_overline,
  }
  if trimmed.is_empty() {
    // Preserve collapsible whitespace as a single space so inline-block gaps match browser layout.
    if text.is_empty() {
      @node.Node::leaf("#text", @style.Style::default())
    } else {
      // Indentation-only whitespace in block formatting contexts should not
      // create measurable text runs. Keep whitespace for inline/flex/grid/
      // contents contexts where it can participate in layout.
      let keep_ws = match parent_style.display {
        @types.Inline
        | @types.InlineBlock
        | @types.Flex
        | @types.InlineFlex
        | @types.Grid
        | @types.InlineGrid
        | @types.Contents => true
        _ => false
      }
      if !keep_ws {
        return @node.Node::leaf("#text", @style.Style::default())
      }
      let collapsed = " "
      @node.Node::text(
        "#text",
        text_style,
        create_text_measure_with_provider(
          collapsed,
          font_size,
          text_line_height,
          white_space,
          writing_mode,
          font_weight~,
          font_family~,
          letter_spacing=ls,
          word_spacing=ws,
        ),
        collapsed,
      )
    }
  } else {
    // Use Node::text to store the text content for rendering
    @node.Node::text(
      "#text",
      text_style,
      create_text_measure_with_provider(
        normalized_text,
        font_size,
        text_line_height,
        white_space,
        writing_mode,
        font_weight~,
        font_family~,
        letter_spacing=ls,
        word_spacing=ws,
      ),
      normalized_text,
    )
  }
}
