///|
/// Glyph bitmap cache and cache warming helpers.

///|
/// Bitmap cache for rasterized glyphs.
/// Key: "cp:fs_int:weight:bold:family" -> GlyphBitmap
let glyph_bitmap_cache : Ref[Map[String, GlyphBitmap]] = { val: {} }

///|
/// Cache for parsed glyph path commands (still used for advance width).
/// Key: "cp:fs_int:bold" -> (commands, advance)
let glyph_cache : Ref[Map[String, (Array[@svg.PathCommand], Double)]] = {
  val: {},
}

///|
fn glyph_cache_key(
  cp : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
  font_weight? : Double = 400.0,
) -> String {
  let bold_flag = if is_bold { 1 } else { 0 }
  let fs_key = (font_size * 10.0).to_int()
  let weight_key = font_weight.to_int()
  cp.to_string() +
  ":" +
  fs_key.to_string() +
  ":" +
  weight_key.to_string() +
  ":" +
  bold_flag.to_string() +
  ":" +
  font_family
}

///|
fn clear_glyph_caches() -> Unit {
  glyph_cache.val = {}
  glyph_bitmap_cache.val = {}
}

///|
fn cached_glyph_bitmap(
  provider : GlyphProvider,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
  font_weight : Double,
  baseline_offset : Double,
) -> GlyphBitmap {
  let cache_key = glyph_cache_key(
    codepoint,
    font_size,
    is_bold,
    font_family,
    font_weight~,
  )
  match glyph_bitmap_cache.val.get(cache_key) {
    Some(bm) => bm
    None => {
      let (commands, advance) = glyph_from_provider(
        provider, codepoint, font_size, is_bold, font_family, font_weight,
      )
      let translated = translate_path_commands(commands, 0.0, baseline_offset)
      let bm = rasterize_glyph_to_bitmap(translated, advance)
      glyph_bitmap_cache.val.set(cache_key, bm)
      bm
    }
  }
}

///|
/// Pre-rasterize common ASCII glyphs at given font sizes.
/// Call after set_glyph_provider to warm the bitmap cache.
pub fn pre_rasterize_glyphs(
  font_sizes : Array[Double],
  font_family? : String = "",
) -> Int {
  let provider = match glyph_provider_override.val {
    Some(p) => p
    None => return 0
  }
  let mut count = 0
  for fs in font_sizes {
    let baseline_offset = match provider.get_ascent_for_family {
      Some(get_ascent) if font_family.length() > 0 =>
        get_ascent(font_family) * fs
      _ => provider.ascent_ratio * fs
    }
    for cp = 32; cp <= 126; cp = cp + 1 {
      let key = glyph_cache_key(cp, fs, false, font_family, font_weight=400.0)
      if glyph_bitmap_cache.val.get(key) is None {
        let _ = cached_glyph_bitmap(
          provider, cp, fs, false, font_family, 400.0, baseline_offset,
        )
        count = count + 1
      }
    }
  }
  count
}
