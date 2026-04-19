///|
/// Standard Macintosh glyph names (258 entries)
let mac_glyph_names : Array[String] = [
  ".notdef", ".null", "nonmarkingreturn", "space", "exclam", "quotedbl", "numbersign",
  "dollar", "percent", "ampersand", "quotesingle", "parenleft", "parenright", "asterisk",
  "plus", "comma", "hyphen", "period", "slash", "zero", "one", "two", "three", "four",
  "five", "six", "seven", "eight", "nine", "colon", "semicolon", "less", "equal",
  "greater", "question", "at", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
  "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  "bracketleft", "backslash", "bracketright", "asciicircum", "underscore", "grave",
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
  "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar", "braceright",
  "asciitilde", "Adieresis", "Aring", "Ccedilla", "Eacute", "Ntilde", "Odieresis",
  "Udieresis", "aacute", "agrave", "acircumflex", "adieresis", "atilde", "aring",
  "ccedilla", "eacute", "egrave", "ecircumflex", "edieresis", "iacute", "igrave",
  "icircumflex", "idieresis", "ntilde", "oacute", "ograve", "ocircumflex", "odieresis",
  "otilde", "uacute", "ugrave", "ucircumflex", "udieresis", "dagger", "degree", "cent",
  "sterling", "section", "bullet", "paragraph", "germandbls", "registered", "copyright",
  "trademark", "acute", "dieresis", "notequal", "AE", "Oslash", "infinity", "plusminus",
  "lessequal", "greaterequal", "yen", "mu", "partialdiff", "summation", "product",
  "pi", "integral", "ordfeminine", "ordmasculine", "Omega", "ae", "oslash", "questiondown",
  "exclamdown", "logicalnot", "radical", "florin", "approxequal", "Delta", "guillemotleft",
  "guillemotright", "ellipsis", "nonbreakingspace", "Agrave", "Atilde", "Otilde",
  "OE", "oe", "endash", "emdash", "quotedblleft", "quotedblright", "quoteleft", "quoteright",
  "divide", "lozenge", "ydieresis", "Ydieresis", "fraction", "currency", "guilsinglleft",
  "guilsinglright", "fi", "fl", "daggerdbl", "periodcentered", "quotesinglbase",
  "quotedblbase", "perthousand", "Acircumflex", "Ecircumflex", "Aacute", "Edieresis",
  "Egrave", "Iacute", "Icircumflex", "Idieresis", "Igrave", "Oacute", "Ocircumflex",
  "apple", "Ograve", "Uacute", "Ucircumflex", "Ugrave", "dotlessi", "circumflex",
  "tilde", "macron", "breve", "dotaccent", "ring", "cedilla", "hungarumlaut", "ogonek",
  "caron", "Lslash", "lslash", "Scaron", "scaron", "Zcaron", "zcaron", "brokenbar",
  "Eth", "eth", "Yacute", "yacute", "Thorn", "thorn", "minus", "multiply", "onesuperior",
  "twosuperior", "threesuperior", "onehalf", "onequarter", "threequarters", "franc",
  "Gbreve", "gbreve", "Idotaccent", "Scedilla", "scedilla", "Cacute", "cacute", "Ccaron",
  "ccaron", "dcroat",
]

///|
/// Parse post table
pub fn parse_post(
  reader : BinaryReader,
  offset : Int,
  num_glyphs : Int,
) -> PostTable {
  // Fixed-point 16.16 italic angle at offset+4
  // Read italic angle as signed f16dot16
  let hi = reader.peek_int16_at(offset + 4)
  let lo = reader.peek_uint16_at(offset + 6)
  let italic_angle = hi.to_double() + lo.to_double() / 65536.0
  let underline_position = reader.peek_int16_at(offset + 8)
  let underline_thickness = reader.peek_int16_at(offset + 10)
  let is_fixed_pitch_raw = reader.peek_uint32_at(offset + 12)
  let is_fixed_pitch = is_fixed_pitch_raw != 0
  // version at offset+0 (fixed 16.16): 0x00020000 = version 2.0
  let version = reader.peek_uint32_at(offset)
  let glyph_names : Array[String] = []
  if version == 0x00020000 {
    // Version 2.0: name index table
    // numberOfGlyphs at offset+32
    let name_count = reader.peek_uint16_at(offset + 32)
    let count = if name_count < num_glyphs { name_count } else { num_glyphs }
    // glyphNameIndex array at offset+34
    let indices : Array[Int] = []
    for i in 0..<count {
      indices.push(reader.peek_uint16_at(offset + 34 + i * 2))
    }
    // Pascal strings follow the index array
    let mut str_offset = offset + 34 + name_count * 2
    let extra_names : Array[String] = []
    // Read all Pascal strings
    let max_index = {
      let mut m = 0
      for idx in indices {
        if idx > m {
          m = idx
        }
      }
      m
    }
    let num_extra = if max_index >= 258 { max_index - 258 + 1 } else { 0 }
    for i in 0..<num_extra {
      let str_len = reader.data[str_offset].to_int()
      let chars : Array[Char] = []
      for j in 0..<str_len {
        chars.push(
          Int::unsafe_to_char(reader.data[str_offset + 1 + j].to_int()),
        )
      }
      extra_names.push(String::from_array(chars))
      str_offset = str_offset + 1 + str_len
      ignore(i)
    }
    for idx in indices {
      if idx < 258 {
        glyph_names.push(mac_glyph_names[idx])
      } else {
        let extra_idx = idx - 258
        if extra_idx < extra_names.length() {
          glyph_names.push(extra_names[extra_idx])
        } else {
          glyph_names.push("")
        }
      }
    }
  }
  {
    italic_angle,
    underline_position,
    underline_thickness,
    is_fixed_pitch,
    glyph_names,
  }
}
