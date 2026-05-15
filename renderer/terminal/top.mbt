///|
fn default_render_context(width : Int, height : Int) -> @renderer.RenderContext {
  {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
}

///|
/// Render HTML to Sixel string (legacy, depth-based colors).
pub fn render_to_sixel(html : String, width : Int, height : Int) -> String {
  let layout = @renderer.render(html, default_render_context(width, height))
  @sixel.render_layout(layout, width, height)
}

///|
/// Render HTML to Sixel string with actual CSS colors.
pub fn render_to_sixel_with_styles(
  html : String,
  width : Int,
  height : Int,
) -> String {
  render_to_sixel_with_scroll(html, width, height, 0)
}

///|
/// Render HTML to Sixel string with actual CSS colors and scroll offset.
pub fn render_to_sixel_with_scroll(
  html : String,
  width : Int,
  height : Int,
  scroll_y : Int,
) -> String {
  render_to_sixel_with_css(html, width, height, scroll_y, [])
}

///|
/// Render HTML to Sixel with external CSS and scroll offset.
pub fn render_to_sixel_with_css(
  html : String,
  width : Int,
  height : Int,
  scroll_y : Int,
  external_css : Array[String],
) -> String {
  let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
    html,
    default_render_context(width, height),
    external_css,
  )
  @sixel.render_with_styles_scrolled(node, layout, width, height, scroll_y)
}

///|
/// Render HTML to Kitty graphics output with external CSS and scroll offset.
pub fn render_to_kitty_with_css(
  html : String,
  width : Int,
  height : Int,
  scroll_y : Int,
  external_css : Array[String],
) -> String {
  let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
    html,
    default_render_context(width, height),
    external_css,
  )
  let paint_node = @paint_node.from_node_and_layout(node, layout)
  @kitty.render_paint_node_to_kitty_scrolled(
    paint_node, width, height, scroll_y,
  )
}

///|
pub async fn[T : @io.Writer] write_kitty_with_css(
  writer : T,
  html : String,
  width : Int,
  height : Int,
  scroll_y : Int,
  external_css : Array[String],
) -> Unit {
  let (node, layout) = @renderer.render_to_node_and_layout_with_external_css(
    html,
    default_render_context(width, height),
    external_css,
  )
  let paint_node = @paint_node.from_node_and_layout(node, layout)
  @kitty.write_paint_node_to_kitty_scrolled(
    writer, paint_node, width, height, scroll_y,
  )
}
