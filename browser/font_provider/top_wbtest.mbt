///|
fn stub_provider(
  missing_codepoint : Int,
  base_advance : Double,
) -> @image.GlyphProvider {
  {
    get_glyph: fn(codepoint, _font_size, _is_bold) {
      if codepoint == missing_codepoint {
        ([], 0.0)
      } else {
        ([], base_advance)
      }
    },
    get_kern: fn(_cp1, _cp2, _font_size, _is_bold) { base_advance / 10.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: base_advance / 10.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
fn weighted_stub_provider(base_advance : Double) -> @image.GlyphProvider {
  {
    get_glyph: fn(_codepoint, _font_size, _is_bold) { ([], base_advance) },
    get_kern: fn(_cp1, _cp2, _font_size, _is_bold) { base_advance / 10.0 },
    get_glyph_by_weight: Some(fn(_codepoint, _font_size, font_weight) {
      ([], font_weight / 100.0)
    }),
    get_kern_by_weight: Some(fn(_cp1, _cp2, _font_size, font_weight) {
      font_weight / 1000.0
    }),
    ascent_ratio: base_advance / 10.0,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
test "system font candidates include broad CJK fallbacks" {
  let mut joined = ""
  for candidate in system_font_face_candidates() {
    let (regular_paths, bold_paths) = candidate
    for path in regular_paths {
      joined = joined + path + "\n"
    }
    for path in bold_paths {
      joined = joined + path + "\n"
    }
  }
  inspect(joined.contains("Arial Unicode"), content="true")
  inspect(joined.contains("NotoSansCJK"), content="true")
}

///|
test "merged providers use bold provider for bold requests" {
  let merged = merge_glyph_provider_pairs([
    (stub_provider(0, 10.0), Some(stub_provider(0, 20.0))),
  ])
  let (_, regular_advance) = (merged.get_glyph)('A'.to_int(), 16.0, false)
  let (_, bold_advance) = (merged.get_glyph)('A'.to_int(), 16.0, true)
  let regular_kern = (merged.get_kern)('A'.to_int(), 'B'.to_int(), 16.0, false)
  let bold_kern = (merged.get_kern)('A'.to_int(), 'B'.to_int(), 16.0, true)
  inspect(regular_advance, content="10")
  inspect(bold_advance, content="20")
  inspect(regular_kern, content="1")
  inspect(bold_kern, content="2")
}

///|
test "merged providers pass numeric weight to underlying provider" {
  let merged = merge_glyph_provider_pairs([(weighted_stub_provider(10.0), None)])
  match merged.get_glyph_by_weight {
    Some(glyph_by_weight) => {
      let (_, medium_advance) = glyph_by_weight('A'.to_int(), 16.0, 500.0)
      inspect(medium_advance, content="5")
    }
    None => fail("merged provider must expose numeric weight glyph hook")
  }
  match merged.get_kern_by_weight {
    Some(kern_by_weight) => {
      let medium_kern = kern_by_weight('A'.to_int(), 'B'.to_int(), 16.0, 500.0)
      inspect(medium_kern, content="0.5")
    }
    None => fail("merged provider must expose numeric weight kern hook")
  }
}

///|
test "merged providers fall back when primary font misses a glyph" {
  let jp = '日'.to_int()
  let merged = merge_glyph_provider_pairs([
    (stub_provider(jp, 10.0), None),
    (stub_provider(0, 20.0), None),
  ])
  let (_, latin_advance) = (merged.get_glyph)('A'.to_int(), 16.0, false)
  let (_, jp_advance) = (merged.get_glyph)(jp, 16.0, false)
  inspect(latin_advance, content="10")
  inspect(jp_advance, content="20")
}
