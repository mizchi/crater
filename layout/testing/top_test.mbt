///|
test "layout testing package toggles inline text advance ratio hook" {
  @testing.set_builtin_text_advance_ratio(1.0)
  @testing.clear_builtin_text_advance_ratio()
}
