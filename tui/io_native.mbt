///|
/// I/O implementation for native target (stub)
/// Note: Full async I/O requires FFI to native libraries

///|
/// Read a key (stub - returns 'q' immediately)
pub fn read_key() -> String {
  "q"
}

///|
/// Print string to stdout (no newline)
/// Note: Native MoonBit doesn't have print without newline, using println
pub fn print_raw(s : String) -> Unit {
  println(s)
}

///|
/// Cleanup stdin state (stub)
pub fn cleanup_stdin() -> Unit {
  // No-op for native
}

///|
/// Enable raw mode (stub)
pub fn enable_raw_mode() -> Unit {
  // No-op for native
}

///|
/// Get terminal size (default values)
pub fn get_terminal_size() -> (Int, Int) {
  (80, 24)
}

///|
/// Sleep for milliseconds (stub - immediate return)
pub fn sleep(_ms : Int) -> Unit {
  // No-op for native (would need FFI)
}
