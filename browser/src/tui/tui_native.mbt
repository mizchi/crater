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
fn bytes_to_string(buf : FixedArray[Byte], len : Int) -> String {
  let chars : Array[Char] = []
  let mut i = 0
  while i < len {
    let b0 = buf[i].to_int()
    if b0 < 0x80 {
      chars.push(b0.unsafe_to_char())
      i = i + 1
    } else if (b0 & 0xE0) == 0xC0 && i + 1 < len {
      let b1 = buf[i + 1].to_int()
      let code = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      chars.push(code.unsafe_to_char())
      i = i + 2
    } else if (b0 & 0xF0) == 0xE0 && i + 2 < len {
      let b1 = buf[i + 1].to_int()
      let b2 = buf[i + 2].to_int()
      let code = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      chars.push(code.unsafe_to_char())
      i = i + 3
    } else if (b0 & 0xF8) == 0xF0 && i + 3 < len {
      let b1 = buf[i + 1].to_int()
      let b2 = buf[i + 2].to_int()
      let b3 = buf[i + 3].to_int()
      let code = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      let adjusted = code - 0x10000
      let high = 0xD800 + (adjusted >> 10)
      let low = 0xDC00 + (adjusted & 0x3FF)
      chars.push(high.unsafe_to_char())
      chars.push(low.unsafe_to_char())
      i = i + 4
    } else {
      i = i + 1
    }
  }
  chars.iter().map(fn(c) { c.to_string() }).fold(init="", fn(a, b) { a + b })
}

///|
fn read_continuation_byte() -> Int {
  let b = tui_read_byte()
  if b >= 0 {
    return b
  }
  for _retry = 0; _retry < 5; _retry = _retry + 1 {
    tui_sleep_ms(1)
    let retry = tui_read_byte()
    if retry >= 0 {
      return retry
    }
  }
  -1
}

///|
fn read_raw_key_from_prefix(prefix : Array[Byte]) -> String {
  if prefix.length() == 0 {
    return ""
  }
  let first = prefix[0].to_int()
  if first == 0x1b {
    let buf = FixedArray::make(32, b'\x00')
    let mut len = 0
    for i = 0; i < prefix.length() && i < 32; i = i + 1 {
      buf[i] = prefix[i]
      len = len + 1
    }
    if len == 1 {
      let second = tui_read_byte()
      if second < 0 {
        return bytes_to_string(buf, len)
      }
      buf[1] = second.to_byte()
      len = 2
    }
    let second = buf[1].to_int()
    if second < 0 {
      return bytes_to_string(buf, len)
    }
    if second == 0x5b {
      let already_complete = len >= 3 &&
        buf[len - 1].to_int() >= 0x40 &&
        buf[len - 1].to_int() <= 0x7E &&
        buf[len - 1].to_int() != 0x5B
      if already_complete {
        return bytes_to_string(buf, len)
      }
      for i = len; i < 32; i = i + 1 {
        let b = tui_read_byte()
        if b < 0 {
          break
        }
        buf[i] = b.to_byte()
        len = len + 1
        if b >= 0x40 && b <= 0x7E && b != 0x5B {
          break
        }
      }
    } else if second == 0x4f {
      let b = tui_read_byte()
      if b >= 0 {
        buf[2] = b.to_byte()
        len = 3
      }
    }
    return bytes_to_string(buf, len)
  }

  let buf = FixedArray::make(4, b'\x00')
  let mut len = 0
  for i = 0; i < prefix.length() && i < 4; i = i + 1 {
    buf[i] = prefix[i]
    len = len + 1
  }
  if (first & 0xE0) == 0xC0 {
    while len < 2 {
      let b = read_continuation_byte()
      if b < 0 {
        break
      }
      buf[len] = b.to_byte()
      len = len + 1
    }
  } else if (first & 0xF0) == 0xE0 {
    while len < 3 {
      let b = read_continuation_byte()
      if b < 0 {
        break
      }
      buf[len] = b.to_byte()
      len = len + 1
    }
  } else if (first & 0xF8) == 0xF0 {
    while len < 4 {
      let b = read_continuation_byte()
      if b < 0 {
        break
      }
      buf[len] = b.to_byte()
      len = len + 1
    }
  }
  bytes_to_string(buf, len)
}

///|
fn parse_mouse_event(key : String) -> String? {
  guard key.has_prefix("\u001b[<") else { return None }
  guard key.length() > 4 else { return None }
  let suffix = key[key.length() - 1]
  guard suffix == 'M' || suffix == 'm' else { return None }
  let payload = key.unsafe_substring(start=3, end=key.length() - 1)
  let parts = payload.split(";").collect()
  guard parts.length() == 3 else { return None }
  let btn = @strconv.parse_int(parts[0].to_string()) catch { _ => return None }
  let col = @strconv.parse_int(parts[1].to_string()) catch { _ => return None }
  let row = @strconv.parse_int(parts[2].to_string()) catch { _ => return None }
  if btn == 0 && suffix == 'M' {
    return Some("Mouse:\{col},\{row}")
  }
  if btn == 64 {
    return Some("MouseScrollUp:\{col},\{row}")
  }
  if btn == 65 {
    return Some("MouseScrollDown:\{col},\{row}")
  }
  None
}

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
    Some(value) => @strconv.parse_int(value) catch { _ => fallback }
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
fn normalize_native_key(key : String) -> String {
  match parse_mouse_event(key) {
    Some(mouse) => mouse
    None =>
      match key {
        "\u0003" => "q"
        "\u0004" => "Ctrl-D"
        "\u001b[A" => "ArrowUp"
        "\u001b[B" => "ArrowDown"
        "\u001b[C" => "ArrowRight"
        "\u001b[D" => "ArrowLeft"
        "\u001b[5~" => "PageUp"
        "\u001b[6~" => "PageDown"
        "\u001b[3~" => "Delete"
        "\u007f" | "\u0008" => "Backspace"
        "\r" | "\n" => "Enter"
        "\t" => "Tab"
        "\u001b[Z" => "Shift-Tab"
        "\u001b" => "Escape"
        "\u0015" => "Ctrl-U"
        _ => key
      }
  }
}

///|
pub fn read_key() -> String {
  read_key_with_timeout(-1)
}

///|
pub fn read_key_with_timeout(timeout_ms : Int) -> String {
  if not(is_tty()) {
    if timeout_ms >= 0 {
      tui_sleep_ms(timeout_ms)
      return ""
    }
    return "q"
  }
  if not(is_raw_mode()) {
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

///|
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
