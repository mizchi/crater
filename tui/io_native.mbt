///|
/// I/O implementation for native target using C FFI
/// Provides raw mode, terminal size, and character-by-character input

// --- C FFI declarations ---

///|
extern "C" fn tui_enable_raw_mode() -> Int = "tui_enable_raw_mode"

///|
extern "C" fn tui_disable_raw_mode() -> Int = "tui_disable_raw_mode"

///|
extern "C" fn tui_is_raw_mode() -> Int = "tui_is_raw_mode"

///|
extern "C" fn tui_get_terminal_cols() -> Int = "tui_get_terminal_cols"

///|
extern "C" fn tui_get_terminal_rows() -> Int = "tui_get_terminal_rows"

///|
extern "C" fn tui_read_byte() -> Int = "tui_read_byte"

///|
#borrow(buf)
extern "C" fn tui_read_bytes(buf : FixedArray[Byte], max_len : Int) -> Int = "tui_read_bytes"

///|
#borrow(str)
extern "C" fn tui_print_raw_ffi(str : Bytes, len : Int) = "tui_print_raw"

///|
extern "C" fn tui_flush() = "tui_flush"

///|
extern "C" fn tui_is_tty() -> Int = "tui_is_tty"

///|
extern "C" fn tui_sleep_ms(ms : Int) = "tui_sleep_ms"

// --- Helper functions ---

///|
/// Convert a fixed array of bytes to a string with a specific length
fn bytes_to_string(buf : FixedArray[Byte], len : Int) -> String {
  // Create a smaller fixed array with only the needed bytes
  let small_buf = FixedArray::make(len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    small_buf[i] = buf[i]
  }
  Bytes::from_array(small_buf).to_unchecked_string().to_string()
}

// --- Public API ---

///|
/// Enable raw mode for character-by-character input
pub fn enable_raw_mode() -> Unit {
  let _ = tui_enable_raw_mode()
}

///|
/// Disable raw mode and restore terminal settings
pub fn cleanup_stdin() -> Unit {
  let _ = tui_disable_raw_mode()
}

///|
/// Check if terminal is in raw mode
pub fn is_raw_mode() -> Bool {
  tui_is_raw_mode() != 0
}

///|
/// Get terminal size (columns, rows)
pub fn get_terminal_size() -> (Int, Int) {
  let cols = tui_get_terminal_cols()
  let rows = tui_get_terminal_rows()
  (cols, rows)
}

///|
/// Read a single key from stdin (raw mode)
/// Returns the key as a string (may be escape sequence)
pub fn read_key() -> String {
  let first = tui_read_byte()
  if first < 0 {
    return ""
  }

  // Check for escape sequence
  if first == 0x1b {
    // Try to read more bytes for escape sequence
    let buf = FixedArray::make(16, b'\x00')
    buf[0] = first.to_byte()
    let mut len = 1

    // Read additional bytes with short timeout
    for i = 1; i < 16; i = i + 1 {
      let b = tui_read_byte()
      if b < 0 {
        break
      }
      buf[i] = b.to_byte()
      len = len + 1
      // Stop after certain sequences
      if b >= 0x40 && b <= 0x7e {
        break
      }
    }

    // Convert to string
    bytes_to_string(buf, len)
  } else {
    // Single byte character
    let buf = FixedArray::make(4, b'\x00')
    buf[0] = first.to_byte()
    let mut len = 1

    // Check for UTF-8 multi-byte sequence
    if (first & 0xe0) == 0xc0 {
      // 2-byte sequence
      let b = tui_read_byte()
      if b >= 0 {
        buf[1] = b.to_byte()
        len = 2
      }
    } else if (first & 0xf0) == 0xe0 {
      // 3-byte sequence
      for i = 1; i < 3; i = i + 1 {
        let b = tui_read_byte()
        if b < 0 {
          break
        }
        buf[i] = b.to_byte()
        len = len + 1
      }
    } else if (first & 0xf8) == 0xf0 {
      // 4-byte sequence
      for i = 1; i < 4; i = i + 1 {
        let b = tui_read_byte()
        if b < 0 {
          break
        }
        buf[i] = b.to_byte()
        len = len + 1
      }
    }

    bytes_to_string(buf, len)
  }
}

///|
/// Print string to stdout without newline
pub fn print_raw(s : String) -> Unit {
  let bytes = s.to_bytes()
  tui_print_raw_ffi(bytes, bytes.length())
  tui_flush()
}

///|
/// Sleep for milliseconds
pub fn sleep(ms : Int) -> Unit {
  tui_sleep_ms(ms)
}

///|
/// Check if stdin is a TTY
pub fn is_tty() -> Bool {
  tui_is_tty() != 0
}

///|
/// Debug print to stderr
pub fn debug_stderr(s : String) -> Unit {
  println("[DEBUG] " + s)
}

///|
/// Debug stdin state
pub fn debug_stdin_state(_label : String) -> Unit {
  // No-op for native
}

// --- Async versions (using moonbitlang/async) ---

///|
/// Read a line from stdin (line-buffered, cooked mode)
/// Returns the line without trailing newline
pub async fn read_line() -> String {
  let buf = FixedArray::make(1024, b'\x00')
  let n = @stdio.stdin.read(buf, offset=0, max_len=1024)
  if n <= 0 {
    return ""
  }
  let bytes = Bytes::from_array(buf)
  let s = bytes.to_unchecked_string()
  let view = s[:n]
  view.to_string().trim_end(chars="\n\r").to_string()
}

///|
/// Print string to stdout without newline (async version)
pub async fn print_raw_async(s : String) -> Unit {
  @stdio.stdout.write(s)
}

///|
/// Sleep for milliseconds (async version)
pub async fn sleep_async(ms : Int) -> Unit {
  @async.sleep(ms)
}

// --- Input session stubs (would need more complex implementation) ---

///|
/// Keypress handler storage
let keypress_handler : Ref[(String) -> Unit] = { val: fn(_s) {  } }
let keypress_running : Ref[Bool] = { val: false }

///|
/// Start keypress listener (raw mode)
pub fn start_keypress_listener(handler : (String) -> Unit) -> Unit {
  keypress_handler.val = handler
  keypress_running.val = true
  enable_raw_mode()

  // Note: In native, this would need to be run in a loop
  // For now, this is a basic implementation
  // A full implementation would need threading or async polling
}

///|
/// Stop keypress listener
pub fn stop_keypress_listener() -> Unit {
  keypress_running.val = false
  cleanup_stdin()
}

///|
/// Poll for keypress (call this in a loop)
pub fn poll_keypress() -> Bool {
  if not(keypress_running.val) {
    return false
  }
  let key = read_key()
  if key.length() > 0 {
    (keypress_handler.val)(key)
    return true
  }
  false
}

///|
/// Start inplace input (stub - complex implementation needed)
pub fn start_inplace_input(
  _row : Int,
  _col : Int,
  _width : Int,
  _height : Int,
  _multiline : Bool,
  _initial : String,
  _on_result : (InputResult) -> Unit,
) -> Unit {
  // Inplace input requires complex cursor management
  // This is a stub that would need full implementation
}

///|
/// Start inline input with cooked mode (stub)
pub fn start_inline_input_cooked(
  _field_name : String,
  _initial : String,
  _on_result : (InputResult) -> Unit,
) -> Unit {
  // Cooked mode input would need async context
  // This is a stub
}
