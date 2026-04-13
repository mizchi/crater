///|
/// Test-only hook for deterministic inline text measurement.
pub fn set_builtin_text_advance_ratio(ratio : Double) -> Unit {
  @inline.set_builtin_text_advance_ratio(ratio)
}

///|
/// Clear the deterministic inline text measurement hook.
pub fn clear_builtin_text_advance_ratio() -> Unit {
  @inline.clear_builtin_text_advance_ratio()
}
