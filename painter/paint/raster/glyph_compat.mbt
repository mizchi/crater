///|
/// Compatibility facade for glyph provider APIs.
/// Prefer `mizchi/crater-painter/paint/glyph` for new code.

///|
pub using @glyph {type GlyphProvider}

///|
pub fn set_glyph_provider(provider : @glyph.GlyphProvider) -> Unit {
  @glyph.set_glyph_provider(provider)
}

///|
pub fn clear_glyph_provider() -> Unit {
  @glyph.clear_glyph_provider()
}

///|
pub fn glyph_provider_from_delegate(
  delegate : @glyph_provider.GlyphProvider,
) -> @glyph.GlyphProvider {
  @glyph.glyph_provider_from_delegate(delegate)
}

///|
pub fn glyph_provider_from_font(font : @font.TTFont) -> @glyph.GlyphProvider {
  @glyph.glyph_provider_from_font(font)
}

///|
pub fn glyph_provider_from_bytes(data : Bytes) -> @glyph.GlyphProvider? {
  @glyph.glyph_provider_from_bytes(data)
}

///|
pub fn pre_rasterize_glyphs(
  font_sizes : Array[Double],
  font_family? : String = "",
) -> Int {
  @glyph.pre_rasterize_glyphs(font_sizes, font_family~)
}
