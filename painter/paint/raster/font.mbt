///|
/// Bitmap font public facade.

///|
/// Get bitmap data for an ASCII character.
/// Returns array of 16 bytes, each byte is one row (MSB = leftmost pixel).
/// Returns None for unsupported characters.
pub fn get_char_bitmap(c : Char) -> Array[Int]? {
  match bitmap_font_index(c.to_int()) {
    Some(index) => Some(bitmap_font_data[index])
    None => None
  }
}

///|
/// Check if character is supported by the bitmap font.
pub fn is_font_supported(c : Char) -> Bool {
  bitmap_font_is_supported_code(c.to_int())
}
