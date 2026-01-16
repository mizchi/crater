///|
/// I/O implementation for native target using moonbitlang/async
/// Note: No raw mode support - input is line-buffered

///|
/// Read a line from stdin (line-buffered, not raw mode)
/// Returns the line without trailing newline
pub async fn read_line() -> String {
  let buf = FixedArray::make(1024, b'\x00')
  let n = @stdio.stdin.read(buf, offset=0, max_len=1024)
  if n <= 0 {
    return ""
  }
  // Convert bytes to string, trim trailing newline
  let bytes = Bytes::from_array(buf)
  let s = bytes.to_unchecked_string()
  let view = s[:n]
  view.to_string().trim_end(chars="\n\r").to_string()
}

///|
/// Read a key (stub - returns empty string, would need raw mode)
pub fn read_key() -> String {
  // Raw mode not available without C FFI
  // This is a stub that returns empty string
  ""
}

///|
/// Print string to stdout without newline (async version)
pub async fn print_raw_async(s : String) -> Unit {
  @stdio.stdout.write(s)
}

///|
/// Print string to stdout without newline (sync stub - uses println)
/// Note: True non-newline print requires async context
pub fn print_raw(s : String) -> Unit {
  // In native MoonBit, we can't do sync I/O without async context
  // This is a fallback that adds a newline
  println(s)
}

///|
/// Cleanup stdin state (no-op for native without raw mode)
pub fn cleanup_stdin() -> Unit {
  // No-op - no raw mode to cleanup
}

///|
/// Enable raw mode (stub - not available without C FFI)
pub fn enable_raw_mode() -> Unit {
  // Raw mode requires termios which needs C FFI
}

///|
/// Get terminal size from environment or defaults
pub fn get_terminal_size() -> (Int, Int) {
  // Default to 80x24 if not available
  // Environment variable access would need FFI
  (80, 24)
}

///|
/// Sleep for milliseconds (async version)
pub async fn sleep_async(ms : Int) -> Unit {
  @async.sleep(ms)
}

///|
/// Sleep for milliseconds (sync stub - immediate return)
pub fn sleep(_ms : Int) -> Unit {
  // Sync sleep not available without blocking
  // Would need C FFI for usleep/nanosleep
}

///|
/// Start keypress listener (stub - not available without raw mode)
pub fn start_keypress_listener(_handler : (String) -> Unit) -> Unit {
  // Raw mode input not available without C FFI
}

///|
/// Stop keypress listener (stub)
pub fn stop_keypress_listener() -> Unit {
  // No-op
}

///|
/// Start inplace input (stub - not available without raw mode)
pub fn start_inplace_input(
  _row : Int,
  _col : Int,
  _width : Int,
  _height : Int,
  _multiline : Bool,
  _initial : String,
  _on_result : (InputResult) -> Unit,
) -> Unit {
  // Inplace input requires raw mode
  // This is a stub that does nothing
}

///|
/// Start inline input with cooked mode (simplified for native)
pub fn start_inline_input_cooked(
  _field_name : String,
  _initial : String,
  _on_result : (InputResult) -> Unit,
) -> Unit {
  // Cooked mode input would need async context
  // This is a stub
}

///|
/// Debug print to stderr
pub fn debug_stderr(s : String) -> Unit {
  println("[DEBUG] " + s)
}

///|
/// Debug stdin state (stub)
pub fn debug_stdin_state(_label : String) -> Unit {
  // No-op
}
