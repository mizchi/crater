// Shared helpers for taffy compatibility tests

///|
/// Helper for approximate floating point comparison (tolerance: 0.1)
pub fn assert_approx(actual : Double, expected : Double) -> Unit raise {
  let tolerance = 0.1
  let diff = if actual > expected {
    actual - expected
  } else {
    expected - actual
  }
  if diff > tolerance {
    raise Failure::Failure(
      "assert_approx failed: actual=\{actual}, expected=\{expected}, diff=\{diff}",
    )
  }
}
