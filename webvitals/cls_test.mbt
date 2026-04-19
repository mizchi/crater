///|
test "CLS: element shift calculation" {
  // Example from web.dev: element occupies 50% of viewport,
  // moves down by 25% of viewport height
  let viewport = @types.Size::new(800.0, 600.0)

  // Before: element at top, 50% height
  let before = @types.BoundingRect::new(0.0, 0.0, 800.0, 300.0)
  // After: element moved down by 25% (150px)
  let after = @types.BoundingRect::new(0.0, 150.0, 800.0, 300.0)
  let shift = compute_element_shift(before, after, viewport)

  // Impact fraction: union covers 75% of viewport (0 to 450 = 450/600 height)
  // Union: x=0, y=0, width=800, height=450
  // Area = 800 * 450 = 360000
  // Viewport area = 800 * 600 = 480000
  // Impact = 360000 / 480000 = 0.75
  inspect(shift.impact_fraction, content="0.75")

  // Distance fraction: moved 150px / 800 (max viewport dim) = 0.1875
  inspect(shift.distance_fraction, content="0.1875")

  // Score: 0.75 * 0.1875 = 0.140625
  inspect(shift.score, content="0.140625")
}

///|
test "CLS: no movement = zero score" {
  let viewport = @types.Size::new(1920.0, 1080.0)
  let rect = @types.BoundingRect::new(100.0, 100.0, 200.0, 150.0)
  let shift = compute_element_shift(rect, rect, viewport)
  inspect(shift.distance_fraction, content="0")
  inspect(shift.score, content="0")
}

///|
test "CLS: total score for multiple elements" {
  let viewport = @types.Size::new(1000.0, 1000.0)
  let before = [
    @types.BoundingRect::new(0.0, 0.0, 500.0, 200.0),
    @types.BoundingRect::new(0.0, 200.0, 500.0, 200.0),
  ]
  let after = [
    @types.BoundingRect::new(0.0, 100.0, 500.0, 200.0), // moved down 100px
    @types.BoundingRect::new(0.0, 300.0, 500.0, 200.0), // moved down 100px
  ]
  let total = compute_total(before, after, viewport)
  // Both elements shifted, total should be sum of individual scores
  inspect(total > 0.0, content="true")
}
