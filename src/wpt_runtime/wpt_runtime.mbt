///|
/// Lightweight JS export for WPT runner.
/// Avoids linking the full JS surface that currently hits compiler ICE.
pub fn renderHtmlToJsonForWpt(
  html : String,
  width : Int,
  height : Int,
) -> String {
  let ctx : @renderer.RenderContext = {
    viewport_width: width.to_double(),
    viewport_height: height.to_double(),
    root_font_size: 16.0,
    color_scheme: @media.ColorScheme::Light,
  }
  let layout = @renderer.render(html, ctx)
  @renderer.layout_to_json(layout)
}
