///|
/// Bitmap font dimensions and ASCII support range.

///|
pub let font_width : Int = 8

///|
pub let font_height : Int = 16

///|
let bitmap_font_min_code : Int = 32

///|
let bitmap_font_max_code : Int = 126

///|
fn bitmap_font_is_supported_code(code : Int) -> Bool {
  code >= bitmap_font_min_code && code <= bitmap_font_max_code
}

///|
fn bitmap_font_index(code : Int) -> Int? {
  if bitmap_font_is_supported_code(code) {
    Some(code - bitmap_font_min_code)
  } else {
    None
  }
}
