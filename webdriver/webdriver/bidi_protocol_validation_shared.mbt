///|
/// Compatibility wrappers for pure BiDi protocol validation helpers.

///|
fn parse_decimal_string(value : String) -> Int? {
  @protocol.parse_decimal_string(value)
}

///|
fn is_ascii_alpha(c : Char) -> Bool {
  @protocol.is_ascii_alpha(c)
}

///|
fn is_ascii_alnum(c : Char) -> Bool {
  @protocol.is_ascii_alnum(c)
}

///|
fn is_ascii_case_insensitive_equal(lhs : String, rhs : String) -> Bool {
  @protocol.is_ascii_case_insensitive_equal(lhs, rhs)
}
