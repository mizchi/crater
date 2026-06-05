///|
/// Text wiring unit: lower a text run into per-glyph
/// `@gfx.DrawTrianglesCommand`s.
///
/// This mirrors kagura's `mizchi/text` wiring role. It reuses crater's
/// existing glyph layout (`@glyph.layout_glyph_bitmaps`, the same path the
/// terminal rasterizer uses) to position glyphs, then emits one quad per
/// glyph ink box in the shared `RenderFrame2D` coordinate space. Its
/// dependencies are `gfx`, the shared `gfx_frame` primitives and the glyph
/// layer (`crater-painter/paint/glyph`).
///
/// Glyph atlas sampling (textured glyph quads via `src_image_ids`) layers
/// on later through `gfx_frame.new_primitive_command`; today the ink box is
/// filled with the text color, driven by real font metrics.

///|
/// Lower a list of positioned glyphs into draw commands. Each glyph with a
/// non-empty ink box becomes one quad at
/// `(x + offset_x, y + offset_y, bitmap.width, bitmap.height)`, matching
/// the box the terminal rasterizer blits.
pub fn glyph_placements_to_commands(
  frame : @gfx_frame.RenderFrame2D,
  placements : Array[@glyph.GlyphPlacement],
  color : @gfx.Color,
) -> Array[@gfx.DrawTrianglesCommand] {
  let commands : Array[@gfx.DrawTrianglesCommand] = []
  for placement in placements {
    let bitmap = placement.bitmap
    if bitmap.width <= 0 || bitmap.height <= 0 {
      continue
    }
    let gx = placement.x + bitmap.offset_x.to_double()
    let gy = placement.y + bitmap.offset_y.to_double()
    let (vertices, indices) = @gfx_frame.ndc_rect_fill_vertices(
      gx,
      gy,
      bitmap.width.to_double(),
      bitmap.height.to_double(),
      frame.screen_w.to_double(),
      frame.screen_h.to_double(),
    )
    commands.push(
      @gfx_frame.new_primitive_command(frame, vertices, indices, color),
    )
  }
  commands
}

///|
/// Lay out `text` with the given glyph provider and lower it into draw
/// commands at pixel position `(x, y)`.
pub fn text_run_commands(
  frame : @gfx_frame.RenderFrame2D,
  provider : @glyph.GlyphProvider,
  text : String,
  x : Int,
  y : Int,
  font_size : Double,
  color : @gfx.Color,
  max_width? : Int = 0,
  line_height? : Double = 0.0,
  is_bold? : Bool = false,
  font_family? : String = "",
  letter_spacing? : Double = 0.0,
  word_spacing? : Double = 0.0,
  font_weight? : Double = 400.0,
) -> Array[@gfx.DrawTrianglesCommand] {
  let (placements, _used_height) = @glyph.layout_glyph_bitmaps(
    provider,
    x,
    y,
    text,
    max_width,
    font_size,
    line_height,
    is_bold,
    font_family~,
    letter_spacing~,
    word_spacing~,
    font_weight~,
  )
  glyph_placements_to_commands(frame, placements, color)
}
