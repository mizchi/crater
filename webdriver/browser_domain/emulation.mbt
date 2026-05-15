///|
/// Pure helpers for synthetic emulation domain handling.

///|
pub fn default_runtime_user_agent() -> String {
  "Crater/1.0 (MoonBit; BiDi)"
}

///|
pub fn extract_emulation_fetch_url(expression : String) -> String? {
  let open_paren = match @protocol.find_substring(expression, "fetch(", 0) {
    Some(idx) => idx + 6
    None => return None
  }
  let chars = expression.to_array()
  let mut cursor = open_paren
  while cursor < chars.length() && chars[cursor] == ' ' {
    cursor = cursor + 1
  }
  if cursor >= chars.length() {
    return None
  }
  let quote = chars[cursor]
  if quote != '\'' && quote != '"' {
    return None
  }
  let mut end = cursor + 1
  while end < chars.length() && chars[end] != quote {
    end = end + 1
  }
  if end >= chars.length() {
    return None
  }
  Some(expression.unsafe_substring(start=cursor + 1, end~))
}

///|
pub fn emulation_timezone_offset_minutes(timezone : String) -> Int? {
  if timezone.length() != 6 {
    return None
  }
  let chars = timezone.to_array()
  let sign = chars[0]
  if sign != '+' && sign != '-' {
    return None
  }
  if chars[3] != ':' {
    return None
  }
  if !(chars[1] >= '0' &&
    chars[1] <= '9' &&
    chars[2] >= '0' &&
    chars[2] <= '9' &&
    chars[4] >= '0' &&
    chars[4] <= '9' &&
    chars[5] >= '0' &&
    chars[5] <= '9') {
    return None
  }
  let hours = (chars[1].to_int() - '0'.to_int()) * 10 +
    (chars[2].to_int() - '0'.to_int())
  let minutes = (chars[4].to_int() - '0'.to_int()) * 10 +
    (chars[5].to_int() - '0'.to_int())
  let total = hours * 60 + minutes
  Some(if sign == '+' { -total } else { total })
}
