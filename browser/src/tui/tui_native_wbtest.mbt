///|
test "normalize_native_key maps control and navigation keys" {
  assert_eq(normalize_native_key("\u0004"), "Ctrl-D")
  assert_eq(normalize_native_key("\u0015"), "Ctrl-U")
  assert_eq(normalize_native_key("\u001b[A"), "ArrowUp")
  assert_eq(normalize_native_key("\u001b[B"), "ArrowDown")
  assert_eq(normalize_native_key("\u001b[5~"), "PageUp")
  assert_eq(normalize_native_key("\u001b[6~"), "PageDown")
  assert_eq(normalize_native_key("\u001b[3~"), "Delete")
  assert_eq(normalize_native_key("\u007f"), "Backspace")
  assert_eq(normalize_native_key("\r"), "Enter")
  assert_eq(normalize_native_key("\t"), "Tab")
  assert_eq(normalize_native_key("\u001b[Z"), "Shift-Tab")
  assert_eq(normalize_native_key("\u001b"), "Escape")
}

///|
test "normalize_native_key maps sgr mouse events" {
  assert_eq(normalize_native_key("\u001b[<0;12;8M"), "MouseDown:12,8")
  assert_eq(normalize_native_key("\u001b[<0;12;8m"), "MouseUp:12,8")
  assert_eq(normalize_native_key("\u001b[<35;12;8M"), "MouseMove:12,8")
  assert_eq(normalize_native_key("\u001b[<64;12;8M"), "MouseScrollUp:12,8")
  assert_eq(normalize_native_key("\u001b[<65;12;8M"), "MouseScrollDown:12,8")
}
