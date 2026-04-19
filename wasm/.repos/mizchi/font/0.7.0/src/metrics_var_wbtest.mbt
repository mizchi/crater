///|
test "glyph_metrics_at: non-variable font returns same as glyph_metrics" {
  let data = @fs.read_file_to_bytes("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font)
  let gid = font.glyph_index(0x41) // 'A'
  let static_m = font.glyph_metrics(gid)
  let var_m = font.glyph_metrics_at(gid, {})
  inspect(var_m.advance_width, content=static_m.advance_width.to_string())
  inspect(
    var_m.left_side_bearing,
    content=static_m.left_side_bearing.to_string(),
  )
  inspect(var_m.bbox.x_min, content=static_m.bbox.x_min.to_string())
}

///|
test "glyph_metrics_at: gvar default instance matches static" {
  let data = Bytes::from_array(minimal_gvar_ttf[:])
  guard parse_font(data) is Some(font)
  let gid = font.glyph_index(0x41)
  let static_m = font.glyph_metrics(gid)
  let var_m = font.glyph_metrics_at(gid, { "wght": 400.0 })
  // Advance should be same at default
  inspect(var_m.advance_width, content=static_m.advance_width.to_string())
}

///|
test "glyph_metrics_at: gvar bold instance has different bbox" {
  let data = Bytes::from_array(minimal_gvar_ttf[:])
  guard parse_font(data) is Some(font)
  let gid = font.glyph_index(0x41)
  let default_m = font.glyph_metrics_at(gid, { "wght": 400.0 })
  let bold_m = font.glyph_metrics_at(gid, { "wght": 900.0 })
  // Bold 'A' has Y peak +100 (700 -> 800), so y_max should differ
  assert_true(bold_m.bbox.y_max > default_m.bbox.y_max)
}

///|
test "glyph_metrics_at: gvar mid instance interpolates bbox" {
  let data = Bytes::from_array(minimal_gvar_ttf[:])
  guard parse_font(data) is Some(font)
  let gid = font.glyph_index(0x41)
  let default_m = font.glyph_metrics_at(gid, { "wght": 400.0 })
  let mid_m = font.glyph_metrics_at(gid, { "wght": 650.0 })
  let bold_m = font.glyph_metrics_at(gid, { "wght": 900.0 })
  // Mid bbox should be between default and bold
  assert_true(mid_m.bbox.y_max >= default_m.bbox.y_max)
  assert_true(mid_m.bbox.y_max <= bold_m.bbox.y_max)
}

///|
test "glyph_metrics_at: CFF font computes bbox" {
  let data = @fs.read_file_to_bytes("fixtures/NotoSans-subset.otf")
  guard parse_font(data) is Some(font)
  guard font.cff is Some(_)
  let gid = font.glyph_index(0x41)
  if gid > 0 {
    let m = font.glyph_metrics_at(gid, {})
    let outline = font.glyph_outline(gid)
    if outline.length() > 0 {
      assert_true(m.bbox.x_max > m.bbox.x_min)
    }
  }
}

///|
test "glyph_metrics_at: CFF2 var font computes variable bbox" {
  let data = @fs.read_file_to_bytes("fixtures/minimal-cff2-var.otf")
  guard parse_font(data) is Some(font)
  guard font.cff is Some(cff) && cff.ivs is Some(_)
  let gid = font.glyph_index(0x41)
  if gid > 0 {
    let default_m = font.glyph_metrics_at(gid, {})
    let bold_m = font.glyph_metrics_at(gid, { "wght": 900.0 })
    // Both should have valid bbox
    let has_outline = font.glyph_outline(gid).length() > 0
    if has_outline {
      assert_true(default_m.bbox.x_max > default_m.bbox.x_min)
      assert_true(bold_m.bbox.x_max > bold_m.bbox.x_min)
    }
  }
}
