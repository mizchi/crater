///|
/// Native terminal output, mode, and size operations.

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
