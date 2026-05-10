///|
// Content-height convenience helpers and layout extent calculation.

///|
/// Get content height with external CSS
pub fn get_content_height_with_css(
  html : String,
  width : Int,
  height : Int,
  external_css : Array[String],
) -> Int {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render_with_external_css(html, ctx, external_css)
  layout.height.to_int()
}

///|
/// Get content height from HTML
pub fn get_content_height(html : String, width : Int, height : Int) -> Int {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render(html, ctx)
  layout.height.to_int()
}

///|
/// Calculate the actual content extent (maximum y + height of all elements)
/// This handles cases where parent has height: 100% but children extend beyond
fn calculate_content_extent(layout : @types.Layout) -> Double {
  // Start with this element's bottom edge
  let mut max_extent = layout.y + layout.height
  // Check all children recursively
  for child in layout.children {
    let child_extent = calculate_content_extent(child)
    if child_extent > max_extent {
      max_extent = child_extent
    }
  }
  max_extent
}

///|
/// Get content height from a parsed Document with external CSS
pub fn get_content_height_with_document(
  doc : @html.Document,
  width : Int,
  height : Int,
  external_css : Array[String],
) -> Int {
  let ctx : RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @css.ColorScheme::Light,
  }
  let layout = render_document_with_external_css(doc, ctx, external_css)
  // Use actual content extent instead of just layout.height
  // This handles height: 100% on body where children extend beyond
  let content_extent = calculate_content_extent(layout)
  content_extent.to_int().max(layout.height.to_int())
}
