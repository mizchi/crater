///|
fn merge_glyph_providers(
  regular : @image.GlyphProvider,
  bold : @image.GlyphProvider?,
) -> @image.GlyphProvider {
  let ascent_ratio = match bold {
    Some(bold_provider) =>
      if bold_provider.ascent_ratio > regular.ascent_ratio {
        bold_provider.ascent_ratio
      } else {
        regular.ascent_ratio
      }
    None => regular.ascent_ratio
  }
  {
    get_glyph: fn(codepoint, font_size, is_bold) {
      if is_bold {
        match bold {
          Some(bold_provider) =>
            (bold_provider.get_glyph)(codepoint, font_size, true)
          None => (regular.get_glyph)(codepoint, font_size, is_bold)
        }
      } else {
        (regular.get_glyph)(codepoint, font_size, is_bold)
      }
    },
    get_kern: fn(cp1, cp2, font_size, is_bold) {
      if is_bold {
        match bold {
          Some(bold_provider) =>
            (bold_provider.get_kern)(cp1, cp2, font_size, true)
          None => (regular.get_kern)(cp1, cp2, font_size, is_bold)
        }
      } else {
        (regular.get_kern)(cp1, cp2, font_size, is_bold)
      }
    },
    ascent_ratio,
    get_glyph_for_family: regular.get_glyph_for_family,
    get_kern_for_family: regular.get_kern_for_family,
    get_ascent_for_family: regular.get_ascent_for_family,
  }
}

///|
fn load_system_glyph_provider() -> @image.GlyphProvider? {
  let (regular_font_data, bold_font_data) = load_system_font_faces()
  if regular_font_data.length() == 0 {
    return None
  }
  let regular_provider = match
    @image.glyph_provider_from_bytes(regular_font_data) {
    Some(provider) => provider
    None => return None
  }
  let bold_provider = if bold_font_data.length() > 0 {
    @image.glyph_provider_from_bytes(bold_font_data)
  } else {
    None
  }
  Some(merge_glyph_providers(regular_provider, bold_provider))
}
