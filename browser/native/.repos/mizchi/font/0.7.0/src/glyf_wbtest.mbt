///|
test "contours_to_path_commands - triangle (all on-curve)" {
  let contour : Array[GlyphPoint] = [
    { x: 100, y: 0, on_curve: true },
    { x: 200, y: 200, on_curve: true },
    { x: 0, y: 200, on_curve: true },
  ]
  let cmds = contours_to_path_commands([contour])
  inspect(
    cmds,
    content="[MoveTo(100, 0), LineTo(100, 0), LineTo(200, 200), LineTo(0, 200), ClosePath]",
  )
}

///|
test "contours_to_path_commands - quadratic bezier" {
  // on-curve, off-curve, on-curve
  let contour : Array[GlyphPoint] = [
    { x: 0, y: 0, on_curve: true },
    { x: 50, y: 100, on_curve: false },
    { x: 100, y: 0, on_curve: true },
  ]
  let cmds = contours_to_path_commands([contour])
  inspect(
    cmds,
    content="[MoveTo(0, 0), LineTo(0, 0), QuadraticCurveTo(50, 100, 100, 0), ClosePath]",
  )
}

///|
test "contours_to_path_commands - implicit midpoints" {
  // on-curve, off-curve, off-curve, on-curve
  // Should create implicit on-curve midpoint between two off-curve points
  let contour : Array[GlyphPoint] = [
    { x: 0, y: 0, on_curve: true },
    { x: 50, y: 100, on_curve: false },
    { x: 100, y: 100, on_curve: false },
    { x: 150, y: 0, on_curve: true },
  ]
  let cmds = contours_to_path_commands([contour])
  inspect(
    cmds,
    content="[MoveTo(0, 0), LineTo(0, 0), QuadraticCurveTo(50, 100, 75, 100), QuadraticCurveTo(100, 100, 150, 0), ClosePath]",
  )
}

///|
test "contours_to_path_commands - all off-curve" {
  // All off-curve: should start from midpoint of first and last
  let contour : Array[GlyphPoint] = [
    { x: 100, y: 0, on_curve: false },
    { x: 200, y: 100, on_curve: false },
    { x: 100, y: 200, on_curve: false },
    { x: 0, y: 100, on_curve: false },
  ]
  let cmds = contours_to_path_commands([contour])
  inspect(
    cmds,
    content="[MoveTo(50, 50), QuadraticCurveTo(100, 0, 150, 50), QuadraticCurveTo(200, 100, 150, 150), QuadraticCurveTo(100, 200, 50, 150), QuadraticCurveTo(0, 100, 50, 50), ClosePath]",
  )
}

///|
test "contours_to_path_commands - empty" {
  let cmds = contours_to_path_commands([])
  inspect(cmds, content="[]")
}

///|
test "scale_commands - basic scaling" {
  let commands : Array[@svg.PathCommand] = [
    @svg.MoveTo(100.0, 200.0),
    @svg.LineTo(300.0, 400.0),
    @svg.ClosePath,
  ]
  let scaled = scale_commands(commands, 0.5, false)
  inspect(scaled, content="[MoveTo(50, 100), LineTo(150, 200), ClosePath]")
}

///|
test "scale_commands - with y flip" {
  let commands : Array[@svg.PathCommand] = [
    @svg.MoveTo(100.0, 200.0),
    @svg.LineTo(300.0, 400.0),
    @svg.ClosePath,
  ]
  let scaled = scale_commands(commands, 0.5, true)
  inspect(scaled, content="[MoveTo(50, -100), LineTo(150, -200), ClosePath]")
}
