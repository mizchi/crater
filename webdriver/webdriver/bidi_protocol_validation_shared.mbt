///|
/// Compatibility wrappers for pure BiDi protocol validation helpers.

///|
fn parse_decimal_string(value : String) -> Int? {
  @protocol.parse_decimal_string(value)
}

///|
fn json_as_safe_int(value : Json, min : Double, max : Double) -> Int? {
  @protocol.json_as_safe_int(value, min, max)
}

///|
fn json_as_safe_number(value : Json, min : Double, max : Double) -> Double? {
  @protocol.json_as_safe_number(value, min, max)
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
