///|
/// TUI implementation for native target
/// Note: Full TUI is simplified for MVP - use JS target for interactive mode

///|
/// Read a key (simplified - reads a line in native)
pub fn read_key() -> String {
  // Native stdin reading requires BufferedReader
  // For MVP, just return quit after a delay
  "q"
}

///|
/// Read a line with prompt
pub fn read_line(_prompt : String) -> String {
  // Simplified for MVP
  ""
}

///|
/// Print string to stdout
pub fn print_raw(s : String) -> Unit {
  println(s)
}

///|
/// Cleanup stdin state (stub for native)
pub fn cleanup_stdin() -> Unit {
  // No-op for native
}

///|
/// Get command line arguments (native implementation)
pub fn get_args() -> Array[String] {
  // Get command line args using sys module (skips first element which is program name)
  let all_args = @sys.get_cli_args()
  let result : Array[String] = []
  for i = 1; i < all_args.length(); i = i + 1 {
    result.push(all_args[i])
  }
  result
}

///|
/// Get terminal size in characters (columns, rows)
/// Native implementation - returns default values for now
/// TODO: Use ioctl TIOCGWINSZ or environment variables COLUMNS/LINES
pub fn get_terminal_size() -> (Int, Int) {
  // Default terminal size
  (80, 24)
}

///|
/// Enable raw mode (stub for native)
pub fn enable_raw_mode() -> Unit {
  // No-op for native
}

///|
/// Wait for Enter key (stub for native)
pub fn wait_for_enter() -> Unit {
  // No-op for native
}
