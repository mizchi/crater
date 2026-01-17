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
#borrow(buf)
extern "C" fn tui_write_bytes_ffi(buf : FixedArray[Byte], len : Int) = "tui_write_bytes"

///|
extern "C" fn tui_flush() = "tui_flush"

///|
extern "C" fn tui_is_tty() -> Int = "tui_is_tty"

///|
extern "C" fn tui_sleep_ms(ms : Int) = "tui_sleep_ms"

// --- Helper functions ---

///|
/// Decode UTF-8 bytes to a MoonBit String (UTF-16)
fn bytes_to_string(buf : FixedArray[Byte], len : Int) -> String {
  let chars : Array[Char] = []
  let mut i = 0

  while i < len {
    let b0 = buf[i].to_int()

    if b0 < 0x80 {
      // ASCII (single byte)
      chars.push(b0.unsafe_to_char())
      i = i + 1
    } else if (b0 & 0xE0) == 0xC0 && i + 1 < len {
      // 2-byte UTF-8 sequence
      let b1 = buf[i + 1].to_int()
      let code = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      chars.push(code.unsafe_to_char())
      i = i + 2
    } else if (b0 & 0xF0) == 0xE0 && i + 2 < len {
      // 3-byte UTF-8 sequence
      let b1 = buf[i + 1].to_int()
      let b2 = buf[i + 2].to_int()
      let code = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      chars.push(code.unsafe_to_char())
      i = i + 3
    } else if (b0 & 0xF8) == 0xF0 && i + 3 < len {
      // 4-byte UTF-8 sequence (outside BMP, needs surrogate pair)
      let b1 = buf[i + 1].to_int()
      let b2 = buf[i + 2].to_int()
      let b3 = buf[i + 3].to_int()
      let code = ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
      // Encode as UTF-16 surrogate pair
      let adjusted = code - 0x10000
      let high = 0xD800 + (adjusted >> 10)
      let low = 0xDC00 + (adjusted & 0x3FF)
      chars.push(high.unsafe_to_char())
      chars.push(low.unsafe_to_char())
      i = i + 4
    } else {
      // Invalid or unexpected byte, skip
      i = i + 1
    }
  }

  // Convert Array[Char] to String
  chars.iter().map(fn(c) { c.to_string() }).fold(init="", fn(a, b) { a + b })
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

    // Read second byte
    let second = tui_read_byte()
    if second < 0 {
      // Just ESC
      return bytes_to_string(buf, len)
    }
    buf[1] = second.to_byte()
    len = 2

    // Check if it's a CSI sequence (ESC [)
    if second == 0x5b {
      // CSI sequence - read until final byte (0x40-0x7E, excluding '[')
      for i = 2; i < 16; i = i + 1 {
        let b = tui_read_byte()
        if b < 0 {
          break
        }
        buf[i] = b.to_byte()
        len = len + 1
        // Final byte of CSI is in 0x40-0x7E range (letters and some symbols)
        // But not '[' (0x5B) and not intermediate/parameter bytes (0x20-0x3F)
        if b >= 0x40 && b <= 0x7e && b != 0x5b {
          break
        }
      }
    } else if second == 0x4f {
      // SS3 sequence (ESC O) - read one more byte
      let b = tui_read_byte()
      if b >= 0 {
        buf[2] = b.to_byte()
        len = 3
      }
    }
    // Other escape sequences: just return what we have

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
/// Encode a Unicode code point to UTF-8 bytes
fn encode_utf8(code : Int, buf : FixedArray[Byte], pos : Int) -> Int {
  if code < 0x80 {
    buf[pos] = code.to_byte()
    1
  } else if code < 0x800 {
    buf[pos] = (0xC0 | (code >> 6)).to_byte()
    buf[pos + 1] = (0x80 | (code & 0x3F)).to_byte()
    2
  } else if code < 0x10000 {
    buf[pos] = (0xE0 | (code >> 12)).to_byte()
    buf[pos + 1] = (0x80 | ((code >> 6) & 0x3F)).to_byte()
    buf[pos + 2] = (0x80 | (code & 0x3F)).to_byte()
    3
  } else {
    buf[pos] = (0xF0 | (code >> 18)).to_byte()
    buf[pos + 1] = (0x80 | ((code >> 12) & 0x3F)).to_byte()
    buf[pos + 2] = (0x80 | ((code >> 6) & 0x3F)).to_byte()
    buf[pos + 3] = (0x80 | (code & 0x3F)).to_byte()
    4
  }
}

///|
/// Print string to stdout without newline
pub fn print_raw(s : String) -> Unit {
  // Convert UTF-16 string to UTF-8 bytes
  let str_len = s.length()
  // Max 4 bytes per code point
  let max_size = str_len * 4
  let buf = FixedArray::make(max_size, b'\x00')
  let mut pos = 0
  let mut i = 0

  while i < str_len {
    let unit = s[i].to_int()

    // Check for surrogate pair (for characters outside BMP)
    if unit >= 0xD800 && unit <= 0xDBFF && i + 1 < str_len {
      let unit2 = s[i + 1].to_int()
      if unit2 >= 0xDC00 && unit2 <= 0xDFFF {
        // Decode surrogate pair to code point
        let code = 0x10000 + ((unit - 0xD800) << 10) + (unit2 - 0xDC00)
        pos = pos + encode_utf8(code, buf, pos)
        i = i + 2
        continue
      }
    }

    // Regular BMP character
    pos = pos + encode_utf8(unit, buf, pos)
    i = i + 1
  }

  tui_write_bytes_ffi(buf, pos)
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
let inside_listener_loop : Ref[Bool] = { val: false }

///|
/// Start keypress listener (raw mode) - blocks until stop_keypress_listener is called
/// This provides the same interface as JS where the listener runs until stopped
/// If called from within a handler (e.g., from restore_tui), just updates the handler
pub fn start_keypress_listener(handler : (String) -> Unit) -> Unit {
  keypress_handler.val = handler
  keypress_running.val = true
  enable_raw_mode()

  // If called from within a handler, just update the handler reference
  // The original loop will continue with the new handler
  if inside_listener_loop.val {
    return
  }

  inside_listener_loop.val = true

  // Run polling loop internally - this blocks until stop_keypress_listener is called
  while keypress_running.val {
    let key = read_key()
    if key.length() > 0 {
      (keypress_handler.val)(key)
    } else {
      sleep(10)
    }
  }

  inside_listener_loop.val = false
}

///|
/// Stop keypress listener
pub fn stop_keypress_listener() -> Unit {
  keypress_running.val = false
  cleanup_stdin()
}

///|
/// Poll for keypress (call this in a loop) - for manual polling if needed
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
/// Get character display width (simplified: ASCII=1, CJK=2)
fn char_width_code(code : Int) -> Int {
  if code < 0x80 {
    1
  } else if code >= 0x1100 &&
    (code <= 0x115F ||
    code == 0x2329 ||
    code == 0x232A ||
    (code >= 0x2E80 && code <= 0x9FFF) ||
    (code >= 0xAC00 && code <= 0xD7A3) ||
    (code >= 0xF900 && code <= 0xFAFF) ||
    (code >= 0xFE10 && code <= 0xFE1F) ||
    (code >= 0xFE30 && code <= 0xFE6F) ||
    (code >= 0xFF00 && code <= 0xFF60) ||
    (code >= 0xFFE0 && code <= 0xFFE6)) {
    2
  } else {
    1
  }
}

///|
/// Get string display width
fn string_width(s : String) -> Int {
  let mut width = 0
  for i = 0; i < s.length(); i = i + 1 {
    width = width + char_width_code(s[i].to_int())
  }
  width
}

///|
/// Render text buffer at position with wrapping
fn render_inplace_buffer(
  text : String,
  start_row : Int,
  start_col : Int,
  max_width : Int,
  max_height : Int,
) -> (Int, Int) {
  let mut output = ""
  let mut row = start_row
  let mut col = start_col

  // Move to start position and clear area
  for r = 0; r < max_height; r = r + 1 {
    output = output + "\u001b[" + (start_row + r).to_string() + ";" + start_col.to_string() + "H"
    for w = 0; w < max_width; w = w + 1 {
      output = output + " "
    }
  }
  output = output + "\u001b[" + start_row.to_string() + ";" + start_col.to_string() + "H"

  // Render text with wrapping
  let mut line_width = 0
  for i = 0; i < text.length(); i = i + 1 {
    let code = text[i].to_int()
    let cw = char_width_code(code)

    // Handle newline
    if code == 10 {
      // '\n'
      row = row + 1
      col = start_col
      line_width = 0
      if row < start_row + max_height {
        output = output + "\u001b[" + row.to_string() + ";" + col.to_string() + "H"
      }
      continue
    }

    // Wrap if needed
    if line_width + cw > max_width {
      row = row + 1
      col = start_col
      line_width = 0
      if row < start_row + max_height {
        output = output + "\u001b[" + row.to_string() + ";" + col.to_string() + "H"
      }
    }

    if row < start_row + max_height {
      output = output + Int::unsafe_to_char(code).to_string()
      line_width = line_width + cw
      col = col + cw
    }
  }

  print_raw(output)
  (row, col)
}

///|
/// Helper to convert buffer to string
fn buf_to_string(buf : Array[Char]) -> String {
  buf.iter().map(fn(c) { c.to_string() }).fold(init="", fn(a, b) { a + b })
}

///|
/// Start inplace input (native implementation with raw mode editing)
/// Blocks until user confirms, cancels, or tabs
pub fn start_inplace_input(
  row : Int,
  col : Int,
  width : Int,
  height : Int,
  multiline : Bool,
  initial : String,
  on_result : (InputResult) -> Unit,
) -> Unit {
  // Ensure raw mode is enabled
  let was_raw = is_raw_mode()
  if not(was_raw) {
    enable_raw_mode()
  }

  // Initialize buffer with initial value
  let buf : Array[Char] = []
  for i = 0; i < initial.length(); i = i + 1 {
    buf.push(Int::unsafe_to_char(initial[i].to_int()))
  }

  // Cursor position within buffer
  let mut cursor_pos = buf.length()

  // Render initial state and show cursor
  let _ = render_inplace_buffer(buf_to_string(buf), row, col, width, height)
  let text_before = buf_to_string(buf.iter().take(cursor_pos).collect())
  let offset = string_width(text_before)
  print_raw("\u001b[" + (row + offset / width).to_string() + ";" + (col + offset % width).to_string() + "H")
  print_raw(ansi_show_cursor())

  // Edit loop
  for {
    let key = read_key()
    if key.length() == 0 {
      sleep(10)
      continue
    }

    let mut need_render = false
    let mut done = false
    let mut result : InputResult = InputResult::Cancelled

    // Check for escape sequences
    if key.length() > 1 && key[0].to_int() == 0x1b {
      if key == "\u001b[Z" {
        // Shift+Tab - confirm and go to previous
        done = true
        result = InputResult::TabPrev(buf_to_string(buf))
      } else if key == "\u001b[D" {
        // Left arrow - move cursor left
        if cursor_pos > 0 {
          cursor_pos = cursor_pos - 1
          need_render = true
        }
      } else if key == "\u001b[C" {
        // Right arrow - move cursor right
        if cursor_pos < buf.length() {
          cursor_pos = cursor_pos + 1
          need_render = true
        }
      } else if key == "\u001b[A" || key == "\u001b[B" {
        // Up/Down arrows - ignore for now (TODO: multiline navigation)
        ()
      } else if key == "\u001b[H" {
        // Home - move to start
        cursor_pos = 0
        need_render = true
      } else if key == "\u001b[F" {
        // End - move to end
        cursor_pos = buf.length()
        need_render = true
      }
    } else if key == "\u001b" {
      // Escape - cancel
      done = true
      result = InputResult::Cancelled
    } else if key.length() == 1 {
      let code = key[0].to_int()

      if code == 9 {
        // Tab - confirm and go to next
        done = true
        result = InputResult::TabNext(buf_to_string(buf))
      } else if code == 13 {
        // Enter (CR) - confirm (both single and multiline)
        done = true
        result = InputResult::Confirmed(buf_to_string(buf))
      } else if code == 10 {
        // Ctrl+J (LF) - newline in multiline, confirm in single line
        if multiline {
          buf.insert(cursor_pos, '\n')
          cursor_pos = cursor_pos + 1
          need_render = true
        } else {
          done = true
          result = InputResult::Confirmed(buf_to_string(buf))
        }
      } else if code == 4 {
        // Ctrl+D - also confirm
        done = true
        result = InputResult::Confirmed(buf_to_string(buf))
      } else if code == 3 {
        // Ctrl+C - cancel
        done = true
        result = InputResult::Cancelled
      } else if code == 127 || code == 8 {
        // Backspace - delete char before cursor
        if cursor_pos > 0 {
          let _ = buf.remove(cursor_pos - 1)
          cursor_pos = cursor_pos - 1
          need_render = true
        }
      } else if code == 1 {
        // Ctrl+A - move to start
        cursor_pos = 0
        need_render = true
      } else if code == 5 {
        // Ctrl+E - move to end
        cursor_pos = buf.length()
        need_render = true
      } else if code >= 32 {
        // Printable character - insert at cursor
        let c = Int::unsafe_to_char(code)
        let new_str = buf_to_string(buf) + c.to_string()
        let new_width = string_width(new_str)
        let max_total = width * height
        if new_width <= max_total {
          buf.insert(cursor_pos, c)
          cursor_pos = cursor_pos + 1
          need_render = true
        }
      }
    } else {
      // Multi-byte UTF-8 character - insert at cursor
      for i = 0; i < key.length(); i = i + 1 {
        buf.insert(cursor_pos, Int::unsafe_to_char(key[i].to_int()))
        cursor_pos = cursor_pos + 1
      }
      need_render = true
    }

    if need_render {
      let _ = render_inplace_buffer(buf_to_string(buf), row, col, width, height)
      // Update cursor position display
      let text_before_cursor = buf_to_string(buf.iter().take(cursor_pos).collect())
      let cursor_offset = string_width(text_before_cursor)
      let cursor_row = row + cursor_offset / width
      let cursor_col = col + cursor_offset % width
      print_raw("\u001b[" + cursor_row.to_string() + ";" + cursor_col.to_string() + "H")
      print_raw(ansi_show_cursor())
    }

    if done {
      // Hide cursor before exiting
      print_raw(ansi_hide_cursor())
      // Restore raw mode state if we changed it
      if not(was_raw) {
        cleanup_stdin()
      }
      on_result(result)
      return
    }
  }
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

// --- Functions for JS compatibility ---

///|
/// Keep alive non-blocking (no-op for native, used in JS for event loop)
pub fn keep_alive_nonblocking(_ms : Int) -> Unit {
  // No-op for native - native uses blocking loop
}

///|
/// Start inline input (same as inplace input for native)
pub fn start_inline_input(
  row : Int,
  col : Int,
  width : Int,
  height : Int,
  multiline : Bool,
  initial : String,
  on_result : (InputResult) -> Unit,
) -> Unit {
  start_inplace_input(row, col, width, height, multiline, initial, on_result)
}

///|
/// Start render ticker (stub - native uses polling loop instead)
pub fn start_render_ticker(_ms : Int, _callback : () -> Unit) -> Int {
  // Native doesn't need a render ticker - it uses a polling loop
  0
}

///|
/// Stop render ticker (stub)
pub fn stop_render_ticker(_ticker_id : Int) -> Unit {
  // No-op for native
}

///|
/// Start input session with callback (wrapper for start_inplace_input)
pub fn start_input_session_cb(
  row : Int,
  col : Int,
  width : Int,
  height : Int,
  multiline : Bool,
  initial : String,
  on_result : (InputResult) -> Unit,
) -> Unit {
  start_inplace_input(row, col, width, height, multiline, initial, on_result)
}

///|
/// Abort input session (stub)
pub fn abort_input_session() -> Unit {
  // Native input is blocking, cannot be aborted externally
}
