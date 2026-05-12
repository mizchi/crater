///|
/// Native terminal input parsing and key normalization.

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
  let btn = @string.parse_int(parts[0].to_string()) catch { _ => return None }
  let col = @string.parse_int(parts[1].to_string()) catch { _ => return None }
  let row = @string.parse_int(parts[2].to_string()) catch { _ => return None }
  if btn == 0 && suffix == 'M' {
    return Some("MouseDown:\{col},\{row}")
  }
  if btn == 0 && suffix == 'm' {
    return Some("MouseUp:\{col},\{row}")
  }
  if btn == 64 {
    return Some("MouseScrollUp:\{col},\{row}")
  }
  if btn == 65 {
    return Some("MouseScrollDown:\{col},\{row}")
  }
  if suffix == 'M' && btn >= 32 {
    return Some("MouseMove:\{col},\{row}")
  }
  None
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
