///|
/// Bitmap font dimensions and ASCII support range.

///|
pub let font_width : Int32 = 8

///|
pub let font_height : Int32 = 16

///|
let bitmap_font_min_code : Int32 = 32

///|
let bitmap_font_max_code : Int32 = 126

///|
fn bitmap_font_is_supported_code(code : Int32) -> Bool {
  code >= bitmap_font_min_code && code <= bitmap_font_max_code
}

///|
fn bitmap_font_index(code : Int32) -> Int32? {
  if bitmap_font_is_supported_code(code) {
    Some(code - bitmap_font_min_code)
  } else {
    None
  }
}
