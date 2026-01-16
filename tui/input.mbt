///|
/// Input handling for TUI applications
/// Parses terminal escape sequences into structured events

///|
/// Key modifiers
pub(all) enum KeyModifier {
  None
  Shift
  Ctrl
  Alt
  CtrlShift
  CtrlAlt
  ShiftAlt
  CtrlShiftAlt
} derive(Show)

///|
/// Special keys
pub(all) enum SpecialKey {
  Up
  Down
  Left
  Right
  Home
  End
  PageUp
  PageDown
  Insert
  Delete
  Tab
  BackTab
  Backspace
  Enter
  Escape
  F(Int)
} derive(Show)

///|
/// Keyboard event
pub(all) enum KeyEvent {
  Char(Char, KeyModifier)
  Special(SpecialKey, KeyModifier)
} derive(Show)

///|
/// Mouse button
pub(all) enum MouseButton {
  Left
  Middle
  Right
  ScrollUp
  ScrollDown
  None
} derive(Show)

///|
/// Mouse event type
pub(all) enum MouseEventType {
  Press
  Release
  Move
  Drag
} derive(Show)

///|
/// Mouse event
pub(all) struct MouseEvent {
  button : MouseButton
  event_type : MouseEventType
  x : Int
  y : Int
  modifier : KeyModifier
} derive(Show)

///|
/// Input event
pub(all) enum InputEvent {
  Key(KeyEvent)
  Mouse(MouseEvent)
  Resize(Int, Int)
  Unknown(String)
} derive(Show)

///|
/// Parse a single byte as a character
fn is_printable(c : Char) -> Bool {
  let code = c.to_int()
  // ASCII printable or Unicode characters (above 127)
  (code >= 32 && code < 127) || code >= 128
}

///|
/// Parse escape sequence
pub fn parse_input(input : String) -> InputEvent {
  if input.length() == 0 {
    return InputEvent::Unknown("")
  }
  let chars = input.to_array()
  if chars.length() == 1 {
    let c = chars[0]
    let code = c.to_int()
    // Control characters
    if code == 27 {
      return InputEvent::Key(
        KeyEvent::Special(SpecialKey::Escape, KeyModifier::None),
      )
    }
    if code == 13 || code == 10 {
      return InputEvent::Key(
        KeyEvent::Special(SpecialKey::Enter, KeyModifier::None),
      )
    }
    if code == 9 {
      return InputEvent::Key(
        KeyEvent::Special(SpecialKey::Tab, KeyModifier::None),
      )
    }
    if code == 127 {
      return InputEvent::Key(
        KeyEvent::Special(SpecialKey::Backspace, KeyModifier::None),
      )
    }
    // Ctrl+letter (1-26 except 9, 10, 13)
    if code >= 1 && code <= 26 {
      let letter = (code + 96).unsafe_to_char() // 'a' = 97
      return InputEvent::Key(KeyEvent::Char(letter, KeyModifier::Ctrl))
    }
    // Printable characters
    if is_printable(c) {
      return InputEvent::Key(KeyEvent::Char(c, KeyModifier::None))
    }
    return InputEvent::Unknown(input)
  }

  // Escape sequences
  if chars[0] == '\u001b' {
    if chars.length() >= 2 && chars[1] == '[' {
      return parse_csi_sequence(chars)
    }
    if chars.length() >= 2 && chars[1] == 'O' {
      return parse_ss3_sequence(chars)
    }
    // Alt+key
    if chars.length() == 2 {
      let c = chars[1]
      if is_printable(c) {
        return InputEvent::Key(KeyEvent::Char(c, KeyModifier::Alt))
      }
    }
  }

  // Multi-character printable input (e.g., pasted text or unicode)
  // Return the first character as a key event
  if chars.length() > 0 && is_printable(chars[0]) {
    return InputEvent::Key(KeyEvent::Char(chars[0], KeyModifier::None))
  }
  InputEvent::Unknown(input)
}

///|
/// Parse CSI (Control Sequence Introducer) sequence
fn parse_csi_sequence(chars : Array[Char]) -> InputEvent {
  // Skip ESC[
  let len = chars.length()
  if len < 3 {
    return InputEvent::Unknown(String::from_array(chars))
  }
  let final_char = chars[len - 1]

  // Check for SGR mouse format first (ESC[<...M or ESC[<...m)
  let is_sgr = len >= 4 && chars[2] == '<'
  if is_sgr {
    if final_char == 'M' {
      return parse_mouse_sgr(chars, MouseEventType::Press)
    } else if final_char == 'm' {
      return parse_mouse_sgr(chars, MouseEventType::Release)
    }
  }

  // Simple arrow keys and navigation
  match final_char {
    'A' => InputEvent::Key(KeyEvent::Special(SpecialKey::Up, KeyModifier::None))
    'B' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::Down, KeyModifier::None))
    'C' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::Right, KeyModifier::None))
    'D' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::Left, KeyModifier::None))
    'H' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::Home, KeyModifier::None))
    'F' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::End, KeyModifier::None))
    'Z' =>
      InputEvent::Key(
        KeyEvent::Special(SpecialKey::BackTab, KeyModifier::Shift),
      )
    '~' => parse_tilde_sequence(chars)
    'M' => parse_mouse_x10(chars)
    'm' => parse_mouse_sgr(chars, MouseEventType::Release)
    _ => InputEvent::Unknown(String::from_array(chars))
  }
}

///|
/// Parse tilde sequences (Insert, Delete, PgUp, PgDn, F5-F12)
fn parse_tilde_sequence(chars : Array[Char]) -> InputEvent {
  let params = extract_csi_params(chars)
  if params.length() == 0 {
    return InputEvent::Unknown(String::from_array(chars))
  }
  let num = params[0]
  match num {
    1 => InputEvent::Key(KeyEvent::Special(SpecialKey::Home, KeyModifier::None))
    2 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::Insert, KeyModifier::None))
    3 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::Delete, KeyModifier::None))
    4 => InputEvent::Key(KeyEvent::Special(SpecialKey::End, KeyModifier::None))
    5 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::PageUp, KeyModifier::None))
    6 =>
      InputEvent::Key(
        KeyEvent::Special(SpecialKey::PageDown, KeyModifier::None),
      )
    7 => InputEvent::Key(KeyEvent::Special(SpecialKey::Home, KeyModifier::None))
    8 => InputEvent::Key(KeyEvent::Special(SpecialKey::End, KeyModifier::None))
    15 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(5), KeyModifier::None))
    17 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(6), KeyModifier::None))
    18 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(7), KeyModifier::None))
    19 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(8), KeyModifier::None))
    20 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(9), KeyModifier::None))
    21 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(10), KeyModifier::None))
    23 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(11), KeyModifier::None))
    24 =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(12), KeyModifier::None))
    _ => InputEvent::Unknown(String::from_array(chars))
  }
}

///|
/// Parse SS3 (Single Shift 3) sequence for F1-F4
fn parse_ss3_sequence(chars : Array[Char]) -> InputEvent {
  if chars.length() < 3 {
    return InputEvent::Unknown(String::from_array(chars))
  }
  match chars[2] {
    'P' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(1), KeyModifier::None))
    'Q' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(2), KeyModifier::None))
    'R' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(3), KeyModifier::None))
    'S' =>
      InputEvent::Key(KeyEvent::Special(SpecialKey::F(4), KeyModifier::None))
    _ => InputEvent::Unknown(String::from_array(chars))
  }
}

///|
/// Extract numeric parameters from CSI sequence
fn extract_csi_params(chars : Array[Char]) -> Array[Int] {
  let params : Array[Int] = []
  let mut num = 0
  let mut has_num = false
  // Skip ESC[
  for i = 2; i < chars.length() - 1; i = i + 1 {
    let c = chars[i]
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      // '0'-'9'
      num = num * 10 + (code - 48)
      has_num = true
    } else if c == ';' {
      if has_num {
        params.push(num)
      }
      num = 0
      has_num = false
    }
  }
  if has_num {
    params.push(num)
  }
  params
}

///|
/// Parse X10 mouse format (ESC[M followed by 3 bytes)
fn parse_mouse_x10(chars : Array[Char]) -> InputEvent {
  if chars.length() < 6 {
    return InputEvent::Unknown(String::from_array(chars))
  }
  let cb = chars[3].to_int() - 32
  let cx = chars[4].to_int() - 32
  let cy = chars[5].to_int() - 32
  let button_code = cb & 3
  let button = match button_code {
    0 => MouseButton::Left
    1 => MouseButton::Middle
    2 => MouseButton::Right
    3 => MouseButton::None
    _ => MouseButton::None
  }
  let has_bit_64 = (cb & 64) != 0
  let has_bit_32 = (cb & 32) != 0
  let event_type = if has_bit_64 {
    if button_code == 0 {
      MouseEventType::Move // Scroll up
    } else {
      MouseEventType::Move // Scroll down
    }
  } else if has_bit_32 {
    MouseEventType::Drag
  } else if button is MouseButton::None {
    MouseEventType::Release
  } else {
    MouseEventType::Press
  }
  let modifier = parse_mouse_modifier(cb)
  InputEvent::Mouse({ button, event_type, x: cx, y: cy, modifier })
}

///|
/// Parse SGR mouse format (ESC[<Pb;Px;PyM or ESC[<Pb;Px;Pym)
fn parse_mouse_sgr(
  chars : Array[Char],
  event_type : MouseEventType,
) -> InputEvent {
  // Find '<' to confirm SGR format
  let mut start = 0
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '<' {
      start = i + 1
      break
    }
  }
  if start == 0 {
    return InputEvent::Unknown(String::from_array(chars))
  }
  let params = extract_sgr_params(chars, start)
  if params.length() < 3 {
    return InputEvent::Unknown(String::from_array(chars))
  }
  let cb = params[0]
  let cx = params[1]
  let cy = params[2]
  let has_bit_64 = (cb & 64) != 0
  let has_bit_32 = (cb & 32) != 0
  let button_code = cb & 3
  let button = if has_bit_64 {
    if (cb & 1) != 0 {
      MouseButton::ScrollDown
    } else {
      MouseButton::ScrollUp
    }
  } else {
    match button_code {
      0 => MouseButton::Left
      1 => MouseButton::Middle
      2 => MouseButton::Right
      _ => MouseButton::None
    }
  }
  let actual_event_type = if has_bit_32 {
    MouseEventType::Drag
  } else {
    event_type
  }
  let modifier = parse_mouse_modifier(cb)
  InputEvent::Mouse({
    button,
    event_type: actual_event_type,
    x: cx,
    y: cy,
    modifier,
  })
}

///|
/// Extract SGR parameters
fn extract_sgr_params(chars : Array[Char], start : Int) -> Array[Int] {
  let params : Array[Int] = []
  let mut num = 0
  let mut has_num = false
  for i = start; i < chars.length() - 1; i = i + 1 {
    let c = chars[i]
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      num = num * 10 + (code - 48)
      has_num = true
    } else if c == ';' {
      if has_num {
        params.push(num)
      }
      num = 0
      has_num = false
    }
  }
  if has_num {
    params.push(num)
  }
  params
}

///|
/// Parse mouse modifier from button code
fn parse_mouse_modifier(cb : Int) -> KeyModifier {
  let shift = (cb & 4) != 0
  let alt = (cb & 8) != 0
  let ctrl = (cb & 16) != 0
  if ctrl && shift && alt {
    KeyModifier::CtrlShiftAlt
  } else if ctrl && shift {
    KeyModifier::CtrlShift
  } else if ctrl && alt {
    KeyModifier::CtrlAlt
  } else if shift && alt {
    KeyModifier::ShiftAlt
  } else if ctrl {
    KeyModifier::Ctrl
  } else if shift {
    KeyModifier::Shift
  } else if alt {
    KeyModifier::Alt
  } else {
    KeyModifier::None
  }
}

///|
/// Check if key matches a specific character with optional modifier
pub fn key_is_char(event : KeyEvent, c : Char) -> Bool {
  match event {
    KeyEvent::Char(ch, KeyModifier::None) => ch == c
    _ => false
  }
}

///|
/// Check if key matches a special key
pub fn key_is_special(event : KeyEvent, special : SpecialKey) -> Bool {
  match event {
    KeyEvent::Special(s, KeyModifier::None) =>
      match (s, special) {
        (SpecialKey::Up, SpecialKey::Up) => true
        (SpecialKey::Down, SpecialKey::Down) => true
        (SpecialKey::Left, SpecialKey::Left) => true
        (SpecialKey::Right, SpecialKey::Right) => true
        (SpecialKey::Home, SpecialKey::Home) => true
        (SpecialKey::End, SpecialKey::End) => true
        (SpecialKey::PageUp, SpecialKey::PageUp) => true
        (SpecialKey::PageDown, SpecialKey::PageDown) => true
        (SpecialKey::Insert, SpecialKey::Insert) => true
        (SpecialKey::Delete, SpecialKey::Delete) => true
        (SpecialKey::Tab, SpecialKey::Tab) => true
        (SpecialKey::BackTab, SpecialKey::BackTab) => true
        (SpecialKey::Backspace, SpecialKey::Backspace) => true
        (SpecialKey::Enter, SpecialKey::Enter) => true
        (SpecialKey::Escape, SpecialKey::Escape) => true
        (SpecialKey::F(n1), SpecialKey::F(n2)) => n1 == n2
        _ => false
      }
    _ => false
  }
}

///|
/// Check if key is Ctrl+C
pub fn key_is_ctrl_c(event : KeyEvent) -> Bool {
  match event {
    KeyEvent::Char('c', KeyModifier::Ctrl) => true
    _ => false
  }
}

///|
/// Check if key is Ctrl+Q (common quit)
pub fn key_is_ctrl_q(event : KeyEvent) -> Bool {
  match event {
    KeyEvent::Char('q', KeyModifier::Ctrl) => true
    _ => false
  }
}
