///|
/// TUI implementation for native target

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
extern "C" fn tui_is_tty() -> Int = "tui_is_tty"

///|
extern "C" fn tui_sleep_ms(ms : Int) = "tui_sleep_ms"

///|
#borrow(buf)
extern "C" fn tui_write_bytes_ffi(buf : FixedArray[Byte], len : Int) = "tui_write_bytes"

///|
extern "C" fn tui_flush() = "tui_flush"

///|
fn trim_line_endings(s : String) -> String {
  let mut end = s.length()
  while end > 0 {
    let c = s[end - 1]
    if c == '\n' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  s.unsafe_substring(start=0, end~)
}

///|
fn env_int_or(key : String, fallback : Int) -> Int {
  match @sys.get_env_var(key) {
    Some(value) => @string.parse_int(value) catch { _ => fallback }
    None => fallback
  }
}

///|
fn is_tty() -> Bool {
  tui_is_tty() != 0
}

///|
fn is_raw_mode() -> Bool {
  tui_is_raw_mode() != 0
}

///|
pub fn read_key() -> String {
  read_key_with_timeout(-1)
}

///|
pub fn read_key_with_timeout(timeout_ms : Int) -> String {
  if !is_tty() {
    if timeout_ms >= 0 {
      tui_sleep_ms(timeout_ms)
      return ""
    }
    return "q"
  }
  if !is_raw_mode() {
    enable_raw_mode()
  }
  let prefix : Array[Byte] = []
  let mut waited = 0
  let step_ms = 5
  while true {
    let b = tui_read_byte()
    if b >= 0 {
      prefix.push(b.to_byte())
      break
    }
    if timeout_ms >= 0 && waited >= timeout_ms {
      return ""
    }
    tui_sleep_ms(step_ms)
    waited = waited + step_ms
  }
  for _i = 0; _i < 31; _i = _i + 1 {
    let b = tui_read_byte()
    if b < 0 {
      break
    }
    prefix.push(b.to_byte())
  }
  normalize_native_key(read_raw_key_from_prefix(prefix))
}

///|
pub async fn read_line(prompt : String) -> String {
  cleanup_stdin()
  print_raw(prompt)
  match @stdio.stdin.read_until("\n") {
    Some(line) => trim_line_endings(line)
    None => ""
  }
}

///|
pub fn print_raw(s : String) -> Unit {
  let str_len = s.length()
  let buf = FixedArray::make(str_len * 4, b'\x00')
  let mut pos = 0
  let mut i = 0
  while i < str_len {
    let unit = s[i].to_int()
    if unit >= 0xD800 && unit <= 0xDBFF && i + 1 < str_len {
      let unit2 = s[i + 1].to_int()
      if unit2 >= 0xDC00 && unit2 <= 0xDFFF {
        let code = 0x10000 + ((unit - 0xD800) << 10) + (unit2 - 0xDC00)
        pos = pos + encode_utf8(code, buf, pos)
        i = i + 2
        continue
      }
    }
    pos = pos + encode_utf8(unit, buf, pos)
    i = i + 1
  }
  tui_write_bytes_ffi(buf, pos)
  tui_flush()
}

///|
pub fn cleanup_stdin() -> Unit {
  let _ = tui_disable_raw_mode()
}

///|
pub fn get_args() -> Array[String] {
  let all_args = @sys.get_cli_args()
  let result : Array[String] = []
  for i = 1; i < all_args.length(); i = i + 1 {
    result.push(all_args[i])
  }
  result
}

///|
pub fn get_terminal_size() -> (Int, Int) {
  let cols = tui_get_terminal_cols()
  let rows = tui_get_terminal_rows()
  let resolved_cols = if cols > 0 { cols } else { env_int_or("COLUMNS", 80) }
  let resolved_rows = if rows > 0 { rows } else { env_int_or("LINES", 24) }
  (resolved_cols, resolved_rows)
}

///|
pub fn enable_raw_mode() -> Unit {
  let _ = tui_enable_raw_mode()
}

///|
pub async fn wait_for_enter() -> Unit {
  let _ = read_line("")
}
