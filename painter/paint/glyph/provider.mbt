///|
/// Glyph provider contract and provider adapter helpers.

///|
/// Provides glyph outlines and advance widths for text rendering.
pub(all) struct GlyphProvider {
  /// Get SVG path commands for a glyph. Args: (codepoint, font_size, is_bold).
  /// Returns (commands, advance_width).
  get_glyph : (Int, Double, Bool) -> (Array[@svg.PathCommand], Double)
  /// Get kerning adjustment between two codepoints. Args: (cp1, cp2, font_size, is_bold).
  get_kern : (Int, Int, Double, Bool) -> Double
  /// Weight-aware glyph provider. Args: (codepoint, font_size, font_weight).
  get_glyph_by_weight : ((Int, Double, Double) -> (
    Array[@svg.PathCommand],
    Double,
  ))?
  /// Weight-aware kerning. Args: (cp1, cp2, font_size, font_weight).
  get_kern_by_weight : ((Int, Int, Double, Double) -> Double)?
  /// Font ascent in pixels at font_size=1. Multiply by actual font_size.
  ascent_ratio : Double // ascent / units_per_em (e.g. 1854/2048 ~= 0.905)
  /// Multi-font glyph provider. Args: (codepoint, font_size, is_bold, font_family).
  /// Returns (commands, advance_width) or None to fall back to get_glyph.
  get_glyph_for_family : ((Int, Double, Bool, String) -> (
    Array[@svg.PathCommand],
    Double,
  )?)?
  /// Multi-font kerning. Args: (cp1, cp2, font_size, is_bold, font_family).
  get_kern_for_family : ((Int, Int, Double, Bool, String) -> Double)?
  /// Weight-aware multi-font glyph provider.
  get_glyph_for_family_by_weight : ((Int, Double, Double, String) -> (
    Array[@svg.PathCommand],
    Double,
  )?)?
  /// Weight-aware multi-font kerning.
  get_kern_for_family_by_weight : ((Int, Int, Double, Double, String) -> Double)?
  /// Multi-font ascent ratio. Args: (font_family) -> ratio.
  get_ascent_for_family : ((String) -> Double)?
}

///|
let glyph_provider_override : Ref[GlyphProvider?] = { val: None }

///|
pub fn get_glyph_provider() -> GlyphProvider? {
  glyph_provider_override.val
}

///|
pub fn set_glyph_provider(provider : GlyphProvider) -> Unit {
  glyph_provider_override.val = Some(provider)
  clear_glyph_caches()
}

///|
pub fn clear_glyph_provider() -> Unit {
  glyph_provider_override.val = None
  clear_glyph_caches()
}

///|
pub fn glyph_provider_from_delegate(
  delegate : @font_provider.GlyphProvider,
) -> GlyphProvider {
  {
    get_glyph: fn(codepoint, font_size, is_bold) {
      let (commands, advance) = (delegate.get_glyph)(
        codepoint, font_size, is_bold,
      )
      (commands, advance)
    },
    get_kern: fn(cp1, cp2, font_size, is_bold) {
      (delegate.get_kern)(cp1, cp2, font_size, is_bold)
    },
    get_glyph_by_weight: match delegate.get_glyph_by_weight {
      Some(glyph_by_weight) =>
        Some(fn(codepoint, font_size, font_weight) {
          let (commands, advance) = glyph_by_weight(
            codepoint, font_size, font_weight,
          )
          (commands, advance)
        })
      None => None
    },
    get_kern_by_weight: match delegate.get_kern_by_weight {
      Some(kern_by_weight) =>
        Some(fn(cp1, cp2, font_size, font_weight) {
          kern_by_weight(cp1, cp2, font_size, font_weight)
        })
      None => None
    },
    ascent_ratio: delegate.ascent_ratio,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
/// Create a GlyphProvider from a parsed TTFont.
/// This allows native text rendering without JS FFI.
pub fn glyph_provider_from_font(font : @font.TTFont) -> GlyphProvider {
  glyph_provider_from_delegate(@font_provider.glyph_provider_from_font(font))
}

///|
/// Parse font bytes and create a GlyphProvider.
/// Returns None if font parsing fails.
pub fn glyph_provider_from_bytes(data : Bytes) -> GlyphProvider? {
  match @font_provider.glyph_provider_from_bytes(data) {
    Some(provider) => Some(glyph_provider_from_delegate(provider))
    None => None
  }
}

///|
pub fn resolve_effective_font_weight(
  is_bold : Bool,
  font_weight : Double,
) -> Double {
  if font_weight != 400.0 || !is_bold {
    font_weight
  } else {
    700.0
  }
}

///|
pub fn is_bold_font_weight(font_weight : Double) -> Bool {
  font_weight >= 600.0
}

///|
fn glyph_from_provider(
  provider : GlyphProvider,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
  font_weight : Double,
) -> (Array[@svg.PathCommand], Double) {
  match provider.get_glyph_for_family_by_weight {
    Some(glyph_fn) if font_family.length() > 0 =>
      match glyph_fn(codepoint, font_size, font_weight, font_family) {
        Some(r) => return r
        None => ()
      }
    _ => ()
  }
  match provider.get_glyph_for_family {
    Some(glyph_fn) if font_family.length() > 0 =>
      match glyph_fn(codepoint, font_size, is_bold, font_family) {
        Some(r) => return r
        None => ()
      }
    _ => ()
  }
  match provider.get_glyph_by_weight {
    Some(glyph_fn) => glyph_fn(codepoint, font_size, font_weight)
    None => (provider.get_glyph)(codepoint, font_size, is_bold)
  }
}

///|
pub fn kern_from_provider(
  provider : GlyphProvider,
  cp1 : Int,
  cp2 : Int,
  font_size : Double,
  is_bold : Bool,
  font_family : String,
  font_weight : Double,
) -> Double {
  match provider.get_kern_for_family_by_weight {
    Some(kern_fn) if font_family.length() > 0 =>
      return kern_fn(cp1, cp2, font_size, font_weight, font_family)
    _ => ()
  }
  match provider.get_kern_for_family {
    Some(kern_fn) if font_family.length() > 0 =>
      return kern_fn(cp1, cp2, font_size, is_bold, font_family)
    _ => ()
  }
  match provider.get_kern_by_weight {
    Some(kern_fn) => kern_fn(cp1, cp2, font_size, font_weight)
    None => (provider.get_kern)(cp1, cp2, font_size, is_bold)
  }
}

///|
fn get_advance(
  provider : GlyphProvider,
  codepoint : Int,
  font_size : Double,
  is_bold : Bool,
  font_family? : String = "",
  font_weight? : Double = 400.0,
) -> Double {
  let effective_font_weight = resolve_effective_font_weight(
    is_bold, font_weight,
  )
  let effective_is_bold = is_bold || is_bold_font_weight(effective_font_weight)
  let (_, advance) = glyph_from_provider(
    provider, codepoint, font_size, effective_is_bold, font_family, effective_font_weight,
  )
  advance
}
