///|
/// Parse decimal ASCII digits to an int.
fn parse_decimal_string(value : String) -> Int? {
  if value.length() == 0 {
    return None
  }

  let mut parsed = 0
  for c in value.iter() {
    if c < '0' || c > '9' {
      return None
    }
    parsed = parsed * 10 + (c.to_int() - '0'.to_int())
  }
  Some(parsed)
}

///|
/// ASCII alphabetic helper.
fn is_ascii_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// ASCII alphanumeric helper.
fn is_ascii_alnum(c : Char) -> Bool {
  is_ascii_alpha(c) || (c >= '0' && c <= '9')
}

///|
/// Case-insensitive ASCII equality.
fn is_ascii_case_insensitive_equal(lhs : String, rhs : String) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let lhs_chars = lhs.to_array()
  let rhs_chars = rhs.to_array()
  for i = 0; i < lhs_chars.length(); i = i + 1 {
    let l = lhs_chars[i]
    let r = rhs_chars[i]
    if l == r {
      continue
    }
    let l_is_upper = l >= 'A' && l <= 'Z'
    let r_is_upper = r >= 'A' && r <= 'Z'
    if l_is_upper && l.to_int() + 32 == r.to_int() {
      continue
    }
    if r_is_upper && r.to_int() + 32 == l.to_int() {
      continue
    }
    return false
  }
  true
}
