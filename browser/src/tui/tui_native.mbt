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
/// Get command line arguments (stub for native)
pub fn get_args() -> Array[String] {
  // TODO: implement native argument parsing
  []
}
