///|
// Shared string helpers for renderer package internals.

///|
/// Remove suffix of given length from string
fn remove_suffix(s : String, len : Int) -> String {
  let end = s.length() - len
  if end <= 0 {
    return ""
  }
  let buf = StringBuilder::new()
  for i = 0; i < end; i = i + 1 {
    buf.write_char(s[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}
