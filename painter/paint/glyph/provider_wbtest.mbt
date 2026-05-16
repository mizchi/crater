///|
/// Whitebox tests pinning the numeric font_weight contract on GlyphProvider.
/// Implements: paint.font-weight-numeric (GitHub issue #48).

///|
fn recording_provider_by_weight(
  recorded : Ref[Double],
) -> GlyphProvider {
  {
    get_glyph: fn(_codepoint, _font_size, _is_bold) {
      (([] : Array[@svg.PathCommand]), 4.0)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: Some(fn(_codepoint, _font_size, font_weight) {
      recorded.val = font_weight
      (([] : Array[@svg.PathCommand]), 4.0)
    }),
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
test "glyph_from_provider forwards numeric font_weight 500 without collapsing" {
  let recorded : Ref[Double] = { val: 0.0 }
  let provider = recording_provider_by_weight(recorded)
  let _ = glyph_from_provider(provider, 'A'.to_int(), 16.0, false, "", 500.0)
  inspect(recorded.val, content="500")
}

///|
test "glyph_from_provider forwards numeric font_weight 600 without collapsing" {
  let recorded : Ref[Double] = { val: 0.0 }
  let provider = recording_provider_by_weight(recorded)
  let _ = glyph_from_provider(provider, 'A'.to_int(), 16.0, false, "", 600.0)
  inspect(recorded.val, content="600")
}

///|
test "glyph_from_provider forwards numeric font_weight 400 distinctly from 700" {
  let recorded400 : Ref[Double] = { val: 0.0 }
  let _ = glyph_from_provider(
    recording_provider_by_weight(recorded400),
    'A'.to_int(),
    16.0,
    false,
    "",
    400.0,
  )
  let recorded700 : Ref[Double] = { val: 0.0 }
  let _ = glyph_from_provider(
    recording_provider_by_weight(recorded700),
    'A'.to_int(),
    16.0,
    false,
    "",
    700.0,
  )
  inspect(recorded400.val, content="400")
  inspect(recorded700.val, content="700")
  inspect(recorded400.val != recorded700.val, content="true")
}

///|
fn legacy_bold_provider(
  recorded_bold : Ref[Bool],
) -> GlyphProvider {
  {
    get_glyph: fn(_codepoint, _font_size, is_bold) {
      recorded_bold.val = is_bold
      (([] : Array[@svg.PathCommand]), 4.0)
    },
    get_kern: fn(_left, _right, _font_size, _is_bold) { 0.0 },
    get_glyph_by_weight: None,
    get_kern_by_weight: None,
    ascent_ratio: 0.8,
    get_glyph_for_family: None,
    get_kern_for_family: None,
    get_glyph_for_family_by_weight: None,
    get_kern_for_family_by_weight: None,
    get_ascent_for_family: None,
  }
}

///|
test "legacy bool-only providers still receive is_bold when no by_weight slot" {
  let recorded : Ref[Bool] = { val: false }
  let _ = glyph_from_provider(
    legacy_bold_provider(recorded),
    'A'.to_int(),
    16.0,
    true,
    "",
    700.0,
  )
  inspect(recorded.val, content="true")
}
