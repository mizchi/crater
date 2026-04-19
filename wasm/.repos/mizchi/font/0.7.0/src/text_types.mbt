///|
/// Text rendering type definitions.

///|
pub(all) struct FontKey {
  family : String
  weight : Int
  italic : Bool
} derive(Show)

///|
pub(all) struct TextStyle {
  font : FontKey
  size_px : Double
  line_height : Double
  letter_spacing : Double
} derive(Show)

///|
pub(all) struct TextMetrics {
  width : Double
  height : Double
  baseline : Double
} derive(Show)

///|
pub(all) struct GlyphQuad {
  glyph_id : Int
  atlas_x : Double
  atlas_y : Double
  atlas_w : Double
  atlas_h : Double
  dst_x : Double
  dst_y : Double
  dst_w : Double
  dst_h : Double
} derive(Show)

///|
pub(all) struct TextRun {
  text : String
  style : TextStyle
} derive(Show)

///|
pub fn new_text_run(text : String, style : TextStyle) -> TextRun {
  { text, style }
}

///|
pub fn default_text_style(family : String, size_px : Double) -> TextStyle {
  {
    font: { family, weight: 400, italic: false },
    size_px,
    line_height: size_px * 1.4,
    letter_spacing: 0.0,
  }
}

///|
pub enum FontFormat {
  TrueType
  OpenType
  Woff1
  Woff2
  TrueTypeCollection
  Unknown
} derive(Show, Eq)

///|
pub fn detect_font_format(data : Bytes) -> FontFormat {
  if data.length() < 4 {
    return Unknown
  }
  let b0 = data[0]
  let b1 = data[1]
  let b2 = data[2]
  let b3 = data[3]
  if b0 == b'\x00' && b1 == b'\x01' && b2 == b'\x00' && b3 == b'\x00' {
    TrueType
  } else if b0 == b'\x4F' && b1 == b'\x54' && b2 == b'\x54' && b3 == b'\x4F' {
    OpenType
  } else if b0 == b'\x77' && b1 == b'\x4F' && b2 == b'\x46' && b3 == b'\x46' {
    Woff1
  } else if b0 == b'\x77' && b1 == b'\x4F' && b2 == b'\x46' && b3 == b'\x32' {
    Woff2
  } else if b0 == b'\x74' && b1 == b'\x74' && b2 == b'\x63' && b3 == b'\x66' {
    TrueTypeCollection
  } else {
    Unknown
  }
}

///|
pub(all) struct AtlasPageInfo {
  page_id : Int
  width : Int
  height : Int
  dirty : Bool
} derive(Show)
