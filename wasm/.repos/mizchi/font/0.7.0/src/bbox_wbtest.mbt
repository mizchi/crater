///|
test "compute_path_bbox: empty commands" {
  let bbox = compute_path_bbox([])
  inspect(bbox.x_min, content="0")
  inspect(bbox.y_min, content="0")
  inspect(bbox.x_max, content="0")
  inspect(bbox.y_max, content="0")
}

///|
test "compute_path_bbox: simple rect" {
  let cmds : Array[@svg.PathCommand] = [
    @svg.MoveTo(10.0, 20.0),
    @svg.LineTo(100.0, 20.0),
    @svg.LineTo(100.0, 80.0),
    @svg.LineTo(10.0, 80.0),
    @svg.ClosePath,
  ]
  let bbox = compute_path_bbox(cmds)
  inspect(bbox.x_min, content="10")
  inspect(bbox.y_min, content="20")
  inspect(bbox.x_max, content="100")
  inspect(bbox.y_max, content="80")
}

///|
test "compute_path_bbox: quadratic curve extrema" {
  // Curve from (0,0) to (100,0) with control point at (50,100)
  // y extremum at t=0.5: y = 0.25*0 + 0.5*100 + 0.25*0 = 50
  let cmds : Array[@svg.PathCommand] = [
    @svg.MoveTo(0.0, 0.0),
    @svg.QuadraticCurveTo(50.0, 100.0, 100.0, 0.0),
  ]
  let bbox = compute_path_bbox(cmds)
  inspect(bbox.x_min, content="0")
  inspect(bbox.y_min, content="0")
  inspect(bbox.x_max, content="100")
  // y_max should be 50 (the extremum), ceil'd
  inspect(bbox.y_max, content="50")
}

///|
test "compute_path_bbox: cubic curve extrema" {
  // S-curve from (0,0) to (100,0) with control points creating overshoot
  let cmds : Array[@svg.PathCommand] = [
    @svg.MoveTo(0.0, 0.0),
    @svg.CurveTo(0.0, 80.0, 100.0, -80.0, 100.0, 0.0),
  ]
  let bbox = compute_path_bbox(cmds)
  inspect(bbox.x_min, content="0")
  inspect(bbox.x_max, content="100")
  // y should extend beyond endpoints due to curve overshoot
  assert_true(bbox.y_max > 0)
  assert_true(bbox.y_min < 0)
}

///|
test "CFF font glyph_metrics returns non-zero bbox" {
  // Load a CFF font (OTF with CFF outlines)
  let data = @fs.read_file_to_bytes("fixtures/NotoSans-subset.otf")
  guard parse_font(data) is Some(font) else {
    fail("failed to parse font")
    return
  }
  // Check if this is a CFF font
  guard font.cff is Some(_) else {
    // Skip test if not CFF (this is OK)
    return
  }
  // Get metrics for 'A' (U+0041)
  let gid = font.glyph_index(0x0041)
  if gid > 0 {
    let metrics = font.glyph_metrics(gid)
    // CFF bbox should now be computed from outline, not zero
    let has_outline = font.glyph_outline(gid).length() > 0
    if has_outline {
      assert_true(metrics.bbox.x_max > metrics.bbox.x_min)
      assert_true(metrics.bbox.y_max > metrics.bbox.y_min)
    }
  }
}

///|
test "glyf font glyph_metrics bbox unchanged" {
  // Ensure glyf-based fonts still use the efficient table-based bbox
  let data = @fs.read_file_to_bytes("fixtures/NotoSansMono-Regular.ttf")
  guard parse_font(data) is Some(font) else {
    fail("failed to parse font")
    return
  }
  let gid = font.glyph_index(0x0041) // 'A'
  let metrics = font.glyph_metrics(gid)
  // glyf 'A' should have non-zero bbox from the table
  assert_true(metrics.bbox.x_max > metrics.bbox.x_min)
  assert_true(metrics.bbox.y_max > metrics.bbox.y_min)
}
